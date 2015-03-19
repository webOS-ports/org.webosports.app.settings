enyo.kind({
	name: "DateTime",
	layoutKind: "FittableRowsLayout",
	events: {
		onBackbutton: ""
	},
	timeZones: null,
	currentTimeZone: null,
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
			  kind: "Scroller",
			  touch: true, horizontal: "hidden",
			  components: [{
			  kind: "enyo.FittableRows",
			  components: [
				{kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout",
				 name: "mdts1", style: "padding: 35px 10% 0 10%;", components: [
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
				{kind: "onyx.Groupbox", layoutKind: "FittableRowsLayout",
				 name: "mdts2", style: "padding: 10px 10% 8px 10%;", components: [
					{kind: "onyx.GroupboxHeader", content: "Time Zone"},
					{classes: "group-item", name: "TimeZoneItem", kind: "onyx.Item", content: "unknown",
					 tapHighlight: true, ontap: "showTimeZonePicker"}
				]}
			]}
			]},
			  /* Time Zone panel */
			{
			  kind: "enyo.FittableRows", components: [
				  {
					  name: "TimeZonePicker",
					  kind: "onyx.Groupbox",
					  layoutKind: "FittableRowsLayout",
					  style: "padding: 35px 10% 8px 10%;",
					  fit: true,
					  components: [
						  {
							  kind: "onyx.GroupboxHeader",
							  content: "Choose a Time Zone"
						  },
						  {
							  touch: true,
							  fit: true,
							  name: "TimeZonesList",
							  kind: "List",
							  count: 0,
							  onSetupItem: "setupTimeZoneRow",
							  components: [{
								  name: "timeZoneListItem",
								  classes: "tz-group-item",
								  ontap: "listItemTapped", components: [
									  {tag: "div", components: [
									  {name: "TZCountry", style: "float: left; font-weight: bold;",
									   allowHtml: true, content: "Country"},
									  {style: "float: right;",
									   name: "TZOffset", content: "GMT+10:00"}]},
									  {tag: "br"},
									  {tag: "div", style: "padding-top: 1px;", components: [
									  {name: "TZCity", style: "float: left;",
									   allowHtml: true, content: "City"},
									  {style: "float: right; font-size: smaller; padding-top: 2px;",
									   allowHtml: true,
									   name: "TZDescription", content: "Description"}]},
									  {tag: "br"}
								  ]
							  }]
						  }
					  ]
				  }]
			}
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

			/* Mock some data requests */

			this.handleGetPreferenceValuesResponse(null, {
				"timeZone": [
					{ "Country": "Samoa", "CountryCode": "WS", "ZoneID": "Pacific\/Apia", "City": "Apia", "Description": "West Samoa Time", "offsetFromUTC": 780, "supportsDST": 1, "preferred": true }, 
					{ "Country": "United States of America", "CountryCode": "US", "ZoneID": "America\/Adak", "City": "Adak", "Description": "Hawaii-Aleutian Time", "offsetFromUTC": -600, "supportsDST": 1, "preferred": true }, 
					{ "Country": "French Polynesia", "CountryCode": "PF", "ZoneID": "Pacific\/Tahiti", "City": "Tahiti", "Description": "Tahiti Time", "offsetFromUTC": -600, "supportsDST": 0 }
				]});

			this.handleGetPreferencesResponse(null, {
				timeFormat: "HH12",
				timeZone: { "Country": "French Polynesia", "CountryCode": "PF", "ZoneID": "Pacific\/Tahiti", "City": "Tahiti", "Description": "Tahiti Time", "offsetFromUTC": -600, "supportsDST": 0 },
				useNetworkTime: true
			});

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
			this.$.mdts1.setStyle("padding: 35px 5% 0 5%;");
			this.$.mdts2.setStyle("padding: 10px 5% 8px 5%;");
			this.$.TimeZonePicker.setStyle("padding: 35px 5% 8px 5%;");
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
			this.$.SetSystemPreferences.send({timeFormat: inSender.selected.content === "12 Hour" ? "HH12" : "HH24"});
		}
		else {
			this.log(inSender.selected);
		}

		if (typeof(this.$.TimePicker) !== "undefined")
			this.$.TimePicker.setIs24HrMode(inSender.selected.content !== "12 Hour");
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
	listItemTapped: function(inSender, inEvent) {
		var newTimeZone = this.timeZones[inEvent.index];
		if (this.palm) {
			this.$.SetSystemPreferences.send({timeZone: newTimeZone});
		}
		this.currentTimeZone = newTimeZone;
		this.log("New time zone is " + newTimeZone.ZoneID);
		this.$.TimeZoneItem.setContent(this.currentTimeZone.ZoneID);
		this.showMainDateTimePanel();
	},
	setupTimeZoneRow: function (inSender, inEvent) {
		var cntry = this.timeZones[inEvent.index].Country;
		var offset = this.timeZones[inEvent.index].offsetFromUTC;
		var cty = this.timeZones[inEvent.index].City;
		var dscrptn = this.timeZones[inEvent.index].Description;
		// Want offset in hours and minutes
		var hrs = offset / 60;
		var ihrs = parseInt(hrs, 10);
		var mnts = Math.abs(offset) - Math.abs(ihrs) * 60;
		if (hrs !== 0) {
			offset = "UTC" + (ihrs >= 0 ? "+" : "") +
				ihrs + ":" + (mnts < 10 ? "0" : "") + mnts;
		} else {
			offset = "UTC";
		}
		// Manage troublesome cases
		if (!cty || cty.length === 0) {
			cty = cntry; // Just for something to display
		}
		// Strip off redundant country leader (if present)
		var tmpstr = cntry + "\/";
		if (cty.indexOf(tmpstr) === 0) {
			cty = cty.slice(tmpstr.length);
		}
		if (enyo.Panels.isScreenNarrow()) {
			// Verbose state names (No!)
			var ndstr = "North Dakota\/";
			var kystr = "Kentucky\/";
			var instr = "Indiana\/";
			if (cty.indexOf(ndstr) === 0) {
				cty = "ND\/" + cty.slice(ndstr.length);
			} else if (cty.indexOf(kystr) === 0) {
				cty = "KY\/" + cty.slice(kystr.length);
			} else if (cty.indexOf(instr) === 0) {
				cty = "IN\/" + cty.slice(instr.length);
			}
			// Ref. http://www.timeanddate.com/time/zones/
			if (dscrptn === "Fernando de Noronha Time") {
				dscrptn = "FNT";
			} else if (dscrptn === "Saint Pierre and Miquelon Standard Time") {
				dscrptn = "Pierre &amp; Miquelon Standard Time";
			}
			// Arbitrary hack. Looks OK on a Nexus 4.
			if (cntry.length >= 31) {
				cntry = cntry.slice(0,28) + "&hellip;";
			}
		}
		this.$.TZCountry.setContent(cntry);
		this.$.TZOffset.setContent(offset);
		this.$.TZCity.setContent(cty);
		this.$.TZDescription.setContent(dscrptn);
		return true;
	},
	showTimeZonePicker: function(inSender, inEvent) {
		this.$.DateTimePanels.setIndex(1);
	},
	showMainDateTimePanel: function(inSender, inEvent) {
		this.$.DateTimePanels.setIndex(0);
	},
	handleBackGesture: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		if (this.$.DateTimePanels.getIndex() > 0) {
			this.$.DateTimePanels.setIndex(0);
		} else {
			this.doBackbutton();
		}
	},
	//Service Callbacks
	handleGetPreferencesResponse: function(inSender, inResponse) {
		if(inResponse.timeFormat !== undefined) {
			this.$.TimeFormatPicker.setSelected(this.$.TimeFormatPicker.getClientControls()[inResponse.timeFormat === "HH12" ? 0 : 1]);
		}

		if(inResponse.useNetworkTime !== undefined)
			this.$.NetworkTimeToggle.setValue(inResponse.useNetworkTime);

		if(inResponse.timeZone !== undefined) {
			this.currentTimeZone = inResponse.timeZone;
			this.$.TimeZoneItem.setContent(this.currentTimeZone.ZoneID);
		}

		this.updateTimeControlStates();
	},
	handleGetPreferenceValuesResponse: function(inSender, inResponse) {
		if (inResponse["timeZone"] !== undefined) {
			this.timeZones = inResponse["timeZone"];
			this.$.TimeZonesList.setCount(this.timeZones.length);
		}
	}
});
