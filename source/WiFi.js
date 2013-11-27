enyo.kind({
    name: "WiFiListItem",
    classes: "group-item-wrapper",
    components: [
        {
            classes: "group-item",
            layoutKind: "FittableColumnsLayout",
            components: [
                {
                    name: "SSID",
                    content: "SSID",
                    fit: true
                },
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
                    src: "assets/wifi/secure-icon.png",
                    showing: false,
                    classes: "wifi-list-icon"
                },
                {
                    name: "SecurityType",
                    classes: "wifi-list-icon"
                },
                {
                    name: "Signal",
                    kind: "Image",
                    src: "assets/wifi/signal-icon.png",
                    classes: "wifi-list-icon"
                }
            ],
        }],
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
});

enyo.kind({
    name: "WiFiService",
    kind: "enyo.PalmService",
    service: "palm://com.palm.wifi/"
});

enyo.kind({
    name: "WiFi",
    layoutKind: "FittableRowsLayout",
    phonyFoundNetworks: [
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
    foundNetworks: [],
    events: {
        onActiveChanged: ""
    },
    currentSSID: "",
    palm: false,
    findNetworksRequest: null,
    components: [
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
                },
            ]
  },
        {
            kind: "onyx.Toolbar",
            style: "line-height: 28px;",
            components: [
                {
                    content: "Wi-Fi"
                },
                {
                    name: "WiFiToggle",
                    kind: "onyx.ToggleButton",
                    style: "position: absolute; top: 8px; right: 6px; height: 31px;",
                    onChange: "toggleButtonChanged"
                }
            ]
        },
        {
            name: "WiFiPanels",
            kind: "Panels",
            arrangerKind: "HFlipArranger",
            fit: true,
            draggable: false,
            components: [
                {
                    name: "WiFiDisabled",
                    layoutKind: "FittableRowsLayout",
                    style: "padding: 35px 10% 35px 10%;",
                    components: [{
                            style: "padding-bottom: 10px;",
                            components: [{
                                    content: "WiFi is disabled",
                                    style: "display: inline;"
                    },
                            ]
                        }
                    ]
                },
                {
                    kind: "enyo.FittableRows",
                    classes: "content-wrapper",
                    components: [
                        {
                            name: "NetworkList",
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            classes: "content-aligner",
                            fit: true,
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    classes: "group-header",
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
                                        }
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
                                }
                            ]
                }]
                },
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
                {
                    name: "Settings",
                    layoutKind: "FittableRowsLayout",
                    classes: "content-wrapper",
                    components: [
                        {
                            classes: "content-aligner",
                            components: [{
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "onyx.GroupboxHeader",
                                            content: "When Device Sleeps"
                                        },
                                        {
                                            kind: "onyx.PickerDecorator",
                                            alwaysLooksFocused: true,
                                            components: [
                                                {},
                                                {
                                                    name: "SleepBehaviourPicker",
                                                    style: "max-width:170px; margin-top:41px; left:auto !important; right:0 !important;",
                                                    kind: "onyx.Picker",
                                                    components: [
                                     //TODO: get current state

                                                        {
                                                            content: "Keep Wi-Fi On",
                                                            active: true
                                                        },
                                                        {
                                                            content: "Turn Wi-Fi Off"
                                                        }
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    kind: "onyx.Button",
                                    content: "Back",
                                    ontap: "showNetworksList"
                                },
                            ]
                        },
                    ]
    },
                { /* Workaround for HFlipArranger incorrectly displaying with 2 panels*/ }
            ]
        },
        {
            kind: "onyx.Toolbar",
            components: [
                {
                    name: "Grabber",
                    kind: "onyx.Grabber"
                },
            ]
        },
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
  },
        {
            name: "WiFiServiceWatch",
            kind: "enyo.PalmService",
            service: "palm://com.palm.bus/signal",
            method: "registerServerStatus",
            onResponse: "handleWifiServiceStatus",
  }
    ],
    //Handlers
    create: function (inSender, inEvent) {
        this.inherited(arguments);

        console.log("WiFi: created");

        if (!window.PalmSystem) {
            // WiFi is enabled by default ...
            this.$.WiFiPanels.setIndex(1);
            // if we're outside the webOS system add some entries for easier testing
            this.foundNetworks = this.phonyFoundNetworks;
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
            return;
        }

        this.$.WiFiServiceWatch.send({
            "serviceName": "com.palm.wifi"
        });
        this.palm = true;
    },
    handleWifiServiceStatus: function (inSender, inResponse) {
        var result = inResponse.data;

        if (!result)
            return;

        if (result.connected) {
            this.$.GetWiFiStatus.send({});
            this.$.FindNetworks.send({});
        } else {
            this.$.WiFiPanels.setIndex(0);
            this.$.WiFiToggle.setValue(false);
        }
    },
    reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow())
            this.$.Grabber.applyStyle("visibility", "hidden");
        else
            this.$.Grabber.applyStyle("visibility", "visible");
    },
    //Action Handlers
    toggleButtonChanged: function (inSender, inEvent) {
        if (inEvent.value == true)
            this.activateWiFi(this);
        else
            this.deactivateWiFi(this);

        this.doActiveChanged(inEvent);
    },
    listItemTapped: function (inSender, inEvent) {
        this.currentNetwork = {
            ssid: inSender.$.SSID.content,
            securityTypes: inSender.$.Padlock.content
        };

        if (inSender.$.Padlock.content != "none" || inSender.$.Padlock.content != "") {
            this.$.PopupSSID.setContent(this.currentNetwork.ssid);
            this.showNetworkConnect();
        } else {
            console.log("Connect to open network");
            this.connect(this, {
                ssid: this.currentNetwork.ssid
            });
        }
    },
    onJoinButtonTapped: function (inSender, inEvent) {
        this.$.WiFiPanels.setIndex(3);
    },
    setupSearchRow: function (inSender, inEvent) {
        inEvent.item.$.wiFiListItem.$.SSID.setContent(this.foundNetworks[inEvent.index].networkInfo.ssid);

        inEvent.item.$.wiFiListItem.$.Active.setShowing(true);
        if (this.foundNetworks[inEvent.index].networkInfo.availableSecurityTypes !== "none") {
            inEvent.item.$.wiFiListItem.$.Padlock.setShowing(true);
        }

        if (this.foundNetworks[inEvent.index].networkInfo.signalBars) {
            inEvent.item.$.wiFiListItem.$.Signal.setSrc("assets/wifi/signal-icon-" + this.foundNetworks[inEvent.index].networkInfo.signalBars + ".png");
        }
    },
    onNetworkConnect: function (inSender, inEvent) {
        var password = this.$.PasswordInput.getValue();

        if (this.validatePassword(password)) {
            this.connect(this, {
                ssid: this.currentSSID,
                password: password
            });
        } else {
            this.showError("Entered password is invalid");
        }

        // switch back to network list view
        this.$.WiFiPanels.setIndex(1);

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
    showNetworksList: function (inSender, inEvent) {
        return this.$.WiFiPanels.setIndex(1);
    },
    showNetworkConnect: function (inSender, inEvent) {
        this.$.WiFiPanels.setIndex(2);
    },
    setToggleValue: function (value) {
        this.$.WiFiToggle.setValue(value);
    },
    showError: function (message) {
        this.$.ErrorMessage.setContent(message);
        this.$.ErrorPopup.show();
    },
    activateWiFi: function (inSender, inEvent) {
        if (this.palm) {
            this.$.SetWiFiState.send({
                "state": "enabled"
            });
        }
    },
    deactivateWiFi: function (inSender, inEvent) {
        if (this.palm) {
            this.$.SetWiFiState.send({
                "state": "disabled"
            });
        }
    },
    connect: function (inSender, inEvent) {
        if (!this.palm)
            return;

        var ssid = this.currentNetwork.ssid;
        var password = inEvent.password;
        var hidden = false;

        var obj = {};

        if (password != "") {
            enyo.log("Connecting to PSK network");
            obj = {
                "ssid": ssid,
                "security": {
                    "securityType": "psk",
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

        var request = navigator.service.Request("luna://com.palm.wifi/", {
            method: 'connect',
            parameters: obj
        });
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
    //Service Callbacks
    handleWiFiStatus: function (inSender, inResponse) {
        var result = inResponse.data;

        if (!result)
            return;

        if (result.status == "serviceDisabled") {
            this.$.WiFiToggle.setValue(false);
            this.$.WiFiPanels.setIndex(0);
            this.clearFoundNetworks();
        } else if (result.status == "serviceEnabled") {
            this.$.WiFiToggle.setValue(true);
            this.$.WiFiPanels.setIndex(1);
        }
    },
    handleFindNetworksResponse: function (inSender, inResponse) {
        var result = inResponse.data;
        if (result.foundNetworks) {
            this.foundNetworks = result.foundNetworks;
            this.$.SearchRepeater.setCount(this.foundNetworks.length);
        } else {
            this.clearFoundNetworks();
        }
    },
    handleConnectResponse: function (inSender, inResponse) {
        var result = inResponse.data;
    }
});