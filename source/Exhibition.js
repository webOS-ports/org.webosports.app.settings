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
			{kind: "onyx.Grabber", style: "margin-top: 8px; margin-bottom: 8px;"},
			{kind: "onyx.Button",
			style: "position: absolute; left: 50%; margin-top: 4px; margin-left: -73px;",
			content: "Start Exhibition",
			ontap: "startExhibitionTapped"}
		]}
	],
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
