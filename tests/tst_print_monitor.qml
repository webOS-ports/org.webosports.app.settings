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

import QtQuick 2.9
import QtTest 1.2

import "../src/qml/General"

/*
 * The Print Manager run headless, as a print job starts it: the banner, the
 * dashboard and the alert, against com.palm.printmgr's job status as
 * luneos-print-adapter posts it (print_service.c post_job_state and
 * post_page_info), and the window that stays out of sight meanwhile.
 */
Item {
    id: root
    width: 480
    height: 800

    property var calls: []
    // uri -> the callbacks of its subscriptions
    property var subscribers: ({})

    function fakeCall(uri, json, onReply, onError) {
        calls.push({ uri: uri, params: JSON.parse(json) });
        onReply({ payload: JSON.stringify({ returnValue: true }) });
        return { cancel: function() {} };
    }

    function fakeSubscribe(uri, json, onReply, onError) {
        calls.push({ uri: uri, params: JSON.parse(json) });
        var entry = { onReply: onReply, cancelled: false };
        var list = subscribers[uri] || [];
        list.push(entry);
        subscribers[uri] = list;
        onReply({ payload: JSON.stringify({ returnValue: true, subscribed: true }) });
        return { cancel: function() { entry.cancelled = true; } };
    }

    function post(method, event) {
        var n = 0;
        (subscribers["luna://com.palm.printmgr/jobs/" + method] || []).forEach(function(s) {
            if (!s.cancelled) {
                s.onReply({ payload: JSON.stringify(Object.assign({ returnValue: true }, event)) });
                n++;
            }
        });
        return n;
    }

    // A job's state as the adapter posts it
    function state(jobID, printerState, extra) {
        return Object.assign({ jobID: jobID, printerID: "Office_Printer", description: "Report.pdf",
                               appName: "PDF", statusId: "JOBSTATE", printerState: printerState },
                             extra || {});
    }

    function callsTo(uri) {
        return calls.filter(function(c) { return c.uri === uri; });
    }

    Component {
        id: monitorComponent
        PrintMonitor {}
    }

    TestCase {
        name: "PrintMonitor"
        when: windowShown

        property var monitor: null

        function init() {
            root.calls = [];
            root.subscribers = {};
            monitor = createTemporaryObject(monitorComponent, root, {
                call: root.fakeCall, subscribe: root.fakeSubscribe });
            monitor.start();
        }

        function banners() {
            return root.callsTo("luna://com.webos.notification/createToast").map(function(c) { return c.params.message; });
        }

        function test_followsEveryJob() {
            compare(root.callsTo("luna://com.palm.printmgr/jobs/getStatus")[0].params, { subscribe: true });
            compare(root.callsTo("luna://com.palm.printmgr/jobs/getRenderStatus")[0].params, { subscribe: true });
            verify(monitor.idle);
            verify(monitor.dashboard === null);
        }

        function test_aJobThatPrints() {
            // jobs/addFile: the page, then close: queued
            root.post("getStatus", { jobID: 7, description: "Report.pdf", appName: "PDF", statusId: "PAGESTARTINFO",
                                     pageNum: 1, currentPage: 1, totalPages: 3 });
            compare(banners(), ["Preparing Print Job..."]);
            var toast = root.callsTo("luna://com.webos.notification/createToast")[0].params;
            compare(toast.type, "light");
            compare(toast.sourceId, "org.webosports.app.settings.printmanager");
            verify(/icon-printmanager\.png$/.test(toast.iconUrl), toast.iconUrl);
            verify(toast.iconUrl.indexOf("file://") !== 0);

            var d = monitor.dashboard;
            verify(d !== null, "the dashboard");
            compare(d.windowProperties["LuneOS_window"], "dashboard");
            compare(d.title, "Preparing Print Job...");
            compare(d.text, "Report.pdf");
            compare(d.kind, "normal");

            root.post("getStatus", root.state(7, "QUEUED", { currentPage: 0, totalPages: 3, blockedReasons: [] }));
            compare(d.text, "Waiting for the printer...");
            root.post("getStatus", root.state(7, "RUNNING", { currentPage: 2, totalPages: 3, blockedReasons: [] }));
            compare(d.title, "Page 2 of 3 from PDF");
            compare(d.text, "Report.pdf");
            // No second banner for the same job
            compare(banners().length, 1);

            root.post("getStatus", root.state(7, "DONE", { jobStatus: "Success", timeActive: 4 }));
            verify(monitor.idle);
            tryVerify(function() { return monitor.dashboard === null; });
        }

        // A PDF (a web page from Atlas): the print service gives no page
        // numbers, as it cannot tell how many pages one file holds.
        function test_aPdfWithoutPageNumbers() {
            var pdf = { description: "webOS - Wikipedia", appName: "Browser", blockedReasons: [] };
            root.post("getStatus", { jobID: 9, description: "webOS - Wikipedia", appName: "Browser",
                                     statusId: "PAGESTARTINFO", pageNum: 1, currentPage: 0, totalPages: 0 });
            var d = monitor.dashboard;
            verify(d !== null, "the dashboard");
            root.post("getStatus", root.state(9, "QUEUED", Object.assign({ currentPage: 0, totalPages: 0 }, pdf)));
            compare(d.title, "webOS - Wikipedia");
            compare(d.text, "Waiting for the printer...");
            root.post("getStatus", root.state(9, "RUNNING", Object.assign({ currentPage: 0, totalPages: 0 }, pdf)));
            compare(d.title, "Printing from Browser");
            compare(d.text, "webOS - Wikipedia");
            root.post("getStatus", root.state(9, "BLOCKED", Object.assign({ currentPage: 0, totalPages: 0 }, pdf,
                                                                            { blockedReasons: ["toner-low"] })));
            verify(d.title.indexOf("Page") < 0, d.title);
            compare(d.text, "webOS - Wikipedia");
        }

        function test_aJobOutOfPaper() {
            root.post("getStatus", root.state(8, "RUNNING", { currentPage: 1, totalPages: 1, blockedReasons: [] }));
            root.post("getStatus", root.state(8, "BLOCKED", { currentPage: 1, totalPages: 1,
                                                              blockedReasons: ["Out_Of_Paper"] }));
            var d = monitor.dashboard;
            compare(d.title, "Out of Paper");
            compare(d.kind, "error");
            var a = monitor.alert;
            verify(a !== null, "the alert");
            compare(a.windowProperties["LuneOS_window"], "popupalert");
            compare(a.title, "Out of Paper");
            compare(a.message, "To finish the print job, load more paper in the tray.");

            // Dismiss: the alert goes, the dashboard stays
            a.dismiss();
            tryVerify(function() { return monitor.alert === null; });
            verify(monitor.dashboard !== null);
            // The printer has a new complaint: the alert again
            root.post("getStatus", root.state(8, "BLOCKED", { blockedReasons: ["Jammed"] }));
            tryVerify(function() { return monitor.alert !== null; });
            compare(monitor.alert.title, "Printer Jam");

            // Cancel Print Job
            monitor.alert.cancelJob();
            compare(root.callsTo("luna://com.palm.printmgr/jobs/cancel")[0].params, { jobID: 8 });
            tryVerify(function() { return monitor.alert === null; });
            root.post("getStatus", root.state(8, "DONE", { jobStatus: "Cancelled" }));
            compare(monitor.dashboard.title, "Print Job Canceled");
        }

        function test_warningsOnly() {
            root.post("getStatus", root.state(9, "RUNNING", { currentPage: 1, totalPages: 2,
                                                              blockedReasons: ["Low_On_Toner"] }));
            var d = monitor.dashboard;
            compare(d.title, "Low on Toner");
            compare(d.text, "Page 1 of 2 from PDF");
            compare(d.kind, "warning");
            verify(monitor.alert === null, "a warning is no alert");
            root.post("getStatus", root.state(9, "BLOCKED", { blockedReasons: ["Busy"] }));
            compare(d.title, "Printer Busy");
            verify(monitor.alert === null);
        }

        function test_aJobThatFailsStaysUntilSwiped() {
            root.post("getStatus", root.state(10, "RUNNING", { blockedReasons: [] }));
            root.post("getStatus", root.state(10, "DONE", { jobStatus: "Error" }));
            compare(monitor.dashboard.title, "Print Job Failed");
            compare(monitor.dashboard.kind, "error");
            verify(monitor.alert === null);
            verify(!monitor.idle);
            monitor.dashboard.dismissed();
            tryVerify(function() { return monitor.idle; });
            tryVerify(function() { return monitor.dashboard === null; });
            compare(monitor.jobs.length, 0, "a job that is over goes when swiped");
        }

        function test_severalJobs() {
            root.post("getStatus", root.state(11, "RUNNING", { currentPage: 1, totalPages: 4, blockedReasons: [] }));
            root.post("getStatus", Object.assign(root.state(12, "QUEUED", { blockedReasons: [] }),
                                                 { description: "Photo.jpg", appName: "Photos" }));
            compare(banners().length, 2);
            var d = monitor.dashboard;
            compare(d.count, 2);
            // The latest
            compare(d.title, "Photo.jpg");
            // Swiped: the jobs under way come back with their next news
            d.dismissed();
            tryVerify(function() { return monitor.dashboard === null; });
            verify(monitor.idle);
            root.post("getStatus", root.state(11, "RUNNING", { currentPage: 2, totalPages: 4, blockedReasons: [] }));
            verify(monitor.dashboard === null, "the same state: still away");
            root.post("getStatus", root.state(11, "BLOCKED", { blockedReasons: ["Door_Open"] }));
            tryVerify(function() { return monitor.dashboard !== null; });
            compare(monitor.dashboard.title, "Door Open");
        }

        function test_anAppThatRenders() {
            // The render status of a browser page: the banner as its first page comes
            root.post("getRenderStatus", { jobID: 13, currentPage: 1, totalPages: 2 , renderResultCode: 0 });
            compare(banners(), ["Preparing Print Job..."]);
            // A render that failed is not the Print Manager's to tell
            root.post("getRenderStatus", { jobID: 14, renderResultCode: -703 });
            compare(banners().length, 1);
            // An unknown job that printed is no news
            root.post("getStatus", root.state(15, "DONE", { jobStatus: "Success" }));
            compare(monitor.jobs.length, 1);
        }

        function test_tapOpensTheQueue() {
            var spy = createTemporaryQmlObject("import QtTest 1.2; SignalSpy { signalName: \"openQueue\" }", root);
            spy.target = monitor;
            root.post("getStatus", root.state(16, "RUNNING", { blockedReasons: [] }));
            monitor.dashboard.tapped();
            compare(spy.count, 1);
        }

        function test_stopLetsGo() {
            monitor.stop();
            compare(root.post("getStatus", root.state(17, "RUNNING")), 0);
        }
    }

    // --- The window ----------------------------------------------------------

    TestCase {
        name: "PrintManagerWindow"
        when: windowShown

        function makeWindow(params) {
            var component = Qt.createComponent(Qt.resolvedUrl("../src/qml/GenericCategoryWindow.qml"));
            verify(component.status !== Component.Error, component.errorString());
            var w = createTemporaryObject(component, null, {
                appId: "org.webosports.app.settings.printmanager",
                launchParams: params ? JSON.stringify(params) : ""
            });
            verify(w !== null);
            return w;
        }

        function test_headlessStaysOutOfSight() {
            var w = makeWindow({ "$disableCardPreLaunch": true, runHeadless: true });
            wait(50);
            verify(!w.visible, "no card for a headless launch");
            verify(w._printMonitor !== null, "the monitor runs");
            verify(w.keepAlive);
        }

        function test_aLaunchShowsTheQueue() {
            var w = makeWindow(null);
            tryVerify(function() { return w.visible; }, 1000);
        }

        function test_theDashboardOpensTheQueue() {
            var w = makeWindow({ runHeadless: true });
            wait(50);
            var monitor = w._printMonitor;
            root.calls = [];
            root.subscribers = {};
            monitor.call = root.fakeCall;
            monitor.subscribe = root.fakeSubscribe;
            monitor.start();
            root.post("getStatus", root.state(20, "RUNNING", { blockedReasons: [] }));
            verify(monitor.dashboard !== null);
            monitor.dashboard.tapped();
            verify(w.visible, "the queue");
            w.visible = false;
        }

        function test_goesWhenThereIsNothingToTell() {
            var w = makeWindow({ runHeadless: true });
            var quits = 0;
            w.quitWhenIdle = function() { quits++; };
            wait(50);
            var monitor = w._printMonitor;
            monitor.call = root.fakeCall;
            monitor.subscribe = root.fakeSubscribe;
            monitor.start();
            root.post("getStatus", root.state(21, "RUNNING", { blockedReasons: [] }));
            wait(200);
            compare(quits, 0, "not while a job prints");
            root.post("getStatus", root.state(21, "DONE", { jobStatus: "Success" }));
            tryVerify(function() { return quits === 1; }, 7000, "it goes once all is told");
        }

        function test_otherCategoriesShowAtOnce() {
            var component = Qt.createComponent(Qt.resolvedUrl("../src/qml/GenericCategoryWindow.qml"));
            var w = createTemporaryObject(component, null, { appId: "org.webosports.app.settings.example" });
            verify(w.visible);
            verify(w._printMonitor === null);
        }
    }
}
