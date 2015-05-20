enyo.kind({
	name: "SearchPreferences",
	layoutKind: "FittableRowsLayout",
	palm: false,
	preferredSearch: undefined,
	components:[
		{kind: "onyx.Toolbar",
		 style: "line-height: 28px;",
		 components:[
			 {name: "TextDiv",
			  tag: "div",
			  style: "height: 100%; margin: 0;",
			  components: [
				  {name: "Title",
				   content: "Just Type Preferences"}
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
						   {content: "", fit: true},
						   {kind: "onyx.PickerDecorator", components: [
							   {},
							   {name: "SearchEnginePicker",
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
		{kind: "enyo.LunaService", method: "getAllSearchPreference",
		 name: "GetAllSearchPreference",
		 service: "luna://com.palm.universalsearch",
		 onComplete: "handleGetAllSearchPreferenceResponse"},
		{kind: "enyo.LunaService", method: "getUniversalSearchList",
		 name: "GetUniversalSearchList",
		 service: "luna://com.palm.universalsearch",
		 onComplete: "handleGetUniversalSearchListResponse"}
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
		if(this.palm) {
		}
		else {
			this.log(inSender.selected);
		}
	},
	//Service Callbacks
	handleGetAllSearchPreferenceResponse: function(inSender, inResponse) {
		if (inResponse.SearchPreference !== undefined &&
		    inResponse.SearchPreference.defaultSearchEngine !== undefined) {
			this.preferredSearch = inResponse.SearchPreference.defaultSearchEngine;
			this.$.GetUniversalSearchList.send({});
		}
	},
	handleGetUniversalSearchListResponse: function(inSender, inResponse) {
		if (inResponse["UniversalSearchList"] !== undefined) {
			for (var i = 0; i < inResponse.UniversalSearchList.length; ++i) {
				var item = inResponse.UniversalSearchList[i];
				this.$.SearchEnginePicker.
					createComponent({content: item.displayName});
				if (item.displayName === this.preferredSearch) {
					this.$.SearchEnginePicker.getClientControls()[i+1].setActive(true);
				}
			}
			this.render();
		}
	}
});
