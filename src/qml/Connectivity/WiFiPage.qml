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

import "../Common"

import MeeGo.Connman 0.2

BasePage {
    TechnologyModel {
        id: wifiModel
        name: "wifi"
    }

    Column {
        width: parent.width

        ListView {
            width: parent.width
            height: 100
            model: wifiModel

            delegate: Item {
                property NetworkService delegateService: modelData

                width: parent.width
                height: 50
                CheckDelegate {
                    anchors.fill: parent
                    text: delegateService.name
                }
            }
        }
    }
}
