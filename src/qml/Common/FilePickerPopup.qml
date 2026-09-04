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
import QtQuick.Templates 2.4 as T
import QtQuick.Layouts 1.3
import Qt.labs.folderlistmodel 2.1

// Theme specific properties
import QtQuick.Controls.LuneOS 2.0
// Units & font sizes
import LunaNext.Common 0.1

/*
 * Picks a file under /media/internal/downloads - there is no system file
 * picker for QML apps here (WallpaperPickerPopup hits the same gap for
 * pictures), so the directory files actually land in over USB is listed
 * directly, plain rows rather than WallpaperPickerPopup's thumbnail grid
 * since a .ovpn/.pem/.p12 has no useful preview. Shared by every page that
 * needs to point a service at a file it cannot browse to itself - VPN
 * profile/certificate import, the system Certificate Manager's own import.
 */
Popup {
    id: filePicker

    // Every caller of this loads it dynamically via a Loader that itself
    // sits inside another already-open Popup (the profile/certificate
    // import popup) - a Loader-instantiated item's parent is the Loader
    // itself, not the window, and Popup's usual auto-parent-to-the-overlay
    // behaviour on open() never gets a chance to run because a parent is
    // already set by the time open() is called. The Loader reports a 0x0
    // size, so every width/height/x/y binding below silently resolved
    // against that instead of the real window - not visibly "wrong", just
    // invisible (negative size). Overlay.overlay is the standard fix for a
    // dynamically-instantiated Popup: it is always the real window's own
    // overlay item, regardless of how or where this was created.
    parent: T.Overlay.overlay

    property var nameFilters: []
    // One line under the title, e.g. "OpenVPN config (.ovpn)"
    property string hint: ""

    signal fileSelected(string path)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width: Math.min(parent.width - Units.gu(4), Units.gu(50))
    height: Math.min(parent.height - Units.gu(4), Units.gu(60))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    FolderListModel {
        id: folderModel
        folder: "file:///media/internal/downloads"
        nameFilters: filePicker.nameFilters
        showDirs: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        Label {
            Layout.fillWidth: true
            text: "Choose a File"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: FontUtils.sizeToPixels("18pt")
            font.weight: Font.Bold
        }

        Label {
            Layout.fillWidth: true
            visible: filePicker.hint !== ""
            horizontalAlignment: Text.AlignHCenter
            text: filePicker.hint
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("small")
        }

        Label {
            Layout.fillWidth: true
            visible: folderModel.count === 0
            Layout.preferredHeight: visible ? Units.gu(8) : 0
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: "No matching files found. Copy some into " +
                  "/media/internal/downloads over USB and they will show up here."
            color: "#666666"
            font.pixelSize: FontUtils.sizeToPixels("medium")
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: folderModel.count > 0
            clip: true

            model: folderModel

            delegate: ItemDelegate {
                width: ListView.view.width
                height: Units.gu(6)
                text: model.fileName
                font.pixelSize: FontUtils.sizeToPixels("16pt")

                onClicked: {
                    filePicker.fileSelected(model.filePath);
                    filePicker.close();
                }

                HorizontalSeparator {
                    anchors.bottom: parent.bottom
                    width: parent.width
                }
            }

            ScrollIndicator.vertical: ScrollIndicator { }
        }

        Button {
            Layout.fillWidth: true
            text: "Cancel"
            LuneOSButton.mainColor: LuneOSButton.secondaryColor
            onClicked: filePicker.close()
        }
    }
}
