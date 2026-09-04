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

import "../Common"

/*
 * Certificate Manager, after the webOS 3.0.5 app of the same name
 * (com.palm.app.certificatemanager).
 *
 * Unlike most of the "guessed at a service" pages elsewhere in this app,
 * this one had nothing to guess: org.webosports.service.certmgr is a real,
 * already-built LuneOS service (certmgrd, meta-webos-ports'
 * recipes-webos-owo/certmgrd) wrapping the genuine LG webOS-OSE
 * pmcertificatemgr library it links against for the actual X.509/PKCS#12
 * handling - not a legacy guess, not a per-app placeholder, just wired up.
 *
 * The methods, read straight from certmgr_service.c's own LSMethod table:
 *   listAll {}
 *      -> { returnValue, certificates: [ { serial, start, expiration,
 *           issuer, issuerOrganization, issuerOrganizationUnit, subject,
 *           subjectSurname, subjectOrganization, subjectOrganizationUnit } ] }
 *      No subscribe support - refreshed after every install/remove instead.
 *   install { path, passphrase }
 *      -> { returnValue }
 *      passphrase is optional (PKCS#12 bundles are commonly protected,
 *      plain PEM/CRT certificates are not). path has to already be on the
 *      filesystem - there is no upload, so this goes through the same
 *      /media/internal/downloads file picker VPN profile/certificate import
 *      uses.
 *   remove { serial }
 *      -> { returnValue }
 */
