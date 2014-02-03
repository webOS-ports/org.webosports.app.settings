/*jslint sloppy: true */
/*global enyo, console*/


enyo.kind({
    name: "PackageListItem",
    classes: "group-item-wrapper",
    components: [
        {
            classes: "group-item",
            layoutKind: "FittableColumnsLayout",
            components: [
                {
                    name: "package",
                    content: "",
                    fit: true
                },
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
    name: "LicenseTextItem",
    classes: "group-item-wrapper",
    components: [
        {
            classes: "group-item",
            layoutKind: "FittableColumnsLayout",
            components: [
                {	
                    name: "licenseText",
                    tag: "pre",
                    content: "",
                    fit: true
                },
            ],
        }],
});


enyo.kind({
	name: "Licenses",
	kind: "FittableRows",
	fit: true,
	currentRequest: false,
	published: {
		updateResults: null
	},
	components: [	
		 /* Top toolbar */
		{kind: "onyx.Toolbar", style: "line-height: 28px;", content: "Licenses"},
		 /* WiFi Panels */
        {
            name: "licensePanels",
            kind: "Panels",
            //arrangerKind: "HFlipArranger",
            fit: true,
            draggable: false,
            components: [
            	/* Package List */
                {
                    kind: "enyo.FittableRows",
                    classes: "content-wrapper",
                    components: [
                        {
                            name: "PackageList",
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            classes: "content-aligner",
                            style: "max-width: 1024px;",
                            fit: true,
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    content: "Choose a Package"
                                },
                                {
                                    classes: "networks-scroll",
                                    kind: "Scroller",
                                    touch: true,
                                    horizontal: "hidden",
                                    fit: true,
                                    components: [{
                                            name: "packageRepeater",
                                            kind: "Repeater",
                                            count: 0,
                                            onSetupItem: "setupPackageRow",
                                            components: [
                                                {
                                                    kind: "PackageListItem",
                                                    ontap: "packageSelected"
                                                }
                                            ]
                                    }]
                                },

        				]}
        		]},
        		/* Loading Message */
        		{name: "spinner", style: "padding: 10px; font-weight: bold; text-align:center;", components: [
					{ tag: "br"},
					{content: "Getting Licenses for Package..."},
					{ tag: "br"},
					{kind: "onyx.Spinner", classes: "onyx-light"}
				]},
        		/*License Text Panel */
        		{
                    kind: "enyo.FittableRows",
                    classes: "content-wrapper",
                    components: [
                        {
                            name: "LicenseList",
                            kind: "onyx.Groupbox",
                            layoutKind: "FittableRowsLayout",
                            classes: "content-aligner",
                            style: "max-width: 1024px;",
                            fit: true,
                            components: [
                                {
                                    kind: "onyx.GroupboxHeader",
                                    content: "Licenses"
                                },
                                {
                                    classes: "networks-scroll",
                                    kind: "Scroller",
                                    touch: true,
                                    //horizontal: "hidden",
                                    fit: true,
                                    components: [{
                                            name: "licenseRepeater",
                                            kind: "Repeater",
                                            count: 0,
                                            onSetupItem: "setupLicenseRow",
                                            components: [
                                                {
                                                    kind: "LicenseTextItem",
                                                }
                                            ]
                                    }]
                                },

        				]}
        		]},


    	]},
        /* Bottom toolbar */
        {
            name: "footer",
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
                {
					kind: "onyx.Button",
					name: "btnBack",
					classes: "center",
					content: "Back",
					ontap: "doBack",
					showing: false
				}
            ]
        },
		//service caller:
		{
			name: "listPackagesService",
			kind: "enyo.PalmService",
			service: "palm://org.webosports.service.licenses",
			method: "listPackages",
			subscribe: false,
			onComplete: "gotPackageList"
		},
		{
			name: "listLicenseService",
			kind: "enyo.PalmService",
			service: "palm://org.webosports.service.licenses",
			method: "listLicensesForPackage",
			subscribe: false,
			onComplete: "gotLicensesForPackage"
		},
		{
			name: "getLicenseService",
			kind: "enyo.PalmService",
			service: "palm://org.webosports.service.licenses",
			method: "getLicenseTextForPackage",
			subscribe: false,
			onComplete: "gotLicenseText"
		}
	],

	

	create: function (inSender, inEvent) {
        this.inherited(arguments);
        // load the packages in the background, not in the main load thread
        enyo.asyncMethod(this, this.bindSafely("loadPackages"));
	},

	reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow())
            this.$.Grabber.applyStyle("visibility", "hidden");
        else
            this.$.Grabber.applyStyle("visibility", "visible");
    },

    loadPackages: function(){
    	if (!window.PalmSystem) {
    		// Setup some mock data
    		this.packageList = ["Package 1", "Package 2", "Package 3", "Package 4", "Package 5", "Package 6", "Package 7", "Package 8", "Package 9", "Package 10"];
    		this.$.packageRepeater.setCount(this.packageList.length);
    	} else {
			this.$.listPackagesService.send({});
    	}

    },

    gotPackageList: function (inSender, inEvent) {
		var result = inEvent.data.packages;
		if(result) {
			this.packageList = result;
			this.$.packageRepeater.setCount(this.packageList.length);
		}
    },

    gotLicensesForPackage: function(inSender, inEvent){
    	var result = inEvent.data.licenses;
    	if(result) {
			this.licenseList = result;

			var numOfLicense = this.licenseList.length;
			for(var i=0; i<numOfLicense; i++){
				this.log("Calling getLicenseService for package:" + this.selectedPackage + " license:" +  this.licenseList[i]);
				this.$.getLicenseService.send({"package": this.selectedPackage, "license": this.licenseList[i]});
			}
			
		}	
    },

    gotLicenseText: function(inSender, inEvent) {
		var result = inEvent.data.license;
		if(result) {
			this.licenseTextList.push(String.fromCharCode.apply(null, new Uint16Array(result)));

			// we have got all the license, refresh the list
			if(this.licenseTextList.length == this.licenseList.length) {

				//this.log(this.licenseTextList);

				this.$.licenseRepeater.setCount(this.licenseTextList.length);	
				this.showLicense();	
			}
			
		}
    },

    showPackage: function() {
    	this.$.licensePanels.setIndex(0);
    	this.$.btnBack.hide();
    	this.$.footer.reflow();
    },

    showLoading: function() {
    	this.$.licensePanels.setIndex(1);
    	this.$.btnBack.show();
    	this.$.footer.reflow();
    },

    showLicense: function() {
    	this.$.licensePanels.setIndex(2);
    	this.$.btnBack.show();
    	this.$.footer.reflow();
    },

	setupPackageRow: function (inSender, inEvent) {
        inEvent.item.$.packageListItem.$.package.setContent(this.packageList[inEvent.index]);
	},

	packageSelected: function (inSender, inEvent) {

		this.selectedPackage = this.packageList[inEvent.index];

		this.log("Getting License for Package: " + this.selectedPackage);

		this.licenseTextList = [];

		if (!window.PalmSystem) {
    		// Setup some mock data
    		this.licenseTextList = ["License Text", "License Text"];
    		this.$.licenseRepeater.setCount(this.licenseTextList.length);
    		this.showLicense();
    	} else {
			this.$.listLicenseService.send({"package": this.selectedPackage});
			this.showLoading();
    	}
		
	},

	setupLicenseRow: function (inSender, inEvent) {
        inEvent.item.$.licenseTextItem.$.licenseText.setContent(this.licenseTextList[inEvent.index]);
	},

	doBack: function (inSender, inEvent) {
		this.showPackage();
	}

	
});
