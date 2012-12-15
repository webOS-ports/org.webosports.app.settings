enyo.kind({
	name: "WiFiService",
	kind: "enyo.webOS.ServiceRequest",
	service: "palm://com.palm.wifi/"
});

enyo.kind({
	name: "WiFi",
	layoutKind: "FittableRowsLayout",
	components: [
		{name: "SetRadioState",
		kind: "WiFiService",
		method: "setstate",
		onFailure: "handleSetStateFailure"},
		
		{name: "GetConnectionStatus",
		kind: "WiFiService",
		method: "getstatus",
		subscribe: true,
		resubscribe: true,
		onResponse: "handleWiFiConnectionStatus"},
		
		{name: "FindNetworks",
		kind: "WiFiService",
		method: "findnetworks",
		onResponse: "handleFindNetworksResponse"},
		
		{name: "Connect",
		kind: "WiFiService",
		method: "connect",
		onResponse: "handleConnectResponse"},
		
		{name: "GetProfileInfo",
		kind: "WiFiService",
		method: "getprofile",
		onResponse: "handleProfileInfoResponse"},
		
		{name: "GetWiFiInfo",
		kind: "WiFiService",
		method: "getinfo",
		onSuccess: "handleWiFiInfoResponse"},
		
		{name: "DeleteProfile",
		kind: "WiFiService", 
		method: "deleteprofile",
		onFailure: "handleDeleteProfileFailure"},
		
		{kind: "onyx.Toolbar",
		style: "line-height: 36px;",
		components:[
				{content: "Wi-Fi"},
				{kind: "onyx.ToggleButton", style: "float: right;"}
		]},
		{name: "WiFiPanels",
		kind: "Panels",
		arrangerKind: "HFlipArranger",
		fit: true,
		draggable: false,
		components:[
				{name: "SearchList",
				layoutKind: "FittableRowsLayout",
				style: "padding: 35px 10% 35px 10%;",
				components:[
					{kind: "onyx.GroupboxHeader", style: "border-radius: 8px 8px 0 0;", content: "Choose a Network"},
					{kind: "Scroller",
					touch: true,
					horizontal: "hidden",
					fit: true,
					style: "border: 1px solid white; border-top: 0; border-radius: 0 0 8px 8px;",
					components:[
						{kind: "Repeater", count: 1, components: [
							{name: "SearchListItem", classes: "group-item", content: "Search List Item"}
						]}
					]},
				]},
				{name: "KnownList",
				layoutKind: "FittableRowsLayout",
				style: "padding: 35px 10% 35px 10%;",
				components:[
					{kind: "onyx.GroupboxHeader", style: "border-radius: 8px 8px 0 0;", content: "Known Networks"},
					{kind: "Scroller",
					touch: true,
					horizontal: "hidden",
					fit: true,
					style: "border: 1px solid white; border-top: 0; border-radius: 0 0 8px 8px;",
					components:[
						{kind: "Repeater", count: 1, components: [
							{name: "KnownListItem", classes: "group-item", content: "Known List Item"}
						]}
					]},
				]},
				{ /* Workaround for HFlipArranger incorrectly displaying with 2 panels*/ }
		]},
		{kind: "onyx.Toolbar", components:[
			{kind: "onyx.RadioGroup",
			style: "position: absolute; left: 50%; margin-left: -76px;",
			components:[
				{content: "Search", active: true, ontap: "searchTapped"},
				{content: "Known", ontap: "knownTapped"}
			]},
			{kind: "onyx.IconButton",
			src: "assets/icon-new.png",
			style: "float: right; margin-top: 6px;",
			ontap: ""},
			{kind: "onyx.Button",
			content: "Rescan",
			style: "float: right; margin-top: 5px;",
			ontap: ""},
		]}
	],
	searchTapped: function(inSender, inEvent) {
		this.$.WiFiPanels.setIndex(0);
	},
	knownTapped: function(inSender, inEvent) {
		this.$.WiFiPanels.setIndex(1);
	}
});
