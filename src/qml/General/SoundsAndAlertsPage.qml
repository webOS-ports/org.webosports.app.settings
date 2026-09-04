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
import QtMultimedia 6.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * Sounds & Ringtones, after the webOS 3.0.5 app of the same name
 * (com.palm.app.soundsandalerts).
 *
 * Same rows in the same order as the original: a master Sounds switch that
 * hides everything below it, volume, system sounds, keyboard clicks, the
 * ringtone and its volume, and vibrate. The Beats Audio row is gone - it drove
 * an HP-specific audio path that no LuneOS device has.
 *
 * The alert and notification tones are an addition: the shell plays both of
 * them off the alerttone and notificationtone preferences, and until now
 * nothing on the device could change either.
 *
 * Where the settings live:
 *  - muteSound, systemSounds, ringtone and the keyboard preferences are
 *    com.webos.service.systemservice preferences, exactly as they were. The shell reads
 *    muteSound and ringtone from there, so the two agree.
 *  - the master volume goes to audiod's own com.webos.service.audio/master,
 *    which is the call that actually moves the volume.
 *  - the ringtone volume goes to com.palm.audio/ringtone, where audiod's legacy
 *    shim keeps it. Today that shim only remembers the number - it has no
 *    ringtone stream to apply it to - but it is the same number the shell's
 *    device menu shows, so the two stay in step, and the preview below plays at
 *    that volume so the slider still means something.
 */
