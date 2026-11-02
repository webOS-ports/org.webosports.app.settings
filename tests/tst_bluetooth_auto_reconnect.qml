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
import LuneOS.Bluetooth 0.2
import LuneOS.Service 1.0

import "../src/qml/Connectivity"

/*
 * The "Reconnect headsets automatically" switch of the Bluetooth page, and
 * the page telling bluetooth2 about a device the user disconnected, against
 * a stand-in for com.webos.service.bluetooth2/autoReconnect. Run with
 * tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    // bluetooth2's /autoReconnect: answers getStatus once asked (or not at
    // all, for a bluetooth2 without it), and records the rest.
    Component {
        id: fakeLunaComponent
        LunaService {
            property var calls: []
            property var statusSubscriber: null
            property bool refuseSetState: false

            function _answer(fct, response) {
                if (fct)
                    fct({"payload": JSON.stringify(response)});
            }
            function call(uri, args, ok, err) {
                calls.push({"uri": uri, "args": JSON.parse(args)});
                if (uri === "luna://com.webos.service.bluetooth2/autoReconnect/setState") {
                    if (refuseSetState)
                        _answer(err, {"returnValue": false, "errorCode": -1, "errorText": "no"});
                    else
                        _answer(ok, {"returnValue": true, "enabled": JSON.parse(args).enabled});
                }
                else
                    _answer(ok, {"returnValue": true});
            }
            function subscribe(uri, args, ok, err) {
                calls.push({"uri": uri, "args": JSON.parse(args)});
                if (uri === "luna://com.webos.service.bluetooth2/autoReconnect/getStatus")
                    statusSubscriber = ok;
            }
            function sendStatus(enabled) {
                _answer(statusSubscriber, {"returnValue": true, "subscribed": true, "enabled": enabled});
            }
            function callsTo(method) {
                return calls.filter(function (c) {
                    return c.uri === "luna://com.webos.service.bluetooth2/autoReconnect/" + method;
                });
            }
        }
    }

    Component {
        id: pageComponent
        BluetoothPage { anchors.fill: parent }
    }

    TestCase {
        name: "BluetoothAutoReconnect"
        when: windowShown

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

        function findLabel(item, text) {
            // A Label's own text, not a control's
            if (item.text === text && item.checked === undefined)
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findLabel(item.children[i], text);
                if (found)
                    return found;
            }
            return null;
        }

        function findListView(item) {
            if (item.positionViewAtIndex !== undefined)
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findListView(item.children[i]);
                if (found)
                    return found;
            }
            return null;
        }

        // The page's columns place their rows when they are next polished,
        // not as soon as a row appears; let them, before clicking where a
        // row will be.
        function waitForLayout(item) {
            for (var it = item; it; it = it.parent) {
                if (isPolishScheduled(it))
                    waitForPolish(it);
            }
        }

        function makePage() {
            var luna = createTemporaryObject(fakeLunaComponent, root);
            var page = createTemporaryObject(pageComponent, root, {"luna": luna});
            verify(page !== null, "the page did not load");
            return {"page": page, "luna": luna};
        }

        function init() {
            BluetoothManager.discoveringMode = false;
        }

        function test_itAsksBluetooth2ForTheSetting() {
            var t = makePage();
            var asked = t.luna.callsTo("getStatus");
            compare(asked.length, 1);
            compare(asked[0].args.subscribe, true);
        }

        function test_noSwitchUntilBluetooth2Answers() {
            var t = makePage();
            var sw = findByText(t.page, "Reconnect headsets automatically");
            verify(sw !== null, "no switch");
            verify(!sw.visible, "a switch for a setting bluetooth2 has not given");
        }

        function test_theSwitchShowsTheSetting() {
            var t = makePage();
            var sw = findByText(t.page, "Reconnect headsets automatically");
            t.luna.sendStatus(true);
            verify(sw.visible);
            verify(sw.checked);
            t.luna.sendStatus(false);
            verify(!sw.checked, "the switch did not follow bluetooth2");
        }

        function test_turningItOffTellsBluetooth2() {
            var t = makePage();
            t.luna.sendStatus(true);
            var sw = findByText(t.page, "Reconnect headsets automatically");
            tryCompare(sw, "visible", true);
            waitForLayout(sw);
            mouseClick(sw);
            verify(!sw.checked);
            var set = t.luna.callsTo("setState");
            compare(set.length, 1);
            compare(set[0].args.enabled, false);

            waitForLayout(sw);

            mouseClick(sw);
            set = t.luna.callsTo("setState");
            compare(set.length, 2);
            compare(set[1].args.enabled, true);
            verify(sw.checked);
        }

        function test_aChangeFromElsewhereAfterTogglingStillShows() {
            var t = makePage();
            t.luna.sendStatus(true);
            var sw = findByText(t.page, "Reconnect headsets automatically");
            tryCompare(sw, "visible", true);
            waitForLayout(sw);
            mouseClick(sw);	// off, and the binding is gone
            t.luna.sendStatus(true);
            verify(sw.checked, "the switch stopped following bluetooth2");
        }

        function test_aRefusedChangeIsUndone() {
            var t = makePage();
            t.luna.refuseSetState = true;
            t.luna.sendStatus(true);
            var sw = findByText(t.page, "Reconnect headsets automatically");
            tryCompare(sw, "visible", true);
            waitForLayout(sw);
            mouseClick(sw);
            verify(sw.checked, "the switch shows what bluetooth2 did not take");
        }

        function test_disconnectingADeviceMakesBluetooth2ForgetIt() {
            var t = makePage();
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            // luneos-components' stand-in list: the last one is connected.
            var list = findListView(t.page);
            verify(list !== null);
            list.positionViewAtIndex(list.count - 1, ListView.End);
            wait(0);
            var label = findLabel(t.page, "Fake Paired Connected");
            verify(label !== null, "no connected device in the list");
            tryCompare(label, "visible", true);
            waitForLayout(label);
            mouseClick(label);
            var forget = t.luna.callsTo("forget");
            compare(forget.length, 1);
            compare(forget[0].args.address, "33-BB-CC-00-11-22");
        }

        function test_connectingADeviceForgetsNothing() {
            var t = makePage();
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            var label = findLabel(t.page, "Fake Paired");
            verify(label !== null);
            tryCompare(label, "visible", true);
            waitForLayout(label);
            mouseClick(label);
            compare(t.luna.callsTo("forget").length, 0);
        }
    }
}
