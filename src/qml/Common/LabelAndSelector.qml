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
 * A label with a list of choices on the right, the ListSelector rows of the
 * Mojo settings apps. "activated" only fires for a choice the user made, so
 * binding currentIndex to a setting cannot write it straight back.
 */
Item {
    id: labelAndSelector

    property alias label: labelName.text
    property alias model: selector.model
    property alias currentIndex: selector.currentIndex

    signal activated(int index)

    // Both, so the row is sized correctly whether it is laid out by a
    // Column (which reads height) or by a GroupBox (which reads implicit).
    height: Units.gu(6)
    implicitHeight: Units.gu(6)

    Label {
        id: labelName
        anchors.left: parent.left
        anchors.right: selector.left
        anchors.rightMargin: Units.gu(1)
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }

    ComboBox {
        id: selector
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Units.gu(24)

        onActivated: (index) => labelAndSelector.activated(index)
    }
}
