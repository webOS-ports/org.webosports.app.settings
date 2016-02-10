/*jslint sloppy: true, stupid: true */

Array.prototype.contains = function(obj) {
    var i = this.length;
    while (i--) {
        if (this[i] === obj) {
            return true;
        }
    }
    return false;
};

enyo.kind({
	name: "WiFiListItem",
	classes: "group-item-wrapper",
	components: [
	{
		classes: "group-item",
		layoutKind: "enyo.FittableRowsLayout",
		components: [
		{
			kind: "enyo.FittableColumns",
			fit: true,
			components: [
				{
					name: "SSID",
					content: "SSID"
				}, //ssid
				{
					kind: "enyo.FittableColumns",
					style: "float: right; height: 44px;",
					components: [
					{
						name: "Active",
						kind: "Image",
						src: "assets/wifi/checkmark.png",
						showing: false,
						classes: "wifi-list-icon"
					},
					{
						name: "Padlock",
						kind: "Image",
						src: "assets/secure-icon.png",
						showing: false,
						classes: "wifi-list-icon"
					},
					{
						name: "Signal",
						kind: "Image",
						src: "assets/wifi/signal-icon.png",
						classes: "wifi-list-icon"
					}]
				} // icons
			]
		},
		{
			kind: "enyo.FittableColumns",
			fit: true,
			components: [
			{
				name: "StatusMessage",
				content: "",
				classes: "wifi-message-status",
				showing: false,
				style: "padding-top: 10px;"
			},
			{
				name: "spin",
				kind: "onyx.Spinner",
				showing: false,
				style: "padding: 30px; float: right;",
				classes: "onyx-light"
			}]
		}]
	}
	],
	handlers: {
		onmousedown: "pressed",
		ondragstart: "released",
		onmouseup: "released"
	},
	pressed: function() {
		this.addClass("onyx-selected");
	},
	released: function() {
		this.removeClass("onyx-selected");
	}
});

var phonyFoundNetworks = [
    {
            "name": "BTWiFi",
            "security": [ "none" ],
            "strength": 77,
            "state": "ready"
    },
    {
            "name": "BTWiFi-with-FON",
            "security": [ "none" ],
            "strength": 69,
            "state": "idle"
    },
    {
            "name": "NONAME",
            "state": "idle",
            "security": [ "psk" ],
            "strength": 86
    },
    {
            "name": "SKY13476",
            "state": "association",
            "security": [ "psk" ],
            "strength": 86
    },
    {
            "name": "BTHub3-8MP5",
            "security": [ "psk" ],
            "strength": 64,
            "state": "failure"
    },
    {
            "name": "open-net",
            "security": [ "none" ],
            "strength": 70,
            "state": "idle"
    }
];

