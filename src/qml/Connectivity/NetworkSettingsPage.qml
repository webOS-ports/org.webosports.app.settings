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


    /*
     * These alias properties summarize what settings are relative to this page
     */
    //property alias roamingAllowed: roamingAllowedSwitch.checked
    //property alias dataUsage: dataUsageSwitch.checked
    Component.onCompleted: {
      //  retrieveProperties();
    }

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
        OfonoManager {
            id: modemManager
            onAvailableChanged: {
               console.log("Ofono is " + available)
               //textLine2.text = modemManager.available ? netreg.currentOperator["Name"].toString() :"Ofono not available"
            }
            onModemAdded: {
                console.log("modem added "+modem)
            }
            onModemRemoved: {
                console.log("modem removed "+modem)
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
        }

        OfonoConnMan {
           id: ofono1
           Component.onCompleted: {
               console.log("Herrie modemManager.modems: "+modemManager.modems)
           }
           modemPath: modemManager.modems[0]
        }


        OfonoSimManager {
            id: simManager
            //modemPath: modemManager.defaultModem
            modemPath: modemManager.modems[0]

        }
        OfonoModem {
            id: modem1
            //modemPath: modemManager.defaultModem
            modemPath: modemManager.modems[0]
        }

        OfonoContextConnection {
                id: context1
                contextPath : ofono1.contexts[0]
                Component.onCompleted: {
                    console.log("Herrie: " + context1.active ? "online" : "offline")
              }
                onActiveChanged: {
                    console.log("Herrie: " + context1.active ? "online" : "offline")
                }
            }

        OfonoNetworkRegistration {
            id: network
            //modemPath: modemManager.defaultModem
            modemPath: modemManager.modems[0]
            Component.onCompleted: {
                network.scan()
            }
            onNetworkOperatorsChanged : {
                //console.log("operators :"+network.currentOperator["name"].toString())
            }
        }
        OfonoNetworkOperator {
            id: networkOperator
        }
        OfonoSimListModel {
            id: simListModel
        }

        // Push changes to LuneOS
        /*onRoamingAllowedChanged: {
            var roamguard = roamingAllowed ? "disable" : "enable"
            luna.call("palm://com.palm.wan/set",
                      '{"roamguard": "' + roamguard + '"}', _handleSetSuccess,
                      _handleSetError)
        }
        onDataUsageChanged: {
            var disablewan = dataUsage ? "off" : "on"
            luna.call("palm://com.palm.wan/set",
                      '{"disablewan": "' + disablewan + '"}',
                      _handleSetSuccess, _handleSetError)
        }*/
    }
}
