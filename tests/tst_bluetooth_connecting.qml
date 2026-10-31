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
import LunaNext.Common 0.1

import "../src/qml/Connectivity"

/*
 * The spinner a device's row of the Bluetooth page shows while a connect or
 * disconnect is under way: until the device reports the state asked for,
 * BlueZ fails the call, or the timeout passes. Rows are tapped; what they
 * call is a stand-in for BluetoothManager's connect and disconnect that
 * hands back stand-ins for BluezQt's PendingCall (finished(call), error,
 * errorText), as luneos-components' BluetoothManager stand-in returns none.
 * The devices are its BluetoothDevicesModel stand-in, a ListModel:
 *   0 "" (address only), 1 "Fake", 2 "Fake Paired",
 *   3 "Fake Connected", 4 "Fake Paired Connected".
 * Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    Component {
        id: pageComponent
        BluetoothPage { anchors.fill: parent }
    }

    Component {
        id: pendingCallComponent
        QtObject {
            property int error: 0
            property string errorText: ""
            signal finished(var call)
        }
    }

    // BluetoothManager's connectDeviceAddress()/disconnectDeviceAddress():
    // each returns a new call (or none, with startsCalls off), kept in
    // lastCall; connectingDevice is what a second tap would stop.
    Component {
        id: managerComponent
        QtObject {
            property QtObject connectingDevice: null
            property bool startsCalls: true
            property var lastCall: null
            property var requests: []
            function _call(what) {
                requests = requests.concat([what]);
                lastCall = startsCalls ? pendingCallComponent.createObject(root) : null;
                return lastCall;
            }
            function connectDeviceAddress(address) { return _call("connect " + address); }
            function disconnectDeviceAddress(address) { return _call("disconnect " + address); }
        }
    }

    TestCase {
        name: "BluetoothConnecting"
        when: windowShown

        property var page
        property var manager

        function findByObjectName(item, name) {
            if (item.objectName === name)
                return item;
            for (var i = 0; i < item.children.length; ++i) {
                var found = findByObjectName(item.children[i], name);
                if (found)
                    return found;
            }
            return null;
        }
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
        function waitForLayout(item) {
            for (var it = item; it; it = it.parent) {
                if (isPolishScheduled(it))
                    waitForPolish(it);
            }
        }

        function list() { return findByObjectName(page, "deviceList"); }
        function row(i) { return list().itemAtIndex(i); }
        function spinner(i) { return findByObjectName(row(i), "deviceBusyIndicator"); }
        function mark(i) { return findByObjectName(row(i), "deviceConnectedMark"); }
        function address(i) { return list().model.get(i).Address; }
        function setConnected(i, connected) { list().model.setProperty(i, "Connected", connected); }
        // Tap row i, near its name; returns the call it started
        function tap(i) {
            waitForLayout(row(i));
            mouseClick(row(i), Units.gu(4), row(i).height / 2);
            return manager.lastCall;
        }

        function init() {
            BluetoothManager.discoveringMode = false;
            BluetoothManager.btManager.usableAdapter.stopDiscovery();
            page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            manager = createTemporaryObject(managerComponent, root);
            page.deviceManager = manager;
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            tryVerify(function () { return list().count === 5 && row(4) !== null; }, 2000);
        }

        function test_aRowSpinsWhileItsDeviceConnects() {
            verify(!spinner(1).running, "a spinner before any tap");
            tap(1);
            verify(spinner(1).running, "no spinner while connecting");
            verify(spinner(1).visible);
            verify(!spinner(2).running, "another row spins too");
            setConnected(1, true);
            verify(!spinner(1).running, "still spinning once connected");
            compare(mark(1).opacity, 1, "no check mark once connected");
        }

        function test_aFailedConnectStopsAndSaysSo() {
            var call = tap(2);
            verify(spinner(2).running);
            call.error = 1;
            call.errorText = "org.bluez.Error.Failed";
            call.finished(call);
            verify(!spinner(2).running, "still spinning after the call failed");
            compare(mark(2).opacity, 0, "a check mark for a device that did not connect");
            var message = findByText(page, "Unable to connect.");
            verify(message !== null && message.visible, "no \"Unable to connect.\"");
            page.deviceMessageMs = 100;
            tryVerify(function () { return findByText(page, "Unable to connect.") === null; }, 2000,
                      "\"Unable to connect.\" stays");
        }

        function test_aCallThatWentThroughWaitsForTheDevice() {
            var call = tap(1);
            call.finished(call);
            verify(spinner(1).running, "stopped before the device said it was connected");
            verify(findByText(page, "Unable to connect.") === null);
            setConnected(1, true);
            verify(!spinner(1).running);
        }

        function test_noAnswerStopsAfterTheTimeout() {
            page.deviceOperationTimeoutMs = 300;
            tap(1);
            verify(spinner(1).running);
            tryCompare(spinner(1), "running", false, 3000, "spins past the timeout");
            verify(findByText(page, "Unable to connect.") === null, "a timeout is not a failure");
        }

        function test_aRowSpinsWhileItsDeviceDisconnects() {
            compare(mark(3).opacity, 1);
            tap(3);
            verify(spinner(3).running, "no spinner while disconnecting");
            compare(mark(3).opacity, 0, "the check mark shows under the spinner");
            setConnected(3, false);
            verify(!spinner(3).running, "still spinning once disconnected");
            compare(mark(3).opacity, 0);
        }

        function test_aFailedDisconnectSaysSo() {
            var call = tap(4);
            call.error = 1;
            call.finished(call);
            verify(!spinner(4).running);
            compare(mark(4).opacity, 1, "no check mark on a device still connected");
            verify(findByText(page, "Unable to disconnect.") !== null);
        }

        function test_aTapConnectsOrDisconnects() {
            tap(1);
            tap(3);
            compare(manager.requests, ["connect " + address(1), "disconnect " + address(3)]);
        }

        function test_nothingStartedNothingSpins() {
            manager.startsCalls = false;
            tap(1);
            verify(!spinner(1).running, "spins for a call BluetoothManager did not make");
        }

        // BluetoothManager drops the device it was connecting when another
        // one is tapped; the first one's failing call says nothing.
        function test_aSecondConnectReplacesTheFirst() {
            var first = tap(1);
            tap(2);
            verify(!spinner(1).running, "the dropped device still spins");
            verify(spinner(2).running, "the device tapped last does not spin");
            first.error = 1;
            first.finished(first);
            verify(findByText(page, "Unable to connect.") === null,
                   "\"Unable to connect.\" for a connect that was dropped");
            verify(spinner(2).running, "the dropped call stopped the other device");
        }

        // A second tap on the device BluetoothManager is connecting stops it
        // (BluetoothManager disconnects it, and hands back that call).
        function test_aSecondTapStopsTheConnect() {
            tap(2);
            manager.connectingDevice = createTemporaryQmlObject(
                        "import QtQuick; QtObject { property string address: \"" + address(2) + "\" }", root);
            tap(2);
            compare(manager.requests.length, 2);
            verify(!spinner(2).running, "still spinning after the connect was stopped");
        }

        function test_theRowKeepsItsPlaceWhileSpinning() {
            waitForLayout(row(3));
            var label = findByText(row(3), "Fake Connected");
            var h = row(3).height, w = label.width;
            var mx = mark(3).mapToItem(row(3), 0, 0).x;
            tap(3);
            waitForLayout(row(3));
            compare(row(3).height, h, "the row changed height");
            compare(label.width, w, "the name moved");
            var s = spinner(3);
            var c = s.mapToItem(row(3), s.width / 2, s.height / 2);
            fuzzyCompare(c.x, mx + mark(3).width / 2, 1, "the spinner is not where the check mark was");
            // The ring, inside the control's padding
            verify((s.width - s.leftPadding - s.rightPadding) * s.scale <= mark(3).width + 1,
                   "the spinner is wider than the check mark");
            verify((s.height - s.topPadding - s.bottomPadding) * s.scale <= mark(3).height + 1,
                   "the spinner is taller than the check mark");
        }

        // The spinner takes no taps: one on it reaches the row (a second tap
        // stops a connect), and the other rows and the rest of the page go
        // on taking theirs.
        function test_theSpinnerDoesNotTakeTaps() {
            tap(3);
            waitForLayout(row(3));
            var spy3 = createTemporaryQmlObject("import QtTest; SignalSpy { signalName: \"clicked\" }", root);
            spy3.target = findByObjectName(row(3), "deviceRowMouseArea");
            var spy2 = createTemporaryQmlObject("import QtTest; SignalSpy { signalName: \"clicked\" }", root);
            spy2.target = findByObjectName(row(2), "deviceRowMouseArea");
            var s = spinner(3);
            mouseClick(s, s.width / 2, s.height / 2);
            compare(spy3.count, 1, "a tap on the spinner did not reach its row");
            var p = row(3).mapToItem(row(2), row(3).width - 10, -2);
            mouseClick(row(2), p.x, p.y);
            compare(spy2.count, 1, "a tap on the row above did not reach it");

            BluetoothManager.btManager.usableAdapter.stopDiscovery();
            var button = findByText(page, "Search again");
            waitForLayout(button);
            mouseClick(button);
            verify(BluetoothManager.discovering, "\"Search again\" did not take its tap");
        }
    }
}
