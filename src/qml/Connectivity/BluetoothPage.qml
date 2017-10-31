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
// LuneOS Bluetooth wrapper
import LuneOS.Bluetooth 0.1

BasePage {
    id: bluetoothPageId

    Component.onCompleted: {
        retrieveProperties();
    }
    Component.onDestruction: {
        console.log("Stopping bluetooth discovery.");
        BluetoothService.stopDiscovery();
    }

    Connections {
        target: BluetoothService
        onReady: {
            if(BluetoothService.powered) {
                BluetoothService.startDiscovery();
            }
        }
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: bluetoothPowerSwitch
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            Connections {
                target: BluetoothService
                onPoweredChanged: {
                    bluetoothPowerSwitch.checked=BluetoothService.powered;
                    if(BluetoothService.powered) {
                        BluetoothService.startDiscovery();
                    }
                    else {
                        BluetoothService.stopDiscovery();
                    }
                }
            }
            checked: BluetoothService.powered
            onCheckedChanged: BluetoothService.setPowered(checked);
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

                    model: BluetoothService.deviceModel

                    delegate: Item {
                        property BluetoothDevice delegateDevice: device

                        width: parent.width
                        height: Units.gu(3.2)

                        RowLayout {
                            anchors.fill: parent

                            Text {
                                height: parent.height
                                Layout.fillWidth: true
                                text: delegateDevice.name
                            }
                            Image {
                                source: "../images/wifi/checkmark.png"
                                visible: delegateDevice.connected

                                fillMode: Image.PreserveAspectFit
                                Layout.preferredHeight: parent.height
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                        }
                    }
                }
            }
        }
    }

    function retrieveProperties() {
    }
}
