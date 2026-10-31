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
        return deviceManager.disconnectDeviceAddress(address);
    }

    /*
     * "Forget device" in the popup of a paired device: bluetooth2 unpairs it
     * (adapter/unpair, which BlueZ's RemoveDevice does, disconnecting it
     * first when it is connected). Once that went through, bluetooth2 is
     * told not to connect it again when Bluetooth comes on: unpairing does
     * not do that by itself, and the disconnect it brings looks to
     * bluetooth2 like the device going away, which keeps it.
     */
    readonly property string unpairService: "luna://com.webos.service.bluetooth2/adapter/unpair"

    function forgetDevice(address, adapterAddress) {
        var args = {"address": address};
        if (adapterAddress)
            args.adapterAddress = adapterAddress;
        _setDeviceOperation(address, null);
        luna.call(unpairService, JSON.stringify(args),
                  function (message) {
                      var response = JSON.parse(message.payload);
                      if (response.returnValue === false) {
                          bluetoothPageId._forgetFailed(address, message);
                          return;
                      }
                      luna.call(autoReconnectService + "/forget", JSON.stringify(args),
                                _handleSetSuccess, _handleSetError);
                  },
                  function (message) {
                      bluetoothPageId._forgetFailed(address, message);
                  });
    }

    function _forgetFailed(address, message) {
        console.warn("Bluetooth: could not forget " + address + ": " + (message ? message.payload : ""));
        deviceMessage = "Unable to forget the device.";
        deviceMessageTimer.restart();
    }

    /*
     * A connect or disconnect started from the device list, by address:
     * {action: "connect" or "disconnect", started: ms, call: its BluezQt
     * PendingCall}. The device's row shows a spinner in place of its check
     * mark until the device reports the state asked for, BlueZ says the
     * call failed, or deviceOperationTimeoutMs passes - as the legacy app
     * spun a row's spinner while it connected. A new object is assigned on
     * every change, so the rows' bindings follow. Holding the call also
     * keeps it from being collected before it finishes.
     */
    property var deviceOperations: ({})
    // Who connects and disconnects: BluetoothManager, or a test's stand-in
    property var deviceManager: BluetoothManager
    property int deviceOperationTimeoutMs: 30000
    // A failed call is said in the list's status line for this long, as the
    // legacy app said "Unable to connect." in its status area for 5 s.
    property string deviceMessage: ""
    property int deviceMessageMs: 5000

    function _setDeviceOperation(address, op) {
        var ops = {};
        for (var a in deviceOperations) {
            if (a !== address)
                ops[a] = deviceOperations[a];
        }
        if (op)
            ops[address] = op;
        deviceOperations = ops;
    }

    // A tap on a device's row: disconnect it when it is connected, connect
    // it otherwise. BluetoothManager takes a second tap on the device it is
    // connecting as "stop", and drops the device it was connecting when
    // another one is tapped, so neither keeps its spinner.
    function toggleDevice(address, connected) {
        if (connected) {
            _trackDeviceOperation(address, "disconnect", connected, disconnectDevice(address));
            return;
        }
        var connecting = deviceManager.connectingDevice;
        var stops = !!connecting && connecting.address === address;
        for (var a in deviceOperations) {
            if (deviceOperations[a].action === "connect")
                _setDeviceOperation(a, null);
        }
        var call = deviceManager.connectDeviceAddress(address);
        if (!stops)
            _trackDeviceOperation(address, "connect", connected, call);
    }

    // call: what BluetoothManager returned - a PendingCall, or nothing when
    // it did not start one (Bluetooth not up), and then there is nothing to
    // wait for.
    function _trackDeviceOperation(address, action, connected, call) {
        if (!call)
            return;
        var op = {"action": action, "started": Date.now(), "call": call};
        _setDeviceOperation(address, op);
        if (call.finished) {
            call.finished.connect(function (finishedCall) {
                bluetoothPageId._deviceCallFinished(address, op, finishedCall || call);
            });
        }
        _deviceStateChanged(address, connected);
    }

    function _deviceCallFinished(address, op, call) {
        if (deviceOperations[address] !== op || !call.error)
            return;
        // Done when the device says so (_deviceStateChanged): a connect
        // that went through can report Connected after its reply.
        console.warn("Bluetooth: could not " + op.action + " " + address + ": " + call.errorText);
        _setDeviceOperation(address, null);
        deviceMessage = op.action === "connect" ? "Unable to connect." : "Unable to disconnect.";
        deviceMessageTimer.restart();
    }

    // A row's device changed its connected state (or a call was just started)
    function _deviceStateChanged(address, connected) {
        var op = deviceOperations[address];
        if (op && (op.action === "connect") === connected)
            _setDeviceOperation(address, null);
    }

    function _expireDeviceOperations() {
        var now = Date.now();
        for (var a in deviceOperations) {
            if (now - deviceOperations[a].started >= deviceOperationTimeoutMs) {
                console.warn("Bluetooth: no answer to " + deviceOperations[a].action + " " + a);
                _setDeviceOperation(a, null);
            }
        }
    }

    Timer {
        interval: Math.max(50, Math.min(1000, bluetoothPageId.deviceOperationTimeoutMs / 4))
        repeat: true
        running: Object.keys(bluetoothPageId.deviceOperations).length > 0
        onTriggered: bluetoothPageId._expireDeviceOperations()
    }
    Timer {
        id: deviceMessageTimer
        interval: bluetoothPageId.deviceMessageMs
        onTriggered: bluetoothPageId.deviceMessage = ""
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
            if (!BluetoothManager.bluetoothOperational)
                bluetoothPageId.deviceOperations = {};
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

    /*
     * Laid out like the other settings pages (Tethering, Sounds & Alerts):
     * a scrolling column with the page margin, every row inside a group so
     * its label lines up with the group's other rows, and the rows
     * themselves LuneOS.Forms ones, so they have the same font and height.
     * The device list takes the height of its devices and scrolls with the
     * page, so whatever comes under it is not squeezed off the bottom.
     */
    SettingsPageContent {
        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: discoverableToggle
                    label: "Discoverable"

                    checked: BluetoothManager.discoverable
                    onToggled: BluetoothManager.setDiscoverable(checked)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: bluetoothPageId.autoReconnectKnown
                }

                // A row of the same group as "Discoverable", so the two
                // labels line up, with what it does said under the group,
                // as Tethering does for its switches.
                LabelAndSwitch {
                    id: autoReconnectSwitch
                    visible: bluetoothPageId.autoReconnectKnown

                    label: "Reconnect headsets automatically"
                    // Toggling sets checked from C++, which keeps this binding.
                    checked: bluetoothPageId.autoReconnectEnabled
                    onToggled: bluetoothPageId.setAutoReconnect(checked)
                }
            }
        }

        ExplanationText {
            visible: bluetoothPageId.autoReconnectKnown
            text: "When Bluetooth comes on, connect the headset or speaker " +
                  "used last. A device you disconnect here is not connected " +
                  "again until you connect it."
        }

        GroupBox {
            width: parent.width

            title: "Choose a device"
            Column {
                width: parent.width

                // Finding a headset takes BlueZ 10 to 20 s; say that it is
                // looking, and once it has stopped, let it look again.
                RowLayout {
                    width: parent.width
                    height: Units.gu(6)
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
                        text: bluetoothPageId.deviceMessage !== ""
                              ? bluetoothPageId.deviceMessage
                              : BluetoothManager.discovering ? "Searching for devices\u2026"
                                                             : (deviceList.count > 0 ? "" : "No devices found.")
                        color: Colors.secondaryText
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                    }
                    Button {
                        text: "Search again"
                        visible: !BluetoothManager.discovering
                        onClicked: BluetoothManager.searchAgain()
                    }
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: BluetoothManager.bluetoothOperational && deviceList.count > 0
                }

                ListView {
                    id: deviceList
                    objectName: "deviceList"
                    width: parent.width
                    height: contentHeight
                    interactive: false

                    model: btDevicesModel

                    delegate: Item {
                        id: deviceRow
                        width: ListView.view.width
                        height: Units.gu(6)

                        property variant btDevice: model
                        readonly property bool deviceConnected: btDevice.Connected === true
                        // "connect", "disconnect" or "" (deviceOperations)
                        readonly property string operation: {
                            var op = bluetoothPageId.deviceOperations[btDevice.Address];
                            return op ? op.action : "";
                        }
                        onDeviceConnectedChanged: bluetoothPageId._deviceStateChanged(btDevice.Address, deviceRow.deviceConnected)

                        RowLayout {
                            anchors.fill: parent

                            Label {
                                Layout.fillWidth: true
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: btDevice.Name || btDevice.Address
                                // As big as the label of any other row
                                // (LabelAndSwitch, LabelAndValue)
                                font.pixelSize: FontUtils.sizeToPixels("16pt")
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
                            // The check mark of a connected device, or the
                            // spinner in its place while a connect or
                            // disconnect is under way. The place is kept
                            // either way, so the lock of a paired device
                            // stays in one column and nothing moves.
                            Item {
                                Layout.preferredHeight: Units.gu(3.2)
                                Layout.preferredWidth: Units.gu(3.2)

                                Image {
                                    objectName: "deviceConnectedMark"
                                    anchors.fill: parent
                                    source: "../images/wifi/checkmark.png"
                                    opacity: btDevice.Connected && deviceRow.operation === "" ? 1 : 0

                                    fillMode: Image.PreserveAspectFit
                                    horizontalAlignment: Image.AlignHCenter
                                    verticalAlignment: Image.AlignVCenter
                                }
                                // The style's legacy spinner ring, scaled
                                // down to the place of the check mark
                                // (scale leaves the layout as it is)
                                BusyIndicator {
                                    objectName: "deviceBusyIndicator"
                                    anchors.centerIn: parent
                                    running: deviceRow.operation !== ""
                                    scale: Math.min(1, parent.height / Math.max(1, implicitHeight - topPadding - bottomPadding))
                                }
                            }
                        }
                        // Show a separator between items
                        HorizontalSeparator {
                            objectName: "deviceSeparator"
                            anchors.bottom: parent.bottom
                            width: parent.width
                            visible: index < deviceList.count - 1
                        }
                        /*
                         * Tap: connect or disconnect. Press and hold on a
                         * paired device: its popup, with "Forget device".
                         * A TapHandler, as on the Wi-Fi page, where a
                         * MouseArea's pressAndHold was lost to the list's
                         * Flickable after a few pixels of drift (see
                         * WiFiPage.qml). This list does not flick itself,
                         * and in tst_bluetooth_forget a MouseArea's hold
                         * survives the page's Flickable too; a pointer
                         * handler shares the press with any Flickable, so
                         * it keeps working if that changes. TapHandler
                         * emits no tapped() after longPressed(), so a hold
                         * never also connects.
                         */
                        readonly property TapHandler rowTap: deviceTap
                        TapHandler {
                            id: deviceTap
                            objectName: "deviceRowTap"
                            longPressThreshold: 0.8

                            onLongPressed: {
                                if (deviceRow.btDevice.Paired !== true)
                                    return;
                                deviceInfoPopup.device = deviceRow.btDevice;
                                deviceInfoPopup.open();
                            }

                            onTapped: {
                                console.log("Bluetooth Device Selected. Name = " + btDevice.Name + ", connected = " + btDevice.Connected);
                                bluetoothPageId.toggleDevice(btDevice.Address, deviceRow.deviceConnected);
                            }
                        }
                    }
                }
            }
        }

        ExplanationText {
            visible: BluetoothManager.bluetoothOperational && deviceList.count > 0
            text: "Touch and hold a paired device to see its details or forget it."
        }

        /*
         * Calls: whether a hands-free headset that connects during a call
         * takes the call over. The setting is audiod's
         * (bluetoothHeadsetTakesCall, on unless turned off); this block only
         * shows it and hands changes back. Until audiod answers, or if its
         * answer does not carry the setting, the switch shows audiod's
         * default. It stays up with the radio off: it is about where the
         * call is heard, and it applies the next time a headset connects.
         * Beside it, whether alerts and notifications play on the phone's
         * speaker rather than in a Bluetooth headset (audiod's
         * bluetoothAlertsOnSpeaker, off unless turned on), the same way.
         */
        Column {
            id: headsetCallsBlock
            objectName: "headsetCallsBlock"
            width: parent.width
            // The page column's spacing, so the explanation sits as far
            // under the group as on the other settings pages (Tethering)
            spacing: Units.gu(2)

            property bool headsetTakesCall: true
            property bool alertsOnSpeaker: false

            Component.onCompleted: {
                bluetoothPageId.luna.subscribe("luna://org.webosports.service.audio/getSettings",
                                               JSON.stringify({"subscribe": true}),
                                               headsetCallsBlock.handleSettings,
                                               bluetoothPageId._handleGetError);
            }

            function handleSettings(message) {
                if (!message || !message.payload)
                    return;

                var response = JSON.parse(message.payload);
                if (response.returnValue === false)
                    return;
                if (typeof response.bluetoothHeadsetTakesCall === "boolean")
                    headsetCallsBlock.headsetTakesCall = response.bluetoothHeadsetTakesCall;
                if (typeof response.bluetoothAlertsOnSpeaker === "boolean")
                    headsetCallsBlock.alertsOnSpeaker = response.bluetoothAlertsOnSpeaker;
            }

            function setHeadsetTakesCall(takes) {
                headsetCallsBlock.headsetTakesCall = takes;
                bluetoothPageId.luna.call("luna://org.webosports.service.audio/setSettings",
                                          JSON.stringify({"bluetoothHeadsetTakesCall": takes}),
                                          bluetoothPageId._handleSetSuccess,
                                          bluetoothPageId._handleSetError);
            }

            function setAlertsOnSpeaker(on) {
                headsetCallsBlock.alertsOnSpeaker = on;
                bluetoothPageId.luna.call("luna://org.webosports.service.audio/setSettings",
                                          JSON.stringify({"bluetoothAlertsOnSpeaker": on}),
                                          bluetoothPageId._handleSetSuccess,
                                          bluetoothPageId._handleSetError);
            }

            GroupBox {
                width: parent.width

                title: "Calls"
                Column {
                    width: parent.width

                    LabelAndSwitch {
                        id: headsetTakesCallSwitch
                        label: "Headset takes calls"

                        checked: headsetCallsBlock.headsetTakesCall
                        Connections {
                            target: headsetCallsBlock
                            function onHeadsetTakesCallChanged() {
                                headsetTakesCallSwitch.checked = headsetCallsBlock.headsetTakesCall;
                            }
                        }
                        onToggled: headsetCallsBlock.setHeadsetTakesCall(checked)
                    }

                    HorizontalSeparator {
                        width: parent.width
                    }

                    LabelAndSwitch {
                        id: alertsOnSpeakerSwitch
                        label: "Alerts on phone speaker"

                        checked: headsetCallsBlock.alertsOnSpeaker
                        Connections {
                            target: headsetCallsBlock
                            function onAlertsOnSpeakerChanged() {
                                alertsOnSpeakerSwitch.checked = headsetCallsBlock.alertsOnSpeaker;
                            }
                        }
                        onToggled: headsetCallsBlock.setAlertsOnSpeaker(checked)
                    }
                }
            }

            ExplanationText {
                text: "A headset that connects during a call takes it over. " +
                      "With this off the call stays where it is, and the " +
                      "Phone app can still move it to the headset. " +
                      "With \"Alerts on phone speaker\" on, alerts and " +
                      "notifications play on the phone's speaker instead " +
                      "of in the headset, as the ringtone does."
            }
        }
    }

    BluetoothDeviceInfoPopup {
        id: deviceInfoPopup
        objectName: "deviceInfoPopup"
        luna: bluetoothPageId.luna
        onForgetRequested: (address, adapterAddress) => bluetoothPageId.forgetDevice(address, adapterAddress)
        // Nothing to keep once it is off screen
        onClosed: device = null
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
