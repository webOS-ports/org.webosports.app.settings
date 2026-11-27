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

    Component {
        id: sectionComponent
        PhoneInfoSection {
            width: root.width
            subscribe: root.fakeSubscribe
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
        function test_on_the_page() {
            var page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            var onPage = findChild(page, "phoneInfoSection");
            verify(onPage !== null);
            tryVerify(function() { return onPage.sims.length > 0; }, 2000, "the SIM list");
            compare(onPage.sims, page.sims);
            verify(onPage.visible);
            var simId = onPage.sims[0].simId;
            tryVerify(function() { return onPage.statuses[simId] !== undefined; }, 2000, "networkStatusQuery");
            var row = findChild(onPage, "phoneInfo-" + simId + "-Operator");
            verify(row !== null);
            compare(row.value, "Test Carrier");
            compare(findChild(onPage, "phoneInfo-" + simId + "-IMS").value, "Not reported");
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
