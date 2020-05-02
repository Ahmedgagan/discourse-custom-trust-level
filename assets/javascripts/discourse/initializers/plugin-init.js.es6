import { withPluginApi } from "discourse/lib/plugin-api";
import { alias } from "@ember/object/computed";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import User from "discourse/models/user";

export default {
  name: "enable-links",

  initialize(container) {
    withPluginApi("0.8.33",pluginInit)
  }
}
function pluginInit(api){
  api.modifyClass("controller:user",{  
    @discourseComputed('siteSettings.csl_display_tl0_website_as_link')
    linkWebsite(settingEnabled){
      return settingEnabled || this._super(...arguments);
    }
  });
  api.modifyClass("component:topic-footer-buttons",{ 
    @on('init')
    subscribe(){
      const currentUser = User.current();
      if(currentUser) {
        console.log("ghus gaya")
        this.messageBus.subscribe(`/${currentUser.id}/custom_can_create_post`, canCreate => {
          console.log("ghus gaya")
          console.log(canCreate)
          this.set('topic.details.can_create_post', canCreate)
        });
      }
    }
  });
}