/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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

import "../Common"
import LuneOS.Forms 1.0
import LuneOS.System 1.0

/*
 * Developer Mode, after the webOS 3.0.5 app of the same name
 * (com.palm.app.devmodeswitcher).
 *
 * Until now this page was still the ExamplePage template it was copied from
 * in 2017 - it shipped as a launcher entry offering "Hourly Coffee" and
 * "Search in Wikipedia" against no service at all - while
 * org.webosports.service.devmode, which is what actually turns developer mode
 * on, had no UI anywhere.
 *
 * That service has two switches, and this page is those two switches and
 * the ways in they open:
 *  - getStatus returns "status" and "usbDebugging", each "enabled" or
 *    "disabled".
 *  - setStatus takes either or both. "status" writes or removes
 *    /var/luna/dev-mode-enabled; "usbDebugging" writes or removes
 *    /var/usb-debugging-enabled and starts or stops android-tools-adbd with
 *    it. Turning developer mode off stops adbd too, which is why the switch
 *    below follows it down.
 *  - adbd lets a computer in only once the user said so: the shell asks
 *    ("Allow USB debugging?"), and revokeAdbKeys forgets every computer
 *    allowed "always".
 *  - ssh lets root in with a key (add/remove/listAuthorizedKeys keep root's
 *    authorized_keys), and with root's password only over the local link:
 *    the USB network, or an emulator's NAT (meta-luneos' luneos_image).
 *    sshOverWifi opens port 22 on Wi-Fi as well as USB. setDevPassword sets
 *    root's password, clearDevPassword takes it away again ("*"), and
 *    getAccessStatus says which of these are set. Setting a password, adding
 *    a key and opening Wi-Fi need developer mode on; taking away does not.
 *
 * Only this app may call those (devmode-service.management, in the
 * service's ACG). The password is typed twice, handed to the service and
 * not kept: both fields are emptied once it is sent, and it is never logged.
 * Removing the password asks first, as Revoke does; a key is removed
 * as a fingerprint is, by swiping its row and then Delete.
 *
 * The reply is not trusted for the result. setStatus builds its returnValue
 * from a "success" flag that the usbDebugging path only sets inside an
 * asynchronous fs callback, after the reply has already been composed - so a
 * change that worked can still answer false. Every change is followed by a
 * fresh getStatus, and that is what the switches are drawn from.
 *
 * The legacy app's "Change Password" row was novacom's password; there is
 * no novacom here, and the password below is root's, for logging in on the
 * device itself and over the USB cable.
 */
