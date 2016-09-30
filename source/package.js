enyo.depends(
	"$lib/layout",
	"$lib/onyx/source",	// To theme Onyx using Theme.less, change this line to $lib/onyx/source,
	"style/Theme.less",	// uncomment this line, and follow the steps described in Theme.less
	"$lib/more-arrangers",
	"$lib/enyo-webos",
	"$lib/webos-lib",
	// CSS/LESS style files
	"style",
	// Model and data definitions
	"data",
	// View kind definitions
	"views",
	// Include our default entry point
	"App.js"
);
