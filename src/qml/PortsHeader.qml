/*
 * (c) 2013 Simon Busch <morphis@gravedo.de>
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

import QtQuick 2.0

Rectangle {
    id: root

    property string title: "Unknown"
    property variant taglines: []
    property string icon: ""

    width: parent.width
    height: 70

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#555" }
        GradientStop { position: 1.0; color: "#333" }
    }

    Item {
        id: content

        anchors.fill: parent
        anchors.margins: 3

        Image {
            id: icon
            anchors.left: parent.left
            anchors.right: titleText.let
            height: parent.height
            source: root.icon
        }

        Text {
            id: titleText
            text: root.title
            anchors.left: icon.right
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 8
            font.pixelSize: 21
            font.bold: true
            color: "white"
        }

        Text {
            id: taglineText
            font.pixelSize: 13
            anchors.top: titleText.bottom
            anchors.left: icon.right
            anchors.leftMargin: 10
            color: "white"
        }
    }

    Component.onCompleted: {
        taglineText.text = root.taglines[Math.floor(Math.random() * root.taglines.length)]
    }
}
