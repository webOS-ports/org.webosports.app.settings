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
 *
 * The signal in dBm and dB comes from cellInfoQuery, asked every few
 * seconds while the section is on screen: asking keeps the modem measuring,
 * which costs battery, so it is not asked while hidden or in the
 * background. A telephonyd or modem without it shows the bars alone.
 */
GroupBox {
    id: section

    // simListQuery's sims: simId, name, operatorName, bars, powered, ...
    property var sims: []
    // As LunaService.subscribe, giving back a call with cancel()
    property var subscribe: null
    // As LunaService.call
    property var call: null
    // whether the section is on screen; the page's, when it can tell
    property bool shown: visible && Qt.application.state === Qt.ApplicationActive

    // cellInfoQuery's cells per simId, as last heard
    property var cells: ({})

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

    function wfcPreferenceName(preference) {
        switch (preference) {
        case "wifi":      return "Wi-Fi preferred";
        case "cellular":  return "Mobile network preferred";
        case "wifi-only": return "Wi-Fi only";
        default:          return "Unknown";
        }
    }

    function cellTypeName(type) {
        switch (type) {
        case "gsm":   return "GSM";
        case "wcdma": return "UMTS";
        case "lte":   return "LTE";
        case "nr":    return "NR";
        default:      return "";
        }
    }

    // A serving cell's measurements; prefixed with its radio when there are
    // more of them, as LTE and NR at once on 5G NSA
    function cellRows(cell, prefixed) {
        var rows = [];
        var prefix = prefixed && cellTypeName(cell.type) !== "" ? cellTypeName(cell.type) + " " : "";
        if (cell.rssi !== undefined)
            rows.push({"rowLabel": prefix + "RSSI", "rowValue": cell.rssi + " dBm"});
        if (cell.rsrp !== undefined)
            rows.push({"rowLabel": prefix + "RSRP", "rowValue": cell.rsrp + " dBm"});
        if (cell.rsrq !== undefined)
            rows.push({"rowLabel": prefix + "RSRQ", "rowValue": cell.rsrq + " dB"});
        if (cell.sinr !== undefined)
            rows.push({"rowLabel": prefix + "SINR", "rowValue": (Math.round(cell.sinr * 10) / 10) + " dB"});
        return rows;
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
        var serving = cells[sim.simId] || [];
        for (var c = 0; c < serving.length; c++)
            rows = rows.concat(cellRows(serving[c], serving.length > 1));
        rows.push({"rowLabel": "Calls over", "rowValue": callsOver(status)});

        var ims = status.ims;
        if (ims === undefined) {
            rows.push({"rowLabel": "IMS", "rowValue": "Not reported"});
            return rows;
        }
        rows.push({"rowLabel": "IMS", "rowValue": ims.registered ? "Registered" : "Not registered"});
        rows.push({"rowLabel": "IMS over", "rowValue": bearerName(ims)});
        // a setting: shown registered or not, left out where not reported
        if (ims.wfcPreference !== undefined)
            rows.push({"rowLabel": "Wi-Fi calling", "rowValue": wfcPreferenceName(ims.wfcPreference)});
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

    function _heardCells(simId, message) {
        var response = message && message.payload ? JSON.parse(message.payload) : null;
        var copy = Object.assign({}, cells);
        if (response && response.returnValue && response.extended && Array.isArray(response.extended.cells))
            copy[simId] = response.extended.cells;
        else
            delete copy[simId];
        cells = copy;
    }

    function _askCells() {
        if (!call)
            return;
        for (var i = 0; i < sims.length; i++) {
            if (!sims[i].powered)
                continue;
            let n = Number(sims[i].simId);
            call("luna://com.palm.telephony/cellInfoQuery", JSON.stringify({"simId": n}),
                 function(message) { section._heardCells(n, message); },
                 function(error) { section._heardCells(n, null); });
        }
    }

    // telephonyd keeps the modem measuring 30 s after the last time
    Timer {
        id: cellTimer
        interval: 5000
        repeat: true
        triggeredOnStart: true
        running: section.shown && section.call !== null && section.sims.length > 0
        onTriggered: section._askCells()
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