enyo.kind({
    name: "WiFi",
    layoutKind: "FittableRowsLayout",
    foundNetworks: null,
    events: {
        onActiveChanged: "",
        onBackbutton: ""
    },
    currentSSID: "",
    palm: false,
    findNetworksRequest: null,
    autoscan: null,
    debug: false,
    components: [
	
        /* Error popup */
        {
            name: "ErrorPopup",
            kind: "onyx.Popup",
            classes: "error-popup",
            modal: true,
            style: "padding: 10px;",
            components: [
                {
                    name: "ErrorMessage",
                    content: "",
                    style: "display: inline;"
                }
            ]
        },

        /* Top toolbar */
        {
            kind: "onyx.Toolbar",
            layoutKind: "FittableColumnsLayout",
            style: "line-height: 28px;",
            components: [
                {
                    content: "Wi-Fi"
                }, // This is hacky
                {
                    fit: true
                },
                {
                    name: "WiFiToggle",
                    kind: "onyx.ToggleButton",
                    onChange: "toggleButtonChanged",
                    showing: "true",
                    style: "height: 31px;"
                }
            ]
        },
        /* WiFi Panels */
        {
            name: "WiFiPanels",
            kind: "Panels",
            arrangerKind: "HFlipArranger",
            fit: true,
            draggable: false,
            components: [
                /* WiFi disabled panel */
                {
                    name: "WiFiDisabled",
                    layoutKind: "FittableRowsLayout",
                    style: "padding: 35px 10% 35px 10%;",
                    components: [{
                            style: "padding-bottom: 10px;",
                            components: [{
                                    content: "WiFi is disabled",
                                    style: "display: inline;"
                            }]
                        }
                    ]
                },
                /* Network list panel */
                {
                    kind: "enyo.FittableRows",
                   	components: [
                        {
                            name: "NetworkList",
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            style: "padding: 35px 10% 35px 10%;",
                            fit: true,
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    content: "Choose a Network"
                                },
                                {
                                    classes: "networks-scroll",
                                    kind: "Scroller",
                                    touch: true,
                                    horizontal: "hidden",
                                    fit: true,
                                    components: [{
                                            name: "SearchRepeater",
                                            kind: "Repeater",
                                            count: 0,
                                            onSetupItem: "setupSearchRow",
                                            components: [
                                                {
                                                    kind: "WiFiListItem",
                                                    ontap: "listItemTapped"
                                                }
                                            ]
                                    }]
                                },
                                {name: "networkSearch", kind: "enyo.FittableColumns", showing: false, classes: "wifi-join-button", components: [
				    {content: "Searching for networks", fit: true, classes: "networkSearch"},
				    {name: "spin2",	kind: "onyx.Spinner", showing: true, style: "padding: 30px;", classes: "onyx-light" },
                                ]},				//network search spinner
                                {
                                    name: "JoinButton",
                                    kind: "enyo.FittableColumns",
                                    classes: "wifi-join-button",
                                    components: [
                                        {
                                            kind: "Image",
                                            src: "assets/wifi/join-plus-icon.png"
                                        },
                                        {
                                            content: "Join Network",
                                            fit: true
                                        },
                                        
                                    ],
                                    ontap: "onJoinButtonTapped",
                                    handlers: {
                                        onmousedown: "pressed",
                                        ondragstart: "released",
                                        onmouseup: "released"
                                    },
                                    pressed: function () {
                                        this.addClass("onyx-selected");
                                    },
                                    released: function () {
                                        this.removeClass("onyx-selected");
                                    }
                                },
                               
                            ]
						}]
                },
                /* Network connect panel */
                {
                    name: "NetworkConnect",
                    layoutKind: "FittableRowsLayout",
                    classes: "content-wrapper",
                    components: [
                        {
                            classes: "content-aligner",
                            components: [
                                {
                                    classes: "content-heading",
                                    components: [
                                        {
                                            content: "Join ",
                                            tag: "span"
                                        },
                                        {
                                            name: "PopupSSID",
                                            tag: "span",
                                            content: "SSID",
                                            style: "font-weight: bold;"
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "onyx.GroupboxHeader",
                                            content: "Password"
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            alwaysLooksFocused: true,
                                            components: [
                                                {
                                                    name: "PasswordInput",
                                                    placeholder: "Type here ..",
                                                    kind: "onyx.Input",
                                                    type: "password"
                                                }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Button",
                                    classes: "onyx-affirmative",
                                    content: "Connect",
                                    ontap: "onNetworkConnect"
                                },
                                {
                                    kind: "onyx.Button",
                                    content: "Cancel",
                                    ontap: "onNetworkConnectAborted"
                                }
                            ]
                        }
                    ]
                },
                /* Join network panel */
                {
                    name: "NewNetworkJoin",
                    layoutKind: "FittableRowsLayout",
                    classes: "content-wrapper",
                    components: [
                        {
                            classes: "content-aligner",
                            components: [
                                {
                                    content: "Join Other Network",
                                    classes: "content-heading"
                                },
                                {
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "onyx.GroupboxHeader",
                                            content: "Network Name"
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            alwaysLooksFocused: true,
                                            components: [
                                                {
                                                    name: "ssidInput",
                                                    placeholder: "Enter Network Name",
                                                    kind: "onyx.Input",
                                                    type: "text"
                                                }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "onyx.GroupboxHeader",
                                            content: "Network Security"
                                        },
                                        {
                                            kind: "onyx.PickerDecorator",
                                            alwaysLooksFocused: true,
                                            components: [
                                                {},
                                                {
                                                    name: "SecurityTypePicker",
                                                    style: "max-width:170px; margin-top:41px; left:auto !important; right:0 !important;",
                                                    kind: "onyx.Picker",
                                                    components: [
                                                        //TODO: load dynamically
                                                        {
                                                            name: "OpenSecurityItem",
                                                            content: "Open",
                                                            active: true
                                                        },
                                                        {
                                                            content: "WPA-Personal"
                                                        },
                                                        {
                                                            content: "WEP"
                                                        },
                                                        {
                                                            content: "Enterprise"
                                                        }
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Button",
                                    classes: "onyx-affirmative",
                                    content: "Connect",
                                    ontap: "onOtherJoinConnectTapped"
                                },
                                {
                                    kind: "onyx.Button",
                                    content: "Cancel",
                                    ontap: "onOtherJoinCancelled"
                                },
                            ]
                        },
                    ]
                },
                /* Network configuration panel */
                {
                    name: "NetworkConfiguration",
                    layoutKind: "FittableRowsLayout",
                    classes: "content-wrapper",
                    currentNetwork: null,
                    components: [
                        {
                            classes: "content-aligner",
                            components: [
                                {
                                    classes: "content-heading",
                                    content: "Network Info goes here..."
                                },
                                {
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "FittableColumns",
                                            classes: "group-item",
                                            style: "height: 40px; padding-top: 15px;",
                                            components: [
                                                {
                                                    content: "Automatic IP Setings",
                                                    fit: true
                                                },
                                                {
                                                    kind: "onyx.ToggleButton",
                                                    value: true,
                                                    style: "height: 31px;"
                                                },
                                            ]
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "onyx.InputDecorator",
                                            layoutKind: "FittableColumnsLayout",
                                            components: [
                                                {
                                                    name: "AddressInput",
                                                    kind: "onyx.Input",
                                                    fit: true
                                                },
                                                {
                                                    content: "Address",
                                                    classes: "config - label"
                                                }
                                            ]
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            layoutKind: "FittableColumnsLayout",
                                            components: [
                                                {
                                                    name: "SubnetInput",
                                                    kind: "onyx.Input",
                                                    fit: true
                                                },
                                                {
                                                    content: "Subnet",
                                                    classes: "config-label"
                                                }
                                            ]
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            layoutKind: "FittableColumnsLayout",
                                            components: [
                                                {
                                                    name: "GatewayInput",
                                                    kind: "onyx.Input",
                                                    fit: true
                                                },
                                                {
                                                    content: "Gateway",
                                                    classes: "config-label"
                                                }
                                            ]
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            layoutKind: "FittableColumnsLayout",
                                            components: [
                                                {
                                                    name: "DNSServerInput1",
                                                    kind: "onyx.Input",
                                                    fit: true
                                                },
                                                {
                                                    content: "DNS Server",
                                                    classes: "config-label"
                                                }
                                            ]
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            layoutKind: "FittableColumnsLayout",
                                            components: [
                                                {
                                                    name: "DNSServerInput2",
                                                    kind: "onyx.Input",
                                                    fit: true
                                                },
                                                {
                                                    content: "DNS Server",
                                                    classes: "config-label"
                                                }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Button",
                                    classes: "onyx-negative",
                                    content: "Forget Network",
                                    ontap: "forgetNetwork"
                                },
                                {
                                    kind: "onyx.Button",
                                    content: "Done",
                                    ontap: "showNetworksList"
                                },
                            ]
                        },
                    ]
                },
                
                { /* Workaround for HFlipArranger incorrectly displaying with 2 panels*/ },
            ]
            
        },
        /* Bottom toolbar */
        {
            kind: "onyx.Toolbar",
            layoutKind: "FittableColumnsLayout",
            components: [
                {
                    name: "Grabber",
                    kind: "onyx.Grabber"
                }, // this is hacky
                {
                    fit: true
                },
            ]
        },
    ],
    //Handlers
    create: function () {
        this.inherited(arguments);

        this.log("WiFi: created");

        if (!window.PalmSystem) {
            // WiFi is enabled by default
            this.handleWiFiEnabled();
            // If we're outside the webOS system add some entries for easier testing.
            this.foundNetworks = phonyFoundNetworks;
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
            return;
        }

        this.palm = true;

        if (!navigator.WiFiManager)
            return;

        // Not much seems to happen if the WiFi status is changed
        // outside of the Settings app.
        navigator.WiFiManager.onenabled = enyo.bind(this, "handleWiFiEnabled");
        navigator.WiFiManager.ondisabled = enyo.bind(this, "handleWiFiDisabled");
        navigator.WiFiManager.onnetworkschange = enyo.bind(this, "handleWiFiNetworksChanged");

//        if (navigator.WiFiManager.enabled) {
//            this.handleWiFiEnabled();
//        }

        this.doActiveChanged({value: navigator.WiFiManager.enabled});
        this.updateSpinnerState("start");
    },
    reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
            this.$.NetworkList.setStyle("padding: 35px 5% 35px 5%;");
            this.$.Grabber.applyStyle("visibility", "hidden");
        }else{
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },
    //Action Handlers
    toggleButtonChanged: function (inSender, inEvent) {
        if (inEvent.value == true){
            this.activateWiFi();
        } else{
            this.deactivateWiFi();
            this.managepopup = false;
       }
        this.doActiveChanged(inEvent);
    },
    listItemTapped: function (inSender, inEvent) {
        var selectedNetwork = this.foundNetworks[inEvent.index];

        // Don't try to connect to already connected or connecting network.
        if (selectedNetwork.state != "idle" && selectedNetwork.state != "failure") {
            this.$.NetworkConfiguration.currentNetwork = {
                path: selectedNetwork.path
            };
            this.showNetworkConfiguration();
            return;
        }

        this.currentNetwork = {
            ssid: selectedNetwork.name,
            path: selectedNetwork.path,
            security: selectedNetwork.security
        };

        // When the network does not have any security configured it will always
        // have the "none" security type set.
        if (!this.currentNetwork.security.contains("none")) {
            this.log("Connecting to secured network");
            this.$.PopupSSID.setContent(this.currentNetwork.ssid);
            this.showNetworkConnect();
        } else {
            this.log("Connect to open network");
            this.connectNetwork({
                path: this.currentNetwork.path,
                password: ""
            });
        }
    },
    triggerWifiConnect: function () {
        var i, path = "";
        for (i = 0; i < this.foundNetworks.length; i++) {
            if (this.foundNetworks[i].name === this.wifiTarget.ssid) {
                path = this.foundNetworks[i].path;
		break;
            }
        }
        this.currentNetwork = {
            ssid: this.wifiTarget.ssid,
            path: path,
            security: this.wifiTarget.securityType
        };
        this.connecting = true;
        this.$.PopupSSID.setContent(this.currentNetwork.ssid);
        this.showNetworkConnect();
    },
    onJoinButtonTapped: function (inSender, inEvent) {
	this.showJoinNetwork();
    },
    signalStrengthToBars: function(strength) {
        if(strength > 0 && strength < 34)
            return 1;
        else if(strength >= 34 && strength < 50)
            return 2;
        else if(strength >= 50)
            return 3;
        return 0;
    },
    setupSearchRow: function (inSender, inEvent) {
    	var ssid = "";
	// For the narrow page only, shorten a long SSID.
    	if(enyo.Panels.isScreenNarrow()){
    	    if(this.foundNetworks[inEvent.index].name.length >= 18){
    		ssid = this.foundNetworks[inEvent.index].name.slice(0,18) + "...";
    	    }else{
    		ssid = this.foundNetworks[inEvent.index].name;
    	    }
    	}else{
    	    ssid = this.foundNetworks[inEvent.index].name;
    	}
    	
        inEvent.item.$.wiFiListItem.$.SSID.setContent( ssid );

        switch (this.foundNetworks[inEvent.index].state) {
        case "association":
        case "configuration":
            inEvent.item.$.wiFiListItem.$.Active.setShowing(false);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setShowing(true);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setContent("Connecting...");
            inEvent.item.$.wiFiListItem.$.spin.setShowing(true);
            break;
        case "ready":

        case "online":
            inEvent.item.$.wiFiListItem.$.Active.setShowing(true);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setShowing(false);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setContent("");
            inEvent.item.$.wiFiListItem.$.spin.setShowing(false);
        	break;
        case "failure":
            inEvent.item.$.wiFiListItem.$.Active.setShowing(false);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setShowing(true);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setContent("Association failed!");
            inEvent.item.$.wiFiListItem.$.spin.setShowing(false);
            break;
        case "idle":
        default:
            inEvent.item.$.wiFiListItem.$.Active.setShowing(false);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setShowing(false);
            inEvent.item.$.wiFiListItem.$.StatusMessage.setContent("");
            inEvent.item.$.wiFiListItem.$.spin.setShowing(false);
            break;
        }

        if (!this.foundNetworks[inEvent.index].security.contains("none")) {
            inEvent.item.$.wiFiListItem.$.Padlock.setShowing(true);
        }

        if (this.foundNetworks[inEvent.index].strength) {
            var bars = this.signalStrengthToBars(this.foundNetworks[inEvent.index].strength);
            inEvent.item.$.wiFiListItem.$.Signal.setSrc("assets/wifi/signal-icon-" + bars + ".png");
	}
    },
//    setupKnownNetworkRow: function (inSender, inEvent) {
//    	var ssid = "";
//	if(enyo.Panels.isScreenNarrow()){
//	    // if the SSID is longer shorten it for the narrow page only
//    	    if(this.foundNetworks[inEvent.index].name.length >= 18){
//    		ssid = this.foundNetworks[inEvent.index].name.slice(0,18) + "..";
//    	    }else{
//    		ssid = this.foundNetworks[inEvent.index].name;
//    	    }
//    	}else{
//    	    ssid = this.foundNetworks[inEvent.index].name;
//    	}
//        inEvent.item.$.wiFiListItem.$.SSID.setContent( ssid );
//        inEvent.item.$.wiFiListItem.$.Security.setContent(this.knownNetworks[inEvent.index].security);
//        inEvent.item.$.wiFiListItem.$.Signal.setShowing(false);
//    },
    onNetworkConnect: function (inSender, inEvent) {
	var name = "";
	if (this.currentNetwork.name !== "") {
	    name = this.currentNetwork.name;
	}

	var password = this.$.PasswordInput.getValue();
	var passwordPlausible = this.validatePassword(password);

        if (!passwordPlausible) {
	    this.showError("Entered password is invalid");
        } else {
            this.connectNetwork({
                path: this.currentNetwork.path,
                password: password,
		name: name
            });

            // Switch back to network list view
            this.showNetworksList();
	    delete password;
            this.$.PasswordInput.setValue("");
	    delete name;
	}
    },
    onNetworkConnectAborted: function (inSender, inEvent) {
        // switch back to network list view
        this.showNetworksList();

        this.$.PasswordInput.setValue("");
    },
    onOtherJoinConnectTapped: function(inSender, inEvent) {
	if (this.$.ssidInput.getValue() !== "") {
            this.currentNetwork = {
		ssid: this.$.ssidInput.getValue(),
		path: "", // How do we get this from the ssid?
		// hidden: true; // In fact, you could type a known ssid.
		security: ["none"],
		name: this.$.ssidInput.getValue()
            };
	    var requiredSec = this.$.SecurityTypePicker.getSelected().getContent();
	    if (requiredSec === "WPA-Personal" ||
		requiredSec === "WEP") {
		this.currentNetwork.security = ["psk"];
	    }

	    var path = "";
	    var i;
	    for (i = 0; i < this.foundNetworks.length; ++i) {
	        if (this.foundNetworks[i].name === "") {
	            path = this.foundNetworks[i].path;
	            this.log("Found hidden network:", path);
	            this.log("Found hidden network security:",
			     this.foundNetworks[i].security);
	            this.log("Searching for hidden network security[0]:",
			     this.currentNetwork.security[0]);
		    // If we have found a hidden network with the right
		    // kind of security, chances are this is the one
		    // we mean. (Hmmm.)
	            if (this.foundNetworks[i].security.contains(
			this.currentNetwork.security[0])) {
	                this.currentNetwork.path = path;
			break;
	            }
	        }
	    }

	    // Cannot connect to a network without a path.
	    if (this.currentNetwork.path === "") {
		this.log("We did not find the hidden network.");
		return;
	    }

            if (!this.currentNetwork.security.contains("none")) {
		this.log("Connecting to secured network");
		this.$.PopupSSID.setContent(this.$.ssidInput.getValue());
		this.showNetworkConnect();
            } else {
		this.log("Connect to open network");
		this.connectNetwork({
                    path: this.currentNetwork.path,
                    password: "",
		    name: this.currentNetwork.name
		});
            }
	}
    },
    onOtherJoinCancelled: function (inSender, inEvent) {
        // switch back to network list view
        this.showNetworksList();

        this.$.ssidInput.setValue("");
        this.$.SecurityTypePicker.setSelected(this.$.OpenSecurityItem);
    },
    //Action Functions
    showWiFiDisabled: function () {
        this.stopAutoscan();
        this.$.WiFiPanels.setIndex(0);
    },
    showNetworksList: function (inSender, inEvent) {
	this.updateSpinnerState("start");
        return this.$.WiFiPanels.setIndex(1);
    },
    showNetworkConnect: function () {
        this.$.WiFiPanels.setIndex(2);
        this.stopAutoscan();
    },
    showJoinNetwork: function() {
        this.$.WiFiPanels.setIndex(3);
        this.stopAutoscan();
    },
    showNetworkConfiguration: function () {
        this.$.WiFiPanels.setIndex(4);
        this.stopAutoscan();
    },
    // Called by our parent.
    setToggleValue: function (value) {
        this.$.WiFiToggle.setValue(value);
    },
    showError: function (message) {
	this.updateSpinnerState();
        this.$.ErrorMessage.setContent(message);
        this.$.ErrorPopup.show();
    },
    activateWiFi: function () {
	this.updateSpinnerState("start");
        this.showNetworksList();
	if (!navigator.WiFiManager)
            return;
        navigator.WiFiManager.enabled = true;
    },
    deactivateWiFi: function () {
        this.showWiFiDisabled();
        if (!navigator.WiFiManager)
            return;
        navigator.WiFiManager.enabled = false;
    },
    handleNetworkConnectSucceeded: function(inSender, inEvent) {
	this.log();
    },
    handleNetworkConnectFailed: function(inSender, inEvent) {
	this.log();
    },
    connectNetwork: function (network) {
        this.log(network);

        if (!this.palm)
            return;

        var networkToConnect = {
            path: network.path,
            hidden: false,
            security: "",
            password: "",
	    name: ""
        };

        if (network.password != "") {
            this.log("Connecting to PSK network");
            networkToConnect.security = "psk";
            networkToConnect.password = network.password;
        } else {
            this.log("Connecting to unsecured network");
        }

        if (network.name != "") {
            this.log("Connecting to hidden network");
            networkToConnect.name = network.name;
	    // Need to look up its path.
	    // I believe it should be in the list.
        }

        navigator.WiFiManager.connectNetwork(networkToConnect,
                                             enyo.bind(this, "handleNetworkConnectSucceeded"),
                                             enyo.bind(this, "handleNetworkConnectFailed"));

        this.triggerAutoscan();
    },
    forgetNetwork: function(inSender, inEvent) {
        var network = this.$.NetworkConfiguration.currentNetwork;

        navigator.WiFiManager.removeNetwork(network.path);

        this.showNetworksList();
    },
    updateSpinnerState: function(action) {
	if (action === "start"){
	    this.$.networkSearch.show();
	}else{
	    this.$.networkSearch.hide();
	}
    },
    handleBackGesture: function() {
	if(this.$.WiFiPanels.getIndex() > 1){
	    this.$.WiFiPanels.setIndex(1);
	    this.updateSpinnerState();				// stop the spinner
	}else if( this.$.WiFiPanels.getIndex() === 1 ||
		  this.$.WiFiPanels.getIndex() === 0){
	    this.doBackbutton();
	    this.updateSpinnerState();				// stop the spinner
	}
    },

    //Utility Functions
    clearFoundNetworks: function () {
        this.foundNetworks = [];
        this.$.SearchRepeater.setCount(this.foundNetworks.length);
    },
    validatePassword: function (key) {
        var pass = false;

        if (8 <= key.length && 63 >= key.length) {
            pass = true;
        }

        return pass;
    },
    startAutoscan: function() {
	if (null === this.autoscan) {
            this.log("Starting autoscan ...");
            this.autoscan = window.setInterval(enyo.bind(this, "triggerAutoscan"), 15000);
            if (!this.foundNetworks) {
                this.triggerAutoscan();
                this.log("this.triggerAutoscan();");
            }
        }
    },
    triggerAutoscan: function(inSender, inEvent) {
	this.updateSpinnerState("start");
	if (!navigator.WiFiManager)
            return;
        navigator.WiFiManager.retrieveNetworks(enyo.bind(this, "handleRetrieveNetworksResponse"),
                                               enyo.bind(this, "handleRetrieveNetworksFailed"));
    },
    stopAutoscan: function() {
        if (null !== this.autoscan) {
            this.log("Stopping autoscan ...");
            window.clearInterval(this.autoscan);
            this.autoscan = null;
        }
        this.updateSpinnerState();
    },
    //Service Callbacks
    handleRetrieveNetworksResponse: function (networks) {
        this.clearFoundNetworks();
        if (networks) {
            this.foundNetworks = networks;
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
            if (this.wifiTarget && this.connecting != true) {
                this.triggerWifiConnect();
            }
        }
    },
    handleRetrieveNetworksFailed: function() {
	log.this(); // Worth a mention. Surely?
        this.clearFoundNetworks();
    },
    // Not convinced this happens if the WiFi status is changed
    // outside of the Settings app.
    handleWiFiEnabled: function() {
        this.$.WiFiToggle.setValue(true);
        this.$.WiFiPanels.setIndex(1);
        this.startAutoscan();
    },
    handleWiFiDisabled: function() {
        this.$.WiFiPanels.setIndex(0);
        this.$.WiFiToggle.setValue(false);
        this.stopAutoscan();
    },
    handleWiFiNetworksChanged: function(networks) {
        this.handleRetrieveNetworksResponse(networks);
        this.stopAutoscan();
    },
    
});
