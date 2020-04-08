
enabled_site_setting :custom_trust_level_enabled
after_initialize do

  module ModifyCanCreate
    def can_create_post_on_topic?(topic)
      is_admin?||is_moderator?||( super && user.trust_level >= SiteSetting.can_create_post_on_topic_min_trust_level)
    end
    def can_edit_topic?(topic)
      return false if (
        !SiteSetting.can_tl3_edit_topics
        SiteSetting.trusted_users_can_edit_others? &&
        !topic.archived &&
        !topic.private_message? &&
        user.has_trust_level?(TrustLevel[3]) &&
        can_create_post?(topic)
      )
      super
    end
    def can_reply_as_new_topic?(topic)
      (authenticated? && topic && SiteSetting.can_tl0_reply_as_new_topic && user.has_trust_level?(TrustLevel[0])) || super
    end
  end

  class ::Guardian
    prepend ModifyCanCreate if SiteSetting.custom_trust_level_enabled
  end
end