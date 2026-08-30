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
 * A label with a slider underneath, the way the volume rows of the legacy
 * Sounds & Ringtones app were laid out.
 *
 * "moved" fires while the user drags, "released" once when the finger leaves
 * the handle: settings that are cheap to apply follow the drag, the ones that
 * make a noise (a feedback beep, a ringtone preview) wait for the release.
 */
Item {
    id: labelAndSlider

    property alias label: labelName.text
    property alias value: slider.value
    property alias pressed: slider.pressed

    signal moved(int value)
    signal released(int value)

    height: labelName.height + slider.height + Units.gu(1)

    Label {
        id: labelName
        anchors.left: parent.left
        anchors.top: parent.top
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: labelName.bottom
        anchors.topMargin: Units.gu(0.5)

        from: 0
        to: 100
        stepSize: 1

        onMoved: labelAndSlider.moved(Math.round(slider.value))
        onPressedChanged: if (!pressed) labelAndSlider.released(Math.round(slider.value))
    }
}
