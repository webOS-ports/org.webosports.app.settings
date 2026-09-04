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
 * The scrolling body of a settings page: everything declared inside lands in
 * a vertical column, one group under the next.
 *
 * The column is capped and centred rather than stretched. That is what the
 * legacy apps did too - every one of them wrapped its rows in Enyo's
 * "box-center" - and it is what makes the same page read correctly on a phone
 * and on a tablet: on a phone the cap is wider than the screen, so the column
 * simply fills it, while on a tablet the rows stay a comfortable line length
 * instead of stretching a switch a foot away from its label.
 */
Flickable {
    id: pageContent

    default property alias contentChildren: contentColumn.data
    property alias spacing: contentColumn.spacing
    // Widen or narrow the column for a page that needs it (a list of printers
    // can take more width than a column of switches).
    property real maximumContentWidth: Units.gu(56)

    readonly property real columnWidth: contentColumn.width

    anchors.fill: parent
    anchors.margins: Units.gu(1)

    contentWidth: width
    contentHeight: contentColumn.height
    flickableDirection: Flickable.AutoFlickIfNeeded
    clip: true

    Column {
        id: contentColumn

        width: Math.min(pageContent.width, pageContent.maximumContentWidth)
        x: (pageContent.width - width) / 2
        spacing: Units.gu(2)
    }
}
