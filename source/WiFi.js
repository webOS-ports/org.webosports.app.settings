enyo.kind({
	name: "WiFi",
	layoutKind: "FittableRowsLayout",
	components: [
		{kind: "onyx.Toolbar",
		components:[
				{content: "Wi-Fi"},
				{kind: "onyx.ToggleButton", style: "float: right;"}
		]},
		{name: "WiFiPanels",
		kind: "Panels",
		arrangerKind: "HFlipArranger",
		fit: true,
		draggable: false,
		components:[
				{name: "SearchList",
				layoutKind: "FittableRowsLayout",
				style: "padding: 35px 10% 35px 10%;",
				components:[
					{kind: "onyx.GroupboxHeader", style: "border-radius: 8px 8px 0 0;", content: "Choose a Network"},
					{kind: "Scroller",
					touch: true,
					horizontal: "hidden",
					fit: true,
					style: "border: 1px solid white; border-top: 0; border-radius: 0 0 8px 8px;",
					components:[
						{classes: "group-item", content: "wifi"},
						{classes: "group-item", content: "more wifi"}
					]},
				]},
				{name: "KnownList",
				layoutKind: "FittableRowsLayout",
				style: "padding: 35px 10% 35px 10%;",
				components:[
					{kind: "onyx.GroupboxHeader", style: "border-radius: 8px 8px 0 0;", content: "Known Networks"},
					{kind: "Scroller",
					touch: true,
					horizontal: "hidden",
					fit: true,
					style: "border: 1px solid white; border-top: 0; border-radius: 0 0 8px 8px;",
					components:[
						{classes: "group-item", content: "framjooble"},
						{classes: "group-item", content: "fwoggle"},
						{classes: "group-item", content: "halfhalo's waterproof router"},
					]},
				]},
				{ /* Workaround for HFlipArranger incorrectly displaying with 2 panels*/ }
		]},
		{kind: "onyx.Toolbar", components:[
			{kind: "onyx.RadioGroup",
			style: "position: absolute; left: 50%; margin-left: -76px;",
			components:[
				{content: "Search", active: true, ontap: "searchTapped"},
				{content: "Known", ontap: "knownTapped"}
			]},
			{kind: "onyx.IconButton",
			src: "assets/icon-new.png",
			style: "float: right",
			ontap: ""},
		]}
	],
	searchTapped: function(inSender, inEvent) {
		this.$.WiFiPanels.setIndex(0);
	},
	knownTapped: function(inSender, inEvent) {
		this.$.WiFiPanels.setIndex(1);
	}
});
