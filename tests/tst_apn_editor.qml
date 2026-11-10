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

import "../src/qml/Connectivity"

/*
 * Adding, editing and removing access points on the Mobile Network page,
 * against luneos-components' QOfono stand-in (one with addContext,
 * removeContext, contextAdded, reportError and the MMS fields, from its
 * ofono-mock-apn change on). The stand-in keeps its contexts in one shared
 * script, so every test looks its contexts up by path rather than assuming
 * what an earlier test left. Run with tests/run-tests.sh.
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
        NetworkSettingsPage { anchors.fill: parent }
    }

    SignalSpy {
        id: addedSpy
        signalName: "contextAdded"
    }
    SignalSpy {
        id: removedSpy
        signalName: "contextRemoved"
    }

    TestCase {
        name: "ApnEditor"
        when: windowShown

        property var page: null

        function init() {
            page = createTemporaryObject(pageComponent, root);
            verify(page !== null, "the page did not load");
            addedSpy.target = connMan();
            removedSpy.target = connMan();
            addedSpy.clear();
            removedSpy.clear();
        }

        function connMan() {
            var c = findChild(page, "apnConnMan");
            verify(c !== null);
            return c;
        }

        function popup() {
            var p = findChild(page, "apnEditPopup");
            verify(p !== null);
            return p;
        }

        function child(name) {
            var c = findChild(popup().contentItem, name);
            verify(c !== null, name);
            return c;
        }

        function editContext() {
            var c = findChild(popup(), "apnEditContext");
            verify(c !== null);
            return c;
        }

        // Open the editor on an existing context, as tapping its row does.
        function openExisting(path) {
            popup().isNew = false;
            popup().contextPath = path;
            popup().open();
            tryCompare(popup(), "opened", true, 2000);
        }

        function addOne() {
            var add = findChild(page, "apnAddButton");
            verify(add !== null);
            verify(add.enabled);
            add.clicked();
            tryCompare(addedSpy, "count", 1, 2000);
            tryCompare(popup(), "opened", true, 2000);
            return addedSpy.signalArguments[0][0];
        }

        // Add: the editor opens on the new context; Save keeps it with what was typed.
        function test_addAndSave() {
            var before = connMan().contexts.length;
            var path = addOne();
            compare(connMan().contexts.length, before + 1);
            verify(popup().isNew);
            compare(popup().contextPath, path);
            compare(child("apnTypeCombo").currentIndex, 0, "a new context is an Internet one");
            verify(!child("apnMmsCenterField").visible, "MMS fields on an Internet context");

            child("apnNameField").text = "Test APN";
            child("apnApnField").text = "test.apn";
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);

            openExisting(path);
            compare(child("apnNameField").text, "Test APN");
            compare(child("apnApnField").text, "test.apn");
            verify(!popup().isNew);
            verify(child("apnDeleteButton").visible);
            popup().close();
        }

        // Cancel on a context added for the editor removes it again.
        function test_addAndCancelRemoves() {
            var before = connMan().contexts.length;
            var path = addOne();
            verify(!child("apnDeleteButton").visible, "Delete on a context that is being added");
            child("apnCancelButton").clicked();
            tryCompare(removedSpy, "count", 1, 2000);
            compare(removedSpy.signalArguments[0][0], path);
            compare(connMan().contexts.length, before);
            verify(connMan().contexts.indexOf(path) < 0);
        }

        // Cancel on an existing context leaves it alone.
        function test_cancelExistingKeeps() {
            var path = connMan().contexts[0];
            var before = connMan().contexts.length;
            openExisting(path);
            child("apnNameField").text = "not saved";
            child("apnCancelButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            wait(50);
            compare(removedSpy.count, 0);
            compare(connMan().contexts.length, before);
            openExisting(path);
            verify(child("apnNameField").text !== "not saved");
            popup().close();
        }

        // An MMS context shows and saves its message center and proxy.
        function test_mmsFields() {
            openExisting("/mock/modem0/context2");
            compare(child("apnTypeCombo").currentIndex, 1);
            verify(child("apnMmsCenterField").visible);
            verify(child("apnMmsProxyField").visible);
            compare(child("apnMmsCenterField").text, "http://mms.example.com/mms");
            compare(child("apnMmsProxyField").text, "10.0.0.1:8080");

            child("apnMmsCenterField").text = "http://mmsc.operator.example/";
            child("apnMmsProxyField").text = "192.0.2.1:80";
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            compare(editContext().messageCenter, "http://mmsc.operator.example/");
            compare(editContext().messageProxy, "192.0.2.1:80");

            openExisting("/mock/modem0/context2");
            compare(child("apnMmsCenterField").text, "http://mmsc.operator.example/");
            compare(child("apnMmsProxyField").text, "192.0.2.1:80");
            popup().close();
        }

        // Changing the type to MMS brings the MMS fields up and saves the type.
        function test_typeChange() {
            var path = addOne();
            var combo = child("apnTypeCombo");
            verify(!child("apnMmsCenterField").visible);
            combo.currentIndex = 1;
            verify(child("apnMmsCenterField").visible);
            child("apnMmsCenterField").text = "http://mms.new.example/";
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);

            openExisting(path);
            compare(editContext().type, "mms");
            compare(child("apnTypeCombo").currentIndex, 1);
            compare(child("apnMmsCenterField").text, "http://mms.new.example/");
            popup().close();
        }

        // Delete removes an existing context.
        function test_delete() {
            var path = addOne();
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            var before = connMan().contexts.length;

            openExisting(path);
            child("apnDeleteButton").clicked();
            tryCompare(removedSpy, "count", 1, 2000);
            compare(removedSpy.signalArguments[0][0], path);
            compare(connMan().contexts.length, before - 1);
            tryCompare(popup(), "opened", false, 2000);
        }

        // ofono refusing AddContext: no editor, the Add button comes back.
        function test_addFails() {
            var add = findChild(page, "apnAddButton");
            var before = connMan().contexts.length;
            connMan().failNextContextCall("org.ofono.Error.NotAttached");
            add.clicked();
            verify(!add.enabled, "Add stays enabled while one is under way");
            tryVerify(function() { return add.enabled; }, 2000);
            wait(50);
            compare(addedSpy.count, 0);
            verify(!popup().opened);
            compare(connMan().contexts.length, before);
            var shown = findChild(page, "apnListError");
            verify(shown !== null);
            verify(shown.visible);
            compare(shown.text, "org.ofono.Error.NotAttached");

            // the next try clears it
            add.clicked();
            verify(!shown.visible);
            tryCompare(addedSpy, "count", 1, 2000);
            tryCompare(popup(), "opened", true, 2000);
            child("apnCancelButton").clicked();
            tryCompare(removedSpy, "count", 1, 2000);
        }
    }
}
