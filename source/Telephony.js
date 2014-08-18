enyo.kind({
	name: "WanService",
	kind: "enyo.PalmService",
});

enyo.kind({
	name: "Telephony",
	layoutKind: "FittableRowsLayout",
	components:[
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
				{name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
					{kind: "onyx.Groupbox", components: [
						{kind: "onyx.GroupboxHeader", content: "Network"},
						{ kind: "enyo.FittableColumns", classes: "group-item", components:[
							{content: "Roaming allowed", fit: true, style: "padding-top: 10px;"},
							{kind: "onyx.TooltipDecorator", fit: true, style:  "padding-top: 10px;", components: [
								{name: "RoamingAllowed", kind: "onyx.ToggleButton", style: "float: right;", onChange: "roamingAllowedChanged"},
								{kind: "onyx.Tooltip", content: "Allow Roaming"}
							]}	
						]},
						{ kind: "enyo.FittableColumns", classes: "group-item", components:[
							{content: "Data usage", fit: true, style: "padding-top: 10px;"},
							{kind: "onyx.TooltipDecorator", fit: true, style:  "padding-top: 10px;", components: [
								{name: "DataUsage", kind: "onyx.ToggleButton", style: "float: right;", onChange: "dataUsageChanged"},
								{kind: "onyx.Tooltip", content: "Allow Data Usage"}
							]}
						]},
					]},
				]},
			]
		},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
		{kind: "WanService", method: "getstatus", name: "GetWanStatus", onComplete: "handleWanStatus"},
		{kind: "WanService", method: "set", name: "SetWanProperty" }
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");
			return;
		}

		this.$.GetWanStatus.send({});
	},
	reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
        	this.$.div.setStyle("padding: 35px 5% 35px 5%;");
            this.$.Grabber.applyStyle("visibility", "hidden");
        }else{
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },
   
	/* service response handlers */
	handleWanStatus: function(inResponse) {
		var result = inResponse.data;

		console.log("WAN status changed: " + JSON.stringify(result));

		if (result.returnValue) {
			var roamingAllowed = false;
			var dataUsage = false;

			dataUsage = (result.disablewan == "on");
			roamingAllowed = (result.roamGuard == "enable");

			this.$.RoamingAllowed.setValue(roamingAllowed)
			this.$.DataUsage.setValue(dataUsage);
		}
	},
	/* component event handlers */
	roamingAllowedChanged: function(inSender, inEvent) {
		if (!this.palm)
			return;

		this.$.SetWanProperty.send({roamGuard: inSender.getValue()});
	},
	dataUsageChanged: function(inSender, inEvent) {
		if (!this.palm)
			return;

		this.$.SetWanProperty.send({disablewan: inSender.getValue()});
	}
});
