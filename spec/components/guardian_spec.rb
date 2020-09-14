# frozen_string_literal: true

require 'rails_helper'
require 'guardian'

describe Guardian do
  let(:trust_level_0) { build(:user, trust_level: 0) }
  let(:trust_level_1) { build(:user, trust_level: 1) }
  let(:trust_level_2) { build(:user, trust_level: 2) }
  let(:trust_level_3) { build(:user, trust_level: 3) }
  let(:admin) { build(:admin) }
  let(:moderator) { build(:moderator) }
  let(:topic) { Fabricate(:topic, posts_count: 10) }

  before { SiteSetting.custom_trust_level_enabled = true }

  describe "can_create_post_on_topic?" do
    before do
      SiteSetting.csl_can_create_post_on_topic_min_trust_level = 1
      SiteSetting.csl_numbers_of_replies_upto_20_posts = 2
      SiteSetting.csl_numbers_of_replies_upto_50_posts = 3
      SiteSetting.csl_numbers_of_replies_above_50_posts = 5
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 11)
      topic.posts << Fabricate(:post, user: admin, post_number: 13)
      topic.posts << Fabricate(:post, user: admin, post_number: 14)
    end

    it 'returns true if user has trust_level specified in site setting' do
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(true)
    end

    it 'returns false if user doesnt have has trust_level specified in site setting' do
      expect(Guardian.new(trust_level_0).can_create_post_on_topic?(topic)).to eq(false)
    end

    it 'returns true if users has posts less than site setting csl_numbers_of_replies_upto_20_posts' do
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(true)
    end

    it 'returns true if users has posts less than site setting csl_numbers_of_replies_upto_50_posts' do
      topic.posts_count = 21
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 22)
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(true)
    end

    it 'returns true if users has posts less than site setting csl_numbers_of_replies_above_50_posts' do
      topic.posts_count = 51
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 52)
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 53)
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 54)
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(true)
    end

    it 'returns false if users have posts count equal to site setting csl_numbers_of_replies_upto_20_posts' do
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 12)
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(false)
    end

    it 'returns false if users have posts count equal to site setting csl_numbers_of_replies_upto_50_posts' do
      topic.posts_count = 21
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 22)
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 23)
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(false)
    end

    it 'returns false if users have posts count equal to site setting csl_numbers_of_replies_above_50_posts' do
      topic.posts_count = 51
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 52)
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 53)
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 54)
      topic.posts << Fabricate(:post, user: trust_level_1, post_number: 55)
      expect(Guardian.new(trust_level_1).can_create_post_on_topic?(topic)).to eq(false)
    end

    it 'returns true if user is admin' do
      expect(Guardian.new(admin).can_create_post_on_topic?(topic)).to eq(true)
    end

    it 'returns true if user is admin' do
      expect(Guardian.new(moderator).can_create_post_on_topic?(topic)).to eq(true)
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
        expect(Guardian.new(trust_level_3).can_edit_topic?(topic)).to eq(true)
      end
    end

    context "when disabled" do
      before do
        SiteSetting.csl_can_tl3_edit_topics = false
      end

      it 'returns false for users of trust_level_3' do
        expect(Guardian.new(trust_level_3).can_edit_topic?(topic)).to eq(false)
      end
    end
  end

  describe 'can_reply_as_new_topic?' do
    context "when enabled" do
      before do
        SiteSetting.csl_can_tl0_reply_as_new_topic = true
      end

      it 'returns true for users having trust_level_0' do
        expect(Guardian.new(trust_level_0).can_reply_as_new_topic?(topic)).to eq(true)
      end
    end

    context "when disabled" do
      before do
        SiteSetting.csl_can_tl0_reply_as_new_topic = false
      end

      it 'returns false for users having trust_level_0' do
        expect(Guardian.new(trust_level_0).can_reply_as_new_topic?(topic)).to eq(false)
      end
    end
  end

  describe 'can_invite_to?' do
    before do
      SiteSetting.csl_can_invite_to_topic_min_trust_level = 2
    end

    it 'returns true for users having csl_can_invite_to_topic_min_trust_level' do
      expect(Guardian.new(trust_level_2).can_invite_to?(topic)).to eq(true)
    end

    it 'returns false for users not having csl_can_invite_to_topic_min_trust_level' do
      expect(Guardian.new(trust_level_0).can_invite_to?(topic)).to eq(false)
    end
  end

  describe 'can_ignore_users?' do
    before do
      SiteSetting.csl_min_trust_level_to_ignore_users = 2
    end

    it 'returns true for users having csl_min_trust_level_to_ignore_users' do
      expect(Guardian.new(trust_level_2).can_ignore_users?).to eq(true)
    end

    it 'returns false for users not having csl_min_trust_level_to_ignore_users' do
      expect(Guardian.new(trust_level_0).can_ignore_users?).to eq(false)
    end
  end
end
