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
			{name: "Grabber", kind: "onyx.Grabber"},
			{kind: "onyx.Button",
			style: "position: absolute; left: 50%; margin-left: -73px;",
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
		if(window.PalmSystem) {
			var request = navigator.service.Request("luna://com.palm.display/control/",
			{
				method: 'setState',
				parameters: {state:"dock"}
			});
		}
		else {
			enyo.log("Starting Exhibition");
		}
	}
});
