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
	name: "BluetoothListItem",
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
    name: "Bluetooth",
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
                    content: "Bluetooth"
                }, // This is hacky
                {
                    fit: true
                },
                {
                    name: "BluetoothToggle",
                    kind: "onyx.ToggleButton",
                    onChange: "toggleButtonChanged",
                    showing: "true",
                    style: "height: 31px;"
                }
            ]
        },
        /* Bluetooth Panels */
        {
            name: "BluetoothPanels",
            kind: "Panels",
            arrangerKind: "HFlipArranger",
            fit: true,
            draggable: false,
            components: [
                /* Bluetooth disabled panel */
                {
                    name: "BluetoothDisabled",
                    layoutKind: "FittableRowsLayout",
                    style: "padding: 35px 10% 35px 10%;",
                    components: [{
                            style: "padding-bottom: 10px;",
                            components: [{
                                    content: "Bluetooth is disabled",
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
                                    content: "Choose a Network",
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
                                                    kind: "BluetoothListItem",
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
                                    ontap: ""
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

        this.log("Bluetooth: created");

        if (!window.PalmSystem) {
            // Bluetooth is enabled by default
            this.handleBluetoothEnabled();
            // if we're outside the webOS system add some entries for easier testing
            this.foundNetworks = phonyFoundNetworks;
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
            return;
        }

        this.palm = true;

        console.log(navigator);
        if (!navigator.BluetoothManager)
            return;

        navigator.BluetoothManager.onenabled = enyo.bind(this, "handleBluetoothEnabled");
        navigator.BluetoothManager.ondisabled = enyo.bind(this, "handleBluetoothDisabled");
        navigator.BluetoothManager.onnetworkschange = enyo.bind(this, "handleBluetoothNetworksChanged");

//        if (navigator.BluetoothManager.enabled) {
//            this.handleBluetoothEnabled();
//        }

        this.doActiveChanged({value: navigator.BluetoothManager.enabled});
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
            this.activateBluetooth(this);
        } else{
            this.deactivateBluetooth(this);
            this.managepopup = false;
       }
        this.doActiveChanged(inEvent);
    },
    listItemTapped: function (inSender, inEvent) {
        var selectedNetwork = this.foundNetworks[inEvent.index];

        // don't try to connect to already connected or connecting network
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
        // have the "none" security type set
        if (!this.currentNetwork.security.contains("none")) {
            this.log("Connecting to secured network");
            this.$.PopupSSID.setContent(this.currentNetwork.ssid);
            this.showNetworkConnect();
        } else {
            this.log("Connect to open network");
            this.connectNetwork(this, {
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
    	if(enyo.Panels.isScreenNarrow()){
    		if(this.foundNetworks[inEvent.index].name.length >= 18){					// if the SSID is longer shorten it for the narrow page only
    			ssid = this.foundNetworks[inEvent.index].name.slice(0,18) + "..";
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
            inEvent.item.$.wiFiListItem.$.StatusMessage.setContent("Connecting ...");
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
    setupKnownNetworkRow: function (inSender, inEvent) {
    	var ssid = "";	
		if(enyo.Panels.isScreenNarrow()){
    		if(this.foundNetworks[inEvent.index].name.length >= 18){					// if the SSID is longer shortten it for the narrow page only
    			ssid = this.foundNetworks[inEvent.index].name.slice(0,18) + "..";
    		}else{
    			ssid = this.foundNetworks[inEvent.index].name;
    		}
    	}else{
    		ssid = this.foundNetworks[inEvent.index].name;
    	}
        inEvent.item.$.wiFiListItem.$.SSID.setContent( ssid );
        inEvent.item.$.wiFiListItem.$.Security.setContent(this.knownNetworks[inEvent.index].security);
        inEvent.item.$.wiFiListItem.$.Signal.setShowing(false);
    },
    onNetworkConnect: function (inSender, inEvent) {
		var password = this.$.PasswordInput.getValue();
		
        if (this.validatePassword(password)) {
            this.connectNetwork(this, {
                path: this.currentNetwork.path,
                password: password
            });
        } else {
			this.showError("Entered password is invalid");
        }

        // switch back to network list view
        this.showNetworksList();
		delete password;
        this.$.PasswordInput.setValue("");
    },
    onNetworkConnectAborted: function (inSender, inEvent) {
        // switch back to network list view
        this.showNetworksList(inSender, inEvent);

        this.$.PasswordInput.setValue("");
    },
    onOtherJoinCancelled: function (inSender, inEvent) {
        // switch back to network list view
        this.showNetworksList(inSender, inEvent);

        this.$.ssidInput.setValue("");
        this.$.SecurityTypePicker.setSelected(this.$.OpenSecurityItem);
    },
    //Action Functions
    showBluetoothDisabled: function (inSender, inEvent) {
        this.stopAutoscan();
        this.$.BluetoothPanels.setIndex(0);
    },
    showNetworksList: function (inSender, inEvent) {
		this.updateSpinnerState("start");
        return this.$.BluetoothPanels.setIndex(1);
    },
    showNetworkConnect: function (inSender, inEvent) {
        this.$.BluetoothPanels.setIndex(2);
        this.stopAutoscan();
    },
    showJoinNetwork: function(inSender, inEvent) {
        this.$.BluetoothPanels.setIndex(3);
        this.stopAutoscan();
    },
    showNetworkConfiguration: function (inSender, inEvent) {
        this.$.BluetoothPanels.setIndex(4);
        this.stopAutoscan();
    },
    setToggleValue: function (value) {
        this.$.BluetoothToggle.setValue(value);
    },
    showError: function (message) {
		this.updateSpinnerState();
        this.$.ErrorMessage.setContent(message);
        this.$.ErrorPopup.show();
    },
    activateBluetooth: function (inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		this.updateSpinnerState("start");
        this.showNetworksList();
		if (!navigator.BluetoothManager)
            return;
        navigator.BluetoothManager.enabled = true;
    },
    deactivateBluetooth: function (inSender, inEvent) {
        this.showBluetoothDisabled();
        if (!navigator.BluetoothManager)
            return;
        navigator.BluetoothManager.enabled = false;
    },
    handleNetworkConnectSucceeded: function() {
	},
    handleNetworkConnectFailed: function() {
	},
    connectNetwork: function (inSender, inEvent) {
        this.log("connectNetwork", inEvent);

        if (!this.palm)
            return;

        var networkToConnect = {
            path: inEvent.path,
            hidden: false,
            security: "",
            password: ""
        };

        if (inEvent.password != "") {
            this.log("Connecting to PSK network");
            networkToConnect.security = "psk";
            networkToConnect.password = inEvent.password;
        }
        else {
            this.log("Connecting to unsecured network");
        }

        navigator.BluetoothManager.connectNetwork(networkToConnect,
                                             enyo.bind(this, "handleNetworkConnectSucceeded"),
                                             enyo.bind(this, "handleNetworkConnectFailed"));

        this.triggerAutoscan();
    },
    forgetNetwork: function(inSender, inEvent) {
        var network = this.$.NetworkConfiguration.currentNetwork;

        navigator.BluetoothManager.removeNetwork(network.path);

        this.showNetworksList();
    },
    updateSpinnerState: function(action) {
		this.log("action:", action);
		
		if (action === "start" ){
			this.$.networkSearch.show();
		}else{
			this.$.networkSearch.hide();
		}
    },

    handleBackGesture: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);	
		
		if(this.$.BluetoothPanels.getIndex() > 1){
			this.$.BluetoothPanels.setIndex(1);
			this.updateSpinnerState();					// stop the spinner
		}else{
			if( this.$.BluetoothPanels.getIndex() === 1 || this.$.BluetoothPanels.getIndex() === 0){
				this.doBackbutton();
				this.updateSpinnerState();				// stop the spinner
			}
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
    startAutoscan: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		if (null === this.autoscan) {
            this.log("Starting autoscan ...");
            this.autoscan = window.setInterval(enyo.bind(this, "triggerAutoscan"), 15000);
            if (!this.foundNetworks) {
                this.triggerAutoscan();
                this.log("this.triggerAutoscan();");
            }
        }
    },
    triggerAutoscan: function() {
		this.updateSpinnerState("start");
		if (!navigator.BluetoothManager)
            return;
        navigator.BluetoothManager.retrieveNetworks(enyo.bind(this, "handleRetrieveNetworksResponse"),
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
        this.log(networks);
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
        this.clearFoundNetworks();
    },
    handleBluetoothEnabled: function() {
        this.$.BluetoothToggle.setValue(true);
        this.$.BluetoothPanels.setIndex(1);
        this.startAutoscan();
    },
    handleBluetoothDisabled: function() {
        this.$.BluetoothPanels.setIndex(0);
        this.$.BluetoothToggle.setValue(false);
        this.stopAutoscan();
    },
    handleBluetoothNetworksChanged: function(networks) {
        this.handleRetrieveNetworksResponse(networks);
        this.stopAutoscan();
    },
    
});
