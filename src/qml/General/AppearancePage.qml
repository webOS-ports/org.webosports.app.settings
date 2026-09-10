/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * Appearance.
 *
 * Everything the other mobile Linuxes keep on a panel of this name - SFOS's
 * ambiences, UBports' Background & Appearance and Desktop & Launcher,
 * GNOME/Phosh's Background - LuneOS had spread over two places: the wallpaper
 * was a single row buried in Screen & Lock, and how the shell itself looks was
 * only reachable from the Tweaks app. Both are here now.
 *
 * Two different stores behind it, because they are genuinely two different
 * things:
 *
 *  - The wallpaper is a systemservice preference. Picking a picture goes
 *    through wallpaper/importWallpaper, which crops and scales it for the
 *    screen and hands back the wallpaper object to store; the card shell draws
 *    whatever the preference points at. That is the same path the row in
 *    Screen & Lock used, moved here unchanged.
 *
 *  - The rest are luna-next-cardshell's own tweaks, held by
 *    org.webosports.service.tweaks.prefs under the "luna-next-cardshell"
 *    owner. They are read with /get and written with /set, one key at a time,
 *    and the values and choices here are exactly the ones the shell's
 *    preference definition declares - AppTweaks.qml reads the same keys back
 *    out. The Tweaks app edits the same store; it is the developer-facing
 *    editor of every tweak there is, while this panel is the handful that are
 *    about how the device looks, in the place someone would look for them.
 *
 * Most of the shell tweaks are marked "restart": "luna" in that definition,
 * meaning the shell reads them at startup and does not watch them afterwards.
 * The page says so rather than looking as though nothing happened.
 */
