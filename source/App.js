enyo.kind({
	name: "ListItem",
	classes: "list-item",
	layoutKind: "FittableColumnsLayout",
	handlers: {
		onmousedown: "pressed",
		ondragstart: "released",
		onmouseup: "released",
	},
	published: {
		icon: "",
		title: ""
	},
	components:[
		{name: "ItemIcon", kind: "Image", style: "height: 100%"},
		{name: "ItemTitle", style: "padding-left: 10px;"},
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
				{kind: "ListItem",
				icon: "icon.png",
				title: "Wi-Fi",
				ontap: "openWiFi",
				components:[
					{name: "WiFiToggle",
					kind: "onyx.ToggleButton",
					style: "position: absolute; top: 11px; right: 9px; height: 31px;",
					onChange: "wifiToggleChanged"}
				]},
				//{kind: "ListItem", icon: "icon.png", title: "Mobile Hotspot"}, //NOTE: Integrate into Wi-Fi
				/* No service implementation yet
				{kind: "ListItem",
				icon: "icon.png",
				title: "Bluetooth",
				ontap: "openBluetooth",
				components:[
					{kind: "onyx.ToggleButton",
					style: "height:32px; float: right;"}
				]},
				{kind: "ListItem",
				icon: "icon.png",
				title: "VPN",
				ontap: "openVPN",
				components:[
					{kind: "onyx.ToggleButton",
					style: "height:32px; float: right;"}
				]},
				*/
				{kind: "ListItem", icon: "icon.png", title: "Telephony", ontap: "openTelephony"},
				//Services
				{kind: "onyx.Toolbar", classes: "list-header", content: "Services"},
				//{kind: "ListItem", icon: "icon.png", title: "Accounts", ontap: "openAccounts"},
				//{kind: "ListItem", icon: "icon.png", title: "Backup", ontap: "openBackup"},
				//{kind: "ListItem", icon: "icon.png", title: "Text Assist", ontap: "openTextAssist"},
				{kind: "ListItem", icon: "icon.png", title: "Exhibition", ontap: "openExhibition"},
				//{kind: "ListItem", icon: "icon.png", title: "SIM", ontap: "openSIM"},
				//{kind: "ListItem", icon: "icon.png", title: "Software Manager", ontap: "openSoftwareManager"},
				//{kind: "ListItem", icon: "icon.png", title: "System Updates", ontap: "openSystemUpdates"},
				
				//Core Settings
				{kind: "onyx.Toolbar", classes: "list-header", content: "Core"},
				{kind: "ListItem", icon: "icon.png", title: "Screen & Lock", ontap: "openScreenLock"},
				//{kind: "ListItem", icon: "icon.png", title: "Sounds & Ringtones", ontap: "openSoundRingtones"},
				{kind: "ListItem", icon: "icon.png", title: "Date & Time", ontap: "openDateTime"},
				//{kind: "ListItem", icon: "icon.png", title: "Regional Settings", ontap: "openRegionalSettings"},
				//{kind: "ListItem", icon: "icon.png", title: "Location Services", ontap: "openLocationServices"},
				//{kind: "ListItem", icon: "icon.png", title: "Device Info", ontap: "openDeviceInfo"},
				{kind: "ListItem", icon: "icon.png", title: "Developer Options", ontap: "openDevOptions"},
			]},
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
			{}, //	{kind: "Bluetooth"},
			{}, //	{kind: "VPN"},
			{}, //	{kind: "Accounts"},
			{}, //	{kind: "Backup"},
			{}, //	{kind: "TextAssist"},
			{kind: "Exhibition"},
			{}, //	{kind: "SIM"},
			{}, //	{kind: "SoftwareManager"},
			{}, //	{kind: "SystemUpdates"},
			{kind: "ScreenLock"},
			{}, //	{kind: "SoundRingtones"},
			{kind: "DateTime"},
			{}, //	{kind: "RegionalSettings"},
			{}, //	{kind: "LocationServices"},
			{}, //	{kind: "DeviceInfo"},
			{kind: "DevOptions"},
			{kind: "Telephony"}
		]},
	],
	//Action Functions
	wifiActiveChanged: function(inSender, inEvent) {
		this.$.WiFiToggle.setValue(inEvent.value);
	},
	wifiToggleChanged: function(inSender) {
		this.$.WiFiPanel.setToggleValue(inSender.value);
	},
	//Panel selection functions
	openWiFi: function(inSender) {
		this.$.ContentPanels.setIndex(1);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openBluetooth: function(inSender) {
		this.$.ContentPanels.setIndex(2);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openVPN: function(inSender) {
		this.$.ContentPanels.setIndex(3);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openAccounts: function(inSender) {
		this.$.ContentPanels.setIndex(4);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openBackup: function(inSender) {
		this.$.ContentPanels.setIndex(5);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openTextAssist: function(inSender) {
		this.$.ContentPanels.setIndex(6);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openExhibition: function(inSender) {
		this.$.ContentPanels.setIndex(7);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openSIM: function(inSender) {
		this.$.ContentPanels.setIndex(8);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openSoftwareManager: function(inSender) {
		this.$.ContentPanels.setIndex(9);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openSystemUpdates: function(inSender) {
		this.$.ContentPanels.setIndex(10);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openScreenLock: function(inSender) {
		this.$.ContentPanels.setIndex(11);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openSoundRingtones: function(inSender) {
		this.$.ContentPanels.setIndex(12);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openDateTime: function(inSender) {
		this.$.ContentPanels.setIndex(13);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openRegionalSettings: function(inSender) {
		this.$.ContentPanels.setIndex(14);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openLocationServices: function(inSender) {
		this.$.ContentPanels.setIndex(15);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openDeviceInfo: function(inSender) {
		this.$.ContentPanels.setIndex(16);
		
		if(enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openDevOptions: function(inSender) {
		this.$.ContentPanels.setIndex(17);

		if (enyo.Panels.isScreenNarrow())
			this.setIndex(1);
	},
	openTelephony: function(inSender) {
		this.$.ContentPanels.setIndex(18);

		if (enyo.Panels.isScreenNarrow())
			this.setIndex(1);
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
			this.$.AppPanels.$ContentPanels.addStyles("box-shadow: 0");
		}
		else {
			this.$.AppPanels.setArrangerKind("CollapsingArranger");
			this.$.AppPanels.setDraggable(true);
			this.$.AppPanels.$.ContentPanels.addStyles("box-shadow: -4px 0px 4px rgba(0,0,0,0.3)");
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
