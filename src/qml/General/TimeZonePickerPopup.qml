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
// Units & font sizes
import LunaNext.Common 0.1

import LuneOS.Forms 1.0

/*
 * The time zone list, after the second scene of the legacy Date & Time app.
 *
 * Same shape as the original - a search box, a row per zone showing the
 * country over the city with the zone's description on the right, and Cancel
 * at the bottom - as LuneOS.Forms' ListPickerPopup. The list comes from
 * systemservice's own getPreferenceValues, so it is exactly the set of zones
 * the device can be put into.
 */
ListPickerPopup {
    id: timeZonePicker

    // The zone objects as systemservice hands them out
    property var zones: []
    // ZoneID of the zone currently in force, shown ticked
    property string currentZoneId: ""

    signal zoneSelected(var zone)

    width: Math.min(parent.width - Units.gu(4), Units.gu(50))

    title: "Time Zone"
    currentKey: currentZoneId
    loading: zones.length === 0
    // Always searchable: there are hundreds
    searchThreshold: 0

    // Country first, city second, the order the legacy list was sorted in;
    // the search finds a zone by country, city or description
    entries: {
        var sorted = zones.slice();
        sorted.sort(function(a, b) {
            var left = (a.Country || "") + " " + (a.City || "");
            var right = (b.Country || "") + " " + (b.City || "");
            return left.toLowerCase().localeCompare(right.toLowerCase());
        });
        return sorted.map(function(zone) {
            return {
                "key": zone.ZoneID,
                "label": zone.Country ? zone.Country : zone.Description,
                "sublabel": zone.City ? zone.City : "",
                "note": zone.Description ? zone.Description : "",
                "zone": zone
            };
        });
    }

    onPicked: (key, entry) => timeZonePicker.zoneSelected(entry.zone)
}
