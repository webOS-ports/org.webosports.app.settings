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

import Eos.Window 0.1
import LunaNext.Common 0.1
import LuneOS.Components 1.0 as LuneComponents

/*
 * The Print Manager's alert when a job cannot go on until something is done
 * at the printer, as webOS 3.0.5 popped one up: what is wrong ("Out of
 * Paper") over what to do, the printer's icon beside them, and Cancel
 * Print Job (red, the job goes) or Dismiss. It is the shell's popup alert,
 * as Phone's are: no panel of its own, the shell paints the strip behind.
 */
WebOSWindow {
    id: alert

    property string title: ""
    property string message: ""
    property url icon
    // Cancel Print Job was asked and the print service has not answered
    property bool cancelling: false

    signal cancelJob()
    signal dismiss()

    width: Settings.displayWidth
    height: Math.max(Units.gu(12.5), Math.min(Units.gu(15), content.implicitHeight + Units.gu(8)))

    keepAlive: true
    windowType: "_WEBOS_WINDOW_TYPE_SYSTEM_UI"
    visible: false

    Component.onCompleted: {
        setWindowProperty("LuneOS_window", "popupalert");
        visible = true;
    }

    // Swiped away, as Dismiss
    onWindowCloseRequested: alert.dismiss()

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Row {
        id: content
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Units.gu(1.5)
        }
        spacing: Units.gu(1.5)

        Image {
            width: Units.gu(6.4)
            height: width
            anchors.verticalCenter: parent.verticalCenter
            fillMode: Image.PreserveAspectFit
            source: alert.icon
            sourceSize.width: width
            sourceSize.height: height
        }

        Column {
            width: parent.width - Units.gu(6.4) - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Units.gu(0.5)

            Text {
                objectName: "printAlertTitle"
                width: parent.width
                color: "white"
                font.family: "Prelude"
                font.bold: true
                font.pixelSize: Units.gu(1.8)
                elide: Text.ElideRight
                text: alert.title
            }
            Text {
                objectName: "printAlertMessage"
                width: parent.width
                color: "white"
                wrapMode: Text.Wrap
                font.family: "Prelude"
                font.pixelSize: Units.gu(1.4)
                text: alert.message
            }
        }
    }

    Row {
        anchors {
            bottom: parent.bottom
            bottomMargin: Units.gu(1)
            horizontalCenter: parent.horizontalCenter
        }
        height: Units.gu(4)
        spacing: Units.gu(1)

        // Red: the job goes
        LuneComponents.DialogButton {
            objectName: "printAlertCancel"
            text: "Cancel Print Job"
            color: "#be0003"
            fontcolor: "white"
            buttonWidth: Units.gu(16)
            opacity: alert.cancelling ? 0.5 : 1
            onClicked: if (!alert.cancelling) alert.cancelJob()
        }
        LuneComponents.DialogButton {
            objectName: "printAlertDismiss"
            text: "Dismiss"
            color: "white"
            fontcolor: "#292929"
            buttonWidth: Units.gu(16)
            onClicked: alert.dismiss()
        }
    }
}
