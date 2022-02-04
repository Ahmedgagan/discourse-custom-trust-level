import { withPluginApi } from "discourse/lib/plugin-api";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import User from "discourse/models/user";
import I18n from "I18n";
import { postUrl } from "discourse/lib/utilities";

export default {
  name: "enable-links",

  initialize() {
    withPluginApi("0.8.33", pluginInit);
  },
};
function pluginInit(api) {
  api.modifyClass("controller:user", {
    @discourseComputed("siteSettings.csl_display_tl0_website_as_link")
    linkWebsite(settingEnabled) {
      return settingEnabled || this._super(...arguments);
    },
  });

  const currentUser = api.getCurrentUser();
  const siteSettings = api.container.lookup("site-settings:main");

  if (!currentUser.allow_trust_level_upgrade) {
    api.addGlobalNotice(
      `Please read <a href='${postUrl(null, parseInt(siteSettings.csl_topic_id_for_trust_level_freeze))}'>Beginners Guide</a> topic and make sure to give it a like.`,
      "trust-level-freeze-notice",
      { html: "<h3>Your are freezed on a trust level!</h3>", }
    );
  }

  api.modifyClass("component:topic-footer-buttons", {
    @on("init")
    subscribe() {
      const currentUser = User.current();

      if (currentUser && !this.topic.isPrivateMessage) {
        this.messageBus.subscribe(
          `/${currentUser.id}/custom_can_create_post`,
          (canCreate) => {
            this.set("topic.details.can_create_post", canCreate);
          }
        );
      }
    },
  });
}
