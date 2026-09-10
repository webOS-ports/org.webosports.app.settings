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
// Units & font sizes
import LunaNext.Common 0.1

/*
 * A label with an editable field on the right - the textfield-group rows the
 * Mojo settings apps used wherever something had to be typed in rather than
 * picked, as in the legacy Wi-Fi app's static IP scene.
 *
 * "edited" only fires for a change the user made, so binding "text" to a
 * setting cannot write it straight back.
 */
Item {
    id: labelAndTextField

    property alias label: labelName.text
    property alias text: field.text
    property alias placeholderText: field.placeholderText
    property alias inputMethodHints: field.inputMethodHints
    property alias readOnly: field.readOnly
    // Drawn by the field itself rather than by the page, so a row cannot be
    // left looking valid while the button that depends on it is disabled.
    property bool acceptable: true

    signal edited(string text)

    // Both, so the row is sized correctly whether it is laid out by a
    // Column (which reads height) or by a GroupBox (which reads implicit).
    height: Units.gu(6)
    implicitHeight: Units.gu(6)

    Label {
        id: labelName
        anchors.left: parent.left
        anchors.right: field.left
        anchors.rightMargin: Units.gu(1)
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }

    TextField {
        id: field
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Units.gu(24)
        height: Units.gu(5)

        color: "#2a2929"
        horizontalAlignment: Text.AlignRight
        leftPadding: Units.gu(1)
        rightPadding: Units.gu(1)
        font.pixelSize: FontUtils.sizeToPixels("16pt")

        background: Rectangle {
            color: field.enabled ? "#ffffff" : "#e4e4e4"
            radius: Units.gu(0.6)
            border.color: labelAndTextField.acceptable ? "#9a9a9a" : "#be0003"
            border.width: 1
        }

        onTextEdited: labelAndTextField.edited(text)
    }
}
