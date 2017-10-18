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
import MeeGo.Connman 0.2
import QtBluetooth 5.9

BasePage {
    id: bluetoothPageId

    // use connman to power on/off bluetooth
    TechnologyModel {
        id: bluetoothTechnologyModel
        name: "bluetooth"
    }
    BluetoothDiscoveryModel {
        id: bluetoothModel
        running: bluetoothPowered
        onServiceDiscovered: console.log("Found new service " + service.deviceAddress + " " + service.deviceName + " " + service.serviceName);
        onDeviceDiscovered: console.log("New device: " + device)
        onErrorChanged: {
                switch (bluetoothModel.error) {
                case BluetoothDiscoveryModel.PoweredOffError:
                    console.log("Error: Bluetooth device not turned on"); break;
                case BluetoothDiscoveryModel.InputOutputError:
                    console.log("Error: Bluetooth I/O Error"); break;
                case BluetoothDiscoveryModel.InvalidBluetoothAdapterError:
                    console.log("Error: Invalid Bluetooth Adapter Error"); break;
                case BluetoothDiscoveryModel.NoError:
                    break;
                default:
                    console.log("Error: Unknown Error"); break;
                }
        }
   }

    property bool bluetoothPowered

    Component.onCompleted: {
        retrieveProperties();
    }

    pageActionHeaderComponent: Component {
        Switch {
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            onCheckedChanged: bluetoothPowered=checked;
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

                    model: bluetoothModel

                    delegate: Item {
                        property BluetoothService delegateService: service

                        width: parent.width
                        height: Units.gu(3.2)

                        RowLayout {
                            anchors.fill: parent

                            Text {
                                height: parent.height
                                Layout.fillWidth: true
                                text: delegateService.deviceName
                            }
                            Image {
                                source: "../images/wifi/checkmark.png"
                                visible: true

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
        bluetoothPageId.bluetoothPowered = bluetoothTechnologyModel.powered;
    }
    onBluetoothPoweredChanged: bluetoothTechnologyModel.powered = bluetoothPageId.bluetoothPowered;
}
