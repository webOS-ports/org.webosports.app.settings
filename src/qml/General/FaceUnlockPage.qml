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
    id: faceUnlockPageId

    // Mirrors com.webos.service.faceunlock/getStatus
    property bool cameraAvailable: false
    property bool faceEnrolled: false
    property string serviceState: ""

    // libfart holds exactly one enrolled face, so there is no list and no
    // rename - enrolling again replaces what is there.
    property bool enrolling: false
    property int enrollProgress: 0
    property string enrollHint: ""
    property string enrollResult: ""
    property var _enrollCall: null

    Component.onCompleted: subscribeStatus();

    // The Cancel button appears exactly where Set up sat, so the second half of
    // a double-tap would abort the enrollment it just started.
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
        onTriggered: faceUnlockPageId.subscribeStatus()
    }

    function subscribeStatus() {
        luna.subscribe("luna://com.webos.service.faceunlock/getStatus",
                       JSON.stringify({"subscribe": true}),
                       onStatusChanged, _handleStatusError);
    }

    function refreshStatus() {
        luna.call("luna://com.webos.service.faceunlock/getStatus", "{}",
                  onStatusChanged, _handleStatusError);
    }

    function onStatusChanged(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue) {
            // daemon restarted; re-subscribe so the panel recovers on its own
            statusRetry.restart();
            return;
        }

        cameraAvailable = response.available === true;
        faceEnrolled = response.enrolled === true;
        serviceState = response.state !== undefined ? response.state : "";
    }

    function _handleStatusError(message) {
        console.warn("Face unlock getStatus error: " + message);
        statusRetry.restart();
    }

    // luneos-faced relays libfart's per-frame enrollment state
    function enrollmentHint(hint) {
        if (hint === "noFace") return "No face detected - look at the screen";
        if (hint === "multipleFaces") return "More than one face in view";
        if (hint === "badLighting") return "Too dark - find brighter light";
        if (hint === "ok") return "Hold still";
        return "";
    }

    function startEnroll() {
        enrolling = true;
        enrollProgress = 0;
        enrollHint = "";
        enrollResult = "";

        _enrollCall = luna.subscribe("luna://com.webos.service.faceunlock/enroll",
                                     JSON.stringify({"subscribe": true}),
                                     onEnrollMessage, onEnrollError);
    }

    function onEnrollMessage(message) {
        var response = JSON.parse(message.payload);

        if (response.returnValue === false) {
            _endEnroll();
            enrollResult = "Enrollment failed: " +
                           (response.errorText !== undefined ? response.errorText
                                                             : "unknown error");
            return;
        }

        if (response.progress !== undefined)
            enrollProgress = response.progress;

        if (response.hint !== undefined)
            enrollHint = enrollmentHint(response.hint);

        if (response.completed === true) {
            _endEnroll();
            enrollResult = "Face saved.";
            refreshStatus();
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
        luna.call("luna://com.webos.service.faceunlock/abort", "{}", null, null);
        _endEnroll();
        enrollResult = "";
    }

    function clearFace() {
        luna.call("luna://com.webos.service.faceunlock/clear", "{}",
                  _handleMutationDone, _handleMutationError);
    }

    function _handleMutationDone(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            console.warn("Face unlock operation failed: " + message.payload);
            return;
        }
        enrollResult = "";
        refreshStatus();
    }

    function _handleMutationError(message) {
        console.warn("Face unlock operation error: " + message);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            visible: !faceUnlockPageId.cameraAvailable
            wrapMode: Text.WordWrap
            text: "Face unlock is unavailable. The front camera could not be " +
                  "reached, or the face unlock service is not running."
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        GroupBox {
            Layout.fillWidth: true
            visible: faceUnlockPageId.cameraAvailable
            title: faceUnlockPageId.faceEnrolled ? "Your face" : "Set up face unlock"

            ColumnLayout {
                anchors.fill: parent

                Label {
                    Layout.fillWidth: true
                    visible: !faceUnlockPageId.enrolling
                    wrapMode: Text.WordWrap
                    text: faceUnlockPageId.faceEnrolled
                          ? "A face is enrolled on this device. Setting up again replaces it."
                          : "Hold the phone at arm's length, look at the screen and keep still."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                /*
                 * Centred and equally wide, the way every other pair of
                 * buttons in this application sits. A fixed gu(20) each was
                 * wider than the group box could hold on a phone, so the
                 * pair was pushed off the right edge by the spacer that was
                 * meant to align it; filling the width and capping it lets
                 * them shrink to whatever is there instead.
                 */
                RowLayout {
                    Layout.fillWidth: true
                    visible: !faceUnlockPageId.enrolling
                    spacing: Units.gu(1)

                    Item { Layout.fillWidth: true }

                    Button {
                        text: faceUnlockPageId.faceEnrolled ? "Set up again" : "Set up"
                        Layout.preferredHeight: Units.gu(5.5)
                        Layout.fillWidth: true
                        Layout.maximumWidth: Units.gu(20)
                        onClicked: faceUnlockPageId.startEnroll()
                    }

                    Button {
                        text: "Remove"
                        visible: faceUnlockPageId.faceEnrolled
                        // The red this application uses wherever something is
                        // about to be thrown away.
                        LuneOSButton.mainColor: "#be0003"
                        LuneOSButton.textColor: "white"
                        Layout.preferredHeight: Units.gu(5.5)
                        Layout.fillWidth: true
                        Layout.maximumWidth: Units.gu(20)
                        onClicked: faceUnlockPageId.clearFace()
                    }

                    Item { Layout.fillWidth: true }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    visible: faceUnlockPageId.enrolling

                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "Look at the screen."
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                    }

                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: 100
                        value: faceUnlockPageId.enrollProgress
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Units.gu(1)

                        Label {
                            Layout.fillWidth: true
                            text: faceUnlockPageId.enrollHint
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }

                        Button {
                            text: "Cancel"
                            enabled: !cancelGuard.running
                            Layout.preferredHeight: Units.gu(5.5)
                            Layout.preferredWidth: Units.gu(20)
                            Layout.maximumWidth: Units.gu(20)
                            onClicked: faceUnlockPageId.cancelEnroll()
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: faceUnlockPageId.enrollResult !== ""
                    wrapMode: Text.WordWrap
                    text: faceUnlockPageId.enrollResult
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
        }

        // Not boilerplate: with an RGB-only camera and no secure enclave this
        // really is weaker than the passcode, and saying so is the honest
        // equivalent of Android labelling it a "Convenience" biometric.
        GroupBox {
            Layout.fillWidth: true
            visible: faceUnlockPageId.cameraAvailable
            title: "How secure is this?"

            Label {
                anchors.fill: parent
                wrapMode: Text.WordWrap
                text: "Face unlock is less secure than your PIN or password. " +
                      "Someone who looks a lot like you may be able to unlock " +
                      "your phone, and a detailed photo or replica can " +
                      "sometimes fool it. It also needs reasonable light to " +
                      "work at all.\n\n" +
                      "Use it for convenience, not to protect anything " +
                      "sensitive. Your PIN is still required after a restart."
                font.pixelSize: FontUtils.sizeToPixels("small")
            }
        }

        Item { Layout.fillHeight: true }
    }
}
