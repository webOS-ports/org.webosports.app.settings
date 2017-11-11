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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0

// Units & font sizes
import LunaNext.Common 0.1
// LuneOS Bluetooth wrapper
import LuneOS.Bluetooth 0.2

Popup {
    id: displayPinCodePopup
    dim: true
    modal: true
    visible: true
    x: (parent.width - width)/2
    y: (parent.height - height)/2

    property string deviceName: "";
    property string pinCode: "";

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Units.gu(2)
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            width: displayPinCodePopup.width - Units.gu(2)
            wrapMode: Label.Wrap
            horizontalAlignment: Text.AlignHCenter
            text: "Please enter the following code on " + deviceName
        }
        TextField {
            anchors.horizontalCenter: parent.horizontalCenter
            width: contentWidth + Units.gu(2)
            readOnly: true
            text: pinCode
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Close"
            onClicked: displayPinCodePopup.close();
        }
    }
}
