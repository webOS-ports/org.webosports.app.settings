/*jslint browser: true, debug: true, sloppy: true, stupid: true, todo: true */
/*global enyo */
var utcOffSets = [
	{
		"utc": "Etc/GMT-12:00",
		"loc": "Baker Island, Howland Island (both uninhabited)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-11:00",
		"loc": "American Samoa, Niue",
		"tz": ""

	},

	{
		"utc": "Etc/GMT-10:00",
		"loc": "United States (Hawaii)",
		"tz": ""

	},
	{
		"utc": "Etc/GMT-9:30",
		"loc": "Marquesas Islands",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-9:00",
		"loc": "Gambier Islands",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-8:00",
		"loc": "British Columbia, Mexico Baja, California, Nevada, Oregon, Washington (state)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-7:00",
		"loc": "northeastern British Columbia, Mexico (Sonora), United States (Arizona)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-6:00",
		"loc": "Saskatchewan, Costa Rica, El Salvador, Ecuador, Guatemala, Honduras",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-5:00",
		"loc": "Colombia, Cuba, Ecuador (continental), Jamaica, Panama, Peru",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-4:30",
		"loc": "Venezuela",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-4:00",
		"loc": "Brazil, South Georgia and the South Sandwich Islands",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-3:30",
		"loc": "Newfoundland",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-3:00",
		"loc": "Argentina, Paraguay",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-2:00",
		"loc": "Brazil (Fernando de Noronha), South Georgia and the South Sandwich Islands",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-1:00",
		"loc": "Cape Verde",
		"tz": ""
	},
	{
		"utc": "Etc/GMT-0:00",
		"loc": "Cte d'Ivoire, Ghana, Iceland, Senegal, Saint Helena",
		"tz": ""
	},
	{
		"utc": "Etc/GMT1:00",
		"loc": "Algeria, Angola, Benin, Cameroon, Gabon, Niger, Nigeria, Tunisia",
		"tz": ""
	},
	{
		"utc": "Etc/GMT2:00",
		"loc": "Burundi, Egypt, Malawi, Mozambique, Kaliningrad Oblast, Rwanda, South Africa, Swaziland, Zambia, Zimbabwe",
		"tz": ""
	},
	{
		"utc": "Etc/GMT3:00",
		"loc": "Belarus, Djibouti, Eritrea, Ethiopia, Iraq, Kenya, Madagascar, Russia (European), Saudi Arabia, Somalia, South Sudan, Sudan, Tanzania, Uganda, Yemen|",
		"tz": ""
	},
	{
		"utc": "Etc/GMT3:30",
		"loc": "Baker Island",
		"tz": ""
	},
	{
		"utc": "Etc/GMT4:00",
		"loc": "Armenia, Azerbaijan, Georgia, Mauritius, Oman, Seychelles, United Arab Emirates",
		"tz": ""
	},
	{
		"utc": "Etc/GMT4:30",
		"loc": "Afghanistan",
		"tz": ""
	},
	{
		"utc": "Etc/GMT5:00",
		"loc": "Kazakhstan (west), Maldives, Pakistan, Uzbekistan",
		"tz": ""
	},
	{
		"utc": "Etc/GMT5:30",
		"loc": "India, Sri Lanka",
		"tz": ""
	},
	{
		"utc": "Etc/GMT5:45",
		"loc": "Nepal",
		"tz": ""
	},
	{
		"utc": "Etc/GMT6:00",
		"loc": "Kazakhstan (most), Bangladesh, Bhutan, Russia (Ural: Sverdlovsk Oblast, Chelyabinsk Oblast)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT6:30",
		"loc": "Cocos Islands, Myanmar",
		"tz": ""
	},
	{
		"utc": "Etc/GMT7:00",
		"loc": "Western Indonesia, Russia (Novosibirsk Oblast), Thailand, Vietnam, Cambodia,Laos",
		"tz": ""
	},
	{
		"utc": "Etc/GMT8:00",
		"loc": "Hong Kong, Central Indonesia, China, (Krasnoyarsk Krai), Malaysia, Philippines, Singapore, Taiwan, Mongolia, Western Australia, (Eucla) official, Macau,Brunei",
		"tz": ""
	},
	{
		"utc": "Etc/GMT8:45",
		"loc": "Australia (Eucla) unofficial",
		"tz": ""
	},
	{
		"utc": "Etc/GMT9:00",
		"loc": "Eastern Indonesia, East Timor, Russia (Irkutsk Oblast), Japan, North Korea, South Korea",
		"tz": ""
	},
	{
		"utc": "Etc/GMT9:30",
		"loc": "Australia (Northern Territory)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT10:00",
		"loc": "Russia (Zabaykalsky Krai), Papua New Guinea, Australia (Queensland)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT10:30",
		"loc": "Lord Howe Island",
		"tz": ""
	},
	{
		"utc": "Etc/GMT11:00",
		"loc": "New Caledonia, Russia (Primorsky Krai), Solomon Islands",
		"tz": ""
	},
	{
		"utc": "Etc/GMT11:30",
		"loc": "Norfolk Island",
		"tz": ""
	},
	{
		"utc": "Etc/GMT12:00",
		"loc": "Kiribati (Gilbert Islands), Fiji, Russia (Kamchatka Krai)",
		"tz": ""
	},
	{
		"utc": "Etc/GMT12:45",
		"loc": "Chatham Islands",
		"tz": ""
	},
	{
		"utc": "Etc/GMT13:00",
		"loc": "Kiribati (Phoenix Islands), Tonga, Tokelau",
		"tz": ""
	},
	{
		"utc": "Etc/GMT14:00",
		"loc": "Kiribati (Line Islands)",
		"tz": ""
	}

];

