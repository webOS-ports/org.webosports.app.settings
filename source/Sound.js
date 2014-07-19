
enyo.kind({
	name: "Sound", kind: "enyo.Control", layoutkind: "enyo.FittableColumnsLayout", published: {}, events: {}, palm: false, audio: false, components: [
		{kind: "onyx.Toolbar", layoutKind: "FittableColumnsLayout", classes: "onyx-toolbar", style: "height: 32px;", components: [
			{content: "Audio"},
			{fit: true},
			{name: "audioToggle", kind: "onyx.ToggleButton", onChange: "toggleButtonChanged", showing: "true"}
		]},
		{name: "audioPanels", layoutKind: "FittableRowsLayout", fit: true, draggable: false, showing: false, components: [
			{kind: "enyo.FittableRows", classes: "content-wrapper", components: [
				{name: "AudioList", kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout", classes: "content-aligner", fit: true, components: [
					{kind: "onyx.GroupboxHeader", content: "Audio Settings"},
					{classes: "group-item", components: [
						{name: "volume", content: "Volume ", class: "group-item"},
						{kind: "onyx.Slider", value: "20", onChanging: "voulemChange"}
					]},
					{classes: "group-item", components: [
						{kind: "enyo.FittableColumns", components: [
							{name: "keys", content: "Keyboard Clicks"},
							{fit: true, onchange: "create"},
							{kind: "onyx.ToggleButton", classes: "audioToggles", onChange: "keyClicks"}
							]}
						]},
						{classes: "group-item", components: [
							{kind: "enyo.FittableColumns", components: [
								{name: "vibrate", content: "Vibrate"},
									{fit: true},
									{kind: "onyx.ToggleButton", style: "float: right;", onChange: "vib"}
								]}
							]},
						{classes: "group-item", components: [
							{kind: "enyo.FittableColumns", components: [
								{content: "System Sounds "},
								{fit: true},
								{kind: "onyx.ToggleButton", onChange: "systemSounds"}
							]}
						]}
					]}
				]}
			]},
		{name: "audioDisabled", layoutKind: "FittableRowsLayout", style: "padding: 35px 10% 35px 10%;", showing: false, components: [
			{style: "padding-bottom: 10px;", components: [
					{content: "Audio is disabled", style: "display: inline;"}
			]}
		]},
		{name: "ErrorPopup", kind: "onyx.Popup", classes: "error-popup", modal: true, style: "padding: 10px;", components: [
			{name: "ErrorMessage", content: "", style: "display: inline;"}
		]}
	],
	//Handlers
	create: function() {
		this.inherited(arguments);
		console.log ("Sound: created");
	
		// initialization code goes here
        if (!window.PalmSystem) {
			// if we're outside the webOS system add some entries for easier testing
			this.audio = true;
        }
        this.manage();
	},
    reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
            
        }else{
            
        }
    },
    manage: function (inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);
		this.audio = this.getAudioStatus();
		// setup the pannel
		if (this.audio === true){
			this.$.audioDisabled.setShowing(false);
			this.$.audioPanels.setShowing(true);
		}else{
			this.$.audioDisabled.setShowing(true);
			this.$.audioPanels.setShowing(false);
		}   
		
		// set up the buttons
	
		if (this.audio === true){
			this.$.audioToggle.setValue(true);
		}else{
			this.$.audioToggle.setValue(false);
		}
    },
    
	//Action Functions
	toggleButtonChanged: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent.value);
		// TO DO - Auto-generated code
		if (inEvent.value === false){
			this.deactivateAudio();
			this.$.audioPanels.setShowing(false);
		}
		
		if (inEvent.value === true){
			this.$.audioDisabled.setShowing(false);
			this.$.audioPanels.setShowing(true);
		}
		
	},
	
	//Utility Functions
	deactivateAudio: function (inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
        this.$.audioDisabled.show();
    },
    
	//Service Callbacks
	getAudioStatus: function(inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);
		return(true);
		// return(get audio status here ===  true/false  );
	},
	keyClicks: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
	},
	vib: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
	},
	systemSounds: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
	},
	voulemChange: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
	}
});
