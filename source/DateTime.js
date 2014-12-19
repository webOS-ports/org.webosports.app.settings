enyo.kind({
	name: "DateTime",
	layoutKind: "FittableRowsLayout",
	palm: false,
	handlers: {
		onClose: "closePopup",
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
			{name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true, components: [
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Time and Date Settings"},
				
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Time Format", fit: true,  style: "padding-top: 10px; min-width: 95px;"},
						{kind: "onyx.PickerDecorator", style: "float: right; padding-top: 10px;", components: [
							{},
							{name: "TimeFormatPicker", kind: "onyx.Picker", onChange: "timeFormatChanged", components: [
								{content: "12 Hour", active: true},
								{content: "24 Hour"}
							]},
							{kind: "onyx.Tooltip", content: "12/24hr Setting"}
						]}
				
					]},
				
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Network Time", fit: true, style: "padding-top: 10px;" },
						{kind: "onyx.PickerDecorator", style: "float: right; padding-top: 10px;", components: [
							{name: "NetworkTimeToggle", kind: "onyx.ToggleButton", value: true, style: "float: right;", onChange: "networkTimeChanged"},
							{kind: "onyx.Tooltip", content: "Network Time"}
						]}
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Time", fit: true, style: " padding-top: 10px;"},
						{name: "TimePicker", kind: "onyx.TimePicker", disabled: true, style: "float: right;  padding-top: 6px;", onSelect: "dateTimeChanged"},
					]},
					{ kind: "enyo.FittableColumns", classes: "group-item", components:[
						{content: "Date", fit: true, style: "padding-top: 10px;"},
						{name: "DatePicker", kind: "onyx.DatePicker", disabled: true, style: "float: right; padding-top: 6px;", onSelect: "dateTimeChanged"},
					]}
				]},
				{kind: "onyx.Groupbox", components: [
					{kind: "onyx.GroupboxHeader", content: "Timezone"},
					{classes: "group-item", name: "TimeZoneItem", kind: "onyx.Item", style: "padding-top: 10px;", tapHighlight: true, content: "unknown", ontap: "changeTimezone"},
				]},
			]},
		]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
		{name: "tomeZonePopup", kind: "onyx.Popup", classes: "popup", centered: true, floating: true,	components: [
			{kind: "TimeZonePicker", style: "height: 365px;"},
		]},		// time zone popup
		{kind: "SystemService", method: "getPreferences", name: "GetSystemPreferences", onComplete: "handleGetPreferencesResponse"},
		{kind: "SystemService", method: "setPreferences", name: "SetSystemPreferences" },
		{kind: "enyo.PalmService", method: "setSystemTime", name: "SetSystemTime", service: "luna://com.palm.systemservice/time" },
		{kind: "SystemService", method: "getPreferenceValues", name: "GetSystemPreferenceValues", onComplete: "handleGetPreferenceValuesResponse" },
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem) {
			enyo.log("Non-palm platform, service requests disabled.");

			/* mock some data requests */

			this.handleGetPreferencesResponse(null, { data: {
				timeFormat: "HH12",
				timeZone: "Pacific\/Tahiti",
				useNetworkTime: true,
			}});

			this.handleGetPreferenceValuesResponse(null, { data:
				{ "timeZone": [
					{ "Country": "Samoa", "CountryCode": "WS", "ZoneID": "Pacific\/Apia", "City": "Apia", "Description": "West Samoa Time", "offsetFromUTC": 780, "supportsDST": 1, "preferred": true }, 
					{ "Country": "United States of America", "CountryCode": "US", "ZoneID": "America\/Adak", "City": "Adak", "Description": "Hawaii-Aleutian Time", "offsetFromUTC": -600, "supportsDST": 1, "preferred": true }, 
					{ "Country": "French Polynesia", "CountryCode": "PF", "ZoneID": "Pacific\/Tahiti", "City": "Tahiti", "Description": "Tahiti Time", "offsetFromUTC": -600, "supportsDST": 0 }
				]}});

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
			this.$.div.setStyle("padding: 35px 5% 35px 5%;");
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
	timeZomePopup: function(inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);	
		this.$.tomeZonePopup.show();
		this.$.tomeZonePopup.setShowing(true);
	},
	closePopup: function(inSender, inEvent){
		this.$.tomeZonePopup.hide();
	},
	timeFormatChanged: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetSystemPreferences.send({timeFormat: inSender.selected.content == "12 Hour" ? "HH12" : "HH24"});
		}
		else {
			enyo.log(inSender);
		}

		if (typeof(this.$.TimePicker) !== "undefined")
			this.$.TimePicker.setIs24HrMode(inSender.selected.content != "12 Hour");
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
		timeObj.utc = parseInt(inEvent.value.getTime() / 1000);

		if(this.palm) {
			this.$.SetSystemTime.send(timeObj);
			this.$.SetSystemPreferences.send({useNetworkTime: false, receiveNetworkTimeUpdates: false});
		}
		else {
			enyo.log(timeObj);
		}
	},
	timeZoneChanged: function(inSender, inEvent) {
		var newTimeZone = this.$.TimeZonePicker.selected.zoneId;

		console.log("New time zone is " + newTimeZone);

		if (!this.palm)
			return;

		this.$.SetSystemPreferences.send({timeZone: newTimeZone});
	},
	changeTimezone: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);	
		this.timeZomePopup();
	},
	//Service Callbacks
	handleGetPreferencesResponse: function(inSender, inResponse) {
		var result = inResponse.data;

		if(result.timeFormat != undefined) {
			this.$.TimeFormatPicker.setSelected(this.$.TimeFormatPicker.getClientControls()[result.timeFormat == "HH12" ? 0 : 1]);
		}

		if(result.useNetworkTime != undefined)
			this.$.NetworkTimeToggle.setValue(result.useNetworkTime);

		if(result.timeZone != undefined) {
			this.currentTimezone = result.timeZone;
			this.$.TimeZoneItem.setContent(this.currentTimezone.ZoneID);
		}

		this.updateTimeControlStates();
	},
	handleGetPreferenceValuesResponse: function(inSender, inResponse) {
		var result = inResponse.data;

		if (result["timeZone"] !== undefined) {
			var timeZones = result["timeZone"];
			/* FIXME */
		}
	}
});
