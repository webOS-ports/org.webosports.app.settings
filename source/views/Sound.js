enyo.kind({
	name: "Sound",
	kind: "enyo.FittableRows",
	published: {},
	events: {
		onMuteChanged: ""
	},
	palm: false,
	mute: false,
	keys: false,
	vibrate: false,
	micMute: false,
	system: false,
	systemVolume: 0,
	ringerVolume: 0,
	components: [
		{kind: "onyx.Toolbar", layoutKind: "FittableColumnsLayout",
		 classes: "onyx-toolbar", style: "line-height: 28px;", components: [
			 {content: "Sound & Ringtones"}, // This is hacky
			 {fit: true},
			 {content: "Mute"},
			 {name: "muteToggle",
			  kind: "onyx.ToggleButton",
			  onChange: "muteToggleChanged",
			  showing: "true",
			  style: "height: 31px;"}
		 ]},
		{name: "tonePicker", kind: "FilePicker", fileType:["ringtone"], onPickFile: "tonePicked", autoDismiss: true},
		{kind: "Scroller", touch: true,	horizontal: "hidden", fit: true, components:[
			{name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
				{kind: "enyo.FittableRows", components: [
					{name: "AudioList", kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout", fit: true, components: [
						{kind: "onyx.GroupboxHeader", content: "Audio Settings"},
						
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{style: "padding-top: 0px;", content: "Volume "},
							{kind: "onyx.TooltipDecorator", style: "padding-top: 2.5px;", fit: true, components: [
								{name: "volumeSlider", kind: "onyx.Slider",
								 onChange: "volumeChange"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", style: "padding-bottom: 1px;", components: [
							{fit: true, content: "Keyboard Clicks"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "keyClicksToggle", kind: "onyx.ToggleButton", style: "float: right;",
								 disabled: true, onChange: "keyClicks"},
								{kind: "onyx.Tooltip", content: "Keyboard Clicks on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{fit: true, content: "Vibrate"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "vibrateToggle", kind: "onyx.ToggleButton", style: "float: right;",
								 disabled: true, onChange: "vib"},
								{kind: "onyx.Tooltip", content: "Keyboard Vibrate on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{fit: true, content: "Mic Mute"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "micMuteToggle", kind: "onyx.ToggleButton", style: "float: right;",
								 onChange: "micMuteToggleChanged"},
								{kind: "onyx.Tooltip", content: "Mic mute on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{fit: true, content: "System Sounds"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "systemSoundToggle", kind: "onyx.ToggleButton", style: "float: right;",
								 disabled: true, onChange: "systemSounds"},
								{kind: "onyx.Tooltip", content: "System sound on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{content: "Ringer Volume ", style:  "padding-top: 0px;"},
							{kind: "onyx.TooltipDecorator", style: "padding-top: 2.5px;", fit: true, components: [
								{name:"ringerSlider", kind: "onyx.Slider",
								 disabled: true, onChanging: "ringerVolumeChange"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", style: "padding: 0px;", components: [
							{name: "ringerPicker", kind: "onyx.Button", fit: true,
							 content: "Ringtone Picker", ontap: "pickATone"},
						]}
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
		{name: "GetAudioStatus", kind: "enyo.LunaService", service: "luna://org.webosports.service.audio",
		 subscribe: true,
		 method: "getStatus", onComplete: "handleGetAudioStatusResponse"},
		{name: "SetMute", kind: "enyo.LunaService", service: "luna://org.webosports.service.audio",
		 method: "setMute"},
		{name: "SetVolume", kind: "enyo.LunaService", service: "luna://org.webosports.service.audio",
		 method: "setVolume"},
		{name: "SetMicMute", kind: "enyo.LunaService", service: "luna://org.webosports.service.audio",
		 method: "setMicMute"},
		{name: "GetSystemPreferences", kind: "SystemService", method: "getPreferences",
		 onComplete: "handleGetPreferencesResponse", subscribe: true},
		{name: "SetSystemPreferences", kind: "SystemService", method: "setPreferences"}
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
			this.showState();
			return;
		}
		this.palm = true;
		this.$.GetAudioStatus.send({});
		this.$.GetSystemPreferences.send({"keys": ["ringtone"]});
	},
	reflow: function (inSender) {
		this.inherited(arguments);
		if (enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
		} else {
			this.$.Grabber.applyStyle("visibility", "visible");
			this.$.div.setStyle("padding: 35px 10% 35px 10%;");
		}
	},
	showState: function() {
		this.$.muteToggle.setValue(this.mute);
		this.$.keyClicksToggle.setValue(this.keys);
		this.$.vibrateToggle.setValue(this.vibrate);
		this.$.systemSoundToggle.setValue(this.system);
		this.$.volumeSlider.setValue(this.systemVolume);
		this.$.ringerSlider.setValue(this.ringerVolume);
	},
	//Action Functions
	setMuteToggleValue: function(value) {
		this.$.muteToggle.setValue(value);
	},
	muteToggleChanged: function(inSender, inEvent) {
		this.mute = inEvent.value;
		if (this.palm) {
			this.$.SetMute.send({mute: this.mute});
		}
		this.doMuteChanged({mute: this.mute});
	},
	pickATone: function(inSender, inEvent) {
		this.$.tonePicker.pickFile();
	},
	tonePicked: function(inSender, inEvent) {
		if(!inEvent || inEvent.length === 0)
			return;
		this.$.SetSystemPreferences.send({"ringtone": inEvent[0]});
	},
	keyClicks: function(inSender, inEvent) {
		this.keys = inEvent.value;
	},
	vib: function(inSender, inEvent) {
		this.vibrate = inEvent.value;
	},
	micMuteToggleChanged: function(inSender, inEvent) {
		this.micMute = inEvent.value;
		if (this.palm) {
			this.$.SetMicMute.send({micMute: this.micMute});
		}
	},
	systemSounds: function(inSender, inEvent) {
		this.system = inEvent.value;
	},
	volumeChange: function(inSender, inEvent) {
		var v = parseInt(this.$.volumeSlider.value, 10);
		if (this.palm && this.systemVolume !== v) {
			this.systemVolume = v;
			this.$.SetVolume.send({volume: this.systemVolume});
		}
	},
	ringerVolumeChange: function(inSender, inEvent) {
		this.ringerVolume = inEvent.value;
	},
	//Service Callbacks
	handleGetAudioStatusResponse: function(inSender, inResponse) {
		if (inResponse.volume != undefined) {
			this.systemVolume = inResponse.volume;
			this.$.volumeSlider.silence();
			this.$.volumeSlider.setValue(this.systemVolume);
			this.$.volumeSlider.unsilence();
		}
		if (inResponse.mute != undefined) {
			this.mute = inResponse.mute;
			this.$.muteToggle.silence();
			this.$.muteToggle.setValue(this.mute);
			this.$.muteToggle.unsilence();
			this.doMuteChanged({mute: this.mute});
		}
		if (inResponse.micMute != undefined) {
			this.micMute = inResponse.micMute;
			this.$.micMuteToggle.silence();
			this.$.micMuteToggle.setValue(this.micMute);
			this.$.micMuteToggle.unsilence();
		}
	},
	handleGetPreferencesResponse: function(inSender, inResponse) {
		// Set our controls to match the values in the response.

		if (inResponse.ringtone != undefined) {
			this.$.ringerPicker.setContent("Ringtone -- " + inResponse.ringtone.name);
		}
	}
});
