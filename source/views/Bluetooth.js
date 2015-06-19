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
            style: "position:inherit; z-index:20; background-color: #EAEAEA; line-height: 38px;",
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
                            style: "width: 32px; height: 32px; margin: 4px;",
                            ontap: "doDeviceTapped",
                            //TODO: classes
                        },
                        {fit: true, components: [
                            {
                                name: "DeviceName",
                                content: "DeviceName",
                                style: "padding-left: 10px; line-height: 36px;",
                                ontap: "doDeviceTapped",
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
                            ontap: "doInfoButtonTapped"
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

var foundDevices = [
    //Device types: phone, keyboard, audio, other
    {
        name: "Pre3",
        type: "phone"
    },
    {
        name: "Mako",
        type: "phone"
    },
    {
        name: "Tenderloin",
        type: "phone"
    },
    {
        name: "HP TouchPad Wireless Keyboard",
        type: "keyboard"
    },
    {
        name: "My PC",
        type: "other",
    },
    {
        name: "WebOS Toaster",
        type: "other",
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
                            //TODO: Update this based as the discoverable status of the device is changed.
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
                                    //TODO: Update this based as the search status is changed.
                                    name: "SearchStatus",
                                    kind: "enyo.FittableColumns",
                                    style: "padding-bottom: 15px;",
                                    components: [
                                        {
                                            name: "SearchSpinner",
                                            kind: "Image",
                                            src: "assets/bluetooth/connecting.gif",
                                            style: "width: 32px; height: 32px; margin-right: 10px;"
                                        },
                                        {
                                            name: "SearchStatusMessage",
                                            content: "Searching for audio devices...",
                                            style: "line-height: 30px; font-size: 18px;"
                                        }
                                    ]
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
                                    name: "NoDevicesFoundMessage",
                                    kind: "enyo.FittableRows",
                                    style: "margin-top: 20px; text-align: center; font-size: 16px;",
                                    components: [
                                        {
                                            style: "font-weight: bold;",
                                            content: "No devices found."
                                        },
                                        {
                                            tag: "br"
                                        },
                                        {
                                            content: "Please make sure that your Bluetooth device is on and in paring mode."
                                        }
                                    ]
                                }
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
            this.$.DeviceRepeater.setCount(this.foundDevices.length);
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
        if (inEvent.value === true){
            this.activateBluetooth(this);
        } else{
            this.deactivateBluetooth(this);
            this.managepopup = false;
       }
        this.doActiveChanged(inEvent);
    },
    listItemTapped: function (inSender, inEvent) {
        var selectedDevice = this.foundDevices[inEvent.index];

        // don't try and connect to a device that is disabled
        if (selectedDevice.enabled === false) return true;

        // if we are connected (2) or connecting (1), set the status to disconnected (0)
        if (selectedDevice.connectionState === 2 || selectedDevice.connectionState === 1) {
            selectedDevice.connectionState = 0;
            //TODO: Use Bluetooth Service to update device status
            //IE navigator.BluetoothManager.disconnectDevice(selectedDevice, enyo.bind(this, "handleDeviceDisconnectSucceeded"), enyo.bind(this, "handleDeviceDisconnectFailed"));
        }
        // if we are not connected, set the status to connecting (1)
        else if (selectedDevice.connectionState === 0)
        {
            selectedDevice.connectionState = 1;
            //TODO: Use Bluetooth Service to update device status
            //IE navigator.BluetoothManager.connectDevice(selectedDevice, enyo.bind(this, "handleDeviceConnectSucceeded"), enyo.bind(this, "handleDeviceConnectFailed"));
        }

        this.$.DeviceRepeater.build();
    },
    handleInfoButtonTapped: function(inSender, inEvent)
    {
        //TODO: Pass type of device into the panel so that we know:
        // a) Which panel to display (device info vs device options)
        // b) which options to display (ie Mirror SMS)
        //this.showDeviceInfo();
        this.showDeviceOptions();
    },
    deviceSearchPickerChanged: function(inSender, inEvent)
    {
        this.$.SearchStatusMessage.setContent("Searching for " + inEvent.content.toLowerCase() + " devices...");
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
    onAddDeviceButtonTapped: function (inSender, inEvent) {
		this.showAddDevice();
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
    //Action Functions
    showBluetoothDisabled: function (inSender, inEvent) {
        this.stopAutoscan();
        this.$.BluetoothPanels.setIndex(0);
    },
    showDevicesList: function (inSender, inEvent) {
        return this.$.BluetoothPanels.setIndex(1);
    },
    showDeviceInfo: function (inSender, inEvent) {
        //TODO: Set device options based on the selected device
        this.$.BluetoothPanels.setIndex(2);
        this.stopAutoscan();
    },
    showDeviceOptions: function(inSender, inEvent) {
        //TODO: Set device options based on the selected device
        this.$.BluetoothPanels.setIndex(3);
        this.stopAutoscan();
    },
    showAddDevice: function (inSender, inEvent) {
        this.$.BluetoothPanels.setIndex(4);
        this.stopAutoscan();
    },
    setToggleValue: function (value) {
        this.$.BluetoothToggle.setValue(value);
    },
    showError: function (message) {
        this.$.ErrorMessage.setContent(message);
        this.$.ErrorPopup.show();
    },
    activateBluetooth: function (inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
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
    handleDeviceConnectSucceeded: function() {
        //TODO: Update device connectionStatus to 2, rebuild repeater.
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
    handleDeviceDeleted: function(inSender, inEvent) {
        var selectedDevice = this.foundDevices[inEvent.index];

        //TODO: Remove device from the service
        //IE: navigator.BluetoothManager.removeDevice(selectedDevice);

        this.foundDevices.splice(inEvent.index, 1);

        this.$.DeviceRepeater.setCount(this.foundDevices.length);
        this.$.DeviceRepeater.build();
    },
    handleDeviceNameChanged: function(inSender, inEvent)
    {
        var selectedDevice = this.foundDevices[inEvent.index];
        selectedDevice.name = inEvent.originator.$.DeviceNameInput.getValue();

        //TODO: Update device info in the service
        //IE: navigator.BluetoothManager.updateDevice(selectedDevice);
        this.$.DeviceRepeater.build();
    },
    handleBackGesture: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);	
		
		if(this.$.BluetoothPanels.getIndex() > 1){
			this.$.BluetoothPanels.setIndex(1);
		}else{
			if( this.$.BluetoothPanels.getIndex() === 1 || this.$.BluetoothPanels.getIndex() === 0){
				this.doBackbutton();
			}
		}
	},

    //Utility Functions
    clearfoundDevices: function () {
        this.foundDevices = [];
        this.$.DeviceRepeater.setCount(this.foundDevices.length);
    },
    //TODO: This section will need to be re-architected to attempt to autoconnect to devices, etc.
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
    },
    //Service Callbacks
    handleRetrieveNetworksResponse: function (networks) {
        this.log(networks);
        this.clearfoundDevices();
        if (networks) {
            this.foundDevices = networks;
            this.$.DeviceRepeater.setCount(this.foundDevices.length);
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
