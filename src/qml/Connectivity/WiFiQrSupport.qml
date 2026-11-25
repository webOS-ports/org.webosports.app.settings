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
// Connman
import Connman 0.2
// LS2 access
import LuneOS.Service 1.0
// WifiQrCode
import LuneOS.Components 1.0
// The passcode popup Screen & Lock and Fingerprint use
import "../General"

/*
 * Wi-Fi QR codes on the Wi-Fi page: joining a network from one, and showing
 * one for a saved network.
 *
 * Joining. The network is found in the list by its name - or, for a code
 * that says the network is hidden, as one of connman's nameless hidden
 * services of the same security - and connected the ordinary way. connman
 * then asks the page's agent for the passphrase (and a hidden network's
 * name), and answerUserInput() gives it the code's, once: if connman asks
 * again the code's passphrase was wrong, and the usual popup comes up. The
 * code's passphrase is only kept until then, or a minute at most.
 *
 * Sharing. connman never hands a passphrase out, so it comes from
 * com.webos.service.wifi/getPassphrase, which reads connman's storage. It
 * wants proof the passcode was just entered: the unlockToken
 * com.webos.service.auth/matchDevicePasscode gives for a right one, spent
 * by the wifi service (purpose "reveal"). Without a lock set there is
 * nothing to prove and no token is asked for, as on Android.
 */
