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

import "../src/qml/General"

/*
 * Settings > System Updates against a stand-in for
 * org.webosports.service.update that answers as the service does (its
 * lib/update.js): checkUpdate, the downloadUpdate subscription and
 * initiateUpdate. Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings.updates"
    property Component actionHeaderComponent

    readonly property var changes: [
        { "version": 26, "changes": ["Faster boot", "<b>not markup</b>"] },
        { "version": 25, "changes": ["Wi-Fi fixes"] }
    ]

    Component {
        id: serviceComponent
        LunaService {
            // What checkUpdate answers; null: the service is not on the bus.
            property var checkAnswer: ({ "returnValue": true, "success": true, "needUpdate": false })
            property var initiateAnswer: ({ "success": true, "error": false })
            property var calls: []
            property var downloadOk: null
            property int cancelled: 0

            function call(uri, args, ok, err) {
                calls.push(uri);
                if (checkAnswer === null) {
                    err("Service does not exist: org.webosports.service.update.");
                    return;
                }
                if (uri === "luna://org.webosports.service.update/retrieveVersion")
                    ok({ "payload": JSON.stringify({ "returnValue": true, "localVersion": "1.0",
                                                     "codename": "Espressino", "buildTree": "testing",
                                                     "buildNumber": "142" }) });
                else if (uri === "luna://org.webosports.service.update/checkUpdate")
                    ok({ "payload": JSON.stringify(checkAnswer) });
                else if (uri === "luna://org.webosports.service.update/initiateUpdate")
                    ok({ "payload": JSON.stringify(initiateAnswer) });
            }
            function subscribe(uri, args, ok, err) {
                calls.push(uri);
                downloadOk = ok;
                var service = this;
                return { "cancel": function () { service.cancelled++; } };
            }
            // The next message of the downloadUpdate subscription.
            function send(answer) {
                downloadOk({ "payload": JSON.stringify(answer) });
            }
        }
    }

    Component {
        id: pageComponent
        UpdatePage { anchors.fill: parent }
    }

    TestCase {
        name: "UpdatePage"
        when: windowShown

        property var service: null

        function makePage(checkAnswer) {
            service = createTemporaryObject(serviceComponent, root);
            if (checkAnswer !== undefined)
                service.checkAnswer = checkAnswer;
            var page = createTemporaryObject(pageComponent, root, { "luna": service });
            verify(page !== null, "the page did not load");
            return page;
        }

        function shown(page, name) {
            var item = findChild(page, name);
            verify(item !== null, "no " + name);
            return item.visible;
        }

        function available(page) {
            service.checkAnswer = { "returnValue": true, "success": true, "needUpdate": true,
                                    "changesSinceLast": root.changes };
            page.checkForUpdate();
            compare(page.updateState, "available");
        }

        function test_theInstalledVersionIsShown() {
            var page = makePage();
            compare(findChild(page, "versionRow").value, "1.0 (Espressino)");
            compare(findChild(page, "channelRow").value, "testing");
            compare(findChild(page, "buildRow").value, "142");
        }

        function test_itChecksWhenItOpens() {
            var page = makePage();
            verify(service.calls.indexOf("luna://org.webosports.service.update/checkUpdate") >= 0);
            compare(page.updateState, "uptodate");
            compare(findChild(page, "updateStatus").text, "This device is up to date.");
            verify(shown(page, "checkButton"));
            verify(!shown(page, "downloadButton"));
            verify(!shown(page, "installButton"));
        }

        function test_anUpdateListsItsChangesAndOffersTheDownload() {
            var page = makePage({ "returnValue": true, "success": true, "needUpdate": true,
                                  "changesSinceLast": root.changes });
            compare(page.updateState, "available");
            compare(page.changes.length, 2);
            verify(shown(page, "downloadButton"));
            verify(!shown(page, "checkButton"));
            verify(!shown(page, "installButton"));
        }

        function test_aFailedCheckSaysWhyAndCanBeTriedAgain() {
            var page = makePage({ "returnValue": false, "success": false, "needUpdate": false,
                                  "message": "Could not get manifest - Status code falsy: 404" });
            compare(page.updateState, "failed");
            compare(findChild(page, "updateStatus").text,
                    "Could not check for updates: Could not get manifest - Status code falsy: 404");
            verify(shown(page, "checkButton"));
        }

        function test_theDownloadShowsProgressThenOffersTheInstall() {
            var page = makePage();
            available(page);
            page.downloadUpdate();
            compare(page.updateState, "downloading");
            verify(shown(page, "updateProgress"));
            verify(!shown(page, "downloadButton"));

            service.send({ "percentage": "41.70" });
            compare(page.percentage, 41.7);
            compare(findChild(page, "updateStatus").text, "Downloading the update: 41%");

            service.send({ "success": true, "finished": true, "error": false, "msg": "Done downloading." });
            compare(page.updateState, "downloaded");
            compare(service.cancelled, 1);
            verify(!shown(page, "updateProgress"));
            verify(shown(page, "installButton"));
        }

        function test_aFailedDownloadCanBeTriedAgain() {
            var page = makePage();
            available(page);
            page.downloadUpdate();
            service.send({ "success": false, "error": true, "needCheck": false,
                           "msg": "Error during download" });
            compare(page.updateState, "failed");
            compare(service.cancelled, 1);
            verify(shown(page, "downloadButton"));
            compare(findChild(page, "downloadButton").text, "Try the download again");
            verify(!shown(page, "checkButton"));
        }

        function test_aDownloadTheFeedNoLongerHasAsksForANewCheck() {
            var page = makePage();
            available(page);
            page.downloadUpdate();
            service.send({ "success": false, "error": true, "needCheck": true,
                           "msg": "Device images file corrupt or version not present anymore. Please check for updates again." });
            compare(page.updateState, "failed");
            verify(shown(page, "checkButton"));
            verify(!shown(page, "downloadButton"));
        }

        function test_installingRestarts() {
            var page = makePage();
            available(page);
            page.downloadUpdate();
            service.send({ "success": true, "finished": true, "error": false });
            page.installUpdate();
            verify(service.calls.indexOf("luna://org.webosports.service.update/initiateUpdate") >= 0);
            compare(page.updateState, "restarting");
            verify(!shown(page, "installButton"));
        }

        function test_anInstallThatCannotStartSaysWhy() {
            var page = makePage();
            available(page);
            page.downloadUpdate();
            service.send({ "success": true, "finished": true, "error": false });
            service.initiateAnswer = { "returnValue": false, "success": false, "error": true,
                                       "msg": "script exited with code 1" };
            page.installUpdate();
            compare(page.updateState, "failed");
            compare(findChild(page, "updateStatus").text,
                    "The update could not be started: script exited with code 1");
            verify(shown(page, "installButton"));
        }

        function test_closingThePageEndsTheDownload() {
            var page = makePage();
            available(page);
            page.downloadUpdate();
            page.destroy();
            tryCompare(service, "cancelled", 1);
        }

        function test_withoutTheServiceItSaysSo() {
            ignoreWarning(new RegExp("Update service did not answer"));
            var page = makePage(null);
            verify(!page.serviceAvailable);
            compare(page.updateState, "failed");
        }
    }
}
