# frozen_string_literal: true

# name: custom trust level
# about: Adds a few custom trust levels capabilities in Discourse
# version: 0.1.0
# authors: Ahmed Gagan(Ahmedgagan), Faizan Gagan(fzngagan)
# url: https://github.com/Ahmedgagan/discourse-custom-trust-level

enabled_site_setting :custom_trust_level_enabled
load File.expand_path('../models/custom_trust_level_setting.rb', __FILE__)
DiscoursePluginRegistry.serialized_current_user_fields << "allow_trust_level_upgrade"
after_initialize do

  self.on(:post_created) do |post, options|
    user = User.find(post.user_id)
    topic = Topic.find(post.topic_id)

    if !(user.admin || user.moderator) && !topic.private_message?
      if topic.posts_count <= 20 && topic.posts.where("user_id=?", user.id).count >= SiteSetting.csl_numbers_of_replies_upto_20_posts
        MessageBus.publish("/#{user.id}/custom_can_create_post", false)
      elsif topic.posts_count > 20 && topic.posts_count <= 50 && topic.posts.where("user_id=?", user.id).count >= SiteSetting.csl_numbers_of_replies_upto_50_posts
        MessageBus.publish("/#{user.id}/custom_can_create_post", false)
      elsif topic.posts_count > 50 && topic.posts.where("user_id=?", user.id).count >= SiteSetting.csl_numbers_of_replies_above_50_posts
        MessageBus.publish("/#{user.id}/custom_can_create_post", false)
      else
        MessageBus.publish("/#{user.id}/custom_can_create_post", true)
      end
    end
  end

  module ModifyCanCreate

    def can_create_post_on_topic?(topic)
      return true if is_admin?
      return true if is_moderator?

      if !topic.private_message?
        return false if topic.posts_count <= 20 && topic.posts.where("user_id=?", current_user.id).count >= SiteSetting.csl_numbers_of_replies_upto_20_posts

        return false if topic.posts_count > 20 && topic.posts_count <= 50 && topic.posts.where("user_id=?", current_user.id).count >= SiteSetting.csl_numbers_of_replies_upto_50_posts

        return false if topic.posts_count > 50 && topic.posts.where("user_id=?", current_user.id).count >= SiteSetting.csl_numbers_of_replies_above_50_posts
      end

      is_admin? || is_moderator? || (super && user.trust_level >= SiteSetting.csl_can_create_post_on_topic_min_trust_level)
    end

    def can_edit_topic?(topic)
      return false if (
        !SiteSetting.csl_can_tl3_edit_topics &&
        SiteSetting.trusted_users_can_edit_others? &&
        !topic.archived &&
        !topic.private_message? &&
        user.has_trust_level?(TrustLevel[3]) &&
        can_create_post?(topic)
      )
      super
    end

    def can_reply_as_new_topic?(topic)
      (authenticated? && topic && SiteSetting.csl_can_tl0_reply_as_new_topic && user.has_trust_level?(TrustLevel[0])) || super
    end

    def can_invite_to?(object, groups = nil)
      return false unless authenticated?
      is_topic = object.is_a?(Topic)
      return true if is_admin? && !is_topic
      return false if (SiteSetting.max_invites_per_day.to_i == 0 && !is_staff?)
      return false unless can_see?(object)
      return false if groups.present?

      if is_topic
        if object.private_message?
          return true if is_admin?
          return false unless SiteSetting.enable_personal_messages?
          return false if object.reached_recipients_limit? && !is_staff?
        end

        if (category = object.category) && category.read_restricted
          if (groups = category.groups&.where(automatic: false))&.any?
            return groups.any? { |g| can_edit_group?(g) } ? true : false
          else
            return false
          end
        end
      end

      user.has_trust_level?(SiteSetting.csl_can_invite_to_topic_min_trust_level)
    end

    def can_ignore_users?
      return false if anonymous?
      @user.staff? || @user.trust_level >= SiteSetting.csl_min_trust_level_to_ignore_users
    end

    def can_invite_to_forum?(groups = nil)
      authenticated? &&
      (SiteSetting.max_invites_per_day.to_i > 0 || is_staff?) &&
      !SiteSetting.enable_discourse_connect &&
      SiteSetting.enable_local_logins &&
      (
        (!SiteSetting.must_approve_users? && @user.has_trust_level?(SiteSetting.csl_min_trust_level_to_invite_to_forum)) ||
        is_staff?
      ) &&
      (groups.blank? || is_admin? || groups.all? { |g| can_edit_group?(g) })
    end

  end

  module PostActionCreatorExtender
    private
    def trusted_spam_flagger?
      SiteSetting.high_trust_flaggers_auto_hide_posts &&
        @post_action_name == :spam &&
        @created_by.has_trust_level?(SiteSetting.csl_min_trust_level_to_auto_hide_post) &&
        @post.user&.trust_level == TrustLevel[0]
    end
  end

  module CustomTrustLevelGranter
    def grant
      if @user.trust_level < @trust_level && @user.allow_trust_level_upgrade
        @user.change_trust_level!(@trust_level)
        @user.save!
      end
    end
  end

  add_to_class(:user, :allow_trust_level_upgrade) do
    return true if SiteSetting.csl_topic_id_for_trust_level_freeze.to_i <= 0
    return true if self.admin?
    return true if self.trust_level > SiteSetting.csl_user_trust_level_to_freeze
    return true if Topic.find(SiteSetting.csl_topic_id_for_trust_level_freeze.to_i).user_id == self.id
    return true if self.custom_fields['allow_trust_level_upgrade']
    return true if Topic.find(SiteSetting.csl_topic_id_for_trust_level_freeze.to_i).first_post.post_actions.where(post_action_type_id: PostActionType.types[:like], user_id: self.id).first

    return false
  end

  add_to_serializer(:current_user, :allow_trust_level_upgrade) do
    object.allow_trust_level_upgrade
  end

  PostActionCreator.prepend PostActionCreatorExtender if SiteSetting.custom_trust_level_enabled

  Guardian.prepend ModifyCanCreate if SiteSetting.custom_trust_level_enabled

  TrustLevelGranter.prepend CustomTrustLevelGranter if SiteSetting.custom_trust_level_enabled

  register_user_custom_field_type('allow_trust_level_upgrade', :boolean)
  allow_staff_user_custom_field 'allow_trust_level_upgrade'
  allow_public_user_custom_field 'allow_trust_level_upgrade'
  register_editable_user_custom_field 'allow_trust_level_upgrade'

  on(:like_created) do |like|
    if like.post.topic_id == SiteSetting.csl_topic_id_for_trust_level_freeze.to_i && !like.user.custom_fields['allow_trust_level_upgrade']
      like.user.custom_fields['allow_trust_level_upgrade'] = true
      like.user.save_custom_fields(true)
    end
  end
end
