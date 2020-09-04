import { withPluginApi } from "discourse/lib/plugin-api";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default {
  name: "enable-links",

  initialize(container) {
    withPluginApi("0.8.33", pluginInit);
  }
};
function pluginInit(api) {
  api.modifyClass("controller:user", {
    @discourseComputed("siteSettings.csl_display_tl0_website_as_link")
    linkWebsite(settingEnabled) {
      return settingEnabled || this._super(...arguments);
    }
  });
}
