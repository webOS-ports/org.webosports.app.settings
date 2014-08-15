enyo.kind({
	kind: "enyo.PalmService",
	name: "DisplayService",
	service: "luna://com.palm.display/control"
});

enyo.kind({
	kind: "enyo.PalmService",
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
		/* {name: "ImagePicker", kind: "FilePicker", fileType:["image"], onPickFile: "selectedImageFile", autoDismiss: true}, */
		{kind: "Scroller",
		touch: true,
		horizontal: "hidden",
		fit: true,
		components:[
			{tag: "div", style: "padding: 35px 10% 35px 10%;", components: [
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Screen"},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Brightness", style:  "padding-top: 10px;",},
						{ kind: "onyx.TooltipDecorator", fit: true, style: "padding-top: 15px;", components: [
							{name: "BrightnessSlider", kind: "onyx.Slider", onChange: "brightnessChanged", onChanging: "brightnessChanged"}
						]},
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Turn off after",	style: "padding-top: 10px;"},
						{kind: "onyx.PickerDecorator", fit: true, style: " padding-top: 12px; float: right;", components: [
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
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Wallpaper"},
					{classes: "group-item",
					style: "padding: 0; height: 212px; background-color: red",
					components:[
						/* {kind: "onyx.Button", style: "width: 100%;", content: "Change Wallpaper", ontap: "openWallpaperPicker"}, */
						{kind: "enyo.Scroller",
						touch: true,
						horizontal: "hidden",
						style: "width: 100%; height: 212px;",
						components: [
							{style: "width: 100%;",
							defaultKind: enyo.kind({
								kind: "ListItem",
								title: "",
								filename: "",
								style: "margin: 0;",
								ontap: "pickWallpaper"
							}),
							components: [
								{title: "Blue Rocks", filename: "bluerocks.png"},
								{title: "Bubbles", filename: "bubbles.png"},
								{title: "Butterfly", filename: "butterfly.png"},
								{title: "Dew", filename: "plant.png"},
								{title: "Flowers", filename: "flowers.png"},
								{title: "Ice Plant", filename: "iceplant.png"},
								{title: "Ice Veins", filename: "iceveins.png"},
								{title: "Milky Way", filename: "milkyway.png"},
								{title: "Moonrise", filename: "moonrise.png"},
								{title: "Orange Sunset", filename: "orangesunset.png"},
								{title: "Snow Tracks", filename: "snowtracks.png"},
								{title: "Wyoming", filename: "wyoming.png"},
							]}
						]}
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
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Notifications"},
					{kind: "enyo.FittableColumns", classes: "group-item", components:[
						{kind: "Control",  fit: true, content: "Show When Locked", style: "padding-top: 10px;"},
						{kind: "onyx.TooltipDecorator", fit: true, style:  "padding-top: 10px;", components: [
							{name: "AlertsToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "lockAlertsChanged"},
							{kind: "onyx.Tooltip", content: "Blinks the LED when new notifications arrive."}
						]},
					]},
					{kind: "enyo.FittableColumns", classes: "group-item",components:[
						{kind: "Control", fit: true, content: "Blink Notifications", style:  "padding-top: 10px;" },
						{kind: "onyx.TooltipDecorator", fit: true, style:  "padding-top: 10px;", components: [
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
		{name: "ImportWallpaper", kind: "enyo.PalmService", service: "luna://com.palm.systemservice/wallpaper", method: "importWallpaper", onComplete: "handleImportWallpaper"}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);

		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");
			return
		}

		this.$.GetDisplayProperty.send({properties: ["maximumBrightness", "timeout"]});
		this.$.GetSystemPreferences.send({keys: ["showAlertsWhenLocked", "BlinkNotifications"]});

		this.palm = true;
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
			this.$.SetDisplayProperty.send({maximumBrightness: parseInt(this.$.BrightnessSlider.value)});
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
			this.$.SetDisplayProperty.send({timeout:t});
		}
		else {
			enyo.log(t);
		}
	},
	openWallpaperPicker: function() {
		this.$.ImagePicker.pickFile();
	},
	lockAlertsChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({showAlertsWhenLocked: inSender.value});
		}
		else {
			enyo.log(inSender.value);
		}
	},
	blinkNotificationsChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({BlinkNotifications: inSender.value});
		}
		else {
			enyo.log(inSender.value);
		}
	},
	selectedImageFile: function(inSender, response) {
		if(response && response.length == 0)
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
		enyo.log("Handling Get Properties Response");
		var result = inResponse.data;
		enyo.log(JSON.stringify(result));
		if(result.maximumBrightness != undefined)
			this.$.BrightnessSlider.setValue(result.maximumBrightness);
			
		if(result.timeout != undefined) {
			if(result.timeout == 30)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[0]);
			if(result.timeout == 60)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[1]);
			if(result.timeout == 120)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[2]);
			if(result.timeout == 180)
				this.$.TimeoutPicker.setSelected(this.$.TimeoutPicker.getClientControls()[3]);
		}
	},
	handleGetPreferencesResponse: function(inSender, inResponse) {
		var result = inResponse.data;
		if(result.showAlertsWhenLocked != undefined)
			this.$.AlertsToggle.setValue(result.showAlertsWhenLocked);
		if(result.BlinkNotifications != undefined)
			this.$.BlinkToggle.setValue(result.BlinkNotifications);
	},
	pickWallpaper: function(inSender, inResponse) {
		var wallpaperPath = "file:///usr/lib/luna/system/luna-systemui/images/wallpapers/";
		this.$.ImportWallpaper.send({"target": wallpaperPath + inSender.filename});

	},
	handleImportWallpaper: function(inSender, inResponse) {
		var result = inResponse.data;
		if(result.wallpaper) {
			this.$.SetSystemPreferences.send({wallpaper: result.wallpaper});
		}
	},

});
