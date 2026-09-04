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
// Units & font sizes
import LunaNext.Common 0.1

/*
 * The webOS time picker: an hour wheel, a minute wheel, and an AM/PM wheel
 * that disappears when the device is set to 24 hour time - the legacy picker
 * took the same is24HrMode flag off the Time Format row above it.
 *
 * Same contract as DatePicker: "edited" is the user, writing "value" is not.
 */
Item {
    id: timePicker

    property alias label: pickerLabel.text
    property bool is24Hour: false

    property date value: new Date()

    signal edited(date value)

    height: Math.max(pickerLabel.height, wheels.implicitHeight)

    /*
     * Guards the wheels while they are being positioned from "value", so
     * moving them in code does not read back as a user edit.
     *
     * A Tumbler settles its currentIndex over several frames after its model
     * and delegates are built, so the guard cannot simply be dropped at the end
     * of the assignment: the index changes that matter arrive well after it.
     * It is lifted on a timer instead, once the wheels have stopped moving on
     * their own. Without this the page set the device clock while it was still
     * drawing itself.
     */
    property bool _settingUp: true

    Timer {
        id: armTimer
        interval: 400
        onTriggered: timePicker._settingUp = false
    }

    onValueChanged: _syncFromValue()
    onIs24HourChanged: _syncFromValue()
    Component.onCompleted: _syncFromValue()

    function _syncFromValue() {
        _settingUp = true;
        armTimer.restart();

        var hours = value.getHours();
        if (is24Hour) {
            hourWheel.currentIndex = hours;
        } else {
            // 0 and 12 o'clock are both shown as 12
            hourWheel.currentIndex = (hours % 12 === 0) ? 11 : (hours % 12) - 1;
            meridiemWheel.currentIndex = hours < 12 ? 0 : 1;
        }
        minuteWheel.currentIndex = value.getMinutes();
    }

    function _wheelsMoved() {
        if (_settingUp)
            return;

        var hours;
        if (is24Hour) {
            hours = hourWheel.currentIndex;
        } else {
            hours = (hourWheel.currentIndex + 1) % 12;
            if (meridiemWheel.currentIndex === 1)
                hours += 12;
        }

        var newTime = new Date(value);
        newTime.setHours(hours, minuteWheel.currentIndex, 0, 0);

        value = newTime;
        timePicker.edited(newTime);
    }

    function _twoDigits(number) {
        return number < 10 ? "0" + number : "" + number;
    }

    Label {
        id: pickerLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }

    RowLayout {
        id: wheels
        anchors.right: parent.right
        spacing: Units.gu(0.5)

        Tumbler {
            id: hourWheel
            Layout.preferredWidth: Units.gu(7)
            Layout.preferredHeight: Units.gu(16)
            visibleItemCount: 3
            model: timePicker.is24Hour ? 24 : 12
            delegate: Text {
                text: timePicker.is24Hour ? timePicker._twoDigits(modelData) : (modelData + 1)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font: hourWheel.font
                opacity: 1.0 - Math.abs(Tumbler.displacement) / (hourWheel.visibleItemCount / 2)
            }
            onCurrentIndexChanged: timePicker._wheelsMoved()
        }
        Tumbler {
            id: minuteWheel
            Layout.preferredWidth: Units.gu(7)
            Layout.preferredHeight: Units.gu(16)
            visibleItemCount: 3
            model: 60
            delegate: Text {
                text: timePicker._twoDigits(modelData)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font: minuteWheel.font
                opacity: 1.0 - Math.abs(Tumbler.displacement) / (minuteWheel.visibleItemCount / 2)
            }
            onCurrentIndexChanged: timePicker._wheelsMoved()
        }
        Tumbler {
            id: meridiemWheel
            visible: !timePicker.is24Hour
            Layout.preferredWidth: visible ? Units.gu(7) : 0
            Layout.preferredHeight: Units.gu(16)
            visibleItemCount: 3
            wrap: false
            model: ["AM", "PM"]
            onCurrentIndexChanged: timePicker._wheelsMoved()
        }
    }
}
