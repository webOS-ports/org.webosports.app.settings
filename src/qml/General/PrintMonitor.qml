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

import LuneOS.Service 1.0

/*
 * How the printing goes, as webOS 3.0.5's Print Manager told it while it
 * ran headless: the print dialog starts it ({"runHeadless": true}) as a job
 * opens, and it follows every job on com.palm.printmgr's jobs/getStatus
 * (and jobs/getRenderStatus, for an app that renders its pages).
 *
 *   - "Preparing Print Job..." in a banner when a job is first heard of;
 *   - a dashboard while jobs are under way: the latest job, how far it got
 *     ("Page 2 of 5 from Documents"), or what stops it, with a count when
 *     there are more; a tap opens the queue (openQueue);
 *   - an alert when the printer cannot go on until something is done at
 *     the printer (out of paper, a jam, the door open...), with Cancel
 *     Print Job and Dismiss.
 *
 * A job that printed goes from the dashboard; one that failed or was
 * cancelled stays until the dashboard is swiped away.
 */
Item {
    id: monitor

    // As LunaService.call and LunaService.subscribe (the latter giving back
    // a call with cancel()); the window's own service unless set.
    property var call: function(uri, json, onReply, onError) { return luna.call(uri, json, onReply, onError); }
    property var subscribe: function(uri, json, onReply, onError) { return luna.subscribe(uri, json, onReply, onError); }
    property string appId: "org.webosports.app.settings.printmanager"
    // The app's icon, which the dashboard, the banner and the alert show
    property url icon: Qt.resolvedUrl("../images/icons/icon-printmanager.png")

    // The jobs heard of and not printed yet, oldest first:
    // { jobID, appName, description, state, currentPage, totalPages,
    //   reasons, swiped, alertDismissed }. state is "Preparing", "QUEUED",
    // "RUNNING", "BLOCKED", "Cancelled" or "Failed".
    property var jobs: []
    // A job has been heard of since the monitor started
    property bool heardOfAJob: false

    readonly property var dashboardJobs: jobs.filter(function(j) { return !j.swiped; })
    readonly property var latest: dashboardJobs.length > 0 ? dashboardJobs[dashboardJobs.length - 1] : null
    readonly property var alertJob: {
        for (var i = jobs.length - 1; i >= 0; i--) {
            var j = jobs[i];
            if (j.state === "BLOCKED" && !j.alertDismissed && blockingReason(j.reasons) !== "")
                return j;
        }
        return null;
    }
    // Nothing to tell: the dashboard and the alert are gone
    readonly property bool idle: dashboardJobs.length === 0 && alertJob === null

    // The dashboard was tapped
    signal openQueue()

    LunaService {
        id: luna
        name: monitor.appId
    }

    property var _calls: []

    function start() {
        stop();
        _calls = [
            subscribe("luna://com.palm.printmgr/jobs/getStatus", JSON.stringify({ subscribe: true }),
                      function(m) { monitor._status(monitor._parse(m)); }, function(e) {
                          console.warn("PrintMonitor: no job status: " + e);
                      }),
            subscribe("luna://com.palm.printmgr/jobs/getRenderStatus", JSON.stringify({ subscribe: true }),
                      function(m) { monitor._render(monitor._parse(m)); }, function() {})
        ];
    }

    function stop() {
        _calls.forEach(function(c) {
            if (c && typeof c.cancel === "function")
                c.cancel();
        });
        _calls = [];
    }

    Component.onDestruction: stop()

    function _parse(message) {
        try {
            return JSON.parse(message.payload);
        } catch (e) {
            return {};
        }
    }

    function _index(jobID) {
        for (var i = 0; i < jobs.length; i++) {
            if (jobs[i].jobID === jobID)
                return i;
        }
        return -1;
    }

    // The job, made anew when first heard of, with the banner unless it is
    // over already (quiet).
    function _job(r, quiet) {
        var i = _index(r.jobID);
        if (i >= 0)
            return jobs[i];
        var job = { jobID: r.jobID, appName: r.appName || "", description: r.description || "",
                    state: "Preparing", currentPage: 0, totalPages: 0, reasons: [],
                    swiped: false, alertDismissed: false };
        jobs = jobs.concat([job]);
        heardOfAJob = true;
        if (!quiet)
            banner("Preparing Print Job...");
        return job;
    }

    // jobs changed in place: tell the bindings
    function _changed(job, changes) {
        var i = _index(job.jobID);
        if (i < 0)
            return;
        var list = jobs.slice();
        list[i] = Object.assign({}, job, changes);
        jobs = list;
    }

    function _remove(jobID) {
        jobs = jobs.filter(function(j) { return j.jobID !== jobID; });
    }

    function _render(r) {
        if (r.jobID === undefined || r.renderResultCode === undefined)
            return;
        // A render that failed is the app's to tell (its print dialog says so)
        if (r.renderResultCode < 0)
            return;
        var job = _job(r);
        if (r.totalPages > 0 || r.currentPage > 0)
            _changed(job, { currentPage: r.currentPage || job.currentPage, totalPages: r.totalPages || job.totalPages });
    }

    function _status(r) {
        if (r.jobID === undefined)
            return;
        var known = _index(r.jobID) >= 0;
        if (r.statusId === "JOBSTATE" && r.printerState === "DONE") {
            if (!known && r.jobStatus === "Success")
                return;
            if (r.jobStatus === "Success") {
                _remove(r.jobID);
                return;
            }
            var done = _job(r, true);
            _changed(done, { state: r.jobStatus === "Cancelled" ? "Cancelled" : "Failed", swiped: false,
                             reasons: [r.jobStatus === "Cancelled" ? "Cancelled" : "Failed"] });
            return;
        }
        var job = _job(r);
        var changes = {};
        if (r.appName)
            changes.appName = r.appName;
        if (r.description)
            changes.description = r.description;
        if (r.currentPage > 0)
            changes.currentPage = r.currentPage;
        if (r.totalPages > 0)
            changes.totalPages = r.totalPages;
        if (r.statusId === "JOBSTATE") {
            var reasons = r.blockedReasons || [];
            // A change of what stops it is news again, swiped or not
            if (String(reasons) !== String(job.reasons) || r.printerState !== job.state) {
                changes.swiped = false;
                changes.alertDismissed = false;
            }
            changes.state = r.printerState;
            changes.reasons = reasons;
            // Low on ink while it prints is a warning, as webOS had it
            if (r.printerState === "RUNNING" && (reasons.indexOf("Low_On_Ink") >= 0 || reasons.indexOf("Low_On_Toner") >= 0))
                changes.state = "BLOCKED";
        }
        _changed(job, changes);
    }

    // --- What is said --------------------------------------------------------

    // The reasons that stop a job until something is done at the printer, in
    // the order they matter; Busy and low ink only warn.
    readonly property var _alerts: [
        { reason: "Door_Open", title: "Door Open", text: "To finish the print job, close the printer door." },
        { reason: "Out_Of_Paper", title: "Out of Paper", text: "To finish the print job, load more paper in the tray." },
        { reason: "Jammed", title: "Printer Jam", text: "To finish the print job, clear the paper or carriage jam." },
        { reason: "Service_Request", title: "Printer Error", text: "Refer to the printer for more information." },
        { reason: "Out_Of_Ink", title: "Out of Ink", text: "To finish the print job, insert new ink cartridge(s)." },
        { reason: "Out_Of_Toner", title: "Out of Toner", text: "To finish the print job, insert new toner cartridge(s)." },
        { reason: "Unable_To_Connect", title: "Unable To Connect", text: "A connection with the printer cannot be made." },
        { reason: "Cancelled", title: "Print Job Canceled", text: "The print job has been canceled." },
        { reason: "Failed", title: "Print Job Failed", text: "The print job has failed.  Try printing again." }
    ]
    readonly property var _warnings: [
        { reason: "Busy", title: "Printer Busy", text: "The printer is currently busy." },
        { reason: "Low_On_Ink", title: "Low on Ink", text: "" },
        { reason: "Low_On_Toner", title: "Low on Toner", text: "" }
    ]

    function _first(table, reasons) {
        for (var i = 0; i < table.length; i++) {
            if ((reasons || []).indexOf(table[i].reason) >= 0)
                return table[i];
        }
        return null;
    }

    // The reason that stops the job, or "" when nothing does
    function blockingReason(reasons) {
        var a = _first(_alerts, reasons);
        return a && a.reason !== "Cancelled" && a.reason !== "Failed" ? a.reason : "";
    }

    function pageText(job) {
        if (!job || job.currentPage <= 0)
            return "";
        var from = job.appName || job.description;
        if (job.totalPages > 0)
            return "Page " + job.currentPage + " of " + job.totalPages + (from ? " from " + from : "");
        return "Page " + job.currentPage + (from ? " from " + from : "");
    }

    // { title, text, kind } for the dashboard: kind "normal", "warning" or "error"
    function describe(job) {
        if (!job)
            return { title: "", text: "", kind: "normal" };
        var name = job.description || job.appName;
        if (job.state === "Preparing")
            return { title: "Preparing Print Job...", text: name, kind: "normal" };
        if (job.state === "QUEUED")
            return { title: pageText(job) || name, text: "Waiting for the printer...", kind: "normal" };
        if (job.state === "RUNNING")
            return { title: pageText(job) || ("Printing" + (job.appName ? " from " + job.appName : "")),
                     text: pageText(job) ? job.description : name, kind: "normal" };
        var alert = _first(_alerts, job.reasons);
        if (alert)
            return { title: alert.title, text: name, kind: "error" };
        var warning = _first(_warnings, job.reasons);
        if (warning)
            return { title: warning.title, text: pageText(job) || name, kind: "warning" };
        // Stopped, and the printer does not say why
        return { title: "Printer Error", text: name, kind: "error" };
    }

    // { title, text } for the alert
    function alertText(job) {
        var a = job ? _first(_alerts, job.reasons) : null;
        return a ? { title: a.title, text: a.text } : { title: "", text: "" };
    }

    // --- What the user does --------------------------------------------------

    // The dashboard swiped away: the jobs that are over go, and those under
    // way come back with their next news.
    function dashboardSwiped() {
        var list = [];
        jobs.forEach(function(j) {
            if (j.state === "Cancelled" || j.state === "Failed")
                return;
            list.push(Object.assign({}, j, { swiped: true }));
        });
        jobs = list;
    }

    property bool cancelling: false

    function cancelJob(jobID) {
        cancelling = true;
        call("luna://com.palm.printmgr/jobs/cancel", JSON.stringify({ jobID: jobID }), function(m) {
            monitor.cancelling = false;
            var r = monitor._parse(m);
            if (r.returnValue !== false) {
                var i = monitor._index(jobID);
                if (i >= 0)
                    monitor._changed(monitor.jobs[i], { alertDismissed: true });
            }
        }, function() {
            monitor.cancelling = false;
        });
    }

    function dismissAlert(jobID) {
        var i = _index(jobID);
        if (i >= 0)
            _changed(jobs[i], { alertDismissed: true });
    }

    // A banner, as enyo.windows.addBannerMessage posts one: a "light" toast,
    // which goes by and leaves nothing in the notification list
    function banner(message) {
        call("luna://com.webos.notification/createToast",
             JSON.stringify({ type: "light", sourceId: appId, message: message, iconUrl: _path(icon) }),
             function() {}, function(e) { console.warn("PrintMonitor: no banner: " + e); });
    }

    function _path(url) {
        var s = String(url);
        return s.indexOf("file://") === 0 ? s.substring(7) : s;
    }

    // --- The windows -------------------------------------------------------

    Loader {
        id: dashboardLoader
        objectName: "printDashboardLoader"
        active: monitor.latest !== null
        sourceComponent: PrintDashboard {
            readonly property var info: monitor.describe(monitor.latest)
            title: info.title
            text: info.text
            kind: info.kind
            count: monitor.dashboardJobs.length
            icon: monitor.icon
            smallIcon: monitor._path(monitor.icon)
            onTapped: monitor.openQueue()
            // Later: this runs in the window's own signal
            onDismissed: Qt.callLater(monitor.dashboardSwiped)
        }
    }

    Loader {
        id: alertLoader
        objectName: "printAlertLoader"
        active: monitor.alertJob !== null
        sourceComponent: PrintAlert {
            readonly property var job: monitor.alertJob
            readonly property var info: monitor.alertText(job)
            title: info.title
            message: info.text
            icon: monitor.icon
            cancelling: monitor.cancelling
            onCancelJob: if (job) monitor.cancelJob(job.jobID)
            onDismiss: if (job) monitor.dismissAlert(job.jobID)
        }
    }

    readonly property alias dashboard: dashboardLoader.item
    readonly property alias alert: alertLoader.item
}
