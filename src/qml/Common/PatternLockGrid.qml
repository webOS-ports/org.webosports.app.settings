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
// Units & font sizes
import LunaNext.Common 0.1

/*
 * The Android-style 3x3 pattern grid, for the Pattern lock mode.
 *
 * A single MouseArea covers the whole grid rather than one per dot: the
 * finger only has to pass near a node to select it, the way the real thing
 * behaves, which a per-dot MouseArea (each barely bigger than the dot itself)
 * would not give you.
 *
 * "patternDrawn" only fires for a pattern of at least minimumLength dots -
 * Android's own rule, so a stray tap cannot become a one-dot "pattern" nobody
 * could ever redraw reliably. Anything shorter clears itself and reports
 * "tooShort" instead.
 */
Item {
    id: patternGrid

    property int minimumLength: 4
    // Node colours. The defaults suit the light Settings background; the lock
    // screen passes its own, closer to the dark PadLock chrome.
    property color dotColor: "#9a9a9a"
    property color selectedColor: "#2a7fd4"
    property color errorColor: "#be0003"

    signal patternDrawn(string encoded)
    signal tooShort()

    implicitWidth: Units.gu(36)
    implicitHeight: Units.gu(36)

    readonly property int _columns: 3
    readonly property real _cellSize: Math.min(width, height) / _columns
    readonly property real _nodeRadius: _cellSize * 0.12
    readonly property real _hitRadius: _cellSize * 0.38

    // Indices of the nodes visited so far, in order
    property var _selected: []
    property bool _dragging: false
    property bool _showError: false
    property point _dragPoint: Qt.point(0, 0)

    function _nodeCenter(index) {
        var col = index % _columns;
        var row = Math.floor(index / _columns);
        return Qt.point((col + 0.5) * _cellSize + (width - _cellSize * _columns) / 2,
                        (row + 0.5) * _cellSize + (height - _cellSize * _columns) / 2);
    }

    function _nodeAt(point) {
        for (var i = 0; i < _columns * _columns; i++) {
            var center = _nodeCenter(i);
            var dx = point.x - center.x;
            var dy = point.y - center.y;
            if (Math.sqrt(dx * dx + dy * dy) <= _hitRadius)
                return i;
        }
        return -1;
    }

    // Clears the drawn pattern, so the popup can reuse the same grid for a
    // second draw (the confirm step) or after a mismatch.
    function reset() {
        _selected = [];
        _dragging = false;
        _showError = false;
        canvas.requestPaint();
    }

    function showError() {
        _showError = true;
        canvas.requestPaint();
    }

    MouseArea {
        anchors.fill: parent

        onPressed: (mouse) => {
            patternGrid._showError = false;
            var node = patternGrid._nodeAt(Qt.point(mouse.x, mouse.y));
            patternGrid._selected = node >= 0 ? [node] : [];
            patternGrid._dragging = true;
            patternGrid._dragPoint = Qt.point(mouse.x, mouse.y);
            canvas.requestPaint();
        }

        onPositionChanged: (mouse) => {
            if (!patternGrid._dragging)
                return;

            patternGrid._dragPoint = Qt.point(mouse.x, mouse.y);

            var node = patternGrid._nodeAt(Qt.point(mouse.x, mouse.y));
            if (node >= 0 && patternGrid._selected.indexOf(node) < 0) {
                var updated = patternGrid._selected.slice();
                updated.push(node);
                patternGrid._selected = updated;
            }
            canvas.requestPaint();
        }

        onReleased: {
            patternGrid._dragging = false;

            if (patternGrid._selected.length >= patternGrid.minimumLength)
                patternGrid.patternDrawn(patternGrid._selected.join("-"));
            else if (patternGrid._selected.length > 0)
                patternGrid.tooShort();

            canvas.requestPaint();
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            var lineColor = patternGrid._showError ? patternGrid.errorColor
                                                    : patternGrid.selectedColor;

            // The connecting lines, under the dots.
            if (patternGrid._selected.length > 0) {
                ctx.strokeStyle = lineColor;
                ctx.lineWidth = Units.gu(0.5);
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.beginPath();

                var start = patternGrid._nodeCenter(patternGrid._selected[0]);
                ctx.moveTo(start.x, start.y);
                for (var i = 1; i < patternGrid._selected.length; i++) {
                    var point = patternGrid._nodeCenter(patternGrid._selected[i]);
                    ctx.lineTo(point.x, point.y);
                }
                // Follow the finger to the last node it is passing over.
                if (patternGrid._dragging)
                    ctx.lineTo(patternGrid._dragPoint.x, patternGrid._dragPoint.y);
                ctx.stroke();
            }

            // The nine dots.
            for (var n = 0; n < 9; n++) {
                var center = patternGrid._nodeCenter(n);
                var visited = patternGrid._selected.indexOf(n) >= 0;

                ctx.beginPath();
                ctx.arc(center.x, center.y, patternGrid._nodeRadius, 0, Math.PI * 2);
                ctx.fillStyle = visited ? lineColor : patternGrid.dotColor;
                ctx.fill();

                if (visited) {
                    ctx.beginPath();
                    ctx.arc(center.x, center.y, patternGrid._nodeRadius * 2.2, 0, Math.PI * 2);
                    ctx.strokeStyle = lineColor;
                    ctx.lineWidth = Units.gu(0.15);
                    ctx.stroke();
                }
            }
        }
    }
}
