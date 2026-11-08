/*
 * (c) 2026 Alan Morford <alan-morford@users.noreply.github.com>
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
import LuneOS.Forms 1.0

/*
 * The Pre Keyboard's own words: the ones added by holding them in its
 * suggestion bar, or kept by tapping them as typed there. Autocorrect leaves
 * them alone and swiping can spell them; a word taken out is corrected again.
 *
 * Kept per language family, as the keyboard keeps them (the Englishes share
 * theirs): a tab for each family of the languages checked. Same look as the
 * LuneOS keyboard's dictionary beside it: a row to add, a swipe to take one away.
 *
 * The page owns the storage (the keyboard preference's "pre" object); this
 * only shows what it is given and says what was asked for.
 */
Popup {
    id: preDictionaryPopup

    // { "en": ["luneos", ...], "fr": [...] }
    property var learned: ({})
    // The families to show, in order: ["en", "fr"]
    property var families: ["en"]

    signal addWordRequested(string family, string word)
    signal removeWordRequested(string family, string word)

    readonly property string family: families.length > 0
                                     ? families[Math.min(tabBar.currentIndex, families.length - 1)] : "en"
    readonly property var words: learned[family] || []

    function familyName(f) {
        switch (f) {
        case "en": return "English";
        case "fr": return "Français";
        case "de": return "Deutsch";
        case "es": return "Español";
        case "it": return "Italiano";
        }
        return f;
    }

    //! Letters only, and an apostrophe: what the keyboard can take as a word.
    function isWord(w) {
        // Any letters, in any script, and the apostrophe; no spaces, digits or
        // other ASCII punctuation, and not starting with the apostrophe.
        return w.length > 0 && w[0] !== "'" && /^[^\s\d!-&(-\/:-@[-`{-~]+$/.test(w);
    }

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape

    width: Math.min(parent.width - Units.gu(4), Units.gu(50))
    // keyboardTop: the window's height, or where the on-screen keys start
    height: Math.min(keyboardTop - Units.gu(4), Units.gu(70))

    onOpened: newWordField.text = ""

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "Pre Keyboard Dictionary"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        TabBar {
            id: tabBar
            Layout.fillWidth: true
            visible: preDictionaryPopup.families.length > 1

            Repeater {
                model: preDictionaryPopup.families
                TabButton { text: preDictionaryPopup.familyName(modelData) }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Units.gu(1)

            TextField {
                id: newWordField
                Layout.fillWidth: true
                Layout.preferredHeight: Units.gu(5)
                placeholderText: "Add a word"
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase

                onAccepted: addWordButton.clicked()
            }
            Button {
                id: addWordButton
                text: "Add"
                enabled: preDictionaryPopup.isWord(newWordField.text.trim())
                LuneOSButton.mainColor: LuneOSButton.affirmativeColor
                onClicked: {
                    preDictionaryPopup.addWordRequested(preDictionaryPopup.family, newWordField.text.trim());
                    newWordField.text = "";
                }
            }
        }

        Label {
            Layout.fillWidth: true
            visible: preDictionaryPopup.words.length === 0
            Layout.preferredHeight: visible ? Units.gu(6) : 0
            verticalAlignment: Text.AlignVCenter
            wrapMode: Text.WordWrap
            text: "No words yet. Hold a word in the keyboard's suggestion bar to add it."
            color: Colors.secondaryText
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            interactive: contentHeight > height

            model: preDictionaryPopup.words

            // Swipe sideways to ask for delete confirmation, as in the
            // LuneOS keyboard's dictionary.
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
                        text: modelData
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
                        LuneOSButton.mainColor: LuneOSButton.negativeColor
                        LuneOSButton.textColor: "white"
                        onClicked: {
                            preDictionaryPopup.removeWordRequested(preDictionaryPopup.family, modelData);
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

        Button {
            Layout.fillWidth: true
            text: "Done"
            onClicked: preDictionaryPopup.close()
        }
    }
}
