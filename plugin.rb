# name: custom trust level
# about: Adds a few custom trust levels capabilities in Discourse
# version: 0.1.0
# authors: Ahmed Gagan(Ahmedgagan), Faizan Gagan(fzngagan)
# url: https://github.com/Ahmedgagan/discourse-custom-trust-level


enabled_site_setting :custom_trust_level_enabled
after_initialize do

  self.on(:post_created) do |post, options|
    p "on me ghusa"
    p post
    p post.topic_id
    p post.user_id
    user = User.find(post.user_id)
    topic = Topic.find(post.topic_id)
    
    if !(user.admin || user.moderator)
      if topic.posts_count<=20
        if topic.posts.where("user_id=?",user.id).length >= 2
          MessageBus.publish("/#{user.id}/custom_can_create_post", false)
        else
          MessageBus.publish("/#{user.id}/custom_can_create_post", true)
        end
      elsif topic.posts_count>20 && topic.posts_count<=50
        if topic.posts.where("user_id=?",user.id).length >= 3
          MessageBus.publish("/#{user.id}/custom_can_create_post", false)
        else
          MessageBus.publish("/#{user.id}/custom_can_create_post", true)
        end
      elsif topic.posts_count>50
        if topic.posts.where("user_id=?",user.id).length >= 5
          MessageBus.publish("/#{user.id}/custom_can_create_post", false)
        else
          MessageBus.publish("/#{user.id}/custom_can_create_post", true)
        end
      end
    end
  end


  module ModifyCanCreate

    def can_create_post_on_topic?(topic)
      return true if is_admin?
      return true if is_moderator?
      if topic.posts_count<=20
        if topic.posts.where("user_id=?",current_user.id).length >= 2
          return false
        end
      elsif topic.posts_count>20 && topic.posts_count<=50
        if topic.posts.where("user_id=?",current_user.id).length >= 3
          return false
        end
      elsif topic.posts_count>50
        if topic.posts.where("user_id=?",current_user.id).length >= 5
          return false
        end
      end
      is_admin?||is_moderator?||( super && user.trust_level >= SiteSetting.csl_can_create_post_on_topic_min_trust_level)
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
  end

  class ::Guardian
    prepend ModifyCanCreate if SiteSetting.custom_trust_level_enabled
    
  end
end
