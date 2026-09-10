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

// The installed package registers this under the plain "QOfono" URI, the
// same way NetworkSettingsPage imports it.
import QOfono 0.2

/*
 * Emergency Broadcast.
 *
 * Cell broadcast is how a network pushes an emergency warning to every phone
 * in a cell without sending anyone a message - CMAS in the US, EU-Alert in
 * Europe, ETWS in Japan. LuneOS receives none of it today because nothing
 * ever turned it on: ofono's CellBroadcast interface is there and QOfono
 * binds it, but no page anywhere set Powered on it.
 *
 * UBports has this page, and phosh has an Alerts panel; the categories below
 * are the standard 3GPP channel assignments both of them use, so a device
 * subscribes to the same things a phone next to it does:
 *
 *    4370        Presidential level - cannot be turned off anywhere
 *    4371-4374   Extreme threats
 *    4375-4378   Severe threats
 *    4379        AMBER (child abduction) alerts
 *    4396        Public safety messages
 *    4380-4381   Operator tests
 *
 * ETWS and the presidential channel are mandatory: ofono subscribes to them
 * itself and there is no opting out, which is the point of them. The rest are
 * this page's business, and are written as ofono's "Topics" string - a
 * comma-separated list where an entry may be a single channel or a "from-to"
 * range. Reading it back has to cope with both spellings, because ofono, the
 * modem and whatever set it last do not have to agree on which to use.
 *
 * On a dual-SIM device this is per modem, the same way the SIM PIN section of
 * Network Settings is: one OfonoCellBroadcast speaks for one modem, so the
 * SIM is a choice rather than always the default modem.
 */
