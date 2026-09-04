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
 * Add or edit one VPN profile against com.webos.service.vpn.
 *
 * The fields under the connection type are not written out here: the
 * service describes them per provider (getAgentFormFields for a fresh
 * profile, getProfileDetails's own vpnFormFields when editing) and this
 * builds the form from that description, the way the legacy app's
 * DynamicForm did. See luneos-vpn-api.md.
 *
 * A profile's name is its identity - there is no separate id - so it is
 * fixed once created, same as the type. Both stay editable only while
 * "profile" is null (adding).
 */
Popup {
    id: profilePopup

    property LunaService luna
    // The connection types the service offers (getAgents' vpnAgents, just
    // guid + label - not the fields, those are fetched per selected type).
    property var types: []
    // The profile being edited ({vpnProfileName, ...} from getProfileList),
    // or null when adding a new one.
    property var profile: null

    signal saved(string name, string vpnAgentGuid, string host, string domain, var vpnFormFields)

    readonly property bool editing: profile !== null

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    height: Math.min(parent.height - Units.gu(4), Units.gu(70))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // The fields for whatever type is selected, filled in once
    // getAgentFormFields / getProfileDetails answers.
    property var vpnFormFields: []
    // What has been typed, by field id - reassigned wholesale on every edit
    // so bindings actually notice, the same shape VpnFormFieldsColumn hands
    // edits back in.
    property var fieldValues: ({})
    property string loadError: ""

    onOpened: {
        nameField.text = editing ? (profile.vpnProfileName || "") : "";
        hostField.text = editing && profile.vpnHost ? profile.vpnHost : "";
        domainField.text = editing && profile.vpnDomain ? profile.vpnDomain : "";
        vpnFormFields = [];
        fieldValues = ({});
        loadError = "";

        if (editing) {
            luna.call("luna://com.webos.service.vpn/getProfileDetails",
                      JSON.stringify({"vpnProfileName": profile.vpnProfileName}),
                      _handleProfileDetails, _handleLoadError);
        } else if (types.length > 0) {
            typeSelector.currentIndex = 0;
            _loadFields(types[0].vpnAgentGuid);
        }
    }

    function _handleProfileDetails(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            profilePopup.loadError = response.errorText || "Failed to load profile.";
            return;
        }
        var index = _typeIndex(response.vpnAgentGuid);
        typeSelector.currentIndex = Math.max(0, index);

        var vpnProfile = response.vpnProfile || {};
        hostField.text = vpnProfile.vpnHost || "";
        domainField.text = vpnProfile.vpnDomain || "";
        _applyFields(vpnProfile.vpnFormFields || []);
    }

    function _loadFields(vpnAgentGuid) {
        vpnFormFields = [];
        fieldValues = ({});
        luna.call("luna://com.webos.service.vpn/getAgentFormFields",
                  JSON.stringify({"vpnAgentGuid": vpnAgentGuid}),
                  _handleAgentFormFields, _handleLoadError);
    }

    function _handleAgentFormFields(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            profilePopup.loadError = response.errorText || "Failed to load provider fields.";
            return;
        }
        _applyFields(response.vpnFormFields || []);
    }

    function _applyFields(fields) {
        var values = {};
        for (var i = 0; i < fields.length; i++) {
            if (fields[i].value !== undefined)
                values[fields[i].id] = fields[i].value;
        }
        profilePopup.vpnFormFields = fields;
        profilePopup.fieldValues = values;
    }

    function _handleLoadError(message) {
        profilePopup.loadError = "" + message;
    }

    function _typeIndex(vpnAgentGuid) {
        for (var i = 0; i < types.length; i++) {
            if (types[i].vpnAgentGuid === vpnAgentGuid)
                return i;
        }
        return 0;
    }

    function _setFieldValue(id, value) {
        var values = {};
        for (var key in fieldValues)
            values[key] = fieldValues[key];
        values[id] = value;
        fieldValues = values;
    }

    // The submitted vpnFormFields: the fetched descriptors with each value
    // filled in from fieldValues - everything else (connmanProperty,
    // connmanPropertyMap, type, label...) goes back exactly as received.
    function _submittedFields() {
        var fields = [];
        for (var i = 0; i < vpnFormFields.length; i++) {
            var field = {};
            for (var key in vpnFormFields[i])
                field[key] = vpnFormFields[i][key];
            if (fieldValues[field.id] !== undefined)
                field.value = fieldValues[field.id];
            fields.push(field);
        }
        return fields;
    }

    readonly property bool entryValid: {
        if (nameField.text.trim() === "" || hostField.text.trim() === "")
            return false;

        for (var i = 0; i < vpnFormFields.length; i++) {
            var field = vpnFormFields[i];
            if (!field.required)
                continue;
            var value = fieldValues[field.id];
            if (value === undefined || value === null || String(value).trim() === "")
                return false;
        }
        return true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: profilePopup.editing ? "Edit Profile" : "Add a Profile"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        Flickable {
            id: formFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: formColumn.height
            flickableDirection: Flickable.AutoFlickIfNeeded
            clip: true

            Column {
                id: formColumn
                width: formFlickable.width
                spacing: Units.gu(1)

                Label {
                    width: parent.width
                    text: "Connection type"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                ComboBox {
                    id: typeSelector
                    width: parent.width
                    textRole: "vpnAgentLabel"
                    model: profilePopup.types
                    // Changing the type on an existing profile would leave
                    // its stored fields describing the wrong provider.
                    enabled: !profilePopup.editing
                    onActivated: (index) => {
                        if (!profilePopup.editing && profilePopup.types[index])
                            profilePopup._loadFields(profilePopup.types[index].vpnAgentGuid);
                    }

                    // The LuneOS style's own delegate resolves text via
                    // "Array.isArray(control.model) ? modelData[...] : ..." -
                    // for a plain JS array of objects (this model) that
                    // comes back empty, and ItemDelegate's style makes empty
                    // text invisible. Read modelData directly instead.
                    delegate: ItemDelegate {
                        width: typeSelector.width
                        text: modelData[typeSelector.textRole]
                        font.weight: typeSelector.currentIndex === index ? Font.DemiBold : Font.Normal
                        checked: typeSelector.currentIndex === index
                    }
                }

                Label {
                    width: parent.width
                    text: "Profile name"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                TextField {
                    id: nameField
                    width: parent.width
                    height: Units.gu(5)
                    enabled: !profilePopup.editing
                    placeholderText: "Work"
                    inputMethodHints: Qt.ImhNoPredictiveText
                    color: "#2a2929"
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                }

                Label {
                    width: parent.width
                    text: "VPN server"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                TextField {
                    id: hostField
                    width: parent.width
                    height: Units.gu(5)
                    placeholderText: "Host name or IP address"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase | Qt.ImhUrlCharactersOnly
                    color: "#2a2929"
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                }

                Label {
                    width: parent.width
                    text: "Domain (optional)"
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
                TextField {
                    id: domainField
                    width: parent.width
                    height: Units.gu(5)
                    placeholderText: "corp.example.com"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    color: "#2a2929"
                    leftPadding: Units.gu(1)
                    rightPadding: Units.gu(1)
                    background: Rectangle {
                        color: "#ffffff"
                        radius: Units.gu(0.6)
                        border.color: "#9a9a9a"
                        border.width: 1
                    }
                }

                HorizontalSeparator { width: parent.width }

                /*
                 * Whatever this connection type needs on top of a host.
                 */
                VpnFormFieldsColumn {
                    width: parent.width
                    fields: profilePopup.vpnFormFields
                    values: profilePopup.fieldValues
                    luna: profilePopup.luna
                    // While adding, certificates land under whatever name is
                    // typed right now - renaming afterwards (before Save) is
                    // the one gap this leaves, not worth a staging area for.
                    vpnProfileName: profilePopup.editing ? profile.vpnProfileName
                                                          : nameField.text.trim()
                    onValueEdited: (id, value) => profilePopup._setFieldValue(id, value)
                }

                Label {
                    width: parent.width
                    visible: profilePopup.loadError !== ""
                    wrapMode: Text.WordWrap
                    text: profilePopup.loadError
                    color: "#be0003"
                    font.pixelSize: FontUtils.sizeToPixels("small")
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            Button {
                Layout.fillWidth: true
                text: "Cancel"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: profilePopup.close()
            }
            Button {
                Layout.fillWidth: true
                text: "Save"
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                enabled: profilePopup.entryValid
                onClicked: {
                    var selectedType = profilePopup.types[typeSelector.currentIndex];
                    profilePopup.saved(nameField.text.trim(),
                                       profilePopup.editing ? profile.vpnAgentGuid
                                                            : (selectedType ? selectedType.vpnAgentGuid : ""),
                                       hostField.text.trim(),
                                       domainField.text.trim(),
                                       profilePopup._submittedFields());
                    profilePopup.close();
                }
            }
        }
    }
}
