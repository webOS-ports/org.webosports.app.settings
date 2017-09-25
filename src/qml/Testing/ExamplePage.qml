/*
 * (c) 2017 Christophe Chapuis <chris.chapuis@gmail.com>
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
 * This is an example of what the code for some settings can look like
 * It is supposed to be a set of good practices, don't hesitate to
 * copy/paste code from here and adapt to your needs.
 *
 * Note: All the settings here are fake. Of Course.
 */

BasePage {
    id: pageRoot

    /*
     * These alias properties summarize what settings are relative to this page
     */
    property alias hourlyCoffee: hourlyCoffeeSwitch.checked
    property alias wikiSearch: wikiSearchSwitch.checked
    property alias publicName: publicNameTextField.text
    property alias aggressivity: aggressivityCombo.currentIndex

    Component.onCompleted: retrieveProperties();

    /*
     * Need some models for combos or lists ? Let's declare it before the UI.
     */
    ListModel {
        id: aggressivityModel
        ListElement { level: "Low" }
        ListElement { level: "Medium" }
        ListElement { level: "High" }
        ListElement { level: "Fatal" }
    }

    /* A settings page has a vertical layout: put everything in a Column */
    Column {
        width: parent.width

        /* GroupBoxes look good! */
        GroupBox {
            width: parent.width

            title: "Productivity"
            Column {
                width: parent.width

                Switch {
                    id: hourlyCoffeeSwitch
                    width: parent.width
                    text: "Hourly Coffee"
                    font.weight: Font.Normal
                    LayoutMirroring.enabled: true // by default the switch is on the left in Qt, not very webOS-ish

                    LuneOSSwitch.labelOn: "On"
                    LuneOSSwitch.labelOff: "Off"
                }
                Rectangle { color: "silver"; width: parent.width; height: 2 }
                Switch {
                    id: wikiSearchSwitch
                    width: parent.width
                    text: "Search in Wikipedia"
                    font.weight: Font.Normal
                    LayoutMirroring.enabled: true

                    LuneOSSwitch.labelOn: "Yes"
                    LuneOSSwitch.labelOff: "No"
                }
            }
        }

        GroupBox {
            width: parent.width

            title: "Advertising"
            Column {
                width: parent.width

                TextField {
                    id: publicNameTextField
                    width: parent.width
                    placeholderText: "Public name..."
                    text: "Default Name"
                }
                Rectangle { color: "silver"; width: parent.width; height: 2 }
                ComboBox {
                    id: aggressivityCombo
                    width: parent.width
                    textRole: "level"
                    model: aggressivityModel
                }
            }
        }
    }

    /*
     * Bindings with LuneOS settings
     */
    // Initialization and eventual subscription
    function retrieveProperties() {
        luna.call("palm://com.palm.systemservice/getCoffeePreference", '{"subscribe": "true"}', _handleGetCoffeePreference, _handleGetError);
        luna.call("palm://com.palm.systemservice/getAggressivity", '{}', _handleGetAggressivity, _handleGetError);
    }
    function _handleGetCoffeePreference(message) {
        if(message && message.payload) {
            payloadValue = JSON.parse(message.payload);
            if(typeof payloadValue.hourly !== 'undefined') {
                pageRoot.hourlyCoffee = payloadValue.hourly;
            }
        }
    }
    function _handleGetAggressivity(message) {
        if(message && message.payload) {
            payloadValue = JSON.parse(message.payload);
            if(typeof payloadValue.value !== 'undefined') {
                pageRoot.aggressivity = payloadValue.value;
            }
        }
    }
    // Push changes to LuneOS
    onHourlyCoffeeChanged: {
        luna.call("palm://com.palm.systemservice/setCoffeePreference", '{"hourly": "'+hourlyCoffee+'"}', _handleSetSuccess, _handleSetError);
    }
    onAggressivityChanged: {
        luna.call("palm://com.palm.systemservice/setAggressivity", '{"value": "'+aggressivity+'"}', _handleSetSuccess, _handleSetError);
    }
}
