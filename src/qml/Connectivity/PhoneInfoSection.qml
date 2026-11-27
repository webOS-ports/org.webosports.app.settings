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

import QtQuick.Controls.LuneOS 2.0
import LunaNext.Common 0.1
import LuneOS.Forms 1.0

/*
 * What the phone is registered on, per SIM, read only: what Android's
 * *#*#4636#*#* "Phone information" shows that is worth a user's while. The
 * operator, the radio technology, the signal, and the IMS registration
 * behind VoLTE and Wi-Fi calling: registered or not, for voice and SMS, and
 * over Wi-Fi or the mobile network.
 *
 * All of it comes from telephonyd: the SIMs and their bars from
 * simListQuery (the page's, passed in as sims), the rest from
 * networkStatusQuery for each SIM. A telephonyd from before IMS was
 * reported leaves the IMS rows at "Not reported" rather than "No".
 */
GroupBox {
    id: section

    // simListQuery's sims: simId, name, operatorName, bars, powered, ...
    property var sims: []
    // As LunaService.subscribe, giving back a call with cancel()
    property var subscribe: null

    // networkStatusQuery's extended object per simId, as last heard
    property var statuses: ({})

    property var _calls: ({})

    title: "Phone Information"
    visible: sims.length > 0

    function technologyName(technology) {
        switch (technology) {
        case "gsm":  return "GSM (2G)";
        case "edge": return "EDGE (2G)";
        case "umts": return "UMTS (3G)";
        case "hspa": return "HSPA (3G)";
        case "lte":  return "LTE (4G)";
        case "nr":   return "NR (5G)";
        case undefined: return "Not reported";
        default:     return "Unknown";
        }
    }

    function yesNo(value) {
        return value === undefined ? "Not reported" : (value ? "Yes" : "No");
    }

    function bearerName(ims) {
        if (!ims.registered)
            return "Not registered";
        switch (ims.bearer) {
        case "wifi":     return "Wi-Fi";
        case "cellular": return "Mobile network";
        // Stock ofono cannot tell
        default:         return "Unknown";
        }
    }

    // What calls go over: what the status bar's VoWiFi and VoLTE say
    function callsOver(status) {
        if (status.vowifi === true)
            return "Wi-Fi (VoWiFi)";
        if (status.volte === true)
            return "Mobile network (VoLTE)";
        return status.state === "service" ? "2G/3G" : "No service";
    }

    function rowsFor(sim) {
        var status = statuses[sim.simId];
        var rows = [];

        if (!sim.powered) {
            rows.push({"rowLabel": "Network", "rowValue": "SIM off"});
            return rows;
        }
        if (status === undefined) {
            rows.push({"rowLabel": "Network", "rowValue": "Not reported"});
            return rows;
        }

        var name = status.networkName || sim.operatorName || "";
        rows.push({"rowLabel": "Operator", "rowValue": name !== "" ? name : "None"});
        rows.push({"rowLabel": "Network",
                   "rowValue": status.state === "service" ? technologyName(status.technology) : "No service"});
        // telephonyd's 0-5 bars, the status bar's scale
        rows.push({"rowLabel": "Signal", "rowValue": (sim.bars !== undefined ? sim.bars : 0) + "/5"});
        rows.push({"rowLabel": "Calls over", "rowValue": callsOver(status)});

        var ims = status.ims;
        if (ims === undefined) {
            rows.push({"rowLabel": "IMS", "rowValue": "Not reported"});
            return rows;
        }
        rows.push({"rowLabel": "IMS", "rowValue": ims.registered ? "Registered" : "Not registered"});
        rows.push({"rowLabel": "IMS over", "rowValue": bearerName(ims)});
        rows.push({"rowLabel": "Voice over IMS", "rowValue": yesNo(ims.voiceCapable)});
        rows.push({"rowLabel": "SMS over IMS", "rowValue": yesNo(ims.smsCapable)});
        return rows;
    }

    function _heard(simId, message) {
        if (!message || !message.payload)
            return;
        var response = JSON.parse(message.payload);
        var copy = Object.assign({}, statuses);
        if (response.returnValue && response.extended)
            copy[simId] = response.extended;
        else
            delete copy[simId];
        statuses = copy;
    }

    // One subscription per SIM, kept while the SIM is listed
    function _follow() {
        if (!subscribe)
            return;
        var wanted = {};
        for (var i = 0; i < sims.length; i++)
            wanted[sims[i].simId] = true;

        var calls = Object.assign({}, _calls);
        for (var id in calls) {
            if (!wanted[id]) {
                if (calls[id] && calls[id].cancel)
                    calls[id].cancel();
                delete calls[id];
            }
        }
        for (let simId in wanted) {
            if (calls[simId] !== undefined)
                continue;
            // let: each answer has to land on its own SIM
            let n = Number(simId);
            calls[simId] = subscribe("luna://com.palm.telephony/networkStatusQuery",
                                     JSON.stringify({"simId": n, "subscribe": true}),
                                     function(message) { section._heard(n, message); },
                                     function(error) { section._heard(n, null); }) || null;
        }
        _calls = calls;
    }

    onSimsChanged: _follow()
    onSubscribeChanged: _follow()
    Component.onCompleted: _follow()
    Component.onDestruction: {
        for (var id in _calls) {
            if (_calls[id] && _calls[id].cancel)
                _calls[id].cancel();
        }
    }

    Column {
        width: parent.width

        Repeater {
            model: section.sims

            delegate: Column {
                id: simColumn
                width: parent.width

                readonly property var sim: modelData
                readonly property var rows: section.rowsFor(modelData)

                Label {
                    visible: section.sims.length > 1
                    leftPadding: Units.gu(1)
                    topPadding: index > 0 ? Units.gu(1) : 0
                    text: simColumn.sim.name
                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                }

                Repeater {
                    model: simColumn.rows
                    delegate: Column {
                        width: parent.width

                        HorizontalSeparator {
                            width: parent.width
                            visible: index > 0 || section.sims.length > 1
                        }
                        LabelAndValue {
                            objectName: "phoneInfo-" + simColumn.sim.simId + "-" + modelData.rowLabel
                            width: parent.width
                            label: modelData.rowLabel
                            value: modelData.rowValue
                        }
                    }
                }
            }
        }
    }
}
