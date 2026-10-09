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
 * location or notifications - as the permission prompt answered it.
 *
 * The answers are kept by the web runtime itself (WebAppMgr, in the browser
 * engine's own per-application settings), which is what decides the next
 * request; this list reads and changes them there through WebAppMgr's
 * getAppPermissions / setAppPermission / resetAppPermissions rather than
 * keeping a copy of its own that could drift from what is enforced.
 *
 * Only applications that have been asked are listed: one that never asked
 * has nothing to change. "Ask Again" forgets the answer, so the application
 * drops off the list and is asked the next time it wants the permission.
 * Applications shipped with the system that are granted the permission by
 * their own appinfo.json are shown without a choice, since nothing here could
 * change that.
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
    property var entries: []
    // Application id to title, from the application manager.
    property var titles: ({})

    readonly property var choices: ["Allowed", "Denied", "Ask Again"]
    readonly property var settingForChoice: ["allow", "block", "ask"]


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

    function titleFor(appId) {
        return permissionList.titles.hasOwnProperty(appId) ? permissionList.titles[appId]
                                                            : appId;
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
        if (!response.returnValue || !response.apps)
            return;

        var names = {};
        for (var i = 0; i < response.apps.length; i++) {
            var app = response.apps[i];
            names[app.id] = app.title ? app.title : app.id;
        }
        permissionList.titles = names;
    }

    Component.onCompleted: {
        refresh();
        // Titles only; the ids alone are still usable if this does not answer.
        luna.call("luna://com.webos.service.applicationManager/listApps", "{}",
                  _handleListApps, function(message) {
                      console.warn("Application manager did not answer: " + message);
                  });
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
        visible: permissionList.available && permissionList.entries.length === 0
        height: visible ? Units.gu(6) : 0
        verticalAlignment: Text.AlignVCenter
        wrapMode: Text.WordWrap
        text: permissionList.emptyText
        color: "#666666"
        font.pixelSize: FontUtils.sizeToPixels("medium")
    }

    Repeater {
        model: permissionList.available ? permissionList.entries : []

        delegate: Column {
            width: permissionList.width

            readonly property var entry: modelData

            HorizontalSeparator {
                width: parent.width
                visible: index > 0
                height: visible ? 1 : 0
            }

            LabelAndValue {
                width: parent.width
                visible: entry.system === true
                label: permissionList.titleFor(entry.appId)
                value: "Allowed (system)"
            }

            LabelAndSelector {
                width: parent.width
                visible: entry.system !== true
                label: permissionList.titleFor(entry.appId)
                model: permissionList.choices
                currentIndex: entry.setting === "block" ? 1 : 0
                onActivated: (index) => permissionList.setSetting(
                                 entry.appId, permissionList.settingForChoice[index])
            }
        }
    }
}
