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
 * The Bluetooth page against luneos-components' stand-ins (its
 * test/imports, LuneOS.Bluetooth's BluetoothManager among them; one with
 * "discovering" and searchAgain(), from luneos-components' bt-discovery-trust
 * change on). Run with tests/run-tests.sh.
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

    TestCase {
        name: "BluetoothPage"
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

        // The page's columns place their rows when they are next polished,
        // not as soon as a row appears; let them, before clicking where a
        // row will be.
        function waitForLayout(item) {
            for (var it = item; it; it = it.parent) {
                if (isPolishScheduled(it))
                    waitForPolish(it);
            }
        }

        function init() {
            BluetoothManager.discoveringMode = false;
            BluetoothManager.btManager.usableAdapter.stopDiscovery();
        }

        function test_thePageSearchesWhileItIsUp() {
            var page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            verify(BluetoothManager.discoveringMode);
            page.destroy();
            wait(0);
            verify(!BluetoothManager.discoveringMode, "the search outlived the page");
        }

        function test_itSaysWhenItIsSearching() {
            var page = createTemporaryObject(pageComponent, root);
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            BluetoothManager.btManager.usableAdapter.startDiscovery();
            var label = findByText(page, "Searching for devices…");
            verify(label !== null && label.visible, "no \"Searching\" while searching");
            var button = findByText(page, "Search again");
            verify(button !== null);
            verify(!button.visible, "\"Search again\" while searching");
        }

        function test_searchAgainOnceItHasStopped() {
            var page = createTemporaryObject(pageComponent, root);
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            BluetoothManager.btManager.usableAdapter.stopDiscovery();
            verify(findByText(page, "Searching for devices…") === null);
            var button = findByText(page, "Search again");
            verify(button !== null && button.visible, "no \"Search again\" once stopped");
            waitForLayout(button);
            mouseClick(button);
            verify(BluetoothManager.discovering, "\"Search again\" did not search");
        }
    }
}
