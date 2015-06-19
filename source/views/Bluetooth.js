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
	//classes: "group-item-wrapper",
    style: "position: relative;",

    events: {
        onDeleteDevice: "",
        onDeviceNameChanged: "",
        onInfoButtonTapped: ""
    },

	components: [
        {
            name: "BluetoothSlider",
            kind: "enyo.Slideable",
            min: 0,
            max: 110,
            unit: "%",
            value: 0,
            style: "position:inherit; z-index:20; background-color: #EAEAEA; line-height: 38px;",
            preventDragPropagation: false,
            classes: "group-item",
            onmousedown: "pressed",
            ondragstart: "handleDrag",
            onmouseup: "released",
            components: [
                {
                    kind: "enyo.FittableColumns",
                    fit: true,
                    components: [
                        {
                            name: "DeviceType",
                            kind: "Image",
                            src: "assets/bluetooth/other.png",
                            style: "width: 32px; height: 32px; margin: 4px;",
                            //TODO: classes
                        },
                        {fit: true, components: [
                            {
                                name: "DeviceName",
                                content: "DeviceName",
                                style: "padding-left: 10px; line-height: 36px;",
                                onhold: "editDeviceName"
                            },
                            {name: "DeviceNameInputDecorator", kind: "onyx.InputDecorator", style: "height: 18px;", showing: false, components: [
                                {name: "DeviceNameInput", kind: "onyx.Input", placeholder: "DeviceName", style: "line-height: 24px;", selectOnFocus: true, onchange: "inputChange", onblur: "inputLostFocus"}
                            ]}
                        ]}, //Device Name
                        {
                            name: "MoreInfo",
                            kind: "enyo.Button",
                            showing: false,
                            style: "margin-left: 10px;",
                            components: [
                                { kind: "Image", src: "assets/bluetooth/info.png", style: "width: 32px; height: 32px;"}
                            ],
                            ontap: "infoButtonTapped"
                        }, // icons
                        {
                            name: "ConnectingSpinner",
                            kind: "Image",
                            src: "assets/bluetooth/connecting.gif",
                            style: "width: 32px; height: 32px; margin: 4px; padding-top: 4px;",
                            showing: false
                        },
                    ]
                },
            ],
        },
        {
            classes: "group-item",
            style: "position:absolute; top:0px; z-index:10; line-height: 38px; text-align: center; width: 100%; background-image:url('assets/bg.png');", components: [
                {kind: "onyx.Button", content: "Cancel", ontap: "closeSlider"},
                {kind: "onyx.Button", content: "Delete", classes: "onyx-negative", style: "margin-left: 10px;", ontap: "deleteDevice"}
            ],
            ontap: "closeSlider"
        }
	],

    resizeHandler: function()
    {
        this.inherited(arguments);
        console.log("Ping!");
        console.log(this.$.BluetoothSlider.getBounds());
    },

	pressed: function(inSender, inEvent) {
        if (!this.$.DeviceNameInputDecorator.getShowing() && inEvent.originator !== this.$.MoreInfo)
        {
            this.addClass("onyx-selected");
            this.$.BluetoothSlider.applyStyle("background-color", "#C4E3FE");
        }
	},
	
    released: function() {
        this.removeClass("onyx-selected");
        this.$.BluetoothSlider.applyStyle("background-color", "#EAEAEA");
	},

    infoButtonTapped: function() {
        this.doInfoButtonTapped();
    },

    /*
    *   Slider
    */
    
    handleDrag: function() {
        this.released();
        this.$.BluetoothSlider.preventDragPropagation = true;
    },
    
    closeSlider: function() {
        this.$.BluetoothSlider.animateToMin();
        this.$.BluetoothSlider.preventDragPropagation = false;
        return true;
    },

    deleteDevice: function() {
        this.doDeleteDevice();
        return true;
    },

    /*
    *   Device Name
    */
    editDeviceName: function() {
        this.$.DeviceName.setShowing(false);
        this.$.DeviceNameInputDecorator.setShowing(true);
        this.$.BluetoothSlider.draggable = false;
        this.$.DeviceNameInput.focus();
        return true;
    },

    inputChange: function() {
        this.doDeviceNameChanged();
    },

    inputLostFocus: function() {
        this.$.DeviceName.setShowing(true);
        this.$.DeviceNameInputDecorator.setShowing(false);
        this.$.BluetoothSlider.draggable = true;
        return true;
    }
});

