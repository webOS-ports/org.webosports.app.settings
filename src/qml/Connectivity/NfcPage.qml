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
    property string cloneStatus: ""
    property string lockStatus: ""
    property bool lockConfirmPending: false

    // Result of a PACE document read (readPassportPACE) - null until one
    // succeeds, cleared whenever the tag changes
    property var documentFields: null
    property string documentPhotoBase64: ""
    property string documentPhotoFormat: ""
    property string documentReadStatus: ""

    // Set while waiting for a second (target) tag after "Copy this tag" -
    // holds the source tag's raw bytes until a new tag is presented
    property string cloneSourceHex: ""
    property bool cloneWaitingForTarget: false

    readonly property bool tagIsWritable:
        tagInfo !== null && tagInfo.interfaces !== undefined &&
        tagInfo.interfaces.indexOf("org.sailfishos.nfc.TagType2") >= 0

    readonly property bool tagIsCloneable:
        tagInfo !== null && tagInfo.rawDataHex !== undefined && tagInfo.rawDataHex !== ""

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

        var wasPresent = tagPresent;
        tagPresent = response.present === true;
        tagInfo = response.tag !== undefined ? response.tag : null;

        // A fresh tag invalidates whatever the last write/clone/lock said
        if (tagInfo === null) {
            writeStatus = "";
            cloneStatus = "";
            lockStatus = "";
            documentFields = null;
            documentPhotoBase64 = "";
            documentPhotoFormat = "";
            documentReadStatus = "";
        }

        // Waiting for a target to copy onto, and a *new* tag (the source
        // was removed first) just appeared with raw data of its own to
        // overwrite - go
        if (cloneWaitingForTarget && !wasPresent && tagPresent &&
            tagInfo !== null && tagInfo.rawDataHex !== undefined) {
            writeToCloneTarget();
        }
    }

    function startClone() {
        cloneSourceHex = tagInfo.rawDataHex;
        cloneWaitingForTarget = true;
        cloneStatus = "Remove this tag, then hold a blank tag against the device to copy to it.";
    }

    function cancelClone() {
        cloneWaitingForTarget = false;
        cloneStatus = "";
    }

    function writeToCloneTarget() {
        cloneWaitingForTarget = false;
        cloneStatus = "Writing...";

        luna.call("luna://com.webos.service.nfc/cloneTag",
                  JSON.stringify({"rawDataHex": cloneSourceHex}),
                  onCloneDone, onCloneError);
    }

    function onCloneDone(message) {
        var response = JSON.parse(message.payload);

        cloneStatus = response.returnValue ? "Copied to the new tag."
                                            : ("Failed: " + response.errorText);
    }

    function onCloneError(message) {
        cloneStatus = "Failed: " + message;
    }

    function doLockTag() {
        lockStatus = "Locking...";

        luna.call("luna://com.webos.service.nfc/lockTag", "{}",
                  onLockDone, onLockError);
    }

    function onLockDone(message) {
        var response = JSON.parse(message.payload);

        lockStatus = response.returnValue ? "Tag locked. It can no longer be written to."
                                           : ("Failed: " + response.errorText);
    }

    function onLockError(message) {
        lockStatus = "Failed: " + message;
    }

    function readDocument() {
        documentFields = null;
        documentPhotoBase64 = "";
        documentPhotoFormat = "";
        documentReadStatus = "Reading - hold the document steady...";

        luna.call("luna://com.webos.service.nfc/readPassportPACE",
                  JSON.stringify({"can": documentCanField.text, "readPhoto": true}),
                  onDocumentReadDone, onDocumentReadError);
    }

    function onDocumentReadDone(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue) {
            documentReadStatus = "Failed: " + response.errorText;
            return;
        }

        documentReadStatus = "";
        documentFields = response;
        documentPhotoBase64 = response.photoBase64 !== undefined ? response.photoBase64 : "";
        documentPhotoFormat = response.photoFormat !== undefined ? response.photoFormat : "";
    }

    function onDocumentReadError(message) {
        documentReadStatus = "Failed: " + message;
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

    TabBar {
        id: nfcTabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: Units.gu(4.8)

        TabButton {
            text: "Tag"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }
        TabButton {
            text: "ID / Passport"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }
    }

    SwipeView {
        id: nfcTabView
        anchors.top: nfcTabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        currentIndex: nfcTabBar.currentIndex
        onCurrentIndexChanged: nfcTabBar.currentIndex = currentIndex

    ScrollView {
        clip: true

    ColumnLayout {
        width: nfcTabView.width
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

        GroupBox {
            Layout.fillWidth: true
            visible: nfcPageId.nfcAvailable && nfcPageId.nfcEnabled

            title: "Copy a tag"

            ColumnLayout {
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: nfcPageId.cloneStatus !== "" ? nfcPageId.cloneStatus
                              : (nfcPageId.tagIsCloneable
                                 ? "Ready to copy. Only Type 2 tags can be copied."
                                 : "Hold the tag you want to copy against the device.")
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }

                    Button {
                        text: "Copy this tag"
                        visible: !nfcPageId.cloneWaitingForTarget
                        enabled: nfcPageId.tagIsCloneable
                        onClicked: nfcPageId.startClone()
                    }

                    Button {
                        text: "Cancel"
                        visible: nfcPageId.cloneWaitingForTarget
                        onClicked: nfcPageId.cancelClone()
                    }
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            visible: nfcPageId.nfcAvailable && nfcPageId.nfcEnabled

            title: "Lock a tag"

            ColumnLayout {
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: nfcPageId.lockStatus !== "" ? nfcPageId.lockStatus
                              : (nfcPageId.lockConfirmPending
                                 ? "This is permanent - the tag can never be written to again."
                                 : "Permanently write-protect this tag. Cannot be undone.")
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }

                    Button {
                        text: "Lock tag"
                        visible: !nfcPageId.lockConfirmPending
                        enabled: nfcPageId.tagIsWritable
                        onClicked: nfcPageId.lockConfirmPending = true
                    }

                    Button {
                        text: "Cancel"
                        visible: nfcPageId.lockConfirmPending
                        onClicked: nfcPageId.lockConfirmPending = false
                    }

                    Button {
                        text: "Confirm lock"
                        visible: nfcPageId.lockConfirmPending
                        onClicked: {
                            nfcPageId.lockConfirmPending = false;
                            nfcPageId.doLockTag();
                        }
                    }
                }
            }
        }
    } // ColumnLayout (Tag tab)
    } // ScrollView (Tag tab)

    ScrollView {
        clip: true

    ColumnLayout {
        width: nfcTabView.width
        spacing: Units.gu(1)

        GroupBox {
            Layout.fillWidth: true
            visible: nfcPageId.nfcAvailable && nfcPageId.nfcEnabled

            title: "Read ID card or passport"

            ColumnLayout {
                anchors.fill: parent

                RowLayout {
                    Layout.fillWidth: true

                    TextField {
                        id: documentCanField
                        Layout.preferredWidth: Units.gu(16)
                        placeholderText: "6-digit CAN"
                        maximumLength: 6
                        inputMethodHints: Qt.ImhDigitsOnly

                        // The numeric VKB has no dismiss/done key on this
                        // device, so don't rely on reaching a button that
                        // may end up hidden behind it - submit as soon as
                        // the CAN is complete and drop focus to close it.
                        onTextChanged: {
                            if (text.length === 6) {
                                focus = false;
                                nfcPageId.readDocument();
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Button {
                        text: "Read"
                        enabled: documentCanField.text.length === 6
                        onClicked: nfcPageId.readDocument()
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    text: nfcPageId.documentReadStatus !== "" ? nfcPageId.documentReadStatus
                          : "Enter the CAN printed on the document, then hold it against the device."
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }

                HorizontalSeparator {
                    Layout.fillWidth: true
                    visible: nfcPageId.documentFields !== null
                }

                Image {
                    Layout.alignment: Qt.AlignHCenter
                    visible: nfcPageId.documentPhotoBase64 !== ""
                    source: nfcPageId.documentPhotoBase64 !== ""
                            ? ("data:image/" + nfcPageId.documentPhotoFormat + ";base64," +
                               nfcPageId.documentPhotoBase64)
                            : ""
                    fillMode: Image.PreserveAspectFit
                    Layout.preferredHeight: Units.gu(24)
                    Layout.preferredWidth: Units.gu(18)
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.documentFields !== null
                    label: "Name"
                    value: nfcPageId.documentFields
                           ? (nfcPageId.documentFields.givenNames + " " + nfcPageId.documentFields.surname)
                           : ""
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.documentFields !== null
                    label: "Document number"
                    value: nfcPageId.documentFields ? nfcPageId.documentFields.documentNumber : ""
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.documentFields !== null
                    label: "Nationality"
                    value: nfcPageId.documentFields ? nfcPageId.documentFields.nationality : ""
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.documentFields !== null
                    label: "Date of birth"
                    value: nfcPageId.documentFields ? nfcPageId.documentFields.dateOfBirth : ""
                }

                LabelAndValue {
                    Layout.fillWidth: true
                    visible: nfcPageId.documentFields !== null
                    label: "Date of expiry"
                    value: nfcPageId.documentFields ? nfcPageId.documentFields.dateOfExpiry : ""
                }
            }
        }
    } // ColumnLayout (ID/Passport tab)
    } // ScrollView (ID/Passport tab)
    } // SwipeView
}
