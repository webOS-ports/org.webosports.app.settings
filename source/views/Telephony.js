enyo.kind({
	name: "WanService",
	kind: "enyo.LunaService",
	service: "luna://com.palm.wan/"
});

enyo.kind({
	name: "Telephony",
	layoutKind: "FittableRowsLayout",
	palm: false,
	// Suppress service calls when setting control states
	// to match service call responses.
	// Suppress when positive.
	suppressSetRoamGuard: 0,
	suppressSetDisableWan: 0,
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
		var roamingAllowed = false;
		var dataUsage = false;

		this.log("roamGuard: " + inResponse.roamGuard);
		if (inResponse.roamGuard != undefined) {
			roamingAllowed = (inResponse.roamGuard === "enable");
			// The control's onChange is only triggered if it changes!
			if (this.$.RoamingAllowed.getValue() !== roamingAllowed) {
				this.log("Setting RoamingAllowed " + roamingAllowed);
				this.suppressSetRoamGuard = this.suppressSetRoamGuard + 1;
				this.$.RoamingAllowed.setValue(roamingAllowed);
			}
		}

		this.log("disablewan: " + inResponse.disablewan);
		if (inResponse.disablewan != undefined) {
			dataUsage = (inResponse.disablewan === "off");
			// The control's onChange is only triggered if it changes!
			if (this.$.DataUsage.getValue() !== dataUsage) {
				this.log("Setting DataUsage " + dataUsage);
				this.suppressSetDisableWan = this.suppressSetDisableWan + 1;
				this.$.DataUsage.setValue(dataUsage);
			}
		}
	},
	/* component event handlers */
	roamingAllowedChanged: function(inSender, inEvent) {
		this.log(inSender.value + " /w set suppression flag: " + this.suppressSetRoamGuard);
		var newSetting = inSender.value ? "enable" : "disable";
		if (this.palm && this.suppressSetRoamGuard === 0) {
			this.$.SetWanProperty.send({"roamGuard": newSetting});
			this.log("Set roamGuard " + newSetting + " sent");
		} else {
			this.log("Set roamGuard " + newSetting + " suppressed");
		}
		if (this.suppressSetRoamGuard > 0) {
			this.suppressSetRoamGuard = this.suppressSetRoamGuard - 1;
		}
	},
	dataUsageChanged: function(inSender, inEvent) {
		this.log(inSender.value + " /w set suppression flag: " + this.suppressSetDisableWan);
		var newSetting = inSender.value ? "off" : "on";
		if (this.palm && this.suppressSetDisableWan === 0) {
			this.$.SetWanProperty.send({"disablewan": newSetting});
			this.log("Set disablewan " + newSetting + " sent");
		} else {
			this.log("Set disablewan " + newSetting + " suppressed");
		}
		if (this.suppressSetDisableWan > 0) {
			this.suppressSetDisableWan = this.suppressSetDisableWan - 1;
		}
	}
});
