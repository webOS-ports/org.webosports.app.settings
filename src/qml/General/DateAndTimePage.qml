/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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
 * Date & Time, after the webOS 3.0.5 app of the same name
 * (com.palm.app.dateandtime).
 *
 * Same rows in the same order as the original: the time format selector, the
 * Network Time switch with the pickers that appear underneath it when it is
 * off, the Network Time Zone switch, and the time zone row that opens the
 * searchable zone list.
 *
 * Everything here is luna-sysservice, which LuneOS carries unchanged from
 * webOS, so this is one of the few pages that maps one-for-one:
 *  - timeFormat, useNetworkTime, useNetworkTimeZone and timeZone are plain
 *    systemservice preferences, subscribed so the page follows a zone that
 *    arrives over NITZ while it is open.
 *  - the clock comes from time/getSystemTime, also subscribed: it re-reports
 *    on every jump, which is how the row updates the moment a network time
 *    lands.
 *  - setting the clock by hand is time/setSystemTime, in whole seconds.
 *  - the zone list is getPreferenceValues, the same call the original used.
 *
 * The Network Time Zone group is hidden when there is no telephony on the bus:
 * without a modem there is no NITZ to receive, so the switch would be a
 * setting that could never do anything. The original made the same decision
 * from a com.palm.telephony platformQuery.
 */
