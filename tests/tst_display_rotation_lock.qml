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
import LuneOS.System 1.0

import "../src/qml/General"

/*
 * Display's Rotation Lock switch reads the rotationLock preference: the
 * locked angle, or 400 when the screen follows the sensor. Anything else in
 * the store is not locked - an int took a false as 0, and the switch showed
 * a lock the shell does not keep.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    SystemPreferences { id: writer; keys: ["rotationLock"] }

    // One page for the whole case: luneos-components' preference stub kept
    // talking to destroyed ones until "test/imports: preference
    // subscriptions end, rotationLock is an angle".
    DisplayPage { id: page; anchors.fill: parent }

    TestCase {
        name: "DisplayRotationLock"
        when: windowShown && writer.loaded && page.prefsLoaded

        function store(value) {
            verify(writer.set("rotationLock", value));
        }

        function cleanup() {
            store(400);
            tryCompare(page, "rotationLocked", false);
        }

        function test_an_angle_is_locked() {
            store(90);
            tryCompare(page, "rotationLockAngle", 90);
            compare(page.rotationLocked, true);
            store(0);
            tryCompare(page, "rotationLockAngle", 0);
            compare(page.rotationLocked, true, "upright is a lock too");
        }

        function test_free_is_not_locked() {
            store(90);
            tryCompare(page, "rotationLocked", true);
            store(400);
            tryCompare(page, "rotationLocked", false);
        }

        function test_not_a_number_is_not_locked() {
            store(90);
            tryCompare(page, "rotationLocked", true);
            store(false);
            tryCompare(page, "rotationLocked", false);
            compare(page.rotationLockAngle, page.rotationUnlocked);
        }
    }
}
