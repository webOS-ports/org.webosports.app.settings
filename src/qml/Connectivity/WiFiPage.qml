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

import MeeGo.Connman 0.2

BasePage {
    id: wifiPageId

    TechnologyModel {
        id: wifiModel
        name: "wifi"
    }

    property bool wifiPowered //: wifiPowerSwitch.checked

    Component.onCompleted: {
        retrieveProperties();
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: wifiPowerSwitch
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            onCheckedChanged: wifiPowered=checked;
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
                        height: 50
                        CheckDelegate {
                            anchors.fill: parent
                            text: delegateService.name
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    height: 50
                    Image {
                        source: ""
                        height: parent.height
                        width: height
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
        wifiPageId.wifiPowered = wifiModel.powered;
    }
    onWifiPoweredChanged: wifiModel.powered = wifiPageId.wifiPowered;
}
