# frozen_string_literal: true

require 'rails_helper'
require 'guardian'

describe Guardian do
  let(:trust_level_0) { build(:user, trust_level: 0) }
  let(:trust_level_1) { build(:user, trust_level: 1) }
  let(:trust_level_2) { build(:user, trust_level: 2) }
  let(:trust_level_3) { build(:user, trust_level: 3) }
  let(:trust_level_4) { build(:user, trust_level: 4) }
  let(:topic) { Fabricate(:topic) }

  before { SiteSetting.custom_trust_level_enabled = true }

  describe "can_create_post_on_topic?" do
    before do
      SiteSetting.csl_can_create_post_on_topic_min_trust_level = 1
    end

    it 'returns true if user has trust_level specified in site setting' do
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to be_truthy
    end

    it 'returns false if user doesnt have has trust_level specified in site setting' do
      expect(Guardian.new(trust_level_0).can_create_post_on_topic?(topic)).to be_falsey
    end
  end

  describe 'can_edit_topic?' do

    before do
      SiteSetting.trusted_users_can_edit_others = true
    end

    context "when enabled" do
      before do
        SiteSetting.csl_can_tl3_edit_topics = true
      end

      it 'returns true for users of trust_level_3' do
        expect(Guardian.new(trust_level_3).can_edit_topic?(topic)).to be_truthy
      end
    end

    context "when disabled" do
      before do
        SiteSetting.csl_can_tl3_edit_topics = false
      end

      it 'returns false for users of trust_level_3' do
        expect(Guardian.new(trust_level_3).can_edit_topic?(topic)).to be_falsey
      end
    end
  end

  describe 'can_reply_as_new_topic?' do
    context "when enabled" do
      before do
        SiteSetting.csl_can_tl0_reply_as_new_topic = true
      end

      it 'returns true for users having trust_level_0' do
        expect(Guardian.new(trust_level_0).can_reply_as_new_topic?(topic)).to be_truthy
      end
    end

    context "when disabled" do
      before do
        SiteSetting.csl_can_tl0_reply_as_new_topic = false
      end

      it 'returns false for users having trust_level_0' do
        expect(Guardian.new(trust_level_0).can_reply_as_new_topic?(topic)).to be_falsey
      end
    end
  end

  describe 'can_invite_to?' do
    before do
      SiteSetting.csl_can_invite_to_topic_min_trust_level = 2
    end

    it 'returns true for users having csl_can_invite_to_topic_min_trust_level' do
      expect(Guardian.new(trust_level_2).can_invite_to?(topic)).to be_truthy
    end

    it 'returns false for users not having csl_can_invite_to_topic_min_trust_level' do
      expect(Guardian.new(trust_level_0).can_invite_to?(topic)).to be_falsey
    end
  end

  describe 'can_ignore_users?' do
    before do
      SiteSetting.csl_min_trust_level_to_ignore_users = 2
    end

    it 'returns true for users having csl_min_trust_level_to_ignore_users' do
      expect(Guardian.new(trust_level_2).can_ignore_users?).to be_truthy
    end

    it 'returns false for users not having csl_min_trust_level_to_ignore_users' do
      expect(Guardian.new(trust_level_0).can_ignore_users?).to be_falsey
    end
  end

  describe 'can_invite_to_forum?' do
    before do
      SiteSetting.csl_min_trust_level_to_invite_to_forum = 3
    end

    it 'returns true for users having csl_min_trust_level_to_invite_to_forum' do
      expect(Guardian.new(trust_level_3).can_invite_to_forum?).to be_truthy
    end

    it 'returns false for users not having csl_min_trust_level_to_invite_to_forum' do
      expect(Guardian.new(trust_level_2).can_invite_to_forum?).to be_falsey
    end
  end

end
