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
 * Accessibility.
 *
 * Nothing on a LuneOS device could be made bigger. Every size in the whole
 * interface comes from Units.gu(), and every font size from
 * FontUtils.sizeToPixels(), and both resolve through one number - the grid
 * unit, which came from luna.conf or the GRID_UNIT_PX environment variable
 * and could not be changed from anywhere a person can reach.
 *
 * That number now has a scale applied to it, and this page sets it. Three
 * pieces, one per repository, because the value has to cross from a
 * preference into the constructor of a QML plugin:
 *
 *  1. This page writes a "uiScale" systemservice preference, which is an
 *     ordinary setPreferences call.
 *  2. luna-next-cardshell's Preferences watches that key and mirrors it into
 *     /var/luna/preferences/ui-scale.
 *  3. LunaNext.Common's Units reads that file when it is constructed and
 *     multiplies the grid unit by it.
 *
 * A file rather than a bus call at step 3 because Units is constructed by a
 * plugin every application loads before it draws anything: a round trip
 * there would be a startup cost every application on the device pays, for a
 * value that changes about twice in the life of one. The consequence is that
 * the scale is fixed for the life of a process, so a change shows up in an
 * application the next time it starts, and in the shell when the shell does.
 * The page says so rather than looking as though nothing happened.
 *
 * The range is deliberately narrow. Below about three quarters the shell's
 * own chrome stops fitting together, and above about half again the launcher
 * runs out of room for a row of icons; Units clamps to that on both sides, so
 * a value from anywhere else cannot leave a device unusable.
 *
 * The rest of what an accessibility panel usually holds is not here because
 * there is nothing behind it: no screen reader on the device, no colour
 * inversion or contrast control in the compositor, no per-application
 * accessibility service. Those are listed in docs/missing-services.md rather
 * than drawn as switches that do nothing.
 */
BasePage {
    id: pageRoot

    property real uiScale: 1.0
    property bool prefsLoaded: false

    // What Units is scaling this process by, which is not necessarily what
    // the preference says - see the file header.
    readonly property real appliedScale: Units.uiScale

    readonly property var scaleValues: [0.85, 1.0, 1.15, 1.3]
    readonly property var scaleLabels: ["Small", "Normal", "Large", "Largest"]

    Component.onCompleted: retrieveProperties();

    function _closestScaleIndex(value) {
        var best = 1;
        var bestDistance = Number.MAX_VALUE;

        for (var i = 0; i < pageRoot.scaleValues.length; i++) {
            var distance = Math.abs(pageRoot.scaleValues[i] - value);
            if (distance < bestDistance) {
                bestDistance = distance;
                best = i;
            }
        }
        return best;
    }

    // True once the preference and what this process is drawn at disagree,
    // which is exactly when there is something to tell the user.
    readonly property bool restartNeeded:
        Math.abs(pageRoot.uiScale - pageRoot.appliedScale) > 0.01

    SettingsPageContent {
        GroupBox {
            width: parent.width

            Column {
                width: parent.width

                LabelAndSelector {
                    id: scaleSelector
                    width: parent.width
                    label: "Size"
                    model: pageRoot.scaleLabels

                    currentIndex: pageRoot._closestScaleIndex(pageRoot.uiScale)
                    Connections {
                        target: pageRoot
                        function onUiScaleChanged() {
                            scaleSelector.currentIndex =
                                pageRoot._closestScaleIndex(pageRoot.uiScale);
                        }
                    }
                    onActivated: (index) => pageRoot.setUiScale(pageRoot.scaleValues[index])
                }
            }
        }

        ExplanationText {
            text: "This makes everything larger or smaller together - text, " +
                  "buttons and the spacing between them - rather than the " +
                  "text alone, so nothing ends up overlapping."
        }

        GroupBox {
            width: parent.width
            visible: pageRoot.restartNeeded

            title: "Not applied yet"

            Column {
                width: parent.width

                Label {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: "Each application reads this when it starts, so it " +
                          "takes effect in an application the next time that " +
                          "application is opened, and across the whole device " +
                          "the next time it is restarted."
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        GroupBox {
            width: parent.width

            title: "Elsewhere"

            Column {
                width: parent.width
                spacing: Units.gu(1)

                Button {
                    text: "Display"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openDisplaySettings()
                }

                Button {
                    text: "Sounds & Ringtones"
                    LuneOSButton.mainColor: LuneOSButton.secondaryColor
                    onClicked: pageRoot.openSoundSettings()
                }
            }
        }

        ExplanationText {
            text: "Screen brightness and how long before the screen turns " +
                  "off are on Display. Vibration and how loud alerts are, on " +
                  "Sounds & Ringtones."
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        luna.subscribe("luna://com.webos.service.systemservice/getPreferences",
                       JSON.stringify({"keys": ["uiScale"], "subscribe": true}),
                       _handleGetPreferences, _handleGetError);
    }

    function _handleGetPreferences(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);

        // Absent on a device nobody has been through this page on, which is
        // normal size rather than an error.
        if (response.hasOwnProperty("uiScale"))
            pageRoot.uiScale = response.uiScale;

        pageRoot.prefsLoaded = true;
    }

    function setUiScale(scale) {
        pageRoot.uiScale = scale;
        _setPreference("uiScale", scale);
    }

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

    // Each settings category is its own launchable application on the device.
    function openDisplaySettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.display"}),
                  _handleSetSuccess, _handleSetError);
    }

    function openSoundSettings() {
        luna.call("luna://com.webos.service.applicationManager/launch",
                  JSON.stringify({"id": "org.webosports.app.settings.soundsandalerts"}),
                  _handleSetSuccess, _handleSetError);
    }
}
