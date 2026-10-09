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
 *
 * The notification LED's colours are here, though, rather than in a panel of
 * their own. Choosing one is a per-application choice about notifications, and
 * the list of applications - and the filtering in listedApps() that decides
 * which of them are worth offering - already exists on this page; a second
 * panel would repeat both. The LED's on/off switch stays where it is, on
 * Screen & Lock: that switch writes BlinkNotifications, which is the key legacy
 * Preferences.cpp read into m_ledThrobberEnabled and the one the shell now
 * checks before lighting the LED. It is read here only to say why a colour
 * would have no effect.
 */
BasePage {
    id: pageRoot

    property bool notificationServiceAvailable: false
    property bool appServiceAvailable: false

    property bool toastsEnabled: true
    property var blockedApps: []
    property var apps: []

    // Whether the LED blinks at all, owned by Screen & Lock; read only here.
    property bool blinkNotifications: true

    /*
     * The notificationLedColors preference verbatim: application id to colour
     * string, with "*" for the colour every other application falls back to.
     *
     * Held as the whole object because one preference holds every
     * application's colour, so a change is a read-modify-write and dropping a
     * key this page did not know about would lose somebody else's setting.
     * "*" cannot collide with an application id - those are reverse-DNS names -
     * which is why this stays a flat map rather than a nested object.
     */
    property var ledColors: ({})

    // Preferences arrive asynchronously; do not write before the first read
    // has landed or the default above would overwrite the device.
    property bool ledPrefsLoaded: false

    readonly property string defaultLedColorKey: "*"

    /*
     * The colours on offer, a fixed short list rather than a full picker.
     * These LEDs are a few millimetres of diffused plastic: telling red from
     * orange on one is realistic, telling apart two neighbouring shades of
     * teal is not, and a picker would suggest otherwise.
     *
     * "" means nothing set, which on an application row is "use the default"
     * and on the default row is the shell's own white. Values are the plain
     * six-digit hex the shell hands to nyx.
     */
    readonly property var ledColorChoices: [
        { "key": "",        "label": "Default" },
        { "key": "#ffffff", "label": "White"   },
        { "key": "#ff0000", "label": "Red"     },
        { "key": "#ff6000", "label": "Orange"  },
        { "key": "#ffd000", "label": "Yellow"  },
        { "key": "#00ff00", "label": "Green"   },
        { "key": "#00ffd0", "label": "Cyan"    },
        { "key": "#0000ff", "label": "Blue"    },
        { "key": "#8000ff", "label": "Purple"  },
        { "key": "#ff00c0", "label": "Magenta" }
    ]

    Component.onCompleted: retrieveProperties();

    // Colour stored for an application, or "" when it has none of its own.
    function ledColorFor(appId) {
        if (pageRoot.ledColors && pageRoot.ledColors.hasOwnProperty(appId))
            return pageRoot.ledColors[appId];
        return "";
    }

    /*
     * The colour an application will actually blink in, following the same
     * fallback the shell applies, so that the swatch shown is the truth rather
     * than an empty circle for every application that has not been set.
     */
    function effectiveLedColorFor(appId) {
        var own = ledColorFor(appId);
        if (own !== "")
            return own;

        var fallback = ledColorFor(pageRoot.defaultLedColorKey);
        return fallback !== "" ? fallback : "#ffffff";
    }

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
            title: "Notification LED"

            Column {
                width: parent.width

                LedColorRow {
                    width: parent.width
                    label: "Default colour"
                    colorChoices: pageRoot.ledColorChoices
                    colorValue: pageRoot.ledColorFor(pageRoot.defaultLedColorKey)
                    effectiveColor: pageRoot.effectiveLedColorFor(pageRoot.defaultLedColorKey)
                    // With nothing stored this row resolves to the shell's own
                    // white, so that is what it says.
                    placeholder: "White"
                    onClicked: ledColorPicker.openFor(pageRoot.defaultLedColorKey,
                                                      "Default colour")
                }

                ExplanationText {
                    text: "Used for any application without a colour of its own."
                }

                /*
                 * Says plainly why the colours would do nothing, rather than
                 * leaving the user to wonder. Empty text hides itself, so the
                 * ordinary case costs no gap in the column.
                 */
                ExplanationText {
                    text: !pageRoot.blinkNotifications
                          ? "The notification LED is switched off: turn on " +
                            "Blink Notifications in Screen & Lock to use these " +
                            "colours."
                          : ""
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

                        /*
                         * Inset under the application's own switch, so it reads
                         * as belonging to it rather than as another application.
                         * Hidden when the application may not show a
                         * notification at all, since then there is nothing for
                         * the LED to blink for.
                         */
                        LedColorRow {
                            x: Units.gu(2)
                            width: parent.width - Units.gu(2)
                            visible: appSwitch.checked
                            label: "LED colour"
                            colorChoices: pageRoot.ledColorChoices
                            colorValue: pageRoot.ledColorFor(modelData.id)
                            effectiveColor: pageRoot.effectiveLedColorFor(modelData.id)
                            onClicked: ledColorPicker.openFor(
                                           modelData.id,
                                           modelData.title ? modelData.title : modelData.id)
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

        /*
         * A different question from the switches above: those decide whether
         * an application's banners reach the screen at all, this is what a
         * web application was answered when it asked to use the HTML5
         * Notification API. See Common/AppPermissionList.qml.
         */
        GroupBox {
            width: parent.width

            title: "Web Applications"

            AppPermissionList {
                width: parent.width
                permission: "notifications"
                luna: pageRoot.luna
                emptyText: "No web application has asked to show notifications yet."
            }
        }

        ExplanationText {
            text: "A web application asks before it shows notifications. " +
                  "Ask Again forgets the answer, so it asks the next time."
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
                  "the notification LED blinks for them at all, are set there."
        }
    }

    ListPickerPopup {
        id: ledColorPicker

        // Which row opened it: an application id, or "*" for the default.
        property string targetAppId: ""

        entries: pageRoot.ledColorChoices
        currentKey: pageRoot.ledColorFor(targetAppId)
        emptyText: "No colours available."

        function openFor(appId, rowTitle) {
            targetAppId = appId;
            title = rowTitle;
            open();
        }

        onPicked: (key, entry) => pageRoot.setLedColorFor(ledColorPicker.targetAppId, key)
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

        // Subscribed so that the swatches follow a colour changed elsewhere,
        // and so that turning the LED off on Screen & Lock shows up here.
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["BlinkNotifications", "notificationLedColors"],
                                       "subscribe": true}),
                       _handleGetPreferences, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("BlinkNotifications"))
            pageRoot.blinkNotifications = response.BlinkNotifications;

        if (response.hasOwnProperty("notificationLedColors")) {
            var colors = response.notificationLedColors;

            /*
             * Tolerated for the same reason the shell tolerates it: a
             * preference is whatever was last written, so a hand-edited string
             * or a value left over from an earlier shape must not break the
             * page. Anything that is not an object is treated as nothing set.
             */
            if (typeof colors === "string") {
                try {
                    colors = JSON.parse(colors);
                } catch (e) {
                    console.warn("Stored notification LED colours are not valid JSON: " + colors);
                    colors = null;
                }
            }

            pageRoot.ledColors = (colors && typeof colors === "object") ? colors : ({});
        }

        pageRoot.ledPrefsLoaded = true;
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

    /*
     * One preference holds every application's colour, so this is a
     * read-modify-write of the object the subscription last gave us.
     *
     * An unset row deletes its key rather than storing "": that keeps the
     * stored object down to the applications that actually have a colour, and
     * leaves the shell's own fallback to decide what the rest blink in.
     *
     * The local copy is replaced rather than mutated, because QML only
     * re-evaluates the swatches and names bound to ledColors when the property
     * itself changes; mutating it in place would leave every row showing the
     * old colour until the subscription replied.
     */
    function setLedColorFor(appId, color) {
        if (!pageRoot.ledPrefsLoaded) {
            console.log("Trying to set preferences before reading them first: ignoring.");
            return;
        }

        var updated = {};
        for (var key in pageRoot.ledColors) {
            if (pageRoot.ledColors.hasOwnProperty(key))
                updated[key] = pageRoot.ledColors[key];
        }

        if (color === "")
            delete updated[appId];
        else
            updated[appId] = color;

        pageRoot.ledColors = updated;

        luna.call("luna://com.webos.service.systemservice/setPreferences",
                  JSON.stringify({"notificationLedColors": updated}),
                  _handleSetSuccess, _handleSetError);
    }

    // Each settings category is its own launchable application on the device.
    function openScreenLockSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.screenlock"}),
                  _handleSetSuccess, _handleSetError);
    }
}
