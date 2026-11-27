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
import LuneOS.Service 1.0

import "../src/qml/Connectivity"

/*
 * The Mobile data and Data roaming switches on the Mobile Network page write
 * com.palm.wan/set for a tap only, not for every getstatus update. They used
 * to write back whatever the subscription told them: telephonyd reported
 * mobile data off while the connection it had just been asked for was still
 * coming up, the page sent that back as a set, and one tap on the Q25 ended
 * disconnected 49 ms after it connected.
 *
 * Against luneos-components' com.palm.wan stand-in, where every set posts a
 * status to every getstatus subscriber: a set the page sends shows up as one
 * more status here than the sets this test sent itself.
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
        NetworkSettingsPage {
            anchors.fill: parent
        }
    }

    // Another client of com.palm.wan, as telephonyd's own updates reach the page.
    LunaService {
        id: other
        name: "org.webosports.tests.networkdata"
    }

    property int statuses: 0
    property var lastStatus: ({})
    function onStatus(message) {
        statuses++;
        lastStatus = JSON.parse(message.payload);
    }
    function ignore(message) {
    }

    TestCase {
        name: "NetworkDataSwitch"
        when: windowShown

        property var page: null

        /*
         * One page for every test: the stand-in never drops a getstatus
         * subscriber, so a page destroyed between tests would still be
         * called for each status after it.
         */
        function initTestCase() {
            other.subscribe("luna://com.palm.wan/getstatus", '{"subscribe": true}', onStatus, ignore);
            page = pageComponent.createObject(root);
            verify(page !== null, "the page did not load");
        }

        function init() {
            // from a known state: data on, roaming guarded
            other.call("luna://com.palm.wan/set", '{"disablewan": "off", "roamguard": "enable"}', ignore, ignore);
            tryCompare(sw("dataUsageSwitch"), "checked", true, 2000);
            tryCompare(sw("roamingAllowedSwitch"), "checked", false, 2000);
            wait(50);
            statuses = 0;
        }

        function cleanupTestCase() {
            page.destroy();
        }

        function sw(name) {
            var s = findChild(page, name);
            verify(s !== null, name);
            return s;
        }

        // An update from the service moves the switch and sends nothing back.
        function test_statusIsNotWrittenBack() {
            other.call("luna://com.palm.wan/set", '{"disablewan": "on"}', ignore, ignore);
            tryCompare(sw("dataUsageSwitch"), "checked", false, 2000);
            wait(50);
            compare(statuses, 1, "the page wrote the status it was sent back to com.palm.wan");

            other.call("luna://com.palm.wan/set", '{"disablewan": "off"}', ignore, ignore);
            tryCompare(sw("dataUsageSwitch"), "checked", true, 2000);
            wait(50);
            compare(statuses, 2, "the page wrote the status it was sent back to com.palm.wan");

            other.call("luna://com.palm.wan/set", '{"roamguard": "disable"}', ignore, ignore);
            tryCompare(sw("roamingAllowedSwitch"), "checked", true, 2000);
            wait(50);
            compare(statuses, 3, "the page wrote the roam guard it was sent back to com.palm.wan");
        }

        // A tap still sets it, once.
        function test_tapSets() {
            mouseClick(sw("dataUsageSwitch"));
            tryCompare(root.lastStatus, "disablewan", "on", 2000);
            wait(50);
            compare(statuses, 1);
            verify(!sw("dataUsageSwitch").checked);

            mouseClick(sw("dataUsageSwitch"));
            tryCompare(root.lastStatus, "disablewan", "off", 2000);
            wait(50);
            compare(statuses, 2);

            mouseClick(sw("roamingAllowedSwitch"));
            tryCompare(root.lastStatus, "roamguard", "disable", 2000);
            wait(50);
            compare(statuses, 3);
            mouseClick(sw("roamingAllowedSwitch"));
            tryCompare(root.lastStatus, "roamguard", "enable", 2000);
        }
    }
}
