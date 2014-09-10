/*jslint sloppy: true */
/*global enyo, console*/

enyo.kind({
	name: "SystemUpdates",
	kind: "FittableRows",
	fit: true,
	currentRequest: false,
	published: {
		updateResults: null
	},
	components: [
		//ui components:
		{kind: "onyx.Toolbar", style: "line-height: 28px;", content: "System Update"},
		
		//display status information and change log:
		{
			name: "statusDisplay",
			classes: "nice-padding",
			style: "text-align: left;",
			fit: false,
			allowHtml: true,
			content: "No update information available. Check for updates now?"
		},
		{
			name: "changesDisplayContainer", 
			kind: "enyo.FittableRows", 
			classes: "changes-display", 
			fit: true, components: [
				{classes: "vspacer"},
				{kind: "enyo.FittableColumns", name: "spinnerContainer", style: "height: 69px;", showing: false, components: [
					{style: "width: 40%" },
					{name: "spinner", kind: "onyx.Spinner", showing: true, classes: "center onyx-light enyo-fill" },
					{style: "width: 40%" }
				]},
				{kind: "enyo.Scroller", fit: true, touch: true, components: [
					{name: "changesDisplay", classes: "nice-padding center", style: "text-align: left;", allowHtml: true}
				]},
				{classes: "vspacer"}
			]
		},
		
		//buttons:
		{name: "toolbarControls", kind: "onyx.Toolbar", style: "text-align: center", components: [
			{name: "Grabber", kind: "onyx.Grabber", style: "position: absolute; left: 0%; padding-left: 40px;"},
			{
				kind: "onyx.Button",
				name: "btnCheck",
				classes: "center",
				content: "Check for updates",
				ontap: "doCheck"
			},
			{
				kind: "onyx.Button",
				name: "btnDownload",
				classes: "onyx-affirmative center",
				content: "Download System Update",
				ontap: "doDownload",
				showing: false
			},
			{
				kind: "onyx.Button",
				name: "btnDownloadSkipFeeds",
				classes: "center",
				content: "Download anyway",
				ontap: "doDownloadSkipFeeds",
				showing: false
			},
			{
				kind: "onyx.Button",
				name: "btnInitiateUpdate",
				classes: "onyx-affirmative center",
				content: "Install System Update",
				ontap: "doInstall",
				showing: false
			}
		]},
		
		//service caller:
		{
			name: "updateService",
			kind: "enyo.PalmService",
			service: "palm://org.webosports.service.update",
			method: "checkUpdate",
			subscribe: false,
			onComplete: "updateChecked"
		},
		{
			name: "downloadService",
			kind: "enyo.PalmService",
			service: "palm://org.webosports.service.update",
			method: "downloadUpdate",
			subscribe: true,
			//resubscribe: true, //not sure what that really means.
			onComplete: "downloadComplete"
		},
		{
			name: "initiateService",
			kind: "enyo.PalmService",
			service: "palm://org.webosports.service.update",
			method: "initiateUpdate",
			subscribe: false,
			onComplete: "initiateUpdateComplete"
		}
	],
	reflow: function (inSender) {
        this.inherited(arguments);
        if (enyo.Panels.isScreenNarrow()){
            this.$.Grabber.applyStyle("visibility", "hidden");
        }else{
            this.$.Grabber.applyStyle("visibility", "visible");
        }
    },
	//button callbacks:
	doCheck: function (inSender, inEvent) {
		this.currentRequest = this.$.updateService.send({});
		this.startActivity("Checking remote platform version...");
	},
	doDownload: function (inSender, inEvent) {
		this.currentRequest = this.$.downloadService.send({});
		this.startActivity("Starting to download system update...");
	},
	doDownloadSkipFeeds: function (inSender, inEvent) {
		this.currentRequest = this.$.downloadService.send({skipFeedsUpdate: true});
		this.startActivity("Starting to download system update...");
	},
	doInstall: function (inSender, inEvent) {
		this.currentRequest = this.$.initiateService.send({});
		this.startActivity("Initiating reboot into system update state.");
	},

	//helper methods:
	startActivity: function (msg) {
		this.$.toolbarControls.hide();
		this.$.changesDisplay.hide();
		this.$.spinnerContainer.show();
		this.$.spinner.start();
		if (msg) {
			this.updateStatus(msg);
		}
		this.render();
	},
	stopActivity: function () {
		if (this.currentRequest) {
			this.currentRequest.cancel();
		}
		this.$.toolbarControls.show();
		this.$.spinner.stop();
		this.$.spinnerContainer.hide();
		this.$.changesDisplay.show();
		this.render();
	},

	updateStatus: function (msg) {
		this.$.statusDisplay.setContent(msg);
		this.resized();
	},

	//service callbacks:
	updateChecked: function (inSender, inEvent) {
		var result = inEvent.data;
		this.stopActivity();
		
		this.setUpdateResults(result);
	},

	downloadComplete: function (inSender, inEvent) {
		var result = inEvent.data, errorMsg;
		
		console.log("Got: " + JSON.stringify(result));
		if (result.error) { //had error. Download aborted or something...
			errorMsg = result.msg.replace(/\n/g, "<br>");
			this.updateStatus(errorMsg);

			this.$.btnDownloadSkipFeeds.hide();
			if (result.errorStage === "feedsUpdate") {
				console.log("Allow retry...");
				this.$.btnDownload.setContent("Retry");
				this.$.btnDownloadSkipFeeds.show();
			}
			this.stopActivity();
		} else if (result.finished) { //finished downloading
			this.updateStatus("Downloading finished");
			this.$.btnInitiateUpdate.show();
			this.$.btnDownload.hide();
			this.$.btnDownloadSkipFeeds.hide();
			this.stopActivity();
		} else { //only some status from service:
			this.updateStatus("Downloaded " + result.numDownloaded + " of " + result.toDownload + " packages.");
		}
	},

	initiateUpdateComplete: function (inSender, inEvent) {
		var result = inEvent.data;
		
		if (result.success) { //had error. Download aborted or something...
			this.updateStatus("Successfully initiated update. System will now reboot and update.");
		} else { //only some status from service:
			this.updateStatus("Error, could not initiate update: " + result.msg);
		}
		this.stopActivity();
	},

	setUpdateResults: function (result) {
		this.$.changesDisplay.setContent("");

		if (!result) {
			return;
		}

		if (result.success) {
			if (result.needUpdate) {
				this.updateStatus("An update is available.");

				enyo.forEach(result.changesSinceLast, function processChange(change) {
					var content = [
						"<p><strong>Version: ", change.version, "</strong></p>"
					], i;

					content.push("<ul>");
					for (i = 0; i < change.changes.length; i += 1) {
						content.push("<li>");
						content.push(change.changes[i]);
						content.push("</li>");
					}
					content.push("</ul>");

					content.push("<hr>");

					this.$.changesDisplay.addContent(content.join(""));
				}, this);
				
				this.$.btnDownload.show();
				this.$.btnCheck.hide();
			} else {
				this.updateStatus("Your system is up to date.");
			}
		} else if (result.success === false) {
			this.updateStatus("Could not check for updates: " + (result.message || result.errorText || "no error speficied."));
		}
	}
});
