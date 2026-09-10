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

import "../Common"

/*
 * Applications, after webOS 3.0.5's Software Manager (com.palm.app.swmanager),
 * whose icon this uses.
 *
 * There has been no way to see what is installed, what it may do, or to
 * remove any of it without Preware. SFOS has packages and sideloading,
 * UBports has App Access under Security & Privacy, GNOME has an Applications
 * panel, FuriOS adds hiding apps from the drawer.
 *
 * Two services, both already there:
 *  - com.webos.service.applicationManager/listApps, subscribed, is the list.
 *    Each entry is that application's whole appinfo.json plus what SAM works
 *    out for itself: "systemApp" and "removable", which it forces to false
 *    for anything it considers a system app, so this page never has to decide
 *    what is safe to remove - it asks.
 *  - com.webos.appInstallService/remove takes the id and does the removing.
 *
 * The permissions each application asked for are the requiredPermissions of
 * its own appinfo, which is what LS2 turns into that application's ACG
 * membership at build time. It is the closest thing webOS has to the
 * permission list the other three show, and until now it was only visible by
 * reading files on the device.
 *
 * System applications are hidden behind a switch rather than left out: half
 * of what is installed on a webOS device is a service or a shell piece with
 * visible: false, and a list that led with those would be useless. They are
 * worth being able to see, though, which is why the switch is there.
 *
 * Removal is a sideways swipe, the webOS delete gesture, the same as removing
 * a keyboard on the Regional Settings page - so it takes a deliberate
 * movement rather than one mistaken tap.
 */
