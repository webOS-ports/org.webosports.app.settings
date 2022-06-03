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

// LS2 access
import LuneOS.Service 1.0

Page {
    id: basePage

    // this is exposed by the page loader
    Component.onCompleted: actionHeaderComponent=pageActionHeaderComponent;
    property Component pageActionHeaderComponent

    background: Rectangle {
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#D8D8D8" }
            GradientStop { position: 1.0; color: "#888" }
        }
    }

    // Convenience LS2 services & functions
    property LunaService luna: LunaService {
        name: appId
    }

    function _handleGetError(message) {
        console.warn("ERROR: Failed to get setting: " + message);
    }
    function _handleSetSuccess(message) {
    }
    function _handleSetError(message) {
        console.warn("ERROR: Failed to set setting: " + message);
    }
}