var mockDevices = [
    //Device types: phone, keyboard, audio, other
    //States: 0 - Not Connected, 1 - Connecting, 2 - Connected
    {
        name: "Phone",
        type: "phone",
        enabled: true,
        connectionState: 0
    },
    {
        name: "Keyboard",
        type: "keyboard",
        enabled: false,
        connectionState: 0
    },
    {
        name: "Headset",
        type: "audio",
        enabled: true,
        connectionState: 2
    },
    {
        name: "Computer",
        type: "other",
        enabled: true,
        connectionState: 1
    },
    {
        name: "Toaster",
        type: "other",
        enabled: true,
        connectionState: 0
    }
];

enyo.kind({
    name: "Bluetooth",
    layoutKind: "FittableRowsLayout",
    foundDevices: null,
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
                /* Device list panel */
                {
                    kind: "enyo.FittableRows",
                    components: [
                        {
                            name: "DiscoverableStatus",
                            kind: "enyo.FittableColumns",
                            style: "padding: 35px 10% 0 10%;",
                            components: [
                                {
                                    name: "DiscoverableSpinner",
                                    kind: "Image",
                                    src: "assets/bluetooth/connecting.gif",
                                    style: "width: 32px; height: 32px; margin-right: 10px;"
                                },
                                {
                                    name: "DiscoverableStatusMessage",
                                    content: "Making your device visible and discoverable to others.", //"Your device is now discoverable."
                                    style: "line-height: 30px;"
                                }
                            ]
                        },
                        {
                            name: "DeviceList",
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            style: "padding: 35px 10% 35px 10%;",
                            fit: true,
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    content: "Devices",
                                },
                                {
                                    classes: "networks-scroll",
                                    style: "border-bottom: 0px;",
                                    kind: "Scroller",
                                    touch: true,
                                    touchOverscroll: false,
                                    horizontal: "hidden",
                                    components: [{
                                            name: "SearchRepeater",
                                            kind: "Repeater",
                                            count: 0,
                                            onSetupItem: "setupDeviceRow",
                                            
                                            components: [
                                                {
                                                    kind: "BluetoothListItem",
                                                    ontap: "listItemTapped",
                                                    onInfoButtonTapped: "handleInfoButtonTapped"
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
                                            src: "assets/bluetooth/join-plus-icon.png"
                                        },
                                        {
                                            content: "Add Device",
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
                /* Device Info panel */
                {
                    kind: "enyo.FittableRows",
                    components: [
                        {
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            style: "padding: 35px 10% 35px 10%;",
                            fit: true,
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    content: "Device Info",
                                },
                                {
                                    kind: "FittableColumns",
                                    classes: "group-item",
                                    components: [
                                        {
                                            content: "Auto-Connect",
                                            fit: true
                                        },
                                        {
                                            name: "autoConnectToggleButton",
                                            kind: "onyx.ToggleButton",
                                            value: true,
                                            style: "height: 31px;"
                                        },
                                    ]
                                },
                                {
                                    kind: "FittableColumns",
                                    classes: "group-item",
                                    components: [
                                        {
                                            content: "Mirror Phone Calls",
                                            fit: true
                                        },
                                        {
                                            name: "mirrorPhoneCallsToggleButton",
                                            kind: "onyx.ToggleButton",
                                            value: true,
                                            style: "height: 31px;"
                                        },
                                    ]
                                },
                                {
                                    kind: "FittableColumns",
                                    classes: "group-item",
                                    components: [
                                        {
                                            content: "Mirror SMS",
                                            fit: true
                                        },
                                        {
                                            name: "mirrorSMSToggleButton",
                                            kind: "onyx.ToggleButton",
                                            value: true,
                                            style: "height: 31px;"
                                        },
                                    ]
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
                                    ontap: "showDevicesList"
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
            this.foundDevices = mockDevices;
            this.$.SearchRepeater.setCount(this.foundDevices.length);
            return;
        }

        this.palm = true;

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
            this.$.DeviceList.setStyle("padding: 35px 5% 35px 5%;");
            this.$.DiscoverableStatus.setStyle("padding: 35px 5% 35px 5%;");
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
        return true;
        var selectedNetwork = this.foundDevices[inEvent.index];

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
    handleInfoButtonTapped: function(inSender, inEvent)
    {
        //TODO: Pass type of device into the panel so that we know:
        // a) Which panel to display (device info vs device options)
        // b) which options to display (ie Mirror SMS)
        console.log("PING!!!!!!!")
        this.showDeviceInfo();
    },
    triggerWifiConnect: function () {
        var i, path = "";
        for (i = 0; i < this.foundDevices.length; i++) {
            if (this.foundDevices[i].name === this.wifiTarget.ssid) {
                path = this.foundDevices[i].path;
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
    setupDeviceRow: function (inSender, inEvent) {
        var deviceName = "";
        if(enyo.Panels.isScreenNarrow() && this.foundDevices[inEvent.index].name.length >= 18){ // if the name is longer shorten it for the narrow page only
            deviceName = this.foundDevices[inEvent.index].name.slice(0,18) + "..";
        }else{
            deviceName = this.foundDevices[inEvent.index].name;
        }

        inEvent.item.$.bluetoothListItem.$.DeviceName.setContent( deviceName );
        inEvent.item.$.bluetoothListItem.$.DeviceNameInput.setValue( deviceName );

        switch (this.foundDevices[inEvent.index].type) {
            case "phone":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/phone.png");
                inEvent.item.$.bluetoothListItem.$.MoreInfo.setShowing(true);
                break;
            case "keyboard":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/keyboard.png");
                break;
            case "audio":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/audio.png");
                break;
            case "other":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/computer.png");
                break;
        }

        inEvent.item.$.bluetoothListItem.$.DeviceName.addRemoveClass("bluetooth-disabled", !this.foundDevices[inEvent.index].enabled);

        if (this.foundDevices[inEvent.index].enabled){
            inEvent.item.$.bluetoothListItem.$.ConnectingSpinner.setShowing(this.foundDevices[inEvent.index].connectionState == 1);
            inEvent.item.$.bluetoothListItem.$.DeviceName.addRemoveClass("bluetooth-active", this.foundDevices[inEvent.index].connectionState == 2);

            if (this.foundDevices[inEvent.index].connectionState == 2)
            {
                switch (this.foundDevices[inEvent.index].type) {
                    case "phone":
                        inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/phone-active.png");
                        break;
                    case "keyboard":
                        inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/keyboard-active.png");
                        break;
                    case "audio":
                        inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/audio-active.png");
                        break;
                    case "other":
                        inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/computer-active.png");
                        break;
                }
            }
        }
    },
    setupKnownNetworkRow: function (inSender, inEvent) {

    	var ssid = "";	
		if(enyo.Panels.isScreenNarrow()){
    		if(this.foundDevices[inEvent.index].name.length >= 18){					// if the SSID is longer shortten it for the narrow page only
    			ssid = this.foundDevices[inEvent.index].name.slice(0,18) + "..";
    		}else{
    			ssid = this.foundDevices[inEvent.index].name;
    		}
    	}else{
    		ssid = this.foundDevices[inEvent.index].name;
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
        this.showDevicesList();
		delete password;
        this.$.PasswordInput.setValue("");
    },
    onNetworkConnectAborted: function (inSender, inEvent) {
        // switch back to network list view
        this.showDevicesList(inSender, inEvent);

        this.$.PasswordInput.setValue("");
    },
    onOtherJoinCancelled: function (inSender, inEvent) {
        // switch back to network list view
        this.showDevicesList(inSender, inEvent);

        this.$.ssidInput.setValue("");
        this.$.SecurityTypePicker.setSelected(this.$.OpenSecurityItem);
    },
    //Action Functions
    showBluetoothDisabled: function (inSender, inEvent) {
        this.stopAutoscan();
        this.$.BluetoothPanels.setIndex(0);
    },
    showDevicesList: function (inSender, inEvent) {
		this.updateSpinnerState("start");
        return this.$.BluetoothPanels.setIndex(1);
    },
    showDeviceInfo: function (inSender, inEvent) {
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
        this.showDevicesList();
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

        this.showDevicesList();
    },
    updateSpinnerState: function(action) {
		//TODO: remove?
        this.log("action:", action);
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
    clearfoundDevices: function () {
        this.foundDevices = [];
        this.$.SearchRepeater.setCount(this.foundDevices.length);
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
            if (!this.foundDevices) {
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
        this.clearfoundDevices();
        if (networks) {
            this.foundDevices = networks;
            this.$.SearchRepeater.setCount(this.foundDevices.length);
            if (this.wifiTarget && this.connecting != true) {
                this.triggerWifiConnect();
            }
        }
    },
    handleRetrieveNetworksFailed: function() {
        this.clearfoundDevices();
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
