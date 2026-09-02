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
// Units & font sizes
import LunaNext.Common 0.1

/*
 * A LabelAndValue that can be tapped to change the value, the way the legacy
 * Ringtone row opened the file picker. The placeholder stands in - greyed out -
 * for as long as there is nothing set.
 */
ItemDelegate {
    id: labelAndPicker

    property alias label: labelName.text
    property string value
    property string placeholder

    height: Units.gu(6)

    RowLayout {
        anchors.fill: parent

        Label {
            id: labelName
            font.pixelSize: FontUtils.sizeToPixels("16pt")
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: labelAndPicker.value !== "" ? labelAndPicker.value : labelAndPicker.placeholder
            elide: Text.ElideRight
            color: labelAndPicker.value !== "" ? "black" : "#666666"
            font.pixelSize: FontUtils.sizeToPixels("16pt")
        }
    }
}