BasePage {
    id: pageRoot

    /*
     * These properties summarize what settings are relative to this page
     */
    property bool soundsOn: true
    property bool systemSounds: true
    property bool keyboardClicks: true
    property bool vibrateWhenSoundsOn: true
    property bool vibrateWhenSoundsOff: true
    property int systemVolume: 50
    property int ringtoneVolume: 50
    property string ringtoneName: ""
    property string ringtonePath: ""
    property string alertToneName: ""
    property string alertTonePath: ""
    property string notificationToneName: ""
    property string notificationTonePath: ""

    // audiod wants the sound output it reported back when setting the volume:
    // its schema is REQUIRED_2(soundOutput, volume) and an empty payload is
    // rejected outright.
    property string soundOutput: "pcm_output"

    // Keyboard clicks moved: webOS 3.0.5 kept them as TapSounds inside the
    // x_palm_virtualkeyboard_prefs JSON string, LuneOS ships keyPressFeedback
    // inside the "keyboard" preference (see /etc/palm/defaultPreferences.txt).
    // Only that one field is ours, so keep the rest of the object intact.
    property var keyboardPrefs: ({})

    // Preferences arrive asynchronously; don't write anything back before the
    // first read has landed, or the defaults above would overwrite the device.
    property bool prefsLoaded: false

    pageActionHeaderComponent: Component {
        Switch {
            id: soundsSwitch
            LuneOSSwitch.labelOn: "On"
            LuneOSSwitch.labelOff: "Off"

            checked: pageRoot.soundsOn
            Connections {
                target: pageRoot
                function onSoundsOnChanged() {
                    soundsSwitch.checked = pageRoot.soundsOn;
                }
            }
            onToggled: pageRoot.setSoundsOn(checked)
        }
    }

    Component.onCompleted: {
        retrieveProperties();
    }

    Flickable {
        id: flickableItem
        anchors.fill: parent
        anchors.margins: Units.gu(1)
        contentWidth: width
        contentHeight: contentItem.childrenRect.height
        flickableDirection: Flickable.AutoFlickIfNeeded
        clip: true

        Column {
            width: flickableItem.width
            spacing: Units.gu(2)

            /*
             * Everything sound-related disappears while the master switch is
             * off, the way the original collapsed its "Sounds" group.
             */
            GroupBox {
                width: parent.width
                visible: pageRoot.soundsOn

                title: "Sounds"
                Column {
                    width: parent.width

                    LabelAndSlider {
                        id: systemVolumeSlider
                        width: parent.width
                        label: "Volume"

                        // Don't fight the finger: only follow the service while
                        // the user isn't dragging.
                        value: pageRoot.systemVolume
                        Connections {
                            target: pageRoot
                            function onSystemVolumeChanged() {
                                if (!systemVolumeSlider.pressed)
                                    systemVolumeSlider.value = pageRoot.systemVolume;
                            }
                        }

                        onMoved: (newVolume) => pageRoot.applySystemVolume(newVolume)
                        onReleased: (newVolume) => {
                            pageRoot.applySystemVolume(newVolume);
                            pageRoot.playVolumeFeedback();
                        }
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    Switch {
                        id: systemSoundsSwitch
                        width: parent.width
                        text: "System Sounds"
                        font.pixelSize: FontUtils.sizeToPixels("16pt")
                        font.weight: Font.Normal
                        LayoutMirroring.enabled: true // by default the switch is on the left in Qt, not very webOS-ish

                        LuneOSSwitch.labelOn: "On"
                        LuneOSSwitch.labelOff: "Off"

                        checked: pageRoot.systemSounds
                        Connections {
                            target: pageRoot
                            function onSystemSoundsChanged() {
                                systemSoundsSwitch.checked = pageRoot.systemSounds;
                            }
                        }
                        onToggled: pageRoot.setSystemSounds(checked)
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    Switch {
                        id: keyboardClicksSwitch
                        width: parent.width
                        text: "Keyboard Clicks"
                        font.pixelSize: FontUtils.sizeToPixels("16pt")
                        font.weight: Font.Normal
                        LayoutMirroring.enabled: true

                        LuneOSSwitch.labelOn: "On"
                        LuneOSSwitch.labelOff: "Off"

                        checked: pageRoot.keyboardClicks
                        Connections {
                            target: pageRoot
                            function onKeyboardClicksChanged() {
                                keyboardClicksSwitch.checked = pageRoot.keyboardClicks;
                            }
                        }
                        onToggled: pageRoot.setKeyboardClicks(checked)
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndPicker {
                        width: parent.width
                        label: "Ringtone"
                        value: pageRoot.displayName(pageRoot.ringtoneName)
                        placeholder: "Pick a ringtone"

                        onClicked: pageRoot.openTonePicker("ringtone", "Ringtone",
                                                           pageRoot.ringtonePath)
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndSlider {
                        id: ringtoneVolumeSlider
                        width: parent.width
                        label: "Ringtone Volume"

                        value: pageRoot.ringtoneVolume
                        Connections {
                            target: pageRoot
                            function onRingtoneVolumeChanged() {
                                if (!ringtoneVolumeSlider.pressed)
                                    ringtoneVolumeSlider.value = pageRoot.ringtoneVolume;
                            }
                        }

                        onMoved: (newVolume) => pageRoot.applyRingtoneVolume(newVolume)
                        // The original played the ringtone back for a few
                        // seconds once the slider was let go, so you could hear
                        // what you had picked.
                        onReleased: (newVolume) => {
                            pageRoot.applyRingtoneVolume(newVolume);
                            pageRoot.previewRingtone();
                        }
                    }
                }
            }

            /*
             * Not part of the 3.0.5 app, but the shell rings the alert and the
             * notification tone off these two preferences and nothing else on
             * the device sets them.
             */
            GroupBox {
                width: parent.width
                visible: pageRoot.soundsOn

                title: "Alerts"
                Column {
                    width: parent.width

                    LabelAndPicker {
                        width: parent.width
                        label: "Alert Tone"
                        value: pageRoot.displayName(pageRoot.alertToneName)
                        placeholder: "Pick an alert tone"

                        onClicked: pageRoot.openTonePicker("alerttone", "Alert Tone",
                                                           pageRoot.alertTonePath)
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndPicker {
                        width: parent.width
                        label: "Notification Tone"
                        value: pageRoot.displayName(pageRoot.notificationToneName)
                        placeholder: "Pick a notification tone"

                        onClicked: pageRoot.openTonePicker("notificationtone", "Notification Tone",
                                                           pageRoot.notificationTonePath)
                    }
                }
            }

            /*
             * Stays put when the master switch goes off: what the device does
             * with the sound off is exactly what this group is about.
             */
            GroupBox {
                width: parent.width

                title: "Vibrate"
                Column {
                    width: parent.width

                    LabelAndSelector {
                        id: vibrateWhenOnSelector
                        width: parent.width
                        label: "Sounds on"
                        model: ["Sound & Vibrate", "Sound"]

                        currentIndex: pageRoot.vibrateWhenSoundsOn ? 0 : 1
                        Connections {
                            target: pageRoot
                            function onVibrateWhenSoundsOnChanged() {
                                vibrateWhenOnSelector.currentIndex = pageRoot.vibrateWhenSoundsOn ? 0 : 1;
                            }
                        }
                        onActivated: (index) => pageRoot.setVibrateWhenSoundsOn(index === 0)
                    }
                    HorizontalSeparator {
                        width: parent.width
                    }
                    LabelAndSelector {
                        id: vibrateWhenOffSelector
                        width: parent.width
                        label: "Sounds off"
                        model: ["Vibrate", "Mute"]

                        currentIndex: pageRoot.vibrateWhenSoundsOff ? 0 : 1
                        Connections {
                            target: pageRoot
                            function onVibrateWhenSoundsOffChanged() {
                                vibrateWhenOffSelector.currentIndex = pageRoot.vibrateWhenSoundsOff ? 0 : 1;
                            }
                        }
                        onActivated: (index) => pageRoot.setVibrateWhenSoundsOff(index === 0)
                    }
                }
            }
        }
    }

    TonePickerPopup {
        id: tonePickerPopup

        onToneSelected: (target, name, path) => pageRoot.setTone(target, name, path)
        onClosed: pageRoot.stopPreview()
    }

    function openTonePicker(target, title, currentPath) {
        tonePickerPopup.target = target;
        tonePickerPopup.title = title;
        tonePickerPopup.currentPath = currentPath;
        tonePickerPopup.open();
    }

    /*
     * Ringtone preview. The shell rings with a plain MediaPlayer too, so this
     * is the same path the ringtone will take when a call comes in.
     */
    property real previewVolume: 1.0

    MediaPlayer {
        id: ringtonePreview
        audioOutput: AudioOutput {
            volume: pageRoot.previewVolume
        }
    }
    Timer {
        id: previewTimer
        interval: 3000 // the legacy app cut its preview off after three seconds
        onTriggered: pageRoot.stopPreview()
    }

    // "ringtone.mp3" is what the preference holds, "ringtone" is what the row
    // should read. Nothing set yet stays empty, so the row shows its
    // placeholder instead.
    function displayName(fileName) {
        if (!fileName)
            return "";

        var dot = fileName.lastIndexOf(".");
        return dot > 0 ? fileName.substring(0, dot) : fileName;
    }

    function previewRingtone() {
        previewTone(pageRoot.ringtonePath, pageRoot.ringtoneVolume / 100);
    }

    function previewTone(path, volume) {
        if (path === "")
            return;

        stopPreview();
        pageRoot.previewVolume = volume;
        ringtonePreview.source = path;
        ringtonePreview.play();
        previewTimer.restart();
    }
    function stopPreview() {
        previewTimer.stop();
        ringtonePreview.stop();
    }

    /*
     * Bindings with LuneOS settings
     */
    // Initialization and subscriptions
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["muteSound", "systemSounds", "ringtone",
                                                "alerttone", "notificationtone", "keyboard",
                                                "VibrateWhenRingerOn", "VibrateWhenRingerOff"],
                                       "subscribe": true}),
                       _handleGetPreferences, _handleGetError);

        // Subscribed rather than polled: the volume keys and the shell's device
        // menu move this behind our back.
        luna.subscribe("luna://com.webos.service.audio/master/getVolume",
                       JSON.stringify({"subscribe": true}),
                       _handleGetMasterVolume, _handleGetError);

        luna.call("luna://com.palm.audio/ringtone/getVolume", "{}",
                  _handleGetRingtoneVolume, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("muteSound"))
            pageRoot.soundsOn = !response.muteSound;
        if (response.hasOwnProperty("systemSounds"))
            pageRoot.systemSounds = response.systemSounds;
        if (response.hasOwnProperty("ringtone") && response.ringtone) {
            pageRoot.ringtoneName = response.ringtone.name || "";
            pageRoot.ringtonePath = response.ringtone.fullPath || "";
        }
        if (response.hasOwnProperty("alerttone") && response.alerttone) {
            pageRoot.alertToneName = response.alerttone.name || "";
            pageRoot.alertTonePath = response.alerttone.fullPath || "";
        }
        if (response.hasOwnProperty("notificationtone") && response.notificationtone) {
            pageRoot.notificationToneName = response.notificationtone.name || "";
            pageRoot.notificationTonePath = response.notificationtone.fullPath || "";
        }
        if (response.hasOwnProperty("keyboard")) {
            var keyboardValue = response.keyboard;
            // Written as an object, but a JSON string is what the old apps left
            // behind, so take either.
            if (typeof keyboardValue === "string") {
                try {
                    keyboardValue = JSON.parse(keyboardValue);
                } catch (e) {
                    console.warn("Cannot parse the keyboard preferences: " + e);
                    keyboardValue = {};
                }
            }
            pageRoot.keyboardPrefs = keyboardValue || {};
            if (pageRoot.keyboardPrefs.hasOwnProperty("keyPressFeedback"))
                pageRoot.keyboardClicks = pageRoot.keyboardPrefs.keyPressFeedback;
        }
        if (response.hasOwnProperty("VibrateWhenRingerOn"))
            pageRoot.vibrateWhenSoundsOn = response.VibrateWhenRingerOn;
        if (response.hasOwnProperty("VibrateWhenRingerOff"))
            pageRoot.vibrateWhenSoundsOff = response.VibrateWhenRingerOff;

        pageRoot.prefsLoaded = true;
    }

    function _handleGetMasterVolume(message) {
        if (!message || !message.payload)
            return;

        var payload = JSON.parse(message.payload);
        // audiod nests the fields under volumeStatus; accept a flat payload too.
        var status = payload.hasOwnProperty("volumeStatus") ? payload.volumeStatus : payload;

        if (status.hasOwnProperty("soundOutput") && status.soundOutput.length > 0)
            pageRoot.soundOutput = status.soundOutput;
        if (status.hasOwnProperty("volume"))
            pageRoot.systemVolume = status.volume;
    }

    function _handleGetRingtoneVolume(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (response.hasOwnProperty("volume"))
            pageRoot.ringtoneVolume = response.volume;
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

    function setSoundsOn(on) {
        pageRoot.soundsOn = on;
        _setPreference("muteSound", !on);
        // Silence the ringer as well: muting the master volume instead would
        // take music and videos down with it, which the ringer switch never did.
        luna.call("luna://com.palm.audio/ringtone/setMuted", JSON.stringify({"muted": !on}),
                  _handleSetSuccess, _handleSetError);
    }

    function setSystemSounds(on) {
        pageRoot.systemSounds = on;
        _setPreference("systemSounds", on);
    }

    function setKeyboardClicks(on) {
        pageRoot.keyboardClicks = on;
        pageRoot.keyboardPrefs.keyPressFeedback = on;
        _setPreference("keyboard", pageRoot.keyboardPrefs);
    }

    function setVibrateWhenSoundsOn(vibrates) {
        pageRoot.vibrateWhenSoundsOn = vibrates;
        _setPreference("VibrateWhenRingerOn", vibrates);
        _buzz(vibrates);
    }

    function setVibrateWhenSoundsOff(vibrates) {
        pageRoot.vibrateWhenSoundsOff = vibrates;
        _setPreference("VibrateWhenRingerOff", vibrates);
        _buzz(vibrates);
    }

    // A short buzz so you can tell it took.
    function _buzz(vibrates) {
        if (!vibrates)
            return;

        luna.call("luna://com.palm.vibrate/vibrate", JSON.stringify({"period": 200, "duration": 500}),
                  _handleSetSuccess, _handleSetError);
    }

    function setTone(target, name, path) {
        if (target === "alerttone") {
            pageRoot.alertToneName = name;
            pageRoot.alertTonePath = path;
        } else if (target === "notificationtone") {
            pageRoot.notificationToneName = name;
            pageRoot.notificationTonePath = path;
        } else {
            pageRoot.ringtoneName = name;
            pageRoot.ringtonePath = path;
        }

        _setPreference(target, {"name": name, "fullPath": path});

        // Alerts and notifications have no volume of their own to preview at -
        // audiod hands out one volume for everything - so they play at the
        // system volume, the ringtone at its own.
        previewTone(path, target === "ringtone" ? pageRoot.ringtoneVolume / 100
                                                : pageRoot.systemVolume / 100);
    }

    function applySystemVolume(volume) {
        pageRoot.systemVolume = volume;
        luna.call("luna://com.webos.service.audio/master/setVolume",
                  JSON.stringify({"soundOutput": pageRoot.soundOutput, "volume": volume}),
                  _handleSetSuccess, _handleSetError);
        // Keep the legacy number audiod hands out to com.palm.audio callers -
        // the shell's device menu among them - in step with the real volume.
        luna.call("luna://com.palm.audio/system/setVolume", JSON.stringify({"volume": volume}),
                  _handleSetSuccess, _handleSetError);
    }

    function playVolumeFeedback() {
        if (!pageRoot.systemSounds)
            return;

        luna.call("luna://com.palm.audio/systemsounds/playFeedback",
                  JSON.stringify({"name": "AdjustVolume"}),
                  _handleSetSuccess, _handleSetError);
    }

    function applyRingtoneVolume(volume) {
        pageRoot.ringtoneVolume = volume;
        luna.call("luna://com.palm.audio/ringtone/setVolume", JSON.stringify({"volume": volume}),
                  _handleSetSuccess, _handleSetError);
    }
}
