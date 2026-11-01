/*
 * (c) 2026 Herman van Hazendonk <github.com@herrie.org>
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
// Units & font sizes
import LunaNext.Common 0.1

import LuneOS.Forms 1.0

/*
 * One paired Bluetooth device, and the way to forget it: what press-and-hold
 * on a paired row of the Bluetooth page opens, in the shape of the Wi-Fi
 * page's WiFiNetworkInfoPopup. The legacy app forgot a device by swiping its
 * row ("Delete", with no further question); here it hangs off press-and-hold
 * like the Wi-Fi page's "Forget network", and a plain tap stays connect or
 * disconnect.
 *
 * Everything comes off the row's model entry, a BluezQt DevicesModel one, so
 * it stays live while open. Which profiles are up is bluetooth2's to say
 * (device/getConnectedDevices), as BlueZ only says "connected"; that row is
 * left out when bluetooth2 does not answer. Rows with nothing to say are
 * dropped rather than shown blank.
 */
Popup {
    id: deviceInfoPopup

    // The row's model entry (Name, Address, AdapterAddress, Paired,
    // Connected, Type, Battery). QML nulls it when the row goes, which it
    // does when BlueZ drops the device.
    property QtObject device: null

    // The page's LunaService, for the profiles. Optional.
    property var luna: null

    // Profiles bluetooth2 has up for the device, by its names ("a2dp", ...)
    property var connectedProfiles: []

    // "Forget device" was chosen: the page unpairs it.
    signal forgetRequested(string address, string adapterAddress)

    modal: true
    dim: true
    focus: true
    // Nothing here is being edited, so dismissing it by tapping away is safe.
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    height: Math.min(parent.height - Units.gu(4), Units.gu(50))

    onDeviceChanged: if (!device) close();

    readonly property string address: device && device.Address ? String(device.Address) : ""

    onOpened: _subscribeProfiles()

    onClosed: {
        if (_profilesCall && _profilesCall.cancel)
            _profilesCall.cancel();
        _profilesCall = null;
        connectedProfiles = [];
    }

    property var _profilesCall: null

    function _subscribeProfiles() {
        connectedProfiles = [];
        if (!luna || address === "")
            return;
        // Pushed on every profile that comes up or goes down
        _profilesCall = luna.subscribe("luna://com.webos.service.bluetooth2/device/getConnectedDevices",
                                       JSON.stringify({"subscribe": true}),
                                       _handleConnectedDevices, _handleConnectedDevicesError);
    }

    function _handleConnectedDevices(message) {
        if (!message || !message.payload)
            return;
        var response = JSON.parse(message.payload);
        if (response.returnValue === false || !response.devices)
            return;
        var profiles = [];
        for (var i = 0; i < response.devices.length; ++i) {
            var d = response.devices[i];
            if (d && typeof d.address === "string" && d.address.toLowerCase() === address.toLowerCase())
                profiles = d.connectedProfiles || [];
        }
        connectedProfiles = profiles;
    }

    function _handleConnectedDevicesError(message) {
        connectedProfiles = [];
    }

    // BluezQt's Device::Type, in the order of its enum (bluez-qt device.h)
    readonly property var _typeNames: ["Phone", "Modem", "Computer", "Network", "Headset",
        "Headphones", "Audio/video", "Keyboard", "Mouse", "Game controller", "Tablet",
        "Peripheral", "Camera", "Printer", "Imaging", "Wearable", "Toy", "Health"]

    function _addRow(rows, label, value) {
        if (value !== "" && value !== undefined && value !== null)
            rows.push({"rowLabel": label, "rowValue": String(value)});
    }

    readonly property var infoRows: {
        var rows = [];
        if (!device)
            return rows;
        _addRow(rows, "Address", address);
        var type = device.Type;
        if (typeof type === "number" && type >= 0 && type < _typeNames.length)
            _addRow(rows, "Type", _typeNames[type]);
        if (device.Connected === true && connectedProfiles.length > 0)
            _addRow(rows, "Profiles", connectedProfiles.map(function (p) {
                return String(p).toUpperCase();
            }).join(", "));
        var battery = device.Battery;
        if (battery && typeof battery.percentage === "number" && battery.percentage >= 0)
            _addRow(rows, "Battery", battery.percentage + "%");
        return rows;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            objectName: "deviceInfoName"
            Layout.fillWidth: true
            text: deviceInfoPopup.device ? (deviceInfoPopup.device.Name || deviceInfoPopup.address) : ""
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        Label {
            objectName: "deviceInfoState"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("small")
            color: Colors.secondaryText
            text: !deviceInfoPopup.device ? ""
                  : deviceInfoPopup.device.Connected === true ? "Connected" : "Not connected"
        }

        Flickable {
            id: infoFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: infoColumn.height
            flickableDirection: Flickable.AutoFlickIfNeeded
            clip: true

            ScrollIndicator.vertical: ScrollIndicator { }

            Column {
                id: infoColumn
                width: infoFlickable.width

                GroupBox {
                    width: parent.width
                    title: "Device Info"
                    visible: deviceInfoPopup.infoRows.length > 0

                    Column {
                        width: parent.width

                        Repeater {
                            model: deviceInfoPopup.infoRows
                            delegate: Column {
                                width: parent.width

                                HorizontalSeparator {
                                    width: parent.width
                                    visible: index > 0
                                }
                                LabelAndValue {
                                    width: parent.width
                                    label: modelData.rowLabel
                                    value: modelData.rowValue
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            Button {
                objectName: "forgetDeviceButton"
                Layout.fillWidth: true
                visible: !!deviceInfoPopup.device && deviceInfoPopup.device.Paired === true
                text: "Forget device"
                LuneOSButton.mainColor: LuneOSButton.negativeColor
                LuneOSButton.textColor: "white"
                onClicked: {
                    var adapter = deviceInfoPopup.device.AdapterAddress;
                    deviceInfoPopup.forgetRequested(deviceInfoPopup.address,
                                                    typeof adapter === "string" ? adapter : "");
                    deviceInfoPopup.close();
                }
            }
            Button {
                objectName: "cancelButton"
                Layout.fillWidth: true
                text: "Cancel"
                onClicked: deviceInfoPopup.close()
            }
        }
    }
}
