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
        NetworkSettingsPage {
            anchors.fill: parent
            apnDatabase: Qt.resolvedUrl("data/provision-test.json")
        }
    }

    SignalSpy {
        id: addedSpy
        signalName: "contextAdded"
    }
    SignalSpy {
        id: removedSpy
        signalName: "contextRemoved"
    }
    SignalSpy {
        id: activeSpy
        signalName: "activeChanged"
    }
    SignalSpy {
        id: refusedSpy
        signalName: "reportError"
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

        function presetLabels() {
            return popup().presets.map(function(p) { return p.label + " (" + p.apn + ")"; });
        }

        // Open the editor on the active Internet context with the database loaded.
        function openActiveInternet() {
            openExisting("/mock/modem0/context1");
            verify(editContext().active, "the stand-in's Internet context starts active");
            tryVerify(function() { return popup().presets.length > 0; }, 2000, "no presets");
        }

        // The Internet access points of the SIM's network: not the MMS or
        // WAP ones, not another network's. The provider whose SPN is the
        // SIM's comes first, the other brand on the network after it.
        function test_presetsForTheSim() {
            openActiveInternet();
            var combo = child("apnPresetCombo");
            verify(combo.visible);
            compare(combo.currentIndex, -1, "nothing chosen yet");
            compare(presetLabels(), ["Mock Internet (internet.mock)",
                                     "Mock Business (business.mock)",
                                     "Other Brand internet (other.brand)"]);
            popup().close();
        }

        // ofono notifies SIM properties while the list opens: the list must
        // not be replaced then (a new model during the popup's row creation
        // crashed Qt on the Radon), and catches up once it closes.
        function test_listStableWhileOpen() {
            openActiveInternet();
            var combo = child("apnPresetCombo");
            var sim = findChild(page, "apnSim");
            var spn = sim.serviceProviderName;
            var shown = JSON.stringify(combo.model);
            combo.popup.open();
            tryCompare(combo.popup, "opened", true, 2000);
            sim.serviceProviderName = "Other Brand";
            compare(JSON.stringify(combo.model), shown, "list replaced while open");
            sim.serviceProviderName = "SomethingElse";
            compare(JSON.stringify(combo.model), shown, "list replaced while open");
            // the rows wrap long names rather than eliding them
            var row = findChild(combo.popup.contentItem, "apnPresetRow0");
            verify(row !== null, "no rows in the open list");
            compare(row.contentItem.wrapMode, Text.Wrap);
            compare(row.contentItem.elide, Text.ElideNone);
            compare(row.contentItem.textFormat, Text.PlainText);
            combo.popup.close();
            tryCompare(combo.popup, "visible", false, 2000);
            sim.serviceProviderName = "Other Brand";
            compare(combo.model[0], "Other Brand internet (other.brand)", "own provider first after closing");
            sim.serviceProviderName = spn;
            compare(combo.model[0], "Mock Internet (internet.mock)");
            popup().close();
        }

        // Choosing one fills the fields; nothing is written until Save.
        function test_presetFillsFields() {
            openActiveInternet();
            var before = editContext().accessPointName;
            var combo = child("apnPresetCombo");
            combo.currentIndex = 1;
            combo.activated(1);
            compare(child("apnNameField").text, "Mock Business");
            compare(child("apnApnField").text, "business.mock");
            compare(popup().presetAuth, "pap");
            compare(editContext().accessPointName, before, "written before Save");
            popup().close();
        }

        // Save writes what the chosen access point carries, its authentication
        // method too, which the form has no field for.
        function test_presetSaved() {
            var path = addOne();
            tryVerify(function() { return popup().presets.length > 1; }, 2000);
            child("apnPresetCombo").activated(1);
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            var ctx = editContext();
            compare(ctx.contextPath, path);
            compare(ctx.accessPointName, "business.mock");
            compare(ctx.username, "biz");
            compare(ctx.password, "secret");
            compare(ctx.authMethod, "pap");
            compare(ctx.name, "Mock Business");
        }

        // An internet access point the database names no protocol for gets
        // IPv4/IPv6, as ofono provisions it; an MMS one keeps the context's.
        function test_presetProtocol() {
            openActiveInternet();
            var proto = child("apnProtocolCombo");
            proto.currentIndex = 0;
            child("apnPresetCombo").activated(0);
            compare(proto.currentIndex, 2, "internet preset without protocol");
            popup().close();
            openExisting("/mock/modem0/context2");
            tryVerify(function() { return popup().presets.length > 0; }, 2000);
            proto.currentIndex = 0;
            child("apnPresetCombo").activated(0);
            compare(proto.currentIndex, 0, "MMS preset without protocol");
            popup().close();
        }

        // A protocol the form does not know is left alone by Save, not
        // replaced with IPv4.
        function test_unknownProtocolKept() {
            openExisting("/mock/modem0/context2");
            var ctx = editContext();
            var old = ctx.protocol;
            ctx.protocol = "";
            popup().close();
            openExisting("/mock/modem0/context2");
            compare(child("apnProtocolCombo").currentIndex, -1);
            compare(child("apnProtocolCombo").displayText, "Unchanged");
            child("apnApnField").text = ctx.accessPointName + "x";
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            compare(ctx.protocol, "", "protocol written");
            openExisting("/mock/modem0/context2");
            child("apnApnField").text = ctx.accessPointName.slice(0, -1);
            child("apnProtocolCombo").currentIndex = Math.max(0, ["ip", "ipv6", "dual"].indexOf(old));
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
        }

        // An MMS context lists the MMS access points and fills center and proxy.
        function test_mmsPreset() {
            openExisting("/mock/modem0/context2");
            tryVerify(function() { return popup().presets.length > 0; }, 2000);
            compare(presetLabels(), ["Mock MMS (mms.mock)"]);
            child("apnPresetCombo").activated(0);
            compare(child("apnApnField").text, "mms.mock");
            compare(child("apnMmsCenterField").text, "http://mmsc.mock/");
            compare(child("apnMmsProxyField").text, "10.1.1.1:8080");
            popup().close();
        }

        // Changing the type lists that type's access points.
        function test_presetsFollowType() {
            openActiveInternet();
            child("apnTypeCombo").currentIndex = 2;
            compare(presetLabels(), ["Mock WAP (wap.mock)"]);
            child("apnTypeCombo").currentIndex = 3;
            verify(!child("apnPresetCombo").visible, "IMS ones are not in the database");
            popup().close();
        }

        // A provider of the SIM's name listed only under another network
        // (Lebara NL under Telfort's 204/12, its SIMs on KPN's 204/08) is not
        // offered: that network's settings do not work on this one.
        function test_sameNameOtherNetworkNotListed() {
            var sim = findChild(page, "apnSim");
            var spn = sim.serviceProviderName;
            sim.serviceProviderName = "Elsewhere";
            openExisting("/mock/modem0/context1");
            tryVerify(function() { return popup().presets.length > 0; }, 2000);
            compare(presetLabels().indexOf("Elsewhere (elsewhere)"), -1);
            popup().close();
            sim.serviceProviderName = spn;
        }

        // No list for an operator the database does not know.
        function test_noPresetsForUnknownOperator() {
            var sim = findChild(page, "apnSim");
            verify(sim !== null);
            var mnc = sim.mobileNetworkCode, spn = sim.serviceProviderName;
            sim.mobileNetworkCode = "99";
            sim.serviceProviderName = "Nobody";
            openExisting("/mock/modem0/context1");
            wait(100);
            compare(popup().presets.length, 0);
            verify(!child("apnPresetCombo").visible);
            popup().close();
            sim.mobileNetworkCode = mnc;
            sim.serviceProviderName = spn;
        }

        // No database (an image without provision.json): no list, the form as before.
        function test_missingDatabase() {
            page.apnDatabase = Qt.resolvedUrl("data/no-such-file.json");
            page.loadApnDatabase();
            tryCompare(page, "apnProviders", [], 2000);
            openExisting("/mock/modem0/context1");
            wait(100);
            compare(popup().presets.length, 0);
            verify(!child("apnPresetCombo").visible);
            verify(child("apnApnField").visible);
            popup().close();
        }

        // Saving an active context: ofono takes no change while it is active,
        // so it is taken down, written and brought back up.
        function test_editActiveContext() {
            openActiveInternet();
            var ctx = editContext();
            var oldApn = ctx.accessPointName;
            activeSpy.target = ctx;
            activeSpy.clear();
            refusedSpy.target = ctx;
            refusedSpy.clear();
            child("apnPresetCombo").activated(0);
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            compare(child("apnErrorText").visible, false);
            compare(ctx.accessPointName, "internet.mock");
            compare(ctx.name, "Mock Internet");
            verify(ctx.active, "not active again");
            compare(activeSpy.count, 2, "down and up once");
            compare(refusedSpy.count, 0, "a write reached ofono while the context was active");
            openExisting("/mock/modem0/context1");
            compare(child("apnApnField").text, "internet.mock");
            // put the shared stand-in back for the other tests
            child("apnApnField").text = oldApn;
            child("apnNameField").text = "Internet";
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
        }

        // Nothing changed: the active context is left up.
        function test_saveUnchangedKeepsActive() {
            openActiveInternet();
            var ctx = editContext();
            activeSpy.target = ctx;
            activeSpy.clear();
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 2000);
            compare(activeSpy.count, 0);
            verify(ctx.active);
        }

        // connman brings the context back up before the writes land: they are
        // refused, the context is taken down once more and written again.
        function test_reactivatedBeforeWrites() {
            openActiveInternet();
            var ctx = editContext();
            var oldApn = ctx.accessPointName;
            activeSpy.target = ctx;
            activeSpy.clear();
            child("apnApnField").text = "retry.mock";
            ctx.reactivateBeforeNextWrite();
            child("apnSaveButton").clicked();
            tryCompare(popup(), "opened", false, 3000);
            compare(ctx.accessPointName, "retry.mock");
            verify(ctx.active);
            compare(activeSpy.count, 4, "down, up (connman), down, up");
            openExisting("/mock/modem0/context1");
            child("apnApnField").text = oldApn;
            child("apnSaveButton").clicked();
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
