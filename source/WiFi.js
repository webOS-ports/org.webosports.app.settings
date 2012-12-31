enyo.kind({
	name: "WiFiService",
	kind: "enyo.webOS.ServiceRequest",
	service: "palm://com.palm.wifi/"
});

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

/*
{name: "SetRadioState",
kind: "WiFiService",
method: "setstate",
onFailure: "handleSetStateFailure"},

{name: "GetConnectionStatus",
kind: "WiFiService",
method: "getstatus",
subscribe: true,
resubscribe: true,
onResponse: "handleWiFiConnectionStatus"},

{name: "FindNetworks",
kind: "WiFiService",
method: "findnetworks",
onResponse: "handleFindNetworksResponse"},

{name: "Connect",
kind: "WiFiService",
method: "connect",
onResponse: "handleConnectResponse"},

{name: "GetProfileInfo",
kind: "WiFiService",
method: "getprofile",
onResponse: "handleProfileInfoResponse"},

{name: "GetWiFiInfo",
kind: "WiFiService",
method: "getinfo",
onSuccess: "handleWiFiInfoResponse"},

{name: "DeleteProfile",
kind: "WiFiService", 
method: "deleteprofile",
onFailure: "handleDeleteProfileFailure"},
*/

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
			{name: "RescanButton",
			kind: "onyx.Button",
			content: "Rescan",
			style: "float: right;",
			ontap: "rescan"},
		]}
	],
	//Handlers
	create: function(inSender, inEvent) {
		this.inherited(arguments);
		if(window.PalmSystem) {
			//Query the initial connection status
			var getConnectionStatus = new WiFiService({method: "getstatus"});
			getConnectionStatus.response(this, "handleInitWiFiConnectionStatus");
			getConnectionStatus.go();
			
			//Subscribe to the connection status service
			var getConnectionStatus = new WiFiService({method: "getstatus", subscribe: true, resubscribe: true});
			getConnectionStatus.response(this, "handleWiFiConnectionStatus");
			getConnectionStatus.go();
			
			this.palm = true;
		}
		else {
			enyo.log("Non-palm platform, service requests disabled.");
		}
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
		//enyo.log("Toggle Button Changed, value:" + inEvent.value);
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
			var setRadioState = new WiFiService({method: "setstate"});
			//setRadioState.error(this, "handleSetStateFailure");
			setRadioState.go({"state": "enabled"});
		}
	},
	deactivateWiFi: function(inSender, inEvent) {
		if(this.palm) {
			var setRadioState = new WiFiService({method: "setstate"});
			//setRadioState.error(this, "handleSetStateFailure");
			setRadioState.go({"state": "disabled"});
		}
	},
	rescan: function(inSender, inEvent) {
		if(this.palm) {
			var findNetworks = new WiFiService({method: "findnetworks"});
			findNetworks.response(this, "handleFindNetworksResponse");
			findNetworks.go();
		}
		else
			this.handleFindNetworksResponse(this, this.phonyFoundNetworks);
	},
	connect: function(inSender, inEvent) {
		if(!this.palm)
			return;

		var ssid = this.currentSSID;
		var password = inEvent.password;
		var hidden = false;
		
		var connect = new WiFiService({method: "connect"});
		connect.response(this, "handleConnectResponse");
		
		if(security.indexOf('psk') > -1 || security.indexOf('wep') > -1) {
			enyo.log("Connecting to PSK network");
			var obj = {
				"ssid": ssid,
				"security": {
					"securityType": "",
					"simpleSecurity": {
						"passKey": password
					}
				}
			};
			enyo.log(JSON.stringify(obj));
			connect.go(obj);
		}
		else if(security.indexOf('enterprise') > -1) {
			enyo.log("Not implemented.");
		}
		else {
			enyo.log("Connecting to unsecured network");
			var obj = {
				"ssid": ssid
			};
			enyo.log(JSON.stringify(obj));
			connect.go(obj);
		}
	},
	//Utility Functions
	clearFoundNetworks: function() {
		this.foundNetworks = [];
		this.$.SearchRepeater.setCount(this.foundNetworks.length);
	},
	//Service Callbacks
	handleInitWiFiConnectionStatus: function(inSender, inResponse) {
		//enyo.log(JSON.stringify(inResponse));
		
		this.$.WiFiToggle.setValue(true);
		this.$.RescanButton.setDisabled(false);
		//Rescanning won't work immediately, so wait a couple of seconds before calling it
		var storedThis = this;
		setTimeout(function() { storedThis.rescan(); }, 2000);
	},
	handleWiFiConnectionStatus: function(inSender, inResponse) {
		//enyo.log(JSON.stringify(inResponse));
		
		if(inResponse.status == "serviceDisabled") {
			this.$.WiFiToggle.setValue(false);
			this.$.RescanButton.setDisabled(true);
			this.clearFoundNetworks();
		}
		else if(inResponse.status == "serviceEnabled") {
			this.$.WiFiToggle.setValue(true);
			this.$.RescanButton.setDisabled(false);
		//Rescanning won't work immediately, so wait a couple of seconds before calling it
			var storedThis = this;
			setTimeout(function() { storedThis.rescan(); }, 2000);
		}
	},
	handleFindNetworksResponse: function(inSender, inResponse) {
		//enyo.log(JSON.stringify(inResponse));
		
		if(inResponse.foundNetworks) {
			this.foundNetworks = inResponse.foundNetworks;
			this.$.SearchRepeater.setCount(this.foundNetworks.length);
		}
		else {
			this.clearFoundNetworks();
		}
	},
	handleConnectResponse: function(inSender, inResponse) {
		//enyo.log(JSON.stringify(inResponse));
	}
});
