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

/*
 * What happened to a connect the user asked for, when it did not work.
 *
 * Two cases. connman is still busy with an earlier attempt on the network
 * (a second tap, or a Connect refused with InProgress): say so and offer to
 * stop that attempt, since otherwise nothing at all happens and the network
 * can stay stuck. Disconnect is what stops it: connman cancels a pending
 * passphrase request or the association, and that answers the earlier
 * Connect. Or the attempt failed: say why, in words.
 */
Popup {
    id: connectProblemPopup

    property NetworkService service: null
    // true: an earlier attempt is still running; false: this one failed.
    property bool busy: false
    property string message: ""

    readonly property string serviceName: service && service.name ? service.name : "this network"

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(parent.width - Units.gu(4), Units.gu(46))

    // The network went out of range and the model dropped it: QML nulls the
    // property, and there is nothing left to stop or explain.
    onServiceChanged: if (!service && opened) close()
    onClosed: service = null

    function showBusy(networkService) {
        service = networkService;
        busy = true;
        message = "";
        open();
    }

    function showFailure(networkService, text) {
        service = networkService;
        busy = false;
        message = text;
        open();
    }

    /*
     * Words for a failed Connect, from connman's D-Bus error name and the
     * service's Error property, or "" when there is nothing to tell: the user
     * cancelled the passphrase prompt or stopped the attempt themselves.
     * connman answers most failures with a bare net.connman.Error.Failed
     * ("Input/output error"), so the service's Error says more there.
     */
    function failureText(errorName, serviceError, dbusMessage) {
        switch (errorName) {
        case "net.connman.Error.OperationAborted":
        case "net.connman.Error.OperationCanceled":
        case "net.connman.Agent.Error.Canceled":
        case "net.connman.Error.AlreadyConnected":
            return "";
        case "net.connman.Error.OperationTimeout":
        case "org.freedesktop.DBus.Error.NoReply":
        case "org.freedesktop.DBus.Error.Timeout":
        case "org.freedesktop.DBus.Error.TimedOut":
            return "Connecting took too long and was stopped.";
        case "net.connman.Error.InvalidArguments":
            return "The passphrase is not valid for this network.";
        case "net.connman.Error.NotRegistered":
            return "There was no way to ask for the passphrase.";
        case "net.connman.Error.NoCarrier":
            return "Both IPv4 and IPv6 are turned off for this network.";
        }

        switch (serviceError) {
        case "invalid-key":
            return "The passphrase was not accepted.";
        case "auth-failed":
        case "login-failed":
            return "The network did not accept the credentials.";
        case "dhcp-failed":
            return "The network did not give out an address.";
        case "out-of-range":
            return "The network is out of range.";
        case "blocked":
            return "Wi-Fi is blocked.";
        }

        return "Could not connect" + (dbusMessage ? " (" + dbusMessage + ")." : ".");
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(2)

        Label {
            Layout.fillWidth: true
            text: connectProblemPopup.serviceName
            font.bold: true
            elide: Text.ElideRight
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        Label {
            objectName: "connectProblemText"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: FontUtils.sizeToPixels("medium")
            text: connectProblemPopup.busy
                  ? "Still trying to connect from an earlier attempt. Stop it, "
                    + "then tap the network to try again."
                  : connectProblemPopup.message + " Tap the network to try again."
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            Button {
                objectName: "connectProblemStop"
                Layout.fillWidth: true
                visible: connectProblemPopup.busy
                text: "Stop connecting"
                LuneOSButton.mainColor: LuneOSButton.negativeColor
                LuneOSButton.textColor: "white"
                onClicked: {
                    if (connectProblemPopup.service)
                        connectProblemPopup.service.requestDisconnect();
                    connectProblemPopup.close();
                }
            }
            Button {
                objectName: "connectProblemDismiss"
                Layout.fillWidth: true
                text: connectProblemPopup.busy ? "Keep waiting" : "OK"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: connectProblemPopup.close()
            }
        }
    }
}
