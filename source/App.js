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
		this.$.ItemIcon.setSrc(this.icon);
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
					style: "position: absolute; top: 11px; right: 9px; height: 31px;" }
				]},
				{kind: "ListItem", icon: "icon.png", title: "Telephony", ontap: "openPanel", targetPanel: "TelephonyPanel"},

				//Services
				{kind: "onyx.Toolbar", classes: "list-header", content: "Services"},
				{kind: "ListItem", icon: "icon.png", title: "System Updates", ontap: "openPanel", targetPanel: "SystemUpdatesPanel"},
				{kind: "ListItem", icon: "icon.png", title: "Licenses", ontap: "openPanel", targetPanel: "LicensesPanel"},
				
				//Core Settings
				{kind: "onyx.Toolbar", classes: "list-header", content: "Core"},
				{kind: "ListItem", icon: "icon.png", title: "Screen & Lock", ontap: "openPanel", targetPanel: "ScreenLockPanel"},
				{kind: "ListItem", icon: "icon.png", title: "Date & Time", ontap: "openPanel", targetPanel: "DateTimePanel"},
				{kind: "ListItem", icon: "icon.png", title: "Language & Input", ontap: "openPanel", targetPanel: "LanguageInputPanel"},
				{kind: "ListItem", icon: "icon.png", title: "Developer Options", ontap: "openPanel", targetPanel: "DevOptionsPanel"},
				{kind: "ListItem", icon: "icon.png", title: "About", ontap: "openPanel", targetPanel: "AboutPanel"}
			]}
		]},
		{name: "ContentPanels",
		kind: "Panels",
		arrangerKind: "CardArranger",
		draggable: false,
		classes: "onyx",
		index: 1,
		components:[
			{kind: "EmptyPanel"},
			{name: "WiFiPanel", kind: "WiFi", onActiveChanged: "wifiActiveChanged"},
			{name: "SystemUpdatesPanel", kind: "SystemUpdates"},
			{name: "LicensesPanel", kind: "Licenses"},
			{name: "ScreenLockPanel", kind: "ScreenLock"},
			{name: "DateTimePanel", kind: "DateTime"},
			{name: "DevOptionsPanel", kind: "DevOptions"},
			{name: "TelephonyPanel", kind: "Telephony"},
			{name: "LanguageInputPanel", kind: "LanguageInput"},
			{name: "AboutPanel", kind: "About"}
		]}
	],
	//Action Functions
	wifiActiveChanged: function(inSender, inEvent) {
		this.$.WiFiToggle.setValue(inEvent.value);
	},
	wifiToggleChanged: function(inSender) {
		this.$.WiFiPanel.setToggleValue(inSender.value);
	},
	//Panel selection functions
	openPanel: function(inSender, inEvent) {
		if (typeof inSender.targetPanel === 'undefined')
			return;
		this.$.ContentPanels.selectPanelByName(inSender.targetPanel);
		this.selectContentPanel();
	},
	// Utility functions
	selectContentPanel: function() {
		if (enyo.Panels.isScreenNarrow())
			this.selectPanelByName("ContentPanels");
	}
});

enyo.kind({
	name: "App",
	layoutKind: "FittableRowsLayout",
	components: [
		{kind: "Signals",
		ondeviceready: "deviceready",
		onbackbutton: "handleBackGesture",
		onCoreNaviDragStart: "handleCoreNaviDragStart",
		onCoreNaviDrag: "handleCoreNaviDrag",
		onCoreNaviDragFinish: "handleCoreNaviDragFinish",},
		{name: "AppPanels", kind: "AppPanels", fit: true},
		{kind: "CoreNavi", fingerTracking: true}
	],
	//Handlers
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.$.AppPanels.setArrangerKind("CoreNaviArranger");
			this.$.AppPanels.setDraggable(false);
			this.$.AppPanels.$.ContentPanels.applyStyle("box-shadow", "0");
		}
		else {
			this.$.AppPanels.setArrangerKind("CollapsingArranger");
			this.$.AppPanels.setDraggable(true);
			this.$.AppPanels.$.ContentPanels.applyStyle("box-shadow", "-4px 0px 4px rgba(0,0,0,0.3)");
		}
	},
	handleBackGesture: function(inSender, inEvent) {
		this.$.AppPanels.setIndex(0);
	},
	handleCoreNaviDragStart: function(inSender, inEvent) {
		this.$.AppPanels.dragstartTransition(this.$.AppPanels.draggable == false ? this.reverseDrag(inEvent) : inEvent);
	},
	handleCoreNaviDrag: function(inSender, inEvent) {
		this.$.AppPanels.dragTransition(this.$.AppPanels.draggable == false ? this.reverseDrag(inEvent) : inEvent);
	},
	handleCoreNaviDragFinish: function(inSender, inEvent) {
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
