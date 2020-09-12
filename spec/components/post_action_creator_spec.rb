# frozen_string_literal: true

require 'rails_helper'

describe PostActionCreator do
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post) }

  before { SiteSetting.custom_trust_level_enabled = true }

  context "flags" do
    describe "Auto hide spam flagged posts" do
      before do
        SiteSetting.high_trust_flaggers_auto_hide_posts = true
        SiteSetting.csl_min_trust_level_to_auto_hide_post = 2
        user.trust_level = TrustLevel[2]
        post.user.trust_level = TrustLevel[0]
      end

      it "hides the post when the flagger have csl_min_trust_level_to_auto_hide_post and the poster is a TL0 user" do
        result = PostActionCreator.create(user, post, :spam)

        expect(post.hidden?).to eq(true)
      end

      it 'does not hide the post if the setting is disabled' do
        SiteSetting.high_trust_flaggers_auto_hide_posts = false

        result = PostActionCreator.create(user, post, :spam)

        expect(post.hidden?).to eq(false)
      end

      it 'does not hide the post if the user does not have csl_min_trust_level_to_auto_hide_post' do
        user.trust_level = TrustLevel[1]
        user.save

        result = PostActionCreator.create(user, post, :spam)

        expect(post.hidden?).to eq(false)
      end
    end
  end
end