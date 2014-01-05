enyo.kind({
	name: "DevModeService",
	kind: "enyo.PalmService",
	service: "palm://org.webosports.service.devmode/"
});

enyo.kind({
	name: "DevOptions",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{kind: "Signals", ondeviceready: "deviceready"},
		{
			kind: "onyx.Toolbar",
			style: "line-height: 36px;",
			components:[
				{ content: "Developer Options" },
				{ name: "DevModeToggle", kind: "onyx.ToggleButton", style: "position: absolute; top: 8px; right: 6px; height: 31px;", onChange: "onDevModeChanged"}
			]
		},
		{
			name: "DevModePanels",
			kind: "Panels",
			arrangerKind: "HFlipArranger",
			fit: true,
			draggable: false,
			components:[
				{
					name: "DevModeDisabled",
					layoutKind: "FittableRowsLayout",
					style: "padding: 35px 10% 35px 10%;",
					components: [
						{
							style:"padding-bottom: 10px;",
							components: [
								{content: "Developer mode is disabled", style: "display: inline;"},
							]
						}
					]
				},
				{
					name: "DevModeSettings",
					layoutKind: "FittableRowsLayout",
					style: "padding: 35px 10% 35px 10%;",
					components: [
						{
							kind: "Scroller",
							touch: true,
							horizontal: "hidden",
							fit: true,
							components: [
								{tag: "div", style: "padding: 35px 10% 35px 10%;", components: [
									{kind: "onyx.Groupbox", components: [
										{kind: "onyx.GroupboxHeader", content: "Graphics"},
										{classes: "group-item", components:[
											{kind: "Control", content: "Enable FPS counter", style: "display: inline-block; line-height: 32px;"},
											{name: "FpsCounterToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "fpsCounterChanged"},
										]}
									]}
								]}
							]
						}
					]
				}
			]
		},
		{
			name: "GetState",
			kind: "DevModeService",
			method: "getState",
			subscribe: true,
			resubscribe: true,
			onResponse: "onGetStateResponse"
		},
		{
			name: "SetState",
			kind: "DevModeService",
			method: "setState",
			onResponse: "onSetStateResponse"
		}
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem)
			enyo.log("Non-palm platform, service requests disabled.");
	},
	deviceready: function(inSender, inEvent) {
		this.inherited(arguments);
		this.palm = true;
		this.$.GetState.send({});
	},
	onDevModeChanged: function(inSender, inEvent) {
		if (!this.palm) {
			this.$.DevModePanels.setIndex(inEvent.value ? 1 : 0);
			return;
		}
		this.$.SetState.send({"state": inEvent.value ? "enabled" : "disabled"});
	},
	onGetStateResponse: function (inSender, inResponse) {
		var result = inResponse.data;
		if (result.status === "enabled") {
			this.$.DevModeToggle.setValue(true);
			this.$.DevModePanels.setIndex(1);
		}
		else {
			this.$.DevModeToggle.setValue(false);
			this.$.DevModePanels.setIndex(0);
		}
	},
	onSetStateResponse: function (inSender, inResponse) {
	},
	fpsCounterChanged: function (inSender, inEvent) {
		var request = navigator.service.Request("luna://com.palm.systemmanager",
		{
			method: 'enableFpsCounter',
			parameters: { "enable": inEvent.value }
		});
	}
});
