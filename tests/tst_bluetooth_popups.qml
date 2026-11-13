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

import "../src/qml/Connectivity"

/*
 * The pairing popups the Bluetooth agent opens. Each used to take its text's
 * width from its own width, while the LuneOS style Popup takes its width from
 * its content plus padding: the two fed each other, the popup grew without end
 * and the app's main thread never came back (a BraX3 pairing a PC, 13 Nov
 * 2026). Run with tests/run-tests.sh; on a tree with that loop, this test
 * never finishes. Needs luneos-components' LuneOSBluetoothRequest stand-in
 * with accept()/reject()/cancel() as functions and the accepted/rejected/
 * canceled signals (its bt-request-standin change on).
 */
Item {
    id: root
    width: 480
    height: 800

    Component { id: requestComponent; LuneOSBluetoothRequest { } }

    Component {
        id: displayPassKey
        BluetoothDisplayPassKeyPopup { deviceName: "herrie-desktop"; passkey: "123456" }
    }
    Component {
        id: displayPinCode
        BluetoothDisplayPinCodePopup { deviceName: "herrie-desktop"; pinCode: "0000" }
    }
    Component {
        id: confirmPassKey
        BluetoothConfirmPassKeyPopup { deviceName: "herrie-desktop"; passkey: "123456" }
    }
    Component {
        id: confirmAuthorize
        BluetoothConfirmAuthorizePopup { deviceName: "herrie-desktop" }
    }
    Component {
        id: authorizeService
        BluetoothAuthorizeServicePopup {
            deviceName: "herrie-desktop"
            serviceUUID: "0000110b-0000-1000-8000-00805f9b34fb"
        }
    }
    Component {
        id: providePassKey
        BluetoothProvidePassKeyPopup { }
    }
    Component {
        id: providePinCode
        BluetoothProvidePinCodePopup { deviceName: "herrie-desktop" }
    }

    SignalSpy { id: acceptSpy; signalName: "accepted" }
    SignalSpy { id: rejectSpy; signalName: "rejected" }
    SignalSpy { id: cancelSpy; signalName: "canceled" }

    TestCase {
        name: "BluetoothPopups"
        when: windowShown

        function findButton(item, text) {
            if (!item)
                return null;
            if (item.text === text && item.hasOwnProperty("clicked"))
                return item;
            var kids = item.children || [];
            for (var i = 0; i < kids.length; i++) {
                var found = findButton(kids[i], text);
                if (found)
                    return found;
            }
            return null;
        }

        function show(component, withRequest) {
            var request = null;
            var props = {};
            if (withRequest) {
                request = createTemporaryObject(requestComponent, root);
                props.bluezRequest = request;
                acceptSpy.clear(); acceptSpy.target = request;
                rejectSpy.clear(); rejectSpy.target = request;
                cancelSpy.clear(); cancelSpy.target = request;
            }
            var popup = createTemporaryObject(component, root, props);
            verify(popup !== null, "the popup did not load");
            tryVerify(function() { return popup.opened; });
            return { popup: popup, request: request };
        }

        function settles(popup) {
            var w = popup.width;
            wait(100);
            compare(popup.width, w, "the popup is still changing width");
            verify(w > 0, "the popup has no width");
            verify(w <= root.width, "the popup is " + w + " wide in a " + root.width + " window");
            verify(popup.x >= 0, "the popup starts left of the window, at " + popup.x);
            verify(popup.height > 0 && popup.height <= root.height,
                   "the popup is " + popup.height + " tall");
        }

        function test_sizes_settle_data() {
            return [
                { tag: "display passkey", component: displayPassKey, request: false },
                { tag: "display pin code", component: displayPinCode, request: false },
                { tag: "confirm passkey", component: confirmPassKey, request: true },
                { tag: "confirm authorize", component: confirmAuthorize, request: true },
                { tag: "authorize service", component: authorizeService, request: true },
                { tag: "provide passkey", component: providePassKey, request: true },
                { tag: "provide pin code", component: providePinCode, request: true }
            ];
        }

        function test_sizes_settle(data) {
            settles(show(data.component, data.request).popup);
        }

        // Each answer goes to bluez once, and the popup closes with it.
        function test_answers_data() {
            return [
                { tag: "authorize: allow", component: confirmAuthorize, button: "Allow", spy: "accept" },
                { tag: "authorize: refuse", component: confirmAuthorize, button: "Refuse", spy: "reject" },
                { tag: "service: authorize", component: authorizeService, button: "Authorize", spy: "accept" },
                { tag: "service: cancel", component: authorizeService, button: "Cancel", spy: "cancel" },
                { tag: "confirm: confirm", component: confirmPassKey, button: "Confirm", spy: "accept" },
                { tag: "confirm: cancel", component: confirmPassKey, button: "Cancel", spy: "cancel" }
            ];
        }

        function test_answers(data) {
            var shown = show(data.component, true);
            var button = findButton(shown.popup.contentItem, data.button);
            verify(button !== null, "no \"" + data.button + "\" button");
            mouseClick(button);
            tryVerify(function() { return !shown.popup.visible; }, 2000, "the popup stayed open");
            compare(acceptSpy.count, data.spy === "accept" ? 1 : 0, "accept");
            compare(rejectSpy.count, data.spy === "reject" ? 1 : 0, "reject");
            compare(cancelSpy.count, data.spy === "cancel" ? 1 : 0, "cancel");
        }

        // The display popups have no request: Close just closes.
        function test_display_close() {
            var popup = show(displayPassKey, false).popup;
            mouseClick(findButton(popup.contentItem, "Close"));
            tryVerify(function() { return !popup.visible; });
        }
    }
}
