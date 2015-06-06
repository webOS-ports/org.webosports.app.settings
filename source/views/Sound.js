enyo.kind({
	name: "Sound",
	kind: "enyo.FittableRows",
	published: {},
	handlers: {
		onClose: "closePopup",
		onTone: "tonepicked"
	},
	palm: false,
	mute: false,
	keys: false,
	vibrate: false,
	system: false,
	systemVolume: 0,
	ringerVolume: 0,
	ringTone: "??",
	debug: false,
	components: [
		{kind: "onyx.Toolbar", layoutKind: "FittableColumnsLayout", classes: "onyx-toolbar", style: "line-height: 28px;", components: [
			{content: "Audio"},
		]},
		{kind: "Scroller", touch: true,	horizontal: "hidden", fit: true, components:[
			{name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
				{kind: "enyo.FittableRows", components: [
					{name: "AudioList", kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout", fit: true, components: [
						{kind: "onyx.GroupboxHeader", content: "Audio Settings"},
						
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{style: "padding-top: 0px;", content: "Volume "},
							{kind: "onyx.TooltipDecorator", style: "padding-top: 2.5px;", fit: true, components: [
								{name: "volumeSlider", kind: "onyx.Slider", value: "20", onChanging: "volumeChange"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", style: "padding-bottom: 1px;", components: [
							{fit: true, content: "Mute"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "muteToggle", kind: "onyx.ToggleButton", style: "float: right; ",
								 onChange: "muteChange"},
								{kind: "onyx.Tooltip", content: "Mute on/off"}
							]}
					
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", style: "padding-bottom: 1px;", components: [
							{fit: true, content: "Keyboard Clicks"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "keyClicksToggle", kind: "onyx.ToggleButton", style: "float: right; ", onChange: "keyClicks"},
								{kind: "onyx.Tooltip", content: "Keyboard Clicks on/off"}
							]}
					
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{name: "vibrate", fit: true, content: "Vibrate"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "vibrateToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "vib"},
								{kind: "onyx.Tooltip", content: "Keyboard Vibrate on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{fit: true, content: "System Sounds"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "systemSoundToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "systemSounds"},
								{kind: "onyx.Tooltip", content: "System sound  on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{content: "Ringer Volume ", style:  "padding-top: 0px;"},
							{kind: "onyx.TooltipDecorator", style: "padding-top: 2.5px;", fit: true, components: [
								{name:"ringerSlider", kind: "onyx.Slider", value: "20", onChanging: "ringerVolumeChange"}
							]}
						]},
						{ kind: "enyo.FittableColumns", classes: "group-item", style: "padding: 0px;", components: [
							{name: "ringerPicker", kind: "onyx.Button", fit: true,  content: "Ring tone Picker ", ontap: "ringerPopup"},
						]},
					]}
				]}
			]},
		]},
		{kind: "onyx.Toolbar", layoutKind: "FittableColumnsLayout", components: [
			{name: "Grabber", kind: "onyx.Grabber" }, // this is hacky
			{fit: true },
		]},
		{name: "ErrorPopup", kind: "onyx.Popup", classes: "error-popup", modal: true, style: "padding: 10px;", components: [
			{name: "ErrorMessage", content: "", style: "display: inline;"}
		]},
		{name: "ringPickerPopup", kind: "onyx.Popup", classes: "popup", centered: true, floating: true,	components: [
			{kind: "pickRingTones", style: "height: 100%; width: 100%;"},
		]},
		{name: "GetAudioStatus", kind: "enyo.LunaService", service: "luna://org.webosports.audio",
		 subscribe: true,
		 method: "getStatus", onComplete: "handleGetAudioStatusResponse"}
	],
	//Handlers
	create: function() {
		this.inherited(arguments);
		console.log ("Sound: created");
	
		if (!window.PalmSystem) {
			// If we're outside the webOS system add some entries for easier testing
			this.keys = true;
			this.vibrate = true;
			this.system = true;
			this.ringerVolume = 65;
			this.systemVolume = 45;
		}
		this.manage();
		if (!window.PalmSystem) {
			return;
		}
		this.log("AAA");
		this.$.GetAudioStatus.send({});
		this.log("BBB");
	},
	reflow: function (inSender) {
		this.inherited(arguments);
		if (enyo.Panels.isScreenNarrow()){
			this.$.Grabber.applyStyle("visibility", "hidden");
			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
		}else{
			this.$.Grabber.applyStyle("visibility", "visible");
			this.$.div.setStyle("padding: 35px 10% 35px 10%;");
		}
	},
	manage: function(){
		// Get every thing set up
		this.$.muteToggle.setValue(this.mute);
		this.$.keyClicksToggle.setValue(this.keys);
		this.$.vibrateToggle.setValue(this.vibrate);	
		this.$.systemSoundToggle.setValue(this.system);
		
		/* Set sliders too */
		this.$.volumeSlider.setValue(this.systemVolume);
		this.$.ringerSlider.setValue(this.ringerVolume);
	},
	//Action Functions
	ringerPopup: function(inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);	
		this.$.ringPickerPopup.show();
		this.$.ringPickerPopup.setShowing(true);
	},
	closePopup: function(inSender, inEvent){
		this.$.ringPickerPopup.hide();
	},
	tonepicked: function(inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);	
		this.$.ringerPicker.setContent("Ring tone -- " + inEvent);
	},
	keyClicks: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);

		console.log("key  value  true/false", inEvent.value);
		this.keys = inEvent.value;
	},
	vib: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);

		console.log("vibrate value  true/false", inEvent.value);
		this.vibrate = inEvent.value;
	},
	systemSounds: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);

		console.log("system value true/false", inEvent.value);
		this.system = inEvent.value;
	},
	volumeChange: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);

		console.log("system volume  value ", inEvent.value);
		this.systemVolume = inEvent.value;
	},
	ringerVolumeChange: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);

		console.log("ringer volume value ", inEvent.value);
		this.ringerVolume = inEvent.value;
	},
	//Service Callbacks
	handleGetAudioStatusResponse: function(inSender, inResponse) {
		this.log("At least we got called");
		if (inResponse.volume != undefined) {
			this.log("Setting volume to " + inResponse.volume);
			this.systemVolume = inResponse.volume;
			this.$.volumeSlider.setValue(this.systemVolume);
		}
	}
});
