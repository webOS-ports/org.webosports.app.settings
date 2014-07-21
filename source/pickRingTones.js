// Copyright 2014, $ORGANIZATION
// All rights reserved.
enyo.kind({
	name: "pickRingTones", kind: "Control", published: {}, events: {}, components: [
				{kind: "enyo.Scroller", fit: true, components: [
						{kind: "enyo.List", fit: true, onSetupItem: "setupRingerList", components: [
								{content: "Item", kind: "onyx.Item", components: [
									{name: "index", classes: "list-sample-index"},
									{name: "tone"}	
								]}
							]}
					]}
			],
	create: function() {
		this.inherited(arguments);
		// initialization code goes here
	},
	setupRingerList: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
	
		var i = inEvent.index;
		// make some mock data if we have none for this row
		if (!this.names[i]) {
			this.tone[i] = maketone("tone 0", "tone 2", "tone 2",  "tone 2");
		}
		var n = this.tone[i];
		var ni = ("00000000" + i).slice(-7);
		// apply selection style if inSender (the list) indicates that this row is selected.
		this.$.item.addRemoveClass("list-sample-selected", inSender.isSelected(i));
		this.$.tone.setContent(n);
		this.$.index.setContent(ni);
		return true;
	}
});
