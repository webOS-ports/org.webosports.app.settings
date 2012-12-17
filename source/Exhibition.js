enyo.kind({
	name: "ExhibitionService",
	kind: "enyo.webOS.ServiceRequest",
	service: "palm://com.palm.display/control/"
});

enyo.kind({
	name: "Exhibition",
	layoutKind: "FittableRowsLayout",
	components:[
		{kind: "onyx.Toolbar",
		style: "line-height: 36px;",
		components:[
				{content: "Exhibition"},
		]},
		{fit: true},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber", style: "margin-top: 8px; margin-bottom: 8px;"},
			{kind: "onyx.Button",
			style: "position: absolute; left: 50%; margin-top: 4px; margin-left: -73px;",
			content: "Start Exhibition",
			ontap: "startExhibitionTapped"}
		]}
	],
	//Handlers
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
		}
		else {
			this.$.Grabber.applyStyle("visibility", "visible");
		}
	},
	//Action Handlers
	startExhibitionTapped: function(inSender, inEvent) {
		try {
			var startExhibition = new ExhibitionService({method:"setState"});
			startExhibition.go({state:"dock"});
		}
		catch(e) {
			enyo.log("Starting Exhibition");
		}
	}
});
