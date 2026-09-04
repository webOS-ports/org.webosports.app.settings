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
 * The small grey paragraph the legacy apps put underneath a group to say what
 * the setting above it actually does ("explanation-text" / "accounts-body-text"
 * in the Mojo and Enyo stylesheets).
 */
Label {
    width: parent ? parent.width : implicitWidth

    wrapMode: Text.WordWrap
    color: "#666666"
    font.pixelSize: FontUtils.sizeToPixels("small")

    /*
     * An empty explanation should not leave a gap in the column - which
     * "visible" alone already gets right, since every page puts this in a
     * plain Column, and a Column simply skips invisible children when it lays
     * the rest out.
     *
     * There used to be a "height: visible ? implicitHeight : 0" here as well,
     * belt-and-braces for containers that do reserve space for hidden items.
     * Nothing here needs that, and it did active harm: a wrapping Label's
     * implicitHeight settles over two layout passes (guess a height, learn
     * the wrapped width, correct the height), and tying that same value into
     * "height" back out let Qt Quick's positioner catch it mid-correction and
     * mistake it for a binding loop - reliably, whenever a sibling earlier in
     * the same Column also changed size in that instant (a GroupBox further
     * up appearing, say). The warning was only ever cosmetic, but it is
     * simpler to not draw it in the first place.
     */
    visible: text !== ""
}
