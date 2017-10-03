/*
 * (c) 2013 Simon Busch <morphis@gravedo.de>
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

import LunaNext.Common 0.1

Pane {
    id: root

    property string title: "Unknown"
    property string icon: ""

    property alias actionHeaderComponent: actionComponentLoader.sourceComponent

    background: Image {
        source: "images/toolbar-light.png"
        fillMode: Image.Stretch
    }

    Row {
        height: parent.height

        Image {
            id: iconImage
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: height
            source: root.icon
        }

        Label {
            id: titleText

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Units.gu(1.0)
            width: parent.width - iconImage.width

            text: root.title
            font.bold: true
            verticalAlignment: Text.AlignVCenter
        }
    }

    Loader {
        id: actionComponentLoader
        sourceComponent: actionHeaderComponent
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }
}
