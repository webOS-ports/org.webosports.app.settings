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
import QtQuick.Controls 2.2

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

/*
 * What each application has been allowed for one Web API that asks first -
 * location or notifications.
 *
 * Two sources, merged:
 *  - What the permission prompt answered. WebAppMgr keeps those in the
 *    browser engine's own per-application settings, which is what decides the
 *    next request, and this list reads and changes them there
 *    (getAppPermissions / setAppPermission / resetAppPermissions) rather than
 *    keeping a copy of its own that could drift from what is enforced. "Ask
 *    Again" forgets an answer, so the application is asked the next time.
 *  - What an application is granted up front by its own appinfo.json
 *    (webAppPermissions), as the application manager's listApps reports it:
 *    for notifications any application, for location only applications that
 *    ship with the system - WebAppMgr asks every other one regardless. Those
 *    rows can be switched to Denied, which stores a decision; a stored
 *    decision always wins over the appinfo.json grant.
 *
 * Only applications with either are listed: one that never asked and is
 * granted nothing has nothing to change.
 */
Column {
    id: permissionList

    // "geolocation" or "notifications", WebAppMgr's names.
    property string permission
    // The page's LunaService.
    property var luna
    // Shown when no application has been asked yet.
    property string emptyText: "No application has asked yet."

    readonly property string webAppManager: "luna://com.webos.service.webappmanager"

    property bool available: true
    // Stored decisions from WebAppMgr: [{ appId, setting, system }].
    property var entries: []
    // listApps entries, for titles and appinfo.json grants.
    property var apps: []

    readonly property var storedChoices: ["Allowed", "Denied", "Ask Again"]
    readonly property var storedSettings: ["allow", "block", "ask"]

    /*
     * One row per application: { appId, title, setting, grantedBy }.
     * grantedBy is "" for a stored decision, "system" or "app" for a grant
     * that comes from appinfo.json. Application ids are compared without
     * case, because the browser engine hands them back lowercased.
     */
    readonly property var rows: {
        var out = [];
        var seen = {};
        var titles = {};
        var i;

        for (i = 0; i < permissionList.apps.length; i++) {
            var app = permissionList.apps[i];
            titles[app.id.toLowerCase()] = app.title ? app.title : app.id;
        }

        function titleFor(appId) {
            var key = appId.toLowerCase();
            return titles.hasOwnProperty(key) ? titles[key] : appId;
        }

        for (i = 0; i < permissionList.entries.length; i++) {
            var entry = permissionList.entries[i];
            // WebAppMgr's own system rows are the same appinfo.json grant
            // this list works out below; let that one stand for both.
            if (entry.system === true)
                continue;
            seen[entry.appId.toLowerCase()] = true;
            out.push({ "appId": entry.appId, "title": titleFor(entry.appId),
                       "setting": entry.setting, "grantedBy": "" });
        }

        for (i = 0; i < permissionList.apps.length; i++) {
            var candidate = permissionList.apps[i];
            var perms = candidate.webAppPermissions;
            if (!perms || perms.indexOf(permissionList.permission) < 0)
                continue;
            var isSystem = candidate.systemApp === true;
            // Location is asked of every application that is not part of
            // the system, whatever its appinfo.json says.
            if (permissionList.permission === "geolocation" && !isSystem)
                continue;
            if (seen[candidate.id.toLowerCase()])
                continue;
            seen[candidate.id.toLowerCase()] = true;
            out.push({ "appId": candidate.id, "title": titleFor(candidate.id),
                       "setting": "allow",
                       "grantedBy": isSystem ? "system" : "app" });
        }

        // Tolerated: WebAppMgr's system rows for applications listApps did
        // not report.
        for (i = 0; i < permissionList.entries.length; i++) {
            var sys = permissionList.entries[i];
            if (sys.system !== true || seen[sys.appId.toLowerCase()])
                continue;
            seen[sys.appId.toLowerCase()] = true;
            out.push({ "appId": sys.appId, "title": titleFor(sys.appId),
                       "setting": "allow", "grantedBy": "system" });
        }

        out.sort(function(a, b) { return a.title.localeCompare(b.title); });
        return out;
    }


    width: parent ? parent.width : implicitWidth

    function refresh() {
        luna.call(webAppManager + "/getAppPermissions",
                  JSON.stringify({"permission": permissionList.permission}),
                  _handleList, _handleUnavailable);
    }

    function setSetting(appId, setting) {
        luna.call(webAppManager + "/setAppPermission",
                  JSON.stringify({"appId": appId,
                                  "permission": permissionList.permission,
                                  "setting": setting}),
                  _handleChange, _handleUnavailable);
    }

    function resetAll() {
        luna.call(webAppManager + "/resetAppPermissions",
                  JSON.stringify({"permission": permissionList.permission}),
                  _handleChange, _handleUnavailable);
    }

    function _handleList(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            console.warn("getAppPermissions " + permissionList.permission +
                         " refused: " + message.payload);
            permissionList.available = false;
            return;
        }

        permissionList.entries = response.apps ? response.apps : [];
        permissionList.available = true;
    }

    // Every change is followed by a fresh read, so the list shows what is
    // stored rather than what was asked for - including when it was refused.
    function _handleChange(message) {
        if (message && message.payload) {
            var response = JSON.parse(message.payload);
            if (!response.returnValue)
                console.warn("Cannot change " + permissionList.permission +
                             " permission: " + message.payload);
        }
        refresh();
    }

    function _handleUnavailable(message) {
        console.warn("WebAppMgr did not answer for " + permissionList.permission +
                     " permissions: " + message);
        permissionList.available = false;
    }

    function _handleListApps(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        // SAM sends no "apps" while it is still starting up, and only the
        // changed entries afterwards; neither is an empty device.
        if (response.returnValue && response.hasOwnProperty("apps") && response.apps)
            permissionList.apps = response.apps;
    }

    Component.onCompleted: {
        refresh();
        // Titles and appinfo.json grants. Subscribed, so an application
        // installed or removed while the page is open shows up here.
        luna.subscribe("luna://com.webos.service.applicationManager/listApps",
                       JSON.stringify({"subscribe": true}),
                       _handleListApps, function(message) {
                           console.warn("Application manager did not answer: " + message);
                       });
    }

    // Nothing reports an answer given elsewhere - an application's own
    // permission question, or the other page - so read the list again
    // whenever the page comes back to the front.
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.application.state === Qt.ApplicationActive)
                permissionList.refresh();
        }
    }

    ServiceUnavailableNotice {
        visible: !permissionList.available
        serviceName: "com.webos.service.webappmanager"
        description: "WebAppMgr did not answer, so what applications have " +
                     "been allowed cannot be shown or changed until it does."
        onRetry: permissionList.refresh()
    }

    Label {
        width: parent.width
        visible: permissionList.available && permissionList.rows.length === 0
        height: visible ? Units.gu(6) : 0
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: permissionList.emptyText
        color: "#666666"
        font.pixelSize: FontUtils.sizeToPixels("medium")
    }

    Repeater {
        model: permissionList.available ? permissionList.rows : []

        delegate: Column {
            width: permissionList.width

            readonly property var row: modelData
            readonly property bool granted: row.grantedBy !== ""

            HorizontalSeparator {
                width: parent.width
                visible: index > 0
                height: visible ? 1 : 0
            }

            // A stored decision: either way, or forget it.
            LabelAndSelector {
                width: parent.width
                visible: !granted
                label: row.title
                model: permissionList.storedChoices
                currentIndex: row.setting === "block" ? 1 : 0
                onActivated: (index) => permissionList.setSetting(
                                 row.appId, permissionList.storedSettings[index])
            }

            // Granted by appinfo.json: nothing stored to forget, but it can
            // be overruled with a decision of its own.
            LabelAndSelector {
                width: parent.width
                visible: granted
                label: row.title
                model: [row.grantedBy === "system" ? "Allowed (system)" : "Allowed (by app)",
                        "Denied"]
                currentIndex: 0
                onActivated: (index) => permissionList.setSetting(
                                 row.appId, index === 1 ? "block" : "allow")
            }
        }
    }
}
