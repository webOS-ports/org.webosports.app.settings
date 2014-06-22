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
						{kind: "onyx.GroupboxHeader", content: "Network"},
						{ classes: "group-item", style: "height: 42px;", components:[
							{content: "Roaming allowed", fit: true, style: "display: inline-block; line-height: 42px;"},
							{name: "RoamingAllowed", kind: "onyx.ToggleButton", style: "float: right;", onChange: "roamingAllowedChanged"},
						]},
						{ classes: "group-item", style: "height: 42px;", components:[
							{content: "Data usage", fit: true, style: "display: inline-block; line-height: 42px;"},
							{name: "DataUsage", kind: "onyx.ToggleButton", style: "float: right;", onChange: "dataUsageChanged"},
						]},
					]},
				]},
			]
		},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"}
		]}
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem)
			enyo.log("Non-palm platform, service requests disabled.");
	},
	deviceready: function(inSender, inEvent) {
		this.inherited(arguments);

		var request = navigator.service.Request("luna://com.palm.wan/", {
			method: 'getstatus', onSuccess: enyo.bind(this, "handleWanStatus")});
	},
	/* service response handlers */
	handleWanStatus: function(inResponse) {
		console.log("WAN status changed: " + JSON.stringify(inResponse));

		if (inResponse.returnValue) {
			var roamingAllowed = false;
			var dataUsage = false;

			dataUsage = (inResponse.disablewan == "on");
			roamingAllowed = (inResponse.roamGuard == "enable");

			this.$.RoamingAllowed.setValue(roamingAllowed)
			this.$.DataUsage.setValue(dataUsage);
		}
	},
	/* component event handlers */
	roamingAllowedChanged: function(inSender, inEvent) {
		var request = navigator.service.Request("luna://com.palm.wan/", {
			method: 'set', parameters: {"roamguard": inSender.getValue() }});
	},
	dataUsageChanged: function(inSender, inEvent) {
		var request = navigator.service.Request("luna://com.palm.wan/", {
			method: 'set', parameters: {"disablewan": inSender.getValue() }});
	}
});
