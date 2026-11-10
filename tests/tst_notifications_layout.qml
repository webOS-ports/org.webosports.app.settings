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
import LuneOS.System 1.0

import "../src/qml/General"

/*
 * Settings > Notifications, Look & Position: the three preferences the shell's
 * NotificationLayout reads, against the mock preference store from
 * luneos-components, which keeps what is written and tells every subscriber.
 * Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    // The shell's side of the store
    SystemPreferences {
        id: shell
        keys: ["notificationStyle", "notificationLocationPortrait", "notificationLocationLandscape"]
    }

    // The notification and application managers, which this part of the page
    // does not need: they do not answer.
    Component {
        id: serviceComponent
        LunaService {
            function call(uri, args, ok, err) {}
            function subscribe(uri, args, ok, err) {}
        }
    }

    Component {
        id: pageComponent
        NotificationsPage { anchors.fill: parent }
    }

    TestCase {
        name: "NotificationsLayout"
        when: windowShown

        function init() {
            tryVerify(() => shell.loaded);
            shell.setMany({ "notificationStyle": "auto",
                            "notificationLocationPortrait": "auto",
                            "notificationLocationLandscape": "auto" });
            tryCompare(shell.values, "notificationStyle", "auto");
            tryCompare(shell.values, "notificationLocationLandscape", "auto");
        }

        // Kept, hidden, once a test is done with them rather than destroyed:
        // the mock store has no way to hear that a subscriber went away, and
        // calls a destroyed page's back. On the device the LunaService
        // cancels its calls as it goes.
        property var pages: []

        function cleanup() {
            for (var i = 0; i < pages.length; i++)
                pages[i].visible = false;
        }

        // What a row shows: the entry its dropdown has selected
        function shown(page, name) {
            var row = findChild(page, name);
            return row.currentIndex < 0 ? "" : row.model[row.currentIndex];
        }

        // Choosing as a finger does: the dropdown's own ComboBox reports it
        function choose(page, name, label) {
            var row = findChild(page, name);
            var combo = null;
            for (var i = 0; i < row.children.length; i++) {
                if (row.children[i].hasOwnProperty("popup"))
                    combo = row.children[i];
            }
            verify(combo !== null, "no dropdown in " + name);
            var index = row.model.indexOf(label);
            verify(index >= 0, label + " is not on offer");
            combo.currentIndex = index;
            combo.activated(index);
        }

        function makePage() {
            var page = pageComponent.createObject(root,
                                                  { "luna": serviceComponent.createObject(root) });
            verify(page !== null, "the page did not load");
            pages.push(page);
            return page;
        }

        function test_automaticUntilChosen() {
            var page = makePage();
            tryVerify(() => page.ledPrefsLoaded);
            compare(shown(page, "notificationStyle"), "Automatic");
            compare(shown(page, "notificationLocationPortrait"), "Automatic");
            compare(shown(page, "notificationLocationLandscape"), "Automatic");
        }

        function test_showsWhatIsStored() {
            shell.setMany({ "notificationStyle": "tablet",
                            "notificationLocationLandscape": "top" });
            var page = makePage();
            tryVerify(() => shown(page, "notificationStyle") === "Tablet");
            compare(shown(page, "notificationLocationPortrait"), "Automatic");
            compare(shown(page, "notificationLocationLandscape"), "Top");
        }

        function test_somethingNotOnOfferIsAutomatic() {
            shell.setMany({ "notificationStyle": "watch",
                            "notificationLocationPortrait": 3 });
            var page = makePage();
            tryCompare(page, "notificationStyle", "auto");
            compare(page.notificationLocationPortrait, "auto");
            compare(shown(page, "notificationStyle"), "Automatic");
        }

        function test_choosingWritesThePreference() {
            var page = makePage();
            tryVerify(() => page.ledPrefsLoaded);
            choose(page, "notificationStyle", "Phone");
            tryCompare(shell.values, "notificationStyle", "phone");
            compare(shown(page, "notificationStyle"), "Phone");

            choose(page, "notificationLocationLandscape", "Bottom");
            tryCompare(shell.values, "notificationLocationLandscape", "bottom");
            compare(shown(page, "notificationLocationLandscape"), "Bottom");
            // the other way round is left as it was
            compare(shell.values.notificationLocationPortrait, "auto");
            compare(shown(page, "notificationLocationPortrait"), "Automatic");
        }

        function test_aChangeElsewhereShows() {
            var page = makePage();
            tryVerify(() => page.ledPrefsLoaded);
            shell.set("notificationLocationPortrait", "top");
            tryVerify(() => shown(page, "notificationLocationPortrait") === "Top");
        }

        // The keys and values the shell's NotificationLayout knows
        // (luna-next-cardshell qml/Utils/NotificationLayout.qml).
        function test_everyChoiceIsOneTheShellKnows() {
            var page = makePage();
            var styles = page.styleChoices.map(c => c.key);
            var places = page.locationChoices.map(c => c.key);
            compare(styles.sort().join(), "auto,phone,tablet");
            compare(places.sort().join(), "auto,bottom,top");
        }
    }
}
