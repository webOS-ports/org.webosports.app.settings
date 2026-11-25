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
// WifiQrCode
import LuneOS.Components 1.0

/*
 * "Scan QR code": the viewfinder, and what it made of the last code it saw.
 * The code another phone shows from its Wi-Fi sharing, or the one on a
 * router's sticker, is read with WifiQrCode; a code that is not a network
 * that can be joined says why and the camera keeps looking, so pointing it at
 * the wrong thing first costs nothing.
 */
Popup {
    id: scanPopup

    // The camera could not be had; the reason is shown instead of a preview.
    property string cameraProblem: ""
    property string status: ""

    // A network read off a code: WifiQrCode.parse()'s map, valid.
    signal networkScanned(var network)

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2
    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    height: Math.min(parent.height - Units.gu(4), Units.gu(64))

    // Before the Loader becomes active with opened: a load error it reports
    // straight away must not be wiped again.
    onAboutToShow: {
        cameraProblem = "";
        status = "";
    }

    // What a code that is not a joinable network gets told.
    function problemText(error) {
        switch (error) {
        case "notWifi":
            return "That is not a Wi-Fi QR code.";
        case "enterprise":
            return "That network needs a user name, not just a password. Join it from the list.";
        case "badPassphrase":
            return "The password in that code does not fit its network.";
        default:
            return "That Wi-Fi QR code could not be read.";
        }
    }

    // A code's text from the scanner; also the way in for tests.
    function handleCode(text) {
        var network = WifiQrCode.parse(text);
        if (!network.valid) {
            status = problemText(network.error);
            return;
        }
        status = "";
        // Let the scanner's callback unwind before the camera is torn down
        // under it, as the eSIM page does.
        Qt.callLater(function () {
            scanPopup.close();
            scanPopup.networkScanned(network);
        });
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "Scan a Wi-Fi QR code"
            font.pixelSize: FontUtils.sizeToPixels("large")
            font.bold: true
            elide: Text.ElideRight
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: FontUtils.sizeToPixels("small")
            text: "Point the camera at the code another phone shows to share its Wi-Fi, " +
                  "or at the one on the router."
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Loader {
                id: scannerLoader
                objectName: "wifiQrScannerLoader"
                anchors.fill: parent
                // Not tied to cameraProblem: a load error sets that, and the
                // two would chase each other.
                active: scanPopup.opened
                visible: scanPopup.cameraProblem === ""
                source: "WiFiQrScanner.qml"
                onLoaded: item.active = Qt.binding(function () { return scanPopup.opened; })
                onStatusChanged: {
                    if (status === Loader.Error)
                        scanPopup.cameraProblem = "The camera is not available.";
                }
            }

            Connections {
                target: scannerLoader.item
                ignoreUnknownSignals: true
                function onCodeRead(text) { scanPopup.handleCode(text); }
                function onCameraFailed(message) { scanPopup.cameraProblem = message; }
            }

            Label {
                anchors.centerIn: parent
                width: parent.width
                visible: scanPopup.cameraProblem !== ""
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: scanPopup.cameraProblem
            }
        }

        Label {
            objectName: "wifiQrScanStatus"
            Layout.fillWidth: true
            visible: text !== ""
            wrapMode: Text.WordWrap
            color: "darkred"
            text: scanPopup.status
        }

        Button {
            Layout.fillWidth: true
            text: "Cancel"
            onClicked: scanPopup.close()
        }
    }
}
