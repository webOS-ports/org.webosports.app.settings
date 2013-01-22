enyo.kind({
	name: "Telephony",
	layoutKind: "FittableRowsLayout",
	components:[
		{kind: "Signals", ondeviceready: "deviceready"},
		{
			kind: "onyx.Toolbar",
			style: "line-height: 36px;",
			components:[
				{ content: "Telephony" },
			]
		},
		{
			kind: "Scroller",
			touch: true,
			horizontal: "hidden",
			fit: true,
			components: [
				{tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
					{kind: "onyx.Groupbox", components: [
						{kind: "onyx.GroupboxHeader", content: "Security"},
						{ classes: "group-item", style: "height: 42px;", components:[
							{content: "SIM Lock", fit: true, style: "display: inline-block; line-height: 42px;"},
							{name: "SimLockToggle", kind: "onyx.ToggleButton", style: "float: right;", onChange: "simLockChanged"},
						]},
						{ classes: "group-item", style: "height: 42px;", components:[
							{content: "SIM PIN", fit: true, style: "display: inline-block; line-height: 42px;"},
							{kind: "onyx.Button", style: "float: right;", content:"Change", ontap: "changeSimPin"},
						]},
					]},
					{kind: "onyx.Groupbox", components: [
						{kind: "onyx.GroupboxHeader", content: "Network"},
						{ classes: "group-item", style: "height: 42px;", components:[
							{content: "Automatic selection", fit: true, style: "display: inline-block; line-height: 42px;"},
							{name: "NetworkAutoSelection", kind: "onyx.ToggleButton", style: "float: right;", onChange: "networkAutoSelectionChanged"},
						]},
					]},
				]},
			]
		},
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem)
			enyo.log("Non-palm platform, service requests disabled.");
	},
	deviceready: function(inSender, inEvent) {
		this.inherited(arguments);
	},
	simLockChanged: function(inSender, inEvent) {
	},
	changeSimPin: function(inSender, inEvent) {
	},
	networkAutoSelectionChanged: function(inSender, inEvent) {
	}
});
