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

/*
 * The camera half of the QR scanner, kept in its own file on purpose: it is
 * loaded through a Loader, so if QtMultimedia is missing or a type here does
 * not resolve, only this fails - the profile list and the download form stay
 * usable. Putting the camera inline cost exactly that once already.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import QtMultimedia
import LuneOS.Camera 1.0

import LunaNext.Common 0.1

Item {
    id: scannerRoot

    // The page turns this on only while its tab is showing; holding the camera
    // open in the background would keep it from every other app.
    property bool active: false
    property string status: ""

    signal cameraFailed(string message)

    // Hands the current preview frame to the caller as a file it can decode.
    function grabFrame(path, onDone) {
        if (!previewId.visible) {
            onDone(false);
            return;
        }

        previewId.grabToImage(function (result) {
            onDone(result.saveToFile(path));
        });
    }

    /*
     * QtMultimedia cannot find the camera by itself here: it enumerates V4L2,
     * and on a Halium device the camera only exists behind gst-droid. So
     * rather than a Camera element - which would bind to no device and show
     * nothing - the source comes from LuneOS.Camera and is assigned to
     * nativeVideoSource, the same way the Camera app does it.
     */
    CaptureSession {
        id: captureSessionId
        videoOutput: previewId
    }

    function _attachCamera() {
        if (!DroidCameraFactory.available) {
            scannerRoot.status = "no camera was found on this device";
            scannerRoot.cameraFailed(scannerRoot.status);
            return;
        }

        if (captureSessionId.nativeVideoSource)
            return;

        var source = DroidCameraFactory.createVideoSource(0);

        if (!source) {
            scannerRoot.status = "the camera could not be started";
            scannerRoot.cameraFailed(scannerRoot.status);
            return;
        }

        // Same order the Camera app uses: clear any QCamera the session might
        // hold, hand it the droid source, then start it. A
        // QGStreamerVideoSource is created inactive, so without the start()
        // the pipeline never leaves PAUSED and the preview stays black with
        // nothing in the log to say why.
        captureSessionId.camera = null;
        captureSessionId.nativeVideoSource = source;
        source.start();
        console.info("EsimQrScanner: source started, active=" + source.active
                     + " output=" + previewId.width + "x" + previewId.height);
    }

    function _detachCamera() {
        // Let go of the camera as soon as the tab is left; a camera left open
        // is one no other application can have.
        if (captureSessionId.nativeVideoSource) {
            captureSessionId.nativeVideoSource.stop();
            captureSessionId.nativeVideoSource = null;
        }
    }

    onActiveChanged: {
        if (active)
            _attachCamera();
        else
            _detachCamera();
    }

    Component.onDestruction: _detachCamera()

    ColumnLayout {
        anchors.fill: parent
        spacing: Units.gu(1)

        VideoOutput {
            id: previewId
            Layout.fillWidth: true
            Layout.fillHeight: true
            fillMode: VideoOutput.PreserveAspectCrop

            /*
             * The frames handed to the decoder are grabs of this item, so what
             * is on screen is exactly what zbar sees - and zbar will not read a
             * code whose quiet zone has been cropped away. The guide says where
             * the edges have to be; without it people fill the screen with the
             * code, which is the one framing that cannot work.
             */
            Rectangle {
                id: aimGuideId
                anchors.centerIn: parent
                width: Math.round(Math.min(parent.width, parent.height) * 0.72)
                height: width
                color: "transparent"
                border.color: "#ffffff"
                border.width: Units.gu(0.2)
                opacity: 0.75
                radius: Units.gu(0.5)
            }

            Label {
                anchors.horizontalCenter: aimGuideId.horizontalCenter
                anchors.top: aimGuideId.bottom
                anchors.topMargin: Units.gu(1)
                text: "Fit the whole code inside the square"
                color: "#ffffff"
                style: Text.Outline
                styleColor: "#000000"
                font.pixelSize: FontUtils.sizeToPixels("small")
            }
        }
    }
}
