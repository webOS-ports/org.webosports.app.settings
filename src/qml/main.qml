/*
 * (c) 2013 Simon Busch <morphis@gravedo.de>
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

ApplicationWindow {
    id: window

    width: 320
    height: 480
    visible: true

    function pushPage(page) {
        pageStack.push(page);
    }

    Component.onCompleted: {
        pageStack.push(Qt.resolvedUrl("MainPage.qml"));
    }

    StackView {
        id: pageStack
        anchors.fill: parent
    }
}
