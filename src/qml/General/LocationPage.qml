/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * Location Services, after the webOS 3.0.5 app of the same name
 * (com.palm.app.location).
 *
 * Same rows in the same order as the original: what websites may do with your
 * location and a way to forget what they were told, what applications may do
 * with it, whether photographs are stamped with it, and which of the sources
 * the device is allowed to locate itself from.
 *
 * The original put the source choice in the application menu ("Locate Me
 * Using... GPS / Google Services"). There is no application menu on a QML
 * settings page, so the two sources are a group of their own here; the second
 * one is called Network Location rather than Google Services because on LuneOS
 * that path goes through geoclue, not through HP's arrangement with Google.
 *
 * Where this stands on LuneOS:
 *   - GPS Status and Locate Me Using talk to com.webos.service.location, a
 *     considerably bigger LG/webOS-OSE-lineage service confirmed live against
 *     real hardware (sargo, mindphone). See the methods documented below -
 *     unchanged from the first version of this page.
 *   - For Websites / For Applications / Geotag Photos drove a guessed
 *     com.palm.location for a while. That guess turned out right about the
 *     bus name (the legacy service really was called that - the native
 *     mojolocation daemon, recovered from the shipped TouchPad rootfs at
 *     usr/palm/services/com.palm.location.service) but wrong about there
 *     being anything to port: mojolocation does not exist on LuneOS, has no
 *     replacement, and the shipped webOS Settings app's own JS
 *     (com.palm.app.location/app/controllers/main-assistant.js, same file
 *     byte-for-byte on both the TouchPad and 305att/Pre3 rootfs images this
 *     was checked against) only ever exposed one global "share location with
 *     websites" toggle and one bulk "Clear My Location Data" button - never a
 *     browsable per-site or per-app list, even though mojolocation's own
 *     data model could have supported one (db8 kind
 *     com.palm.location.LocationServicesAdvancedPrefs:1, indexed on "url",
 *     one row per appId or per site with a permissionState - see
 *     LocationCategoryHandler.cpp in the Pre3 mojolocation decompile).
 *
 *     So this page now does two real things instead of pretending at one
 *     fake service:
 *       - autoLocate / webSetting / geotagPhotos are ordinary preferences
 *         (com.webos.service.systemservice), the same mechanism
 *         TextAssistPage's keyboard settings use - always available, no
 *         "service unavailable" gating needed for these three switches
 *         any more.
 *       - Granted Access is new, genuinely per-app/per-site, and goes
 *         further than the legacy app's shipped UI ever did - it is what
 *         mojolocation's own data model always supported but nothing put in
 *         front of a user. Stored as ordinary db8 records (com.palm.db),
 *         org.webosports.app.settings.locationgrants:1, one row per grant -
 *         the same "own kind, own namespace" pattern TextAssistPage's user
 *         dictionary already uses. Nothing on LuneOS today prompts a user
 *         for location and writes a grant here yet - db8 is genuinely empty
 *         on a fresh device, same as it would be on a fresh legacy one - but
 *         the list, and revoking one entry at a time, work end to end
 *         against whatever any future permission prompt puts there.
 *
 * The methods this page uses on com.webos.service.location, confirmed by
 * introspection and by calling them against sargo and mindphone:
 *   getLocationUpdates { subscribe: bool }
 *      -> { returnValue, errorCode, timestamp, latitude, longitude, altitude,
 *           direction, speed, horizAccuracy, vertAccuracy }
 *      One reply acknowledges the subscription (no position fields yet), then
 *      one per fix. horizAccuracy/timestamp/latitude/longitude are the same
 *      field names the original guess used, so only the method name and the
 *      subscribe payload actually needed to change.
 *   getAllLocationHandlers { subscribe: bool }
 *      -> { returnValue, handlers: [ { name, state } ] }
 *      name is "gps" or "network" on the devices this was tried against;
 *      state is a plain boolean here (unlike getState below).
 *   setState { Handler: string, state: bool }
 *      -> { returnValue }
 *      Handler capitalised - lowercase "handler" fails schema validation
 *      with errorCode 10 "Invalid input", found the hard way against real
 *      hardware. Same "gps"/"network" names as getAllLocationHandlers.
 *
 * getState (singular) exists too but was left unused: it answers "state" as
 * a number where every other call in this service uses a boolean, and
 * getAllLocationHandlers already carries the same information without the
 * inconsistency.
 */
BasePage {
    id: pageRoot

    // The real, live service: GPS Status and Locate Me Using.
    readonly property string gpsService: "com.webos.service.location"
    // Where Granted Access lives - com.palm.db is the same real db8 bus
    // TextAssistPage's dictionary uses, not a placeholder.
    readonly property string grantsKind: "org.webosports.app.settings.locationgrants:1"

    property bool autoLocate: true
    property bool webSetting: true
    property bool geotagPhotos: false
    property bool cameraAvailable: true

    property var locationGrants: []

    // GPS Status: independent of the preferences above, and of whether they
    // ever arrive - com.webos.service.location already answers this today.
    property bool gpsTracking: false
    property bool gpsFixReceived: false
    property bool gpsReachable: true
    property real gpsLatitude: 0
    property real gpsLongitude: 0
    property real gpsAccuracy: 0
    property real gpsFixTimestamp: 0
    property var _trackingCall: null

    // Locate Me Using: also gpsService, also live - getAllLocationHandlers
    // rather than a guess at what com.palm.location might have offered.
    property bool handlersAvailable: false
    property bool gpsHandlerPresent: false
    property bool gpsHandlerEnabled: false
    property bool networkHandlerPresent: false
    property bool networkHandlerEnabled: false

    Component.onCompleted: {
        retrieveProperties();
        retrieveLocationHandlers();
        retrieveLocationGrants();
    }

    SettingsPageContent {
        GroupBox {
            width: parent.width
            title: "GPS Status"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: gpsTrackingSwitch
                    label: "Show My Location"

                    checked: pageRoot.gpsTracking
                    Connections {
                        target: pageRoot
                        function onGpsTrackingChanged() {
                            gpsTrackingSwitch.checked = pageRoot.gpsTracking;
                        }
                    }
                    onToggled: checked ? pageRoot.startGpsTracking() : pageRoot.stopGpsTracking()
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.gpsFixReceived
                }

                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.gpsFixReceived
                    label: "Latitude"
                    value: pageRoot.gpsFixReceived ? pageRoot.gpsLatitude.toFixed(5) : ""
                }
                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.gpsFixReceived
                    label: "Longitude"
                    value: pageRoot.gpsFixReceived ? pageRoot.gpsLongitude.toFixed(5) : ""
                }
                LabelAndValue {
                    width: parent.width
                    visible: pageRoot.gpsFixReceived
                    label: "Accuracy"
                    value: pageRoot.gpsFixReceived ? Math.round(pageRoot.gpsAccuracy) + " m" : ""
                }
            }
        }

        ExplanationText {
            text: {
                if (!pageRoot.gpsReachable)
                    return "location-service did not answer. GPS may not be " +
                           "available on this device.";
                if (pageRoot.gpsTracking && !pageRoot.gpsFixReceived)
                    return "Waiting for a fix...";
                if (pageRoot.gpsFixReceived)
                    return "Last updated " +
                           new Date(pageRoot.gpsFixTimestamp * 1000).toLocaleTimeString(Qt.locale(), Locale.ShortFormat);
                return "";
            }
        }

        GroupBox {
            width: parent.width

            title: "For Websites"
            Column {
                width: parent.width

                LabelAndSelector {
                    id: webSettingSelector
                    width: parent.width
                    label: "Location"
                    model: ["Never Share Location", "Always Ask"]

                    currentIndex: pageRoot.webSetting ? 1 : 0
                    Connections {
                        target: pageRoot
                        function onWebSettingChanged() {
                            webSettingSelector.currentIndex = pageRoot.webSetting ? 1 : 0;
                        }
                    }
                    onActivated: (index) => pageRoot.setWebSetting(index === 1)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    text: "Clear My Location Data"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: clearDataDialog.open()
                }
            }
        }

        ExplanationText {
            text: pageRoot.webSetting
                  ? "You will be asked for authorization when a website requests your location."
                  : "Your location will never be provided to websites that request it."
        }

        GroupBox {
            width: parent.width

            title: "For Applications"

            LabelAndSelector {
                id: autoLocateSelector
                width: parent.width
                label: "Location"
                model: ["Always Ask", "Auto Locate"]

                currentIndex: pageRoot.autoLocate ? 1 : 0
                Connections {
                    target: pageRoot
                    function onAutoLocateChanged() {
                        autoLocateSelector.currentIndex = pageRoot.autoLocate ? 1 : 0;
                    }
                }
                onActivated: (index) => pageRoot.setAutoLocate(index === 1)
            }
        }

        ExplanationText {
            text: pageRoot.autoLocate
                  ? "Your location will be automatically provided to applications that request it."
                  : "You will be asked for authorization when an application requests your location."
        }

        /*
         * Genuinely per-app/per-site, unlike the three groups above - the
         * legacy app never showed this even though its own data model
         * supported it. Empty until something writes a grant here (nothing
         * on LuneOS prompts for location yet), same as it would be on a
         * freshly flashed legacy device too.
         */
        GroupBox {
            width: parent.width

            title: "Granted Access"
            Column {
                width: parent.width

                Label {
                    width: parent.width
                    visible: pageRoot.locationGrants.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: "No app or website has been given your location yet."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                Repeater {
                    model: pageRoot.locationGrants

                    delegate: Column {
                        id: grantRow
                        width: parent.width

                        readonly property var grant: modelData
                        property bool pendingDelete: false

                        // Normal row: what it is and what kind of grant.
                        // Swipe sideways to ask for delete confirmation
                        // (webOS delete gesture).
                        Item {
                            width: parent.width
                            height: Units.gu(7)
                            visible: !grantRow.pendingDelete

                            Column {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Units.gu(1)
                                anchors.rightMargin: Units.gu(1)

                                Label {
                                    width: parent.width
                                    text: grantRow.grant.displayName ||
                                          grantRow.grant.appId || grantRow.grant.url
                                    elide: Text.ElideRight
                                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                                }
                                Label {
                                    width: parent.width
                                    text: grantRow.grant.url ? "Website" : "Application"
                                    elide: Text.ElideRight
                                    color: "#666666"
                                    font.pixelSize: FontUtils.sizeToPixels("small")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent

                                property real _pressX: 0

                                onPressed: (mouse) => { _pressX = mouse.x; }
                                onReleased: (mouse) => {
                                    if (Math.abs(mouse.x - _pressX) > Units.gu(4))
                                        grantRow.pendingDelete = true;
                                }
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            height: Units.gu(7)
                            spacing: Units.gu(2)
                            visible: grantRow.pendingDelete

                            Button {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Cancel"
                                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                onClicked: grantRow.pendingDelete = false
                            }
                            Button {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Revoke"
                                LuneOSButton.mainColor: "#be0003"
                                LuneOSButton.textColor: "white"
                                onClicked: {
                                    pageRoot.removeGrant(grantRow.grant._id);
                                    grantRow.pendingDelete = false;
                                }
                            }
                        }

                        HorizontalSeparator {
                            width: parent.width
                        }
                    }
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    visible: pageRoot.locationGrants.length > 0
                    text: "Revoke All"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: clearDataDialog.open()
                }
            }
        }

        /*
         * Only worth offering where there is a camera to stamp, and only while
         * applications are allowed the location in the first place - the same
         * two conditions the original hid this row on.
         */
        GroupBox {
            width: parent.width
            visible: pageRoot.cameraAvailable && pageRoot.autoLocate

            LabelAndSwitch {
                id: geotagSwitch
                label: "Geotag Photos"

                checked: pageRoot.geotagPhotos
                Connections {
                    target: pageRoot
                    function onGeotagPhotosChanged() {
                        geotagSwitch.checked = pageRoot.geotagPhotos;
                    }
                }
                onToggled: pageRoot.setGeotagPhotos(checked)
            }
        }

        ExplanationText {
            text: pageRoot.cameraAvailable && pageRoot.autoLocate
                  ? "Stores the GPS coordinates of your location when you use the camera."
                  : ""
        }

        /*
         * The original's "Locate Me Using..." application menu - and, unlike
         * the three groups above, not a guess: getAllLocationHandlers and
         * setState are real, confirmed by calling them against sargo and
         * mindphone.
         */
        ServiceUnavailableNotice {
            visible: !pageRoot.handlersAvailable

            serviceName: pageRoot.gpsService
            description: "Which location sources the device may use cannot be " +
                         "changed until this answers."

            onRetry: pageRoot.retrieveLocationHandlers()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.handlersAvailable

            title: "Locate Me Using"
            Column {
                width: parent.width

                LabelAndSwitch {
                    id: gpsSwitch
                    label: "GPS"
                    enabled: pageRoot.gpsHandlerPresent

                    checked: pageRoot.gpsHandlerEnabled
                    Connections {
                        target: pageRoot
                        function onGpsHandlerEnabledChanged() {
                            gpsSwitch.checked = pageRoot.gpsHandlerEnabled;
                        }
                    }
                    onToggled: pageRoot.setLocationHandlerEnabled("gps", checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: networkSwitch
                    label: "Network Location"
                    enabled: pageRoot.networkHandlerPresent

                    checked: pageRoot.networkHandlerEnabled
                    Connections {
                        target: pageRoot
                        function onNetworkHandlerEnabledChanged() {
                            networkSwitch.checked = pageRoot.networkHandlerEnabled;
                        }
                    }
                    onToggled: pageRoot.setLocationHandlerEnabled("network", checked)
                }
            }
        }

        ExplanationText {
            text: "GPS is accurate outdoors and costs battery. Network Location " +
                  "works indoors and is quicker, but only as precise as the " +
                  "nearby cells and access points allow."
        }
    }

    /*
     * Forgetting what websites/applications were told is not reversible, so
     * it is asked about first - the original opened a dialog here too.
     * Reused for both "Clear My Location Data" (web setting group) and
     * "Revoke All" (Granted Access) - either way, every stored grant goes.
     */
    /*
     * A Popup, not a Dialog: QtQuick.Controls.LuneOS has no styled Dialog at
     * all (see LanguagePickerPage.qml's applyDialog for the same gap), so a
     * plain Dialog falls all the way back to the unstyled Qt default -
     * square corners, left-aligned buttons. Popup does have the rounded
     * dialog-bg.png background every other popup in this app already uses.
     */
    Popup {
        id: clearDataDialog

        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape

        width: Math.min(parent.width - Units.gu(4), Units.gu(40))
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2

        ColumnLayout {
            width: parent.width
            spacing: Units.gu(1.5)

            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Clear My Location Data"
                font.pixelSize: FontUtils.sizeToPixels("18pt")
                font.weight: Font.Bold
            }

            Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                text: "Every website and application that has been given your " +
                      "location will be asked about it again the next time they want it."
                font.pixelSize: FontUtils.sizeToPixels("medium")
            }

            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: Units.gu(1)

                Button {
                    text: "Cancel"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: clearDataDialog.close()
                }
                Button {
                    text: "Clear"
                    LuneOSButton.mainColor: LuneOSButton.negativeColor
                    onClicked: {
                        pageRoot.clearAllGrants();
                        clearDataDialog.close();
                    }
                }
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        // Subscribed, same as TextAssistPage's keyboard settings: another
        // app (or a future permission prompt) changing one of these should
        // move the switch here without a re-open.
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"subscribe": true,
                                       "keys": ["autoLocate", "webSetting", "geotagPhotos"]}),
                       _handleGetPrefs, _handleGetError);
    }

    function _handleGetPrefs(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        if (response.hasOwnProperty("autoLocate"))
            pageRoot.autoLocate = response.autoLocate;
        if (response.hasOwnProperty("webSetting"))
            pageRoot.webSetting = response.webSetting;
        if (response.hasOwnProperty("geotagPhotos"))
            pageRoot.geotagPhotos = response.geotagPhotos;
    }

    function setAutoLocate(on) {
        pageRoot.autoLocate = on;
        luna.call("luna://com.webos.service.systemservice/setPreferences",
                  JSON.stringify({"autoLocate": on}), _handleSetSuccess, _handleSetError);
    }

    function setWebSetting(on) {
        pageRoot.webSetting = on;
        luna.call("luna://com.webos.service.systemservice/setPreferences",
                  JSON.stringify({"webSetting": on}), _handleSetSuccess, _handleSetError);
    }

    function setGeotagPhotos(on) {
        pageRoot.geotagPhotos = on;
        luna.call("luna://com.webos.service.systemservice/setPreferences",
                  JSON.stringify({"geotagPhotos": on}), _handleSetSuccess, _handleSetError);
    }

    /*
     * Granted Access - org.webosports.app.settings.locationgrants:1, own
     * kind and own namespace, the same pattern TextAssistPage's user
     * dictionary already uses for db8 data this app owns.
     */
    function retrieveLocationGrants() {
        // "sync": true so this travels with a db8 backup/restore, the same
        // flag TextAssistPage's dictionary kinds set and for the same
        // reason - nothing else has to know this exists.
        luna.call("luna://com.palm.db/putKind",
                  JSON.stringify({"id": pageRoot.grantsKind, "owner": appId,
                                  "indexes": [{"name": "appId", "props": [{"name": "appId"}]},
                                              {"name": "url", "props": [{"name": "url"}]}],
                                  "sync": true}),
                  _loadLocationGrants,
                  // Already registered is the usual answer here, and it is
                  // not a problem: read the list either way.
                  function(message) { _loadLocationGrants(null); });
    }

    function _loadLocationGrants(message) {
        luna.call("luna://com.palm.db/find",
                  JSON.stringify({"query": {"from": pageRoot.grantsKind, "orderBy": "grantedAt"}}),
                  _handleLocationGrants, _handleGetError);
    }

    function _handleLocationGrants(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        pageRoot.locationGrants = response.results !== undefined ? response.results : [];
    }

    function removeGrant(id) {
        luna.call("luna://com.palm.db/del", JSON.stringify({"ids": [id]}),
                  _loadLocationGrants, _handleSetError);
    }

    function clearAllGrants() {
        luna.call("luna://com.palm.db/del",
                  JSON.stringify({"query": {"from": pageRoot.grantsKind}}),
                  _loadLocationGrants, _handleSetError);
    }

    function _handleGetError(message) {
        console.warn("Location preferences did not answer: " + message);
    }

    /*
     * GPS Status
     */
    function startGpsTracking() {
        pageRoot.gpsTracking = true;
        pageRoot.gpsFixReceived = false;

        _trackingCall = luna.subscribe("luna://" + gpsService + "/getLocationUpdates",
                                       JSON.stringify({"subscribe": true}),
                                       _handleLocationFix, _handleLocationUnreachable);
    }

    function stopGpsTracking() {
        pageRoot.gpsTracking = false;
        if (_trackingCall) {
            _trackingCall.cancel();
            _trackingCall = null;
        }
    }

    function _handleLocationFix(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        pageRoot.gpsReachable = true;

        // The subscription ack carries no fix of its own - just
        // "returnValue": true - so wait for a message that actually has one.
        if (!response.hasOwnProperty("latitude"))
            return;

        // errorCode is nonzero on a failure that still answered "true" (a
        // known quirk of this service, kept in mind rather than trusted).
        if (response.errorCode)
            return;

        pageRoot.gpsLatitude = response.latitude;
        pageRoot.gpsLongitude = response.longitude;
        pageRoot.gpsAccuracy = response.horizAccuracy !== undefined ? response.horizAccuracy : 0;
        pageRoot.gpsFixTimestamp = response.timestamp !== undefined ? response.timestamp
                                                                    : Date.now() / 1000;
        pageRoot.gpsFixReceived = true;
    }

    function _handleLocationUnreachable(message) {
        console.warn("location-service did not answer: " + message);
        pageRoot.gpsReachable = false;
        pageRoot.gpsTracking = false;
        pageRoot.gpsFixReceived = false;
    }

    /*
     * Locate Me Using
     */
    function retrieveLocationHandlers() {
        // Subscribed: another app changing this (or the same setState call
        // this page just made) should move the switches without a re-open.
        luna.subscribe("luna://" + gpsService + "/getAllLocationHandlers",
                       JSON.stringify({"subscribe": true}),
                       _handleLocationHandlers, _handleLocationHandlersUnavailable);
    }

    function _handleLocationHandlers(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue || !response.handlers)
            return;

        // Absent from the list entirely (rather than present and disabled)
        // is what a device with no GPS chip looks like; the switch is
        // disabled rather than hidden so the row still explains itself.
        pageRoot.gpsHandlerPresent = false;
        pageRoot.networkHandlerPresent = false;

        for (var i = 0; i < response.handlers.length; i++) {
            var handler = response.handlers[i];
            if (handler.name === "gps") {
                pageRoot.gpsHandlerPresent = true;
                pageRoot.gpsHandlerEnabled = handler.state === true;
            } else if (handler.name === "network") {
                pageRoot.networkHandlerPresent = true;
                pageRoot.networkHandlerEnabled = handler.state === true;
            }
        }

        pageRoot.handlersAvailable = true;
    }

    function _handleLocationHandlersUnavailable(message) {
        console.warn("Location handlers did not answer: " + message);
        pageRoot.handlersAvailable = false;
    }

    function setLocationHandlerEnabled(handlerName, on) {
        if (handlerName === "gps")
            pageRoot.gpsHandlerEnabled = on;
        else
            pageRoot.networkHandlerEnabled = on;

        // "Handler" capitalised: setState rejects a lowercase "handler" as
        // a schema failure (errorCode 10, "Invalid input") rather than
        // simply ignoring it - found by calling this against real hardware.
        luna.call("luna://" + gpsService + "/setState",
                  JSON.stringify({"Handler": handlerName, "state": on}),
                  _handleSetSuccess, _handleSetError);
    }
}
