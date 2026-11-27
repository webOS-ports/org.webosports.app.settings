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

import QtQuick
import QtQuick.Controls.LuneOS
import QtTest

import "../src/qml/Connectivity"

/*
 * The Mobile Network page's phone information: per SIM, what telephonyd's
 * networkStatusQuery says about the registration and IMS, against a fake
 * subscribe that answers as telephonyd does. Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // simId -> { reply: fn, cancelled: bool, args: object }
    property var subscriptions: ({})
    property int subscribeCount: 0

    function fakeSubscribe(uri, json, onReply, onError) {
        var args = JSON.parse(json);
        var entry = { "uri": uri, "args": args, "reply": onReply, "error": onError, "cancelled": false };
        var copy = Object.assign({}, subscriptions);
        copy[args.simId] = entry;
        subscriptions = copy;
        subscribeCount++;
        return { "cancel": function() { entry.cancelled = true; } };
    }

    // cellInfoQuery calls as made: { uri, args, reply, error }
    property var calls: []

    function fakeCall(uri, json, onReply, onError) {
        calls = calls.concat([{ "uri": uri, "args": JSON.parse(json), "reply": onReply, "error": onError }]);
    }

    Component {
        id: sectionComponent
        PhoneInfoSection {
            width: root.width
            subscribe: root.fakeSubscribe
            call: root.fakeCall
            // the test window is not an active application to Qt
            shown: false
        }
    }

    Component {
        id: pageComponent
        NetworkSettingsPage {
            anchors.fill: parent
            apnDatabase: Qt.resolvedUrl("data/provision-test.json")
        }
    }

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    TestCase {
        name: "PhoneInfo"
        when: windowShown

        property var section: null

        function init() {
            root.subscriptions = {};
            root.subscribeCount = 0;
            root.calls = [];
            section = createTemporaryObject(sectionComponent, root);
            verify(section !== null, "the section did not load");
        }

        function sim(simId, extra) {
            var s = { "simId": simId, "name": "SIM " + (simId + 1), "operatorName": "Op" + simId,
                      "powered": true, "bars": 3 };
            for (var k in extra)
                s[k] = extra[k];
            return s;
        }

        function answer(simId, extended) {
            var sub = root.subscriptions[simId];
            verify(sub !== undefined, "no subscription for SIM " + simId);
            sub.reply({ "payload": JSON.stringify({ "returnValue": true, "extended": extended }) });
        }

        function registered(extra) {
            var e = { "state": "service", "registration": "home", "networkName": "Lebara",
                      "technology": "lte", "volte": true, "vowifi": false,
                      "ims": { "registered": true, "voiceCapable": true, "smsCapable": true,
                               "bearer": "cellular" } };
            for (var k in extra)
                e[k] = extra[k];
            return e;
        }

        function value(simId, label) {
            var row = findChild(section, "phoneInfo-" + simId + "-" + label);
            return row === null ? null : row.value;
        }

        function test_hidden_without_sims() {
            verify(!section.visible);
            compare(root.subscribeCount, 0);
        }

        function test_one_subscription_per_sim() {
            section.sims = [sim(0), sim(1)];
            compare(root.subscribeCount, 2);
            compare(root.subscriptions[0].uri, "luna://com.palm.telephony/networkStatusQuery");
            compare(root.subscriptions[0].args.subscribe, true);
            compare(root.subscriptions[1].args.simId, 1);

            // The list again, as every signal change reposts it: no new ones
            section.sims = [sim(0, {"bars": 4}), sim(1)];
            compare(root.subscribeCount, 2);

            // SIM 2 gone: its subscription ends
            section.sims = [sim(0)];
            verify(root.subscriptions[1].cancelled);
            verify(!root.subscriptions[0].cancelled);
        }

        function test_vowifi() {
            section.sims = [sim(0)];
            verify(section.visible);
            compare(value(0, "Network"), "Not reported");

            answer(0, registered({ "vowifi": true,
                "ims": { "registered": true, "voiceCapable": true, "smsCapable": false, "bearer": "wifi" } }));
            compare(value(0, "Operator"), "Lebara");
            compare(value(0, "Network"), "LTE (4G)");
            compare(value(0, "Signal"), "3/5");
            compare(value(0, "Calls over"), "Wi-Fi (VoWiFi)");
            compare(value(0, "IMS"), "Registered");
            compare(value(0, "IMS over"), "Wi-Fi");
            compare(value(0, "Voice over IMS"), "Yes");
            compare(value(0, "SMS over IMS"), "No");
        }

        function test_volte_and_changes() {
            section.sims = [sim(0)];
            answer(0, registered());
            compare(value(0, "Calls over"), "Mobile network (VoLTE)");
            compare(value(0, "IMS over"), "Mobile network");

            // Onto 5G, then IMS lost
            answer(0, registered({ "technology": "nr" }));
            compare(value(0, "Network"), "NR (5G)");
            answer(0, registered({ "technology": "umts", "volte": false,
                "ims": { "registered": false, "voiceCapable": false, "smsCapable": false, "bearer": "" } }));
            compare(value(0, "Network"), "UMTS (3G)");
            compare(value(0, "Calls over"), "2G/3G");
            compare(value(0, "IMS"), "Not registered");
            compare(value(0, "IMS over"), "Not registered");
        }

        // Each answer lands on its own SIM
        function test_two_sims_apart() {
            section.sims = [sim(0), sim(1)];
            answer(1, registered({ "networkName": "Other", "vowifi": true,
                "ims": { "registered": true, "voiceCapable": true, "smsCapable": true, "bearer": "wifi" } }));
            answer(0, registered());
            compare(value(0, "Operator"), "Lebara");
            compare(value(1, "Operator"), "Other");
            compare(value(0, "IMS over"), "Mobile network");
            compare(value(1, "IMS over"), "Wi-Fi");
        }

        // A telephonyd from before IMS was reported
        function test_older_telephonyd() {
            section.sims = [sim(0)];
            answer(0, { "state": "service", "registration": "home", "networkName": "Lebara" });
            compare(value(0, "Network"), "Not reported");
            compare(value(0, "Calls over"), "2G/3G");
            compare(value(0, "IMS"), "Not reported");
            compare(value(0, "IMS over"), null);
        }

        // Registered with IMS on stock ofono: the bearer cannot be told
        function test_bearer_unknown() {
            section.sims = [sim(0)];
            answer(0, registered({ "ims": { "registered": true, "voiceCapable": true,
                                            "smsCapable": true, "bearer": "" } }));
            compare(value(0, "IMS over"), "Unknown");
        }

        function test_no_service_and_sim_off() {
            section.sims = [sim(0), sim(1, {"powered": false})];
            answer(0, registered({ "state": "noservice", "networkName": "", "volte": false,
                "ims": { "registered": false, "voiceCapable": false, "smsCapable": false, "bearer": "" } }));
            compare(value(0, "Network"), "No service");
            compare(value(0, "Calls over"), "No service");
            compare(value(0, "Operator"), "Op0");
            compare(value(1, "Network"), "SIM off");
            compare(value(1, "IMS"), null);
        }

        function test_failed_query_forgets() {
            section.sims = [sim(0)];
            answer(0, registered());
            compare(value(0, "IMS"), "Registered");
            root.subscriptions[0].reply({ "payload": JSON.stringify({ "returnValue": false }) });
            compare(value(0, "Network"), "Not reported");
            compare(value(0, "IMS"), null);
        }

        // On the page, from the SIM list to luneos-components' stand-in
        // telephonyd, whose networkStatusQuery knows nothing of IMS
        // the Dual SIM section's line under each slot's name
        function test_sim_summary() {
            var page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            // an empty slot: telephonyd has no operator or bars for it
            compare(page.simSummary({"simId": 0, "name": "SIM 1", "present": false, "bars": 0}), "No SIM");
            compare(page.simSummary({"simId": 0, "name": "SIM 1", "present": false,
                                     "operatorName": "Stale", "bars": 3}), "No SIM");
            // a SIM without a network
            compare(page.simSummary({"simId": 1, "name": "SIM 2", "present": true, "bars": 0}), "No service");
            compare(page.simSummary({"simId": 1, "name": "SIM 2", "present": true,
                                     "operatorName": "", "bars": 0}), "No service");
            // a SIM on a network
            compare(page.simSummary({"simId": 1, "name": "SIM 2", "present": true,
                                     "operatorName": "simyo", "bars": 2}), "simyo \u00b7 2/5");
            compare(page.simSummary({"simId": 1, "name": "SIM 2", "present": true,
                                     "operatorName": "simyo"}), "simyo \u00b7 0/5");
            // a telephonyd that does not say whether a SIM is there
            compare(page.simSummary({"simId": 1, "name": "SIM 2",
                                     "operatorName": "simyo", "bars": 2}), "simyo \u00b7 2/5");

            // what the section shows for the stand-in's SIMs
            tryVerify(function() { return page.sims.length > 0; }, 2000, "the SIM list");
            for (var i = 0; i < page.sims.length; i++) {
                var label = findChild(page, "dualSimSummary-" + page.sims[i].simId);
                verify(label !== null, "no summary for SIM " + page.sims[i].simId);
                compare(label.text, page.simSummary(page.sims[i]));
                verify(label.text.indexOf("undefined") < 0, label.text);
            }

            // the Brax3's slots: SIM 1 empty, SIM 2 on a network
            page.sims = [{"simId": 0, "name": "SIM 1", "present": false, "bars": 0},
                         {"simId": 1, "name": "SIM 2", "present": true,
                          "operatorName": "simyo", "bars": 2}];
            tryCompare(findChild(page, "dualSimSummary-0"), "text", "No SIM");
            tryCompare(findChild(page, "dualSimSummary-1"), "text", "simyo \u00b7 2/5");
        }

        function test_on_the_page() {
            var page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            var onPage = findChild(page, "phoneInfoSection");
            verify(onPage !== null);
            tryVerify(function() { return onPage.sims.length > 0; }, 2000, "the SIM list");
            compare(onPage.sims, page.sims);
            verify(onPage.visible);
            // the page's LunaService, for cellInfoQuery
            verify(typeof onPage.call === "function", "no call for cellInfoQuery");
            var simId = onPage.sims[0].simId;
            tryVerify(function() { return onPage.statuses[simId] !== undefined; }, 2000, "networkStatusQuery");
            var row = findChild(onPage, "phoneInfo-" + simId + "-Operator");
            verify(row !== null);
            compare(row.value, "Test Carrier");
            compare(findChild(onPage, "phoneInfo-" + simId + "-IMS").value, "Not reported");

            // the page follows telephonyd on the bus
            tryVerify(function() { return page.telephonyStatus.known; }, 2000, "telephonyd's status");
            verify(onPage.serviceAvailable);

            // telephonyd goes: the section lets go of what it heard
            var oldSims = page.sims;
            compare(page._telephonyCalls.length, 2);
            page.telephonyStatus._available = false;
            verify(!onPage.serviceAvailable);
            verify(page.telephonyStatus.wentAway);
            compare(onPage.statuses[simId], undefined);

            // back: the page asks again, the SIM list comes anew (the
            // stand-in answers at once), and the section subscribes afresh
            page.telephonyStatus._available = true;
            verify(onPage.serviceAvailable);
            verify(!page.telephonyStatus.wentAway);
            tryVerify(function() { return page.sims !== oldSims; }, 2000, "the SIM list asked again");
            compare(page.sims.length, oldSims.length);
            tryVerify(function() { return onPage.statuses[simId] !== undefined; }, 2000, "networkStatusQuery again");

            // and not when it was there all along
            oldSims = page.sims;
            page.telephonyStatus.availableChanged();
            wait(100);
            verify(page.sims === oldSims);
        }

        // The Brax3's: Wi-Fi preferred while on LTE
        function test_wfc_preference() {
            section.sims = [sim(0)];
            answer(0, registered());
            // from an extension without it: not shown
            compare(value(0, "Wi-Fi calling"), null);

            var names = { "wifi": "Wi-Fi preferred", "cellular": "Mobile network preferred",
                          "wifi-only": "Wi-Fi only", "": "Unknown", "later": "Unknown" };
            for (var preference in names) {
                answer(0, registered({ "ims": { "registered": true, "voiceCapable": true, "smsCapable": true,
                                                "bearer": "cellular", "wfcPreference": preference } }));
                compare(value(0, "Wi-Fi calling"), names[preference], preference);
            }

            // a setting: shown while IMS is not registered too
            answer(0, registered({ "volte": false, "ims": { "registered": false, "voiceCapable": false,
                "smsCapable": false, "bearer": "", "wfcPreference": "wifi-only" } }));
            compare(value(0, "IMS"), "Not registered");
            compare(value(0, "Wi-Fi calling"), "Wi-Fi only");
        }

        function answerCells(index, cells) {
            root.calls[index].reply({ "payload": JSON.stringify({ "returnValue": true,
                "extended": { "simId": root.calls[index].args.simId, "cells": cells } }) });
        }

        // The Brax3's serving LTE cell, as telephonyd converts it
        function test_signal_values() {
            section.sims = [sim(0), sim(1, {"powered": false})];
            answer(0, registered());
            compare(root.calls.length, 0, "asked while not on screen");

            section.shown = true;
            // at once, for the powered SIM only
            tryVerify(function() { return root.calls.length === 1; }, 1000, "cellInfoQuery");
            compare(root.calls[0].uri, "luna://com.palm.telephony/cellInfoQuery");
            compare(root.calls[0].args.simId, 0);
            compare(value(0, "RSRP"), null);

            answerCells(0, [{ "type": "lte", "rssi": -91, "rsrp": -98, "rsrq": -7, "sinr": 0 }]);
            compare(value(0, "Signal"), "3/5");
            compare(value(0, "RSSI"), "-91 dBm");
            compare(value(0, "RSRP"), "-98 dBm");
            compare(value(0, "RSRQ"), "-7 dB");
            compare(value(0, "SINR"), "0 dB");

            // and again while shown
            tryVerify(function() { return root.calls.length >= 2; }, 7000, "asked again");
            // LTE and NR at once, NR without SINR; the measurements follow the signal row
            answerCells(1, [{ "type": "lte", "rsrp": -101 }, { "type": "nr", "rsrp": -88, "rsrq": -11, "sinr": 12.5 }]);
            compare(value(0, "RSRP"), null);
            compare(value(0, "LTE RSRP"), "-101 dBm");
            compare(value(0, "NR RSRP"), "-88 dBm");
            compare(value(0, "NR RSRQ"), "-11 dB");
            compare(value(0, "NR SINR"), "12.5 dB");
            compare(value(0, "LTE SINR"), null);

            // off screen: no more asking
            section.shown = false;
            var asked = root.calls.length;
            wait(5500);
            compare(root.calls.length, asked);

            // a failed query, or none from an older telephonyd: bars alone
            root.calls[asked - 1].error({});
            compare(value(0, "NR RSRP"), null);
            compare(value(0, "Signal"), "3/5");
        }

        // A modem that reports no cells, or values it did not measure
        function test_signal_partial() {
            section.sims = [sim(0)];
            answer(0, registered());
            section.shown = true;
            tryVerify(function() { return root.calls.length === 1; }, 1000, "cellInfoQuery");
            answerCells(0, []);
            compare(value(0, "RSRP"), null);
            answerCells(0, [{ "type": "gsm", "rssi": -73 }]);
            compare(value(0, "RSSI"), "-73 dBm");
            compare(value(0, "RSRP"), null);
            root.calls[0].reply({ "payload": JSON.stringify({ "returnValue": false }) });
            compare(value(0, "RSSI"), null);
        }

        // telephonyd restarts: its subscriptions end, and are made again
        // once it is back on the bus
        function test_service_restart() {
            section.sims = [sim(0), sim(1)];
            answer(0, registered());
            answer(1, registered({ "networkName": "Other" }));
            var before = root.subscriptions;
            compare(root.subscribeCount, 2);

            // gone: nothing left of what it said, the subscriptions ended
            section.serviceAvailable = false;
            compare(value(0, "Network"), "Not reported");
            compare(value(1, "Operator"), null);
            verify(before[0].cancelled);
            verify(before[1].cancelled);
            compare(root.subscribeCount, 2);

            // back: subscribed afresh, one per SIM, and its answers count
            section.serviceAvailable = true;
            compare(root.subscribeCount, 4);
            verify(root.subscriptions[0] !== before[0]);
            verify(!root.subscriptions[0].cancelled);
            compare(root.subscriptions[1].args.simId, 1);
            answer(0, registered({ "vowifi": true,
                "ims": { "registered": true, "voiceCapable": true, "smsCapable": true, "bearer": "wifi" } }));
            compare(value(0, "Calls over"), "Wi-Fi (VoWiFi)");

            // available again without having gone: nothing new
            section.serviceAvailable = true;
            compare(root.subscribeCount, 4);
        }

        // The hub ends a subscription with an error when the service goes,
        // or the page opened before telephonyd was up: subscribe again once
        // it is there
        function test_subscription_error_then_back() {
            section.sims = [sim(0)];
            answer(0, registered());
            root.subscriptions[0].error({ "payload": "{}" });
            compare(value(0, "Network"), "Not reported");
            compare(root.subscribeCount, 1);

            section.serviceAvailable = false;
            section.serviceAvailable = true;
            compare(root.subscribeCount, 2);
            answer(0, registered());
            compare(value(0, "IMS"), "Registered");
        }

        // The cells go with the service, and are asked again after
        function test_service_restart_cells() {
            section.sims = [sim(0)];
            answer(0, registered());
            section.shown = true;
            tryVerify(function() { return root.calls.length === 1; }, 1000, "cellInfoQuery");
            answerCells(0, [{ "type": "lte", "rsrp": -98 }]);
            compare(value(0, "RSRP"), "-98 dBm");

            section.serviceAvailable = false;
            compare(value(0, "RSRP"), null);

            // back, registered again: no cells from before the restart
            section.serviceAvailable = true;
            answer(0, registered());
            compare(value(0, "Network"), "LTE (4G)");
            compare(value(0, "RSRP"), null);
        }

        function test_destruction_cancels() {
            section.sims = [sim(0), sim(1)];
            var subs = root.subscriptions;
            section.destroy();
            wait(0);
            verify(subs[0].cancelled);
            verify(subs[1].cancelled);
        }
    }
}