BasePage {
    id: pageRoot

    property string timeFormat: "HH12"
    property bool useNetworkTime: true
    property bool useNetworkTimeZone: true
    // luna-sysservice clears these while it is still waiting for the network
    // to hand it a time or a zone, which is what the two "waiting" lines below
    // are about.
    property bool networkTimeReceived: true
    property bool networkTimeZoneReceived: true
    property bool telephonyAvailable: false

    property var timeZone: ({})
    property var availableZones: []

    // Seconds since the epoch as the service last reported them, and the
    // moment we heard it, so the clock can tick on locally in between.
    property real systemTimeUtc: 0
    property real systemTimeReceivedAt: 0
    property string timeZoneAbbreviation: ""

    readonly property bool is24Hour: timeFormat === "HH24"

    // Preferences arrive asynchronously; don't write anything back before the
    // first read has landed, or the defaults above would overwrite the device.
    property bool prefsLoaded: false

    Component.onCompleted: retrieveProperties();

    // The current-time row ticks once a second like the original's setInterval
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: pageRoot.now = pageRoot.currentDeviceTime()
    }

    SettingsPageContent {
        GroupBox {
            width: parent.width
            title: "Time Format"

            LabelAndSelector {
                id: timeFormatSelector
                width: parent.width
                label: "Clock"
                model: ["12 hour", "24 hour"]

                currentIndex: pageRoot.is24Hour ? 1 : 0
                Connections {
                    target: pageRoot
                    function onTimeFormatChanged() {
                        timeFormatSelector.currentIndex = pageRoot.is24Hour ? 1 : 0;
                    }
                }
                onActivated: (index) => pageRoot.setTimeFormat(index === 1 ? "HH24" : "HH12")
            }
        }

        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: networkTimeSwitch
                    label: "Network Time"

                    checked: pageRoot.useNetworkTime
                    Connections {
                        target: pageRoot
                        function onUseNetworkTimeChanged() {
                            networkTimeSwitch.checked = pageRoot.useNetworkTime;
                        }
                    }
                    onToggled: pageRoot.setUseNetworkTime(checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndValue {
                    width: parent.width
                    label: "Current"
                    value: pageRoot.formatDateTime(pageRoot.now)
                }
            }
        }

        ExplanationText {
            // The legacy wording, kept: it is the one thing that explains why
            // the clock has not moved to the network's idea of the time yet.
            text: pageRoot.useNetworkTime && !pageRoot.networkTimeReceived
                  ? "Network time will be set when the network and server are available."
                  : ""
        }

        /*
         * Set-by-hand pickers. The original showed these whenever the network
         * time was off - and also while it was on but had not arrived yet, so
         * the device was never left with no way to set its clock.
         */
        GroupBox {
            id: manualTimeGroup
            width: parent.width
            visible: !pageRoot.useNetworkTime || !pageRoot.networkTimeReceived

            title: "Set Date & Time"

            // The wheels are loaded to the clock when the group appears and
            // left alone afterwards, exactly as the original did on the way
            // in. Following the ticking clock instead would drag a wheel out
            // from under the finger that is spinning it.
            onVisibleChanged: if (visible) pageRoot.loadPickers()

            Column {
                width: parent.width

                DatePicker {
                    id: datePicker
                    width: parent.width
                    label: "Date"

                    onEdited: (newDate) => pageRoot.applyDeviceTime(newDate)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                TimePicker {
                    id: timePicker
                    width: parent.width
                    label: "Time"
                    is24Hour: pageRoot.is24Hour

                    onEdited: (newTime) => pageRoot.applyDeviceTime(newTime)
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.telephonyAvailable

            LabelAndSwitch {
                id: networkTimeZoneSwitch
                label: "Network Time Zone"

                checked: pageRoot.useNetworkTimeZone
                Connections {
                    target: pageRoot
                    function onUseNetworkTimeZoneChanged() {
                        networkTimeZoneSwitch.checked = pageRoot.useNetworkTimeZone;
                    }
                }
                onToggled: pageRoot.setUseNetworkTimeZone(checked)
            }
        }

        ExplanationText {
            text: pageRoot.telephonyAvailable && pageRoot.useNetworkTimeZone &&
                  !pageRoot.networkTimeZoneReceived
                  ? "Waiting for network time zone. Turn Airplane Mode on and then off again to update immediately."
                  : ""
        }

        GroupBox {
            width: parent.width
            // Picking a zone by hand while the network supplies one would be
            // overwritten by the next NITZ message, so the original hid the
            // row rather than let that happen.
            visible: !pageRoot.telephonyAvailable || !pageRoot.useNetworkTimeZone

            title: "Time Zone"

            LabelAndPicker {
                width: parent.width
                label: "Time Zone"
                value: pageRoot.timeZoneDescription()
                placeholder: "Pick a time zone"

                onClicked: {
                    timeZonePicker.zones = pageRoot.availableZones;
                    timeZonePicker.currentZoneId = pageRoot.timeZone
                                                   ? (pageRoot.timeZone.ZoneID || "") : "";
                    timeZonePicker.open();
                }
            }
        }
    }

    TimeZonePickerPopup {
        id: timeZonePicker

        onZoneSelected: (zone) => pageRoot.setTimeZone(zone)
    }

    /*
     * The clock
     */
    // The device's own time, carried forward from the last report rather than
    // read off the host: on LuneOS the two are the same, but on desktop the
    // page then shows what the (mocked) service says instead of the wall clock.
    function currentDeviceTime() {
        if (systemTimeUtc === 0)
            return new Date();

        return new Date((systemTimeUtc + (Date.now() - systemTimeReceivedAt) / 1000) * 1000);
    }

    function loadPickers() {
        var deviceTime = currentDeviceTime();
        datePicker.value = deviceTime;
        timePicker.value = deviceTime;
    }

    // The zone is named on its own row below, so the clock does not repeat it:
    // spelled out in full the line no longer fits a phone.
    function formatDateTime(when) {
        var pattern = pageRoot.is24Hour ? "ddd, d MMM yyyy  HH:mm:ss"
                                        : "ddd, d MMM yyyy  h:mm:ss AP";
        return Qt.formatDateTime(when, pattern);
    }

    function timeZoneDescription() {
        if (!timeZone || !timeZone.ZoneID)
            return "";

        var name = timeZone.City && timeZone.City !== ""
                   ? timeZone.City + ", " + timeZone.Country
                   : (timeZone.Country && timeZone.Country !== "" ? timeZone.Country
                                                                  : timeZone.ZoneID);
        return timeZoneAbbreviation !== "" ? name + " (" + timeZoneAbbreviation + ")" : name;
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["timeFormat", "timeZone", "useNetworkTime",
                                                "useNetworkTimeZone", "receiveNetworkTimeUpdate",
                                                "receiveNetworkTimezoneUpdate"],
                                       "subscribe": true}),
                       _handleGetPreferences, _handleGetError);

        // Subscribed rather than polled: this re-reports on every jump, which
        // is how the row picks up a time that arrived over the network.
        luna.subscribe("luna://com.webos.service.systemservice/time/getSystemTime",
                       JSON.stringify({"subscribe": true}),
                       _handleGetSystemTime, _handleGetError);

        luna.call("luna://com.webos.service.systemservice/getPreferenceValues",
                  JSON.stringify({"key": "timeZone"}),
                  _handleGetTimeZones, _handleGetError);

        // No modem, no NITZ: don't offer a network time zone switch that could
        // never receive anything.
        luna.subscribe("luna://com.webos.service.bus/signal/registerServerStatus",
                       JSON.stringify({"serviceName": "com.palm.telephony", "subscribe": true}),
                       _handleTelephonyStatus, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("timeFormat"))
            pageRoot.timeFormat = response.timeFormat;
        if (response.hasOwnProperty("useNetworkTime"))
            pageRoot.useNetworkTime = response.useNetworkTime;
        if (response.hasOwnProperty("useNetworkTimeZone"))
            pageRoot.useNetworkTimeZone = response.useNetworkTimeZone;
        if (response.hasOwnProperty("receiveNetworkTimeUpdate"))
            pageRoot.networkTimeReceived = response.receiveNetworkTimeUpdate;
        if (response.hasOwnProperty("receiveNetworkTimezoneUpdate"))
            pageRoot.networkTimeZoneReceived = response.receiveNetworkTimezoneUpdate;
        if (response.hasOwnProperty("timeZone") && response.timeZone)
            pageRoot.timeZone = response.timeZone;

        pageRoot.prefsLoaded = true;
    }

    function _handleGetSystemTime(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("utc")) {
            var firstReport = pageRoot.systemTimeUtc === 0;

            pageRoot.systemTimeUtc = response.utc;
            pageRoot.systemTimeReceivedAt = Date.now();
            pageRoot.now = pageRoot.currentDeviceTime();

            // The very first report, and any later jump the service makes
            // behind our back, is what the wheels should be showing.
            if (firstReport && manualTimeGroup.visible)
                pageRoot.loadPickers();
        }
        // "TZ" is the abbreviation the zone is in right now (CET vs CEST), so
        // it follows daylight saving where the zone's own Description does not.
        if (response.hasOwnProperty("TZ"))
            pageRoot.timeZoneAbbreviation = response.TZ;
    }

    function _handleGetTimeZones(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("timeZone"))
            pageRoot.availableZones = response.timeZone;
    }

    function _handleTelephonyStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("connected"))
            pageRoot.telephonyAvailable = response.connected;
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

    function setTimeFormat(format) {
        pageRoot.timeFormat = format;
        _setPreference("timeFormat", format);
    }

    function setUseNetworkTime(on) {
        pageRoot.useNetworkTime = on;
        _setPreference("useNetworkTime", on);
    }

    function setUseNetworkTimeZone(on) {
        pageRoot.useNetworkTimeZone = on;
        _setPreference("useNetworkTimeZone", on);
    }

    function setTimeZone(zone) {
        pageRoot.timeZone = zone;
        _setPreference("timeZone", zone);
    }

    function applyDeviceTime(when) {
        // Setting the clock by hand means this is no longer the network's
        // time; say so, or the next network update would be treated as a
        // correction to a time we just chose.
        _setPreference("receiveNetworkTimeUpdate", false);

        luna.call("luna://com.webos.service.systemservice/time/setSystemTime",
                  JSON.stringify({"utc": Math.floor(when.getTime() / 1000)}),
                  _handleSetSuccess, _handleSetTimeError);
    }

    function _handleSetTimeError(message) {
        console.warn("ERROR: Unable to set the time: " + message);
    }
}
