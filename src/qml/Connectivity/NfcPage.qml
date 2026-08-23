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

import "../Common"

// Units & font sizes
import LunaNext.Common 0.1

BasePage {
    id: nfcPageId

    // Mirrors com.webos.service.nfc/getStatus
    property bool nfcAvailable: false
    property bool nfcEnabled: false
    property bool nfcPowered: false
    property bool tagPresent: false

    // The decoded tag from com.webos.service.nfc/getTagInfo, or null
    property var tagInfo: null

    property string writeStatus: ""

    readonly property bool tagIsWritable:
        tagInfo !== null && tagInfo.interfaces !== undefined &&
        tagInfo.interfaces.indexOf("org.sailfishos.nfc.TagType2") >= 0

    Component.onCompleted: {
        subscribeStatus();
        subscribeTagInfo();
    }

    function subscribeStatus() {
        luna.subscribe("luna://com.webos.service.nfc/getStatus",
                       JSON.stringify({"subscribe": true}),
                       onStatusChanged, _handleGetError);
    }

    function onStatusChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue)
            return;

        nfcAvailable = response.available === true;
        nfcEnabled = response.enabled === true;
        nfcPowered = response.powered === true;
        tagPresent = response.present === true;
    }

    function subscribeTagInfo() {
        luna.subscribe("luna://com.webos.service.nfc/getTagInfo",
                       JSON.stringify({"subscribe": true}),
                       onTagInfoChanged, _handleGetError);
    }

    function onTagInfoChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue)
            return;

        tagPresent = response.present === true;
        tagInfo = response.tag !== undefined ? response.tag : null;

        // A fresh tag invalidates whatever the last write said
        if (tagInfo === null)
            writeStatus = "";
    }

    function setNfcEnabled(value) {
        luna.call("luna://com.webos.service.nfc/setEnabled",
                  JSON.stringify({"enabled": value}),
                  _handleSetSuccess, _handleSetError);
    }

    function writeTag() {
        var request = {"type": writeTypeCombo.currentIndex === 0 ? "uri" : "text"};

        if (request.type === "uri")
            request.uri = writeValueField.text;
        else
            request.text = writeValueField.text;

        writeStatus = "Writing...";

        luna.call("luna://com.webos.service.nfc/writeTag", JSON.stringify(request),
                  onWriteDone, onWriteError);
    }

    function onWriteDone(message) {
        var response = JSON.parse(message.payload);

        writeStatus = response.returnValue ? "Written to the tag."
                                           : ("Failed: " + response.errorText);
    }

    function onWriteError(message) {
        writeStatus = "Failed: " + message;
    }

    // Renders a record in whichever way we managed to decode it
    function describeRecord(record) {
        if (record.kind === "uri")
            return record.uri;

        if (record.kind === "text")
            return record.text + "  (" + record.language + ")";

        if (record.kind === "media")
            return record.text !== undefined ? record.text : record.mediaType;

        if (record.kind === "external")
            return record.externalType;

        if (record.kind === "smartposter")
            return "Smart poster";

        return "Unrecognised record (" + record.payloadSize + " bytes)";
    }

    pageActionHeaderComponent: Component {
        Switch {
            id: nfcPowerSwitch

            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            enabled: nfcPageId.nfcAvailable
            checked: nfcPageId.nfcEnabled

            // Clicking breaks the binding above, so put it back whenever the
            // service tells us the real state changed
            Connections {
                target: nfcPageId
                function onNfcEnabledChanged() {
                    nfcPowerSwitch.checked = nfcPageId.nfcEnabled;
                }
            }

            onClicked: nfcPageId.setNfcEnabled(checked)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            visible: !nfcPageId.nfcAvailable
            wrapMode: Text.WordWrap
            text: "No NFC hardware was found on this device, or the NFC daemon " +
                  "is not running."
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        GroupBox {
            Layout.fillWidth: true
            visible: nfcPageId.nfcAvailable

            title: "Status"

            ColumnLayout {
                anchors.fill: parent

                LabelAndValue {
                    Layout.fillWidth: true
                    label: "Radio"
                    value: nfcPageId.nfcPowered ? "On" : "Off"
                }

                HorizontalSeparator { Layout.fillWidth: true }

                LabelAndValue {
                    Layout.fillWidth: true
                    label: "Tag in range"
                    value: nfcPageId.tagPresent ? "Yes" : "No"
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: nfcPageId.nfcAvailable && nfcPageId.nfcEnabled

            title: "Tag"

            ColumnLayout {
                anchors.fill: parent

                Label {
                    Layout.fillWidth: true
                    visible: nfcPageId.tagInfo === null
                    wrapMode: Text.WordWrap
                    text: nfcPageId.tagPresent ? "Reading the tag..."
                                               : "Hold a tag against the back of the device."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.tagInfo !== null
                    label: "Technology"
                    value: nfcPageId.tagInfo ? nfcPageId.tagInfo.technology : ""
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.tagInfo !== null
                    label: "Protocol"
                    value: nfcPageId.tagInfo ? nfcPageId.tagInfo.protocol : ""
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    // NFCID1 is the tag UID, which is what access badges are keyed on
                    visible: nfcPageId.tagInfo !== null &&
                             nfcPageId.tagInfo.pollParameters !== undefined &&
                             nfcPageId.tagInfo.pollParameters.NFCID1 !== undefined
                    label: "UID"
                    value: (nfcPageId.tagInfo && nfcPageId.tagInfo.pollParameters)
                           ? (nfcPageId.tagInfo.pollParameters.NFCID1 || "") : ""
                }

                HorizontalSeparator {
                    Layout.fillWidth: true
                    visible: nfcPageId.tagInfo !== null
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: nfcPageId.tagInfo !== null
                    clip: true

                    model: (nfcPageId.tagInfo && nfcPageId.tagInfo.records)
                           ? nfcPageId.tagInfo.records : []

                    delegate: Item {
                        width: ListView.view.width
                        height: Units.gu(6)

                        property var record: modelData

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                text: nfcPageId.describeRecord(record)
                                font.pixelSize: FontUtils.sizeToPixels("medium")
                            }

                            Label {
                                Layout.fillWidth: true
                                text: record.kind !== undefined ? record.kind : "raw"
                                color: "#555"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: nfcPageId.tagInfo !== null &&
                             (nfcPageId.tagInfo.records === undefined ||
                              nfcPageId.tagInfo.records.length === 0)
                    text: "This tag is empty."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            visible: nfcPageId.nfcAvailable && nfcPageId.nfcEnabled

            title: "Write a tag"

            ColumnLayout {
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true

                    ComboBox {
                        id: writeTypeCombo
                        model: ["Link", "Text"]
                        Layout.preferredWidth: Units.gu(14)
                    }

                    TextField {
                        id: writeValueField
                        Layout.fillWidth: true
                        placeholderText: writeTypeCombo.currentIndex === 0
                                         ? "https://www.webos-ports.org" : "Text to write"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: nfcPageId.writeStatus !== "" ? nfcPageId.writeStatus
                              : (nfcPageId.tagIsWritable
                                 ? "Ready to write."
                                 : "Hold a writable tag against the device. Only Type 2 tags can be written.")
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }

                    Button {
                        text: "Write"
                        enabled: nfcPageId.tagIsWritable && writeValueField.text !== ""
                        onClicked: nfcPageId.writeTag()
                    }
                }
            }
        }
    }
}
