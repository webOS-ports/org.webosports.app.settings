
var phonyringTones = [
		{
			"name": "Tones 3 beep",
			"scr": "assets/ringtones/tones_3beeps_otasp_done-ondemand.mp3"
		},
		{
			"name": "Error",
			"scr": "assets/ringtones/Error.mp3"
		},
		{
			"name": "App closer",
			"scr": "assets/ringtones/Appcloser.mp3"
		}
	];
	
var ringTones = [];

enyo.kind({
	name: "pickRingTones",
	kind: "enyo.Control",
	published: {},
	events: {
		onClose: "",
		onTone: ""
	},
	
	pickedName: "",
	pickedScr: "",

	components: [
		{name: "toneList", kind: "enyo.List", count: 0, classes: ".list-sample-list", style: "height: 365px;", onSetupItem: "setupItem", ontap: "tonePicked",
		components: [
			{content: "Item", kind: "onyx.Item", classes: "list-sample-item ", components: [
				{kind: "enyo.FittableColumns", classes: "" , components: [
					{name: "rtones", classes: "list-sample-index"},
					{content: "", fit: true},
					
				]}
			]}
		]},
		{name: "playButton", kind: "onyx.IconButton", active: "false", style: "float: left;", src: "assets/Email-btn_controls_play.png", ontap: "playTapped"},
		{kind: "onyx.Button", content: "Close", style: "float: right;", ontap: "closePpoup"},
		{name: "audio", kind: "enyo.Audio"}
	],
	
	create: function() {
		this.inherited(arguments);
		// initialization code goes here
		if (!window.PalmSystem) {
			// if we're outside the webOS system add some entries for easier testing
			this.ringTones = phonyringTones;
        }
        this.loadData();
        this.$.toneList.setCount(this.ringTones.length);
	},
	
	loadData: function(inSender, inEvent) {
	this.log("sender:", inSender, ", event:", inEvent);
	// load data/ringtone file into var ringTones []
	//TODO fix this properly for getting ringtones in /media/internal/ringtones (using Media Indexer?);
	        this.ringTones = phonyringTones;
	},

	setupItem: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		var i = inEvent.index;
		var t = this.ringTones[i].name;
		// apply selection style if inSender (the list) indicates that this row is selected.
		this.$.item.addRemoveClass("list-sample-selected", inSender.isSelected(i));
		this.$.rtones.setContent(t);
		return true;
	},
	
	playTapped: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		var i = inEvent.index;
		this.$.audio.setSrc(this.pickedScr);
		this.$.audio.play();
	},
	
	tonePicked: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		var i = inEvent.index;
		this.$.audio.pause();
		this.pickedName = this.ringTones[i].name;
		this.pickedScr = this.ringTones[i].scr;
		this.doTone(this.pickedName);
		
		console.log(" tone picked =",  this.ringTones[i].scr);
		
	},
	
	closePpoup: function(inSender, inEvent) {
		// TO DO - Auto-generated code
		this.$.audio.pause();
		this.doClose();
		this.$.toneList.refresh();
	},

});
