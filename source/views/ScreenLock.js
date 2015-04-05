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
	// onyx.Picker onChange always gets called twice
	// but we only want to act once.
	actOnChange_displayTimeoutPicker: false,
	actOnChange_lockTimeoutPicker: false,
	actOnChange_lockModePicker: false,
	components:[
		{kind: "onyx.Toolbar",
		style: "line-height: 36px;",
		components:[
				{content: "Screen & Lock"},
		]},
		{name: "ImagePicker", kind: "FilePicker", fileType:["image"], onPickFile: "selectedImageFile", autoDismiss: true},
		{name: "LockPasswordSetter", kind: "enyo.ModalDialog",
		 components: [
			 {content: "Set Password"},
			 {name: "setPwdErrMsg", content: ""},
			 {kind: "onyx.Input", type: "password",
			  placeholder: $L("Enter password")},
			 {tag: "br"},
			 {kind: "onyx.Input", type: "password",
			  placeholder: $L("Confirm password")},
			 {tag: "br"},
			 {kind: "onyx.Button", content: "Done"},
			 {tag: "br"},
			 {kind: "onyx.Button", content: "Cancel"}
		 ]},
		{name: "LockPasswordUnlocker", kind: "enyo.ModalDialog",
		 components: [
			 {content: "Enter Password"},
			 {name: "enterPwdErrMsg", content: ""},
			 {kind: "onyx.Input", type: "password",
			  placeholder: $L("Enter password")},
			 {tag: "br"},
			 {kind: "onyx.Button", content: "Done"},
			 {tag: "br"},
			 {kind: "onyx.Button", content: "Cancel"}
		 ]},
		{name: "PINPad", kind: "enyo.ModalDialog",
		 components: [
			 {name: "instruction", content: "Enter PIN"},
			 {name: "pinPadErrMsg", content: ""},
			 {name: "digits", content: ""},
			 {kind: "PINNumberPad"},
			 {kind: "onyx.Button", content: "Cancel"},
			 {kind: "onyx.Button", content: "Done"}
		 ]},
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
							{name: "TimeoutPicker", kind: "onyx.Picker", onChange: "displayTimeoutChanged", components: [
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
								{name: "LockAfterPicker", kind: "onyx.Picker", onChange: "lockTimeoutChanged", components: [
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
		{name: "GetSystemPreferences", kind: "SystemService", method: "getPreferences", onComplete: "handleGetPreferencesResponse"},
		{name: "SetSystemPreferences", kind: "SystemService", method: "setPreferences"},
		{name: "ImportWallpaper", kind: "enyo.LunaService", service: "luna://com.palm.systemservice/wallpaper", method: "importWallpaper", onComplete: "handleImportWallpaper"},
		{name: "GetDeviceLockMode", kind: "enyo.LunaService", service: "luna://com.palm.systemmanager",
		 method: "getDeviceLockMode", onComplete: "handleGetDeviceLockModeResponse"}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);

		if(!window.PalmSystem) {
			this.log("Non-palm platform, service requests disabled.");
			return;
		}

		this.$.GetDisplayProperty.send({properties: ["maximumBrightness", "timeout"]});
		this.$.GetSystemPreferences.send({keys: ["showAlertsWhenLocked", "BlinkNotifications",
		                                         "lockTimeout"]});
		this.$.GetDeviceLockMode.send({});

		this.palm = true;
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
		} else {
			this.$.Grabber.applyStyle("visibility", "visible");
		}
	},
 	//Action Handlers
	brightnessChanged: function(inSender, inEvent) {
		var v = parseInt(this.$.BrightnessSlider.value, 10);
		if(this.palm) {
			this.$.SetDisplayProperty.send({maximumBrightness: v});
			this.log("Set brightness " + v + " sent");
		} else {
			this.log("Set brightness " + v + " suppressed");
		}
	},
	displayTimeoutChanged: function(inSender, inEvent) {
		// <bad_smell>
		// This is always called twice.
		// Only act on the second call.
		// </bad_smell>
		var t;
		if (this.actOnChange_displayTimeoutPicker) {
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
				this.log("Set " + t + "s sent");
			} else {
				this.log("Set " + t + "s suppressed");
			}
		}
		this.actOnChange_displayTimeoutPicker = !this.actOnChange_displayTimeoutPicker;
	},
	openWallpaperPicker: function() {
		this.$.ImagePicker.pickFile();
	},
	lockModePicked: function(inSender, inEvent) {
		// Needed because this gets called (because we send() in create())
		// before the padlock is defined
		if (this.$.padlock) {
			// <bad_smell>
			// This is always called twice.
			// Only act on the second call.
			// </bad_smell>
			if (this.actOnChange_lockModePicker) {
				switch(inEvent.selected.content) {
				case "Off":
					this.$.padlock.setStyle("height: 33px; opacity: 0;");
					this.$.LockCodeUpdateControl.setShowing(false);
					this.$.LockAfterPickerRow.setShowing(false);
					break;
				case "Simple PIN":
					this.$.padlock.setStyle("height: 33px; opacity: 1;");
					this.$.LockCodeUpdateControl.setContent("Change PIN");
					this.$.LockCodeUpdateControl.setShowing(true);
					this.$.LockAfterPickerRow.setShowing(true);
					break;
				case "Password":
					this.$.padlock.setStyle("height: 33px; opacity: 1;");
					this.$.LockCodeUpdateControl.setContent("Change Password");
					this.$.LockCodeUpdateControl.setShowing(true);
					this.$.LockAfterPickerRow.setShowing(true);
					break;
				}
				
				if(this.palm) {
				} else {
				}
			}
			this.actOnChange_lockModePicker = !this.actOnChange_lockModePicker;
		}
	},
	lockTimeoutChanged: function(inSender, inEvent) {
		// <bad_smell>
		// This is always called twice.
		// Only act on the second call.
		// </bad_smell>
		var t;
		if (this.actOnChange_lockTimeoutPicker) {
			switch(inEvent.selected.content) {
			case "Screen turns off":
				t = 0;
				break;
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
			case "5 minutes":
				t = 300;
				break;
			case "10 minutes":
				t = 600;
				break;
			case "30 minutes":
				t = 1800;
				break;
			}
			if(this.palm) {
				this.$.SetSystemPreferences.send({lockTimeout:t});
				this.log("Set " + t + "s sent");
			} else {
				this.log("Set " + t + "s suppressed");
			}
		}
		this.actOnChange_lockTimeoutPicker = !this.actOnChange_lockTimeoutPicker;
	},
	updateLockCode: function(inSender, inEvent) {
		// Update PIN or password as appropriate
//		this.$.LockPasswordSetter.openAtCenter();
		this.$.PINPad.openAtCenter();
	},
	lockAlertsChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({showAlertsWhenLocked: inSender.value});
			this.log("Set showAlertsWhenLocked " + inSender.value + " sent");
		} else {
			this.log("Set showAlertsWhenLocked " + inSender.value + " suppressed");
		}
	},
	blinkNotificationsChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({BlinkNotifications: inSender.value});
			this.log("Set BlinkNotifications " + inSender.value + " sent");
		} else {
			this.log("Set BlinkNotifications " + inSender.value + " suppressed");
		}
	},
	selectedImageFile: function(inSender, inEvent) {
		if(!inEvent || inEvent.length === 0)
			return;
		var params = {"target": encodeURIComponent(inEvent[0].fullPath)};
		
		/*var cropInfoWindow = inEvent[0].cropInfo;
		
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
		// Set our controls to match the values in the response.

		var newIx;
		var newSel;

		if(inResponse.maximumBrightness != undefined) {
			this.$.BrightnessSlider.silence();
			this.$.BrightnessSlider.setValue(inResponse.maximumBrightness);
			this.$.BrightnessSlider.unsilence();
		}
			
		if(inResponse.timeout != undefined) {
			if(inResponse.timeout == 30) {
				newIx = 0;
			} else if(inResponse.timeout == 60) {
				newIx = 1;
			} else if(inResponse.timeout == 120) {
				newIx = 2;
			} else if(inResponse.timeout == 180) {
				newIx = 3;
			}
			if (typeof newIx !== "undefined") {
				newSel = this.$.TimeoutPicker.getClientControls()[newIx];
				this.$.TimeoutPicker.silence();
				this.$.TimeoutPicker.setSelected(newSel);
				this.$.TimeoutPicker.unsilence();
			}
		}
	},
	handleGetPreferencesResponse: function(inSender, inResponse) {
		// Set our controls to match the values in the response.

		var newIx;
		var newSel;
		if(inResponse.showAlertsWhenLocked != undefined) {
			this.$.AlertsToggle.silence();
			this.$.AlertsToggle.setValue(inResponse.showAlertsWhenLocked);
			this.$.AlertsToggle.unsilence();
		}
		if(inResponse.BlinkNotifications != undefined) {
			this.$.BlinkToggle.silence();
			this.$.BlinkToggle.setValue(inResponse.BlinkNotifications);
			this.$.BlinkToggle.unsilence();
		}
		if(inResponse.lockTimeout != undefined) {
			switch(inResponse.lockTimeout) {
			case 0:
				newIx = 0;
				break;
			case 30:
				newIx = 1;
				break;
			case 60:
				newIx = 2;
				break;
			case 120:
				newIx = 3;
				break;
			case 180:
				newIx = 4;
				break;
			case 300:
				newIx = 5;
				break;
			case 600:
				newIx = 6;
				break;
			case 1800:
				newIx = 7;
				break;
			default:
				this.log("Unknown lock timeout: " + inResponse.lockTimeout + "s");
				break;
			}
			if (typeof newIx !== "undefined") {
				newSel = this.$.LockAfterPicker.getClientControls()[newIx];
				this.$.LockAfterPicker.silence();
				this.$.LockAfterPicker.setSelected(newSel);
				this.$.LockAfterPicker.unsilence();
			}
		} else {
			this.log("Lock timeout is undefined");
		}
	},
	handleGetDeviceLockModeResponse: function(inSender, inResponse) {
		// Set our controls to match the values in the response.

		var newIx;
		var newSel;

		if (!inResponse.returnValue) {
			this.log("Failed to get the device lock mode");
		} else {
			switch(inResponse.lockMode) {
			case "none":
				newIx = 0;
				break;
			case "pin":
				newIx = 1;
				break;
			case "password":
				newIx = 2;
				break;
			default:
				this.log("Unknown lockMode: " + inResponse.lockMode);
				break;
			}
			if (typeof newIx !== "undefined") {
				newSel = this.$.LockModePicker.getClientControls()[newIx];
				this.$.LockModePicker.silence();
				this.$.LockModePicker.setSelected(newSel);
				this.$.LockModePicker.unsilence();
			}
		}
	},
	handleImportWallpaper: function(inSender, inResponse) {
		if(inResponse.wallpaper) {
			this.$.SetSystemPreferences.send({wallpaper: inResponse.wallpaper});
		}
	}
});
