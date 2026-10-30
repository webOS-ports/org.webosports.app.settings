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
import LuneOS.Forms 1.0

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

    // Whether bluetooth2 connects the headset used last again when Bluetooth
    // comes on (boot, switching it on, a stack restart). bluetooth2 keeps the
    // setting; the switch only shows once it has said what it is.
    readonly property string autoReconnectService: "luna://com.webos.service.bluetooth2/autoReconnect"
    property bool autoReconnectKnown: false
    property bool autoReconnectEnabled: true

    function _handleAutoReconnectStatus(message) {
        var response = JSON.parse(message.payload);
        if (response.returnValue === false || response.enabled === undefined)
            return;
        autoReconnectEnabled = response.enabled === true;
        autoReconnectKnown = true;
    }
    function _handleAutoReconnectError(message) {
        console.warn("Bluetooth: no auto-reconnect setting: " + message.payload);
    }
    function setAutoReconnect(enabled) {
        autoReconnectEnabled = enabled;
        luna.call(autoReconnectService + "/setState", JSON.stringify({"enabled": enabled}),
                  _handleAutoReconnectStatus,
                  function (message) {
                      // Not taken: show what bluetooth2 still has.
                      _handleSetError(message);
                      autoReconnectEnabled = !enabled;
                  });
    }
    // The user disconnected this device: bluetooth2 must not bring it back
    // by itself, as Android does not. It cannot tell by itself, as the
    // disconnect goes to BlueZ directly.
    function disconnectDevice(address) {
        luna.call(autoReconnectService + "/forget", JSON.stringify({"address": address}),
                  _handleSetSuccess, _handleSetError);
        BluetoothManager.disconnectDeviceAddress(address);
    }

    // Search while the page is up. BluetoothManager stops a search after
    // 30 s by itself; leaving the card ends it at once, and coming back to
    // it starts a new one, since a headset may have been put into pairing
    // mode in the meantime. BluetoothManager outlives the page (it is a
    // singleton), so the page has to say when it goes too.
    Component.onCompleted: {
        BluetoothManager.discoveringMode = true;
        luna.subscribe(autoReconnectService + "/getStatus", JSON.stringify({"subscribe": true}),
                       _handleAutoReconnectStatus, _handleAutoReconnectError);
    }
    Component.onDestruction: {
        BluetoothManager.discoveringMode = false;
    }
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                BluetoothManager.searchAgain();
            else
                BluetoothManager.discoveringMode = false;
        }
    }

    Connections {
        target: BluetoothManager
        function onBluetoothOperationalChanged() {
            console.log("BluetoothManager.bluetoothOperational="+BluetoothManager.bluetoothOperational);
            btAgent.registerToManager(BluetoothManager.btManager);
        }
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: bluetoothPowerSwitch

            Connections {
                target: BluetoothManager
                function onPoweredChanged() {
                    bluetoothPowerSwitch.checked=BluetoothManager.powered;
                }
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

            Layout.fillWidth: true
            LayoutMirroring.enabled: true

            checked: BluetoothManager.discoverable
            onClicked: {
                BluetoothManager.setDiscoverable(discoverableToggle.checked);
            }
        }

        LabelAndSwitch {
            id: autoReconnectSwitch
            Layout.fillWidth: true
            visible: bluetoothPageId.autoReconnectKnown

            label: "Reconnect headsets automatically"
            // Toggling sets checked from C++, which keeps this binding.
            checked: bluetoothPageId.autoReconnectEnabled
            onToggled: bluetoothPageId.setAutoReconnect(checked)
        }
        ExplanationText {
            Layout.fillWidth: true
            visible: bluetoothPageId.autoReconnectKnown
            text: "When Bluetooth comes on, connect the headset or speaker used last. A device you disconnect here is not connected again until you connect it."
        }

        /* GroupBoxes look good! */
        GroupBox {
            Layout.fillHeight: true
            Layout.fillWidth: true

            title: "Choose a device"
            ColumnLayout {
                anchors.fill: parent

                // Finding a headset takes BlueZ 10 to 20 s; say that it is
                // looking, and once it has stopped, let it look again.
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Units.gu(5)
                    visible: BluetoothManager.bluetoothOperational

                    BusyIndicator {
                        running: BluetoothManager.discovering
                        visible: running
                        Layout.preferredHeight: Units.gu(4)
                        Layout.preferredWidth: Units.gu(4)
                    }
                    Label {
                        Layout.fillWidth: true
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        text: BluetoothManager.discovering ? "Searching for devices\u2026"
                                                           : (btDevicesModel.count > 0 ? "" : "No devices found.")
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                    }
                    Button {
                        text: "Search again"
                        visible: !BluetoothManager.discovering
                        onClicked: BluetoothManager.searchAgain()
                    }
                }

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
                        HorizontalSeparator {
                            anchors.bottom: parent.bottom
                            width: parent.width
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
                                    bluetoothPageId.disconnectDevice(btDevice.Address);
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
