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
 * Battery.
 *
 * There was no legacy webOS app for this - the Palm devices only ever put the
 * charge in the status bar and a "Battery" line in Device Info. SFOS, UBports,
 * Droidian/GNOME and FuriOS all give it a page of its own, and this follows
 * what they put on it: the charge, whether it is charging and from what, and
 * the numbers a failing pack shows up in first.
 *
 * All of it comes from batteryd (com.webos.service.battery), which reads nyx:
 *  - batteryStatusQuery returns percent, percent_ui, temperature_C,
 *    current_mA, voltage_mV and capacity_mAh for the primary battery, plus -
 *    on the devices that have more than one pack - a "batteries" array with a
 *    name, role and its own reading per pack. The array is deliberately absent
 *    on single-battery devices rather than being a one-element list, so the
 *    per-pack group below only appears where there is genuinely something to
 *    tell apart.
 *  - chargerStatusQuery returns DockConnected/DockPower/DockSerialNo for the
 *    Touchstone-style inductive chargers, USBConnected/USBName ("pc", "wall",
 *    "direct" or "none") for the wired ones, and Charging.
 *
 * Neither method takes "subscribe". batteryd instead publishes LS2 signals -
 * batteryStatus and USBDockStatus on /com/palm/power - whenever a reading
 * moves, so the page asks the bus to match those and re-reads on each one.
 * That is the same shape as a subscription without asking batteryd for an API
 * it does not have, and it means the page is quiet while nothing changes
 * rather than polling a sysfs-backed daemon on a timer. Those are the two
 * matches the status bar indicator already makes for the same readings.
 *
 * Two things deliberately absent:
 *  - There is no battery saver switch. batterySaverOnOff is named in
 *    batteryd's ACG file but no such method is registered in the service, and
 *    LuneOS has no power policy behind it to turn on. See
 *    docs/missing-services.md.
 *  - There is no "screen turns off after" row. That is a display timeout and
 *    it lives on the Display page; this one links across to it instead of
 *    keeping a second copy of the same setting.
 */
