// A slightly modified webos-lib enyo.NumberPad.
enyo.kind({
	name: "PINNumberPad",
	layoutKind: "FittableRowsLayout",
	events: {
		onKeyTapped: ""
	},
	defaultKind: enyo.kind({kind: "onyx.Button",
				classes: "onyx-toolbar, onyx-light",
				style: "width: 33.3%; height: 25%; font-size: 32pt; font-weight: bold;",
				ontap: "keyTapped"}),
	components:[
		{content: "1", style: "border-radius: 16px 0 0 0;"},
		{content: "2", style: "border-radius: 0;"},
		{content: "3", style: "border-radius: 0 16px 0 0;"},
		{content: "4", style: "border-radius: 0;"},
		{content: "5", style: "border-radius: 0;"},
		{content: "6", style: "border-radius: 0;"},
		{content: "7", style: "border-radius: 0;"},
		{content: "8", style: "border-radius: 0;"},
		{content: "9", style: "border-radius: 0;"},
		{components: [{kind: "onyx.Icon"}], style: "border-radius: 0 0 0 16px;",
		 disabled: true},
		{content: "0", style: "border-radius: 0;"},
		{components: [{kind: "onyx.Icon", src: "assets/Pin-icon-delete.png",
		               style: "width: 36px; height: 30px;"}],
		 style: "border-radius: 0 0 16px 0;"},
	],
	keyTapped: function(inSender) {
		this.doKeyTapped({value: inSender.content});
	}
});
