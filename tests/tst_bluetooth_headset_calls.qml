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
import QtTest
import LuneOS.Service 1.0

import "../src/qml/Connectivity"

/*
 * The Bluetooth page's "Headset takes calls" switch, against a LunaService
 * that records what the page asks audiod and lets the test answer: the
 * stand-in in luneos-components' test/imports does not know audiod's
 * getSettings/setSettings. Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    Component {
        id: fakeLunaComponent
        LunaService {
            property var calls: []
            property var subscriptions: []

            function call(serviceURI, jsonArgs, returnFct, handleError) {
                calls.push({"uri": serviceURI, "args": JSON.parse(jsonArgs)});
                if (returnFct)
                    returnFct({"payload": JSON.stringify({"returnValue": true})});
            }
            function subscribe(serviceURI, jsonArgs, returnFct, handleError) {
                subscriptions.push({"uri": serviceURI, "args": JSON.parse(jsonArgs),
                                    "reply": returnFct});
            }
        }
    }

    Component {
        id: pageComponent
        BluetoothPage { anchors.fill: parent }
    }

    TestCase {
        name: "BluetoothHeadsetCalls"
        when: windowShown

        readonly property string getSettingsUri: "luna://org.webosports.service.audio/getSettings"
        readonly property string setSettingsUri: "luna://org.webosports.service.audio/setSettings"
        readonly property string label: "Headset takes calls"

        function findByText(item, text) {
            if (item.text === text)
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findByText(item.children[i], text);
                if (found)
                    return found;
            }
            return null;
        }

        function makePage() {
            var luna = createTemporaryObject(fakeLunaComponent, root);
            var page = createTemporaryObject(pageComponent, root, {"luna": luna});
            verify(page !== null, "the page did not load");
            var sw = findByText(page, label);
            verify(sw !== null, "no \"" + label + "\" switch");
            // The switch sits at the foot of the page's ColumnLayout, the
            // parent of the switch's block; let it place the switch before
            // anything clicks it.
            var block = findChild(page, "headsetCallsBlock");
            verify(block !== null, "no headsetCallsBlock");
            waitForPolish(block.parent);
            return {"page": page, "luna": luna, "sw": sw};
        }

        function settingsSubscription(luna) {
            for (var i = 0; i < luna.subscriptions.length; ++i) {
                if (luna.subscriptions[i].uri === getSettingsUri)
                    return luna.subscriptions[i];
            }
            return null;
        }

        function reply(luna, payload) {
            var sub = settingsSubscription(luna);
            verify(sub !== null, "the page did not subscribe to getSettings");
            verify(sub.args.subscribe === true, "getSettings was not a subscription");
            sub.reply({"payload": JSON.stringify(payload)});
        }

        function setSettingsCalls(luna) {
            return luna.calls.filter(function(c) { return c.uri === setSettingsUri; });
        }

        function test_showsTheValueFromGetSettings_data() {
            return [
                {"tag": "true", "value": true},
                {"tag": "false", "value": false}
            ];
        }
        function test_showsTheValueFromGetSettings(data) {
            var t = makePage();
            reply(t.luna, {"returnValue": true, "subscribed": true,
                           "bluetoothHeadsetTakesCall": data.value});
            compare(t.sw.checked, data.value);
            compare(setSettingsCalls(t.luna).length, 0, "an answer was written back");
        }

        function test_unknownSettingShowsTheDefault_data() {
            return [
                {"tag": "no field", "payload": {"returnValue": true, "subscribed": true}},
                {"tag": "returnValue false", "payload": {"returnValue": false,
                                                         "bluetoothHeadsetTakesCall": false}}
            ];
        }
        function test_unknownSettingShowsTheDefault(data) {
            var t = makePage();
            reply(t.luna, data.payload);
            verify(t.sw.checked, "not at audiod's default (on)");
            verify(t.sw.enabled, "the switch was disabled");
        }

        function test_togglingCallsSetSettings_data() {
            return [
                {"tag": "on to off", "from": true},
                {"tag": "off to on", "from": false}
            ];
        }
        function test_togglingCallsSetSettings(data) {
            var t = makePage();
            reply(t.luna, {"returnValue": true, "subscribed": true,
                           "bluetoothHeadsetTakesCall": data.from});
            mouseClick(t.sw);
            compare(t.sw.checked, !data.from);
            var calls = setSettingsCalls(t.luna);
            compare(calls.length, 1, "setSettings calls");
            compare(JSON.stringify(calls[0].args),
                    JSON.stringify({"bluetoothHeadsetTakesCall": !data.from}));
        }

        function test_subscriptionUpdateMovesTheSwitch() {
            var t = makePage();
            reply(t.luna, {"returnValue": true, "subscribed": true,
                           "bluetoothHeadsetTakesCall": true});
            verify(t.sw.checked);
            reply(t.luna, {"returnValue": true, "bluetoothHeadsetTakesCall": false});
            verify(!t.sw.checked, "an update to off did not move the switch");

            // Also after the user has moved it once, which breaks the binding.
            mouseClick(t.sw);
            verify(t.sw.checked);
            reply(t.luna, {"returnValue": true, "bluetoothHeadsetTakesCall": false});
            verify(!t.sw.checked, "an update after a toggle did not move the switch");
            compare(setSettingsCalls(t.luna).length, 1, "an update was written back");
        }
    }
}