BasePage {
    id: pageRoot

    property var wallpaper: ({})
    property bool prefsLoaded: false

    property bool tweaksAvailable: false

    // luna-next-cardshell tweaks
    property string showDateTime: "timeOnly"
    property string showBatteryPercentage: "iconOnly"
    property string batteryPercentageColor: "white"
    property bool useCustomCarrierString: false
    property string carrierString: "LuneOS"
    property bool tapRippleSupport: true
    property bool stackedCardSupport: true
    property bool showGestureArea: true
    property string tabTitleCase: "capitalizedCase"
    property string tabIndicatorNumber: "default"

    readonly property string tweakOwner: "luna-next-cardshell"

    readonly property var clockValues: ["dateOnly", "timeOnly", "dateTime"]
    readonly property var clockLabels: ["Date only", "Time only", "Date and time"]

    readonly property var batteryValues: ["iconOnly", "percentageOnly", "iconPercentage"]
    readonly property var batteryLabels: ["Icon only", "Percentage only", "Icon and percentage"]

    readonly property var batteryColorValues: ["white", "color"]
    readonly property var batteryColorLabels: ["White", "By charge left"]

    readonly property var titleCaseValues: ["upperCase", "lowerCase", "capitalizedCase"]
    readonly property var titleCaseLabels: ["UPPERCASE", "lowercase", "Capitalized Case"]

    readonly property var tabIndicatorValues: ["default", "1", "2", "3", "4", "all"]
    readonly property var tabIndicatorLabels: ["Default", "1", "2", "3", "4", "All"]

    Component.onCompleted: retrieveProperties();

    function _indexOf(values, value, fallback) {
        var at = values.indexOf(value);
        return at >= 0 ? at : fallback;
    }

    SettingsPageContent {
        GroupBox {
            width: parent.width
            title: "Wallpaper"

            LabelAndPicker {
                width: parent.width
                label: "Change Wallpaper"
                value: pageRoot.wallpaperName()
                placeholder: "Pick a picture"

                onClicked: {
                    wallpaperPicker.currentPath = pageRoot.wallpaper
                                                  ? (pageRoot.wallpaper.wallpaperFile || "") : "";
                    wallpaperPicker.open();
                }
            }
        }

        ServiceUnavailableNotice {
            visible: !pageRoot.tweaksAvailable
            serviceName: "org.webosports.service.tweaks.prefs"
            description: "How the shell itself looks is held by the tweaks " +
                         "service. The wallpaper above does not need it."
            onRetry: pageRoot.retrieveTweaks()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.tweaksAvailable
            title: "Status Bar"

            Column {
                width: parent.width

                LabelAndSelector {
                    id: clockSelector
                    width: parent.width
                    label: "Clock"
                    model: pageRoot.clockLabels

                    currentIndex: pageRoot._indexOf(pageRoot.clockValues,
                                                    pageRoot.showDateTime, 1)
                    Connections {
                        target: pageRoot
                        function onShowDateTimeChanged() {
                            clockSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.clockValues,
                                                  pageRoot.showDateTime, 1);
                        }
                    }
                    onActivated: (index) => pageRoot.setTweak("showDateTime",
                                                              pageRoot.clockValues[index])
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSelector {
                    id: batterySelector
                    width: parent.width
                    label: "Battery"
                    model: pageRoot.batteryLabels

                    currentIndex: pageRoot._indexOf(pageRoot.batteryValues,
                                                    pageRoot.showBatteryPercentage, 0)
                    Connections {
                        target: pageRoot
                        function onShowBatteryPercentageChanged() {
                            batterySelector.currentIndex =
                                pageRoot._indexOf(pageRoot.batteryValues,
                                                  pageRoot.showBatteryPercentage, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.setTweak("showBatteryPercentage",
                                                              pageRoot.batteryValues[index])
                }

                HorizontalSeparator {
                    width: parent.width
                    // Nothing to colour when only the icon is shown.
                    visible: pageRoot.showBatteryPercentage !== "iconOnly"
                    height: visible ? 1 : 0
                }

                LabelAndSelector {
                    id: batteryColorSelector
                    width: parent.width
                    visible: pageRoot.showBatteryPercentage !== "iconOnly"
                    height: visible ? Units.gu(6) : 0
                    label: "Percentage colour"
                    model: pageRoot.batteryColorLabels

                    currentIndex: pageRoot._indexOf(pageRoot.batteryColorValues,
                                                    pageRoot.batteryPercentageColor, 0)
                    Connections {
                        target: pageRoot
                        function onBatteryPercentageColorChanged() {
                            batteryColorSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.batteryColorValues,
                                                  pageRoot.batteryPercentageColor, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.setTweak("batteryPercentageColor",
                                                              pageRoot.batteryColorValues[index])
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: customCarrierSwitch
                    label: "Custom Carrier Name"

                    checked: pageRoot.useCustomCarrierString
                    Connections {
                        target: pageRoot
                        function onUseCustomCarrierStringChanged() {
                            customCarrierSwitch.checked = pageRoot.useCustomCarrierString;
                        }
                    }
                    onToggled: pageRoot.setTweak("useCustomCarrierString", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.useCustomCarrierString
                    height: visible ? 1 : 0
                }

                LabelAndTextField {
                    id: carrierField
                    width: parent.width
                    visible: pageRoot.useCustomCarrierString
                    height: visible ? Units.gu(6) : 0
                    label: "Shown instead"

                    text: pageRoot.carrierString
                    Connections {
                        target: pageRoot
                        function onCarrierStringChanged() {
                            if (!carrierField.activeFocus)
                                carrierField.text = pageRoot.carrierString;
                        }
                    }
                    // Written on every keystroke rather than on an accept:
                    // there is no OK button on this row, and the shell only
                    // reads the value at startup anyway.
                    onEdited: (text) => pageRoot.setTweak("carrierString", text)
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.tweaksAvailable
            title: "Cards"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: tapRippleSwitch
                    label: "Tap Ripple"

                    checked: pageRoot.tapRippleSupport
                    Connections {
                        target: pageRoot
                        function onTapRippleSupportChanged() {
                            tapRippleSwitch.checked = pageRoot.tapRippleSupport;
                        }
                    }
                    onToggled: pageRoot.setTweak("tapRippleSupport", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: stackedCardsSwitch
                    label: "Stacked Cards"

                    checked: pageRoot.stackedCardSupport
                    Connections {
                        target: pageRoot
                        function onStackedCardSupportChanged() {
                            stackedCardsSwitch.checked = pageRoot.stackedCardSupport;
                        }
                    }
                    onToggled: pageRoot.setTweak("stackedCardSupport", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: gestureAreaSwitch
                    label: "Gesture Area"

                    checked: pageRoot.showGestureArea
                    Connections {
                        target: pageRoot
                        function onShowGestureAreaChanged() {
                            gestureAreaSwitch.checked = pageRoot.showGestureArea;
                        }
                    }
                    onToggled: pageRoot.setTweak("showGestureArea", checked)
                }
            }
        }

        ExplanationText {
            visible: pageRoot.tweaksAvailable
            text: "The gesture area is the strip below the screen that a Pre " +
                  "had as hardware. Turning it off gives that space back to " +
                  "whatever is on screen."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.tweaksAvailable
            title: "Launcher"

            Column {
                width: parent.width

                LabelAndSelector {
                    id: titleCaseSelector
                    width: parent.width
                    label: "Tab Titles"
                    model: pageRoot.titleCaseLabels

                    currentIndex: pageRoot._indexOf(pageRoot.titleCaseValues,
                                                    pageRoot.tabTitleCase, 2)
                    Connections {
                        target: pageRoot
                        function onTabTitleCaseChanged() {
                            titleCaseSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.titleCaseValues,
                                                  pageRoot.tabTitleCase, 2);
                        }
                    }
                    onActivated: (index) => pageRoot.setTweak("tabTitleCase",
                                                              pageRoot.titleCaseValues[index])
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSelector {
                    id: tabIndicatorSelector
                    width: parent.width
                    label: "Indicators"
                    model: pageRoot.tabIndicatorLabels

                    currentIndex: pageRoot._indexOf(pageRoot.tabIndicatorValues,
                                                    pageRoot.tabIndicatorNumber, 0)
                    Connections {
                        target: pageRoot
                        function onTabIndicatorNumberChanged() {
                            tabIndicatorSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.tabIndicatorValues,
                                                  pageRoot.tabIndicatorNumber, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.setTweak("tabIndicatorNumber",
                                                              pageRoot.tabIndicatorValues[index])
                }
            }
        }

        ExplanationText {
            visible: pageRoot.tweaksAvailable
            text: "The shell reads most of these once, when it starts. A " +
                  "change to anything but the tab settings shows up the next " +
                  "time it does."
        }
    }

    WallpaperPickerPopup {
        id: wallpaperPicker

        onWallpaperSelected: (path) => pageRoot.importWallpaper(path)
    }

    /*
     * Wallpaper
     */
    function wallpaperName() {
        if (!wallpaper || !wallpaper.wallpaperName)
            return "";

        var name = wallpaper.wallpaperName;
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    function importWallpaper(path) {
        // systemservice crops and scales the picture for the screen and hands
        // back the wallpaper object to store; the shell draws whatever the
        // preference points at.
        luna.call("luna://com.webos.service.systemservice/wallpaper/importWallpaper",
                  JSON.stringify({"target": path}),
                  _handleWallpaperImported, _handleSetError);
    }

    function _handleWallpaperImported(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue || !response.wallpaper) {
            console.warn("Cannot import the wallpaper: " + message.payload);
            return;
        }

        pageRoot.wallpaper = response.wallpaper;
        _setPreference("wallpaper", response.wallpaper);
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["wallpaper"], "subscribe": true}),
                       _handleGetPreferences, _handleGetError);

        retrieveTweaks();
    }

    function retrieveTweaks() {
        luna.call("luna://org.webosports.service.tweaks.prefs/get",
                  JSON.stringify({"owner": pageRoot.tweakOwner,
                                  "keys": ["showDateTime", "showBatteryPercentage",
                                           "batteryPercentageColor",
                                           "useCustomCarrierString", "carrierString",
                                           "tapRippleSupport", "stackedCardSupport",
                                           "showGestureArea", "tabTitleCase",
                                           "tabIndicatorNumber"]}),
                  _handleGetTweaks, _handleTweaksUnavailable);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("wallpaper") && response.wallpaper)
            pageRoot.wallpaper = response.wallpaper;

        pageRoot.prefsLoaded = true;
    }

    /*
     * The tweak store keeps whatever type was written into it, and the two
     * definitions of a tweak do not always agree on which that is:
     * useCustomCarrierString is a boolean in the shell's preference file and
     * the string "false" in AppTweaks. Read both spellings rather than
     * trusting either.
     */
    function _asBool(value, fallback) {
        if (value === undefined || value === null)
            return fallback;
        if (typeof value === "string")
            return value === "true";
        return value === true;
    }

    function _asString(value, fallback) {
        return value === undefined || value === null ? fallback : String(value);
    }

    function _handleGetTweaks(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        pageRoot.showDateTime = _asString(response.showDateTime, pageRoot.showDateTime);
        pageRoot.showBatteryPercentage = _asString(response.showBatteryPercentage,
                                                   pageRoot.showBatteryPercentage);
        pageRoot.batteryPercentageColor = _asString(response.batteryPercentageColor,
                                                    pageRoot.batteryPercentageColor);
        pageRoot.useCustomCarrierString = _asBool(response.useCustomCarrierString,
                                                  pageRoot.useCustomCarrierString);
        pageRoot.carrierString = _asString(response.carrierString, pageRoot.carrierString);
        pageRoot.tapRippleSupport = _asBool(response.tapRippleSupport,
                                            pageRoot.tapRippleSupport);
        pageRoot.stackedCardSupport = _asBool(response.stackedCardSupport,
                                              pageRoot.stackedCardSupport);
        pageRoot.showGestureArea = _asBool(response.showGestureArea,
                                           pageRoot.showGestureArea);
        pageRoot.tabTitleCase = _asString(response.tabTitleCase, pageRoot.tabTitleCase);
        pageRoot.tabIndicatorNumber = _asString(response.tabIndicatorNumber,
                                                pageRoot.tabIndicatorNumber);

        pageRoot.tweaksAvailable = true;
    }

    function _handleTweaksUnavailable(message) {
        console.warn("Tweaks service did not answer: " + message);
        pageRoot.tweaksAvailable = false;
    }

    // Push changes to LuneOS
    function _setPreference(key, value) {
        if (!pageRoot.prefsLoaded) {
            console.log("Trying to set preferences before reading them first: ignoring.");
            return;
        }

        var params = {};
        params[key] = value;
        luna.call("luna://com.webos.service.systemservice/setPreferences", JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
    }

    function setTweak(key, value) {
        // Held locally as well as sent: /set has no subscription to report the
        // change back, so nothing else would move the row.
        pageRoot[key] = value;

        var params = {"owner": pageRoot.tweakOwner};
        params[key] = value;
        luna.call("luna://org.webosports.service.tweaks.prefs/set", JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
    }
}
