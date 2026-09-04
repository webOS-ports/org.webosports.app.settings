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

/*
 * The wallpaper grid.
 *
 * The legacy app handed this to the system file picker, which listed what the
 * media indexer had filed under "image". LuneOS has no such picker for QML
 * apps, so the directories wallpapers actually live in are listed directly -
 * the same approach the Sounds & Ringtones page takes for tones: the ones
 * already imported first, then the user's own, then the ones the system
 * shipped.
 */
Popup {
    id: wallpaperPicker

    // Full path of the wallpaper in force, shown ticked
    property string currentPath: ""

    signal wallpaperSelected(string path)

    readonly property var imageFilters: ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.webp"]

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(60))
    height: Math.min(parent.height - Units.gu(4), Units.gu(70))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Wallpapers imported through systemservice end up here, cropped and
    // scaled for the screen.
    FolderListModel {
        id: importedModel
        folder: "file:///media/internal/.wallpapers"
        nameFilters: wallpaperPicker.imageFilters
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
    FolderListModel {
        id: userModel
        folder: "file:///media/internal/wallpapers"
        nameFilters: wallpaperPicker.imageFilters
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
    FolderListModel {
        id: systemModel
        folder: "file:///usr/share/wallpapers"
        nameFilters: wallpaperPicker.imageFilters
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    readonly property var sections: [
        { "title": "My wallpapers", "files": importedModel },
        { "title": "Pictures",      "files": userModel },
        { "title": "System",        "files": systemModel }
    ]

    readonly property bool anyWallpapers:
        importedModel.count > 0 || userModel.count > 0 || systemModel.count > 0

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "Wallpaper"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        Label {
            Layout.fillWidth: true
            visible: !wallpaperPicker.anyWallpapers
            Layout.preferredHeight: visible ? Units.gu(8) : 0
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "No pictures found. Copy some into /media/internal/wallpapers " +
                  "over USB and they will show up here."
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        Flickable {
            id: sectionsFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: sectionsColumn.height
            flickableDirection: Flickable.AutoFlickIfNeeded
            clip: true

            Column {
                id: sectionsColumn
                width: sectionsFlickable.width
                spacing: Units.gu(1)

                Repeater {
                    model: wallpaperPicker.sections

                    delegate: Column {
                        id: section

                        readonly property string sectionTitle: modelData.title
                        readonly property var sectionFiles: modelData.files

                        width: sectionsColumn.width
                        spacing: Units.gu(0.5)
                        visible: sectionFiles.count > 0

                        Label {
                            width: parent.width
                            text: section.sectionTitle
                            color: "#666666"
                            font.pixelSize: FontUtils.sizeToPixels("14pt")
                        }

                        Grid {
                            width: parent.width
                            spacing: Units.gu(1)
                            // As many thumbnails as fit, so a phone gets two
                            // and a tablet four without a second layout.
                            columns: Math.max(2, Math.floor(width / Units.gu(16)))

                            Repeater {
                                model: section.sectionFiles

                                delegate: Item {
                                    // "required property" auto-wiring from a
                                    // model role only fires when the Repeater
                                    // is bound to the model directly; here the
                                    // model comes from section.sectionFiles,
                                    // itself a property on an already-dynamic
                                    // (outer-Repeater) delegate, and that
                                    // extra indirection left fileURL/filePath
                                    // unresolved ("Required property fileURL
                                    // was not initialized") even though the
                                    // FolderListModel had real rows. Reading
                                    // the roles off the implicit "model"
                                    // context property instead sidesteps it.
                                    width: (section.width - (parent.columns - 1) * Units.gu(1))
                                           / parent.columns
                                    height: width * 3 / 4

                                    Image {
                                        anchors.fill: parent
                                        source: model.fileURL
                                        fillMode: Image.PreserveAspectCrop
                                        clip: true
                                        asynchronous: true
                                        // Thumbnails, not full-screen images:
                                        // decoding a dozen 12-megapixel photos
                                        // at full size would eat the device.
                                        sourceSize.width: Units.gu(24)
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: "transparent"
                                        border.width: model.filePath === wallpaperPicker.currentPath
                                                      ? Units.gu(0.4) : 1
                                        border.color: model.filePath === wallpaperPicker.currentPath
                                                      ? "#2a7fd4" : "#909090"
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            wallpaperPicker.wallpaperSelected(model.filePath);
                                            wallpaperPicker.close();
                                        }
                                    }
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
            onClicked: wallpaperPicker.close()
        }
    }
}
