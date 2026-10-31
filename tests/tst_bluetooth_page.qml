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

        // "No devices found." goes by the list on screen. BluezQt's
        // DevicesModel, the one on the device, has no count, so going by the
        // model said it under a list of devices. Here the list is given its
        // own model, and the page's (the stand-in, which has a count) is
        // emptied, so only the list's count is right.
        function test_noDevicesFoundOnlyWhenTheListIsEmpty() {
            var page = createTemporaryObject(pageComponent, root);
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            BluetoothManager.btManager.usableAdapter.stopDiscovery();
            var list = findByObjectName(page, "deviceList");
            verify(list !== null);
            var pageModel = list.model;
            var shown = createTemporaryQmlObject("import QtQuick; ListModel { ListElement { Address: \"11-22-33-44-55-66\"; Name: \"Headset\"; Paired: true; Connected: false } }", root);
            list.model = shown;
            pageModel.clear();
            // ListView passes a new count on once the event loop has run
            tryCompare(list, "count", 1);
            wait(50);
            compare(pageModel.count, 0);
            verify(findByText(page, "No devices found.") === null, "\"No devices found.\" under a device");
            shown.clear();
            tryVerify(function () {
                var label = findByText(page, "No devices found.");
                return label !== null && label.visible;
            }, 2000, "no \"No devices found.\" with no devices");
        }

        // A separator between devices and none under the last one, going by
        // the list too (BluezQt's DevicesModel has no count, and going by it
        // left the devices with no separators at all).
        function test_separatorsBetweenDevicesOnly() {
            var page = createTemporaryObject(pageComponent, root);
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            var list = findByObjectName(page, "deviceList");
            var pageModel = list.model;
            var shown = createTemporaryQmlObject("import QtQuick; ListModel {" +
                "ListElement { Address: \"11-22-33-44-55-01\"; Name: \"One\"; Paired: true; Connected: false }" +
                "ListElement { Address: \"11-22-33-44-55-02\"; Name: \"Two\"; Paired: false; Connected: false }" +
                "ListElement { Address: \"11-22-33-44-55-03\"; Name: \"Three\"; Paired: true; Connected: true } }", root);
            list.model = shown;
            pageModel.clear();
            tryCompare(list, "count", 3);
            wait(50);
            for (var i = 0; i < 3; ++i) {
                var separator = findByObjectName(list.itemAtIndex(i), "deviceSeparator");
                verify(separator !== null);
                compare(separator.visible, i < 2,
                        i < 2 ? "no separator under device " + i : "a separator under the last device");
            }
            // One fewer: the new last one loses its separator
            shown.remove(2);
            tryCompare(list, "count", 2);
            wait(50);
            verify(findByObjectName(list.itemAtIndex(0), "deviceSeparator").visible);
            verify(!findByObjectName(list.itemAtIndex(1), "deviceSeparator").visible,
                   "a separator under the new last device");
        }
    }
}
