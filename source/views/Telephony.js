enyo.kind({
	name: "WanService",
	kind: "enyo.LunaService",
	service: "luna://com.palm.wan/"
});

enyo.kind({
	name: "Telephony",
	layoutKind: "FittableRowsLayout",
	palm: false,
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
		{kind: "WanService", method: "getstatus", name: "GetWanStatus", subscribe: true,
		 onComplete: "handleWanStatus"},
		{kind: "WanService", method: "set", name: "SetWanProperty"}
	],
	create: function(inSender, inEvent) {
		this.inherited(arguments);

		if (!window.PalmSystem) {
			this.log("Non-palm platform, service requests disabled.");
			return;
		}

		this.$.GetWanStatus.send({});
		this.palm = true;
	},
	reflow: function (inSender) {
		this.inherited(arguments);
		if (enyo.Panels.isScreenNarrow()){
			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
			this.$.Grabber.applyStyle("visibility", "hidden");
		} else{
			this.$.Grabber.applyStyle("visibility", "visible");
		}
	},
	/* service response handlers */
	handleWanStatus: function(inSender, inResponse) {
		this.log("roamGuard: " + inResponse.roamGuard);
		if (inResponse.roamGuard != undefined) {
			var roamingAllowed = (inResponse.roamGuard === "disable");
			this.log("Setting RoamingAllowed " + roamingAllowed);
			this.$.RoamingAllowed.silence();
			this.$.RoamingAllowed.setValue(roamingAllowed);
			this.$.RoamingAllowed.unsilence();
		}

		this.log("disablewan: " + inResponse.disablewan);
		if (inResponse.disablewan != undefined) {
			var dataUsage = (inResponse.disablewan === "off");
			this.log("Setting DataUsage " + dataUsage);
			this.$.DataUsage.silence();
			this.$.DataUsage.setValue(dataUsage);
			this.$.DataUsage.unsilence();
		}
	},
	/* component event handlers */
	roamingAllowedChanged: function(inSender, inEvent) {
		this.log(inSender.value);
		var newSetting = inSender.value ? "disable" : "enable";
		if (this.palm) {
			this.$.SetWanProperty.send({"roamguard": newSetting});
			this.log("Set roamguard " + newSetting + " sent");
		} else {
			this.log("Set roamguard " + newSetting + " suppressed");
		}
	},
	dataUsageChanged: function(inSender, inEvent) {
		this.log(inSender.value);
		var newSetting = inSender.value ? "off" : "on";
		if (this.palm) {
			this.$.SetWanProperty.send({"disablewan": newSetting});
			this.log("Set disablewan " + newSetting + " sent");
		} else {
			this.log("Set disablewan " + newSetting + " suppressed");
		}
	}
});
