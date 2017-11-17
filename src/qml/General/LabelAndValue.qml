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
// Units & font sizes
import LunaNext.Common 0.1

Item {
    property alias label: labelName.text
    property alias value: labelValue.text

    height: Units.gu(6)
    Label {
        id: labelName
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }
    Label {
        id: labelValue
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }
}
