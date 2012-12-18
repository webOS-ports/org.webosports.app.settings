enyo.kind({
	name: "DisplayControlService",
	kind: "enyo.webOS.ServiceRequest",
	service: "palm://com.palm.display/control/"
});

enyo.kind({
	name: "PreferenceService",
	kind: "enyo.webOS.ServiceRequest",
	service: "palm://com.palm.systemservice/"
});

enyo.kind({
	name: "ScreenLock",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{kind: "onyx.Toolbar",
		style: "line-height: 36px;",
		components:[
				{content: "Screen & Lock"},
		]},
		{kind: "Scroller",
		touch: true,
		horizontal: "hidden",
		fit: true,
		components:[
			{tag: "div", style: "padding: 35px 10% 35px 10%;", components: [
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Screen"},
					{classes: "group-item",
					components:[
						{content: "Brightness"},
						{name: "BrightnessSlider", kind: "onyx.Slider", onChange: "brightnessChanged", onChanging: "brightnessChanged"}
					]},
					{classes: "group-item",
					style: "height: 42px;",
					components:[
						{content: "Turn off after",
						fit: true,
						style: "display: inline-block; line-height: 42px;"},
						{kind: "onyx.PickerDecorator", style: "float: right;", components: [
							{},
							{name: "TimeoutPicker", kind: "onyx.Picker", onChange: "timeoutChanged", components: [
								{content: "30 Seconds", active: true},
								{content: "1 Minute"},
								{content: "2 Minutes"},
								{content: "3 Minutes"}
							]}
						]}
					
					]},
				]},
				/* Disabled until we have a wallpaper chooser
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Wallpaper"},
					{classes: "group-item",
					components:[
						{kind: "onyx.Button", fit: true, content: "Change Wallpaper"}
					
					]},
				]},
				*/
				/* Disabled because the preference isn't returning anything (and it's standard functionality now)
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Advanced Gestures"},
					{classes: "group-item",
					components:[
						{kind: "onyx.TooltipDecorator", components: [
							{kind: "Control",
							content: "Switch Applications",
							style: "display: inline-block; line-height: 32px;"},
							{kind: "onyx.ToggleButton", style: "float: right;"},
							{kind: "onyx.Tooltip",
							content: "Swiping from the right or left edge of the gesture area will switch to the next or previous app."}
						]},
					
					]},
				]},
				*/
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Notifications"},
					{classes: "group-item",
					components:[
						{kind: "Control",
						content: "Show When Locked",
						style: "display: inline-block; line-height: 32px;"},
						{name: "AlertsToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "lockAlertsChanged"},
					]},
					{classes: "group-item",
					components:[
						{kind: "onyx.TooltipDecorator", components: [
							{kind: "Control",
							content: "Blink Notifications",
							style: "display: inline-block; line-height: 32px;"},
							{name: "BlinkToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "blinkNotificationsChanged"},
							{kind: "onyx.Tooltip", content: "Blinks the LED when new notifications arrive."}
						]},
					]},
				]},
				/* Disabled until A. We have voice dialing and B. I figure out what preference it uses
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Voice Dialing"},
					{classes: "group-item",
					components:[
						{kind: "onyx.TooltipDecorator", components: [
							{kind: "Control",
							content: "Enable When Locked",
							style: "display: inline-block; line-height: 32px;"},
							{kind: "onyx.ToggleButton", style: "float: right;"},
							{kind: "onyx.Tooltip", content: "Access voice dialing even when your phone is locked."}
						]}
					]},
				]},
				*/
			]},
		]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"}
		]}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		try {
			//Subscribe to the connection status service
			var getProperties = new DisplayControlService({method: "getProperty"});
			getProperties.response(this, "handleGetPropertiesResponse");
			getProperties.go({properties: ["maximumBrightness", "timeout"]});
			
			var getPreferences = new PreferenceService({method: "getPreferences"});
			getPreferences.response(this, "handleGetPreferencesResponse");
			getPreferences.go({keys: ["showAlertsWhenLocked", "BlinkNotifications"]});
			
			this.palm = true;
		}
		catch(e) {
			enyo.log("Non-palm platform, service requests disabled.");
		}
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
		}
		else {
			this.$.Grabber.applyStyle("visibility", "visible");
		}
	},
	//Action Handlers
	brightnessChanged: function(inSender, inEvent) {
		if(this.palm) {
			var setProperty = new DisplayControlService({method: "setProperty"});
			//setProperty.response(this, "handleSetPropertyResponse");
			setProperty.go({maximumBrightness: parseInt(this.$.BrightnessSlider.value)});
		}
		else {
			enyo.log(parseInt(this.$.BrightnessSlider.value));
		}
	},
	timeoutChanged: function(inSender, inEvent) {
		var t;
		
		switch(inEvent.selected.content) {
			case "30 Seconds":
				t = 30;
				break;
			case "1 Minute":
				t = 60;
				break;
			case "2 Minutes":
				t = 120;
				break;
			case "3 Minutes":
				t = 180;
				break;
		}
		
		if(this.palm) {
			var setProperty = new DisplayControlService({method: "setProperty"});
			//setProperty.response(this, "handleSetPropertyResponse");
			setProperty.go({timeout: t});
		}
		else {
			enyo.log(t);
		}
	},
	lockAlertsChanged: function(inSender, inEvent) {
		if(this.palm) {
			var setProperty = new PreferenceService({method: "setPreferences"});
			//setProperty.response(this, "handleSetPropertyResponse");
			setProperty.go({showAlertsWhenLocked: inSender.value});
		}
		else {
			enyo.log(inSender.value);
		}
	},
	blinkNotificationsChanged: function(inSender, inEvent) {
		if(this.palm) {
			var setProperty = new PreferenceService({method: "setPreferences"});
			//setProperty.response(this, "handleSetPropertyResponse");
			setProperty.go({BlinkNotifications: inSender.value});
		}
		else {
			enyo.log(inSender.value);
		}
	},
	//Service Callbacks
	handleGetPropertiesResponse: function(inSender, inResponse) {
		if(inResponse.maximumBrightness != undefined)
			this.$.BrightnessSlider.setValue(inResponse.maximumBrightness);
			
		if(inResponse.timeout != undefined) {
			if(inResponse.timeout == 30)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[0]);
			if(inResponse.timeout == 60)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[1]);
			if(inResponse.timeout == 120)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[2]);
			if(inResponse.timeout == 180)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[3]);
		}
	},
	handleGetPreferencesResponse: function(inSender, inResponse) {
		if(inResponse.showAlertsWhenLocked != undefined)
			this.$.AlertsToggle.setValue(inResponse.showAlertsWhenLocked);
			
		if(inResponse.BlinkNotifications != undefined)
			this.$.BlinkToggle.setValue(inResponse.BlinkNotifications);
	},
});
