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

/*
 * A label on the left with an On/Off switch on the right - the ToggleButton
 * row that every Mojo and Enyo settings app was built out of.
 *
 * "checked" follows whatever the page holds and "toggled" only fires for a
 * change the user made, so binding checked to a setting cannot write it
 * straight back. That matters: these settings arrive from a subscription, and
 * a switch that echoed every update would fight the service.
 */
Switch {
    id: labelAndSwitch

    property alias label: labelAndSwitch.text

    width: parent ? parent.width : implicitWidth

    // Qt puts the indicator on the left, which is not very webOS-ish
    LayoutMirroring.enabled: true

    font.pixelSize: FontUtils.sizeToPixels("16pt")
    font.weight: Font.Normal

    LuneOSSwitch.labelOn: "On"
    LuneOSSwitch.labelOff: "Off"
}
