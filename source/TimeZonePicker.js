
var utcOffSets = [
    {
            "utc": "-12:00",
            "loc": "Baker Island",
            "tz": "",
	},
    {
            "utc": "-11:00",
            "loc": "American Samoa",
            "tz": "",
          
    },
    
     {
            "utc": "-10:00",
            "loc": "United States (Hawaii)",
            "tz": "",
          
    },
    {
            "utc": "-9:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-9:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-8:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-7:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-6:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-5:00",
            "loc": " ",
            "tz": "",
	},
	{
            "utc": "-4:30",
            "loc": "Venezuela",
            "tz": "",
	},
	{
            "utc": "-4:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-3:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-2:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-1:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "-0:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "1:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "2:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "3:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "3:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "4:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "4:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "5:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "5:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "5:45",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "6:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "6:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "7:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "8:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "8:45",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "9:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "9:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "10:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "10:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "11:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "11:30",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "12:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "12:45",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "13:00",
            "loc": "Baker Island",
            "tz": "",
	},
	{
            "utc": "14:00",
            "loc": "Baker Island",
            "tz": "",
	},
    
];

enyo.kind({
	name: "TimeZoneListItem", kind: "enyo.Control", classes: "group-item-wrapper", components: [
				{classes: "group-item", layoutKind: "FittableColumnsLayout", components: [
						{kind: "enyo.FittableColumns", components: [
								{content: "", classes: "timezone-item", name: "Utc"},
								{content: "", classes: "timezone-item", name: "locations"},
								{content: "", classes: "timezone-item", name: "Tz"}
							]},
				]}
			],
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
	events: {onClose: ""},
	style: "height: 365px;",
	classes: "popup",
	components: [
		{kind: "enyo.FittableColumns",  style: "height: 365px;", components: [
			{kind: "enyo.Scroller",  style: "width: 100%;", touch: true, horizontal: "hidden",components: [
				{name: "SearchRepeater", kind: "Repeater", count: 0, onSetupItem: "setupSearchRow",components: [
				{name: "Zone", kind: "TimeZoneListItem", classes: "timezone-list", ontap: "listItemTapped"}
			]}
		]},
		
		]},
	{kind: "onyx.Button", content: "Close", style: "float: right;", ontap: "closePpoup"},
				
	],
	create: function() {
		this.inherited(arguments);
		// initialization code goes here
		this.utcOffSets = utcOffSets;
        this.$.SearchRepeater.setCount(this.utcOffSets.length);
		
	},
	setupSearchRow: function (inSender, inEvent) {
		console.log("sender:", inSender, ", event:", inEvent);
		console.log("inEvent.index", inEvent.index );
		var utc = this.utcOffSets[inEvent.index].utc;
		var loc = this.utcOffSets[inEvent.index].loc;
		var tz = this.utcOffSets[inEvent.index].tz;
		
		inEvent.item.$.Zone.$.Utc.setContent(utc);
		inEvent.item.$.Zone.$.locations.setContent(loc);
		inEvent.item.$.Zone.$.Tz.setContent(this.utcOffSets[inEvent.index].tz);
	},
	closePpoup: function(inSender, inEvent) {
		// TO DO - Auto-generated code
		this.doClose();
	
	},
	listItemTapped: function(inSender, inEvent) {
		this.log("sender:", inSender, ", event:", inEvent);
		// TO DO - Auto-generated code
	}
});
