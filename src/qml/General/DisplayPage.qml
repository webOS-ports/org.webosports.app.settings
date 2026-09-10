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
 * Display.
 *
 * webOS 3.0.5 had no display panel: brightness, Auto Dim and "Turn off After"
 * sat at the top of Screen & Lock, above the padlock settings, because the
 * screen turning itself off and the screen locking itself were one idea on a
 * Pre. Every other mobile Linux splits them - SFOS has display, UBports has
 * brightness plus a rotation lock entry, GNOME/Phosh has Display - and so does
 * this now: what dims and turns off the screen is here, what locks it stays on
 * Screen & Lock.
 *
 * The three moved rows keep the services they already used:
 *  - Brightness is com.palm.display's maximumBrightness control property, the
 *    same one the shell's device menu slider moves.
 *  - Turn off After is that service's timeout property, in seconds.
 *  - Auto Dim is the enableALS systemservice preference, which is what lets
 *    the ambient light sensor pull the backlight down. It is shown
 *    unconditionally, as the legacy app showed it: com.palm.ambientLightSensor
 *    will answer a status call whether or not there is a sensor behind it, and
 *    subscribing to find out has a side effect - the service counts
 *    subscribers and turns the sensor on for them - which is not something a
 *    settings panel should be doing just to decide whether to draw a row.
 *
 * Rotation Lock is new here, and is the rotationLock systemservice preference
 * that luna-next-cardshell already reads. Its value is an angle in degrees,
 * with 400 - the shell's "rotationInvalid" - standing for not locked. It is a
 * switch and not a list of orientations on purpose: the shell freezes the
 * screen at whatever it is showing when the preference changes
 * (OrientationHelper's onRotationLockChanged takes the live angle, not the
 * stored one), so offering "lock to Landscape" here would be offering
 * something nothing acts on. Any non-400 value means locked, and 0 is what
 * gets written.
 *
 * Text size is not here. Scaling the interface is an accessibility setting and
 * lives on that panel; this one links across rather than keeping a second
 * copy.
 */
BasePage {
    id: pageRoot

    // com.palm.display
    property int brightness: 100
    property int displayTimeout: 60

    // Preferences
    property bool autoDim: true
    property int rotationLockAngle: rotationUnlocked

    property bool prefsLoaded: false

    // The shell's "rotationInvalid": an angle that is not one, standing for
    // "follow the sensor".
    readonly property int rotationUnlocked: 400

    readonly property bool rotationLocked: rotationLockAngle !== rotationUnlocked

    // The choices the legacy Screen & Lock app offered, in seconds.
    readonly property var displayTimeouts: [60, 120, 300, 600]
    readonly property var displayTimeoutLabels: ["1 minute", "2 minutes", "5 minutes", "10 minutes"]

    Component.onCompleted: retrieveProperties();

    function _indexOf(values, value, fallback) {
        var at = values.indexOf(value);
        return at >= 0 ? at : fallback;
    }

    SettingsPageContent {
        GroupBox {
            width: parent.width

            title: "Backlight"

            Column {
                width: parent.width

                LabelAndSlider {
                    id: brightnessSlider
                    width: parent.width
                    label: "Brightness"
                    // Fully dark is not a brightness anyone wants to be stuck
                    // at, so the legacy app started its slider at 10 as well.
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
            }
        }

        ExplanationText {
            text: "With Auto Dim on, the ambient light sensor pulls the " +
                  "backlight down in the dark and lets it back up in daylight."
        }

        GroupBox {
            width: parent.width

            title: "Screen"

            Column {
                width: parent.width

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

                HorizontalSeparator {
                    width: parent.width
                }

                LabelAndSwitch {
                    id: rotationLockSwitch
                    label: "Rotation Lock"

                    checked: pageRoot.rotationLocked
                    Connections {
                        target: pageRoot
                        function onRotationLockAngleChanged() {
                            rotationLockSwitch.checked = pageRoot.rotationLocked;
                        }
                    }
                    onToggled: pageRoot.setRotationLocked(checked)
                }
            }
        }

        ExplanationText {
            text: "Rotation Lock keeps the screen at the orientation it is " +
                  "in rather than following the device. The same switch is in " +
                  "the menu at the top right of the screen."
        }

        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                Button {
                    text: "Accessibility settings"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openAccessibilitySettings()
                }
            }
        }

        ExplanationText {
            text: "Text and interface size are set there."
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["enableALS", "rotationLock"],
                                       "subscribe": true}),
                       _handleGetPreferences, _handleGetError);

        // com.palm.display has no subscription for these, so they are read
        // once; the shell's device menu is the only other thing that moves
        // them and it does not run at the same time as this page.
        luna.call("luna://com.palm.display/control/getProperty",
                  JSON.stringify({"properties": ["timeout", "maximumBrightness"]}),
                  _handleGetDisplayProperties, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        if (response.hasOwnProperty("enableALS"))
            pageRoot.autoDim = response.enableALS;
        if (response.hasOwnProperty("rotationLock"))
            pageRoot.rotationLockAngle = response.rotationLock;

        pageRoot.prefsLoaded = true;
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

    function applyBrightness(value) {
        pageRoot.brightness = value;
        _setDisplayProperty("maximumBrightness", Math.round(value));
    }

    function setDisplayTimeout(seconds) {
        pageRoot.displayTimeout = seconds;
        _setDisplayProperty("timeout", seconds);
    }

    function setAutoDim(on) {
        pageRoot.autoDim = on;
        _setPreference("enableALS", on);
    }

    function setRotationLocked(locked) {
        // 0 rather than a guessed orientation: see the file header - the shell
        // freezes at whatever is on screen and only reads this as a yes or no.
        pageRoot.rotationLockAngle = locked ? 0 : pageRoot.rotationUnlocked;
        _setPreference("rotationLock", pageRoot.rotationLockAngle);
    }

    // Each settings category is its own launchable application on the device.
    function openAccessibilitySettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.accessibility"}),
                  _handleSetSuccess, _handleSetError);
    }
}
