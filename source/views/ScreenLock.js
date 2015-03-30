enyo.kind({
	kind: "enyo.LunaService",
	name: "DisplayService",
	service: "luna://com.palm.display/control"
});

enyo.kind({
	kind: "enyo.LunaService",
	name: "SystemService",
	service: "luna://com.palm.systemservice"
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
		{name: "ImagePicker", kind: "FilePicker", fileType:["image"], onPickFile: "selectedImageFile", autoDismiss: true},
		{kind: "Scroller",
		touch: true,
		horizontal: "hidden",
		fit: true,
		components:[
			{name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", components: [
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Screen"},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Brightness", style:  "padding-top: 10px;"},
						{ kind: "onyx.TooltipDecorator", fit: true, style: "padding-top: 15px;", components: [
							{name: "BrightnessSlider", kind: "onyx.Slider", onChange: "brightnessChanged", onChanging: "brightnessChanged"}
						]},
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Turn off after"},
						{kind: "onyx.PickerDecorator", fit: true, style: "float: right; min-width: 125px;", components: [
							{},
							{name: "TimeoutPicker", kind: "onyx.Picker", onChange: "timeoutChanged", components: [
								{content: "30 seconds", active: true},
								{content: "1 minute"},
								{content: "2 minutes"},
								{content: "3 minutes"}
							]}
						]}
					]},
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Wallpaper"},
					{classes: "group-item",
					style: "padding: 5;",
					components:[
						{kind: "onyx.Button", style: "width: 95%;", content: "Change Wallpaper", ontap: "openWallpaperPicker"},
					]},
				]},
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
				{kind: "onyx.Groupbox", name: "lockModeGroup", components: [
					{kind: "onyx.GroupboxHeader", content: "Secure Unlock"},
					{kind: "enyo.FittableRows", components:[
						{kind: "enyo.FittableColumns", classes: "group-item",
						 components:[
							 {kind: "onyx.PickerDecorator", fit: true,
							  components: [
								  {},
								  {name: "LockModePicker", kind: "onyx.Picker",
								   onChange: "lockModePicked", components: [
									   {content: "Off", active: true},
									   {content: "Simple PIN"},
									   {content: "Password"}
								   ]}
							  ]},
							 {name: "padlock", kind: "Image",
							  src: "assets/secure-icon.png",
							  style: "height: 33px; opacity: 0;"
							 }
						 ]},
						{name: "LockCodeUpdateControl", content: "", classes: "group-item",
						 ontap: "updateLockCode", showing: false},
						{name: "LockAfterPickerRow", kind: "enyo.FittableColumns", classes: "group-item",
						 showing: false, components: [
							{content: "Lock after"},
							{kind: "onyx.PickerDecorator", fit: true, style: "float: right; min-width: 125px;", components: [
								{},
								{name: "LockAfterPicker", kind: "onyx.Picker", onChange: "timeoutChanged", components: [
									{content: "Screen turns off", active: true},
									{content: "30 seconds"},
									{content: "1 minute"},
									{content: "2 minutes"},
									{content: "3 minutes"},
									{content: "5 minutes"},
									{content: "10 minutes"},
									{content: "30 minutes"}
								]}
							]}
						]}
					]}
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Notifications"},
					{kind: "enyo.FittableColumns", classes: "group-item", components:[
						{kind: "Control", fit: true, content: "Show When Locked"},
						{kind: "onyx.TooltipDecorator", fit: true, components: [
							{name: "AlertsToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "lockAlertsChanged"},
							{kind: "onyx.Tooltip", content: "Blinks the LED when new notifications arrive."}
						]},
					]},
					{kind: "enyo.FittableColumns", classes: "group-item",components:[
						{kind: "Control", fit: true, content: "Blink Notifications"},
						{kind: "onyx.TooltipDecorator", fit: true, components: [
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
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
		{name: "GetDisplayProperty", kind: "DisplayService", method: "getProperty", onComplete: "handleGetPropertiesResponse"},
		{name: "SetDisplayProperty", kind: "DisplayService", method: "setProperty" },
		{name: "GetSystemPreferences", kind: "SystemService", method: "getPreferences", onComplete: "handleGetPropertiesResponse"},
		{name: "SetSystemPreferences", kind: "SystemService", method: "setPreferences"},
		{name: "ImportWallpaper", kind: "enyo.LunaService", service: "luna://com.palm.systemservice/wallpaper", method: "importWallpaper", onComplete: "handleImportWallpaper"}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);

		if(!window.PalmSystem) {
			this.log("Non-palm platform, service requests disabled.");
			return;
		}

		this.$.GetDisplayProperty.send({properties: ["maximumBrightness", "timeout"]});
		this.$.GetSystemPreferences.send({keys: ["showAlertsWhenLocked", "BlinkNotifications"]});

		this.palm = true;
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
		}
		else {
			this.$.Grabber.applyStyle("visibility", "visible");
		}
	},
 	//Action Handlers
	brightnessChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetDisplayProperty.send({maximumBrightness: parseInt(this.$.BrightnessSlider.value, 10)});
		}
		else {
			this.log(parseInt(this.$.BrightnessSlider.value, 10));
		}
	},
	timeoutChanged: function(inSender, inEvent) {
		var t;
		
		switch(inEvent.selected.content) {
			case "30 seconds":
				t = 30;
				break;
			case "1 minute":
				t = 60;
				break;
			case "2 minutes":
				t = 120;
				break;
			case "3 minutes":
				t = 180;
				break;
		}
		
		if(this.palm) {
			this.$.SetDisplayProperty.send({timeout:t});
		}
		else {
			this.log(t);
		}
	},
	openWallpaperPicker: function() {
		this.$.ImagePicker.pickFile();
	},
	lockModePicked: function(inSender, inEvent) {
		switch(inEvent.selected.content) {
		case "Off":
			if (this.$.padlock) {
				this.$.padlock.setStyle("height: 33px; opacity: 0;");
				this.$.LockCodeUpdateControl.setShowing(false);
				this.$.LockAfterPickerRow.setShowing(false);
			}
			break;
		case "Simple PIN":
			if (this.$.padlock) {
				this.$.padlock.setStyle("height: 33px; opacity: 1;");
				this.$.LockCodeUpdateControl.setContent("Change PIN");
				this.$.LockCodeUpdateControl.setShowing(true);
				this.$.LockAfterPickerRow.setShowing(true);
			}
			break;
		case "Password":
			if (this.$.padlock) {
				this.$.padlock.setStyle("height: 33px; opacity: 1;");
				this.$.LockCodeUpdateControl.setContent("Change Password");
				this.$.LockCodeUpdateControl.setShowing(true);
				this.$.LockAfterPickerRow.setShowing(true);
			}
			break;
		}
		
		if(this.palm) {
		}
		else {
		}
	},
	updateLockCode: function(inSender, inEvent) {
		// Update PIN or password as appropriate
	},
	lockAlertsChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({showAlertsWhenLocked: inSender.value});
		}
		else {
			this.log(inSender.value);
		}
	},
	blinkNotificationsChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({BlinkNotifications: inSender.value});
		}
		else {
			this.log(inSender.value);
		}
	},
	selectedImageFile: function(inSender, response) {
		if(!response || response.length === 0)
			return;
		var params = {"target": encodeURIComponent(response[0].fullPath)};
		
		/*var cropInfoWindow = response[0].cropInfo;
		
		if(cropInfoWindow) {
			if(cropInfoWindow.scale)
				params["scale"] = cropInfoWindow.scale;
			
			if(cropInfoWindow.focusX)
				params["focusX"] = cropInfoWindow.focusX;
			
			if(cropInfoWindow.focusY)
				params["focusY"] = cropInfoWindow.focusY;
		}*/

		this.$.ImportWallpaper.send(params);
	},

	//Service Callbacks
	handleGetPropertiesResponse: function(inSender, inResponse) {
		this.log("Handling Get Properties Response", inResponse);
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
	pickWallpaper: function(inSender, inResponse) {
		var wallpaperPath = "file:///usr/share/wallpapers/";
		this.$.ImportWallpaper.send({"target": wallpaperPath + inSender.filename});

	},
	handleImportWallpaper: function(inSender, inResponse) {
		if(inResponse.wallpaper) {
			this.$.SetSystemPreferences.send({wallpaper: inResponse.wallpaper});
		}
	},

});
