enyo.kind({
	name: "DateTime",
	layoutKind: "FittableRowsLayout",
	palm: false,
	events: {
        onBackbutton: "",
    },
	components:[
		{kind: "onyx.Toolbar",
		style: "line-height: 36px;",
		components:[
				{content: "Date & Time"},
		]},
		{kind: "Scroller",
		touch: true,
		horizontal: "hidden",
		fit: true,
		components:[
			{tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
				{kind: "onyx.Groupbox", components: [
					{classes: "group-item",
					style: "height: 42px;",
					components:[
						{content: "Time Format",
						fit: true,
						style: "display: inline-block; line-height: 42px;"},
						{kind: "onyx.PickerDecorator", style: "float: right;", components: [
							{},
							{name: "TimeFormatPicker", kind: "onyx.Picker", onChange: "timeFormatChanged", components: [
								{content: "12 Hour", active: true},
								{content: "24 Hour"}
							]}
						]}
				
					]},
					{classes: "group-item",
					style: "height: 42px;",
					components:[
						{content: "Network Time",
						fit: true,
						style: "display: inline-block; line-height: 42px;"},
						{name: "NetworkTimeToggle", kind: "onyx.ToggleButton", value: true, style: "float: right;", onChange: "networkTimeChanged"}
				
					]},
					{classes: "group-item",
					components:[
						{content: "Set Current Time",
						fit: true,
						style: "line-height: 42px; display: inline-block;"},
							{name: "TimePicker", kind: "onyx.TimePicker", disabled: true, style: "float: right;", onSelect: "dateTimeChanged"},
				
					]},
					{classes: "group-item",
					components:[
						{content: "Set Current Date",
						fit: true,
						style: "line-height: 42px; display: inline-block;"},
							{name: "DatePicker", kind: "onyx.DatePicker", disabled: true, style: "float: right;", onSelect: "dateTimeChanged"},
				
					]},
					{classes: "group-item",
					style: "height: 42px;",
					components:[
						{content: "Timezone",
						fit: true,
						style: "display: inline-block; line-height: 42px;"},
					]},
				]},
			]},
		]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
			{name: "backbutton", kind: "onyx.Button", style: "float: right;", showing: "true", content: "Back", ontap: "goBack"}
		]},
		{kind: "SystemService", method: "getPreferences", name: "GetSystemPreferences", onComplete: "handleGetPreferencesResponse"},
		{kind: "SystemService", method: "setPreferences", name: "SetSystemPreferences" },
		{kind: "enyo.PalmService", method: "setSystemTime", name: "SetSystemTime", service: "luna://com.palm.systemservice/time" }
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");
			return;
		}

		this.$.GetSystemPreferences.send({keys: ["timeFormat", "timeZone", "useNetworkTime"]});

		this.palm = true;
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
			this.$.backbutton.setShowing(true);
		}
		else {
			this.$.Grabber.applyStyle("visibility", "visible");
			this.$.backbutton.setShowing(false);
		}
	},
	goBack: function(inSender, inEvent){
		this.doBackbutton();
	},
	updateTimeControlStates: function() {
		if (this.$.NetworkTimeToggle.value) {
			this.$.TimePicker.setDisabled(true);
			this.$.DatePicker.setDisabled(true);
		}
		else {
			this.$.TimePicker.setDisabled(false);
			this.$.DatePicker.setDisabled(false);
		}
	},
	//Action Handlers
	timeFormatChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({timeFormat: inSender.selected.content == "12 Hour" ? "HH12" : "HH24"});
		}
		else {
			enyo.log(inSender);
		}
		//this.$.TimePicker.setIs24HrMode(inSender.selected.content != "12 Hour");
	},
	networkTimeChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({useNetworkTime: inSender.value, receiveNetworkTimeUpdates: inSender.value});
		}
		else {
			enyo.log(inSender.value);
		}

		this.updateTimeControlStates();
	},
	dateTimeChanged: function(inSender, inEvent) {
		var timeObj = {};
		timeObj.utc = inEvent.value.getTime()/1000;
		if(this.palm) {
			this.$.SetSystemTime.send(timeObj);
			this.$.SetSystemPreferences.send({useNetworkTime: false, receiveNetworkTimeUpdates: false});
		}
		else {
			enyo.log(timeObj);
		}
	},
	//Service Callbacks
	handleGetPreferencesResponse: function(inResponse) {
		var result = inResponse.data;

		if(result.timeFormat != undefined) {
			this.$.TimeFormatPicker.setSelected(this.$.TimeFormatPicker.getClientControls()[result.timeFormat == "HH12" ? 0 : 1]);
		}

		if(result.useNetworkTime != undefined)
			this.$.NetworkTimeToggle.setValue(result.useNetworkTime);

		if(result.timeZone != undefined) {}
			//Set time zone

		this.updateTimeControlStates();
	},
});
