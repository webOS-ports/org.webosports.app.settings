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
 * A LabelAndPicker for a notification-LED colour: the name of the colour on
 * the right, and the colour itself beside it.
 *
 * The swatch is the point of the row - the name next to it is only a label for
 * it - so it shows the colour that will actually blink, including the one
 * inherited from the default. The name, by contrast, shows what is stored, and
 * greys out to the placeholder when that is nothing, the same way
 * LabelAndPicker greys an unset value.
 */
ItemDelegate {
    id: ledColorRow

    property alias label: labelName.text

    // The stored colour, "" when nothing is set for this row.
    property string colorValue: ""
    // [{ key, label }], the same list the picker is given, used to turn
    // colorValue into a name.
    property var colorChoices: []
    // The colour that will actually blink, after any fallback.
    property color effectiveColor: "#ffffff"
    // Shown, greyed, in place of the name while colorValue is "".
    property string placeholder: "Default"

    readonly property bool hasOwnColor: colorValue !== ""

    readonly property string colorName: {
        if (!hasOwnColor)
            return placeholder;

        for (var i = 0; i < colorChoices.length; i++) {
            if (colorChoices[i].key === colorValue)
                return colorChoices[i].label;
        }

        // Set by hand, or by a later version of the page with a longer list.
        // Show it rather than pretending it is unset.
        return colorValue;
    }

    height: Units.gu(6)
    implicitHeight: Units.gu(6)

    RowLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            id: labelName
            font.pixelSize: FontUtils.sizeToPixels("16pt")
        }

        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            text: ledColorRow.colorName
            elide: Text.ElideRight
            color: ledColorRow.hasOwnColor ? "black" : "#666666"
            font.pixelSize: FontUtils.sizeToPixels("16pt")
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Units.gu(2.5)
            implicitHeight: Units.gu(2.5)
            radius: width / 2
            color: ledColorRow.effectiveColor
            // A white or yellow LED on the light page background would
            // otherwise be an invisible circle.
            border.width: 1
            border.color: "#666666"
        }
    }
}
