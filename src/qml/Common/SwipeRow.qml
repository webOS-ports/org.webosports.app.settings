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
 * A settings row you can swipe sideways to delete, the webOS delete gesture.
 *
 * Same thing as a plain SwipeDelegate, minus its opaque white background: a
 * row inside a settings group should sit on the group, not on a white band of
 * its own. The red confirmation the style draws underneath is only created
 * once a swipe starts, so nothing shows through at rest.
 *
 * Set LuneOSSwipeDelegate.confirmText for the wording on the red panel and
 * handle LuneOSSwipeDelegate.onConfirmed to do the deleting.
 */
SwipeDelegate {
    width: parent ? parent.width : implicitWidth
    height: Units.gu(6)

    font.pixelSize: FontUtils.sizeToPixels("16pt")

    background: Item {}
}
