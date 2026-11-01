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
import Connman 0.2

import "../src/qml/Connectivity"

/*
 * The Wi-Fi page when a connect does not work, against luneos-components'
 * Connman stand-in (one with connectRequestFailed and a requestDisconnect
 * that disconnects, from its fix-wifi-connect-inprogress change on).
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
        WiFiPage { anchors.fill: parent }
    }

    SignalSpy {
        id: disconnectSpy
        signalName: "serviceDisconnectionStarted"
    }
    SignalSpy {
        id: connectSpy
        signalName: "serviceConnectionStarted"
    }

    TestCase {
        name: "WiFiPage"
        when: windowShown

        property var page: null

        function init() {
            page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            disconnectSpy.clear();
            connectSpy.clear();
        }

        // The row of a network that is not connected ("Someone else's wifi").
        function row() {
            var list = findChild(page, "wifiList");
            verify(list !== null);
            tryVerify(function() { return list.count >= 2; }, 2000);
            // The delegates come with the list's first layout.
            tryVerify(function() { return list.itemAtIndex(1) !== null; }, 2000);
            var item = list.itemAtIndex(1);
            verify(!item.delegateService.connected);
            item.delegateService.connecting = false;
            item.delegateService.lastConnectError = "";
            item.delegateService.error = "";
            disconnectSpy.target = item.delegateService;
            connectSpy.target = item.delegateService;
            return item;
        }

        function popup() {
            var p = findChild(page, "connectProblemPopup");
            verify(p !== null);
            return p;
        }

        function popupChild(name) {
            var c = findChild(popup().contentItem, name);
            verify(c !== null, name);
            return c;
        }

        // connman refused the Connect with InProgress: the page says so and
        // offers to stop, and stopping disconnects the service.
        function test_inProgressOffersToStop() {
            var item = row();
            item.delegateService.lastConnectError = "";     // InProgress, as libconnman-qt has it
            item.delegateService.connectRequestFailed("In progress");
            tryCompare(popup(), "opened", true, 2000);
            verify(popup().busy);
            verify(popupChild("connectProblemText").text.indexOf("earlier attempt") >= 0);
            var stop = popupChild("connectProblemStop");
            verify(stop.visible);
            // The popup sits in the window's overlay; a press is what
            // clicked() stands for.
            stop.clicked();
            compare(disconnectSpy.count, 1, "Stop connecting did not disconnect");
            tryCompare(popup(), "opened", false, 2000);
        }

        function test_keepWaitingLeavesItAlone() {
            var item = row();
            item.delegateService.connectRequestFailed("In progress");
            tryCompare(popup(), "opened", true, 2000);
            popupChild("connectProblemDismiss").clicked();
            tryCompare(popup(), "opened", false, 2000);
            compare(disconnectSpy.count, 0);
        }

        // A tap on a network that is still connecting does not send another
        // Connect (it would only get InProgress); it offers to stop.
        function test_tapWhileConnectingOffersToStop() {
            var item = row();
            item.delegateService.connecting = true;
            mouseClick(item);
            tryCompare(popup(), "opened", true, 2000);
            verify(popup().busy);
            compare(connectSpy.count, 0, "a second Connect was sent");
            compare(item.delegateService.connected, false);
        }

        function test_tapOnAnIdleNetworkConnects() {
            var item = row();
            mouseClick(item);
            compare(connectSpy.count, 1, "no Connect was sent");
            wait(50);
            verify(!popup().opened);
        }

        // Any other failure is put into words, without a Stop button.
        function test_timeoutIsReported() {
            var item = row();
            item.delegateService.lastConnectError = "net.connman.Error.OperationTimeout";
            item.delegateService.connectRequestFailed("Operation timeout");
            tryCompare(popup(), "opened", true, 2000);
            verify(!popup().busy);
            verify(!popupChild("connectProblemStop").visible);
            verify(popupChild("connectProblemText").text.indexOf("took too long") >= 0);
        }

        function test_failureUsesTheServiceError() {
            var item = row();
            item.delegateService.error = "invalid-key";
            item.delegateService.lastConnectError = "net.connman.Error.Failed";
            item.delegateService.connectRequestFailed("Input/output error");
            tryCompare(popup(), "opened", true, 2000);
            verify(popupChild("connectProblemText").text.indexOf("passphrase was not accepted") >= 0);
        }

        function test_unknownFailureKeepsTheMessage() {
            var item = row();
            item.delegateService.lastConnectError = "net.connman.Error.Failed";
            item.delegateService.connectRequestFailed("Input/output error");
            tryCompare(popup(), "opened", true, 2000);
            verify(popupChild("connectProblemText").text.indexOf("Input/output error") >= 0);
        }

        // Cancelling the passphrase prompt, or stopping the attempt, is the
        // user's own doing: nothing to report.
        function test_userCancelIsNotReported() {
            var item = row();
            item.delegateService.lastConnectError = "net.connman.Error.OperationAborted";
            item.delegateService.connectRequestFailed("Operation aborted");
            wait(100);
            verify(!popup().opened);
        }
    }
}
