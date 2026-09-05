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

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * Screen & Lock, after the webOS 3.0.5 app of the same name
 * (com.palm.app.screenlock).
 *
 * Same rows in the same order as the original: Auto Dim, Brightness and Turn
 * off After; the wallpaper; Advanced Gestures; Secure Unlock with its Lock
 * After row; and the two notification switches.
 *
 * Most of it lands on services LuneOS has:
 *  - brightness and the display timeout are com.palm.display control
 *    properties, the same ones the shell's device menu moves.
 *  - enableALS, sysUiEnableNextPrevGestures, showAlertsWhenLocked,
 *    BlinkNotifications and lockTimeout are systemservice preferences that
 *    luna-sysmgr-common has always read.
 *  - the wallpaper goes through systemservice's wallpaper/importWallpaper,
 *    which LuneOS keeps patched back in, and then into the wallpaper
 *    preference the card shell draws from.
 *
 * Secure Unlock talks to com.palm.systemmanager, which - despite what an
 * earlier version of this comment said - never actually left: luna-sysmgr
 * still builds and still ships in the default image (packagegroup-luneos-
 * extended, systemd WantedBy=multi-user.target); only its own window/
 * compositor role was superseded by luna-next-cardshell, not the LS2 side of
 * it. The ServiceUnavailableNotice below is kept as a fallback for the day it
 * genuinely does not answer, but the ordinary case is that it never shows.
 *
 * Two things the legacy app never had:
 *  - Pattern, alongside PIN and Password, the way Android offers all three.
 *    It is not a new kind of secret to the service: setDevicePasscode and
 *    matchDevicePasscode only ever compared an opaque passCode string, so a
 *    pattern - the nine dots joined by index, "0-1-2-5-8" - is just another
 *    string to them. That took a small fix on the service side, though:
 *    setPasscode() only used to recognise lockMode "pin" or "password" -
 *    anything else, "pattern" included, was silently refused. Fixed in
 *    luna-sysmgr (branch herrie/backuprestore, "Security: accept Pattern and
 *    Face as device lock modes") alongside cardshell's own half of this -
 *    LockScreen.qml needing to know how to draw a pattern grid back at the
 *    person unlocking, which is the one piece that lives outside both the
 *    settings app and luna-sysmgr. Until that commit reaches a built image,
 *    choosing Pattern here will fail against real hardware even though the
 *    row is live.
 *  - Fingerprint, now that a sensor and webos-fingerprint-adapter are on the
 *    device. The lock screen already tries an identify whenever a fingerprint
 *    is enrolled, with no preference gating it; this page adds the preference
 *    (enableFingerprintUnlock) so it can be turned off without deleting the
 *    enrolled prints, and a summary row into the Fingerprint page itself.
 *    Android requires a knowledge factor - PIN, pattern or password - behind
 *    a biometric, so this group stays hidden while Secure Unlock is Off.
 */
BasePage {
    id: pageRoot

    // Display
    property bool autoDim: true
    property int brightness: 100
    property int displayTimeout: 60

    // Preferences
    property bool gesturesEnabled: true
    property bool showAlertsWhenLocked: true
    property bool blinkNotifications: false
    property int lockTimeout: 0
    property var wallpaper: ({})

    // Secure unlock
    property bool lockServiceAvailable: false
    property string lockMode: "none"
    // What the user asked for, held while the current passcode is verified
    property string pendingLockMode: ""

    property bool prefsLoaded: false

    // The choices the original offered, in seconds.
    readonly property var displayTimeouts: [60, 120, 300, 600]
    readonly property var displayTimeoutLabels: ["1 minute", "2 minutes", "5 minutes", "10 minutes"]

    readonly property var lockTimeouts: [0, 30, 60, 120, 180, 300, 600, 1800]
    readonly property var lockTimeoutLabels: ["Screen turns off", "30 seconds", "1 minute",
                                              "2 minutes", "3 minutes", "5 minutes",
                                              "10 minutes", "30 minutes"]

    readonly property var lockModes: ["none", "pattern", "pin", "password"]
    readonly property var lockModeLabels: ["Off", "Pattern", "Simple PIN", "Password"]

    // Fingerprint
    property bool fingerprintSensorAvailable: false
    property var fingerprintTemplates: []
    property bool fingerprintUnlockEnabled: true

    // Face. Same shape as fingerprint, with one difference: luneos-faced holds
    // a single template rather than a list, so there is a bool where
    // fingerprintTemplates has a count.
    property bool faceServiceAvailable: false
    property bool faceEnrolled: false
    property bool faceUnlockEnabled: true

    Component.onCompleted: retrieveProperties();

    function _indexOf(values, value, fallback) {
        var at = values.indexOf(value);
        return at >= 0 ? at : fallback;
    }

    SettingsPageContent {
        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: autoDimSwitch
                    label: "Auto Dim"

                    checked: pageRoot.autoDim
                    Connections {
                        target: pageRoot
                        function onAutoDimChanged() {
                            autoDimSwitch.checked = pageRoot.autoDim;
                        }
                    }
                    onToggled: pageRoot.setAutoDim(checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSlider {
                    id: brightnessSlider
                    width: parent.width
                    label: "Brightness"
                    // Fully dark is not a brightness anyone wants to be stuck
                    // at, so the original started its slider at 10 as well.
                    from: 10

                    value: pageRoot.brightness
                    Connections {
                        target: pageRoot
                        function onBrightnessChanged() {
                            if (!brightnessSlider.pressed)
                                brightnessSlider.value = pageRoot.brightness;
                        }
                    }

                    onMoved: (newBrightness) => pageRoot.applyBrightness(newBrightness)
                    onReleased: (newBrightness) => pageRoot.applyBrightness(newBrightness)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSelector {
                    id: displayTimeoutSelector
                    width: parent.width
                    label: "Turn off After"
                    model: pageRoot.displayTimeoutLabels

                    currentIndex: pageRoot._indexOf(pageRoot.displayTimeouts,
                                                    pageRoot.displayTimeout, 0)
                    Connections {
                        target: pageRoot
                        function onDisplayTimeoutChanged() {
                            displayTimeoutSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.displayTimeouts,
                                                  pageRoot.displayTimeout, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.setDisplayTimeout(pageRoot.displayTimeouts[index])
                }
            }
        }

        GroupBox {
            width: parent.width
            title: "Wallpaper"

            LabelAndPicker {
                width: parent.width
                label: "Change Wallpaper"
                value: pageRoot.wallpaperName()
                placeholder: "Pick a picture"

                onClicked: {
                    wallpaperPicker.currentPath = pageRoot.wallpaper
                                                  ? (pageRoot.wallpaper.wallpaperFile || "") : "";
                    wallpaperPicker.open();
                }
            }
        }

        GroupBox {
            width: parent.width
            title: "Advanced Gestures"

            LabelAndSwitch {
                id: gesturesSwitch
                label: "Enable Gestures"

                checked: pageRoot.gesturesEnabled
                Connections {
                    target: pageRoot
                    function onGesturesEnabledChanged() {
                        gesturesSwitch.checked = pageRoot.gesturesEnabled;
                    }
                }
                onToggled: pageRoot.setGesturesEnabled(checked)
            }
        }

        ExplanationText {
            text: "Swipe up from the bottom of the screen to card an app. " +
                  "Swipe up again to see the Launcher."
        }

        // com.palm.systemmanager ships in the default image and answers this
        // in the ordinary case - see the file header - so this is a fallback
        // for the day it genuinely does not, not the expected state.
        ServiceUnavailableNotice {
            visible: !pageRoot.lockServiceAvailable

            serviceName: "com.palm.systemmanager"
            description: "The device cannot be given a PIN, a pattern or a " +
                         "password until this answers. The lock screen asks the " +
                         "same service, so it cannot check one either."

            onRetry: pageRoot.retrieveLockMode()
        }

        GroupBox {
            width: parent.width
            enabled: pageRoot.lockServiceAvailable

            title: "Secure Unlock"
            Column {
                width: parent.width

                LabelAndSelector {
                    id: lockModeSelector
                    width: parent.width
                    label: "Unlock with"
                    model: pageRoot.lockModeLabels

                    currentIndex: pageRoot._indexOf(pageRoot.lockModes, pageRoot.lockMode, 0)
                    Connections {
                        target: pageRoot
                        function onLockModeChanged() {
                            lockModeSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.lockModes, pageRoot.lockMode, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.requestLockMode(pageRoot.lockModes[index])
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.lockMode !== "none"
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    visible: pageRoot.lockMode !== "none"
                    text: {
                        if (pageRoot.lockMode === "pattern") return "Change Pattern";
                        if (pageRoot.lockMode === "pin") return "Change PIN";
                        return "Change Password";
                    }
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: pageRoot.requestLockMode(pageRoot.lockMode)
                }

                HorizontalSeparator {
                    width: parent.width
                    visible: pageRoot.lockMode !== "none"
                }

                LabelAndSelector {
                    id: lockTimeoutSelector
                    width: parent.width
                    visible: pageRoot.lockMode !== "none"
                    label: "Lock After"
                    model: pageRoot.lockTimeoutLabels

                    currentIndex: pageRoot._indexOf(pageRoot.lockTimeouts,
                                                    pageRoot.lockTimeout, 0)
                    Connections {
                        target: pageRoot
                        function onLockTimeoutChanged() {
                            lockTimeoutSelector.currentIndex =
                                pageRoot._indexOf(pageRoot.lockTimeouts,
                                                  pageRoot.lockTimeout, 0);
                        }
                    }
                    onActivated: (index) => pageRoot.setLockTimeout(pageRoot.lockTimeouts[index])
                }
            }
        }

        /*
         * Fingerprint unlock is a layer on top of Secure Unlock, not an
         * alternative to it - Android's own rule, and the lock screen already
         * follows it implicitly by only trying an identify while it is
         * showing the pad, which only happens once a lock mode is set. Hidden
         * entirely on hardware with no sensor, so it does not clutter a
         * device that will never have anything to show here.
         */
        GroupBox {
            width: parent.width
            enabled: pageRoot.lockServiceAvailable
            visible: pageRoot.fingerprintSensorAvailable

            title: "Fingerprint Unlock"
            Column {
                width: parent.width

                LabelAndSwitch {
                    id: fingerprintUnlockSwitch
                    label: "Unlock with Fingerprint"
                    enabled: pageRoot.lockMode !== "none" &&
                             pageRoot.fingerprintTemplates.length > 0

                    checked: pageRoot.fingerprintUnlockEnabled
                    Connections {
                        target: pageRoot
                        function onFingerprintUnlockEnabledChanged() {
                            fingerprintUnlockSwitch.checked = pageRoot.fingerprintUnlockEnabled;
                        }
                    }
                    onToggled: pageRoot.setFingerprintUnlockEnabled(checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    text: pageRoot.fingerprintTemplates.length === 1
                          ? "1 fingerprint enrolled"
                          : pageRoot.fingerprintTemplates.length + " fingerprints enrolled"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: pageRoot.openFingerprintSettings()
                }
            }
        }

        ExplanationText {
            text: {
                if (!pageRoot.fingerprintSensorAvailable)
                    return "";
                if (pageRoot.lockMode === "none")
                    return "Set a pattern, PIN or password above before fingerprint " +
                           "unlock can be turned on.";
                if (pageRoot.fingerprintTemplates.length === 0)
                    return "No fingerprints are enrolled yet. Add one to use it here.";
                return "";
            }
        }

        /*
         * Face unlock. Mirrors the fingerprint group above, including the rule
         * that a biometric sits behind a knowledge factor, so it stays hidden
         * while Secure Unlock is Off. Hidden entirely where luneos-faced is not
         * running, which is any device without a usable front camera.
         *
         * The lock screen defaults this on - enrolling a face is itself the
         * opt-in - so this switch exists to turn it off again without throwing
         * the enrolled template away.
         */
        GroupBox {
            width: parent.width
            enabled: pageRoot.lockServiceAvailable
            visible: pageRoot.faceServiceAvailable

            title: "Face Unlock"
            Column {
                width: parent.width

                LabelAndSwitch {
                    id: faceUnlockSwitch
                    label: "Unlock with Face"
                    enabled: pageRoot.lockMode !== "none" && pageRoot.faceEnrolled

                    checked: pageRoot.faceUnlockEnabled
                    Connections {
                        target: pageRoot
                        function onFaceUnlockEnabledChanged() {
                            faceUnlockSwitch.checked = pageRoot.faceUnlockEnabled;
                        }
                    }
                    onToggled: pageRoot.setFaceUnlockEnabled(checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                ItemDelegate {
                    width: parent.width
                    height: Units.gu(6)
                    text: pageRoot.faceEnrolled ? "Face enrolled" : "No face enrolled"
                    font.pixelSize: FontUtils.sizeToPixels("16pt")

                    onClicked: pageRoot.openFaceUnlockSettings()
                }
            }
        }

        ExplanationText {
            text: {
                if (!pageRoot.faceServiceAvailable)
                    return "";
                if (pageRoot.lockMode === "none")
                    return "Set a pattern, PIN or password above before face " +
                           "unlock can be turned on.";
                if (!pageRoot.faceEnrolled)
                    return "No face is enrolled yet. Add one to use it here.";
                return "Face unlock is less secure than a PIN or password. " +
                       "A photo or a similar-looking person may be able to unlock your device.";
            }
        }

        GroupBox {
            width: parent.width
            title: "Notifications"

            Column {
                width: parent.width

                LabelAndSwitch {
                    id: showAlertsSwitch
                    label: "Show When Locked"

                    checked: pageRoot.showAlertsWhenLocked
                    Connections {
                        target: pageRoot
                        function onShowAlertsWhenLockedChanged() {
                            showAlertsSwitch.checked = pageRoot.showAlertsWhenLocked;
                        }
                    }
                    onToggled: pageRoot.setShowAlertsWhenLocked(checked)
                }

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: blinkSwitch
                    label: "Blink Notifications"

                    checked: pageRoot.blinkNotifications
                    Connections {
                        target: pageRoot
                        function onBlinkNotificationsChanged() {
                            blinkSwitch.checked = pageRoot.blinkNotifications;
                        }
                    }
                    onToggled: pageRoot.setBlinkNotifications(checked)
                }
            }
        }

        ExplanationText {
            text: "The center button blinks when new notifications arrive."
        }
    }

    WallpaperPickerPopup {
        id: wallpaperPicker

        onWallpaperSelected: (path) => pageRoot.importWallpaper(path)
    }

    PasscodePopup {
        id: passcodePopup

        onVerifyRequested: (passcode) => pageRoot.verifyPasscode(passcode)
        onChosen: (passcode) => pageRoot.storePasscode(passcode)
        onCancelled: pageRoot.cancelLockModeChange()
    }

    /*
     * Secure unlock
     *
     * Turning a lock on is one step. Changing or removing one is two: the
     * current passcode first, then the new one - which is what the original
     * did, and what stops someone picking up an unlocked device and taking the
     * lock off.
     */
    function requestLockMode(newMode) {
        pageRoot.pendingLockMode = newMode;

        if (pageRoot.lockMode === "none") {
            _openSetPasscode(newMode, false);
            return;
        }

        passcodePopup.mode = "verify";
        passcodePopup.lockMode = pageRoot.lockMode;
        passcodePopup.open();
    }

    function _openSetPasscode(newMode, isChange) {
        if (newMode === "none") {
            // Nothing to type: the lock is simply removed.
            _applyPasscode("", "none");
            return;
        }

        passcodePopup.mode = "set";
        passcodePopup.lockMode = newMode;
        passcodePopup.isChange = isChange;
        passcodePopup.open();
    }

    function verifyPasscode(passcode) {
        luna.call("luna://com.palm.systemmanager/matchDevicePasscode",
                  JSON.stringify({"passCode": passcode}),
                  _handleVerifyResult, _handleVerifyError);
    }

    function _handleVerifyResult(message) {
        var response = JSON.parse(message.payload);

        if (!response.returnValue) {
            passcodePopup.reportFailure(pageRoot.lockMode === "pin"
                                        ? "That PIN is not correct."
                                        : "That password is not correct.");
            return;
        }

        passcodePopup.close();
        _openSetPasscode(pageRoot.pendingLockMode, true);
    }

    function _handleVerifyError(message) {
        console.warn("Cannot check the passcode: " + message);
        passcodePopup.reportFailure("The passcode could not be checked.");
        pageRoot.lockServiceAvailable = false;
    }

    function storePasscode(passcode) {
        _applyPasscode(passcode, pageRoot.pendingLockMode);
    }

    function _applyPasscode(passcode, mode) {
        luna.call("luna://com.palm.systemmanager/setDevicePasscode",
                  JSON.stringify({"passCode": passcode, "lockMode": mode}),
                  _handlePasscodeStored, _handleSetError);
    }

    function _handlePasscodeStored(message) {
        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            console.warn("Cannot set the passcode: " + message.payload);
            // The selector already moved to what was asked for; put it back to
            // what is really in force.
            cancelLockModeChange();
            return;
        }

        pageRoot.lockMode = pageRoot.pendingLockMode;
        pageRoot.pendingLockMode = "";
    }

    function cancelLockModeChange() {
        // The selector already moved to the choice that was made; put it back.
        pageRoot.pendingLockMode = "";
        lockModeSelector.currentIndex = pageRoot._indexOf(pageRoot.lockModes,
                                                          pageRoot.lockMode, 0);
    }

    /*
     * Wallpaper
     */
    function wallpaperName() {
        if (!wallpaper || !wallpaper.wallpaperName)
            return "";

        var name = wallpaper.wallpaperName;
        var dot = name.lastIndexOf(".");
        return dot > 0 ? name.substring(0, dot) : name;
    }

    function importWallpaper(path) {
        // systemservice crops and scales the picture for the screen and hands
        // back the wallpaper object to store; the shell draws whatever the
        // preference points at.
        luna.call("luna://com.webos.service.systemservice/wallpaper/importWallpaper",
                  JSON.stringify({"target": path}),
                  _handleWallpaperImported, _handleSetError);
    }

    function _handleWallpaperImported(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue || !response.wallpaper) {
            console.warn("Cannot import the wallpaper: " + message.payload);
            return;
        }

        pageRoot.wallpaper = response.wallpaper;
        _setPreference("wallpaper", response.wallpaper);
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["enableALS", "sysUiEnableNextPrevGestures",
                                                "showAlertsWhenLocked", "BlinkNotifications",
                                                "lockTimeout", "wallpaper",
                                                "enableFingerprintUnlock",
                                                "enableFaceUnlock"],
                                       "subscribe": true}),
                       _handleGetPreferences, _handleGetError);

        // com.palm.display has no subscription for these, so they are read
        // once; the shell's device menu is the only other thing that moves
        // them and it does not run at the same time as this page.
        luna.call("luna://com.palm.display/control/getProperty",
                  JSON.stringify({"properties": ["timeout", "maximumBrightness"]}),
                  _handleGetDisplayProperties, _handleGetError);

        retrieveLockMode();

        // Present on some devices, absent on others; failing quietly (rather
        // than through _handleGetError) is the sensor simply not being there.
        luna.subscribe("luna://com.webos.service.fingerprint/getStatus",
                       JSON.stringify({"subscribe": true}),
                       _handleFingerprintStatus, _handleFingerprintUnavailable);

        // Likewise: luneos-faced only exists on devices with a usable front
        // camera, so a failure here is the feature being absent, not an error.
        luna.subscribe("luna://com.webos.service.faceunlock/getStatus",
                       JSON.stringify({"subscribe": true}),
                       _handleFaceStatus, _handleFaceUnavailable);
    }

    function retrieveLockMode() {
        luna.call("luna://com.palm.systemmanager/getDeviceLockMode", "{}",
                  _handleGetLockMode, _handleLockServiceUnavailable);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("enableALS"))
            pageRoot.autoDim = response.enableALS;
        if (response.hasOwnProperty("sysUiEnableNextPrevGestures"))
            pageRoot.gesturesEnabled = response.sysUiEnableNextPrevGestures;
        if (response.hasOwnProperty("showAlertsWhenLocked"))
            pageRoot.showAlertsWhenLocked = response.showAlertsWhenLocked;
        if (response.hasOwnProperty("BlinkNotifications"))
            pageRoot.blinkNotifications = response.BlinkNotifications;
        if (response.hasOwnProperty("lockTimeout"))
            pageRoot.lockTimeout = response.lockTimeout;
        if (response.hasOwnProperty("wallpaper") && response.wallpaper)
            pageRoot.wallpaper = response.wallpaper;
        if (response.hasOwnProperty("enableFingerprintUnlock"))
            pageRoot.fingerprintUnlockEnabled = response.enableFingerprintUnlock;
        if (response.hasOwnProperty("enableFaceUnlock"))
            pageRoot.faceUnlockEnabled = response.enableFaceUnlock;

        pageRoot.prefsLoaded = true;
    }

    function _handleFingerprintStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            // The adapter dropped out from under an available sensor; leave
            // the group showing rather than flicker it away and back.
            return;
        }

        pageRoot.fingerprintSensorAvailable = response.available === true;
        pageRoot.fingerprintTemplates = response.fingerprints !== undefined
                                        ? response.fingerprints : [];
    }

    function _handleFaceStatus(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        pageRoot.faceServiceAvailable = response.available === true;
        pageRoot.faceEnrolled = response.enrolled === true;
    }

    function _handleFaceUnavailable(message) {
        // No front camera, or luneos-faced is not installed.
        pageRoot.faceServiceAvailable = false;
    }

    function _handleFingerprintUnavailable(message) {
        // No sensor on this device, or the adapter is not installed: quiet,
        // not a warning - most devices will hit this every time.
        pageRoot.fingerprintSensorAvailable = false;
    }

    function _handleGetDisplayProperties(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("timeout"))
            pageRoot.displayTimeout = response.timeout;
        if (response.hasOwnProperty("maximumBrightness"))
            pageRoot.brightness = response.maximumBrightness;
    }

    function _handleGetLockMode(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue) {
            pageRoot.lockServiceAvailable = false;
            return;
        }

        pageRoot.lockMode = response.lockMode ? response.lockMode : "none";
        pageRoot.lockServiceAvailable = true;
    }

    function _handleLockServiceUnavailable(message) {
        console.warn("Device lock service did not answer: " + message);
        pageRoot.lockServiceAvailable = false;
    }

    // Push changes to LuneOS
    function _setPreference(key, value) {
        if (!pageRoot.prefsLoaded) {
            console.log("Trying to set preferences before reading them first: ignoring.");
            return;
        }

        var params = {};
        params[key] = value;
        luna.call("luna://com.webos.service.systemservice/setPreferences", JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
    }

    function _setDisplayProperty(key, value) {
        var params = {};
        params[key] = value;
        luna.call("luna://com.palm.display/control/setProperty", JSON.stringify(params),
                  _handleSetSuccess, _handleSetError);
    }

    function setAutoDim(on) {
        pageRoot.autoDim = on;
        _setPreference("enableALS", on);
    }

    function applyBrightness(value) {
        pageRoot.brightness = value;
        _setDisplayProperty("maximumBrightness", Math.round(value));
    }

    function setDisplayTimeout(seconds) {
        pageRoot.displayTimeout = seconds;
        _setDisplayProperty("timeout", seconds);
    }

    function setGesturesEnabled(on) {
        pageRoot.gesturesEnabled = on;
        _setPreference("sysUiEnableNextPrevGestures", on);
    }

    function setShowAlertsWhenLocked(on) {
        pageRoot.showAlertsWhenLocked = on;
        _setPreference("showAlertsWhenLocked", on);
    }

    function setBlinkNotifications(on) {
        pageRoot.blinkNotifications = on;
        _setPreference("BlinkNotifications", on);
    }

    function setLockTimeout(seconds) {
        pageRoot.lockTimeout = seconds;
        _setPreference("lockTimeout", seconds);
    }

    function setFingerprintUnlockEnabled(on) {
        pageRoot.fingerprintUnlockEnabled = on;
        _setPreference("enableFingerprintUnlock", on);
    }

    function setFaceUnlockEnabled(on) {
        pageRoot.faceUnlockEnabled = on;
        _setPreference("enableFaceUnlock", on);
    }

    // Each settings category is its own launchable application on the
    // device; this is how one of them opens another, the way the legacy
    // Help menu items opened com.palm.app.help.
    function openFingerprintSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.fingerprint"}),
                  _handleSetSuccess, _handleSetError);
    }

    function openFaceUnlockSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.faceunlock"}),
                  _handleSetSuccess, _handleSetError);
    }
}
