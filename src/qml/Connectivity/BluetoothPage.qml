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
import LuneOS.Bluetooth 0.2

BasePage {
    id: bluetoothPageId

    BluetoothDevicesModel {
        id: btDevicesModel
    }
    LuneOSBluetoothAgent {
        id: btAgent
        path: "/org/webosports/apps/settings"
        capability: LuneOSBluetoothAgent.DisplayYesNo

        onRequestPinCodeFromUser: {
            console.log("onRequestPinCodeFromUser: device="+device+", request="+request);
        }
        onRequestPasskeyFromUser: {
            console.log("onRequestPasskeyFromUser: device="+device+", request="+request);
        }
        onRequestConfirmationFromUser: {
            console.log("onRequestConfirmationFromUser: device="+device+", passkey="+passkey+", request="+request);
        }
        onRequestAuthorizationFromUser: {
            console.log("onRequestAuthorizationFromUser: device="+device+", request="+request);
        }
        onAuthorizeServiceFromUser: {
            console.log("onAuthorizeServiceFromUser: device="+device+", uuid="+uuid+", request="+request);
        }
        onDisplayPasskey: {
            console.log("onDisplayPasskey: device="+device+", passkey="+passkey+", entered="+entered);
        }
        onDisplayPinCode: {
            console.log("onDisplayPinCode: device="+device+", pinCode="+pinCode);
        }
        onCancel: {
            console.log("onCancel");
        }
        onRelease: {
            console.log("onRelease");
        }
    }

    Component.onCompleted: {
        retrieveProperties();

        BluetoothManager.discoveringMode = true;
        btAgent.registerToManager(BluetoothManager.btManager);
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: bluetoothPowerSwitch
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            Connections {
                target: BluetoothManager
                onPoweredChanged: bluetoothPowerSwitch.checked=BluetoothManager.powered;
            }
            checked: BluetoothManager.powered
            onCheckedChanged: BluetoothManager.powered = checked;
        }
    }

    /* GroupBoxes look good! */
    GroupBox {
        anchors.fill: parent

        title: "Choose a network"
        ColumnLayout {
            anchors.fill: parent

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                model: btDevicesModel

                delegate: Item {
                    width: parent.width
                    height: Units.gu(3.2)

                    property variant btDevice: model

                    RowLayout {
                        anchors.fill: parent

                        Label {
                            height: parent.height
                            Layout.fillWidth: true
                            Layout.minimumWidth: contentWidth
                            text: btDevice.Name || btDevice.Address
                        }
                        Image {
                            source: "../images/secure-icon.png"
                            visible: btDevice.Paired

                            fillMode: Image.PreserveAspectFit
                            Layout.preferredHeight: parent.height
                            Layout.preferredWidth: parent.height
                        }
                        Image {
                            source: "../images/wifi/checkmark.png"
                            visible: btDevice.Connected

                            fillMode: Image.PreserveAspectFit
                            Layout.preferredHeight: parent.height
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // connect !
                            console.log("Bluetooth Device Selected. Name = " + btDevice.Name + ", connected = " + btDevice.Connected);
                            BluetoothManager.connectDeviceAddress(btDevice.Address);
                        }
                    }
                }
            }
        }
    }

    function retrieveProperties() {
    }
}
