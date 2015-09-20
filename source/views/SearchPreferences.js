enyo.kind({
	name: "SearchPreferences",
	layoutKind: "FittableRowsLayout",
	palm: false,
	preferredSearchId: undefined,
	universalSearchList: undefined,
	// onyx.Picker onChange always gets called twice
	// but we only want to act once.
	actOnChange_searchEnginePicker: false,
	components:[
		{kind: "onyx.Toolbar",
		 style: "line-height: 28px;",
		 components:[
			 {name: "TextDiv",
			  tag: "div",
			  style: "height: 100%; margin: 0;",
			  components: [
				  {name: "Title",
				   // On HP webOS 2.2.4 this was "Just Type Preferences".
				   // I am not sure that is accurate for LuneOS.
				   content: "Search Preferences"}
			  ]}
		 ]},
		{kind: "Scroller",
		 fit: true, touch: true, horizontal: "hidden",
		 components: [{
			 kind: "enyo.FittableRows",
			 components: [
				 {kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout",
				  name: "spg1", style: "padding: 35px 10% 0 10%;", components: [
					  {kind: "onyx.GroupboxHeader", content: "Default Search Engine"},
					  {kind: "enyo.FittableColumns", classes: "group-item",
					   components: [
						   {name: "searchEngineIcon", kind: "onyx.Icon",
						    style: "width: 48px; height: 48px"},
						   {kind: "onyx.PickerDecorator", fit: true,
						    components: [
							   {name: "searchEngineButton", content: "Not set"},
							   {name: "searchEnginePicker",
							    kind: "onyx.Picker",
							    onChange: "searchEngineChanged",
							    components: []
							   }
						   ]}
					   ]}
				  ]}]}
		             ]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
		{kind: "enyo.LunaService", method: "getAllSearchPreference", subscribe: true,
		 name: "GetAllSearchPreference",
		 service: "luna://com.palm.universalsearch",
		 onComplete: "handleGetAllSearchPreferenceResponse"},
		{kind: "enyo.LunaService", method: "getUniversalSearchList", subscribe: true,
		 name: "GetUniversalSearchList",
		 service: "luna://com.palm.universalsearch",
		 onComplete: "handleGetUniversalSearchListResponse"},
		{kind: "enyo.LunaService", method: "setSearchPreference",
		 name: "SetSearchPreference",
		 service: "luna://com.palm.universalsearch"}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");
			return;
		}
		this.$.GetAllSearchPreference.send({});
		this.palm = true;
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
			this.$.spg1.setStyle("padding: 35px 5% 0 5%;");
		}
		else {
			this.$.Grabber.applyStyle("visibility", "visible");
			this.$.spg1.setStyle("padding: 35px 10% 0 10%;");
		}
	},
	//Action Handlers
	searchEngineChanged: function(inSender, inEvent) {
		var id;
		if (this.actOnChange_searchEnginePicker) {
			if (this.palm) {
				// The picker does not tell us the selected id,
				// it tells us the selected displayName.
				// (At least it is a reasonable assumption that
				// both are unique sets.)
				for (var i = 0; i < this.universalSearchList.length; ++i) {
					if (inEvent.selected.content ===
					    this.universalSearchList[i].displayName) {
						id = this.universalSearchList[i].id;
					}
				}
				if (id !== undefined) {
					this.$.SetSearchPreference.send({key: "defaultSearchEngine",
					                                 value: id});
					this.log("Set defaultSearchEngine " + id + " sent");
				} else {
					this.log("Somehow selected unknown search engine: " +
					         inEvent.selected.content);
				}
			}
			else {
				this.log("Set defaultSearchEngine " + inEvent.selected.content +
				         " suppressed");
			}
		}
		this.actOnChange_searchEnginePicker = !this.actOnChange_searchEnginePicker;
	},
	//Service Callbacks
	handleGetAllSearchPreferenceResponse: function(inSender, inResponse) {
		if (inResponse.SearchPreference !== undefined &&
		    inResponse.SearchPreference.defaultSearchEngine !== undefined) {
			this.preferredSearchId = inResponse.SearchPreference.defaultSearchEngine;
			this.$.GetUniversalSearchList.send({});
		}
	},
	handleGetUniversalSearchListResponse: function(inSender, inResponse) {
		var newIx;
		var item;
		var newSel;
		if (inResponse["UniversalSearchList"] !== undefined) {
			// Keep a note of the list.
			// searchEngineChanged assumes it and the picker map one-to-one
			// so set things up that way.
			this.universalSearchList = inResponse.UniversalSearchList;
			this.$.searchEnginePicker.destroyClientControls();
			for (var i = 0; i < this.universalSearchList.length; ++i) {
				item = this.universalSearchList[i];
				this.$.searchEnginePicker.
					createComponent({content: item.displayName});
				if (item.id === this.preferredSearchId) {
					newIx = i;
				}
			}
			if (typeof newIx !== "undefined") {
				this.$.searchEngineIcon.setSrc(
					this.universalSearchList[newIx].iconFilePath);
				newSel = this.$.searchEnginePicker.getClientControls()[newIx];
				this.$.searchEnginePicker.silence();
				this.$.searchEnginePicker.setSelected(newSel);
				this.$.searchEnginePicker.unsilence();
				this.$.searchEngineButton.setContent(newSel.content);
			} else {
				this.$.searchEngineButton.setContent("Unrecognised: " +
					this.preferredSearchId);
			}
			this.$.searchEnginePicker.render();
		}
	}
});
