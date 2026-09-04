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

/*
 * Pick one entry out of a long list, with a search box above it - the shape
 * the Mojo settings apps used for languages, regions and keyboards alike.
 *
 * Entries are { key, label, sublabel, note }: "label" is the line you read,
 * "sublabel" the greyed line under it, "note" the value on the right. Only
 * key and label are required.
 *
 * The search box appears once the list is long enough to be worth searching;
 * a list of eight keyboards does not need one.
 */
Popup {
    id: listPicker

    property string title: ""
    property var entries: []
    property string currentKey: ""
    // The message shown in place of the list when there is nothing in it
    property string emptyText: "Nothing to choose from"
    property int searchThreshold: 12

    signal picked(string key, var entry)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(46))
    height: Math.min(parent.height - Units.gu(4), Units.gu(70))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    onOpened: searchField.text = ""

    readonly property bool searchable: entries.length >= searchThreshold

    readonly property var visibleEntries: {
        var filter = searchField.text.toLowerCase().trim();
        if (filter === "" || !searchable)
            return entries;

        var matches = [];
        for (var i = 0; i < entries.length; i++) {
            var entry = entries[i];
            if ((entry.label || "").toLowerCase().indexOf(filter) >= 0 ||
                (entry.sublabel || "").toLowerCase().indexOf(filter) >= 0)
                matches.push(entry);
        }
        return matches;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            visible: listPicker.title !== ""
            text: listPicker.title
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.preferredHeight: Units.gu(5)
            visible: listPicker.searchable
            placeholderText: "Search"
            inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
        }

        Label {
            Layout.fillWidth: true
            visible: listPicker.visibleEntries.length === 0
            Layout.preferredHeight: visible ? Units.gu(6) : 0
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: listPicker.entries.length === 0 ? listPicker.emptyText : "No match"
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            model: listPicker.visibleEntries

            delegate: ItemDelegate {
                width: ListView.view.width
                height: modelData.sublabel ? Units.gu(8) : Units.gu(6)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Units.gu(1)
                    anchors.rightMargin: Units.gu(1)
                    spacing: Units.gu(1)

                    Column {
                        Layout.fillWidth: true

                        Label {
                            width: parent.width
                            text: modelData.label
                            elide: Text.ElideRight
                            font.bold: modelData.key === listPicker.currentKey
                            font.pixelSize: FontUtils.sizeToPixels("medium")
                        }
                        Label {
                            width: parent.width
                            visible: !!modelData.sublabel
                            height: visible ? implicitHeight : 0
                            text: modelData.sublabel ? modelData.sublabel : ""
                            elide: Text.ElideRight
                            color: "#666666"
                            font.pixelSize: FontUtils.sizeToPixels("small")
                        }
                    }

                    Label {
                        visible: !!modelData.note
                        text: modelData.note ? modelData.note : ""
                        color: "#666666"
                        font.pixelSize: FontUtils.sizeToPixels("small")
                    }
                }

                HorizontalSeparator {
                    anchors.bottom: parent.bottom
                    width: parent.width
                }

                onClicked: {
                    listPicker.picked(modelData.key, modelData);
                    listPicker.close();
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Cancel"
            onClicked: listPicker.close()
        }
    }
}
