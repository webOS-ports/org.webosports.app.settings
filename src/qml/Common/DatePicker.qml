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
 * The three spinning wheels the webOS date picker was made of, rebuilt on
 * Tumbler. Qt Quick Controls has no date picker of its own, and a set of wheels
 * is what the original looked like anyway.
 *
 * The month/day/year order follows the locale, so a device set to a European
 * region spins day before month the way the legacy picker did.
 *
 * "edited" only fires for a spin the user made. Writing "value" from the
 * outside moves the wheels silently, which is what keeps a clock ticking in
 * from the service from being echoed straight back at it.
 */
Item {
    id: datePicker

    property alias label: pickerLabel.text
    property int minimumYear: 1970
    property int maximumYear: 2037

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
        onTriggered: datePicker._settingUp = false
    }

    onValueChanged: _syncFromValue()
    Component.onCompleted: _syncFromValue()

    readonly property var monthNames: [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    // Locale.ShortFormat is "d/M/yy" or "M/d/yy" depending on where the device
    // thinks it is; the first of d or M decides which wheel comes first.
    readonly property bool dayBeforeMonth: {
        var format = Qt.locale().dateFormat(Locale.ShortFormat);
        var dayAt = format.indexOf("d");
        var monthAt = format.indexOf("M");
        return dayAt >= 0 && (monthAt < 0 || dayAt < monthAt);
    }

    readonly property int daysInSelectedMonth:
        new Date(minimumYear + yearWheel.currentIndex, monthWheel.currentIndex + 1, 0).getDate()

    function _syncFromValue() {
        _settingUp = true;
        armTimer.restart();
        yearWheel.currentIndex = Math.max(0, Math.min(maximumYear - minimumYear,
                                                      value.getFullYear() - minimumYear));
        monthWheel.currentIndex = value.getMonth();
        dayWheel.currentIndex = value.getDate() - 1;
    }

    function _wheelsMoved() {
        if (_settingUp)
            return;

        // A day that no longer exists (31 February) snaps back to the last of
        // the month rather than rolling over into the next one.
        var day = Math.min(dayWheel.currentIndex + 1, daysInSelectedMonth);
        var newDate = new Date(value);
        newDate.setFullYear(minimumYear + yearWheel.currentIndex,
                            monthWheel.currentIndex, day);

        value = newDate;
        datePicker.edited(newDate);
    }

    Label {
        id: pickerLabel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        font.pixelSize: FontUtils.sizeToPixels("16pt")
    }

    GridLayout {
        id: wheels
        anchors.right: parent.right
        rows: 1
        columnSpacing: Units.gu(0.5)

        Tumbler {
            id: monthWheel
            Layout.column: datePicker.dayBeforeMonth ? 1 : 0
            Layout.preferredWidth: Units.gu(14)
            Layout.preferredHeight: Units.gu(16)
            visibleItemCount: 3
            model: datePicker.monthNames
            onCurrentIndexChanged: datePicker._wheelsMoved()
        }
        Tumbler {
            id: dayWheel
            Layout.column: datePicker.dayBeforeMonth ? 0 : 1
            Layout.preferredWidth: Units.gu(7)
            Layout.preferredHeight: Units.gu(16)
            visibleItemCount: 3
            model: datePicker.daysInSelectedMonth
            delegate: Text {
                text: modelData + 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font: dayWheel.font
                opacity: 1.0 - Math.abs(Tumbler.displacement) / (dayWheel.visibleItemCount / 2)
            }
            onCurrentIndexChanged: datePicker._wheelsMoved()
        }
        Tumbler {
            id: yearWheel
            Layout.column: 2
            Layout.preferredWidth: Units.gu(9)
            Layout.preferredHeight: Units.gu(16)
            visibleItemCount: 3
            model: datePicker.maximumYear - datePicker.minimumYear + 1
            delegate: Text {
                text: datePicker.minimumYear + modelData
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font: yearWheel.font
                opacity: 1.0 - Math.abs(Tumbler.displacement) / (yearWheel.visibleItemCount / 2)
            }
            onCurrentIndexChanged: datePicker._wheelsMoved()
        }
    }
}
