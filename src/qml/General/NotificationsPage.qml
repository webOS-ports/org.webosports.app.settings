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
 * Notifications.
 *
 * One application that will not stop banner-ing was not something a person
 * could do anything about. SFOS, UBports and GNOME all let notifications be
 * turned off per application; here there was no page, and no working service
 * call behind one either - com.webos.notification's disableToast has always
 * taken a "source", and has always accepted it, answered success and done
 * nothing, because the two functions behind it were `return true;` and no
 * more.
 *
 * That is fixed in notificationmgr (meta-webos-ports,
 * 0011-notificationmgr-remember-which-applications-may-not-show-a-toast),
 * which persists the set, enforces it in createToast, and adds a
 * subscribable getToastSettings to read it back. This page is the two ends
 * of that: the list comes from the application manager, the blocked set from
 * getToastSettings, and a switch calls enableToast or disableToast with the
 * application's id.
 *
 * There is no global on/off switch here, and that is deliberate rather than
 * missing. The two global calls that exist are not a setting: "enable" and
 * "disable" are privileged and transient - the shell uses them to hold
 * notifications back during a call or a first-boot - and disableToast with
 * no source sets a timestamp that suppresses banners for a while rather than
 * turning anything off. So the global state is reported when something else
 * has switched it, and not offered as a switch that would not stay where it
 * was put.
 *
 * The two settings that do persist and are about notifications - whether
 * they show on the lock screen, and whether the centre button blinks - have
 * been on Screen & Lock since that page was ported, and this one links there
 * rather than growing a second copy.
 */
BasePage {
    id: pageRoot

    property bool notificationServiceAvailable: false
    property bool appServiceAvailable: false

    property bool toastsEnabled: true
    property var blockedApps: []
    property var apps: []

    Component.onCompleted: retrieveProperties();

    /*
     * Only what a person would recognise. A notification comes from an
     * application by id, and half of what is installed is a service or a
     * piece of the shell - which can post a toast, but is not something to
     * offer a switch for.
     */
    function listedApps() {
        var out = [];
        for (var i = 0; i < pageRoot.apps.length; i++) {
            var app = pageRoot.apps[i];
            var isSystem = app.hasOwnProperty("systemApp") ? app.systemApp === true
                                                           : app.visible === false;
            if (!isSystem)
                out.push(app);
        }
        return out;
    }

    function isAllowed(appId) {
        return pageRoot.blockedApps.indexOf(appId) < 0;
    }

    SettingsPageContent {
        ServiceUnavailableNotice {
            visible: !pageRoot.notificationServiceAvailable
            serviceName: "com.webos.notification"
            description: "The notification manager did not answer " +
                         "getToastSettings. A build older than the one that " +
                         "added it cannot block an application's banners at " +
                         "all, whatever this page showed."
            onRetry: pageRoot.retrieveProperties()
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.notificationServiceAvailable && !pageRoot.toastsEnabled

            title: "Currently off"

            Column {
                width: parent.width

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Something has switched notifications off for " +
                          "everything - a call, or the device still starting " +
                          "up. It is not a setting and it comes back on by " +
                          "itself."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.notificationServiceAvailable &&
                     pageRoot.appServiceAvailable

            title: "Applications"

            Column {
                width: parent.width

                Repeater {
                    model: pageRoot.listedApps()

                    delegate: Column {
                        width: parent.width

                        HorizontalSeparator {
                            width: parent.width
                            visible: index > 0
                            height: visible ? 1 : 0
                        }

                        LabelAndSwitch {
                            id: appSwitch
                            label: modelData.title ? modelData.title : modelData.id

                            checked: pageRoot.isAllowed(modelData.id)
                            Connections {
                                target: pageRoot
                                function onBlockedAppsChanged() {
                                    appSwitch.checked = pageRoot.isAllowed(modelData.id);
                                }
                            }
                            onToggled: pageRoot.setAllowed(modelData.id, checked)
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: pageRoot.listedApps().length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    text: "Nothing is installed that posts notifications."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        ExplanationText {
            visible: pageRoot.notificationServiceAvailable
            text: "An application that is off here cannot put a banner on " +
                  "screen. It can still do everything else it does, and a " +
                  "system message - a low battery, a missed call - arrives " +
                  "whatever is set."
        }

        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                Button {
                    text: "Screen & Lock"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openScreenLockSettings()
                }
            }
        }

        ExplanationText {
            text: "Whether notifications show on the lock screen, and whether " +
                  "the centre button blinks for them, are set there."
        }
    }

    /*
     * Bindings with LuneOS
     */
    function retrieveProperties() {
        // Both subscribed: an application arriving or leaving changes the
        // list, and something else blocking an application changes the
        // switches.
        luna.subscribe("luna://com.webos.notification/getToastSettings",
                       JSON.stringify({"subscribe": true}),
                       _handleToastSettings, _handleNotificationUnavailable);

        luna.subscribe("luna://com.webos.service.applicationManager/listApps",
                       JSON.stringify({"subscribe": true}),
                       _handleListApps, _handleAppServiceUnavailable);
    }

    function _handleToastSettings(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.notificationServiceAvailable = false;
            return;
        }

        if (response.hasOwnProperty("enabled"))
            pageRoot.toastsEnabled = response.enabled === true;
        pageRoot.blockedApps = response.blockedApps ? response.blockedApps : [];

        pageRoot.notificationServiceAvailable = true;
    }

    function _handleNotificationUnavailable(message) {
        console.warn("Notification manager did not answer: " + message);
        pageRoot.notificationServiceAvailable = false;
    }

    function _handleListApps(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.appServiceAvailable = false;
            return;
        }

        // SAM sends no "apps" while it is still starting up, and only the
        // changed entries afterwards; neither is an empty device.
        if (response.hasOwnProperty("apps") && response.apps)
            pageRoot.apps = response.apps;

        pageRoot.appServiceAvailable = true;
    }

    function _handleAppServiceUnavailable(message) {
        console.warn("Application manager did not answer: " + message);
        pageRoot.appServiceAvailable = false;
    }

    function setAllowed(appId, allowed) {
        // The subscription reports the new set, so nothing is held locally -
        // and if the call is refused the switch goes back on its own rather
        // than showing something that is not true.
        luna.call(allowed ? "luna://com.webos.notification/enableToast"
                          : "luna://com.webos.notification/disableToast",
                  JSON.stringify({"source": appId}),
                  _handleToastChange, _handleSetError);
    }

    function _handleToastChange(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            console.warn("Cannot change notifications for that application: " +
                         message.payload);
        }
    }

    // Each settings category is its own launchable application on the device.
    function openScreenLockSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.screenlock"}),
                  _handleSetSuccess, _handleSetError);
    }
}
