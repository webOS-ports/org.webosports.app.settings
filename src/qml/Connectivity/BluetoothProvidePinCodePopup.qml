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
    id: providePinCodePopup
    focus: true
    dim: true
    modal: true
    visible: true
    x: (parent.width - width)/2
    y: (parent.height - height)/2

    property LuneOSBluetoothRequest bluezRequest;
    property string deviceName;
    property bool requestHandled: false

    onClosed: if(!requestHandled) bluezRequest.cancel();

    Column {
        spacing: Units.gu(2)
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "PIN for " + deviceName
        }
        TextField {
            id: pinCodeTextField
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - Units.gu(2)
            text: "123456"
            focus: true
            maximumLength: 16
            Component.onCompleted: {
                selectAll();
                forceActiveFocus()
            }
            inputMethodHints: Qt.ImhNoPredictiveText
        }
        Row {
            spacing: Units.gu(1)
            Button {
                text: "Ok"
                onClicked: {
                    bluezRequest.accept(pinCodeTextField.text);
                    requestHandled = true;
                    providePinCodePopup.close();
                }
            }
            Button {
                text: "Cancel"
                onClicked: {
                    bluezRequest.cancel();
                    requestHandled = true;
                    providePinCodePopup.close();
                }
            }
        }
    }
}
