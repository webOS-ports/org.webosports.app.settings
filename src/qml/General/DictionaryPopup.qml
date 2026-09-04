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
import QtQuick.Layouts 1.3

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * The user dictionary, after the legacy Text Assist app's dictionary scene:
 * two lists behind two tabs - the words you taught it, and the shortcuts that
 * expand as you type - with a row to add to whichever is showing and a swipe
 * to take one away.
 *
 * The page above owns the storage; this only shows what it is given and says
 * what was asked for.
 */
Popup {
    id: dictionaryPopup

    // [{ _id, word }]
    property var words: []
    // [{ _id, shortcut, substitution }]
    property var shortcuts: []

    signal addWordRequested(string word)
    signal removeWordRequested(string id)
    signal addShortcutRequested(string shortcut, string substitution)
    signal removeShortcutRequested(string id)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    width: Math.min(parent.width - Units.gu(4), Units.gu(50))
    height: Math.min(parent.height - Units.gu(4), Units.gu(70))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    onOpened: {
        newWordField.text = "";
        newShortcutField.text = "";
        newSubstitutionField.text = "";
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "User Dictionary"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true

            TabButton { text: "Words" }
            TabButton { text: "Shortcuts" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            /* Words */
            ColumnLayout {
                spacing: Units.gu(1)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)

                    TextField {
                        id: newWordField
                        Layout.fillWidth: true
                        Layout.preferredHeight: Units.gu(5)
                        placeholderText: "Add a word"
                        inputMethodHints: Qt.ImhNoPredictiveText

                        onAccepted: addWordButton.clicked()
                    }
                    Button {
                        id: addWordButton
                        text: "Add"
                        enabled: newWordField.text.trim() !== ""
                        LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                        onClicked: {
                            dictionaryPopup.addWordRequested(newWordField.text.trim());
                            newWordField.text = "";
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: dictionaryPopup.words.length === 0
                    Layout.preferredHeight: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: "No words yet. Words you add here are never corrected."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ListView {
                    id: wordsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    // A small finger drag while releasing on Cancel/Delete used
                    // to be interpreted as a list flick - keep the list from
                    // stealing presses unless it actually needs to scroll,
                    // the same guard Fingerprint's list uses.
                    interactive: contentHeight > height

                    model: dictionaryPopup.words

                    // Swipe sideways to ask for delete confirmation - the same
                    // legacy webOS gesture Fingerprint and Print Manager use,
                    // not the QtQuick Controls SwipeDelegate reveal this used
                    // to be, which looked and behaved unlike either of them.
                    delegate: Item {
                        id: wordRow
                        width: ListView.view.width
                        height: Units.gu(6)

                        property bool pendingDelete: false

                        Item {
                            anchors.fill: parent
                            visible: !wordRow.pendingDelete

                            Label {
                                anchors.left: parent.left
                                anchors.leftMargin: Units.gu(1)
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.word
                                font.pixelSize: FontUtils.sizeToPixels("16pt")
                            }

                            MouseArea {
                                anchors.fill: parent

                                property real _pressX: 0

                                onPressed: (mouse) => { _pressX = mouse.x; }
                                onReleased: (mouse) => {
                                    if (Math.abs(mouse.x - _pressX) > Units.gu(4))
                                        wordRow.pendingDelete = true;
                                }
                            }
                        }

                        // Delete confirmation: Cancel (grey) + Delete (red),
                        // centred, matching the legacy webOS swipe-to-delete.
                        Row {
                            anchors.centerIn: parent
                            spacing: Units.gu(2)
                            visible: wordRow.pendingDelete

                            Button {
                                text: "Cancel"
                                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                onClicked: wordRow.pendingDelete = false
                            }

                            Button {
                                text: "Delete"
                                LuneOSButton.mainColor: "#be0003"
                                LuneOSButton.textColor: "white"
                                onClicked: {
                                    dictionaryPopup.removeWordRequested(modelData._id);
                                    wordRow.pendingDelete = false;
                                }
                            }
                        }

                        HorizontalSeparator {
                            anchors.bottom: parent.bottom
                            width: parent.width
                        }
                    }
                }
            }

            /* Shortcuts */
            ColumnLayout {
                spacing: Units.gu(1)

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Units.gu(1)

                    TextField {
                        id: newShortcutField
                        Layout.preferredWidth: Units.gu(10)
                        Layout.preferredHeight: Units.gu(5)
                        placeholderText: "brb"
                        inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                    }
                    TextField {
                        id: newSubstitutionField
                        Layout.fillWidth: true
                        Layout.preferredHeight: Units.gu(5)
                        placeholderText: "be right back"
                        inputMethodHints: Qt.ImhNoPredictiveText

                        onAccepted: addShortcutButton.clicked()
                    }
                    Button {
                        id: addShortcutButton
                        text: "Add"
                        enabled: newShortcutField.text.trim() !== "" &&
                                 newSubstitutionField.text.trim() !== ""
                        LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                        onClicked: {
                            dictionaryPopup.addShortcutRequested(newShortcutField.text.trim(),
                                                                 newSubstitutionField.text.trim());
                            newShortcutField.text = "";
                            newSubstitutionField.text = "";
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    visible: dictionaryPopup.shortcuts.length === 0
                    Layout.preferredHeight: visible ? Units.gu(6) : 0
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.WordWrap
                    text: "No shortcuts yet. Type the short version and it is " +
                          "replaced by the long one."
                    color: "#666666"
                    font.pixelSize: FontUtils.sizeToPixels("medium")
                }

                ListView {
                    id: shortcutsList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    interactive: contentHeight > height

                    model: dictionaryPopup.shortcuts

                    // Same legacy webOS swipe-to-delete as the Words list
                    // above - see its delegate for why this replaced SwipeRow.
                    delegate: Item {
                        id: shortcutRow
                        width: ListView.view.width
                        height: Units.gu(6)

                        property bool pendingDelete: false

                        Item {
                            anchors.fill: parent
                            visible: !shortcutRow.pendingDelete

                            RowLayout {
                                anchors.left: parent.left
                                anchors.leftMargin: Units.gu(1)
                                anchors.right: parent.right
                                anchors.rightMargin: Units.gu(1)
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Units.gu(1)

                                Label {
                                    Layout.preferredWidth: Units.gu(10)
                                    text: modelData.shortcut
                                    elide: Text.ElideRight
                                    font.weight: Font.Bold
                                    font.pixelSize: FontUtils.sizeToPixels("medium")
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.substitution
                                    elide: Text.ElideRight
                                    font.pixelSize: FontUtils.sizeToPixels("medium")
                                }
                            }

                            MouseArea {
                                anchors.fill: parent

                                property real _pressX: 0

                                onPressed: (mouse) => { _pressX = mouse.x; }
                                onReleased: (mouse) => {
                                    if (Math.abs(mouse.x - _pressX) > Units.gu(4))
                                        shortcutRow.pendingDelete = true;
                                }
                            }
                        }

                        Row {
                            anchors.centerIn: parent
                            spacing: Units.gu(2)
                            visible: shortcutRow.pendingDelete

                            Button {
                                text: "Cancel"
                                LuneOSButton.mainColor: LuneOSButton.secondaryColor
                                onClicked: shortcutRow.pendingDelete = false
                            }

                            Button {
                                text: "Delete"
                                LuneOSButton.mainColor: "#be0003"
                                LuneOSButton.textColor: "white"
                                onClicked: {
                                    dictionaryPopup.removeShortcutRequested(modelData._id);
                                    shortcutRow.pendingDelete = false;
                                }
                            }
                        }

                        HorizontalSeparator {
                            anchors.bottom: parent.bottom
                            width: parent.width
                        }
                    }
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Done"
            onClicked: dictionaryPopup.close()
        }
    }
}