enyo.kind({
	name: "TimeZoneListItem",
	kind: "enyo.Control",
	classes: "group-item-wrapper",
	components: [
	{
		classes: "group-item-timezone",
		layoutKind: "FittableColumnsLayout",
		components: [
		{
			kind: "enyo.FittableRows",
			components: [
			{
				content: "",
				classes: "timezone-item",
				name: "Utc"
			},
			{
				content: "",
				classes: "timezone-item",
				name: "locations"
			},
			{
				content: "",
				classes: "timezone-item",
				name: "Tz"
			}]
		}]
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
	name: "TimeZonePicker",
	kind: "Control",
	published: {},
	events: {
		onClose: "",
		onTapped: ""
	},
	style: "height: 365px;",
	classes: "popup",
	components: [
		{
			kind: "enyo.FittableColumns",
			style: "height: 365px;",
			components: [
				{
					kind: "enyo.Scroller",
					style: "width: 100%;",
					touch: true,
					horizontal: "hidden",
					components: [
					{
						name: "SearchRepeater",
						kind: "Repeater",
						count: 0,
						onSetupItem: "setupSearchRow",
						components: [
						{
							name: "Zone",
							kind: "TimeZoneListItem",
							classes: "timezone-list",
							ontap: "listItemTapped"
						}]
					}]
				}

			]
		},
		{
			kind: "onyx.Button",
			content: "Close",
			style: "float: right;",
			ontap: "closePpoup"
		}

	],

	create: function () {
		this.inherited(arguments);
		// initialization code goes here
		this.utcOffSets = utcOffSets;
		this.$.SearchRepeater.setCount(this.utcOffSets.length);

	},
	setupSearchRow: function (inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);

		var utc = this.utcOffSets[inEvent.index].utc;
		var loc = this.utcOffSets[inEvent.index].loc;
		var tz = this.utcOffSets[inEvent.index].tz;

		inEvent.item.$.Zone.$.Utc.setContent(utc);
		inEvent.item.$.Zone.$.locations.setContent(loc);
		inEvent.item.$.Zone.$.Tz.setContent(this.utcOffSets[inEvent.index].tz);
	},
	closePpoup: function (inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
		this.doClose();

	},
	listItemTapped: function (inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code

		this.selected(this.utcOffSets[inEvent.index].utc);
		this.doTapped();
		this.doClose();
	},
	selected: function (id) {
		this.log("id", id);
		this.ZoneId = id;
	}
});
