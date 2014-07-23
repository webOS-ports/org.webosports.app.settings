// Copyright 2014, $ORGANIZATION
// All rights reserved.

var phonyringTones = [
		{
			"name": "Pre",
			"scr": "assets/ringtones/Pre.mp3"
		}		
	];

enyo.kind({
	name: "pickRingTones", kind: "enyo.Control", published: {},
	events: {
		onClose: ""
	}, 
	components: [
		{name: "toneList", kind: "List", count: 0, style: "height: 365px;", onSetupItem: "setupItem", components: [
			{content: "Item", kind: "onyx.Item", class: "list-item.onyx-selected", components: [
				{kind: "enyo.FittableColumns", class: "group-item", components: [
					{name: "rtones", ontap: "tonePicked"},
					{content: "", fit: true},
					{kind: "onyx.IconButton", Content: "Play", style: "float: right;", src: "assets/Email-btn_controls_play.png", ontap: "playTapped"},
				]}
			]}
		]},
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
        
        this.$.toneList.setCount(this.ringTones.length);
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
		this.$.audio.setSrc(this.ringTones[i].scr);
		this.$.audio.play();
	},
	
	tonePicked: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		var i = inEvent.index;
		console.log(" tone picked =",  this.ringTones[i].scr);
	},
	closePpoup: function(inSender, inEvent) {
		// TO DO - Auto-generated code
		this.$.audio.pause();
		this.doClose();
	}
});
