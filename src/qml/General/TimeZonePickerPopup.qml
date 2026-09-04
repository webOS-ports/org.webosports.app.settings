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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * The time zone list, after the second scene of the legacy Date & Time app.
 *
 * Same shape as the original: a search box that filters on both country and
 * city, a row per zone showing the country over the city with the zone's
 * description on the right, and Cancel at the bottom. The list comes from
 * systemservice's own getPreferenceValues, so it is exactly the set of zones
 * the device can be put into.
 */
Popup {
    id: timeZonePicker

    // The zone objects as systemservice hands them out
    property var zones: []
    // ZoneID of the zone currently in force, shown ticked
    property string currentZoneId: ""

    signal zoneSelected(var zone)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(50))
    height: Math.min(parent.height - Units.gu(4), Units.gu(70))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    onOpened: searchField.text = ""

    // Country first, city second, the order the legacy list was sorted in.
    readonly property var sortedZones: {
        var sorted = zones.slice();
        sorted.sort(function(a, b) {
            var left = (a.Country || "") + " " + (a.City || "");
            var right = (b.Country || "") + " " + (b.City || "");
            return left.toLowerCase().localeCompare(right.toLowerCase());
        });
        return sorted;
    }

    readonly property var visibleZones: {
        var filter = searchField.text.toLowerCase().trim();
        if (filter === "")
            return sortedZones;

        var matches = [];
        for (var i = 0; i < sortedZones.length; i++) {
            var zone = sortedZones[i];
            if ((zone.Country || "").toLowerCase().indexOf(filter) >= 0 ||
                (zone.City || "").toLowerCase().indexOf(filter) >= 0 ||
                (zone.Description || "").toLowerCase().indexOf(filter) >= 0)
                matches.push(zone);
        }
        return matches;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "Time Zone"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.preferredHeight: Units.gu(5)
            placeholderText: "Search"
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        }

        Label {
            Layout.fillWidth: true
            visible: timeZonePicker.visibleZones.length === 0
            Layout.preferredHeight: visible ? Units.gu(6) : 0
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: timeZonePicker.zones.length === 0 ? "Loading time zones..."
                                                    : "No matching time zone"
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        ListView {
            id: zoneList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: timeZonePicker.visibleZones

            delegate: ItemDelegate {
                width: ListView.view.width
                height: Units.gu(8)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Units.gu(1)
                    anchors.rightMargin: Units.gu(1)
                    spacing: Units.gu(1)

                    Column {
                        Layout.fillWidth: true

                        Label {
                            width: parent.width
                            text: modelData.Country ? modelData.Country : modelData.Description
                            elide: Text.ElideRight
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                            font.bold: modelData.ZoneID === timeZonePicker.currentZoneId
                        }
                        Label {
                            width: parent.width
                            visible: !!modelData.City
                            height: visible ? implicitHeight : 0
                            text: modelData.City ? modelData.City : ""
                            elide: Text.ElideRight
                            color: "#666666"
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }

                    Label {
                        text: modelData.Description ? modelData.Description : ""
                        horizontalAlignment: Text.AlignRight
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                }

                HorizontalSeparator {
                    anchors.bottom: parent.bottom
                    width: parent.width
                }

                onClicked: {
                    timeZonePicker.zoneSelected(modelData);
                    timeZonePicker.close();
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Cancel"
            onClicked: timeZonePicker.close()
        }
    }
}
