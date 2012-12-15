enyo.kind({
	name: "App",
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
					{kind: "onyx.ToggleButton", style: "height:32px; float: right;"}
				]},
				//{kind: "ListItem", icon: "icon.png", title: "Mobile Hotspot"}, //NOTE: Integrate into Wi-Fi
				{kind: "ListItem",
				icon: "icon.png",
				title: "Bluetooth",
				ontap: "openBluetooth",
				components:[
					{kind: "onyx.ToggleButton", style: "height:32px; float: right;"}
				]},
				{kind: "ListItem",
				icon: "icon.png",
				title: "VPN",
				ontap: "openVPN",
				components:[
					{kind: "onyx.ToggleButton", style: "height:32px; float: right;"}
				]},
				
				//Services
				{kind: "onyx.Toolbar", classes: "list-header", content: "Services"},
				{kind: "ListItem", icon: "icon.png", title: "Accounts", ontap: "openAccounts"},
				{kind: "ListItem", icon: "icon.png", title: "Backup", ontap: "openBackup"},
				{kind: "ListItem", icon: "icon.png", title: "Text Assist", ontap: "openTextAssist"},
				{kind: "ListItem", icon: "icon.png", title: "Exhibition", ontap: "openExhibition"},
				{kind: "ListItem", icon: "icon.png", title: "SIM", ontap: "openSIM"},
				{kind: "ListItem", icon: "icon.png", title: "Software Manager", ontap: "openSoftwareManager"},
				{kind: "ListItem", icon: "icon.png", title: "System Updates", ontap: "openSystemUpdates"},
				
				//Core Settings
				{kind: "onyx.Toolbar", classes: "list-header", content: "Core"},
				{kind: "ListItem", icon: "icon.png", title: "Screen & Lock", ontap: "openScreenLock"},
				{kind: "ListItem", icon: "icon.png", title: "Sounds & Ringtones", ontap: "openSoundRingtones"},
				{kind: "ListItem", icon: "icon.png", title: "Date & Time", ontap: "openDateTime"},
				{kind: "ListItem", icon: "icon.png", title: "Regional Settings", ontap: "openRegionalSettings"},
				{kind: "ListItem", icon: "icon.png", title: "Location Services", ontap: "openLocationServices"},
				{kind: "ListItem", icon: "icon.png", title: "Device Info", ontap: "openDeviceInfo"},
			]},
		]},
		{name: "ContentPanels",
		kind: "Panels",
		arrangerKind: "CardArranger",
		draggable: false,
		index: 1,
		components:[
			{kind: "EmptyPanel"},
			{kind: "WiFi"},
			{}, //	{kind: "Bluetooth"},
			{}, //	{kind: "VPN"},
			{}, //	{kind: "Accounts"},
			{}, //	{kind: "Backup"},
			{}, //	{kind: "TextAssist"},
			{}, //	{kind: "Exhibition"},
			{}, //	{kind: "SIM"},
			{}, //	{kind: "SoftwareManager"},
			{}, //	{kind: "SystemUpdates"},
				{kind: "ScreenLock"},
			{}, //	{kind: "SoundRingtones"},
			{}, //	{kind: "DateTime"},
			{}, //	{kind: "RegionalSettings"},
			{}, //	{kind: "LocationServices"},
			{}, //	{kind: "DeviceInfo"},
		]},
	],
	reflow: function(inSender) {
		this.inherited(arguments);
		if(enyo.Panels.isScreenNarrow()) {
			this.setArrangerKind("PushPopArranger");
			this.$.ContentPanels.addStyles("box-shadow: 0");
		}
		else {
			this.setArrangerKind("CollapsingArranger");
			this.$.ContentPanels.addStyles("box-shadow: -4px 0px 4px rgba(0,0,0,0.3)");
		}
	},
	openWiFi: function(inSender) { this.$.ContentPanels.setIndex(1); },
	openBluetooth: function(inSender) { this.$.ContentPanels.setIndex(2); },
	openVPN: function(inSender) { this.$.ContentPanels.setIndex(3); },
	openAccounts: function(inSender) { this.$.ContentPanels.setIndex(4); },
	openBackup: function(inSender) { this.$.ContentPanels.setIndex(5); },
	openTextAssist: function(inSender) { this.$.ContentPanels.setIndex(6); },
	openExhibition: function(inSender) { this.$.ContentPanels.setIndex(7); },
	openSIM: function(inSender) { this.$.ContentPanels.setIndex(8); },
	openSoftwareManager: function(inSender) { this.$.ContentPanels.setIndex(9); },
	openSystemUpdates: function(inSender) { this.$.ContentPanels.setIndex(10); },
	openScreenLock: function(inSender) { this.$.ContentPanels.setIndex(11); },
	openSoundRingtones: function(inSender) { this.$.ContentPanels.setIndex(12); },
	openDateTime: function(inSender) { this.$.ContentPanels.setIndex(13); },
	openRegionalSettings: function(inSender) { this.$.ContentPanels.setIndex(14); },
	openLocationServices: function(inSender) { this.$.ContentPanels.setIndex(15); },
	openDeviceInfo: function(inSender) { this.$.ContentPanels.setIndex(16); }
});


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
		{name: "ItemIcon", kind: "Image", style: "width: 42px"},
		{name: "ItemTitle", style: "padding-left: 10px; line-height: 42px"},
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