BasePage {
    id: pageRoot

    // Which entry of modemManager.modems the settings below apply to.
    property int modemIndex: 0

    readonly property string currentModemPath:
        modemManager.modems.length > pageRoot.modemIndex
        ? modemManager.modems[pageRoot.modemIndex] : ""

    // The last thing that arrived while this page was open. Not a history:
    // ofono keeps none, and neither does anything else on the device yet.
    property string lastBroadcast: ""
    property bool lastWasEmergency: false

    readonly property var extremeTopics: [4371, 4372, 4373, 4374]
    readonly property var severeTopics: [4375, 4376, 4377, 4378]
    readonly property var amberTopics: [4379]
    readonly property var publicSafetyTopics: [4396]
    readonly property var testTopics: [4380, 4381]

    OfonoManager {
        id: modemManager
    }

    OfonoCellBroadcast {
        id: cellBroadcast
        modemPath: pageRoot.currentModemPath

        onIncomingBroadcast: (text, topic) => {
            pageRoot.lastBroadcast = text;
            pageRoot.lastWasEmergency = false;
        }

        onEmergencyBroadcast: (text, properties) => {
            pageRoot.lastBroadcast = text;
            pageRoot.lastWasEmergency = true;
        }
    }

    function simNames() {
        var names = [];
        for (var i = 0; i < modemManager.modems.length; i++)
            names.push("SIM " + (i + 1));
        return names;
    }

    /*
     * ofono's Topics is a comma-separated list whose entries are either a
     * single channel or a "from-to" range, so a channel is subscribed if it
     * is named by any entry either way.
     */
    function _topicSubscribed(topic) {
        if (!cellBroadcast.topics || cellBroadcast.topics === "")
            return false;

        var entries = cellBroadcast.topics.split(",");
        for (var i = 0; i < entries.length; i++) {
            var bounds = entries[i].split("-");
            if (bounds.length === 1) {
                if (parseInt(bounds[0], 10) === topic)
                    return true;
            } else if (topic >= parseInt(bounds[0], 10) &&
                       topic <= parseInt(bounds[1], 10)) {
                return true;
            }
        }
        return false;
    }

    function categoryEnabled(topics) {
        // A category is on when every channel in it is subscribed - a
        // half-subscribed category is one something else wrote, and showing
        // it as on would lose the rest of it on the next write.
        for (var i = 0; i < topics.length; i++) {
            if (!_topicSubscribed(topics[i]))
                return false;
        }
        return true;
    }

    function setCategoryEnabled(topics, on) {
        var wanted = [];

        function add(list) {
            for (var i = 0; i < list.length; i++)
                wanted.push(list[i]);
        }

        // Rebuild the whole string from what every switch says, rather than
        // editing the old one: ofono replaces Topics outright, so a partial
        // edit would drop the categories it did not mention.
        var groups = [pageRoot.extremeTopics, pageRoot.severeTopics,
                      pageRoot.amberTopics, pageRoot.publicSafetyTopics,
                      pageRoot.testTopics];
        for (var g = 0; g < groups.length; g++) {
            var isThisOne = groups[g] === topics;
            if (isThisOne ? on : pageRoot.categoryEnabled(groups[g]))
                add(groups[g]);
        }

        cellBroadcast.topics = wanted.join(",");
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: modemManager.modems.length === 0
            serviceName: "org.ofono"
            description: "No modem was found, so there is no network to " +
                         "receive emergency broadcasts from."
            onRetry: {}
        }

        GroupBox {
            width: parent.width
            visible: modemManager.modems.length > 0

            Column {
                width: parent.width

                LabelAndSelector {
                    width: parent.width
                    visible: modemManager.modems.length > 1
                    height: visible ? Units.gu(6) : 0
                    label: "SIM"
                    model: pageRoot.simNames()
                    currentIndex: pageRoot.modemIndex
                    onActivated: (index) => pageRoot.modemIndex = index
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: modemManager.modems.length > 1
                    height: visible ? 1 : 0
                }

                LabelAndSwitch {
                    id: enabledSwitch
                    label: "Receive Alerts"

                    checked: cellBroadcast.enabled
                    Connections {
                        target: cellBroadcast
                        function onEnabledChanged() {
                            enabledSwitch.checked = cellBroadcast.enabled;
                        }
                    }
                    onToggled: cellBroadcast.enabled = checked
                }
            }
        }

        ExplanationText {
            visible: modemManager.modems.length > 0
            text: "Emergency broadcasts are sent by the network to every " +
                  "phone in the area. They are not messages and do not cost " +
                  "anything."
        }

        GroupBox {
            width: parent.width
            visible: modemManager.modems.length > 0
            enabled: cellBroadcast.enabled

            title: "Alerts"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: extremeSwitch
                    label: "Extreme Threats"

                    checked: pageRoot.categoryEnabled(pageRoot.extremeTopics)
                    Connections {
                        target: cellBroadcast
                        function onTopicsChanged() {
                            extremeSwitch.checked =
                                pageRoot.categoryEnabled(pageRoot.extremeTopics);
                        }
                    }
                    onToggled: pageRoot.setCategoryEnabled(pageRoot.extremeTopics, checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: severeSwitch
                    label: "Severe Threats"

                    checked: pageRoot.categoryEnabled(pageRoot.severeTopics)
                    Connections {
                        target: cellBroadcast
                        function onTopicsChanged() {
                            severeSwitch.checked =
                                pageRoot.categoryEnabled(pageRoot.severeTopics);
                        }
                    }
                    onToggled: pageRoot.setCategoryEnabled(pageRoot.severeTopics, checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: amberSwitch
                    label: "AMBER Alerts"

                    checked: pageRoot.categoryEnabled(pageRoot.amberTopics)
                    Connections {
                        target: cellBroadcast
                        function onTopicsChanged() {
                            amberSwitch.checked =
                                pageRoot.categoryEnabled(pageRoot.amberTopics);
                        }
                    }
                    onToggled: pageRoot.setCategoryEnabled(pageRoot.amberTopics, checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: publicSafetySwitch
                    label: "Public Safety"

                    checked: pageRoot.categoryEnabled(pageRoot.publicSafetyTopics)
                    Connections {
                        target: cellBroadcast
                        function onTopicsChanged() {
                            publicSafetySwitch.checked =
                                pageRoot.categoryEnabled(pageRoot.publicSafetyTopics);
                        }
                    }
                    onToggled: pageRoot.setCategoryEnabled(pageRoot.publicSafetyTopics, checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: testSwitch
                    label: "Operator Tests"

                    checked: pageRoot.categoryEnabled(pageRoot.testTopics)
                    Connections {
                        target: cellBroadcast
                        function onTopicsChanged() {
                            testSwitch.checked =
                                pageRoot.categoryEnabled(pageRoot.testTopics);
                        }
                    }
                    onToggled: pageRoot.setCategoryEnabled(pageRoot.testTopics, checked)
                }
            }
        }

        ExplanationText {
            visible: modemManager.modems.length > 0
            text: "Presidential-level alerts and earthquake and tsunami " +
                  "warnings arrive whatever is set here. They cannot be " +
                  "turned off on any phone."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.lastBroadcast !== ""

            title: "Last Received"

            Column {
                width: parent.width

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: pageRoot.lastBroadcast
                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                    font.weight: pageRoot.lastWasEmergency ? Font.Bold : Font.Normal
                }
            }
        }
    }
}
