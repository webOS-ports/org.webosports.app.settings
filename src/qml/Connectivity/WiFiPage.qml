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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0

import "../Common"

// Units & font sizes
import LunaNext.Common 0.1
// Connman
import Connman 0.2

BasePage {
    id: wifiPageId

    TechnologyModel {
        id: wifiModel
        name: "wifi"
    }

    Component.onCompleted: {
        retrieveProperties();
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: wifiPowerSwitch
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            Connections {
                target: wifiModel
                onPoweredChanged: wifiPowerSwitch.checked=wifiModel.powered;
            }
            checked: wifiModel.powered
            onCheckedChanged: wifiModel.powered=checked;
        }
    }

    ColumnLayout {
        width: parent.width
        height: parent.height

        /* GroupBoxes look good! */
        GroupBox {
            width: parent.width
            Layout.fillHeight: true

            title: "Choose a network"
            ColumnLayout {
                width: parent.width
                height: parent.height

                ListView {
                    width: parent.width
                    Layout.fillHeight: true

                    model: wifiModel

                    delegate: Item {
                        property NetworkService delegateService: modelData

                        width: parent.width
                        height: Units.gu(3.2)

                        RowLayout {
                            anchors.fill: parent

                            Text {
                                height: parent.height
                                Layout.fillWidth: true
                                text: delegateService.name
                            }
                            Image {
                                source: "../images/wifi/checkmark.png"
                                visible: delegateService.connected

                                fillMode: Image.PreserveAspectFit
                                Layout.preferredHeight: parent.height
                            }
                            Image {
                                source: "../images/secure-icon.png"
                                visible: delegateService.securityType !== SecurityType.SecurityNone

                                fillMode: Image.PreserveAspectFit
                                Layout.preferredHeight: parent.height
                            }
                            Image {
                                source: "../images/wifi/signal-icon-" + Math.floor(delegateService.strength/25) + ".png"

                                fillMode: Image.PreserveAspectFit
                                Layout.preferredHeight: parent.height
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    height: Units.gu(3.2)
                    Image {
                        source: "../images/icon-new.png"

                        Layout.preferredHeight: parent.height
                        Layout.preferredWidth: height

                        fillMode: Image.PreserveAspectCrop
                        verticalAlignment: Image.AlignTop
                    }
                    Text {
                        height: parent.height
                        Layout.fillWidth: true
                        text: "Join Network"
                    }
                }
            }
        }

        Text {
            font.italic: true
            text: "Your device automatically connects to known networks."
        }
    }

    function retrieveProperties() {
        // nothing special to retrieve here
    }
}