BasePage {
    id: pageRoot

    property bool serviceAvailable: false
    property bool devModeEnabled: false
    property bool usbDebuggingEnabled: false
    property bool passwordSet: false
    property bool sshOverWifiEnabled: false
    // [{type, fingerprint, comment}], from listAuthorizedKeys.
    property var authorizedKeys: []
    // The service's word on the last password or key that did not take,
    // and what the last one that did take did.
    property string passwordError: ""
    property string passwordMessage: ""
    property string keyError: ""
    property string keyMessage: ""
    property string adbMessage: ""

    readonly property string devmodeService: "luna://org.webosports.service.devmode"

    Component.onCompleted: retrieveProperties();

    // Asked again whenever the service comes (back) on the bus: one that
    // starts after the page opened, or restarts, makes it live without "Try
    // again". The first call stays above - an on-demand service is only
    // started by being called.
    ServiceStatus {
        id: serviceStatus

        property bool wentAway: false

        serviceName: "org.webosports.service.devmode"
        onKnownChanged: if (known && !available) wentAway = true
        onAvailableChanged: {
            if (!available) {
                wentAway = true;
                pageRoot.serviceAvailable = false;
            } else if (wentAway) {
                wentAway = false;
                pageRoot.retrieveProperties();
            }
        }
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable
            serviceName: "org.webosports.service.devmode"
            description: "Developer mode is turned on and off by this service, " +
                         "so nothing here can be changed until it answers."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: devModeSwitch
                    label: "Developer Mode"

                    checked: pageRoot.devModeEnabled
                    Connections {
                        target: pageRoot
                        function onDevModeEnabledChanged() {
                            devModeSwitch.checked = pageRoot.devModeEnabled;
                        }
                    }
                    onToggled: pageRoot.setDevMode(checked)
                }
            }
        }

        ExplanationText {
            text: "Developer mode marks the device as one that is being " +
                  "worked on. It is what the developer tools look for before " +
                  "they will do anything to it."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Debugging"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: usbDebuggingSwitch
                    label: "USB Debugging"
                    // adbd is started by the same service and stopped again
                    // when developer mode goes off, so there is nothing to
                    // turn on while that is off.
                    enabled: pageRoot.devModeEnabled

                    checked: pageRoot.usbDebuggingEnabled
                    Connections {
                        target: pageRoot
                        function onUsbDebuggingEnabledChanged() {
                            usbDebuggingSwitch.checked = pageRoot.usbDebuggingEnabled;
                        }
                    }
                    onToggled: pageRoot.setUsbDebugging(checked)
                }
            }
        }

        ExplanationText {
            text: pageRoot.devModeEnabled
                  ? "USB Debugging runs adbd, so a computer connected by USB " +
                    "can use adb once you allow it on this screen. ssh does " +
                    "not need it: it listens while Developer Mode is on."
                  : "Turn Developer Mode on first. USB Debugging is stopped " +
                    "with it."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            Column {
                width: parent.width
                spacing: Units.gu(1)

                // Red, as the Revoke in the popup it opens and as the
                // app's other ways to throw something away (PrintManager's
                // Cancel All). It only asks: forgetting every computer is
                // one stray tap away otherwise (a drag to scroll the page
                // starts on it), and nothing would say it happened. No
                // focus either, so a Space from a keyboard cannot press it
                // again.
                Button {
                    objectName: "revokeAdbKeys"
                    width: parent.width
                    focusPolicy: Qt.NoFocus
                    text: "Revoke USB Debugging Authorizations"
                    LuneOSButton.mainColor: LuneOSButton.negativeColor
                    onClicked: revokeDialog.open()
                }
            }
        }

        ExplanationText {
            text: pageRoot.adbMessage !== ""
                  ? pageRoot.adbMessage
                  : "A computer is let in over USB only once you allow it on " +
                    "this screen. This forgets every computer allowed " +
                    "\"always\", so each one is asked about again."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "SSH"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                LabelAndSwitch {
                    id: sshOverWifiSwitch
                    objectName: "sshOverWifi"
                    label: "SSH over Wi-Fi"
                    // Turning it off is always allowed: developer mode
                    // going off turns it off in the service as well.
                    enabled: pageRoot.devModeEnabled || pageRoot.sshOverWifiEnabled

                    checked: pageRoot.sshOverWifiEnabled
                    Connections {
                        target: pageRoot
                        function onSshOverWifiEnabledChanged() {
                            sshOverWifiSwitch.checked = pageRoot.sshOverWifiEnabled;
                        }
                    }
                    onToggled: pageRoot.setSshOverWifi(checked)
                }

            }
        }

        ExplanationText {
            text: pageRoot.devModeEnabled
                  ? "ssh answers over the USB cable, and on Wi-Fi as well " +
                    "while SSH over Wi-Fi is on."
                  : "Turn Developer Mode on first to set a password, add a " +
                    "key or open SSH to Wi-Fi."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Root's Password"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Label {
                    objectName: "passwordState"
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: pageRoot.passwordSet ? "A password is set" : "No password set"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                }

                FormTextField {
                    id: passwordField
                    objectName: "devPassword"
                    width: parent.width
                    height: Units.gu(5)
                    enabled: pageRoot.devModeEnabled
                    echoMode: showPasswordSwitch.checked ? TextInput.Normal : TextInput.Password
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData
                    placeholderText: pageRoot.passwordSet ? "New password, 8 characters or more"
                                                          : "Password, 8 characters or more"
                    acceptable: text.length === 0 || pageRoot.passwordAcceptable(text)
                    onAccepted: passwordConfirmField.forceActiveFocus()
                }

                FormTextField {
                    id: passwordConfirmField
                    objectName: "devPasswordConfirm"
                    width: parent.width
                    height: Units.gu(5)
                    enabled: pageRoot.devModeEnabled
                    echoMode: passwordField.echoMode
                    inputMethodHints: passwordField.inputMethodHints
                    placeholderText: "The same again"
                    acceptable: text.length === 0 || text === passwordField.text
                    onAccepted: if (setPasswordButton.enabled) setPasswordButton.clicked()
                }

                LabelAndSwitch {
                    id: showPasswordSwitch
                    objectName: "showPassword"
                    label: "Show Password"
                    enabled: pageRoot.devModeEnabled
                    checked: false
                }

                Row {
                    spacing: Units.gu(1)

                    Button {
                        id: setPasswordButton
                        objectName: "setDevPassword"
                        text: pageRoot.passwordSet ? "Change" : "Set"
                        enabled: pageRoot.devModeEnabled &&
                                 pageRoot.passwordAcceptable(passwordField.text) &&
                                 passwordConfirmField.text === passwordField.text
                        onClicked: pageRoot.setPassword(passwordField, passwordConfirmField)
                    }

                    // Taking away needs no developer mode, as in the service.
                    Button {
                        objectName: "removeDevPassword"
                        visible: pageRoot.passwordSet
                        focusPolicy: Qt.NoFocus
                        text: "Remove"
                        LuneOSButton.mainColor: LuneOSButton.negativeColor
                        onClicked: removePasswordDialog.open()
                    }
                }

                Label {
                    objectName: "passwordFeedback"
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.WordWrap
                    textFormat: Text.PlainText
                    text: pageRoot.passwordError !== "" ? pageRoot.passwordError
                        : pageRoot.passwordMismatch(passwordField.text, passwordConfirmField.text)
                          ? "The two passwords are not the same."
                        : pageRoot.passwordMessage
                    color: pageRoot.passwordError !== "" ||
                           pageRoot.passwordMismatch(passwordField.text, passwordConfirmField.text)
                           ? Colors.error : Colors.secondaryText
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
        }

        ExplanationText {
            objectName: "passwordHelp"
            text: "Root's password is for logging in on the device itself, " +
                  "such as on a serial console, and over ssh on the USB " +
                  "cable only (on an emulator, through its NAT). Over Wi-Fi, " +
                  "ssh takes a key only."
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Authorized Keys"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Label {
                    width: parent.width
                    visible: pageRoot.authorizedKeys.length === 0
                    wrapMode: Text.WordWrap
                    text: "No keys."
                    color: Colors.secondaryText
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }

                Repeater {
                    model: pageRoot.authorizedKeys

                    // As FingerprintPage's rows: swipe a row sideways to ask,
                    // then Cancel (grey) or Delete (red) in its place - the
                    // webOS delete gesture, with no button on every row.
                    delegate: Item {
                        id: keyRow
                        objectName: "keyRow-" + keyRow.key.fingerprint
                        width: parent.width
                        height: Units.gu(8)

                        readonly property var key: modelData
                        property bool pendingDelete: false

                        // The row slides out of its own band, not over its
                        // neighbours.
                        clip: true

                        // Normal row: comment, type and fingerprint. It follows
                        // the pointer sideways while the row is held, then on
                        // release slides out of the way of Cancel and Delete
                        // or back home, with the LuneOS style's SwipeDelegate
                        // motion; without that a drag showed nothing at all
                        // until it was let go past the threshold.
                        Item {
                            id: keyContent
                            objectName: "keyContent-" + keyRow.key.fingerprint
                            width: parent.width
                            height: parent.height

                            // Not keySwipe.pressed: MouseArea sends released
                            // before it clears pressed, and the row jumped.
                            Behavior on x {
                                enabled: !keySwipe.tracking
                                NumberAnimation {
                                    easing.type: Easing.OutExpo
                                    duration: 400
                                }
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: Units.gu(1)
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter

                                Text {
                                    objectName: "keyComment-" + keyRow.key.fingerprint
                                    width: parent.width
                                    text: keyRow.key.comment || "No comment"
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: "#333333"
                                    font.pixelSize: FontUtils.sizeToPixels("medium")
                                }
                                Text {
                                    objectName: "keyType-" + keyRow.key.fingerprint
                                    width: parent.width
                                    text: keyRow.key.type
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: Colors.secondaryText
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                                Text {
                                    objectName: "keyFingerprint-" + keyRow.key.fingerprint
                                    width: parent.width
                                    text: keyRow.key.fingerprint
                                    textFormat: Text.PlainText
                                    elide: Text.ElideMiddle
                                    color: Colors.secondaryText
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                            }
                        }

                        // Sideways by more than 4 gu asks; a tap does
                        // nothing (FingerprintPage's tap renames; a key
                        // has nothing to rename). On the row, not on what
                        // slides, so the pointer is measured from a place
                        // that stays put.
                        MouseArea {
                            id: keySwipe
                            objectName: "keySwipe-" + keyRow.key.fingerprint
                            anchors.fill: parent
                            enabled: !keyRow.pendingDelete

                            property real _pressX: 0
                            property real _pressY: 0
                            // The row is under the pointer, not animated.
                            property bool tracking: false

                            // These rows sit straight in SettingsPageContent,
                            // a Flickable, not in a ListView as FingerprintPage's
                            // do. Left alone it takes the drag as soon as the
                            // hand drifts up or down a little, and the swipe is
                            // lost. As PrintManagerPage: keep the drag once it
                            // is more than 2 gu sideways and more sideways than
                            // up or down, so a drag up or down still scrolls.
                            onPressed: (mouse) => {
                                _pressX = mouse.x;
                                _pressY = mouse.y;
                                preventStealing = false;
                                tracking = true;
                            }
                            onPositionChanged: (mouse) => {
                                var dx = Math.abs(mouse.x - _pressX);
                                if (dx > Units.gu(2) && dx > Math.abs(mouse.y - _pressY))
                                    preventStealing = true;
                                keyContent.x = mouse.x - _pressX;
                            }
                            onReleased: (mouse) => {
                                var dx = mouse.x - _pressX;
                                preventStealing = false;
                                tracking = false;
                                if (Math.abs(dx) > Units.gu(4)) {
                                    keyRow.pendingDelete = true;
                                    keyContent.x = dx < 0 ? -keyRow.width : keyRow.width;
                                } else {
                                    keyContent.x = 0;
                                }
                            }
                            // The page took the drag (it scrolls): back home.
                            onCanceled: {
                                preventStealing = false;
                                tracking = false;
                                keyContent.x = 0;
                            }
                        }

                        // Delete confirmation: Cancel (grey) + Delete (red),
                        // centred, as on FingerprintPage.
                        Row {
                            anchors.centerIn: parent
                            spacing: Units.gu(2)
                            visible: keyRow.pendingDelete

                            Button {
                                objectName: "removeKeyCancel-" + keyRow.key.fingerprint
                                focusPolicy: Qt.NoFocus
                                text: "Cancel"
                                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                onClicked: {
                                    keyRow.pendingDelete = false;
                                    keyContent.x = 0;
                                }
                            }

                            Button {
                                objectName: "removeKeyConfirm-" + keyRow.key.fingerprint
                                focusPolicy: Qt.NoFocus
                                text: "Delete"
                                LuneOSButton.mainColor: LuneOSButton.negativeColor
                                LuneOSButton.textColor: "white"
                                onClicked: {
                                    keyRow.pendingDelete = false;
                                    // Home again should the service keep it.
                                    keyContent.x = 0;
                                    pageRoot.removeAuthorizedKey(keyRow.key.fingerprint);
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

                Row {
                    width: parent.width
                    spacing: Units.gu(1)

                    FormTextField {
                        id: keyField
                        objectName: "authorizedKey"
                        width: parent.width - addKeyButton.width - parent.spacing
                        height: Units.gu(5)
                        enabled: pageRoot.devModeEnabled
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                        placeholderText: "ssh-ed25519 AAAA... you@computer"
                        onAccepted: if (addKeyButton.enabled) addKeyButton.clicked()
                    }

                    Button {
                        id: addKeyButton
                        objectName: "addAuthorizedKey"
                        text: "Add"
                        enabled: pageRoot.devModeEnabled && keyField.text.trim() !== ""
                        onClicked: pageRoot.addAuthorizedKey(keyField)
                    }
                }

                Label {
                    objectName: "keyFeedback"
                    width: parent.width
                    visible: text !== ""
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                    text: pageRoot.keyError !== "" ? pageRoot.keyError : pageRoot.keyMessage
                    color: pageRoot.keyError !== "" ? Colors.error : Colors.secondaryText
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
        }

        ExplanationText {
            objectName: "keyHelp"
            text: "ssh lets root in with a key listed here. Paste a public " +
                  "key (the contents of ~/.ssh/id_ed25519.pub), or, from a " +
                  "computer USB Debugging lets in: " +
                  "adb shell luneos-ssh-addkey < ~/.ssh/id_ed25519.pub"
        }
    }

    // Asked first, as Revoke: it takes away a way in the user set up, and
    // a stray tap should not.
    Popup {
        id: removePasswordDialog
        objectName: "removeDevPasswordDialog"

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(40))

        ColumnLayout {
            width: parent.width
            spacing: Units.gu(1.5)

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Remove Root's Password"
                font.pixelSize: FontUtils.sizeToPixels("18pt")
                font.weight: Font.Bold
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: "Root will have no password: logging in on the " +
                      "device or over the USB cable will need a key again."
                font.pixelSize: FontUtils.sizeToPixels("medium")
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Units.gu(1)

                Button {
                    objectName: "removeDevPasswordCancel"
                    focusPolicy: Qt.NoFocus
                    text: "Cancel"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: removePasswordDialog.close()
                }
                Button {
                    objectName: "removeDevPasswordConfirm"
                    focusPolicy: Qt.NoFocus
                    text: "Remove"
                    LuneOSButton.mainColor: LuneOSButton.negativeColor
                    onClicked: {
                        removePasswordDialog.close();
                        pageRoot.clearPassword();
                    }
                }
            }
        }
    }

    // A Popup as LocationPage's "Clear My Location Data": the LuneOS
    // style has no Dialog of its own.
    Popup {
        id: revokeDialog
        objectName: "revokeAdbKeysDialog"

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(40))

        ColumnLayout {
            width: parent.width
            spacing: Units.gu(1.5)

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Revoke USB Debugging Authorizations"
                font.pixelSize: FontUtils.sizeToPixels("18pt")
                font.weight: Font.Bold
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: "Every computer allowed \"always\" will have to be " +
                      "allowed on this screen again before it can use adb."
                font.pixelSize: FontUtils.sizeToPixels("medium")
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Units.gu(1)

                Button {
                    objectName: "revokeAdbKeysCancel"
                    focusPolicy: Qt.NoFocus
                    text: "Cancel"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: revokeDialog.close()
                }
                Button {
                    objectName: "revokeAdbKeysConfirm"
                    focusPolicy: Qt.NoFocus
                    text: "Revoke"
                    LuneOSButton.mainColor: LuneOSButton.negativeColor
                    onClicked: {
                        revokeDialog.close();
                        pageRoot.revokeAdbKeys();
                    }
                }
            }
        }
    }

    /*
     * Bindings with the devmode service
     */
    function retrieveProperties() {
        luna.call("luna://org.webosports.service.devmode/getStatus", "{}",
                  _handleGetStatus, _handleServiceUnavailable);
    }

    function _handleGetStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.serviceAvailable = false;
            return;
        }

        pageRoot.devModeEnabled = response.status === "enabled";
        pageRoot.usbDebuggingEnabled = response.usbDebugging === "enabled";
        pageRoot.serviceAvailable = true;
        retrieveAccess();
    }

    function retrieveAccess() {
        luna.call(devmodeService + "/getAccessStatus", "{}", _handleAccessStatus, _handleAccessError);
        luna.call(devmodeService + "/listAuthorizedKeys", "{}", _handleKeys, _handleAccessError);
    }

    function _reply(message) {
        try {
            return JSON.parse(message.payload);
        } catch (e) {
            return null;
        }
    }

    function _handleAccessStatus(message) {
        var response = _reply(message);
        if (!response || !response.returnValue)
            return;
        pageRoot.passwordSet = response.passwordSet === true;
        pageRoot.sshOverWifiEnabled = response.sshOverWifi === true;
    }

    function _handleKeys(message) {
        var response = _reply(message);
        if (!response || !response.returnValue || !Array.isArray(response.keys))
            return;
        pageRoot.authorizedKeys = response.keys;
    }

    function _handleAccessError(message) {
        console.warn("Developer mode service: " + (message && message.payload));
    }

    // What the service takes: 8 to 512 characters, on one line.
    function passwordAcceptable(text) {
        return text.length >= 8 && text.length <= 512 && !/[\0\r\n]/.test(text);
    }

    // Two passwords typed that differ; nothing to say while one is empty.
    function passwordMismatch(text, confirm) {
        return text !== "" && confirm !== "" && text !== confirm;
    }

    // The fields, not their text: they are emptied here, whatever the
    // answer, so the password does not stay on screen or in the page.
    function setPassword(field, confirmField) {
        var password = field.text;
        var confirm = confirmField.text;
        field.text = "";
        confirmField.text = "";
        pageRoot.passwordError = "";
        pageRoot.passwordMessage = "";
        if (password !== confirm) {
            pageRoot.passwordError = "The two passwords were not the same, so nothing was changed.";
            return;
        }
        if (!passwordAcceptable(password))
            return;
        var changed = pageRoot.passwordSet;
        luna.call(devmodeService + "/setDevPassword", JSON.stringify({"password": password}),
                  function (message) {
                      var response = _reply(message);
                      if (response && response.returnValue) {
                          pageRoot.passwordSet = true;
                          pageRoot.passwordMessage = changed ? "The password was changed." : "The password is set.";
                      } else {
                          pageRoot.passwordError = (response && response.errorText) || "The password was not set.";
                      }
                      retrieveAccess();
                  },
                  function (message) {
                      // Not the message: it is the call, password and all.
                      pageRoot.passwordError = "The password was not set.";
                  });
    }

    function clearPassword() {
        pageRoot.passwordError = "";
        pageRoot.passwordMessage = "";
        luna.call(devmodeService + "/clearDevPassword", "{}",
                  function (message) {
                      var response = _reply(message);
                      if (response && response.returnValue) {
                          pageRoot.passwordSet = false;
                          pageRoot.passwordMessage = "The password was removed.";
                      } else {
                          pageRoot.passwordError = (response && response.errorText) || "The password was not removed.";
                      }
                      retrieveAccess();
                  },
                  function (message) {
                      pageRoot.passwordError = "The password was not removed.";
                  });
    }

    function addAuthorizedKey(field) {
        var key = field.text.trim();
        pageRoot.keyError = "";
        pageRoot.keyMessage = "";
        if (key === "")
            return;
        luna.call(devmodeService + "/addAuthorizedKey", JSON.stringify({"key": key}),
                  function (message) {
                      var response = _reply(message);
                      if (response && response.returnValue) {
                          field.text = "";
                          pageRoot.keyMessage = response.added === false
                              ? "This key is already authorized: " + response.fingerprint
                              : "Key added: " + response.fingerprint;
                      } else {
                          pageRoot.keyError = "The key was not added: " +
                              ((response && response.errorText) || "the service did not say why") + ".";
                      }
                      retrieveAccess();
                  },
                  function (message) {
                      pageRoot.keyError = "The key was not added.";
                  });
    }

    // Asked first: a swipe on the key's row, then its Delete.
    function removeAuthorizedKey(fingerprint) {
        pageRoot.keyError = "";
        pageRoot.keyMessage = "";
        luna.call(devmodeService + "/removeAuthorizedKey", JSON.stringify({"fingerprint": fingerprint}),
                  function (message) {
                      var response = _reply(message);
                      if (response && response.returnValue)
                          pageRoot.keyMessage = "Key removed: " + fingerprint;
                      else
                          pageRoot.keyError = (response && response.errorText) || "The key was not removed.";
                      retrieveAccess();
                  },
                  function (message) {
                      pageRoot.keyError = "The key was not removed.";
                      retrieveAccess();
                  });
    }

    function setSshOverWifi(on) {
        pageRoot.sshOverWifiEnabled = on;
        luna.call(devmodeService + "/sshOverWifi", JSON.stringify({"enabled": on}),
                  function (message) { retrieveAccess(); },
                  function (message) {
                      _handleAccessError(message);
                      retrieveAccess();
                  });
    }

    function revokeAdbKeys() {
        luna.call(devmodeService + "/revokeAdbKeys", "{}",
                  function (message) {
                      var response = _reply(message);
                      pageRoot.adbMessage = response && response.returnValue
                          ? "Every computer will be asked about again."
                          : "The authorizations could not be revoked.";
                  },
                  function (message) {
                      pageRoot.adbMessage = "The authorizations could not be revoked.";
                  });
    }

    function _handleServiceUnavailable(message) {
        console.warn("Developer mode service did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    function setDevMode(on) {
        // Turning developer mode off stops adbd in the service, so show that
        // here straight away rather than leaving a switch on for the second
        // it takes getStatus to come back and say otherwise.
        pageRoot.devModeEnabled = on;
        if (!on)
            pageRoot.usbDebuggingEnabled = false;

        _setStatus({"status": on ? "enabled" : "disabled"});
    }

    function setUsbDebugging(on) {
        pageRoot.usbDebuggingEnabled = on;
        _setStatus({"usbDebugging": on ? "enabled" : "disabled"});
    }

    function _setStatus(params) {
        luna.call("luna://org.webosports.service.devmode/setStatus",
                  JSON.stringify(params),
                  _handleSetStatus, _handleSetStatusError);
    }

    function _handleSetStatus(message) {
        // See the file header: returnValue is not reliable for the
        // usbDebugging path, so ask what the state actually is.
        retrieveProperties();
    }

    function _handleSetStatusError(message) {
        console.warn("Cannot change developer mode: " + message);
        retrieveProperties();
    }
}
