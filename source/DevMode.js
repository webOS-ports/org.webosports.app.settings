enyo.kind({
	name: "DevMode",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{kind: "Signals", ondeviceready: "deviceready"},
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
		if(!window.PalmSystem)
			enyo.log("Non-palm platform, service requests disabled.");
	},
	deviceready: function(inSender, inEvent) {
		this.inherited(arguments);
		var request = navigator.service.Request("luna://org.webosports.service.customization",
		{
			method: 'getDevModeState',
			subscribe: true,
			resubscribe: true,
			onSuccess: enyo.bind(this, "onGetDevModeStateResponse")
		});
		this.palm = true;
	},
	onDevModeChanged: function(inSender, inEvent) {
		var request = navigator.service.Request("luna://org.webosports.service.customization",
		{
			method: 'setDevModeState',
			parameters: {"state": inEvent.value ? "enabled" : "disabled"}
		});
	},
	onGetDevModeStateResponse: function (inResponse) {
		this.$.DevModeToggle.setValue(inResponse.status == "enabled");
	}
});
