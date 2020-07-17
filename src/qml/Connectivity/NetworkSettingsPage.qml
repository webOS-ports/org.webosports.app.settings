/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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

import MeeGo.QOfono 0.2

/*
 * This is an example of what the code for some settings can look like
 * It is supposed to be a set of good practices, don't hesitate to
 * copy/paste code from here and adapt to your needs.
 *
 * Note: All the settings here are fake. Of Course.
 */

BasePage {
    id: pageRoot

    /*
     * These alias properties summarize what settings are relative to this page
     */
    property alias roamingAllowed: roamingAllowedSwitch.checked
    property alias dataUsage: dataUsageSwitch.checked

    Component.onCompleted: {
        retrieveProperties();
    }

    /* A settings page has a vertical layout: put everything in a Column */
    Flickable {
        id: flickableItem
        anchors.fill: parent
        anchors.margins: Units.gu(1)
        contentWidth: width
        contentHeight: contentItem.childrenRect.height
        flickableDirection: Flickable.AutoFlickIfNeeded
        clip: true
        Column {
            spacing: Units.gu(2)
            width: parent.width

            /* GroupBoxes look good! */
            GroupBox {
                width: parent.width

                title: "Network"
                Column {
                    width: parent.width

                    Switch {
                        id: roamingAllowedSwitch
                        width: parent.width
                        text: "Roaming allowed"
                        font.weight: Font.Normal
                        LayoutMirroring.enabled: true // by default the switch is on the left in Qt, not very webOS-ish

                        LuneOSSwitch.labelOn: "Yes"
                        LuneOSSwitch.labelOff: "No"
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    Switch {
                        id: dataUsageSwitch
                        width: parent.width
                        text: "Data usage"
                        font.weight: Font.Normal
                        LayoutMirroring.enabled: true

                        LuneOSSwitch.labelOn: "On"
                        LuneOSSwitch.labelOff: "Off"
                    }
                }
            }

            GroupBox {
                width: parent.width

                title: modemManager.modems[1] ? "Information SIM 1" : "Information"
                Column {
                    width: parent.width

                    LabelAndValue {
                        width: parent.width
                        label: "Operator"
                        value: network.name
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        width: parent.width
                        label: "Technology"
                        value: network.technology
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        width: parent.width
                        label: "Strength"
                        value: network.strength
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        width: parent.width
                        label: "Status"
                        value: network.status
                    }
                }
            }
            GroupBox {
                width: parent.width

                title: "Information SIM 2"
                visible: modemManager.modems[1] ? true : false
                Column {
                    width: parent.width
                    LabelAndValue {
                        width: parent.width
                        label: "Operator"
                        value: network.name
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        width: parent.width
                        label: "Technology"
                        value: network.technology
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        width: parent.width
                        label: "Strength"
                        value: network.strength
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndValue {
                        width: parent.width
                        label: "Status"
                        value: network.status
                    }
                }
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    // Initialization and eventual subscription
    function retrieveProperties() {
        luna.call("luna://com.palm.wan/getstatus", '{"subscribe": "true"}', _handleWanStatus, _handleGetError);
    }
    function _handleWanStatus(message) {
        if(message && message.payload) {
            payloadValue = JSON.parse(message.payload);
            if(typeof payloadValue.roamguard !== 'undefined') {
                roamingAllowed = (payloadValue.roamguard === "disable");
            }
            if(typeof payloadValue.disablewan !== 'undefined') {
                dataUsage = (payloadValue.disablewan === "off");
            }
        }
    }
    OfonoManager {
        id: modemManager
    }
    OfonoSimManager {
        id: simManager
        modemPath: modemManager.defaultModem
    }
    OfonoModem {
        id: modem
        modemPath: modemManager.defaultModem
    }
    OfonoNetworkRegistration {
        id: network
        modemPath: modemManager.defaultModem
    }
    OfonoNetworkOperator {
        id: networkOperator
    }

    // Push changes to LuneOS
    onRoamingAllowedChanged: {
        var roamguard = roamingAllowed ? "disable" : "enable"
        luna.call("palm://com.palm.wan/set", '{"roamguard": "'+roamguard+'"}', _handleSetSuccess, _handleSetError);
    }
    onDataUsageChanged: {
        var disablewan = dataUsage ? "off" : "on"
        luna.call("palm://com.palm.wan/set", '{"disablewan": "'+disablewan+'"}', _handleSetSuccess, _handleSetError);
    }
}
