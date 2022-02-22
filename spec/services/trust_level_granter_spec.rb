# frozen_string_literal: true

require 'rails_helper'

describe TrustLevelGranter do
  fab!(:post) { Fabricate(:post) }
  fab!(:topic) { Fabricate(:topic, id: 1, first_post: post) }

  before do
    SiteSetting.custom_trust_level_enabled = true
    SiteSetting.csl_topic_id_for_trust_level_freeze = 1
  end

  describe 'grant' do
    it 'grants trust level when liked specified topic' do
      user = Fabricate(:user, email: "foo@bar.com", trust_level: 0)
      PostActionCreator.create(user, post, :like)
      TrustLevelGranter.grant(3, user)

      user.reload
      expect(user.trust_level).to eq(3)
    end

    it 'does not grants trust level when not liked specified topic' do
      user = Fabricate(:user, email: "foo@bar.com", trust_level: 0)
      TrustLevelGranter.grant(3, user)

      user.reload
      expect(user.trust_level).to eq(0)
    end

    it 'grants trust level when not liked specified topic and users trust level is greater than specified' do
      user = Fabricate(:user, email: "foo@bar.com", trust_level: 1)
      TrustLevelGranter.grant(3, user)

      user.reload
      expect(user.trust_level).to eq(3)
    end
  end
end