BasePage {
    id: pageRoot

    property bool serviceAvailable: false
    property var apps: []
    property bool showSystemApps: false

    // The application whose details are open, by id. Only one at a time:
    // this is a list to look down, not a set of panels to leave open.
    property string expandedId: ""

    property string lastRemoved: ""
    property string removeError: ""

    Component.onCompleted: retrieveProperties();

    function visibleApps() {
        var out = [];
        for (var i = 0; i < pageRoot.apps.length; i++) {
            var app = pageRoot.apps[i];
            if (pageRoot.showSystemApps || !pageRoot.isSystemApp(app))
                out.push(app);
        }
        return out;
    }

    /*
     * "systemApp" is SAM's own judgement and is the one to trust. Falling
     * back to "visible" for anything that predates it: an application the
     * launcher never shows is not one an ordinary list should lead with
     * either.
     */
    function isSystemApp(app) {
        if (app.hasOwnProperty("systemApp"))
            return app.systemApp === true;
        return app.visible === false;
    }

    function permissionsOf(app) {
        if (!app.requiredPermissions || app.requiredPermissions.length === 0)
            return "";
        return app.requiredPermissions.join(", ");
    }

    SettingsPageContent {
        // A list of everything installed needs the width.
        maximumContentWidth: Units.gu(72)

        ServiceUnavailableNotice {
            visible: !pageRoot.serviceAvailable
            serviceName: "com.webos.service.applicationManager"
            description: "The application manager did not answer, so what is " +
                         "installed cannot be listed."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.serviceAvailable

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: systemAppsSwitch
                    label: "Show System Apps"

                    checked: pageRoot.showSystemApps
                    onToggled: pageRoot.showSystemApps = checked
                }
            }
        }

        ExplanationText {
            visible: pageRoot.serviceAvailable
            text: "System applications are the shell, the built-in services " +
                  "and anything else the device needs. They cannot be removed."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.serviceAvailable

            title: "Installed"

            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.visibleApps()

                    delegate: Column {
                        width: parent.width

                        SwipeRow {
                            id: appRow
                            text: modelData.title ? modelData.title : modelData.id

                            // SAM decides this, not the page.
                            swipe.enabled: modelData.removable === true
                            LuneOSSwipeDelegate.confirmText: "Remove"
                            LuneOSSwipeDelegate.onConfirmed: pageRoot.removeApp(modelData.id)

                            onClicked: pageRoot.expandedId =
                                       (pageRoot.expandedId === modelData.id ? "" : modelData.id)

                            Label {
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.version ? modelData.version : ""
                                color: "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }

                        Column {
                            width: parent.width - Units.gu(2)
                            x: Units.gu(1)
                            visible: pageRoot.expandedId === modelData.id

                            LabelAndValue {
                                width: parent.width
                                label: "ID"
                                value: modelData.id
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: modelData.type !== undefined
                                height: visible ? Units.gu(6) : 0
                                label: "Type"
                                value: modelData.type !== undefined ? modelData.type : ""
                            }

                            LabelAndValue {
                                width: parent.width
                                visible: modelData.vendor !== undefined
                                height: visible ? Units.gu(6) : 0
                                label: "Vendor"
                                value: modelData.vendor !== undefined ? modelData.vendor : ""
                            }

                            Label {
                                width: parent.width
                                visible: pageRoot.permissionsOf(modelData) !== ""
                                topPadding: Units.gu(0.5)
                                text: "May use: " + pageRoot.permissionsOf(modelData)
                                wrapMode: Text.WordWrap
                                color: "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }

                            Label {
                                width: parent.width
                                visible: pageRoot.permissionsOf(modelData) === ""
                                topPadding: Units.gu(0.5)
                                bottomPadding: Units.gu(0.5)
                                text: "Asks for nothing beyond what every " +
                                      "application may do."
                                wrapMode: Text.WordWrap
                                color: "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }

                            Label {
                                width: parent.width
                                visible: modelData.removable !== true
                                bottomPadding: Units.gu(0.5)
                                text: "Part of the system; it cannot be removed."
                                wrapMode: Text.WordWrap
                                color: "#666666"
                                font.pixelSize: FontUtils.sizeToPixels("small")
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: pageRoot.visibleApps().length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "Nothing is installed."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        ExplanationText {
            visible: pageRoot.serviceAvailable
            text: "Swipe an application sideways to remove it. Tap one to see " +
                  "what it is and what it is allowed to do."
        }

        ExplanationText {
            visible: pageRoot.removeError !== ""
            text: pageRoot.removeError
        }
    }

    /*
     * Bindings with LuneOS
     */
    function retrieveProperties() {
        // Subscribed: an install or a removal from anywhere - Preware, an
        // ipk dropped over ssh - reaches this list without it being asked
        // again.
        luna.subscribe("luna://com.webos.service.applicationManager/listApps",
                       JSON.stringify({"subscribe": true}),
                       _handleListApps, _handleServiceUnavailable);
    }

    function _handleListApps(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.serviceAvailable = false;
            return;
        }

        /*
         * SAM sends no "apps" at all while it is still starting up, and
         * sends the changed entries rather than the whole list once
         * subscribed. Neither is an empty device, so leave what is here
         * standing rather than blanking the page.
         */
        if (response.hasOwnProperty("apps") && response.apps)
            pageRoot.apps = response.apps;

        pageRoot.serviceAvailable = true;
    }

    function _handleServiceUnavailable(message) {
        console.warn("Application manager did not answer: " + message);
        pageRoot.serviceAvailable = false;
    }

    function removeApp(appId) {
        pageRoot.removeError = "";
        pageRoot.lastRemoved = appId;

        luna.call("luna://com.webos.appInstallService/remove",
                  JSON.stringify({"id": appId}),
                  _handleRemove, _handleRemoveError);
    }

    function _handleRemove(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.removeError = "Could not remove " + pageRoot.lastRemoved +
                                   (response.errorText ? (": " + response.errorText) : ".");
            return;
        }

        // The list is subscribed, so it corrects itself once the removal has
        // actually happened; nothing to do here.
        if (pageRoot.expandedId === pageRoot.lastRemoved)
            pageRoot.expandedId = "";
    }

    function _handleRemoveError(message) {
        pageRoot.removeError = "Could not remove " + pageRoot.lastRemoved + ": " + message;
    }
}
