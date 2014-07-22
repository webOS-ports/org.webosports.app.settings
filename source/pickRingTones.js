// Copyright 2014, $ORGANIZATION
// All rights reserved.

var phonyringTones = [
		{
			"name": "Pre",
			"scr": "assets/ringtones/Pre.mp3"
		}		
	];

enyo.kind({
	name: "pickRingTones",
	kind: "enyo.Control",
	published: {}, 
	events: {}, 
	components: [
		{name: "toneList", kind: "List", count: 0, style: "height: 400px;", onSetupItem: "setupItem", components: [
			{content: "Item", kind: "onyx.Item", class: "list-item.onyx-selected", ontap: "tonePicked", components: [
				{kind: "enyo.FittableColumns", class: "group-item", components: [
					{name: "rtones"},
					{content: "", fit: true},
					{kind: "onyx.IconButton", Content: "Play", style: "float: right;", src: "assets/Email-btn_controls_play.png", ontap:"playTapped"}
				]}
			]}
		]},
		{name: "play", kind: "enyo.Audio"}
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
		this.$.play.setSrc(this.ringTones[i].scr);
		if (this.$.play.getPaused()) {
			this.$.play.play();
		} else {
			this.$.play.pause();
		}
	},
	
	tonePicked: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		
	}
});
