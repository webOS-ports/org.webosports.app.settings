enyo.kind({
	name: "CustomizationService",
	kind: "enyo.webOS.ServiceRequest",
	service: "palm://org.webosports.service.customization"
});

enyo.kind({
	name: "DevMode",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{
			kind: "onyx.Toolbar",
			style: "line-height: 36px;",
			components:[
				{ content: "Developer Mode" },
				{ name: "DevModeToggle", kind: "onyx.ToggleButton", style: "position: absolute; top: 8px; right: 6px; height: 31px;", onChange: "onDevModeChanged"}
			]
		},
		{
			kind: "Scroller",
			touch: true,
			horizontal: "hidden",
			fit: true,
			components: [ ]
		},
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(window.PalmSystem) {
			getDevModeState = new CustomizationService({"method": "getDevModeState", "subscribe": true, "resubscribe": true});
			getDevModeState.response(this, "onGetDevModeStateResponse");
			getDevModeState.go();
			this.palm = true;
		}
		else {
			enyo.log("Non-palm platform, service requests disabled.");
		}
	},
	onDevModeChanged: function(inSender, inEvent) {
		setDevModeState = new CustomizationService({"method": "setDevModeState"});
		if (inEvent.value) {
			setDevModeState.go({"state":"enabled"});
		}
		else {
			setDevModeState.go({"state":"disabled"});
		}
	},
	onGetDevModeStateResponse: function (inSender, inResponse) {
		if (inResponse.status == "enabled") {
			this.$.DevModeToggle.setValue(true);
		}
		else {
			this.$.DevModeToggle.setValue(false);
		}
	}
});
