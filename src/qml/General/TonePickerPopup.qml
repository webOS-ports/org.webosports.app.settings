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
import Qt.labs.folderlistmodel 2.1

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

import "../Common"

/*
 * The tone list, shared by the ringtone, the alert tone and the notification
 * tone: all three are picked from the same two directories.
 *
 * The legacy app handed this over to the system file picker, which listed what
 * the media indexer had filed under "ringtone". LuneOS has no such picker for
 * QML apps, so the directories the sounds actually live in are listed
 * directly: the ones the user copied over USB first, the system ones below.
 */
Popup {
    id: tonePicker

    // Which preference the pick is for, so the page knows what to write
    property string target
    property string title: "Ringtone"
    property string currentPath

    signal toneSelected(string target, string name, string path)

    readonly property var audioFilters: ["*.mp3", "*.wav", "*.ogg", "*.m4a", "*.aac", "*.flac", "*.wma"]

    FolderListModel {
        id: userRingtonesModel
        folder: "file:///media/internal/ringtones"
        nameFilters: tonePicker.audioFilters
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
    FolderListModel {
        id: systemSoundsModel
        folder: "file:///usr/palm/sounds"
        nameFilters: tonePicker.audioFilters
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    readonly property var sections: [
        { "title": "My ringtones", "files": userRingtonesModel },
        { "title": "System sounds", "files": systemSoundsModel }
    ]

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(45))
    height: Math.min(parent.height - Units.gu(4), Units.gu(60))
    // Overlay.overlay only arrived in Controls 2.3; the app builds against 2.2.
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: tonePicker.title
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        Label {
            Layout.fillWidth: true
            visible: userRingtonesModel.count === 0 && systemSoundsModel.count === 0
            Layout.preferredHeight: Units.gu(6)
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            text: "No sounds found"
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        Flickable {
            id: foldersFlickable

            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: foldersColumn.height
            flickableDirection: Flickable.AutoFlickIfNeeded
            clip: true

            Column {
                id: foldersColumn
                width: foldersFlickable.width

                Repeater {
                    model: tonePicker.sections

                    delegate: Column {
                        id: folderSection

                        readonly property string sectionTitle: modelData.title
                        readonly property var sectionFiles: modelData.files

                        width: foldersColumn.width

                        Label {
                            width: parent.width
                            visible: folderSection.sectionFiles.count > 0
                            height: visible ? Units.gu(4) : 0
                            verticalAlignment: Text.AlignVCenter
                            text: folderSection.sectionTitle
                            color: "#666666"
                            font.pixelSize: FontUtils.sizeToPixels("14pt")
                        }

                        Repeater {
                            model: folderSection.sectionFiles

                            delegate: ItemDelegate {
                                width: folderSection.width
                                height: Units.gu(6)

                                RowLayout {
                                    anchors.fill: parent

                                    Label {
                                        Layout.fillWidth: true
                                        text: fileBaseName
                                        elide: Text.ElideRight
                                        font.bold: filePath === tonePicker.currentPath
                                        font.pixelSize: FontUtils.sizeToPixels("medium")
                                    }
                                    Image {
                                        source: "../images/wifi/checkmark.png"
                                        visible: filePath === tonePicker.currentPath

                                        fillMode: Image.PreserveAspectFit
                                        verticalAlignment: Image.AlignVCenter
                                        horizontalAlignment: Image.AlignHCenter
                                        Layout.preferredHeight: Units.gu(3.2)
                                        Layout.preferredWidth: Units.gu(3.2)
                                    }
                                }

                                HorizontalSeparator {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                }

                                onClicked: {
                                    // The preference keeps the file name with
                                    // its extension, the way the shipped
                                    // default ringtone.mp3 does.
                                    tonePicker.toneSelected(tonePicker.target, fileName, filePath);
                                    tonePicker.close();
                                }
                            }
                        }
                    }
                }
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Cancel"
            onClicked: tonePicker.close()
        }
    }
}
