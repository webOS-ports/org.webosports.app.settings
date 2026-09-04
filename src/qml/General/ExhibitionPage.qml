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
 * Exhibition, after the webOS 3.0.5 app of the same name
 * (com.palm.app.exhibitionpreferences).
 *
 * Same page as the original: a checkbox per application that has declared
 * itself usable in Exhibition mode, a fixed "Time" entry at the top that
 * cannot be switched off, and a button that puts the device into Exhibition
 * mode there and then.
 *
 * The list and the two toggles are luna-appmanager's dock-mode launch points -
 * listDockModeLaunchPoints / addDockModeLaunchPoint / removeDockModeLaunchPoint -
 * which LuneOS carries. Entering the mode is com.palm.display setState "dock",
 * the same call the original made, and the one the card shell watches for.
 *
 * The "Find More..." button is gone: it opened HP's App Catalog, which no
 * longer exists.
 *
 * Worth knowing: the card shell's Exhibition mode currently only draws the
 * clocks. Nothing is lost by ticking an application here - the choice is
 * stored and will be honoured the day the shell hosts dock-mode windows - but
 * until then Time is what you will see, so the page says as much rather than
 * letting the list look busier than it is.
 */
BasePage {
    id: pageRoot

    property var dockApps: []
    property bool listReceived: false

    Component.onCompleted: retrieveProperties();

    SettingsPageContent {
        ExplanationText {
            text: "Exhibition mode is what the device shows while it sits in a " +
                  "charging dock. Pick what may appear there."
        }

        GroupBox {
            width: parent.width
            title: "Applications"

            Column {
                width: parent.width

                /*
                 * The clock is always available and cannot be turned off - it
                 * is what Exhibition mode falls back to - so the original
                 * listed it first with its checkbox disabled.
                 */
                CheckBox {
                    width: parent.width
                    text: "Time"
                    checked: true
                    enabled: false
                    LayoutMirroring.enabled: true
                    font.pixelSize: FontUtils.sizeToPixels("16pt")
                    font.weight: Font.Normal
                }

                Repeater {
                    model: pageRoot.dockApps

                    delegate: Column {
                        width: parent.width

                        HorizontalSeparator {
                            width: parent.width
                        }

                        CheckBox {
                            width: parent.width
                            text: modelData.title
                            checked: modelData.enabled
                            LayoutMirroring.enabled: true
                            font.pixelSize: FontUtils.sizeToPixels("16pt")
                            font.weight: Font.Normal

                            onToggled: pageRoot.setDockAppEnabled(modelData.appId, checked)
                        }
                    }
                }

                Label {
                    width: parent.width
                    visible: pageRoot.listReceived && pageRoot.dockApps.length === 0
                    height: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: "No installed application supports Exhibition mode."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }
            }
        }

        ExplanationText {
            // Honest about where the shell currently stands, rather than
            // letting a ticked box promise something it cannot deliver.
            text: "The card shell shows the clocks in Exhibition mode today. " +
                  "Applications ticked here are remembered and will appear once " +
                  "the shell hosts them."
        }

        Button {
            width: parent.width
            text: "Start Exhibition"
            LuneOSButton.mainColor: LuneOSButton.affirmativeColor
            onClicked: pageRoot.enterExhibitionMode()
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    function retrieveProperties() {
        // Subscribed: installing or removing an application changes this list
        // while the page is open.
        luna.subscribe("luna://com.palm.applicationManager/listDockModeLaunchPoints",
                       JSON.stringify({"subscribe": true}),
                       _handleDockAppList, _handleGetError);
    }

    function _handleDockAppList(message) {
        if (!message || !message.payload)
            return;

        var response = JSON.parse(message.payload);
        if (!response.returnValue)
            return;

        var launchPoints = response.launchPoints !== undefined ? response.launchPoints : [];
        var apps = [];
        for (var i = 0; i < launchPoints.length; i++) {
            apps.push({
                "title": launchPoints[i].title,
                "appId": launchPoints[i].appId,
                "enabled": launchPoints[i].enabled === true
            });
        }

        pageRoot.dockApps = apps;
        pageRoot.listReceived = true;
    }

    function setDockAppEnabled(appId, enabled) {
        var method = enabled ? "addDockModeLaunchPoint" : "removeDockModeLaunchPoint";
        luna.call("luna://com.palm.applicationManager/" + method,
                  JSON.stringify({"appId": appId}),
                  _handleSetSuccess, _handleSetError);
    }

    function enterExhibitionMode() {
        luna.call("luna://com.palm.display/control/setState",
                  JSON.stringify({"state": "dock"}),
                  _handleSetSuccess, _handleSetError);
    }
}
