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
    id: fingerprintPageId

    // Mirrors com.webos.service.fingerprint/getStatus
    property bool sensorAvailable: false
    // FPC sensors store at most 5 templates; the HAL lets a 6th enrollment
    // run through all its scans and only errors out at the very end (with
    // HW_UNAVAILABLE rather than NO_SPACE on sargo), which looks like a
    // silently ignored add. Stop it up front instead.
    readonly property int maxFingerprints: 5

    // Index of the fingerprint currently being renamed, or -1. Kept at page
    // level so only one row edits at a time and so the content can lift above
    // the virtual keyboard (a low row would otherwise sit behind it).
    property int editingIndex: -1
    property string sensorState: ""
    property var fingerprints: []

    // Enrollment state
    property bool enrolling: false
    property int enrollProgress: 0
    property string enrollHint: ""
    property string enrollResult: ""
    property var _enrollCall: null

    Component.onCompleted: subscribeStatus();

    // When enrollment starts, the Cancel button appears in the exact spot the
    // Add button occupied, so the second half of a double-tap (or a touch
    // bounce) would instantly abort the enrollment. Ignore Cancel briefly.
    onEnrollingChanged: if (enrolling) cancelGuard.restart();

    Timer {
        id: cancelGuard
        interval: 800
        repeat: false
    }

    Timer {
        id: statusRetry
        interval: 2000
        repeat: false
        onTriggered: fingerprintPageId.subscribeStatus()
    }

    function subscribeStatus() {
        luna.subscribe("luna://com.webos.service.fingerprint/getStatus",
                       JSON.stringify({"subscribe": true}),
                       onStatusChanged, _handleStatusError);
    }

    // One-shot refresh, used right after a rename/remove so the list updates
    // immediately even if the subscription missed the ListChanged.
    function refreshStatus() {
        luna.call("luna://com.webos.service.fingerprint/getStatus", "{}",
                  onStatusChanged, _handleStatusError);
    }

    function onStatusChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue) {
            // adapter dropped (e.g. restarted); re-subscribe so the panel
            // recovers on its own
            statusRetry.restart();
            return;
        }

        sensorAvailable = response.available === true;
        sensorState = response.state !== undefined ? response.state : "";
        fingerprints = response.fingerprints !== undefined ? response.fingerprints : [];
    }

    function _handleStatusError(message) {
        console.warn("Fingerprint getStatus error: " + message);
        statusRetry.restart();
    }

    function nextFingerName() {
        var i = 1;
        while (fingerprints.indexOf("finger-" + i) >= 0)
            i++;
        return "finger-" + i;
    }

    // The daemon relays the Android HAL acquisition feedback verbatim
    function acquisitionHint(info) {
        if (info === "FPACQUIRED_GOOD") return "Good scan";
        if (info === "FPACQUIRED_PARTIAL") return "Partial print, try again";
        if (info === "FPACQUIRED_INSUFFICIENT") return "Press more firmly";
        if (info === "FPACQUIRED_IMAGER_DIRTY") return "Sensor dirty";
        if (info === "FPACQUIRED_TOO_SLOW") return "Too slow";
        if (info === "FPACQUIRED_TOO_FAST") return "Too fast";
        return "";
    }

    function startEnroll() {
        var name = enrollNameField.text !== "" ? enrollNameField.text
                                               : nextFingerName();

        enrolling = true;
        enrollProgress = 0;
        enrollHint = "";
        enrollResult = "";

        _enrollCall = luna.subscribe("luna://com.webos.service.fingerprint/enroll",
                                     JSON.stringify({"finger": name, "subscribe": true}),
                                     onEnrollMessage, onEnrollError);
    }

    function onEnrollMessage(message) {
        var response = JSON.parse(message.payload);

        if (response.returnValue === false) {
            _endEnroll();
            enrollResult = "Enrollment failed: " +
                           (response.errorText !== undefined ? response.errorText : "unknown error");
            return;
        }

        if (response.progress !== undefined)
            enrollProgress = response.progress;

        if (response.acquisitionInfo !== undefined)
            enrollHint = acquisitionHint(response.acquisitionInfo);

        if (response.finished === true) {
            _endEnroll();
            enrollResult = response.errorText !== undefined
                           ? ("Enrollment failed: " + response.errorText)
                           : "Fingerprint added.";
            if (response.errorText === undefined)
                enrollNameField.text = "";
        }
    }

    function onEnrollError(message) {
        _endEnroll();
        enrollResult = "Enrollment failed: " + message;
    }

    function _endEnroll() {
        enrolling = false;
        if (_enrollCall) {
            _enrollCall.cancel();
            _enrollCall = null;
        }
    }

    function cancelEnroll() {
        luna.call("luna://com.webos.service.fingerprint/abort", "{}",
                  _handleSetSuccess, _handleSetError);
        _endEnroll();
        enrollResult = "";
    }

    function removeFinger(name) {
        luna.call("luna://com.webos.service.fingerprint/remove",
                  JSON.stringify({"finger": name}),
                  _handleMutationDone, _handleSetError);
    }

    function renameFinger(oldName, newName) {
        if (newName === "" || newName === oldName)
            return;
        luna.call("luna://com.webos.service.fingerprint/rename",
                  JSON.stringify({"finger": oldName, "newName": newName}),
                  _handleMutationDone, _handleSetError);
    }

    function _handleMutationDone(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            console.warn("Fingerprint operation failed: " + message.payload);
            return;
        }
        // The daemon persisted the change; pull the fresh list right away
        // rather than waiting on the subscription.
        refreshStatus();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.bottomMargin: fingerprintPageId.editingIndex >= 0
                              ? Qt.inputMethod.keyboardRectangle.height : 0
        spacing: Units.gu(1)

        Behavior on anchors.bottomMargin { NumberAnimation { duration: 150 } }

        Label {
            Layout.fillWidth: true
            visible: !fingerprintPageId.sensorAvailable
            wrapMode: Text.WordWrap
            text: "No fingerprint sensor was found on this device, or the " +
                  "fingerprint daemon is not running."
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        // "Add a fingerprint" is kept at the top so its name field never ends
        // up hidden behind the virtual keyboard.
        GroupBox {
            Layout.fillWidth: true
            visible: fingerprintPageId.sensorAvailable

            title: "Add a fingerprint"

            ColumnLayout {
                anchors.fill: parent

                Label {
                    Layout.fillWidth: true
                    visible: !fingerprintPageId.enrolling &&
                             fingerprintPageId.fingerprints.length >= fingerprintPageId.maxFingerprints
                    wrapMode: Text.WordWrap
                    text: "The sensor can store at most " +
                          fingerprintPageId.maxFingerprints + " fingerprints. " +
                          "Remove one before adding another."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)
                    visible: !fingerprintPageId.enrolling &&
                             fingerprintPageId.fingerprints.length < fingerprintPageId.maxFingerprints

                    TextField {
                        id: enrollNameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: Units.gu(5.5)
                        placeholderText: fingerprintPageId.nextFingerName()
                    }

                    Button {
                        text: "Add"
                        Layout.preferredHeight: Units.gu(5.5)
                        Layout.preferredWidth: Units.gu(20)
                        onClicked: fingerprintPageId.startEnroll()
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: fingerprintPageId.enrolling

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Touch the sensor repeatedly, moving your finger " +
                              "slightly between touches."
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: fingerprintPageId.enrollProgress
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: fingerprintPageId.enrollHint
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        Button {
                            text: "Cancel"
                            enabled: !cancelGuard.running
                            Layout.preferredHeight: Units.gu(5.5)
                            Layout.preferredWidth: Units.gu(20)
                            onClicked: fingerprintPageId.cancelEnroll()
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: fingerprintPageId.enrollResult !== ""
                    wrapMode: Text.WordWrap
                    text: fingerprintPageId.enrollResult
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: fingerprintPageId.sensorAvailable

            title: "Fingerprints"

            ColumnLayout {
                anchors.fill: parent

                Label {
                    Layout.fillWidth: true
                    visible: fingerprintPageId.fingerprints.length === 0
                    wrapMode: Text.WordWrap
                    text: "No fingerprints are enrolled yet. Enrolled " +
                          "fingerprints unlock the device from the lock screen."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ListView {
                    id: listView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: fingerprintPageId.fingerprints.length > 0
                    clip: true

                    model: fingerprintPageId.fingerprints

                    // A small finger drag while pressing the Remove button used to
                    // be interpreted as a list flick, cancelling the click - keep
                    // the list from stealing presses unless it actually needs to
                    // scroll.
                    interactive: contentHeight > height

                    delegate: Item {
                        id: fingerRow
                        width: ListView.view.width
                        height: Units.gu(7)

                        property bool pendingDelete: false
                        readonly property bool editing: fingerprintPageId.editingIndex === index

                        // Normal row: the name, tappable to rename in place.
                        Item {
                            anchors.fill: parent
                            visible: !fingerRow.pendingDelete

                            Text {
                                id: nameLabel
                                visible: !fingerRow.editing
                                anchors.left: parent.left
                                anchors.leftMargin: Units.gu(1)
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                color: "#333333"
                                font.pixelSize: FontUtils.sizeToPixels("medium")
                                text: modelData
                            }

                            TextField {
                                id: nameField
                                visible: fingerRow.editing
                                anchors.left: parent.left
                                anchors.leftMargin: Units.gu(1)
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter
                                height: Units.gu(5)
                                leftPadding: Units.gu(1)
                                rightPadding: Units.gu(1)
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#2a2929"
                                font.pixelSize: FontUtils.sizeToPixels("medium")
                                // A clearly visible white field while editing,
                                // styled after the phone app's SearchField.
                                background: Rectangle {
                                    color: "#ffffff"
                                    radius: Units.gu(0.6)
                                    border.color: "#9a9a9a"
                                    border.width: 1
                                }

                                // Bound to the stored name so the field always
                                // shows the current value, even when a list
                                // refresh recreates the delegate mid-session (a
                                // plain one-off assignment left a blank field).
                                text: modelData
                                property string _committedText: ""

                                onEditingFinished: _fpCommit()
                                onAccepted: { _fpCommit(); fingerprintPageId.editingIndex = -1; }
                                // The virtual keyboard delivers Enter as a key
                                // event, not the accepted()/editingFinished()
                                // signals, so handle it explicitly too.
                                Keys.onReturnPressed: { _fpCommit(); fingerprintPageId.editingIndex = -1; }
                                Keys.onEnterPressed: { _fpCommit(); fingerprintPageId.editingIndex = -1; }
                                onActiveFocusChanged: {
                                    if (activeFocus) {
                                        _committedText = "";
                                    } else {
                                        _fpCommit();
                                        // typing broke the binding above; restore
                                        // it so the field re-syncs to the name
                                        text = Qt.binding(function() { return modelData; });
                                    }
                                }

                                // Commit whenever the text actually changed,
                                // regardless of which row is now active: tapping
                                // another row moves editingIndex before this
                                // field's focus-out fires, so guarding on it would
                                // drop the edit. _committedText de-dupes the
                                // editingFinished + focus-out double fire.
                                function _fpCommit() {
                                    if (text !== "" && text !== modelData && text !== _committedText) {
                                        _committedText = text;
                                        fingerprintPageId.renameFinger(modelData, text);
                                    }
                                    if (fingerprintPageId.editingIndex === index)
                                        fingerprintPageId.editingIndex = -1;
                                }
                            }

                            // Tap the name to edit it; swipe the row sideways to
                            // ask for delete confirmation (webOS delete gesture).
                            MouseArea {
                                anchors.fill: parent
                                enabled: !fingerRow.editing

                                property real _pressX: 0

                                onPressed: (mouse) => { _pressX = mouse.x; }
                                onReleased: (mouse) => {
                                    if (Math.abs(mouse.x - _pressX) > Units.gu(4)) {
                                        fingerRow.pendingDelete = true;
                                    } else {
                                        fingerprintPageId.editingIndex = index;
                                        listView.positionViewAtIndex(index, ListView.Contain);
                                        nameField.forceActiveFocus();
                                    }
                                }
                            }
                        }

                        // Delete confirmation: Cancel (grey) + Delete (red),
                        // centred, matching the legacy webOS swipe-to-delete.
                        Row {
                            anchors.centerIn: parent
                            spacing: Units.gu(2)
                            visible: fingerRow.pendingDelete

                            Button {
                                text: "Cancel"
                                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                onClicked: fingerRow.pendingDelete = false
                            }

                            Button {
                                text: "Delete"
                                LuneOSButton.mainColor: "#be0003"
                                LuneOSButton.textColor: "white"
                                onClicked: {
                                    fingerprintPageId.removeFinger(modelData);
                                    fingerRow.pendingDelete = false;
                                }
                            }
                        }

                        // Separator between rows, as in the other settings lists.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: "#b0b0b0"
                        }
                    }
                }
            }
        }
    }
}
