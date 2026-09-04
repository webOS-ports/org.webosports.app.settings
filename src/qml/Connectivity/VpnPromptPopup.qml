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
 * Answers one net.connman.vpn.Agent.RequestInput prompt relayed by
 * com.webos.service.vpn through getStatus - unlike Wi-Fi's UserAgent (a
 * direct Connman QML binding), the VPN agent role lives in the service
 * itself, so this only ever talks LS2: a "form" prompt renders
 * vpnFormFields (same shape and same shared renderer as VpnProfilePopup), a
 * "banner" prompt is a plain Yes/No. See luneos-vpn-api.md.
 */
Popup {
    id: promptPopup

    property LunaService luna
    property string promptId: ""
    property string promptType: "form"   // form | banner
    property string label: ""
    property var vpnFormFields: []
    property var fieldValues: ({})

    modal: true
    focus: true
    closePolicy: Popup.NoAutoClose

    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    onOpened: {
        var values = {};
        for (var i = 0; i < vpnFormFields.length; i++) {
            if (vpnFormFields[i].value !== undefined)
                values[vpnFormFields[i].id] = vpnFormFields[i].value;
        }
        fieldValues = values;
    }

    function _setFieldValue(id, value) {
        var values = {};
        for (var key in fieldValues)
            values[key] = fieldValues[key];
        values[id] = value;
        fieldValues = values;
    }

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

    function _respond(payload) {
        promptPopup.luna.call("luna://com.webos.service.vpn/uiPromptResponse",
                              JSON.stringify(payload), function() {}, function() {});
        promptPopup.close();
    }

    ColumnLayout {
        width: parent.width
        spacing: Units.gu(1.5)

        Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: promptPopup.label
            font.weight: Font.Bold
            font.pixelSize: FontUtils.sizeToPixels("16pt")
        }

        VpnFormFieldsColumn {
            Layout.fillWidth: true
            visible: promptPopup.promptType === "form"
            fields: promptPopup.vpnFormFields
            values: promptPopup.fieldValues
            onValueEdited: (id, value) => promptPopup._setFieldValue(id, value)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            Button {
                Layout.fillWidth: true
                text: "Cancel"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: promptPopup._respond({"promptId": promptPopup.promptId, "cancelled": true})
            }

            Button {
                Layout.fillWidth: true
                visible: promptPopup.promptType === "banner"
                text: "OK"
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                onClicked: promptPopup._respond({"promptId": promptPopup.promptId, "isOk": true})
            }

            Button {
                Layout.fillWidth: true
                visible: promptPopup.promptType === "form"
                text: "Send"
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                onClicked: promptPopup._respond({"promptId": promptPopup.promptId,
                                                 "vpnFormFields": promptPopup._submittedFields()})
            }
        }
    }
}
