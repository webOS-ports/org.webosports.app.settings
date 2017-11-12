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
import Connman 0.2

Popup {
    id: providePassphrasePopup
    focus: true
    dim: true
    modal: true
    closePolicy: Popup.NoAutoClose
    visible: true
    x: (parent.width - width)/2
    y: (parent.height - height)/2

    property UserAgent agent;
    property string serviceName: ""
    property variant requestedFields: ({});

    Column {
        spacing: Units.gu(2)

        TextField {
            id: username

            height: Units.gu(4)

            anchors.left: parent.left
            anchors.right: parent.right

            font.pixelSize: FontUtils.sizeToPixels("medium")
            echoMode: TextInput.Normal
            placeholderText: "Enter username ..."
            visible: requestedFields.hasOwnProperty("Identity") || requestedFields.hasOwnProperty("Username")
            inputMethodHints: Qt.ImhNoPredictiveText

            onActiveFocusChanged: {
                if (username.focus)
                    Qt.inputMethod.show();
                else
                    Qt.inputMethod.hide();
            }
        }
        TextField {
            id: passphrase

            height: Units.gu(4)

            anchors.left: parent.left
            anchors.right: parent.right

            font.pixelSize: FontUtils.sizeToPixels("medium")
            echoMode: showPassphrase.checked ? TextInput.Normal : TextInput.Password
            inputMethodHints: Qt.ImhNoPredictiveText
            placeholderText: "Enter passphrase ..."
            onActiveFocusChanged: {
                if (passphrase.focus)
                    Qt.inputMethod.show();
                else
                    Qt.inputMethod.hide();
            }
        }
        CheckBox {
            id: showPassphrase
            checked: false
            text: "Show passphrase"
        }

        Row {
            spacing: Units.gu(1)
            Button {
                text: "Connect"
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                enabled: (!username.visible || username.text.length>0) && passphrase.text.length>0
                onClicked: {
                    var reply = {};
                    if(requestedFields.hasOwnProperty("Name")) {
                        reply.Name = serviceName;
                    }

                    if(requestedFields.hasOwnProperty("Identity")) {
                        reply.Identity = username.text;
                    }
                    else if(requestedFields.hasOwnProperty("Username")) {
                        reply.Username = username.text;
                    }
                    if(requestedFields.hasOwnProperty("Passphrase")) {
                        reply.Passphrase = passphrase.text;
                    }
                    else if(requestedFields.hasOwnProperty("Password")) {
                        reply.Password = passphrase.text;
                    }

                    agent.sendUserReply(reply)
                    providePassphrasePopup.close();
                }
            }
            Button {
                text: "Cancel"
                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                onClicked: {
                    agent.userInputCanceled();
                    providePassphrasePopup.close();
                }
            }
        }
    }
}
