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
import QtQuick 2.12
import QtQuick.Controls 2.12

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

    //property var modems :[]

    /*
     * These alias properties summarize what settings are relative to this page
     */
    //property alias roamingAllowed: roamingAllowedSwitch.checked
    //property alias dataUsage: dataUsageSwitch.checked

    /*OfonoManager {
        id: ofonoManager
    }*/
    //Component.onCompleted: {
      //  retrieveProperties();
    //}

    /* A settings page has a vertical layout: put everything in a Column */
    Column {
        width: parent.width

        Row {
            id: tabBar

            anchors.horizontalCenter: parent.horizontalCenter
            height: Units.gu(5)

            Repeater {
                model: simListModel

                RadioButton {
                    LuneOSRadioButton.useCollapsedLayout: true

                    height: tabBar.height
                    width: pageRoot.width/(simListModel.count+1)
                    text: "SIM " + (index+1)
                    checked: swipeView.currentIndex === index
                    onClicked: swipeView.currentIndex = index;
                }
            }
        }

        SwipeView {
            id: swipeView
            width: parent.width
            height: pageRoot.height - tabBar.height

            Repeater {
                model: simListModel

                Flickable {
                    id: flickableItem
                    anchors.margins: Units.gu(1)
                    contentWidth: width
                    contentHeight: Units.gu(60) //groupBox.height
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    clip: true

                    /* GroupBoxes look good! */
                    GroupBox {
                        id: groupBox
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
                            HorizontalSeparator {
                                width: parent.width
                            }
                            LabelAndValue {
                                width: parent.width
                                label: "Operator"
                                value: serviceProviderName
                            }
                            HorizontalSeparator {
                                width: parent.width
                            }
                            LabelAndValue {
                                width: parent.width
                                label: "MCC"
                                //label: "Technology"
                                //value: network.technology
                                value: mobileCountryCode
                            }
                            HorizontalSeparator {
                                width: parent.width
                            }
                            LabelAndValue {
                                width: parent.width
                                //label: "Strength"
                                //value: network.strength
                                label: "MNC"
                                value: mobileNetworkCode
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
        }


        /*
     * Bindings with LuneOS settings
     */
        // Initialization and eventual subscription
        function retrieveProperties() {
            luna.call("luna://com.palm.wan/getstatus", '{"subscribe": "true"}',
                      _handleWanStatus, _handleGetError)
        }
        function _handleWanStatus(message) {
            if (message && message.payload) {
                payloadValue = JSON.parse(message.payload)
                if (typeof payloadValue.roamguard !== 'undefined') {
                    roamingAllowed = (payloadValue.roamguard === "disable")
                }
                if (typeof payloadValue.disablewan !== 'undefined') {
                    dataUsage = (payloadValue.disablewan === "off")
                }
            }
        }

        /*OfonoManager {
            id: modemManager2
            onAvailableChanged: {
               console.log("Herrie Ofono is " + available)
                console.log("Herrie changed modemManager.valid: "+ modemManager.valid);
                console.log("Herrie changed modemManager.ready: "+ modemManager.ready);
                console.log("Herrie changed modemManager.availableModems: "+ modemManager.availableModems);
                console.log("Herrie changed modemManager.enabledModems: "+modemManager.enabledModems);
                console.log("Herrie changed modemManager.defaultVoiceSim: "+modemManager.defaultVoiceSim);
                console.log("Herrie changed modemManager.defaultDataSim: "+modemManager.defaultDataSim);
                console.log("Herrie changed modemManager.defaultVoiceModem: "+modemManager.defaultVoiceModem);
                console.log("Herrie changed modemManager.defaultDataModem: "+modemManager.defaultDataModem);
                console.log("Herrie changed modemManager.presentSimCount: "+modemManager.presentSimCount);
                console.log("Herrie changed modemManager.activeSimCount: "+modemManager.activeSimCount);
               //textLine2.text = modemManager.available ? netreg.currentOperator["Name"].toString() :"Ofono not available"
            }
            onModemAdded: {
                console.log("modem added "+modem)
                console.log("Herrie added modemManager.valid: "+ modemManager.valid);
                console.log("Herrie added modemManager.ready: "+ modemManager.ready);
                console.log("Herrie added modemManager.availableModems: "+ modemManager.availableModems);
                console.log("Herrie added modemManager.enabledModems: "+modemManager.enabledModems);
                console.log("Herrie added modemManager.defaultVoiceSim: "+modemManager.defaultVoiceSim);
                console.log("Herrie added modemManager.defaultDataSim: "+modemManager.defaultDataSim);
                console.log("Herrie added modemManager.defaultVoiceModem: "+modemManager.defaultVoiceModem);
                console.log("Herrie added modemManager.defaultDataModem: "+modemManager.defaultDataModem);
                console.log("Herrie added modemManager.presentSimCount: "+modemManager.presentSimCount);
                console.log("Herrie added modemManager.activeSimCount: "+modemManager.activeSimCount);

            }
            onModemRemoved: {
                console.log("modem removed "+modem)
                console.log("Herrie removed modemManager.valid: "+ modemManager.valid);
                console.log("Herrie removed modemManager.ready: "+ modemManager.ready);
                console.log("Herrie removed modemManager.availableModems: "+ modemManager.availableModems);
                console.log("Herrie removed modemManager.enabledModems: "+modemManager.enabledModems);
                console.log("Herrie removed modemManager.defaultVoiceSim: "+modemManager.defaultVoiceSim);
                console.log("Herrie removed modemManager.defaultDataSim: "+modemManager.defaultDataSim);
                console.log("Herrie removed modemManager.defaultVoiceModem: "+modemManager.defaultVoiceModem);
                console.log("Herrie removed modemManager.defaultDataModem: "+modemManager.defaultDataModem);
                console.log("Herrie removed modemManager.presentSimCount: "+modemManager.presentSimCount);
                console.log("Herrie removed modemManager.activeSimCount: "+modemManager.activeSimCount);

            }
            Component.onCompleted: {
            console.log("Herrie modemManager.valid: "+ modemManager.valid);
            console.log("Herrie modemManager.ready: "+ modemManager.ready);
            console.log("Herrie modemManager.availableModems: "+ modemManager.availableModems);
            console.log("Herrie modemManager.enabledModems: "+modemManager.enabledModems);
            console.log("Herrie modemManager.defaultVoiceSim: "+modemManager.defaultVoiceSim);
            console.log("Herrie modemManager.defaultDataSim: "+modemManager.defaultDataSim);
            console.log("Herrie modemManager.defaultVoiceModem: "+modemManager.defaultVoiceModem);
            console.log("Herrie modemManager.defaultDataModem: "+modemManager.defaultDataModem);
            console.log("Herrie modemManager.presentSimCount: "+modemManager.presentSimCount);
            console.log("Herrie modemManager.activeSimCount: "+modemManager.activeSimCount);
            }
        }*/

        OfonoManager {
            id: ofonoManager
            onModemsChanged: {
                root.modems = modems.slice(0).sort()
                console.log("ofonoManager",modems.slice(0).sort() )
                console.log("path1: " + root.modems[0] )
                console.log("path2: " + root.modems[1] )
            }
        }

        OfonoSimManager {
            id: simMng
            modemPath: path
        }
    }
}