BasePage {
    id: pageRoot

    property bool batteryServiceAvailable: false

    // Primary battery
    property int percent: -1
    property int percentUi: -1
    property int temperature: 0
    property int current: 0
    property int voltage: 0
    // -1 until something answers, and left at -1 by a device whose driver
    // reports neither charge_now nor charge_counter.
    property real capacity: -1

    // What the gauge believes the pack holds when full, and what it held when
    // it was made. Both -1 where the driver is silent.
    property real capacityFull: -1
    property real capacityDesign: -1

    // The driver's own verdict, as batteryd's word for it.
    property string health: "unknown"

    readonly property bool healthKnown: pageRoot.healthIsKnown(pageRoot.health)

    /*
     * Wear is only knowable when both capacities are, and only meaningful
     * when they differ. A gauge that does no capacity learning reports the
     * design figure for both - the tissot does - and dividing one by the
     * other there produces a confident 100% that is arithmetic, not a
     * measurement. That is worth saying rather than showing.
     */
    function wearIsKnown(full, design) {
        return full > 0 && design > 0 && full !== design;
    }

    function gaugeLearns(full, design) {
        return !(full > 0 && design > 0 && full === design);
    }

    function wearPercentOf(full, design) {
        return pageRoot.wearIsKnown(full, design)
               ? Math.round(100 * full / design) : -1;
    }

    readonly property bool wearKnown: pageRoot.wearIsKnown(pageRoot.capacityFull,
                                                           pageRoot.capacityDesign)

    readonly property bool gaugeDoesNotLearn: !pageRoot.gaugeLearns(pageRoot.capacityFull,
                                                                    pageRoot.capacityDesign)

    readonly property int wearPercent: pageRoot.wearPercentOf(pageRoot.capacityFull,
                                                              pageRoot.capacityDesign)

    /*
     * The readings, formatted. Taken as arguments rather than read off this
     * page, because the same rows are shown for the primary battery from the
     * top level of the reply and for each pack from the "batteries" array,
     * and two copies of "is a negative current discharging?" is how the two
     * end up disagreeing.
     */
    function temperatureText(celsius) {
        return celsius + " \u00b0C";
    }

    function voltageText(millivolts) {
        // Reported in millivolts; volts is what a datasheet and every other
        // settings app show.
        return (millivolts / 1000).toFixed(2) + " V";
    }

    function currentText(milliamps) {
        // Signed: negative is the pack being drained, positive is it being
        // filled. Spell that out rather than leaving a bare minus sign to be
        // read as an error.
        return milliamps + " mA" +
               (milliamps < 0 ? " (discharging)"
                              : (milliamps > 0 ? " (charging)" : ""));
    }

    function chargeText(mAh) {
        return Math.round(mAh) + " mAh";
    }

    function capacityText(full, design) {
        return Math.round(full) + " of " + Math.round(design) + " mAh";
    }

    function healthIsKnown(health) {
        return health !== undefined && health !== "" && health !== "unknown";
    }

    /*
     * The kernel's POWER_SUPPLY_HEALTH_* set, as batteryd spells it. Said in
     * words rather than repeated as a code, because this is the one line on
     * the page a person reads when they think something is wrong.
     */
    function conditionTextOf(health) {
        switch (health) {
        case "good":        return "Good";
        case "overheat":    return "Too hot";
        case "hot":         return "Hot";
        case "warm":        return "Warm";
        case "cool":        return "Cool";
        case "cold":        return "Too cold";
        case "dead":        return "Failed";
        case "overvoltage": return "Over voltage";
        case "overcurrent": return "Over current";
        case "failure":     return "Failed, cause unknown";
        case "watchdog":    return "Charging watchdog expired";
        case "safetytimer": return "Charging safety timer expired";
        case "calibrate":   return "Needs calibrating";
        case "nobattery":   return "No battery";
        default:            return "Unknown";
        }
    }

    // Empty on a single-battery device; one entry per pack otherwise.
    property var batteries: []

    // Which pack's readings are open, by sysfs node name. Only one at a time.
    property string expandedBattery: ""

    // Charger
    property bool charging: false
    property bool usbConnected: false
    property string usbName: "none"
    property bool dockConnected: false
    property bool dockPower: false
    property string dockSerial: ""

    readonly property bool onPower: usbConnected || dockPower

    Component.onCompleted: retrieveProperties();

    /*
     * The gauge is the project's own status bar battery artwork (the @4x set
     * from the wiki's Graphics Work page, the same twenty-six frames
     * luna-next-cardshell draws in the status bar - byte for byte the same
     * files). Reusing it rather than drawing a bar here means the charge on
     * this page and the charge in the status bar are never two different
     * pictures of the same number.
     *
     * The frame is picked exactly the way cardshell's BatteryIndicator picks
     * it: a 0-12 level floored out of the percentage, clamped to the eleventh
     * frame, "charged" once it is over that while on power, and "error" when
     * nothing has been read yet.
     */
    function gaugeFrame() {
        /*
         * Guarded on percentUi, not percent: the two are set one after the
         * other as a reply is unpacked, so a binding that keyed off percent
         * would be re-run once with percentUi still at its -1 default and ask
         * for a "battery--1.png" that does not exist.
         */
        if (pageRoot.percentUi < 0)
            return "../images/battery/battery-error.png";

        var level = Math.floor((pageRoot.percentUi * 12) / 100);

        if (level > 11)
            return pageRoot.charging ? "../images/battery/battery-charged.png"
                                     : "../images/battery/battery-11.png";

        return "../images/battery/battery-" +
               (pageRoot.charging ? "charging-" : "") + level + ".png";
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.batteryServiceAvailable
            serviceName: "com.webos.service.battery"
            description: "The battery daemon did not answer, so there is " +
                         "nothing to report about the charge."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.batteryServiceAvailable

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Row {
                    spacing: Units.gu(2)

                    Image {
                        // The artwork is 68x80; keep that so it is not
                        // stretched out of shape.
                        height: Units.gu(10)
                        width: height * 68 / 80
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        source: pageRoot.gaugeFrame()
                    }

                    Label {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pageRoot.percent >= 0 ? (pageRoot.percentUi + "%") : "--"
                        font.pixelSize: FontUtils.sizeToPixels("32pt")
                    }
                }

                LabelAndValue {
                    width: parent.width
                    label: "Status"
                    value: pageRoot.chargeStateText()
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndValue {
                    width: parent.width
                    label: "Power source"
                    value: pageRoot.powerSourceText()
                }

                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.dockConnected && pageRoot.dockSerial !== ""
                    height: visible ? Units.gu(6) : 0
                    label: "Dock"
                    value: pageRoot.dockSerial
                }
            }
        }

        /*
         * Only on a device that reported more than one pack. The primary one
         * is repeated here so the group reads as a complete list rather than
         * as "the other batteries".
         *
         * Every pack carries the same readings the primary one does, health
         * included, so tapping one opens them rather than leaving a second
         * battery as a bare percentage with everything below this group
         * describing only the first. Only one is open at a time: this is a
         * list to look down, not a set of panels to leave open.
         */
        GroupBox {
            width: parent.width
            visible: pageRoot.batteryServiceAvailable && pageRoot.batteries.length > 1

            title: "Batteries"

            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.batteries

                    Column {
                        width: parent.width

                        HorizontalSeparator {
                            width: parent.width
                            visible: index > 0
                            height: visible ? 1 : 0
                        }

                        Item {
                            width: parent.width
                            height: Units.gu(6)

                            LabelAndValue {
                                anchors.fill: parent
                                label: pageRoot.batteryLabel(modelData)
                                value: modelData.present === false
                                       ? "Not present"
                                       : (modelData.percent_ui + "%" +
                                          (modelData.charging ? ", charging" : ""))
                            }

                            MouseArea {
                                anchors.fill: parent
                                // A pack that is not there has nothing to open.
                                enabled: modelData.present !== false
                                onClicked: pageRoot.expandedBattery =
                                    (pageRoot.expandedBattery === modelData.name
                                     ? "" : modelData.name)
                            }
                        }

                        Column {
                            width: parent.width - Units.gu(2)
                            x: Units.gu(1)
                            visible: pageRoot.expandedBattery === modelData.name &&
                                     modelData.present !== false

                            LabelAndValue {
                                width: parent.width
                                visible: modelData.temperature_C !== undefined
                                height: visible ? Units.gu(6) : 0
                                label: "Temperature"
                                value: modelData.temperature_C !== undefined
                                       ? pageRoot.temperatureText(modelData.temperature_C) : ""
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: modelData.voltage_mV !== undefined
                                height: visible ? Units.gu(6) : 0
                                label: "Voltage"
                                value: modelData.voltage_mV !== undefined
                                       ? pageRoot.voltageText(modelData.voltage_mV) : ""
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: modelData.current_mA !== undefined
                                height: visible ? Units.gu(6) : 0
                                label: "Current"
                                value: modelData.current_mA !== undefined
                                       ? pageRoot.currentText(modelData.current_mA) : ""
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: modelData.capacity_mAh !== undefined &&
                                         modelData.capacity_mAh >= 0
                                height: visible ? Units.gu(6) : 0
                                label: "Charge"
                                value: modelData.capacity_mAh !== undefined
                                       ? pageRoot.chargeText(modelData.capacity_mAh) : ""
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: pageRoot.healthIsKnown(modelData.health)
                                height: visible ? Units.gu(6) : 0
                                label: "Condition"
                                value: pageRoot.conditionTextOf(modelData.health)
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: pageRoot.wearIsKnown(modelData.capacity_full_mAh,
                                                              modelData.capacity_design_mAh)
                                height: visible ? Units.gu(6) : 0
                                label: "Capacity"
                                value: pageRoot.capacityText(modelData.capacity_full_mAh,
                                                             modelData.capacity_design_mAh)
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: pageRoot.wearIsKnown(modelData.capacity_full_mAh,
                                                              modelData.capacity_design_mAh)
                                height: visible ? Units.gu(6) : 0
                                label: "Of its original"
                                value: pageRoot.wearPercentOf(modelData.capacity_full_mAh,
                                                              modelData.capacity_design_mAh) + "%"
                            }

                            // Same reasoning as the primary battery's Health
                            // group: a gauge repeating its design figure is
                            // not a pack in perfect condition.
                            Label {
                                width: parent.width
                                visible: !pageRoot.gaugeLearns(modelData.capacity_full_mAh,
                                                               modelData.capacity_design_mAh)
                                topPadding: Units.gu(0.5)
                                bottomPadding: Units.gu(0.5)
                                wrapMode: Text.WordWrap
                                text: "This pack reports the same capacity it " +
                                      "shipped with, so how worn it is cannot " +
                                      "be told from here."
                                color: "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }
                    }
                }
            }
        }

        ExplanationText {
            visible: pageRoot.batteryServiceAvailable && pageRoot.batteries.length > 1
            text: "Tap a battery for its readings. Everything below describes " +
                  "the primary one."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.batteryServiceAvailable

            title: "Details"

            Column {
                width: parent.width

                LabelAndValue {
                    width: parent.width
                    label: "Temperature"
                    value: pageRoot.temperatureText(pageRoot.temperature)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndValue {
                    width: parent.width
                    label: "Voltage"
                    value: pageRoot.voltageText(pageRoot.voltage)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndValue {
                    width: parent.width
                    label: "Current"
                    value: pageRoot.currentText(pageRoot.current)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndValue {
                    width: parent.width
                    // Only where the pack reports it. A device whose driver
                    // has neither charge_now nor charge_counter answers -1,
                    // and an empty row says more than a wrong one.
                    visible: pageRoot.capacity >= 0
                    height: visible ? Units.gu(6) : 0
                    label: "Charge"
                    value: pageRoot.chargeText(pageRoot.capacity)
                }
            }
        }

        ExplanationText {
            visible: pageRoot.capacity >= 0
            text: "Charge is how much is in the pack at this moment - the " +
                  "figure the percentage above is a proportion of."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.batteryServiceAvailable &&
                     (pageRoot.healthKnown || pageRoot.wearKnown ||
                      pageRoot.gaugeDoesNotLearn)

            title: "Health"

            Column {
                width: parent.width

                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.healthKnown
                    height: visible ? Units.gu(6) : 0
                    label: "Condition"
                    value: pageRoot.conditionTextOf(pageRoot.health)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.healthKnown && pageRoot.wearKnown
                    height: visible ? 1 : 0
                }

                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.wearKnown
                    height: visible ? Units.gu(6) : 0
                    label: "Capacity"
                    value: pageRoot.capacityText(pageRoot.capacityFull,
                                                 pageRoot.capacityDesign)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.wearKnown
                    height: visible ? 1 : 0
                }

                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.wearKnown
                    height: visible ? Units.gu(6) : 0
                    label: "Of its original"
                    value: pageRoot.wearPercent + "%"
                }
            }
        }

        ExplanationText {
            visible: pageRoot.wearKnown
            text: "A pack holds less as it ages. Well under what it shipped " +
                  "with means shorter days between charges, and is the point " +
                  "at which replacing it is worth more than any setting on " +
                  "this page."
        }

        ExplanationText {
            visible: !pageRoot.wearKnown && pageRoot.gaugeDoesNotLearn
            text: "This device reports the same capacity it shipped with, " +
                  "which is what a gauge that does not measure wear does " +
                  "rather than a sign of a pack in perfect condition. How " +
                  "worn the battery is cannot be told from here."
        }

        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                Button {
                    text: "Display settings"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openDisplaySettings()
                }
            }
        }

        ExplanationText {
            text: "How long the screen stays on, and how bright it is, are " +
                  "the two settings that move battery life the most."
        }
    }

    /*
     * Wording
     */
    function chargeStateText() {
        if (pageRoot.percent < 0)
            return "Unknown";
        if (pageRoot.charging)
            return "Charging";
        if (pageRoot.onPower)
            return pageRoot.percentUi >= 100 ? "Fully charged" : "Plugged in, not charging";
        return "On battery";
    }

    function powerSourceText() {
        if (pageRoot.dockPower)
            return "Inductive charger";
        if (pageRoot.usbConnected) {
            // The names nyx uses for what is on the other end of the cable.
            if (pageRoot.usbName === "pc")
                return "USB (computer)";
            if (pageRoot.usbName === "wall")
                return "USB (wall charger)";
            if (pageRoot.usbName === "direct")
                return "USB (direct)";
            return "USB";
        }
        return "None";
    }

    function batteryLabel(battery) {
        if (!battery)
            return "";

        // "role" is what the pack is for ("main", "keyboard", ...) and is the
        // more useful of the two when both are set; "name" is the raw sysfs
        // node and is the fallback.
        var label = battery.role && battery.role !== "" ? battery.role : battery.name;
        if (!label || label === "")
            label = "Battery";

        label = label.charAt(0).toUpperCase() + label.substring(1);
        return battery.primary ? (label + " (primary)") : label;
    }

    /*
     * Bindings with LuneOS
     */
    function retrieveProperties() {
        readBatteryStatus();
        readChargerStatus();

        /*
         * batteryd has no subscribable query, but it does publish a signal
         * every time a reading moves. These are the same two matches
         * luna-next-cardshell's BatteryService makes for the status bar
         * indicator - batteryStatus for the charge, USBDockStatus for the
         * charger - so the page follows exactly what the shell follows.
         *
         * "com.palm.bus" rather than "com.webos.service.bus" for the same
         * reason: it is the spelling that is known to work for these two on
         * a device. The ACG covers either.
         */
        luna.subscribe("luna://com.palm.bus/signal/addmatch",
                       JSON.stringify({"category": "/com/palm/power",
                                       "method": "batteryStatus"}),
                       _handleBatterySignal, _handleSignalError);

        luna.subscribe("luna://com.palm.bus/signal/addmatch",
                       JSON.stringify({"category": "/com/palm/power",
                                       "method": "USBDockStatus"}),
                       _handleChargerSignal, _handleSignalError);
    }

    function readBatteryStatus() {
        luna.call("luna://com.webos.service.battery/batteryStatusQuery", "{}",
                  _handleBatteryStatus, _handleBatteryUnavailable);
    }

    function readChargerStatus() {
        luna.call("luna://com.webos.service.battery/chargerStatusQuery", "{}",
                  _handleChargerStatus, _handleBatteryUnavailable);
    }

    function _handleBatteryStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("percent"))
            pageRoot.percent = response.percent;
        // percent_ui is the same charge rounded the way the status bar shows
        // it, so the two never disagree by a point.
        pageRoot.percentUi = response.hasOwnProperty("percent_ui")
                             ? response.percent_ui : pageRoot.percent;
        if (response.hasOwnProperty("temperature_C"))
            pageRoot.temperature = response.temperature_C;
        if (response.hasOwnProperty("current_mA"))
            pageRoot.current = response.current_mA;
        if (response.hasOwnProperty("voltage_mV"))
            pageRoot.voltage = response.voltage_mV;
        if (response.hasOwnProperty("capacity_mAh"))
            pageRoot.capacity = response.capacity_mAh;
        if (response.hasOwnProperty("capacity_full_mAh"))
            pageRoot.capacityFull = response.capacity_full_mAh;
        if (response.hasOwnProperty("capacity_design_mAh"))
            pageRoot.capacityDesign = response.capacity_design_mAh;
        if (response.hasOwnProperty("health"))
            pageRoot.health = response.health;

        pageRoot.batteries = response.hasOwnProperty("batteries") && response.batteries
                             ? response.batteries : [];

        pageRoot.batteryServiceAvailable = true;
    }

    function _handleChargerStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("Charging"))
            pageRoot.charging = response.Charging === true;
        if (response.hasOwnProperty("USBConnected"))
            pageRoot.usbConnected = response.USBConnected === true;
        if (response.hasOwnProperty("USBName"))
            pageRoot.usbName = response.USBName;
        if (response.hasOwnProperty("DockConnected"))
            pageRoot.dockConnected = response.DockConnected === true;
        if (response.hasOwnProperty("DockPower"))
            pageRoot.dockPower = response.DockPower === true;
        // batteryd writes the string "NULL" rather than leaving it out when
        // there is no dock to name.
        pageRoot.dockSerial = response.DockSerialNo && response.DockSerialNo !== "NULL"
                              ? response.DockSerialNo : "";

        pageRoot.batteryServiceAvailable = true;
    }

    function _handleBatterySignal(message) {
        // The signal carries the reading itself, but only ever the primary
        // battery's; re-reading picks up the per-pack array with it.
        readBatteryStatus();
    }

    function _handleChargerSignal(message) {
        readChargerStatus();
    }

    function _handleSignalError(message) {
        // Losing the signal match costs the page its live updates but not its
        // contents, so say so and leave what was read standing.
        console.warn("Cannot follow battery changes: " + message);
    }

    function _handleBatteryUnavailable(message) {
        console.warn("Battery service did not answer: " + message);
        pageRoot.batteryServiceAvailable = false;
    }

    // Each settings category is its own launchable application on the device.
    function openDisplaySettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.display"}),
                  _handleSetSuccess, _handleSetError);
    }
}