Item {
    id: qrSupport

    // The page's TechnologyModel, UserAgent and LunaService. Plain vars, so
    // the tests can hand in stand-ins that answer what the real ones would.
    property var wifiModel: null
    property var agent: null
    property var luna: null

    // How long a code waits for its network to come into range.
    property int joinTimeout: 20000

    // A network from a code, waiting to be found in the list.
    property var pendingJoin: null
    // What to tell connman when it asks: {path, ssid, passphrase}.
    property var pendingAnswer: null
    // The saved network being shared, between the passcode and the answer.
    property NetworkService shareService: null

    readonly property alias scanPopup: scanPopupItem
    readonly property alias sharePopup: sharePopupItem
    readonly property alias passcodePopup: passcodePopupItem
    readonly property alias messagePopup: messagePopupItem

    // --- joining ------------------------------------------------------------

    function startScan() {
        scanPopupItem.open();
    }

    // A code's text from elsewhere: the Camera app hands over a WIFI: code
    // it read as the launch parameter "wifiQrCode".
    function joinCode(text) {
        var network = WifiQrCode.parse(text);
        if (!network.valid) {
            showMessage(scanPopupItem.problemText(network.error));
            return;
        }
        join(network);
    }

    function join(network) {
        pendingAnswer = null;
        pendingJoin = network;
        if (wifiModel && !wifiModel.powered)
            wifiModel.powered = true;
        joinGiveUp.restart();
        if (!tryJoin() && wifiModel && wifiModel.powered)
            wifiModel.requestScan();
    }

    // connman's security for what a code calls it. connman 2.0 reports WPA3
    // networks as psk too, so "sae" finds them there.
    function _securityType(security) {
        switch (security) {
        case "none": return NetworkService.SecurityNone;
        case "wep": return NetworkService.SecurityWEP;
        default: return NetworkService.SecurityPSK;
        }
    }

    function findService(network) {
        if (!wifiModel)
            return null;
        var hiddenMatch = null;
        for (var i = 0; i < wifiModel.count; ++i) {
            var service = wifiModel.get(i);
            if (!service)
                continue;
            if (service.name === network.ssid)
                return service;
            if (network.hidden && !hiddenMatch && service.hidden && service.name === ""
                    && service.securityType === _securityType(network.security))
                hiddenMatch = service;
        }
        return hiddenMatch;
    }

    // True once the network was found (and connected, or found connected).
    function tryJoin() {
        if (!pendingJoin)
            return false;
        var service = findService(pendingJoin);
        if (!service)
            return false;

        var network = pendingJoin;
        pendingJoin = null;
        joinGiveUp.stop();

        if (service.connected && service.name === network.ssid) {
            showMessage("Already connected to “" + network.ssid + "”.");
            return true;
        }
        pendingAnswer = { "path": service.path, "ssid": network.ssid,
                          "passphrase": network.passphrase };
        answerGiveUp.restart();
        // Saved and with the same passphrase, connman asks nothing and just
        // connects; otherwise it asks the agent, and answerUserInput() replies.
        service.requestConnect();
        return true;
    }

    /*
     * From the page's UserAgent: true when this was connman asking for the
     * network a code was scanned for, and it has been answered. Anything a
     * code cannot answer (an identity, WPS) is left to the popup.
     */
    function answerUserInput(servicePath, fields) {
        if (!pendingAnswer || pendingAnswer.path !== servicePath || !agent)
            return false;
        var reply = {};
        for (var field in fields) {
            // connman marks each field mandatory, alternate (WPS, offered
            // beside the passphrase by most home routers; SSID beside Name)
            // or informational (PreviousPassphrase). Only a mandatory one the
            // code cannot fill sends this to the popup.
            var requirement = fields[field] && fields[field]["Requirement"]
                              ? fields[field]["Requirement"] : "mandatory";
            if (field === "Passphrase" && pendingAnswer.passphrase !== "")
                reply["Passphrase"] = pendingAnswer.passphrase;
            else if (field === "Name")
                reply["Name"] = pendingAnswer.ssid;
            else if (requirement === "mandatory")
                return false;
        }
        if (Object.keys(reply).length === 0)
            return false;
        // Once: a second request for it means the code's passphrase was wrong.
        pendingAnswer = null;
        answerGiveUp.stop();
        agent.sendUserReply(reply);
        return true;
    }

    Connections {
        target: qrSupport.wifiModel
        ignoreUnknownSignals: true
        function onCountChanged() { qrSupport.tryJoin(); }
        function onPoweredChanged() {
            if (qrSupport.pendingJoin && qrSupport.wifiModel.powered)
                qrSupport.wifiModel.requestScan();
        }
    }

    Timer {
        id: joinGiveUp
        interval: qrSupport.joinTimeout
        onTriggered: {
            if (!qrSupport.pendingJoin)
                return;
            var ssid = qrSupport.pendingJoin.ssid;
            qrSupport.pendingJoin = null;
            qrSupport.showMessage("“" + ssid + "” was not found. Move closer to it and scan the code again.");
        }
    }

    Timer {
        id: answerGiveUp
        interval: 60000
        onTriggered: qrSupport.pendingAnswer = null
    }

    // --- sharing ------------------------------------------------------------

    // Whether a saved network can be shown as a code at all.
    function canShare(service) {
        return !!service && (service.saved || service.favorite)
               && service.securityType !== NetworkService.SecurityIEEE802
               && service.name !== "";
    }

    function share(service) {
        if (!canShare(service))
            return;
        // An open network has no secret, and no passcode to ask for.
        if (service.securityType === NetworkService.SecurityNone) {
            sharePopupItem.show({ "ssid": service.name, "security": "none",
                                  "passphrase": "", "hidden": service.hidden });
            return;
        }
        shareService = service;
        luna.call("luna://com.webos.service.auth/getDeviceLockMode", "{}",
                  _lockModeForShare, _shareAuthError);
    }

    function _lockModeForShare(message) {
        var response = JSON.parse(message.payload);
        var mode = response.returnValue && response.lockMode ? response.lockMode : "none";
        if (mode === "none") {
            _fetchPassphrase("");
            return;
        }
        passcodePopupItem.mode = "verify";
        passcodePopupItem.lockMode = mode;
        passcodePopupItem.open();
    }

    function _verifyForShare(passcode) {
        luna.call("luna://com.webos.service.auth/matchDevicePasscode",
                  JSON.stringify({ "passCode": passcode }),
                  _verifiedForShare, _shareAuthError);
    }

    function _verifiedForShare(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue || !response.unlockToken) {
            if (response.lockedOut && response.lockoutSeconds > 0)
                passcodePopupItem.reportFailure("Too many tries. Try again in "
                                                + Math.ceil(response.lockoutSeconds / 60) + " min.");
            else
                passcodePopupItem.reportFailure("That is not correct.");
            return;
        }
        passcodePopupItem.close();
        _fetchPassphrase(response.unlockToken);
    }

    function _fetchPassphrase(token) {
        if (!shareService) {
            // The network went out of the list while the passcode was up.
            showMessage("That network is no longer there to share.");
            return;
        }
        var request = { "servicePath": shareService.path };
        if (token !== "")
            request["unlockToken"] = token;
        luna.call("luna://com.webos.service.wifi/getPassphrase", JSON.stringify(request),
                  _passphraseForShare, _passphraseError);
    }

    function _passphraseForShare(message) {
        var response = JSON.parse(message.payload);
        shareService = null;
        if (!response.returnValue) {
            _passphraseError(message);
            return;
        }
        sharePopupItem.show({ "ssid": response.ssid, "security": response.security,
                              "passphrase": response.passphrase, "hidden": response.hidden });
    }

    function _passphraseError(message) {
        shareService = null;
        var response = {};
        try {
            response = JSON.parse(message.payload);
        } catch (e) {
            response = {};
        }
        if (response.passcodeRequired)
            showMessage("The passcode is needed to share this network.");
        else if (response.errorCode === 215)
            showMessage("No password is stored for this network, so there is nothing to share.");
        else if (response.errorCode === 216)
            showMessage("This network's name cannot be put in a QR code.");
        else
            showMessage("This network could not be shared.");
    }

    function _shareAuthError(message) {
        console.warn("WiFiQrSupport: cannot check the passcode: " + (message && message.payload
                                                                     ? message.payload : message));
        if (passcodePopupItem.opened) {
            passcodePopupItem.reportFailure("The passcode could not be checked.");
            return;
        }
        shareService = null;
        showMessage("The passcode could not be checked.");
    }

    // --- what is shown ------------------------------------------------------

    function showMessage(text) {
        messagePopupItem.text = text;
        messagePopupItem.open();
    }

    WiFiScanQrPopup {
        id: scanPopupItem
        objectName: "wifiScanQrPopup"
        onNetworkScanned: (network) => qrSupport.join(network)
    }

    WiFiShareQrPopup {
        id: sharePopupItem
        objectName: "wifiShareQrPopup"
    }

    PasscodePopup {
        id: passcodePopupItem
        objectName: "wifiSharePasscodePopup"
        onVerifyRequested: (passcode) => qrSupport._verifyForShare(passcode)
        onCancelled: qrSupport.shareService = null
    }

    Popup {
        id: messagePopupItem
        objectName: "wifiQrMessagePopup"

        property string text: ""

        modal: true
        dim: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width - Units.gu(4), Units.gu(40))

        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Units.gu(1)

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                textFormat: Text.PlainText
                text: messagePopupItem.text
            }
            Button {
                Layout.fillWidth: true
                text: "OK"
                onClicked: messagePopupItem.close()
            }
        }
    }
}
