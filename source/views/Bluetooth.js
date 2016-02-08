/*jslint sloppy: true, stupid: true */

enyo.kind({
    name: "BluetoothListItem",
    //classes: "group-item-wrapper",
    style: "position: relative;",

    events: {
        onDeleteDevice: "",
        onDeviceNameChanged: "",
        onInfoButtonTapped: "",
        onDeviceTapped: ""
    },

	components: [
        {
            name: "BluetoothSlider",
            kind: "enyo.Slideable",
            min: 0,
            max: 110,
            unit: "%",
            value: 0,
            style: "position:inherit; z-index:20; background-color: #EAEAEA; line-height: 55px;",
            preventDragPropagation: false,
            newDevice: false,
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
                            style: "width: 32px; height: 32px; margin-top: 11px !important",
                            ontap: "doDeviceTapped",
                            //TODO: classes
                        },
                        {fit: true, components: [
                            {
                                name: "DeviceName",
                                content: "DeviceName",
                                style: "padding-left: 10px; line-height: 55px;",
                                ontap: "doDeviceTapped",
                                onhold: "editDeviceName"
                            },
                            {name: "DeviceNameInputDecorator", kind: "onyx.InputDecorator", style: "height: 55px;", showing: false, components: [
                                {name: "DeviceNameInput", kind: "onyx.Input", placeholder: "DeviceName", style: "line-height: 55px;", selectOnFocus: true, onchange: "inputChange", onblur: "inputLostFocus"}
                            ]}
                        ]}, //Device Name
                        {
                            name: "MoreInfo",
                            kind: "enyo.Button",
                            showing: false,
                            style: "margin-left: 10px; margin-top: 11px !important",
                            components: [
                                { kind: "Image", src: "assets/bluetooth/info.png", style: "width: 32px; height: 32px"}
                            ],
                            ontap: "doInfoButtonTapped"
                        }, // icons
                        {
                            name: "ConnectingSpinner",
                            kind: "onyx.Spinner",
                            style: "width: 54px; height: 55px; margin: 4px; padding-top: 4px;",
			    classes: "onyx-light",
                            showing: false
                        },
                    ]
                },
            ],
        },
        {
            name: "SliderButtons",
            classes: "group-item",
            style: "position:absolute; top:0px; z-index:10; line-height: 55px; text-align: center; width: 100%; background-image:url('assets/bg.png');", components: [
                {kind: "onyx.Button", content: "Cancel", ontap: "closeSlider"},
                {kind: "onyx.Button", content: "Delete", classes: "onyx-negative", style: "margin-left: 10px;", ontap: "deleteDevice"}
            ],
            ontap: "closeSlider"
        }
	],

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

    isNewDevice: function() {
        this.newDevice = true;
        this.$.BluetoothSlider.draggable = false;
        this.$.SliderButtons.hide();
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
        if (this.newDevice) return true;
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

// Use the DeviceInfo structure returned by navigator.BluetoothManager.
// type: 3 (phone), 14 (keyboard), 7 (audio), 0 (other)
// connection[ state]: 1 (Not Connected), 2 (Connecting), 4 (Connected),
// 8 (Disconnecting)

var mockDevices = [
    {
        name: "Phone",
        type: 3, //"phone",
        enabled: true,
        connection: 2
    },
    {
        name: "Keyboard",
        type: 14, //"keyboard",
        enabled: false,
        connection: 1
    },
    {
        name: "Headset",
        type: 7, //"audio",
        enabled: true,
        connection: 4
    },
    {
        name: "Computer",
        type: 0, //"other",
        enabled: true,
        connection: 1
    },
    {
        name: "Toaster",
        type: 0, //"other",
        enabled: true,
        connection: 1
    }
];

enyo.kind({
    name: "Bluetooth",
    layoutKind: "FittableRowsLayout",
    foundDevices: [],
    stashedTag: null,
    searchResults: null,
    events: {
        onActiveChanged: "",
        onBackbutton: ""
    },
    palm: false,
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
		/* 67px is spinner height (55) + 2 x padding (6) */
                {
                    kind: "enyo.FittableRows",
                    components: [
                        {
                            name: "DiscoverableStatus",
                            kind: "enyo.FittableColumns",
                            style: "padding: 35px 10% 0 10%; height: 67px",
                            components: [
                                {
                                    name: "DiscoverableSpinner",
                                    kind: "onyx.Spinner",
				    classes: "onyx-light",
                                    style: "width: 54px; height: 55px; margin-right: 10px;"
                                },
                                {
                                    name: "DiscoverableStatusMessage",
                                    content: "Making your device visible and discoverable to others.", //"Your device is now discoverable."
                                    style: "line-height: 55px; font-size: 14px"
                                }
                            ]
                        },
                        {
                            name: "DiscoveringStatus",
			    showing: false,
                            kind: "enyo.FittableColumns",
                            style: "padding: 35px 10% 0 10%; height: 67px",
                            components: [
                                {
                                    name: "DiscoveringSpinner",
                                    kind: "onyx.Spinner",
				    classes: "onyx-light",
                                    style: "width: 54px; height: 55px; margin-right: 10px;"
                                },
                                {
                                    name: "DiscoveringStatusMessage",
                                    content: "Searching for devices...",
                                    style: "line-height: 55px; font-size: 14px"
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
                                            name: "DeviceRepeater",
                                            kind: "Repeater",
                                            count: 0,
                                            onSetupItem: "setupDeviceRow",
                                            
                                            components: [
                                                {
                                                    kind: "BluetoothListItem",
                                                    onDeviceTapped: "listItemTapped",
                                                    onInfoButtonTapped: "handleInfoButtonTapped",
                                                    onDeleteDevice: "handleDeviceDeleted",
                                                    onDeviceNameChanged: "handleDeviceNameChanged"
                                                }
                                            ]
                                    }]
                                },
                                {
                                    name: "AddDeviceButton",
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
                                    ontap: "onAddDeviceButtonTapped",
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
                /* Device Options panel */
                {
                    kind: "enyo.FittableRows",
                    components: [
                        {
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            style: "padding: 35px 10% 5px 10%;",
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    content: "Device Options",
                                },
                                {
                                    kind: "FittableColumns",
                                    classes: "group-item",
                                    components: [
                                        {
                                            content: "Phonebook Access",
                                            fit: true
                                        },
                                        {
                                            name: "phonebookAccessToggleButton",
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
                                            content: "Message Access",
                                            fit: true
                                        },
                                        {
                                            name: "messageAccessToggleButton",
                                            kind: "onyx.ToggleButton",
                                            value: true,
                                            style: "height: 31px;"
                                        },
                                    ]
                                }
                            ]
                        },
                        {
                            style: "padding: 5px 10% 35px 10%; font-size: 14px;",
                            content: "Requires a device that supports Phonebook Access Profile and Message Access Profile."
                        }
                    ]
                },
                /* Add Device panel */
                {
                    name: "AddDevice",
                    layoutKind: "FittableRowsLayout",
                    classes: "content-wrapper",
                    components: [
                        {
                            classes: "content-aligner",
                            components: [
                                {
                                    //TODO: Update this as the search status is changed.
                                    name: "SearchStatus",
                                    kind: "enyo.FittableColumns",
                                    style: "padding-bottom: 15px;",
                                    components: [
                                        {
                                            name: "SearchSpinner",
                                            kind: "onyx.Spinner",
					    classes: "onyx-light",
                                            style: "width: 54px; height: 55px; margin-right: 10px;"
                                        },
                                        {
                                            name: "SearchStatusMessage",
                                            content: "Searching for audio devices...",
                                            style: "line-height: 55px; font-size: 14px;"
                                        }
                                    ]
                                },
                                {
                                    name: "PhoneMessage",
                                    content: "Please note, some phones support only a single handsfree call.",
                                    style: "margin-top: 5px; margin-bottom: 20px; font-size: 14px;",
                                    showing: false
                                },
                                {
                                    kind: "onyx.Groupbox",
                                    components: [
                                        {
                                            kind: "enyo.FittableColumns",
                                            components: [
                                                {
                                                    content: "Type",
                                                    style: "margin-left: 5px; line-height: 30px; font-size: 18px;",
                                                },
                                                {
                                                    kind: "onyx.PickerDecorator",
                                                    fit: true,
                                                    components: [
                                                        {
                                                            classes: "config-label",
                                                            style: "width: 100%; text-align: right;"
                                                        },
                                                        {
                                                            name: "DeviceSearchPicker",
                                                            kind: "onyx.Picker",
                                                            onChange: "deviceSearchPickerChanged",
                                                            components: [
                                                                {
                                                                    content: "Audio",
                                                                    active: true
                                                                },
                                                                {
                                                                    content: "Phone"
                                                                },
                                                                {
                                                                    content: "Keyboard"
                                                                },
                                                                {
                                                                    content: "Other"
                                                                }
                                                            ]
                                                        }
                                                    ]
                                                }
                                            ]
                                        }
                                    ]
                                },
                                {
                                    name: "FoundDeviceList",
                                    kind: "onyx.Groupbox",
                                    layoutKind: "FittableRowsLayout",
                                    fit: true,
                                    showing: false,
                                    components: [
                                        {
                                            kind: "onyx.GroupboxHeader",
                                            content: "Found Devices",
                                        },
                                        {
                                            classes: "networks-scroll",
                                            kind: "Scroller",
                                            touch: true,
                                            touchOverscroll: false,
                                            horizontal: "hidden",
                                            components: [{
                                                    name: "FoundDeviceRepeater",
                                                    kind: "Repeater",
                                                    count: 0,
                                                    onSetupItem: "setupFoundDeviceRow",
                                                    
                                                    components: [
                                                        {
                                                            kind: "BluetoothListItem",
                                                            onDeviceTapped: "foundDeviceTapped",
                                                        }
                                                    ]
                                            }]
                                        }
                                    ]
                                },
                                {
                                    name: "NoDevicesFoundMessage",
                                    kind: "enyo.FittableRows",
                                    style: "margin-top: 20px; text-align: center; font-size: 16px;",
                                    showing: false,
                                    components: [
                                        {
                                            style: "font-weight: bold;",
                                            content: "No devices found."
                                        },
                                        {
                                            tag: "br"
                                        },
                                        {
                                            content: "Please make sure that your Bluetooth device is on and in pairing mode."
                                        }
                                    ]
                                }
                            ]
                        },
                    ]
                },
                 /* Confirm passkey panel */
                {
                    name: "ConfirmPasskeyPanel",
                    layoutKind: "FittableRowsLayout",
                    classes: "content-wrapper",
                    components: [
			{
                            classes: "content-aligner",
                            components: [
				{
				    name: "ConfirmPasskeyIntro",
				    content: "Confirm Passkey",
				    classes: "content-heading"
				},
				{
				    kind: "onyx.Groupbox",
                                    components: [
					{
                                            kind: "onyx.GroupboxHeader",
                                            content: "Passkey"
					},
					{
                                            components: [
						{
                                                    name: "IndicatedPasskey",
						    content: "xxxx"
						}
                                            ]
					}
                                    ]
				},
				{
                                    kind: "onyx.Button",
                                    classes: "onyx-affirmative",
                                    content: "Confirm",
                                    ontap: "confirmPasskey"
				},
				{
                                    kind: "onyx.Button",
                                    content: "Reject",
                                    ontap: "rejectPasskey"
				}
                            ]
			}
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
    // Handlers
    create: function () {
        this.inherited(arguments);

        this.log("Bluetooth: created");

        if (!window.PalmSystem) {
            // Bluetooth is enabled by default
            this.handleBluetoothEnabled();
            // if we're outside the webOS system add some entries for easier testing
            this.foundDevices = mockDevices;
            this.$.DeviceRepeater.setCount(this.foundDevices.length);
            return;
        }

        this.palm = true;

        if (!navigator.BluetoothManager) {
            this.log("No BluetoothManager extension!");
            return;
	}

        navigator.BluetoothManager.onenabled = enyo.bind(this, "handleBluetoothEnabled");
        navigator.BluetoothManager.ondisabled = enyo.bind(this, "handleBluetoothDisabled");

        navigator.BluetoothManager.ondevicefound = enyo.bind(this, "handleDeviceFound");
        navigator.BluetoothManager.ondevicechanged = enyo.bind(this, "handleDeviceChanged");
        navigator.BluetoothManager.ondeviceremoved = enyo.bind(this, "handleDeviceRemoved");
        navigator.BluetoothManager.ondevicedisappeared = enyo.bind(this, "handleDeviceDisappeared");
        navigator.BluetoothManager.onpropertychanged = enyo.bind(this, "handleBluetoothPropertyChanged");

        navigator.BluetoothManager.onrequestpincode = enyo.bind(this, "handleBluetoothRequestPinCode");
        navigator.BluetoothManager.onrequestpasskey = enyo.bind(this, "handleBluetoothRequestPasskey");
        navigator.BluetoothManager.onconfirmpasskey = enyo.bind(this, "handleBluetoothConfirmPasskey");

	navigator.BluetoothManager.resetDevicesList();

//        if (navigator.BluetoothManager.enabled) {
//            this.handleBluetoothEnabled();
//        }

        this.doActiveChanged({value: navigator.BluetoothManager.enabled});//@@
    },
    destroy: function () {
        this.inherited(arguments);
    },
    reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()) {
            this.$.DeviceList.setStyle("padding: 35px 5% 35px 5%;");
            this.$.DiscoverableStatus.setStyle("padding: 35px 5% 35px 5%;");
            this.$.Grabber.applyStyle("visibility", "hidden");
        } else {
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },
    //Action Handlers
    toggleButtonChanged: function(inSender, inEvent) {
        if (inEvent.value === true) {
            this.activateBluetooth();
        } else {
            this.deactivateBluetooth();
            this.managepopup = false;
       }
        this.doActiveChanged(inEvent);
    },
    listItemTapped: function(inSender, inEvent) {
        var selectedDevice = this.foundDevices[inEvent.index];

        // Don't try to connect to a disabled device
        if (selectedDevice.enabled === false)
	    return true;

        // If we are connected (4) or connecting (2), set the status to disconnected (1)
        // If we are not connected, set the status to connecting (2)
        if (selectedDevice.connection === 4 || selectedDevice.connection === 2) {
            selectedDevice.connection = 1;
            if (!navigator.BluetoothManager) {
		return;
	    }
            navigator.BluetoothManager.disconnectDevice(selectedDevice.address,
							enyo.bind(this, "handleDeviceDisconnectSucceeded"),
							enyo.bind(this, "handleDeviceDisconnectFailed"));
        } else if (selectedDevice.connection === 1) {
            selectedDevice.connection = 2;
            if (!navigator.BluetoothManager) {
		return;
	    }
            navigator.BluetoothManager.connectDevice(selectedDevice.address,
						     enyo.bind(this, "handleDeviceConnectSucceeded"),
						     enyo.bind(this, "handleDeviceConnectFailed"));
        }

        this.$.DeviceRepeater.setCount(this.foundDevices.length);
//        this.$.DeviceRepeater.build();
    },
    foundDeviceTapped: function(inSender, inEvent) {
        var selectedDevice = this.searchResults[inEvent.index];

        // If we are connecting, set the status to disconnected
        // If we are not connected, set the status to connecting (2)
        if (selectedDevice.connection === 2) {
            selectedDevice.connection = 1;
            this.$.SearchStatusMessage.setContent("Searching for " + this.$.DeviceSearchPicker.selected.content.toLowerCase() + " devices...");
            //TODO: Use Bluetooth Service cancel the connection attempt
            //IE navigator.BluetoothManager.disconnectDevice(selectedDevice, enyo.bind(this, "handleDeviceDisconnectSucceeded"), enyo.bind(this, "handleDeviceDisconnectFailed"));
        }
        else if (selectedDevice.connection !== 4)
        {
            selectedDevice.connection = 2;
            this.$.SearchStatusMessage.setContent("Connecting...");
            //TODO: Use Bluetooth Service to connect and add the device
            //IE navigator.BluetoothManager.connectDevice(selectedDevice, enyo.bind(this, "handleDeviceConnectSucceeded"), enyo.bind(this, "handleDeviceConnectFailed"));
        }

        this.$.DeviceRepeater.setCount(this.foundDevices.length);
//        this.$.FoundDeviceRepeater.build();
    },
    handleInfoButtonTapped: function(inSender, inEvent)
    {
        //TODO: Pass type of device into the panel so that we know:
        // a) Which panel to display (device info vs device options)
        // b) which options to display (e.g. Mirror SMS)
        //this.showDeviceInfo();
        this.showDeviceOptions();
    },
    deviceSearchPickerChanged: function(inSender, inEvent)
    {
        this.$.SearchStatusMessage.setContent("Searching for " + inEvent.content.toLowerCase() + " devices...");
        this.$.PhoneMessage.setShowing(inEvent.content.toLowerCase() === "phone");
        //TODO: Start Search???
	if (navigator.BluetoothManager)
            navigator.BluetoothManager.discover(true);

	//this.handleDeviceSearchResults();
    },
    onAddDeviceButtonTapped: function(inSender, inEvent) {
	this.showAddDevice();
    },
    setupDeviceRow: function(inSender, inEvent) {
        var deviceName = "";
	// For the narrow page only, if the name is longer shorten it.
        if (enyo.Panels.isScreenNarrow() && this.foundDevices[inEvent.index].name.length >= 18) {
            deviceName = this.foundDevices[inEvent.index].name.slice(0,18) + "..";
        } else {
            deviceName = this.foundDevices[inEvent.index].name;
        }

        inEvent.item.$.bluetoothListItem.$.DeviceName.setContent(deviceName);
        inEvent.item.$.bluetoothListItem.$.DeviceNameInput.setValue(deviceName);

        switch (this.generalType(this.foundDevices[inEvent.index].type)) {
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
	    default:
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/computer.png");
                break;
        }

        inEvent.item.$.bluetoothListItem.$.DeviceName.addRemoveClass("bluetooth-disabled", !this.foundDevices[inEvent.index].enabled);

        if (this.foundDevices[inEvent.index].enabled) {
            inEvent.item.$.bluetoothListItem.$.ConnectingSpinner.setShowing(this.foundDevices[inEvent.index].connection == 2);
            inEvent.item.$.bluetoothListItem.$.DeviceName.addRemoveClass("bluetooth-active", this.foundDevices[inEvent.index].connection == 4);

	    // If connected...
            if (this.foundDevices[inEvent.index].connection == 4)
            {
                switch (this.generalType(this.foundDevices[inEvent.index].type)) {
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
		    default:
                        inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/computer-active.png");
                        break;
                }
            }
        }
    },
    setupFoundDeviceRow: function(inSender, inEvent) {
        var deviceName = "";
	// For the narrow page only, if the name is longer shorten it.
        if (enyo.Panels.isScreenNarrow() && this.foundDevices[inEvent.index].name.length >= 18) {
            deviceName = this.searchResults[inEvent.index].name.slice(0,18) + "..";
        } else {
            deviceName = this.searchResults[inEvent.index].name;
        }

        inEvent.item.$.bluetoothListItem.isNewDevice();
        inEvent.item.$.bluetoothListItem.$.DeviceName.setContent(deviceName);
        inEvent.item.$.bluetoothListItem.$.ConnectingSpinner.setShowing(this.searchResults[inEvent.index].connecting);

        switch (this.generalType(this.searchResults[inEvent.index].type)) {
            case "phone":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/phone.png");
                break;
            case "keyboard":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/keyboard.png");
                break;
            case "audio":
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/audio.png");
                break;
            case "other":
	    default:
                inEvent.item.$.bluetoothListItem.$.DeviceType.setSrc("assets/bluetooth/computer.png");
                break;
        }
    },
    //Action Functions
    showBluetoothDisabled: function() {
        this.stopAutoscan();
        this.$.BluetoothPanels.setIndex(0);
    },
    showDevicesList: function() {
        return this.$.BluetoothPanels.setIndex(1);
    },
    showDeviceInfo: function() {
        //TODO: Set device options based on the selected device
        this.$.BluetoothPanels.setIndex(2);
        this.stopAutoscan();
    },
    showDeviceOptions: function() {
        //TODO: Set device options based on the selected device
        this.$.BluetoothPanels.setIndex(3);
        this.stopAutoscan();
    },
    showAddDevice: function() {
        this.$.BluetoothPanels.setIndex(4);
        this.stopAutoscan();
	if (navigator.BluetoothManager)
            navigator.BluetoothManager.discover(true);

//        this.handleDeviceSearchResults();
    },
    showConfirmPasskeyPanel: function() {
        this.$.BluetoothPanels.setIndex(5);
    },
    setToggleValue: function(value) {
        this.$.BluetoothToggle.setValue(value);
    },
    showError: function(message) {
        this.$.ErrorMessage.setContent(message);
        this.$.ErrorPopup.show();
    },
    activateBluetooth: function() {
        this.showDevicesList();
	if (!navigator.BluetoothManager)
            return;
        navigator.BluetoothManager.enabled = true;
    },
    deactivateBluetooth: function() {
        this.showBluetoothDisabled();
	this.clearFoundDevices();
        if (!navigator.BluetoothManager)
            return;
        navigator.BluetoothManager.enabled = false;
    },
    handleDeviceDeleted: function(inSender, inEvent) {
        var selectedDevice = this.foundDevices[inEvent.index];

	if (navigator.BluetoothManager) {
            navigator.BluetoothManager.removeDevice(selectedDevice.address);
	}

        this.foundDevices.splice(inEvent.index, 1);

        this.$.DeviceRepeater.setCount(this.foundDevices.length);
//        this.$.DeviceRepeater.build();
    },
    handleDeviceNameChanged: function(inSender, inEvent)
    {
        var selectedDevice = this.foundDevices[inEvent.index];
        selectedDevice.name = inEvent.originator.$.DeviceNameInput.getValue();

	// No such function as updateDevice!
//	if (navigator.BluetoothManager) {
//            navigator.BluetoothManager.updateDevice(selectedDevice);
//	}
        this.$.DeviceRepeater.setCount(this.foundDevices.length);
//        this.$.DeviceRepeater.build();
    },
    handleDeviceSearchResults: function(inSender, inEvent)
    {
        this.$.FoundDeviceList.hide();
        this.$.NoDevicesFoundMessage.hide();

        //TODO: get results from service. In the mean time, we'll fake it.
        var searchDeviceType = this.$.DeviceSearchPicker.selected.content.toLowerCase();
        
        var filterFunction = function(value, index, array) {
            return value.type === searchDeviceType;
        };

        this.searchResults = this.foundDevices.filter(filterFunction);

        if (this.searchResults.length > 0) {
            this.$.FoundDeviceList.show();
            this.$.FoundDeviceRepeater.setCount(this.searchResults.length);
            //this.$.FoundDeviceRepeater.build();
        } else {
            this.$.NoDevicesFoundMessage.show();
        }
    },
    handleBackGesture: function() {
	if (this.$.BluetoothPanels.getIndex() > 1) {
	    this.$.BluetoothPanels.setIndex(1);
	} else {
	    if (this.$.BluetoothPanels.getIndex() === 1 ||
		this.$.BluetoothPanels.getIndex() === 0) {
		this.doBackbutton();
	    }
	}
    },

    // Utility Functions
    // From the BluetoothManager extension:
    //enum Type { Other, Computer, Cellular, Smartphone, Phone, Modem, Network,
    //            Headset, Speakers, Headphones, Video, OtherAudio, Joypad,
    //            Keypad, Keyboard, Tablet, Mouse, Printer, Camera, Carkit };
    //
    //enum Strength { None, Poor, Fair, Good, Excellent };
    //
    //enum Connection { Disconnected=1, Connecting=2,
    //                  Connected=4, Disconnecting=8 };
    //
    //How do we use these?
    //enum ConnectionMode { Audio, AudioSource, AudioSink, HandsfreeGateway,
    //                      HeadsetMode, Input };
    generalType: function(n) {
	switch (n) {
	case 0:
	default:
	    return "other";
	    break;
	case 2:
	case 3:
	case 4:
	    return "phone";
	    break;
	case 7:
	case 8:
	case 9:
	case 10:
	case 11:
	    return "audio";
	    break;
	case 13:
	case 14:
	    return "keyboard";
	    break;
	}
    },
    clearFoundDevices: function () {
        this.foundDevices = [];
        this.$.DeviceRepeater.setCount(this.foundDevices.length);
    },
    //TODO: This section will need to be re-architected to attempt to autoconnect to devices, etc.
    startAutoscan: function() {
	if (null === this.autoscan) {
            this.log("Starting autoscan ...");
            this.autoscan = window.setInterval(enyo.bind(this, "triggerAutoscan"), 15000);
            if (!this.foundDevices) {
		this.foundDevices = [];
                this.triggerAutoscan();
            }
        }
    },
    triggerAutoscan: function() {
	if (!navigator.BluetoothManager)
            return;
        navigator.BluetoothManager.discover(true);
        this.log("discover was called.");
    },
    stopAutoscan: function() {
        if (null !== this.autoscan) {
            this.log("Stopping autoscan ...");
            window.clearInterval(this.autoscan);
            this.autoscan = null;
        }
    },
    confirmPasskey: function() {
	var tag = this.stashedTag;
	this.stashedTag = null;
	navigator.BluetoothManager.confirmPasskey(tag, true);
	// Better to "go back", really.
	this.showDevicesList();
    },
    rejectPasskey: function() {
	var tag = this.stashedTag;
	this.stashedTag = null;
	navigator.BluetoothManager.confirmPasskey(tag, false);
	// Better to "go back", really.
	this.showDevicesList();
    },
    // BluetoothManager Callbacks
    handleDeviceFound: function(deviceInfo) {
	for (key in deviceInfo) {
	    this.log(key + ": " + deviceInfo[key]);
	}
	deviceInfo.enabled = true;
	// TODO: Defend against finding devices that are already in the list
	this.foundDevices.push(deviceInfo);
	this.$.DeviceRepeater.setCount(this.foundDevices.length);
//	this.$.DeviceRepeater.render();
//	this.$.DeviceRepeater.build();
    },
    handleDeviceChanged: function(deviceInfo) {
	for (var key in deviceInfo) {
	    this.log(key + ": " + deviceInfo[key]);
	}
	if (deviceInfo.address === undefined) {
	    this.log("Error: Device address not defined.");
	    return;
	}
	for (var i = 0; i < this.foundDevices.length; ++i) {
	    if (deviceInfo.address === this.foundDevices[i].address) {
		for (key in deviceInfo) {
		    this.foundDevices[i][key] = deviceInfo[key];
		}
		this.$.DeviceRepeater.setCount(this.foundDevices.length);
		return;
	    }
	}
	this.log("Error: A device we did not know about was changed.");
    },
    handleDeviceRemoved: function(address) {
	this.log(address);
    },
    handleDeviceDisappeared: function(address) {
	this.log(address);
    },
    handleBluetoothPropertyChanged: function(obj) {
	for (key in obj) {
	    var value = obj[key];
	    this.log(key + ": " + value);
	    switch (key) {
	    case "Discoverable":
		if (value === true) {
		    this.$.DiscoverableSpinner.setShowing(false);
		    this.$.DiscoverableStatusMessage.setContent(
			"Your device is now discoverable.");
		} else {
		    this.$.DiscoverableSpinner.setShowing(true);
		    this.$.DiscoverableStatusMessage.setContent(
			"Making your device visible and discoverable to others.");
		}
		break;
	    case "Discovering":
		if (value === true) {
		    this.$.DiscoveringStatus.setShowing(true);
		} else {
		    this.$.DiscoveringStatus.setShowing(false);
		}
		break;
	    case "Devices":
		if (value === null) {
//		    this.clearFoundDevices();
		    this.log("We were sent a null Devices list! (Ignored.)");
		} else {
		    this.log("Ought to do something with this Devices list!");
		}
		break;
	    }
	}
    },
    handleBluetoothRequestPinCode: function(deviceInfo) {
	for (var key in deviceInfo) {
	    this.log(key + ": " + deviceInfo[key]);
	}
	navigator.BluetoothManager.providePinCode(deviceInfo.tag,true,"0000");
    },
    handleBluetoothRequestPasskey: function(deviceInfo) {
	// tag?
	for (var key in deviceInfo) {
	    this.log(key + ": " + deviceInfo[key]);
	}
	navigator.BluetoothManager.providePasskey(deviceInfo.tag,true,0);
    },
    handleBluetoothConfirmPasskey: function(deviceInfo) {
	for (var key in deviceInfo) {
	    this.log(key + ": " + deviceInfo[key]);
	}
	this.$.ConfirmPasskeyIntro.setContent("Does the passkey match with \"" + deviceInfo.name + "\"?");
	this.$.IndicatedPasskey.setContent(deviceInfo.passkey);
	this.stashedTag = deviceInfo.tag;
	this.showConfirmPasskeyPanel();
    },
    handleDeviceConnectSucceeded: function() {
	this.log();
        //TODO: Update device connection to 4, rebuild repeater.
	},
    handleDeviceConnectFailed: function() {
        //TODO: Display appropriate error
	},
    handleDeviceDisconnectSucceeded: function() {
        //TODO: Any necessary logic
    },
    handleDeviceDisconnectFailed: function() {
        //TODO: Display appropriate error
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
    }
});
