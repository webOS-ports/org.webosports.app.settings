enyo.kind({
	name: "DateTime",
	layoutKind: "FittableRowsLayout",
	palm: false,
	components:[
		{kind: "Signals", ondeviceready: "deviceready"},
		{kind: "onyx.Toolbar",
		style: "line-height: 36px;",
		components:[
				{content: "Date & Time"},
		]},
		{kind: "Scroller",
		touch: true,
		horizontal: "hidden",
		vertical: "auto",
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
						//DEBUG: Disabled until we have network time functionality
						{name: "NetworkTimeToggle", kind: "onyx.ToggleButton", disabled: true, style: "float: right;", onChange: "networkTimeChanged"}
				
					]},
					{classes: "group-item",
					components:[
						{content: "Current Time",
						fit: true,
						style: "line-height: 42px;"},
						{name: "TimeDrawer", kind: "onyx.Drawer", open: true, components:[
							{content: "Date", style: "display: inline-block;"},
							{name: "DatePicker", kind: "onyx.DatePicker", style: "display: inline-block", onSelect: "dateTimeChanged"},
							{content: "Time", style: "display: inline-block;"},
							{name: "TimePicker", kind: "onyx.TimePicker", style: "display: inline-block", onSelect: "dateTimeChanged"}
						]}
				
					]},
					/*
					{classes: "group-item",
					style: "height: 42px;",
					components:[
						{content: "Timezone",
						fit: true,
						style: "display: inline-block; line-height: 42px;"},
				
					]},
					*/
				]},
			]},
		]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(!window.PalmSystem)
			enyo.log("Non-palm platform, service requests disabled.");
	},
	deviceready: function(inSender, inEvent) {
		this.inherited(arguments);
		
	        var request = navigator.service.Request("luna://com.palm.systemservice/",
		{
			method: 'getPreferences',
			parameters: {keys: ["timeFormat", "timeZone", "useNetworkTime"]},
			onSuccess: enyo.bind(this, "handleGetPreferencesResponse")
		});
		
		//DEBUG: No network time functionality yet, so don't use it
	        var request = navigator.service.Request("luna://com.palm.systemservice/",
		{
			method: 'setPreferences',
			parameters: {useNetworkTime: false, receiveNetworkTimeUpdates: false}
		});
		
		this.palm = true;
	},
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
	timeFormatChanged: function(inSender, inEvent) {
		if(this.palm) {
			var request = navigator.service.Request("luna://com.palm.systemservice/",
			{
				method: 'setPreferences',
				parameters: {timeFormat: inSender.selected.content == "12 Hour" ? "HH12" : "HH24"}
			});
		}
		else {
			enyo.log(inSender);
		}
		
		this.$.TimePicker.setIs24HrMode(inSender.selected.content != "12 Hour");
	},
	networkTimeChanged: function(inSender, inEvent) {
		if(this.palm) {
			var request = navigator.service.Request("luna://com.palm.systemservice/",
			{
				method: 'setPreferences',
				parameters: {useNetworkTime: inSender.value, receiveNetworkTimeUpdates: inSender.value}
			});
		}
		else {
			enyo.log(inSender.value);
		}
		
		this.$.TimeDrawer.setOpen(!inSender.value);
	},
	dateTimeChanged: function(inSender, inEvent) {
		var timeObj = {};
		timeObj.utc = inEvent.value.getTime()/1000;
		if(this.palm) {
			var request = navigator.service.Request("luna://com.palm.systemservice/time/",
			{
				method: 'setSystemTime',
				parameters: timeObj
			});
			
			var request = navigator.service.Request("luna://com.palm.systemservice/",
			{
				method: 'setPreferences',
				parameters: {useNetworkTime: false, receiveNetworkTimeUpdates: false}
			});
		}
		else {
			enyo.log(timeObj);
		}
	},
	//Service Callbacks
	handleGetPreferencesResponse: function(inResponse) {
		if(inResponse.timeFormat != undefined) {
			this.$.TimeFormatPicker.setSelected(this.$.TimeFormatPicker.getClientControls()[inResponse.timeFormat == "HH12" ? 0 : 1]);
		}
			
		if(inResponse.useNetworkTime != undefined)
			this.$.NetworkTimeToggle.setValue(inResponse.useNetworkTime);
			
		if(inResponse.timeZone != undefined) {}
			//Set time zone
	},
});
