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
		{
			kind: "onyx.Toolbar",
			style: "line-height: 36px;",
			components:[
				{ content: "Developer Options" },
				{ name: "DevModeToggle", kind: "onyx.ToggleButton", style: "position: absolute; top: 8px; right: 6px; height: 31px;",
				  onChange: "onDevModeChanged", value: true, disabled: true}
			]
		},
		{
			name: "DevModePanels",
			kind: "Panels",
			arrangerKind: "HFlipArranger",
			fit: true,
			draggable: false,
			/* until we have some functionality to handle devmode enabled/disabled we
			 * alwas enable the panel by default */
			index: 1,
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
										{kind: "onyx.GroupboxHeader", content: "Debugging"},
										{classes: "group-item", components: [
											{kind: "Control", content: "USB debugging",
											 style: "display: inline-block; line-height: 32px"},
											{kind: "onyx.ToggleButton", name: "UsbDebuggingToggle", style: "float: right;",
											 onChange: "onUsbDebuggingChanged"}
										]}
									]},
									{kind: "onyx.Groupbox", components: [
										{kind: "onyx.GroupboxHeader", content: "Graphics"},
										{classes: "group-item", components:[
											{kind: "Control", content: "Enable FPS counter", style: "display: inline-block; line-height: 32px;"},
											{name: "FpsCounterToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "onFpsCounterChanged"},
										]}
									]}
								]}
							]
						}
					]
				}
			]
		},
		{name: "GetStatus", kind: "DevModeService", method: "getStatus", onComplete: "onGetStateResponse"},
		{name: "SetStatus", kind: "DevModeService", method: "setStatus", onComplete: "onSetStateResponse"},
		{name: "EnableFpsCounter", kind: "enyo.PalmService", service: "luna://org.webosports.luna/", method: "setFpsCounter"}
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");
			return;
		}
		this.palm = true;
		this.$.GetStatus.send({});
	},
	/* Control handlers */
	onDevModeChanged: function(inSender, inEvent) {
		if (!this.palm) {
			this.$.DevModePanels.setIndex(inEvent.value ? 1 : 0);
			return;
		}
		this.$.SetStatus.send({"status": inEvent.value ? "enabled" : "disabled"});
	},
	onUsbDebuggingChanged: function(inSender, inEvent) {
		console.log("onUsbDebuggingChanged");
		if (!this.palm)
			return;
		this.$.SetStatus.send({"usbDebugging": inEvent.value ? "enabled" : "disabled"});
	},
	onFpsCounterChanged: function (inSender, inEvent) {
		console.log("onFpsCounterChanged");
		if (!this.palm)
			return;
		this.$.EnableFpsCounter.send({"status":inEvent.value ? "enabled" : "disabled"});
	},
	/* Service response handlers */
	onGetStatusResponse: function (inSender, inResponse) {
		var result = inResponse.data;
		console.log(JSON.stringify(result));
		if (result.status === "enabled") {
			this.$.DevModeToggle.setValue(true);
			this.$.DevModePanels.setIndex(1);
		}
		else {
			this.$.DevModeToggle.setValue(false);
			this.$.DevModePanels.setIndex(0);
		}

		this.$.UsbDebuggingToggle.setValue(result.usbDebugging === "enabled");
	},
	onSetStatusResponse: function(inSender, inEvent) {
		this.$.GetStatus({});
	}
});
