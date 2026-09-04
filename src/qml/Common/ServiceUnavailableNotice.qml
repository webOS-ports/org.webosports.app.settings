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
 * Shown at the top of a page whose service did not answer.
 *
 * Several of these settings were ports of apps that talked to a service HP
 * shipped and LuneOS does not have yet. Rather than let the page look like it
 * works and quietly drop every change, it says which service is missing and
 * leaves the rows below it disabled. When the service does turn up, the notice
 * disappears on its own and the page is live - nothing else has to change.
 */
Rectangle {
    id: notice

    // The bus name the page tried to reach, e.g. "org.webosports.service.vpn"
    property string serviceName
    // One line on what stays unavailable until it is there
    property string description

    signal retry()

    width: parent ? parent.width : implicitWidth
    // Both: a Column reads height, a Layout reads implicitHeight.
    implicitHeight: noticeColumn.height + Units.gu(3)
    height: implicitHeight

    color: "#f4ecd0"
    border.color: "#c9b980"
    border.width: 1
    radius: Units.gu(0.6)

    Column {
        id: noticeColumn

        x: Units.gu(1.5)
        y: Units.gu(1.5)
        width: parent.width - Units.gu(3)
        spacing: Units.gu(1)

        Label {
            width: parent.width
            text: "Not available on this device"
            wrapMode: Text.WordWrap
            color: "#5a4b16"
            font.weight: Font.Bold
            font.pixelSize: FontUtils.sizeToPixels("16pt")
        }

        Label {
            width: parent.width
            text: notice.description
            wrapMode: Text.WordWrap
            color: "#5a4b16"
            font.pixelSize: FontUtils.sizeToPixels("small")
        }

        Label {
            width: parent.width
            visible: notice.serviceName !== ""
            height: visible ? implicitHeight : 0
            text: notice.serviceName + " did not answer."
            wrapMode: Text.WrapAnywhere
            color: "#7a6a30"
            font.pixelSize: FontUtils.sizeToPixels("small")
        }

        Button {
            text: "Try again"
            LuneOSButton.mainColor: LuneOSButton.secondaryColor
            onClicked: notice.retry()
        }
    }
}
