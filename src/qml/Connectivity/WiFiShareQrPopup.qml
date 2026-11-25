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
// QrCode, WifiQrCode
import LuneOS.Components 1.0
// Colors
import LuneOS.Forms 1.0

/*
 * A network as a QR code another phone's camera joins it from - the code
 * Android, iOS and GNOME Settings all read - with the password written
 * underneath for whatever cannot scan. Used for a saved network (after the
 * passcode, see WiFiQrSupport) and for the hotspot.
 *
 * The passphrase is let go of as soon as the popup closes.
 */
Popup {
    id: sharePopup

    property string ssid: ""
    // "none", "wep", "psk" or "sae"
    property string security: "psk"
    property string passphrase: ""
    property bool hidden: false

    readonly property string codeText: WifiQrCode.compose(ssid, security, passphrase, hidden)

    modal: true
    dim: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    x: (parent.width - width) / 2
    y: Math.max(0, (parent.height - height) / 2)
    width: Math.min(parent.width - Units.gu(4), Units.gu(46))

    function show(network) {
        ssid = network.ssid || "";
        security = network.security || "none";
        passphrase = network.passphrase || "";
        hidden = !!network.hidden;
        open();
    }

    onClosed: {
        passphrase = "";
        ssid = "";
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "Share Wi-Fi"
            font.pixelSize: FontUtils.sizeToPixels("large")
            font.bold: true
        }

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: FontUtils.sizeToPixels("small")
            // An SSID is whatever its owner typed; never let it be markup.
            textFormat: Text.PlainText
            text: sharePopup.codeText !== ""
                  ? "Scan this with another phone's camera to join “" + sharePopup.ssid + "”."
                  : "“" + sharePopup.ssid + "” cannot be shared as a QR code."
        }

        // Dark on white whatever the theme: the only way round every reader takes.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            // Half the screen's height at most, so the title and Done still
            // fit on a square one (the Q25's 720x720).
            Layout.preferredWidth: Math.min(sharePopup.availableWidth, Units.gu(30),
                                            sharePopup.parent ? sharePopup.parent.height / 2 : Units.gu(30))
            Layout.preferredHeight: Layout.preferredWidth
            visible: qrCode.valid
            color: "white"
            radius: Units.gu(0.5)

            QrCode {
                id: qrCode
                objectName: "wifiShareQrCode"
                anchors.fill: parent
                anchors.margins: Units.gu(0.5)
                text: sharePopup.opened ? sharePopup.codeText : ""
            }
        }

        Label {
            Layout.fillWidth: true
            visible: sharePopup.codeText !== "" && !qrCode.valid
            wrapMode: Text.WordWrap
            color: "darkred"
            text: "The QR code could not be drawn."
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Units.gu(1)

            Label {
                text: "Network"
                color: Colors.secondaryText
            }
            Label {
                Layout.fillWidth: true
                text: sharePopup.ssid
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }
            Label {
                visible: sharePopup.security !== "none"
                text: "Password"
                color: Colors.secondaryText
            }
            Label {
                objectName: "wifiSharePassphrase"
                Layout.fillWidth: true
                visible: sharePopup.security !== "none"
                text: sharePopup.passphrase
                wrapMode: Text.WrapAnywhere
                textFormat: Text.PlainText
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Done"
            LuneOSButton.mainColor: LuneOSButton.affirmativeColor
            onClicked: sharePopup.close()
        }
    }
}
