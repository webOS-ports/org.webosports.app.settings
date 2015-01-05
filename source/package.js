enyo.depends(
	"$lib/layout",
	"$lib/onyx",	// To theme Onyx using Theme.less, change this line to $lib/onyx/source,
	//"Theme.less",	// uncomment this line, and follow the steps described in Theme.less
	"$lib/more-arrangers",
	"$lib/webos-lib",
	"DevModeService.js",
	//Main App
	"App.css",
	"App.js",
	//Settings Panels
	"DateTime.js",
	"ScreenLock.js",
	"WiFi.js",
	"DevOptions.js",
	"Telephony.js",
	"SystemUpdates.css",
	"SystemUpdates.js",
	"LanguageInput.js",
	"About.js",
	"Licenses.js",
	"Sound.js",
	"pickRingTones.js",
	"TimeZonePicker.js"
);
