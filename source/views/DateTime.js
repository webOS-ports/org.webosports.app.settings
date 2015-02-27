enyo.kind({
	name: "DateTime",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{kind: "onyx.Toolbar",
		style: "line-height: 28px;",
		components:[
			{content: "Date & Time"},
		]},
		{ name: "DateTimePanels", kind: "Panels",
		  arrangerKind: "HFlipArranger",
		  fit: true, draggable: false, components: [
			/* Main Date Time panel */
			{ name: "MainDateTimeSettings",
			  kind: "enyo.FittableRows",
			  components: [
				{kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout", style: "padding: 35px 10% 35px 10%;", components: [
					{kind: "onyx.GroupboxHeader", content: "Time and Date Settings"},
					{ kind: "enyo.FittableColumns", classes: "group-item", components: [
						{content: "Time Format", fit: true },
						{kind: "onyx.PickerDecorator", components: [
							{},
							{name: "TimeFormatPicker", kind: "onyx.Picker", onChange: "timeFormatChanged", components: [
								{content: "12 Hour", active: true},
								{content: "24 Hour"}
							]},
							{kind: "onyx.Tooltip", content: "12/24hr Setting"}
						]}
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Network Time", fit: true },
						{kind: "onyx.PickerDecorator", components: [
							{name: "NetworkTimeToggle", kind: "onyx.ToggleButton", value: true, onChange: "networkTimeChanged"},
							{kind: "onyx.Tooltip", content: "Network Time"}
						]}
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Time", fit: true},
						{name: "TimePicker", kind: "onyx.TimePicker", disabled: true, onSelect: "dateTimeChanged"},
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Date", fit: true},
						{name: "DatePicker", kind: "onyx.DatePicker", disabled: true, onSelect: "dateTimeChanged"},
					]}
				]},
				{kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout", style: "padding: 35px 10% 35px 10%;", components: [
					{kind: "onyx.GroupboxHeader", content: "Time Zone"},
					{classes: "group-item", name: "TimeZoneItem", kind: "onyx.Item", tapHighlight: true, content: "unknown", ontap: "changeTimeZone"}
				]}
			]},
			  /* Time Zone panel */
			  { }
		  ]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
		{kind: "SystemService", method: "getPreferences", name: "GetSystemPreferences", onComplete: "handleGetPreferencesResponse"},
		{kind: "SystemService", method: "setPreferences", name: "SetSystemPreferences" },
		{kind: "enyo.LunaService", method: "setSystemTime", name: "SetSystemTime", service: "luna://com.palm.systemservice/time" },
		{kind: "SystemService", method: "getPreferenceValues", name: "GetSystemPreferenceValues", onComplete: "handleGetPreferenceValuesResponse" },
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");

			/* mock some data requests */

			this.handleGetPreferencesResponse(null, {
				timeFormat: "HH12",
				timeZone: "Pacific\/Tahiti",
				useNetworkTime: true
			});

			this.handleGetPreferenceValuesResponse(null, {
				"timeZone": [
					{ "Country": "Samoa", "CountryCode": "WS", "ZoneID": "Pacific\/Apia", "City": "Apia", "Description": "West Samoa Time", "offsetFromUTC": 780, "supportsDST": 1, "preferred": true }, 
					{ "Country": "United States of America", "CountryCode": "US", "ZoneID": "America\/Adak", "City": "Adak", "Description": "Hawaii-Aleutian Time", "offsetFromUTC": -600, "supportsDST": 1, "preferred": true }, 
					{ "Country": "French Polynesia", "CountryCode": "PF", "ZoneID": "Pacific\/Tahiti", "City": "Tahiti", "Description": "Tahiti Time", "offsetFromUTC": -600, "supportsDST": 0 }
				]});

			return;
		}

		this.$.GetSystemPreferences.send({keys: ["timeFormat", "timeZone", "useNetworkTime"]});

		/* Retrieve all time zones */
		this.$.GetSystemPreferenceValues.send({key: "timeZone"});

		this.palm = true;
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.Grabber.applyStyle("visibility", "hidden");
//			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
		}
		else {
			this.$.Grabber.applyStyle("visibility", "visible");
		}
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
			this.log(inSender.selected);
		}

		if (typeof(this.$.TimePicker) !== "undefined")
			this.$.TimePicker.setIs24HrMode(inSender.selected.content != "12 Hour");
	},
	networkTimeChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({useNetworkTime: inSender.value, receiveNetworkTimeUpdates: inSender.value});
		}
		else {
			this.log(inSender.value);
		}

		this.updateTimeControlStates();
	},
	dateTimeChanged: function(inSender, inEvent) {
		var timeObj = {};
		timeObj.utc = parseInt(inEvent.value.getTime() / 1000);

		if(this.palm) {
			this.$.SetSystemTime.send(timeObj);
			this.$.SetSystemPreferences.send({useNetworkTime: false, receiveNetworkTimeUpdates: false});
		}
		else {
			this.log(timeObj);
		}
	},
	timeZoneChanged: function(inSender, inEvent) {
		var newTimeZone = this.$.TimeZonePicker.selected.zoneId;

		this.log("New time zone is " + newTimeZone);

		if (!this.palm)
			return;

		this.$.SetSystemPreferences.send({timeZone: newTimeZone});
	},
	changeTimeZone: function(inSender, inEvent) {
	},
	//Service Callbacks
	handleGetPreferencesResponse: function(inSender, inResponse) {
		if(inResponse.timeFormat != undefined) {
			this.$.TimeFormatPicker.setSelected(this.$.TimeFormatPicker.getClientControls()[inResponse.timeFormat == "HH12" ? 0 : 1]);
		}

		if(inResponse.useNetworkTime != undefined)
			this.$.NetworkTimeToggle.setValue(inResponse.useNetworkTime);

		if(inResponse.timeZone != undefined) {
			this.currentTimeZone = inResponse.timeZone;
			this.$.TimeZoneItem.setContent(this.currentTimeZone.ZoneID);
		}

		this.updateTimeControlStates();
	},
	handleGetPreferenceValuesResponse: function(inSender, inResponse) {
		if (inResponse["timeZone"] !== undefined) {
			var timeZones = inResponse["timeZone"];
			/* FIXME */
		}
	}
});
