enyo.kind({
	name: "ListItem",
	classes: "list-item",
	layoutKind: "FittableColumnsLayout",
	handlers: {
		onmousedown: "pressed",
		ondragstart: "released",
		onmouseup: "released"
	},
	published: {
		icon: "",
		title: ""
	},
	components:[
		{name: "ItemIcon", kind: "Image", style: "height: 100%"},
		{name: "ItemTitle", style: "padding-left: 10px;"}
	],
	create: function() {
		this.inherited(arguments);
		// this.$.ItemIcon.setSrc(this.icon);
		this.$.ItemTitle.setContent(this.title);
	},
	pressed: function() {
		this.addClass("onyx-selected");
	},
	released: function() {
		this.removeClass("onyx-selected");
	}
});

enyo.kind({
	name: "EmptyPanel",
	layoutKind: "FittableRowsLayout",
	style: "background-color: #555;",
	components:[
		{kind: "onyx.Toolbar"},
		{fit: true}
	]
});

enyo.kind({
	name: "AppPanels",
	kind: "Panels",
	realtimeFit: true,
	arrangerKind: "CollapsingArranger",
	events: {
		onBackMain: ""
	},
	handlers: {
		onBackbutton: "backButton"
	},
	debug: false,
	components:[
		{name: "MenuPanel",
		style: "width: 33%",
		layoutKind: "FittableRowsLayout",
		components:[
			{kind: "PortsHeader",
			title: "Settings",
			taglines: [
				"Ye gods, look at all those options!",
				"46% more wub-wub than last year's Settings.",
				"For all your tinkering needs.",
				"Customizable? Customizable.",
				"E pluribus unum.",
				"Schmettings.",
				"This is where the options live, get you some!"
			]},
			{kind: "Scroller",
			horizontal: "hidden",
			classes: "enyo-fill",
			style: "background-image:url('assets/bg.png')",
			fit: true,
			touch: true,
			components:[
				//Connectivity
				{kind: "onyx.Toolbar", classes: "list-header", content: "Connectivity"},
				{kind: "ListItem", icon: "icon.png", title: "Wi-Fi", ontap: "openPanel", targetPanel: "WiFiPanel",
				components:[
					{name: "WiFiToggle",
					kind: "onyx.ToggleButton",
					ontap: "wifiToggleChanged",
					style: "position: absolute; top: 11px; right: 9px; height: 31px;" }
				]},
				{kind: "ListItem", icon: "icon.png", title: "Bluetooth", ontap: "openPanel", targetPanel: "BluetoothPanel",
				components:[
					{name: "BluetoothToggle",
					kind: "onyx.ToggleButton",
					ontap: "bluetoothToggleChanged",
					style: "position: absolute; top: 11px; right: 9px; height: 31px;" }
				]},
				{kind: "ListItem", icon: "icon.png", title: "Telephony", ontap: "openPanel", targetPanel: "TelephonyPanel"},

				//Services
				{kind: "onyx.Toolbar", classes: "list-header", content: "Services"},
				{kind: "ListItem", icon: "icon.png", title: "System Updates", ontap: "openPanel", targetPanel: "SystemUpdatesPanel"},

				// Personal
				{kind: "onyx.Toolbar", classes: "list-header", content: "Personal"},
				{kind: "ListItem", icon: "icon.png", title: "Certificates", ontap: "openPanel", targetPanel: "CertificatesPanel"},

				//Core Settings
				{kind: "onyx.Toolbar", classes: "list-header", content: "Core"},
				{kind: "ListItem", icon: "icon.png", title: "Screen & Lock", ontap: "openPanel", targetPanel: "ScreenLockPanel"},
				{kind: "ListItem", icon: "icon.png", title: "Date & Time", ontap: "openPanel", targetPanel: "DateTimePanel"},
				{kind: "ListItem", icon: "icon.png", title: "Sound & Ringtones", ontap: "openPanel", targetPanel: "AudioPanel",
				components:[
					// Absolute positioning is not ideal.
					{name: "muteLabel", content: "Mute", style: "position: absolute; top: 4px; right: 92px; height: 31px;"},
					{name: "muteToggle",
					 kind: "onyx.ToggleButton",
					 ontap: "muteToggleChanged",
					 style: "position: absolute; top: 11px; right: 9px; height: 31px;" }
				]},
				{kind: "ListItem", icon: "icon.png", title: "Search Preferences", ontap: "openPanel", targetPanel: "SearchPreferencesPanel"},
				{kind: "ListItem", icon: "icon.png", title: "Language & Input", ontap: "openPanel", targetPanel: "LanguageInputPanel"},
				{kind: "ListItem", name: "DevModemListItem", icon: "icon.png", title: "Developer Options", ontap: "openPanel", targetPanel: "DevOptionsPanel", showing: false},
				{kind: "ListItem", icon: "icon.png", title: "About", ontap: "openPanel", targetPanel: "AboutPanel"}
			]}
		]},
		{name: "ContentPanels",
		kind: "enyo.Panels",
		arrangerKind: "CardArranger",
		draggable: false,
		classes: "onyx",
		index: 1,
		components:[
			{kind: "EmptyPanel"},
			{name: "WiFiPanel", kind: "WiFi", onActiveChanged: "wifiActiveChanged"},
			{name: "BluetoothPanel", kind: "Bluetooth", onActiveChanged: "bluetoothActiveChanged"},
			{name: "SystemUpdatesPanel", kind: "SystemUpdates"},
			{name: "CertificatesPanel", kind: "Certificates"},
			{name: "ScreenLockPanel", kind: "ScreenLock"},
			{name: "DateTimePanel", kind: "DateTime"},
			{name: "AudioPanel", kind: "Sound", onMuteChanged: "muteChanged"},
			{name: "SearchPreferencesPanel", kind: "SearchPreferences"},
			{name: "DevOptionsPanel", kind: "DevOptions"},
			{name: "TelephonyPanel", kind: "Telephony"},
			{name: "LanguageInputPanel", kind: "LanguageInput"},
			{name: "AboutPanel", kind: "About"}
		]},
		{name: "GetDevModeStatus", kind: "DevModeService", method: "getStatus", onComplete: "onDevModeGetStatusResponse"},
	],
	create: function() {
		this.inherited(arguments);
		this.$.GetDevModeStatus.send({});
	},
	//Action Functions
	wifiActiveChanged: function(inSender, inEvent) {
		this.$.WiFiToggle.setValue(inEvent.value);//@@
	},
	wifiToggleChanged: function(inSender) {
		this.$.WiFiPanel.setToggleValue(inSender.value);
		return true;
	},
	bluetoothActiveChanged: function(inSender, inEvent) {
		this.$.BluetoothToggle.setValue(inEvent.value);
	},
	bluetoothToggleChanged: function(inSender) {
		this.$.BluetoothPanel.setToggleValue(inSender.value);
		return true;
	},
	muteChanged: function(inSender, inEvent) {
		this.$.muteToggle.silence();
		this.$.muteToggle.setValue(inEvent.mute);
		this.$.muteToggle.unsilence();
	},
	muteToggleChanged: function(inSender) {
		this.$.AudioPanel.setMuteToggleValue(inSender.value);
		return true;
	},
	onDevModeGetStatusResponse: function(inSender, inResponse) {
		this.log(inResponse);
		if (inResponse.status === "enabled") {
			this.log("DevMode enabled, showing devmode list item");
			this.$.DevModemListItem.show();
		}
		else {
			this.log("DevMode disabled, hiding devmode list item");
			this.$.DevModemListItem.hide();
		}
	},
	//Panel selection functions
	openPanel: function(inSender, inEvent) {
		if (typeof inSender.targetPanel === 'undefined') {
		    this.log("No target panel defined!");
		    return;
		}
		this.log("Opening panel ", inSender.targetPanel);
		this.currentPanel = inSender.targetPanel;
		this.$.ContentPanels.selectPanelByName(inSender.targetPanel);
		this.selectContentPanel();
	},
	// Utility functions
	selectContentPanel: function() {
		if (enyo.Panels.isScreenNarrow())
			this.selectPanelByName("ContentPanels");
	},

	handleBack: function() {
		if (this.currentPanel === "AboutPanel")
			this.$.AboutPanel.handleBackGesture();
		else if (this.currentPanel === "WiFiPanel" )
			this.$.WiFiPanel.handleBackGesture();
		else if (this.currentPanel === "BluetoothPanel" )
			this.$.BluetoothPanel.handleBackGesture();
		else if (this.currentPanel === "CertificatesPanel")
			this.$.CertificatesPanel.handleBackGesture();
		else if (this.currentPanel === "DateTimePanel")
			this.$.DateTimePanel.handleBackGesture();
		else if (this.currentPanel === "ScreenLockPanel")
			this.$.ScreenLockPanel.handleBackGesture();
		else
			this.setIndex(0);
	},
	backButton: function(inSender, inEvent){
		this.log("sender:", inSender, ", event:", inEvent);
		this.setIndex(0);
	}
});

