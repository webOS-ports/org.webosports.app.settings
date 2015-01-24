enyo.kind({
    name: "DeviceSoftwareInformation",
    layoutKind: "FittableRowsLayout",
    palm: true,
	events: {
        onBackbutton: "",
    },
    components: [
        { kind: "onyx.Toolbar", style: "line-height: 36px;",
            components:[ { content: "About" } ] },
        { kind: "Scroller", touch: true, horizontal: "hidden", fit: true,
          components:[
            {name: "div", tag: "div", style: "padding: 35px 10% 35px 10%;", fit: true,
              components: [
                {kind: "onyx.Groupbox", components: [
                    {kind: "onyx.GroupboxHeader", content: "Device"},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Name", style: "padding-top: 10px;"},
                        {kind: "Control", name: "DeviceName", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Serial number", style: "padding-top: 10px;"},
                        {kind: "Control", name: "DeviceSerialNumber", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                ]},
                {kind: "onyx.Groupbox", components: [
                    {kind: "onyx.GroupboxHeader", content: "Software"},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Version", style: "padding-top: 10px;"},
                        {kind: "Control", name: "SoftwareVersion", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Codename", style: "padding-top: 10px;"},
                        {kind: "Control", name: "Codename", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Build Tree", style: "padding-top: 10px;"},
                        {kind: "Control", name: "BuildTree", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Build Number", style: "padding-top: 10px;"},
                        {kind: "Control", name: "BuildNumber", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                    { kind: "enyo.FittableColumns", classes: "group-item", components:[
                        {kind: "Control", content: "Android version", style: "padding-top: 10px;"},
                        {kind: "Control", name: "SoftwareAndroidVersion", style: "float: right; padding-top: 10px;", content: "Unknown"},
                    ]},
                ]},
                {kind: "onyx.Button", content: "Software Licenses", style: "width: 100%", ontap: "onShowSoftwareLicenses" }
           ]}
        ]},
        { kind: "onyx.Toolbar", components:[
			{name: "Grabber", kind: "onyx.Grabber"},
		]},
        { kind: "enyo.PalmService", name: "RetrieveVersion", service: "palm://org.webosports.service.update",
            method: "retrieveVersion", onComplete: "onVersionResponse" },
        { kind: "enyo.PalmService", name: "GetAndroidProperty", service: "palm://com.android.properties",
            method: "getProperty", onComplete: "onGetAndroidPropertyResponse"},
    ],
    // Handlers
    create: function(inSender, inEvent) {
        this.inherited(arguments);
        if (!window.PalmSystem) {
            enyo.log("Non-palm platform, service requests disabled.");
            this.palm = false;
            return;
        }
        this.updateAll();
    },
	reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
            this.$.Grabber.applyStyle("visibility", "hidden");
            this.$.div.setStyle("padding: 35px 5% 35px 5%;");
        }else{
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },

    updateAll: function() {
        this.$.RetrieveVersion.send({});
        this.$.GetAndroidProperty.send({keys:[
            "ro.serialno",
            "ro.product.model",
            "ro.product.manufacturer",
            "ro.build.version.release"]});
    },
    // Action Handlers
    onShowSoftwareLicenses: function(inSender, inEvent) {
        this.bubble("onSwitchPanel", {targetPanel: "Licenses"});
    },
    // Service Handlers
    onVersionResponse: function(inSender, inEvent) {
        var response = inEvent.data;
        console.log("Got response from update service: " + response);
        if (!response || !response.returnValue)
            return;

        if (response.localVersion)
            this.$.SoftwareVersion.setContent("" + response.localVersion);
        if (response.codename)
            this.$.Codename.setContent(response.codename);
        if (response.buildTree)
            this.$.BuildTree.setContent(response.buildTree);
        if (response.buildNumber)
            this.$.BuildNumber.setContent(response.buildNumber);
    },
    onGetAndroidPropertyResponse: function(inSender, inEvent) {
        var response = inEvent.data;
        console.log("Got response from android property service: " + response);
        if (!response || !response.returnValue)
            return;
        if (!response.properties)
            return;

        var model = "";
        var manufacturer = "";

        for (var n = 0; n < response.properties.length; n++) {
            var property = response.properties[n];
            if (property["ro.serialno"])
                this.$.DeviceSerialNumber.setContent(property["ro.serialno"]);
            else if (property["ro.product.model"])
                model = property["ro.product.model"];
            else if (property["ro.product.manufacturer"])
                manufacturer = property["ro.product.manufacturer"];
            else if (property["ro.build.version.release"])
                this.$.SoftwareAndroidVersion.setContent(property["ro.build.version.release"]);
        }

        this.$.DeviceName.setContent(manufacturer + " " + model);
    }
});

enyo.kind({
    name: "About",
    layoutKind: "FittableRowsLayout",
    palm: true,
	events: {
		onBackbutton: "",
	},
	handlers: {
		onBackMain: "handleBackGesture",
		onBack: "handleBack"
	},
	debug: false,
    components: [
		{ kind: "Panels", name: "ContentPanels", fit: true, draggable: false,
          components: [
            { name: "Information", kind: "DeviceSoftwareInformation", onSwitchPanel: "switchPanel" },
            { name: "Licenses", kind: "Licenses", onSwitchPanel: "switchPanel" }
        ]},
    ],
    // Handlers
    create: function(inSender, inEvent) {
        this.inherited(arguments);
        if (!window.PalmSystem) {
            enyo.log("Non-palm platform, service requests disabled.");
            this.palm = false;
            return;
        }
    },
    // Action Handlers
    handleBackGesture: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		if(this.$.ContentPanels.getIndex() === 0){
			this.doBackbutton();
        }
        
		if(this.$.ContentPanels.getIndex() === 1){
			//this.switchPanel(null, {targetPanel: "Information"});
			this.$.Licenses.handleBackGesture();	
		}
		

    },
    handleBack: function(inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);
		this.switchPanel(null, {targetPanel: "Information"});
	},
    switchPanel: function(inSender, inEvent) {
        console.log("switchPanel: targetPanel=" + inEvent.targetPanel);
        if (typeof inEvent.targetPanel === 'undefined')
            return;
        this.$.ContentPanels.selectPanelByName(inEvent.targetPanel);
        this.selectContentPanel();
    },
    selectContentPanel: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
        //if (enyo.Panels.isScreenNarrow())
        //	this.$.ContentPanels.;
            //this.selectPanelByName("ContentPanels");
    }
});
