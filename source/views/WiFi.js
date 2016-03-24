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
            "security": [ "psk", "wps" ],
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
    // Hidden networks are found (as it were!)
    // but should be hidden from the user
    foundNetworks: [],
    foundHiddenNetworks: [],
    events: {
        onActiveChanged: "",
        onBackbutton: ""
    },
    palm: false,
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
                                                    ontap: "networkListItemTapped"
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
				    name: "UsernameGroupbox",
                                    components: [
                                        {
                                            kind: "onyx.GroupboxHeader",
                                            content: "Username"
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            alwaysLooksFocused: true,
                                            components: [
                                                {
                                                    name: "UsernameInput",
                                                    placeholder: "Type here...",
                                                    kind: "onyx.Input"
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
                                            content: "Password"
                                        },
                                        {
                                            kind: "onyx.InputDecorator",
                                            alwaysLooksFocused: true,
                                            components: [
                                                {
                                                    name: "PasswordInput",
                                                    placeholder: "Type here...",
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
                                    ontap: "onConnectTapped"
                                },
                                {
                                    kind: "onyx.Button",
                                    content: "Cancel",
                                    ontap: "onConnectCancelTapped"
                                }
                            ]
                        }
                    ]
                },
                /* Join other [hidden] network panel */
                {
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
                                                        {
                                                            name: "OpenSecurityItem",
                                                            content: "Open"
                                                        },
                                                        {
                                                            name: "WPAPerSecurityItem",
                                                            content: "WPA-Personal",
                                                            active: true
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
                                    ontap: "onOtherJoinCancelTapped"
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
                                    ontap: "showNetworksListPanel"
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
    create: function () {
        this.inherited(arguments);

        this.log();

        // If we're outside the webOS system add some entries for easier testing.
        if (!window.PalmSystem) {
            // More interesting to pretend that WiFi is enabled.
            this.showThatWiFiIsEnabled();
            this.foundNetworks = phonyFoundNetworks;
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
            return;
        }

        this.palm = true;
        if (!navigator.WiFiManager)
            return;

        navigator.WiFiManager.onenabled = enyo.bind(this, "handleWiFiEnabled");
        navigator.WiFiManager.ondisabled = enyo.bind(this, "handleWiFiDisabled");
        navigator.WiFiManager.onnetworkschange = enyo.bind(this, "handleWiFiNetworksChanged");

	if (navigator.WiFiManager.enabled) {
	    this.updateSpinnerState("start");
	    this.showThatWiFiIsEnabled();
            navigator.WiFiManager.retrieveNetworks(enyo.bind(this, "handleRetrieveNetworksResponse"),
						   enyo.bind(this, "handleRetrieveNetworksFailed"));
	} else {
	    this.showThatWiFiIsDisabled();
	}
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
    showThatWiFiIsEnabled: function() {
        this.$.WiFiToggle.silence();
        this.$.WiFiToggle.setValue(true);
        this.$.WiFiToggle.unsilence();
        this.showNetworksListPanel();
        this.doActiveChanged({value: true});
    },
    showThatWiFiIsDisabled: function() {
        this.$.WiFiToggle.silence();
        this.$.WiFiToggle.setValue(false);
        this.$.WiFiToggle.unsilence();
        this.showWiFiDisabledPanel();
        this.doActiveChanged({value: false});
    },
    //Action Handlers
    toggleButtonChanged: function (inSender, inEvent) {
        if (inEvent.value === true) {
	    if (navigator.WiFiManager)
		navigator.WiFiManager.enabled = true;
	    this.updateSpinnerState("start");
	    // Handled by navigator.onenabled on device.
	    if (!this.palm)
		this.showNetworksListPanel();
        } else {
	    if (navigator.WiFiManager)
		navigator.WiFiManager.enabled = false;
	    // Handled by navigator.ondisabled on device.
	    if (!this.palm)
		this.showWiFiDisabledPanel();
	}
	// Handled by navigator.onenabled/disabled on device.
	if (!this.palm)
            this.doActiveChanged(inEvent);
    },
    networkListItemTapped: function (inSender, inEvent) {
        var selectedNetwork = this.foundNetworks[inEvent.index];

	for (var i in selectedNetwork) {
	    this.log(i + ": " + selectedNetwork[i]);
	}

        // Show the configuration for a connected network.
        // Otherwise, try to connect.

        if (selectedNetwork.state !== "idle" &&
            selectedNetwork.state !== "failure") {
            this.$.NetworkConfiguration.currentNetwork = {
                path: selectedNetwork.path
            };
            this.showNetworkConfigurationPanel();
            return;
        }

        if (selectedNetwork.security.contains("none")) {
            this.log("Connecting to open network...");
            this.connectNetwork({
                path: selectedNetwork.path,
                password: ""
            });
        } else {
            this.log("Connecting to secured network...");
            this.targetNetwork = {
		path: selectedNetwork.path
            };
	    // Only show the username field if we need it.
	    if (selectedNetwork.security.contains("ieee8021x")) {
		this.$.UsernameGroupbox.show();
		this.targetNetwork.security = ["ieee8021x"];
	    } else {
		this.$.UsernameGroupbox.hide();
	    }
            this.$.PopupSSID.setContent(selectedNetwork.name);
            this.showNetworkConnectPanel(); // Where PopupSSID is.
        }
    },
    onJoinButtonTapped: function (inSender, inEvent) {
	this.showJoinNetworkPanel();
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
    onConnectTapped: function (inSender, inEvent) {
	var password = this.$.PasswordInput.getValue();
	var passwordPlausible = this.validatePassword(password);
        if (!passwordPlausible) {
	    this.showError("Entered password is invalid");
        } else {
	    this.targetNetwork.password = password;
	    if (this.targetNetwork.security !== undefined &&
		this.targetNetwork.security.contains("ieee8021x")) {
		var username = this.$.UsernameInput.getValue();
		this.targetNetwork.user = username;
	    }
            this.connectNetwork(this.targetNetwork);

            this.showNetworksListPanel();
	    delete password;
	    delete this.targetNetwork.password;
            this.$.PasswordInput.setValue("");
	}
    },
    onConnectCancelTapped: function (inSender, inEvent) {
        this.showNetworksListPanel();
        this.$.PasswordInput.setValue("");
    },
    onOtherJoinConnectTapped: function(inSender, inEvent) {
	if (this.$.ssidInput.getValue() !== "") {
            this.targetNetwork = {
		name: this.$.ssidInput.getValue(),
		security: ["none"]
            };

	    var requiredSec = this.$.SecurityTypePicker.getSelected().getContent();
	    if (requiredSec === "WPA-Personal") {
		this.$.UsernameGroupbox.hide();
		this.targetNetwork.security = ["psk"];
	    } else if (requiredSec === "WEP") {
		this.$.UsernameGroupbox.hide();
		this.targetNetwork.security = ["wep"];
	    } else if (requiredSec === "Enterprise") {
		this.$.UsernameGroupbox.show();
		this.targetNetwork.security = ["ieee8021x"];
	    }

	    var i;
	    for (i = 0; i < this.foundHiddenNetworks.length; ++i) {
		// If we have found a hidden network with the right
		// kind of security, chances are this is the one
		// we mean. (Hmmm.)
	        if (this.foundHiddenNetworks[i].security.contains(
		    this.targetNetwork.security[0])) {
	            this.targetNetwork.path = this.foundHiddenNetworks[i].path;
		    break;
	        }
	    }

	    if (this.targetNetwork.path === undefined) {
		this.showError("No such network is present");
		return;
	    }

            if (!this.targetNetwork.security.contains("none")) {
		this.$.PopupSSID.setContent(this.targetNetwork.name);
		this.showNetworkConnectPanel();
            } else {
		this.log("Connecting to open network " + this.targetNetwork.name);
		this.connectNetwork(this.targetNetwork);
            }
	}
    },
    onOtherJoinCancelTapped: function (inSender, inEvent) {
        this.showNetworksListPanel();

        this.$.ssidInput.setValue("");
        this.$.SecurityTypePicker.setSelected(this.$.WPAPerSecurityItem);
    },
    //Action Functions
    showWiFiDisabledPanel: function () {
        this.$.WiFiPanels.setIndex(0);
    },
    showNetworksListPanel: function (inSender, inEvent) {
        this.$.WiFiPanels.setIndex(1);
    },
    showNetworkConnectPanel: function () {
        this.$.WiFiPanels.setIndex(2);
    },
    // Our jargon: We Connect to known networks and Join hidden ones.
    showJoinNetworkPanel: function() {
        this.$.WiFiPanels.setIndex(3);
    },
    showNetworkConfigurationPanel: function () {
        this.$.WiFiPanels.setIndex(4);
    },
    // Called by our parent in response to user action.
    setToggleValue: function (value) {
        this.$.WiFiToggle.setValue(value);
    },
    showError: function (message) {
	this.updateSpinnerState("stop");
        this.$.ErrorMessage.setContent(message);
        this.$.ErrorPopup.show();
    },
    handleNetworkConnectSucceeded: function(inSender, inEvent) {
	this.log();
    },
    handleNetworkConnectFailed: function(inSender, inEvent) {
	this.log();
    },
    connectNetwork: function (network) {
        if (!this.palm)
            return;

        navigator.WiFiManager.connectNetwork(network,
                                             enyo.bind(this, "handleNetworkConnectSucceeded"),
                                             enyo.bind(this, "handleNetworkConnectFailed"));
    },
    forgetNetwork: function(inSender, inEvent) {
        var network = this.$.NetworkConfiguration.currentNetwork;

        navigator.WiFiManager.removeNetwork(network.path);

	this.updateSpinnerState("start");
        this.showNetworksListPanel();
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
	    this.updateSpinnerState("stop");
	}else if(this.$.WiFiPanels.getIndex() === 1 ||
		 this.$.WiFiPanels.getIndex() === 0){
	    this.doBackbutton();
	    this.updateSpinnerState("stop");
	}
    },

    //Utility Functions
    clearFoundNetworks: function () {
        this.foundNetworks = [];
        this.foundHiddenNetworks = [];
        this.$.SearchRepeater.setCount(this.foundNetworks.length);
    },
    validatePassword: function (key) {
        var pass = false;
        if (8 <= key.length && 63 >= key.length) {
            pass = true;
        }

        return pass;
    },
    // WiFiManager Callbacks
    handleWiFiNetworksChanged: function(networks) {
        this.handleRetrieveNetworksResponse(networks);
    },
    handleRetrieveNetworksResponse: function(networks) {
        this.clearFoundNetworks();
        if (networks) {
            this.updateSpinnerState("stop");
	    var i;
	    for (i = 0; i < networks.length; ++i) {
		if (networks[i].name === undefined ||
		    networks[i].name === null ||
		    networks[i].name === "") {
		    this.foundHiddenNetworks.push(networks[i]);
		} else {
		    this.foundNetworks.push(networks[i]);
		}
	    }
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
        }
    },
    handleRetrieveNetworksFailed: function() {
	this.log();
        this.clearFoundNetworks();
    },
    handleWiFiEnabled: function() {
        this.showThatWiFiIsEnabled();
    },
    handleWiFiDisabled: function() {
        this.showThatWiFiIsDisabled();
    }
});