BasePage {
    id: pageRoot

    readonly property string certService: "org.webosports.service.certmgr"

    property bool serviceAvailable: false
    property var certificates: []

    Component.onCompleted: retrieveProperties();

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable

            serviceName: pageRoot.certService
            description: "Certificates cannot be listed, imported or removed " +
                         "until this answers."

            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.serviceAvailable

            title: "Installed Certificates"
            Column {
                width: parent.width

                Label {
                    width: parent.width
                    visible: pageRoot.certificates.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: "No certificates are installed."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                Repeater {
                    model: pageRoot.certificates

                    delegate: Column {
                        id: certRow
                        width: parent.width

                        readonly property var cert: modelData
                        property bool pendingDelete: false

                        // Normal row: subject (falling back to the
                        // organization name for a bare CA cert with no
                        // common name) and issuer/expiration underneath.
                        // Swipe sideways to ask for delete confirmation
                        // (webOS delete gesture).
                        Item {
                            width: parent.width
                            height: Units.gu(8)
                            visible: !certRow.pendingDelete

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Units.gu(1)
                                anchors.rightMargin: Units.gu(1)

                                Label {
                                    width: parent.width
                                    text: certRow.cert.subject || certRow.cert.subjectOrganization ||
                                          ("Certificate " + certRow.cert.serial)
                                    elide: Text.ElideRight
                                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                                }
                                Label {
                                    width: parent.width
                                    text: "Issued by " +
                                          (certRow.cert.issuer || certRow.cert.issuerOrganization || "unknown") +
                                          (certRow.cert.expiration ? " - expires " + certRow.cert.expiration : "")
                                    elide: Text.ElideRight
                                    color: "#666666"
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent

                                property real _pressX: 0

                                onPressed: (mouse) => { _pressX = mouse.x; }
                                onReleased: (mouse) => {
                                    if (Math.abs(mouse.x - _pressX) > Units.gu(4))
                                        certRow.pendingDelete = true;
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: Units.gu(8)
                            spacing: Units.gu(2)
                            visible: certRow.pendingDelete

                            Button {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Cancel"
                                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                onClicked: certRow.pendingDelete = false
                            }
                            Button {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Delete"
                                LuneOSButton.mainColor: "#be0003"
                                LuneOSButton.textColor: "white"
                                onClicked: {
                                    pageRoot.removeCertificate(certRow.cert.serial);
                                    certRow.pendingDelete = false;
                                }
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    enabled: pageRoot.serviceAvailable
                    text: "Import Certificate..."
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: importCertPopup.open()
                }
            }
        }

        ExplanationText {
            text: "Swipe a certificate sideways to remove it. Importing a " +
                  "PKCS#12 bundle (.p12/.pfx) may ask for the passphrase it " +
                  "was protected with; a plain certificate (.pem/.crt/.cer) " +
                  "usually will not need one."
        }
    }

    Popup {
        id: importCertPopup

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(46))
        height: Math.min(parent.height - Units.gu(4), Units.gu(50))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        property string filePath: ""
        property string loadError: ""

        onOpened: {
            filePath = "";
            loadError = "";
            passphraseField.text = "";
        }

        // A single wrapping Item, not two separate top-level children: the
        // LuneOS Popup style only falls back to a content child's implicit
        // size when there is exactly one (contentChildren.length === 1) -
        // see VpnImportProfilePopup.qml for the first time this bit.
        Item {
            anchors.fill: parent

            Loader {
                id: filePickerLoader
            }

            ColumnLayout {
                width: parent.width
                spacing: Units.gu(1.5)

                Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: "Import Certificate"
                    font.pixelSize: FontUtils.sizeToPixels("18pt")
                    font.weight: Font.Bold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)

                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideMiddle
                        text: importCertPopup.filePath !== ""
                              ? importCertPopup.filePath.split("/").pop() : "No file chosen"
                        color: importCertPopup.filePath !== "" ? "#2a2929" : "#999999"
                        font.pixelSize: FontUtils.sizeToPixels("medium")
                    }
                    Button {
                        text: "Choose file..."
                        LuneOSButton.mainColor: LuneOSButton.secondaryColor
                        onClicked: {
                            filePickerLoader.setSource("../Common/FilePickerPopup.qml", {
                                "nameFilters": ["*.p12", "*.pfx", "*.pem", "*.crt", "*.cer"],
                                "hint": "PKCS#12 bundle or certificate"
                            });
                            filePickerLoader.item.fileSelected.connect(function(path) {
                                importCertPopup.filePath = path;
                            });
                            filePickerLoader.item.open();
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: "Passphrase (if any)"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                TextField {
                    id: passphraseField
                    Layout.fillWidth: true
                    height: Units.gu(5)
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    echoMode: TextInput.Password
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhSensitiveData
                    color: "#2a2929"
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: importCertPopup.loadError !== ""
                    wrapMode: Text.WordWrap
                    text: importCertPopup.loadError
                    color: "#be0003"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)

                    Button {
                        Layout.fillWidth: true
                        text: "Cancel"
                        LuneOSButton.mainColor: LuneOSButton.secondaryColor
                        onClicked: importCertPopup.close()
                    }
                    Button {
                        Layout.fillWidth: true
                        text: "Import"
                        LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                        enabled: importCertPopup.filePath !== ""
                        onClicked: pageRoot.installCertificate(importCertPopup.filePath, passphraseField.text)
                    }
                }
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.call("luna://" + certService + "/listAll", "{}",
                  _handleGetCertificates, _handleServiceUnavailable);
    }

    function _handleGetCertificates(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        pageRoot.certificates = response.certificates !== undefined ? response.certificates : [];
        pageRoot.serviceAvailable = true;
    }

    function _handleServiceUnavailable(message) {
        console.warn("Certificate manager did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    function installCertificate(path, passphrase) {
        var payload = {"path": path};
        if (passphrase !== "")
            payload.passphrase = passphrase;

        luna.call("luna://" + certService + "/install", JSON.stringify(payload),
                  _handleInstallDone, _handleInstallError);
    }

    function _handleInstallDone(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            importCertPopup.loadError = response.errorText || "Import failed.";
            return;
        }
        importCertPopup.close();
        pageRoot.retrieveProperties();
    }

    function _handleInstallError(message) {
        importCertPopup.loadError = "" + message;
    }

    function removeCertificate(serial) {
        luna.call("luna://" + certService + "/remove", JSON.stringify({"serial": serial}),
                  function() { pageRoot.retrieveProperties(); }, _handleSetError);
    }
}
