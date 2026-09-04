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
// LS2 access
import LuneOS.Service 1.0

import "../Common"

/*
 * Imports a VPN profile from a file instead of filling in every field by
 * hand - a WireGuard peer or a company's OpenVPN client are normally handed
 * out as a ready-made .conf/.ovpn, not typed in field by field. Wraps
 * com.webos.service.vpn's importProfile; see luneos-vpn-api.md.
 */
Popup {
    id: importPopup

    property LunaService luna

    signal imported()

    readonly property var formats: [
        { "label": "WireGuard config",       "format": "wg-conf",        "filters": ["*.conf"] },
        { "label": "OpenVPN config",          "format": "ovpn",           "filters": ["*.ovpn"] },
        { "label": "ConnMan config",          "format": "connman-config", "filters": ["*.config"] }
    ]

    property string filePath: ""
    property string loadError: ""

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    height: Math.min(parent.height - Units.gu(4), Units.gu(50))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    onOpened: {
        nameField.text = "";
        filePath = "";
        loadError = "";
        formatSelector.currentIndex = 0;
    }

    function _chooseFile() {
        var selected = importPopup.formats[formatSelector.currentIndex];
        filePickerLoader.setSource("../Common/FilePickerPopup.qml", {
            "nameFilters": selected.filters,
            "hint": selected.label + " (" + selected.filters.join(", ") + ")"
        });
        filePickerLoader.item.fileSelected.connect(function(path) {
            importPopup.filePath = path;
        });
        filePickerLoader.item.open();
    }

    function _import() {
        var selected = importPopup.formats[formatSelector.currentIndex];
        luna.call("luna://com.webos.service.vpn/importProfile",
                  JSON.stringify({
                      "vpnProfileName": nameField.text.trim(),
                      "format": selected.format,
                      "filePath": importPopup.filePath
                  }),
                  _handleImportDone, _handleImportError);
    }

    function _handleImportDone(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            importPopup.loadError = response.errorText || "Import failed.";
            return;
        }
        importPopup.imported();
        importPopup.close();
    }

    function _handleImportError(message) {
        importPopup.loadError = "" + message;
    }

    // A single wrapping Item, not two separate top-level children: the
    // LuneOS Popup style only falls back to a content child's implicit size
    // when there is exactly one (contentChildren.length === 1) - with the
    // Loader alongside it as a second child that check silently failed and
    // this popup lost its background along with its sizing.
    Item {
        anchors.fill: parent

        Loader {
            id: filePickerLoader
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Units.gu(1)

            Label {
                Layout.fillWidth: true
                text: "Import a Profile"
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: FontUtils.sizeToPixels("18pt")
                font.weight: Font.Bold
            }

            Label {
                Layout.fillWidth: true
                text: "File type"
                color: "#666666"
                font.pixelSize: FontUtils.sizeToPixels("small")
            }
            ComboBox {
                id: formatSelector
                Layout.fillWidth: true
                textRole: "label"
                model: importPopup.formats
                onActivated: importPopup.filePath = ""

                // The LuneOS style's own delegate resolves text via
                // "Array.isArray(control.model) ? modelData[...] : ..." -
                // for a plain JS array of objects (this model) that comes
                // back empty, and ItemDelegate's style makes empty text
                // invisible. Read modelData directly instead.
                delegate: ItemDelegate {
                    width: formatSelector.width
                    text: modelData[formatSelector.textRole]
                    font.weight: formatSelector.currentIndex === index ? Font.DemiBold : Font.Normal
                    checked: formatSelector.currentIndex === index
                }
            }

            Label {
                Layout.fillWidth: true
                text: "Profile name"
                color: "#666666"
                font.pixelSize: FontUtils.sizeToPixels("small")
            }
            TextField {
                id: nameField
                Layout.fillWidth: true
                height: Units.gu(5)
                leftPadding: Units.gu(1)
                rightPadding: Units.gu(1)
                placeholderText: "Work"
                inputMethodHints: Qt.ImhNoPredictiveText
                color: "#2a2929"
                background: Rectangle {
                    color: "#ffffff"
                    radius: Units.gu(0.6)
                    border.color: "#9a9a9a"
                    border.width: 1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Units.gu(1)

                Label {
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                    text: importPopup.filePath !== ""
                          ? importPopup.filePath.split("/").pop() : "No file chosen"
                    color: importPopup.filePath !== "" ? "#2a2929" : "#999999"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
                Button {
                    text: "Choose file..."
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: importPopup._chooseFile()
                }
            }

            Label {
                Layout.fillWidth: true
                visible: importPopup.loadError !== ""
                wrapMode: Text.WordWrap
                text: importPopup.loadError
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
                    onClicked: importPopup.close()
                }
                Button {
                    Layout.fillWidth: true
                    text: "Import"
                    LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                    enabled: nameField.text.trim() !== "" && importPopup.filePath !== ""
                    onClicked: importPopup._import()
                }
            }
        }
    }
}
