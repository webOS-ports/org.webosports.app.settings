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
            console.log("onRequestPinCodeFromUser: device="+device.name+", request="+request);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothProvidePinCodePopup.qml"),
                                  {"bluezRequest": request, "deviceName": device.name});
        }
        onRequestPasskeyFromUser: {
            console.log("onRequestPasskeyFromUser: device="+device.name+", request="+request);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothProvidePassKeyPopup.qml"),
                                  {"bluezRequest": request});
        }
        onRequestConfirmationFromUser: {
            console.log("onRequestConfirmationFromUser: device="+device.name+", passkey="+passkey+", request="+request);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothConfirmPassKeyPopup.qml"),
                                  {"bluezRequest": request, "deviceName": device.name, "passkey": passkey});
        }
        onRequestAuthorizationFromUser: {
            console.log("onRequestAuthorizationFromUser: device="+device.name+", request="+request);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothConfirmAuthorizePopup.qml"),
                                  {"bluezRequest": request, "deviceName": device.name, "passkey": passkey});
        }
        onAuthorizeServiceFromUser: {
            console.log("onAuthorizeServiceFromUser: device="+device.name+", uuid="+uuid+", request="+request);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothAuthorizeServicePopup.qml"),
                                  {"bluezRequest": request, "deviceName": device.name, "serviceUUID": uuid});
        }
        onDisplayPasskeyToUser: {
            console.log("onDisplayPasskey: device="+device.name+", passkey="+passkey+", entered="+entered);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothDisplayPassKeyPopup.qml"),
                                  {"deviceName": device.name, "passkey": passkey});
        }
        onDisplayPinCodeToUser: {
            console.log("onDisplayPinCode: device="+device.name+", pinCode="+pinCode);
            popupLoader.setSource(Qt.resolvedUrl("BluetoothDisplayPinCodePopup.qml"),
                                  {"deviceName": device.name, "pinCode": pinCode});
        }
        onCancel: {
            console.log("onCancel");
            if(popupLoader.item) popupLoader.item.close();
        }
        onRelease: {
            console.log("onRelease");
            if(popupLoader.item) popupLoader.item.close();
        }
    }

    Component.onCompleted: {
        BluetoothManager.discoveringMode = true;
    }

    Connections {
        target: BluetoothManager
        onBluetoothOperationalChanged: {
            console.log("BluetoothManager.bluetoothOperational="+BluetoothManager.bluetoothOperational);
            btAgent.registerToManager(BluetoothManager.btManager);
        }
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

    ColumnLayout {
        anchors.fill: parent

        Switch {
            id: discoverableToggle

            text: "Discoverable"

            anchors.left: parent.left
            anchors.right: parent.right

            LayoutMirroring.enabled: true
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            checked: BluetoothManager.discoverable
            onClicked: {
                BluetoothManager.setDiscoverable(discoverableToggle.checked);
            }
        }

        /* GroupBoxes look good! */
        GroupBox {
            anchors.left: parent.left
            anchors.right: parent.right
            Layout.fillHeight: true

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
                        height: Units.gu(6)

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
                                horizontalAlignment: Image.AlignHCenter
                                verticalAlignment: Image.AlignVCenter
                                Layout.preferredHeight: Units.gu(3.2)
                                Layout.preferredWidth: Units.gu(1.5)
                            }
                            Image {
                                source: "../images/wifi/checkmark.png"
                                visible: btDevice.Connected

                                fillMode: Image.PreserveAspectFit
                                horizontalAlignment: Image.AlignHCenter
                                verticalAlignment: Image.AlignVCenter
                                Layout.preferredHeight: Units.gu(3.2)
                                Layout.preferredWidth: Units.gu(3.2)
                            }
                        }
                        // Show a separator between items
                        Rectangle {
                            y: parent.height-1
                            height: 1
                            width: parent.width
                            color: '#ADADAD'
                            visible: index < btDevicesModel.count - 1
                        }
                        Rectangle {
                            y: parent.height
                            height: 1
                            width: parent.width
                            color: '#ECECEC'
                            visible: index < btDevicesModel.count - 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                console.log("Bluetooth Device Selected. Name = " + btDevice.Name + ", connected = " + btDevice.Connected);
                                if(!btDevice.Connected) {
                                    // connect !
                                    BluetoothManager.connectDeviceAddress(btDevice.Address);
                                } else {
                                    // disconnect !
                                    BluetoothManager.disconnectDeviceAddress(btDevice.Address);
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Loader {
        id: popupLoader
        anchors.fill: parent

        onItemChanged: {
            if(item && item.onClosed) {
                item.onClosed.connect(function() {
                    // ensure the component is unlaaded
                    if(!item.visible) popupLoader.source = "";
                });
            }
        }
    }
}