enyo.kind({
	name: "settings.MainView",
	layoutKind: "FittableRowsLayout",
	components: [
		{kind: "Signals",
		onbackbutton: "handleBackGesture",
		onCoreNaviDragStart: "handleCoreNaviDragStart",
		onCoreNaviDrag: "handleCoreNaviDrag",
		onCoreNaviDragFinish: "handleCoreNaviDragFinish",
		onrelaunch: "handleRelaunch"
		},
		{name: "AppPanels", kind: "AppPanels", fit: true},
		{kind: "CoreNavi", fingerTracking: true}
	],
	//Handlers
	create: function() {
		this.inherited(arguments);
		if (window.PalmSystem) {
			if(PalmSystem.launchParams !== null)
				this.handleRelaunch();
		}
	},
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.AppPanels.setDraggable(false);
			this.$.AppPanels.$.ContentPanels.applyStyle("box-shadow", "0");
			this.$.AppPanels.$.WiFiToggle.setShowing(true);
			this.$.AppPanels.$.BluetoothToggle.setShowing(true);
			this.$.AppPanels.$.muteLabel.setShowing(true);
			this.$.AppPanels.$.muteToggle.setShowing(true);
		}
		else {
			this.$.AppPanels.setDraggable(true);
			this.$.AppPanels.$.ContentPanels.applyStyle("box-shadow", "-4px 0px 4px rgba(0,0,0,0.3)");
			this.$.AppPanels.$.WiFiToggle.setShowing(false);
			this.$.AppPanels.$.BluetoothToggle.setShowing(false);
			this.$.AppPanels.$.muteLabel.setShowing(false);
			this.$.AppPanels.$.muteToggle.setShowing(false);
		}
	},
	handleRelaunch: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		this.log("launchParams: ", PalmSystem.launchParams);
		var params = JSON.parse(PalmSystem.launchParams);

		if (typeof(params.page) !== 'undefined') {
			var targetPanelName = params.page + "Panel";
			this.log("Switching to panel " + targetPanelName);
			this.$.AppPanels.openPanel({ targetPanel: targetPanelName });
		} else if (typeof(params.target) !== 'undefined' &&
			typeof(params.target.ssid) !== 'undefined' &&
			typeof(params.target.securityType !== 'undefined')) {
			this.$.AppPanels.openPanel({targetPanel:"WiFiPanel"});
			this.$.AppPanels.$.WiFiPanel.wifiTarget = params.target;
		}
	},
	handleBackGesture: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		this.$.AppPanels.handleBack();
		return true;
	},
	handleCoreNaviDragStart: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		this.$.AppPanels.dragstartTransition(this.$.AppPanels.draggable == false ? this.reverseDrag(inEvent) : inEvent);
	},
	handleCoreNaviDrag: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		this.$.AppPanels.dragTransition(this.$.AppPanels.draggable == false ? this.reverseDrag(inEvent) : inEvent);
	},
	handleCoreNaviDragFinish: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		this.$.AppPanels.dragfinishTransition(this.$.AppPanels.draggable == false ? this.reverseDrag(inEvent) : inEvent);
	},
	//Utility Functions
	reverseDrag: function(inEvent) {
		inEvent.dx = -inEvent.dx;
		inEvent.ddx = -inEvent.ddx;
		inEvent.xDirection = -inEvent.xDirection;
		return inEvent;
	}
});
