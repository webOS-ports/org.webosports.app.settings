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

/*
 * Renders one com.webos.service.vpn "vpnFormFields" array - the
 * connman-side field descriptors (id, type, label, value, options,
 * connmanProperty/connmanPropertyMap, ...), not the simpler add/edit "kind"
 * shape used elsewhere on this page. It is the same array in two different
 * places: the profile editor (VpnProfilePopup) and a runtime credential
 * prompt (VpnPromptPopup) both render it and both hand the values back the
 * same way, so the rendering lives here once.
 *
 * This only mutates "values", never "fields" - the descriptors (including
 * connmanProperty/connmanPropertyMap) are round-tripped back to the service
 * unchanged, exactly as they were received. The caller owns "values" (an id
 * -> current value map) and passes a fresh object down; edits come back
 * through valueEdited() rather than this component writing into a bound
 * property directly, the same reassign-on-edit shape VpnProfilePopup already
 * uses for its own fieldValues.
 *
 * Only the widget types the shipped providers actually use are handled:
 * textfield, passwordfield, checkbox, listselector, status.
 */
Column {
    id: fieldsColumn

    property var fields: []
    property var values: ({})

    // Both optional: without them (VpnPromptPopup's case - a runtime
    // credential prompt never asks for a certificate) the fields below just
    // render as plain text entry, no Import button.
    property LunaService luna
    property string vpnProfileName: ""

    signal valueEdited(string id, var value)

    width: parent ? parent.width : implicitWidth
    spacing: Units.gu(1)

    // Which vpnFormFields are a file to import rather than text to type -
    // matched by connmanProperty, not a name guess: OpenConnect.ServerCert
    // ("Server cert fingerprint (SHA1)") looks like a cert field by name but
    // is a typed-in fingerprint, not a file, so this has to be an exact list
    // taken from luneos-vpn-adapter/files/formfields/*.json, not a pattern.
    readonly property var _certRoles: ({
        "OpenVPN.CACert": "ca",
        "OpenVPN.Cert": "cert",
        "OpenVPN.Key": "key",
        "OpenConnect.CACert": "ca",
        "OpenConnect.ClientCert": "cert",
        "OpenConnect.UserPrivateKey": "key",
        "OpenConnect.PKCSClientCert": "pkcs12"
    })

    function _certRole(field) {
        return fieldsColumn._certRoles[field.connmanProperty] || "";
    }

    function _importCertificate(field, filePath) {
        var role = fieldsColumn._certRole(field);
        fieldsColumn.luna.call("luna://com.webos.service.vpn/importCertificate",
            JSON.stringify({"vpnProfileName": fieldsColumn.vpnProfileName,
                            "role": role, "filePath": filePath}),
            function(message) {
                var response = JSON.parse(message.payload);
                if (response.returnValue)
                    fieldsColumn.valueEdited(field.id, response.path);
            },
            function() {});
    }

    // Not part of the rendered form - Column would otherwise still count it
    // for spacing purposes even at zero size, since only invisible children
    // are skipped from the layout.
    Loader {
        id: certPickerLoader
        visible: false
    }

    Repeater {
        model: fieldsColumn.fields

        delegate: Column {
            width: parent.width
            spacing: Units.gu(0.5)
            visible: modelData.visible !== false

            readonly property var field: modelData
            readonly property var currentValue: fieldsColumn.values[field.id]

            Label {
                width: parent.width
                visible: parent.field.type !== "checkbox" && parent.field.type !== "status" &&
                         (parent.field.label || "") !== ""
                text: parent.field.label + (parent.field.required ? " *" : "")
                color: "#666666"
                font.pixelSize: FontUtils.sizeToPixels("small")
            }

            RowLayout {
                width: parent.width
                spacing: Units.gu(1)
                visible: parent.field.type === "textfield" || parent.field.type === "passwordfield"

                readonly property string certRole: fieldsColumn._certRole(parent.field)
                readonly property bool canImportCert: certRole !== "" && fieldsColumn.luna &&
                                                       fieldsColumn.vpnProfileName !== "" &&
                                                       parent.field.editable !== false

                TextField {
                    Layout.fillWidth: true
                    height: Units.gu(5)
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    enabled: parent.parent.field.editable !== false
                    echoMode: parent.parent.field.type === "passwordfield" ? TextInput.Password : TextInput.Normal
                    inputMethodHints: Qt.ImhNoPredictiveText |
                                      (parent.parent.field.type === "passwordfield" ? Qt.ImhSensitiveData : 0) |
                                      (parent.parent.field.inputType === "number" ? Qt.ImhDigitsOnly : 0)
                    color: "#2a2929"
                    // A clearly visible white field, styled after
                    // FingerprintPage's rename field - the default LuneOS
                    // style's TextField background is a flat image, not a
                    // rounded box.
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                    // hasStoredValue: a secret already exists server-side but
                    // was not sent back to us - leave the field blank rather
                    // than show "" as if nothing were set.
                    placeholderText: parent.parent.field.hasStoredValue ? "(unchanged)"
                                     : (parent.parent.field.hint || "")
                    text: parent.parent.currentValue !== undefined && parent.parent.currentValue !== null
                          ? String(parent.parent.currentValue) : ""
                    onTextEdited: fieldsColumn.valueEdited(parent.parent.field.id, text)
                }

                // A CA/client cert or private key is normally handed out as
                // a file, not typed in by hand - see importCertificate in
                // luneos-vpn-api.md.
                Button {
                    visible: parent.canImportCert
                    text: "Import..."
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: {
                        var field = parent.parent.field;
                        certPickerLoader.setSource("FilePickerPopup.qml", {
                            "nameFilters": ["*.pem", "*.crt", "*.cer", "*.key", "*.p12", "*.pfx"],
                            "hint": field.label
                        });
                        certPickerLoader.item.fileSelected.connect(function(path) {
                            fieldsColumn._importCertificate(field, path);
                        });
                        certPickerLoader.item.open();
                    }
                }
            }

            CheckBox {
                width: parent.width
                visible: parent.field.type === "checkbox"
                enabled: parent.field.editable !== false
                text: parent.field.label
                LayoutMirroring.enabled: true
                font.pixelSize: FontUtils.sizeToPixels("16pt")
                font.weight: Font.Normal

                checked: parent.currentValue ===
                         (parent.field.trueValue !== undefined ? parent.field.trueValue : "true")
                onToggled: fieldsColumn.valueEdited(parent.field.id,
                    checked ? (parent.field.trueValue !== undefined ? parent.field.trueValue : "true")
                            : (parent.field.falseValue !== undefined ? parent.field.falseValue : "false"))
            }

            ComboBox {
                id: selector
                width: parent.width
                visible: parent.field.type === "listselector"
                enabled: parent.field.editable !== false
                textRole: "label"
                model: parent.field.options || []

                Component.onCompleted: {
                    var options = parent.field.options || [];
                    for (var i = 0; i < options.length; i++) {
                        if (options[i].value === parent.currentValue) {
                            currentIndex = i;
                            break;
                        }
                    }
                }
                onActivated: (index) => {
                    var options = parent.field.options || [];
                    if (options[index])
                        fieldsColumn.valueEdited(parent.field.id, options[index].value);
                }

                // The LuneOS style's own delegate resolves text via
                // "Array.isArray(control.model) ? modelData[...] : ..." -
                // for a plain JS array of objects (this model) that comes
                // back empty, and ItemDelegate's style makes empty text
                // invisible. Read modelData directly instead.
                delegate: ItemDelegate {
                    width: selector.width
                    text: modelData[selector.textRole]
                    font.weight: selector.currentIndex === index ? Font.DemiBold : Font.Normal
                    checked: selector.currentIndex === index
                }
            }

            Label {
                width: parent.width
                visible: parent.field.type === "status"
                wrapMode: Text.WordWrap
                text: parent.field.value || ""
                font.pixelSize: FontUtils.sizeToPixels("small")
                font.italic: parent.field.statusType === "footnote"
                color: parent.field.statusType === "error" ? "#be0003" : "#666666"
            }
        }
    }
}
