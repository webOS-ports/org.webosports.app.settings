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
	currentSecurity: "",
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
		try {
			//Subscribe to the connection status service
			var getConnectionStatus = new WiFiService({method: "getstatus", subscribe: true, resubscribe: true});
			getConnectionStatus.response(this, "handleWiFiConnectionStatus");
			getConnectionStatus.go();
			this.palm = true;
		}
		catch(e) {
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
		if(inEvent.value == true)
			this.activateWiFi();
		else
			this.deactivateWiFi();
			
		this.doActiveChanged(inEvent);
	},
	listItemTapped: function(inSender, inEvent) {
		this.currentSSID = inSender.$.SSID.content;
		this.currentSecurity = inSender.$.Padlock.content;
		
		if(this.currentSecurity != "none") {
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
			var p = inSender.getValue();
			inSender.setValue("");
			this.$.PasswordPopup.hide();
			this.connect(this, {ssid: this.currentSSID, security: this.currentSecurity, password: p});
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
		var security = this.currentSecurity;
		var password = inEvent.password;
		var hidden = false;
		
		var connect = new WiFiService({method: "connect"});
		connect.response(this, "handleConnectResponse");
		
		//Unsecured
		if(security.indexOf('psk') > -1) {
			enyo.log("Connecting to PSK network");
			var obj = {
				"ssid": ssid,
				"wasCreatedWithJoinOther": hidden,
				"security": {
					"securityType": security,
					"simpleSecurity": {
						"passKey": password,
						"isInHex": this.isKeyInHex(security, password)
					}
				}
			};
			enyo.log(JSON.stringify(obj));
			connect.go(obj);
		}
		else if(security.indexOf('wep') > -1) {
			enyo.log("Connecting to WEP network");
			var obj = {
				"ssid": ssid,
				"wasCreatedWithJoinOther": hidden,
				"security": {
					"securityType": security,
					"simpleSecurity": {
						"passKey": password,
						"keyIndex": 0, //Ranges from 0-3, hardcoded to 0 for now
						"isInHex": this.isKeyInHex(security, password)
					}
				}
			};
			enyo.log(JSON.stringify(obj));
			connect.go(obj);
		}
		else {
			enyo.log("Connecting to unsecured network");
			var obj = {
				"ssid": ssid,
				"wasCreatedWithJoinOther": hidden
			};
			enyo.log(obj);
			connect.go(obj);
		}
		/* No certificate management yet
		else if(security.indexOf('enterprise') > -1) {
			if ("eapTls" === this.$.eapTypeList.getValue() &&
					undefined !== this.$.certificateList.getValue()) {
				this.$.Connect.call({"ssid": ssid,
					"wasCreatedWithJoinOther": hidden,
					"security": {"securityType": security,
						"enterpriseSecurity": {"userId": username,
							"password": password,
							"eapType": this.$.eapTypeList.getValue(),
							"verifyServerCert": this.$.certVerifyCheckbox.getChecked(),
							"clientCertificatePath": this.certItems[this.$.certificateList.getValue()].path}}});
			} else {
				this.$.Connect.call({"ssid": ssid,
					"wasCreatedWithJoinOther": hidden,
					"security": {"securityType": security,
						"enterpriseSecurity": {"userId": username,
							"password": password,
							"eapType": this.$.eapTypeList.getValue(),
							"verifyServerCert": this.$.certVerifyCheckbox.getChecked()}}});
			}
		}
			
		else if(security.indexOf('wapi-cert') > -1) {
			connect.go({
				"ssid": ssid,
				"wasCreatedWithJoinOther": hidden,
				"security": {
					"securityType": security,
					"simpleSecurity": {
						"rootCert": this.certItems[this.$.wapiRootCertificateList.getValue()].path,
						"userCert": this.certItems[this.$.wapiUserCertificateList.getValue()].path
					}
				}
			});
		}
		*/
	},
	//Utility Functions
	isKeyInHex: function (type, key) {
		var hexPattern = new RegExp('^[A-Fa-f0-9]*$'),
			isInHex = false;

		if (hexPattern.test(key)) {
			if ("wep" === type &&
					(10 === key.length || 26 === key.length)) {
				isInHex = true;
			} else if ("psk" === type &&
					64 === key.length) {
				isInHex = true;
			}
		}

		return isInHex;
	},
	//Service Callbacks
	handleWiFiConnectionStatus: function(inSender, inResponse) {
		enyo.log(JSON.stringify(inResponse));
		if(inResponse.status == "serviceDisabled") {
			this.$.WiFiToggle.setValue(false);
			this.$.RescanButton.setDisabled(true);
		}
		else {
			this.$.WiFiToggle.setValue(true);
			this.$.RescanButton.setDisabled(false);
		}
		
		if(this.$.WiFiToggle.value == true)
			this.rescan();
	},
	handleFindNetworksResponse: function(inSender, inResponse) {
		enyo.log(JSON.stringify(inResponse));
		this.foundNetworks = inResponse.foundNetworks;
		this.$.SearchRepeater.setCount(this.foundNetworks.length);
	},
	handleConnectResponse: function(inSender, inResponse) {
		enyo.log(JSON.stringify(inResponse));
	}
});
