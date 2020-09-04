# frozen_string_literal: true

# name: custom trust level
# about: Adds a few custom trust levels capabilities in Discourse
# version: 0.1.0
# authors: Ahmed Gagan(Ahmedgagan), Faizan Gagan(fzngagan)
# url: https://github.com/Ahmedgagan/discourse-custom-trust-level

enabled_site_setting :custom_trust_level_enabled
load File.expand_path('../models/custom_trust_level_setting.rb', __FILE__)
after_initialize do
  module ModifyCanCreate

    def can_create_post_on_topic?(topic)
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

  end

  class PostActionCreator

    private
    def auto_hide_if_needed
      return if @post.hidden?
      return if !@created_by.staff? && @post.user&.staff?
      return unless PostActionType.auto_action_flag_types.include?(@post_action_name)

      # Special case: If you have min trust level and the user is TL0, and the flag is spam,
      # hide it immediately.
      return if SiteSetting.csl_min_trust_level_to_auto_hide_post < 0

      if SiteSetting.high_trust_flaggers_auto_hide_posts &&
          @post_action_name == :spam &&
          @created_by.has_trust_level?(SiteSetting.csl_min_trust_level_to_auto_hide_post) &&
          @post.user&.trust_level == TrustLevel[0]

        @post.hide!(@post_action_type_id, Post.hidden_reasons[:flagged_by_tl3_user])
        return
      end

      score = ReviewableFlaggedPost.find_by(target: @post)&.score || 0
      if score >= Reviewable.score_required_to_hide_post
        @post.hide!(@post_action_type_id)
      end
    end
  end

  class ::Guardian
    prepend ModifyCanCreate if SiteSetting.custom_trust_level_enabled
  end
end
