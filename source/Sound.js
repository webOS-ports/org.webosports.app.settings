
enyo.kind({
	name: "Sound",
	kind: "enyo.FittableRows",
	published: {},
	handlers: {
		onClose: "closePopup",
		onTone: "tonepicked"
	},
	palm: false,
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
			{tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
				{kind: "enyo.FittableRows", components: [
					{name: "AudioList", kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout", classes: "content-aligner", fit: true, components: [
						{kind: "onyx.GroupboxHeader", content: "Audio Settings"},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{name: "volume", content: "Volume "},
							{style: "padding-top: 0px;", fit: true, components: [
								{name: "volumeSlider", kind: "onyx.Slider", value: "20", onChanging: "volumeChange"}
							]}
						]},
						{kind: "enyo.FittableColumns", classes: "group-item", components: [
							{name: "keys", fit: true, content: "Keyboard Clicks"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "keyClicksToggle", kind: "onyx.ToggleButton", onChange: "keyClicks"},
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
							{name: "systemsounds", fit: true, content: "System Sounds"},
							{kind: "onyx.TooltipDecorator", components: [
								{name: "systemSoundToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "systemSounds"},
								{kind: "onyx.Tooltip", content: "System sound  on/off"}
							]}
						]},
						{kind: "enyo.FittableColumns", style: "padding-bottom: 5px; ", classes: "group-item", components: [
							{name: "ringer", content: "Ringer Volume ", style: "padding-bottom: 5px;"},
							{style: "padding-top: 0px;", fit: true, components: [
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
		]},		// tone popup
	],
	//Handlers
	create: function() {
		this.inherited(arguments);
		console.log ("Sound: created");
	
		// initialization code goes here
        if (!window.PalmSystem) {
			// if we're outside the webOS system add some entries for easier testing
			this.keys = true;
			this.vibrate = true;
			this.system = true;
			this.ringerVolume = 65;
			this.systemVolume = 45;
            
        }
        this.manage();
      //  this.$.p.setShowing(0);
    },
    reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
            this.$.Grabber.applyStyle("visibility", "hidden");
        }else{
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },
    
    manage: function (inSender, inEvent){						// get every thing set up
		this.log("sender:", inSender, ", event:", inEvent);

		if (this.keys === true){
			this.$.keyClicksToggle.setValue(true);
		}else{
			this.$.keyClicksToggle.setValue(false);
		}
		
		if (this.vibrate === true){
			console.log ("vibe   ");
			this.$.vibrateToggle.setValue(true);
		}else{
			this.$.vibrateToggle.setValue(false);
		}
		
		if (this.system === true){
			this.$.systemSoundToggle.setValue(true);
		}else{
			this.$.systemSoundToggle.setValue(false);
		}
		
		/* set slider to */
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
	//Utility Functions
	
	//Service Callbacks
	toggleButtonChanged: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent.value);
		// TO DO - Auto-generated code
		if (inEvent.value === false){
			this.deactivateAudio();
			this.$.audioPanels.setShowing(false);
			
			// turn off audio system wide here
		}
		
		if (inEvent.value === true){
			this.$.audioDisabled.setShowing(false);
			this.$.audioPanels.setShowing(true);
			
			// turn on audio system wide  here
		}
	},
	keyClicks: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
		console.log("key  value  true/false", inEvent.value);
		this.keys = inEvent.value;
	},				// set key clicks true/false here
	vib: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
		console.log("vibatre value  true/false", inEvent.value);
		this.vibrate = inEvent.value;
	},						// set vibrate true/false here
	systemSounds: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
		console.log("system value true/false", inEvent.value);
		this.system = inEvent.value;
	},			// set system sounds true/false here
	volumeChange: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
		console.log("system volume  value ", inEvent.value);
		this.systemVolume = inEvent.value;
	},			// set system volume here
	ringerVolumeChange: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
		console.log("ringer volume value ", inEvent.value);
		this.ringerVolume = inEvent.value;
	},		// set ringer volume here
});
