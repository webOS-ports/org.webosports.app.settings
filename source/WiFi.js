enyo.kind({
	name: "WiFiListItem",
	classes: "group-item",
	layoutKind: "FittableColumnsLayout",
	handlers: {
		onmousedown: "pressed",
		ondragstart: "released",
		onmouseup: "released"
	},
	components:[
		{name: "SSID", content: "SSID", fit: true},
		{name: "Padlock", content: "Secured"},
		{name: "Signal", content: "Signal", style: "margin-left: 8px;"}
	],
	pressed: function() {
		this.addClass("onyx-selected");
	},
	released: function() {
		this.removeClass("onyx-selected");
	}
});

enyo.kind({
	name: "WiFiService",
	kind: "enyo.PalmService",
	service: "palm://com.palm.wifi/"
});

enyo.kind({
	name: "WiFi",
	layoutKind: "FittableRowsLayout",
	phonyFoundNetworks: {
		"foundNetworks": [
			{
			    "networkInfo": {
				"ssid": "BTWiFi",
				"availableSecurityTypes": [
				    "none"
				],
				"signalBars": 2,
				"signalLevel": 77,
				"connectState": "ipConfigured"
			    }
			},
			{
			    "networkInfo": {
				"ssid": "BTWiFi-with-FON",
				"availableSecurityTypes": [
				    "none"
				],
				"signalBars": 2,
				"signalLevel": 69
			    }
			},
			{
			    "networkInfo": {
				"ssid": "SKY13476",
				"availableSecurityTypes": [
				    "psk"
				],
				"signalBars": 2,
				"signalLevel": 86
			    }
			},
			{
			    "networkInfo": {
				"ssid": "BTHub3-8MP5",
				"availableSecurityTypes": [
				    "psk"
				],
				"signalBars": 1,
				"signalLevel": 64
			    }
			}
		],
		"returnValue": true
	},
	foundNetworks: [],
	events: {
		onActiveChanged: ""
	},
	currentSSID: "",
	palm: false,
	findNetworksRequest: null,
	components: [
		{name: "PasswordPopup",
		kind: "onyx.Popup",
		modal: true,
		classes: "password-popup",
		onShow: "popupShown",
		components:[
			{content: "Enter password for", style: "display: inline;"},
			{name: "PopupSSID", content: "SSID", style: "margin-left: 4px; display: inline;"},
			{kind: "onyx.InputDecorator", style: "display: block; margin-top: 16px;", components:[
				{name: "PasswordInput", kind: "onyx.Input", type: "password", style: "width: 100%", onkeypress: "passwordKeyPress"}
			]},
		]},
		
		{kind: "onyx.Toolbar",
		style: "line-height: 28px;",
		components:[
				{content: "Wi-Fi"},
				{name: "WiFiToggle", kind: "onyx.ToggleButton", style: "position: absolute; top: 8px; right: 6px; height: 31px;", onChange: "toggleButtonChanged"}
		]},
		{name: "WiFiPanels",
		kind: "Panels",
		arrangerKind: "HFlipArranger",
		fit: true,
		draggable: false,
		components:[
				{name: "SearchList",
				layoutKind: "FittableRowsLayout",
				style: "padding: 35px 10% 35px 10%;",
				components:[
					{kind: "onyx.GroupboxHeader", style: "border-radius: 8px 8px 0 0;", content: "Choose a Network"},
					{kind: "Scroller",
					touch: true,
					horizontal: "hidden",
					fit: true,
					style: "border: 1px solid white; border-top: 0; border-radius: 0 0 8px 8px;",
					components:[
						{name: "SearchRepeater",
						kind: "Repeater",
						count: 0,
						onSetupItem: "setupSearchRow",
						components: [
							{kind: "WiFiListItem", ontap: "listItemTapped"}
						]}
					]},
				]},
				{name: "KnownList",
				layoutKind: "FittableRowsLayout",
				style: "padding: 35px 10% 35px 10%;",
				components:[
					{kind: "onyx.GroupboxHeader", style: "border-radius: 8px 8px 0 0;", content: "Known Networks"},
					{kind: "Scroller",
					touch: true,
					horizontal: "hidden",
					fit: true,
					style: "border: 1px solid white; border-top: 0; border-radius: 0 0 8px 8px;",
					components:[
						{kind: "Repeater", count: 1, components: [
							{kind: "WiFiListItem", ontap: "listItemTapped"}
						]}
					]},
				]},
				{ /* Workaround for HFlipArranger incorrectly displaying with 2 panels*/ }
		]},
		{kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
			{kind: "onyx.RadioGroup",
			style: "position: absolute; bottom: 3px; left: 50%; margin-left: -76px;",
			components:[
				{content: "Search", active: true, ontap: "showSearch"},
				{content: "Known", ontap: "showKnown"}
			]},
			{name: "NewButton",
			kind: "onyx.IconButton",
			src: "assets/icon-new.png",
			style: "float: right;",
			ontap: ""},
		]},
		{
			name: "FindNetworks",
			kind: "WiFiService",
			method: "findnetworks",
			subscribe: true,
			resubscribe: true,
			onResponse: "handleFindNetworksResponse"
		},
		{
			name: "GetWiFiStatus",
			kind: "WiFiService",
			method: "getstatus",
			subscribe: true,
			resubscribe: true,
			onResponse: "handleWiFiStatus"
		},
		{
			name: "SetWiFiState",
			kind: "WiFiService",
			method: "setstate"
		},
		{
			name: "Connect",
			kind: "WiFiService",
			method: "connect",
			onResponse: "handleConnectResponse"
		}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);

		if(!window.PalmSystem)
			return;

		this.palm = true;
		this.$.GetWiFiStatus.send({});
		this.$.FindNetworks.send({});
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow())
			this.$.Grabber.applyStyle("visibility", "hidden");
		else
			this.$.Grabber.applyStyle("visibility", "visible");
	},
	//Action Handlers
	toggleButtonChanged: function(inSender, inEvent) {
		if(inEvent.value == true)
			this.activateWiFi(this);
		else
			this.deactivateWiFi(this);

		this.doActiveChanged(inEvent);
	},
	listItemTapped: function(inSender, inEvent) {
		this.currentSSID = inSender.$.SSID.content;
		
		if(inSender.$.Padlock.content != "none") {
			this.$.PopupSSID.setContent(this.currentSSID);
			this.$.PasswordPopup.show();
		}
		else {
			this.connect(this, {ssid: inSender.$.SSID.content});
		}
	},
	setupSearchRow: function(inSender, inEvent) {
		inEvent.item.$.wiFiListItem.$.SSID.setContent(this.foundNetworks[inEvent.index].networkInfo.ssid);
		inEvent.item.$.wiFiListItem.$.Padlock.setContent(this.foundNetworks[inEvent.index].networkInfo.availableSecurityTypes);
		inEvent.item.$.wiFiListItem.$.Signal.setContent(this.foundNetworks[inEvent.index].networkInfo.signalBars);
	},
	popupShown: function(inSender, inEvent) {
		inSender.children[2].hasNode().focus();
	},
	passwordKeyPress: function(inSender, inEvent) {
		//If return pressed
		if(inEvent.keyCode == 13) {
			this.$.PasswordPopup.hide();
			
			var p = inSender.getValue();
			this.connect(this, {ssid: this.currentSSID, password: p});
			
			inSender.setValue("");
			delete p;
		}
	},
	//Action Functions
	showSearch: function(inSender, inEvent) {
		this.$.WiFiPanels.setIndex(0);
	},
	showKnown: function(inSender, inEvent) {
		this.$.WiFiPanels.setIndex(1);
	},
	setToggleValue: function(value) {
		this.$.WiFiToggle.setValue(value);
	},
	activateWiFi: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetWiFiState.send({"state":"enabled"});
		}
	},
	deactivateWiFi: function(inSender, inEvent) {
		if(this.palm) {
			this.$.SetWiFiState.send({"state":"disabled"});
		}
	},
	connect: function(inSender, inEvent) {
		if(!this.palm)
			return;

		var ssid = this.currentSSID;
		var password = inEvent.password;
		var hidden = false;
		
		var obj = {};
		
		if(password != "") {
			enyo.log("Connecting to PSK network");
			obj = {
				"ssid": ssid,
				"security": {
					"securityType": "",
					"simpleSecurity": {
						"passKey": password
					}
				}
			};
		}
		/*
			TODO: Enterprise support when it becomes available
		*/
		else {
			enyo.log("Connecting to unsecured network");
			obj = {
				"ssid": ssid
			};
		}
		
		var request = navigator.service.Request("luna://com.palm.wifi/",
		{
			method: 'connect',
			parameters: obj
		});
	},
	//Utility Functions
	clearFoundNetworks: function() {
		this.foundNetworks = [];
		this.$.SearchRepeater.setCount(this.foundNetworks.length);
	},
	//Service Callbacks
	handleWiFiStatus: function(inSender, inResponse) {
		var result = inResponse.data;

		if (!result)
			return;

		if(result.status == "serviceDisabled") {
			this.$.WiFiToggle.setValue(false);
			this.clearFoundNetworks();
		}
		else if(result.status == "serviceEnabled") {
			this.$.WiFiToggle.setValue(true);
		}
	},
	handleFindNetworksResponse: function(inSender, inResponse) {
		var result = inResponse.data;
		if (result.foundNetworks) {
			this.foundNetworks = result.foundNetworks;
			this.$.SearchRepeater.setCount(this.foundNetworks.length);
		}
		else {
			this.clearFoundNetworks();
		}
	},
	handleConnectResponse: function(inSender, inResponse) {
		var result = inResponse.data;
	}
});
