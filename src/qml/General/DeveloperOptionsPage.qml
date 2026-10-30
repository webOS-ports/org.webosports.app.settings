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
 *  - ssh lets root in with a key only (PermitRootLogin prohibit-password):
 *    add/remove/listAuthorizedKeys keep root's authorized_keys, and
 *    sshOverWifi opens port 22 on Wi-Fi as well as USB. setDevPassword
 *    sets root's password, which is what a serial or local login takes. getAccessStatus says which of these are set. Setting a
 *    password, adding a key and opening Wi-Fi need developer mode on;
 *    taking away does not.
 *
 * Only this app may call those (devmode-service.management, in the
 * service's ACG). The password is handed to the service and not kept:
 * the field is emptied once it is sent, and it is never logged.
 *
 * The reply is not trusted for the result. setStatus builds its returnValue
 * from a "success" flag that the usbDebugging path only sets inside an
 * asynchronous fs callback, after the reply has already been composed - so a
 * change that worked can still answer false. Every change is followed by a
 * fresh getStatus, and that is what the switches are drawn from.
 *
 * The legacy app's "Change Password" row was novacom's password; there is
 * no novacom here, and the password below is root's, for logging in on the
 * device itself.
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
    // The service's word on the last password or key that did not take.
    property string passwordError: ""
    property string keyError: ""
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

                // The style's own colours, as Set and Add. It only asks:
                // forgetting every computer is one stray tap away
                // otherwise (a drag to scroll the page starts on it), and
                // nothing would say it happened. No focus either, so a
                // Space from a keyboard cannot press it again.
                Button {
                    objectName: "revokeAdbKeys"
                    width: parent.width
                    focusPolicy: Qt.NoFocus
                    text: "Revoke USB Debugging Authorizations"
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

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: pageRoot.passwordSet ? "Change root's password" : "Set root's password"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                }

                Row {
                    width: parent.width
                    spacing: Units.gu(1)

                    FormTextField {
                        id: passwordField
                        objectName: "devPassword"
                        width: parent.width - setPasswordButton.width - parent.spacing
                        height: Units.gu(5)
                        enabled: pageRoot.devModeEnabled
                        echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData
                        placeholderText: "8 characters or more"
                        acceptable: text.length === 0 || pageRoot.passwordAcceptable(text)
                        onAccepted: setPasswordButton.clicked()
                    }

                    Button {
                        id: setPasswordButton
                        objectName: "setDevPassword"
                        text: "Set"
                        enabled: pageRoot.devModeEnabled && pageRoot.passwordAcceptable(passwordField.text)
                        onClicked: pageRoot.setPassword(passwordField)
                    }
                }

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Authorized keys"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                }

                Label {
                    width: parent.width
                    visible: pageRoot.authorizedKeys.length === 0
                    wrapMode: Text.WordWrap
                    text: "No keys. ssh lets root in with a key listed " +
                          "here, never with a password."
                    color: Colors.secondaryText
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }

                Repeater {
                    model: pageRoot.authorizedKeys

                    delegate: Item {
                        id: keyRow
                        width: parent.width
                        height: Units.gu(6)

                        readonly property var key: modelData

                        Column {
                            anchors.left: parent.left
                            anchors.right: removeKeyButton.left
                            anchors.rightMargin: Units.gu(1)
                            anchors.verticalCenter: parent.verticalCenter

                            Label {
                                width: parent.width
                                text: keyRow.key.comment || keyRow.key.type
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                font.pixelSize: FontUtils.sizeToPixels("medium")
                            }
                            Label {
                                width: parent.width
                                text: keyRow.key.fingerprint
                                textFormat: Text.PlainText
                                elide: Text.ElideMiddle
                                color: Colors.secondaryText
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }

                        Button {
                            id: removeKeyButton
                            objectName: "removeKey-" + keyRow.key.fingerprint
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Remove"
                            LuneOSButton.mainColor: LuneOSButton.secondaryColor
                            onClicked: pageRoot.removeAuthorizedKey(keyRow.key.fingerprint)
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
                        onAccepted: addKeyButton.clicked()
                    }

                    Button {
                        id: addKeyButton
                        objectName: "addAuthorizedKey"
                        text: "Add"
                        enabled: pageRoot.devModeEnabled && keyField.text.trim() !== ""
                        onClicked: pageRoot.addAuthorizedKey(keyField)
                    }
                }
            }
        }

        ExplanationText {
            text: pageRoot.passwordError !== "" ? pageRoot.passwordError
                : pageRoot.keyError !== "" ? pageRoot.keyError
                : pageRoot.devModeEnabled
                  ? "ssh answers over the USB cable, and on Wi-Fi as well " +
                    "while SSH over Wi-Fi is on, and takes a key only: paste " +
                    "a public key (the contents of ~/.ssh/id_ed25519.pub) to " +
                    "log in as root with it. The password is for logging in " +
                    "on the device itself, such as on a serial console."
                  : "Turn Developer Mode on first to set a password, add a " +
                    "key or open SSH to Wi-Fi."
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

    // The field, not its text: it is emptied here, whatever the answer, so
    // the password does not stay on screen or in the page.
    function setPassword(field) {
        var password = field.text;
        field.text = "";
        pageRoot.passwordError = "";
        if (!passwordAcceptable(password))
            return;
        luna.call(devmodeService + "/setDevPassword", JSON.stringify({"password": password}),
                  function (message) {
                      var response = _reply(message);
                      if (response && response.returnValue) {
                          pageRoot.passwordSet = true;
                      } else {
                          pageRoot.passwordError = (response && response.errorText) || "The password was not set.";
                      }
                  },
                  function (message) {
                      // Not the message: it is the call, password and all.
                      pageRoot.passwordError = "The password was not set.";
                  });
    }

    function addAuthorizedKey(field) {
        var key = field.text.trim();
        pageRoot.keyError = "";
        if (key === "")
            return;
        luna.call(devmodeService + "/addAuthorizedKey", JSON.stringify({"key": key}),
                  function (message) {
                      var response = _reply(message);
                      if (response && response.returnValue) {
                          field.text = "";
                      } else {
                          pageRoot.keyError = (response && response.errorText) || "The key was not added.";
                      }
                      retrieveAccess();
                  },
                  function (message) {
                      pageRoot.keyError = "The key was not added.";
                  });
    }

    function removeAuthorizedKey(fingerprint) {
        pageRoot.keyError = "";
        luna.call(devmodeService + "/removeAuthorizedKey", JSON.stringify({"fingerprint": fingerprint}),
                  function (message) {
                      var response = _reply(message);
                      if (!response || !response.returnValue)
                          pageRoot.keyError = (response && response.errorText) || "The key was not removed.";
                      retrieveAccess();
                  },
                  _handleAccessError);
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
