
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
				  onChange: "onDevModeChanged", value: false }
			]
		},
		{
			name: "DevModePanels",
			kind: "Panels",
			arrangerKind: "HFlipArranger",
			fit: true,
			draggable: false,
			index: 0, /* disabled by default */
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
								{kind: "onyx.Groupbox", components: [
									{kind: "onyx.GroupboxHeader", content: "Debugging"},
									{kind: "enyo.FittableColumns", classes: "group-item", components: [
											{kind: "Control", content: "USB debugging", style: "padding-top: 10px;"},
											{kind: "onyx.TooltipDecorator", fit: true, style:  "padding-top: 10px;", components: [
												{kind: "onyx.ToggleButton", name: "UsbDebuggingToggle", style: "float: right;", onChange: "onUsbDebuggingChanged"},
												{kind: "onyx.Tooltip", content: "USB debugging"}
											]},
										]},
										
										
										

								]},
	
								{kind: "onyx.Groupbox", components: [
									{kind: "onyx.GroupboxHeader", content: "Graphics"},
									{kind: "enyo.FittableColumns", classes: "group-item", components:[
										{kind: "Control", content: "Enable FPS counter", style: "padding-top: 10px;"},
										{kind: "onyx.TooltipDecorator", fit: true, style:  "padding-top: 10px;", components: [
											{name: "FpsCounterToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "onFpsCounterChanged"},
											{kind: "onyx.Tooltip", content: "Enable FPS counte"}
										]}
									]},		
									{ name: "ScreenOnGroup", kind: "enyo.FittableColumns", classes: "group-item", style: "word-wrap: break-word; height: 52px;", components:[
										{name: "ScreenOnUsb", content: "Screen is always on when USB is connected", style: "padding-top: 10px;" },
										{ style: "float: right; padding-top: 10px;", components: [
											{ name: "screenOffToggle", kind:"onyx.ToggleButton", onContent: "Yes", offContent: "No", classes: "onyx-toggle-button", onChange:"screenOffToggleChanged" },
										]}
									]},
								]}
							]
						}
					]
				}
			]
		},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
		{name: "GetStatus", kind: "DevModeService", method: "getStatus", onComplete: "onGetStatusResponse"},
		{name: "SetStatus", kind: "DevModeService", method: "setStatus", onComplete: "onSetStatusResponse"},
		{name: "EnableFpsCounter", kind: "enyo.PalmService", service: "luna://org.webosports.luna/", method: "setFpsCounter"},
		{name: "GetDisplayProperty", kind: "DisplayService", method: "getProperty", onComplete: "handleGetPropertiesResponse"},
		{name: "SetDisplayProperty", kind: "DisplayService", method: "setProperty" }
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");
			return;
		}
	
		this.$.GetDisplayProperty.send({properties: ["maximumBrightness", "timeout", "onWhenConnected"]});
		this.palm = true;
		this.$.GetStatus.send({});
	},
	reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
            this.$.Grabber.applyStyle("visibility", "hidden");
            this.$.DevModeDisabled.setStyle("padding: 35px 5% 35px 5%;");
            this.$.DevModeSettings.setStyle("padding: 35px 5% 35px 5%;");
			this.$.ScreenOnGroup.addStyles("height: 104px;");
			this.$.ScreenOnUsb.addStyles("max-width: 250px;");
		}else{
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },
    
	screenOffToggleChanged: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
	
		if(this.palm) {
			
			if(inEvent.value === true) {
				this.$.SetDisplayProperty.send({onWhenConnected: true});
			}else {
				this.$.SetDisplayProperty.send({onWhenConnected: false});
			}
		}else {
			enyo.log(parseInt(this.$.BrightnessSlider.value));
		}
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
		this.$.GetStatus.send({});
	},
	handleGetPropertiesResponse: function(inSender, inResponse) {
		enyo.log("Handling Get Properties Response");
		var result = inResponse.data;
		enyo.log(JSON.stringify(result));

		if(result.onWhenConnected !== undefined) {
			this.$.screenOffToggle.setValue(result.onWhenConnected);
		}
	}
});
