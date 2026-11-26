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
 * The camera half of "Scan QR code" on the Wi-Fi page. Loaded through a
 * Loader by WiFiScanQrPopup for the same reason as EsimQrScanner: if
 * QtMultimedia or LuneOS.Camera is missing, only this fails and the page
 * stays usable.
 *
 * Unlike the eSIM scanner this decodes the viewfinder itself, with
 * LuneOS.Camera's BarcodeScanner reading the frames the VideoOutput is shown
 * anyway - no grabbed PNGs, no round trip over the bus.
 */

import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3

import QtMultimedia
import LuneOS.Camera 1.0

import LunaNext.Common 0.1

Item {
    id: scannerRoot

    // The popup turns this on only while it is showing; a camera held open
    // in the background is one no other application can have.
    property bool active: false

    // A QR code came into view: its text, whatever it is. The popup decides
    // whether it is a Wi-Fi network.
    signal codeRead(string text)
    signal cameraFailed(string message)

    readonly property bool useDroidCamera: DroidCameraFactory.available

    MediaDevices {
        id: mediaDevices
    }

    /*
     * Where the camera is not behind gst-droid (a PinePhone, the emulator),
     * QtMultimedia finds it itself. Created only on that path: an unused
     * Camera would still enumerate and probe the devices.
     */
    Component {
        id: plainCameraComponent
        Camera {
            cameraDevice: mediaDevices.defaultVideoInput
        }
    }

    CaptureSession {
        id: captureSessionId
        videoOutput: previewId
    }

    /*
     * On a Halium device the camera only exists behind gst-droid, so the
     * source comes from LuneOS.Camera and goes into nativeVideoSource, as in
     * the Camera app and EsimQrScanner.
     */
    function _attachCamera() {
        if (useDroidCamera) {
            if (captureSessionId.nativeVideoSource)
                return;
            var source = DroidCameraFactory.createVideoSource(0);
            if (!source) {
                scannerRoot.cameraFailed("The camera could not be started.");
                return;
            }
            // A QGStreamerVideoSource starts out inactive: without start()
            // the pipeline stays PAUSED and the preview black.
            captureSessionId.camera = null;
            captureSessionId.nativeVideoSource = source;
            source.start();
            return;
        }

        if (captureSessionId.camera)
            return;
        if (mediaDevices.videoInputs.length === 0) {
            scannerRoot.cameraFailed("No camera was found on this device.");
            return;
        }
        var camera = plainCameraComponent.createObject(scannerRoot);
        if (!camera) {
            scannerRoot.cameraFailed("The camera could not be started.");
            return;
        }
        captureSessionId.camera = camera;
        camera.start();
    }

    function _detachCamera() {
        if (captureSessionId.nativeVideoSource) {
            captureSessionId.nativeVideoSource.stop();
            captureSessionId.nativeVideoSource = null;
        }
        if (captureSessionId.camera) {
            var camera = captureSessionId.camera;
            captureSessionId.camera = null;
            camera.stop();
            camera.destroy();
        }
    }

    onActiveChanged: {
        if (active)
            _attachCamera();
        else
            _detachCamera();
    }

    Component.onCompleted: if (active) _attachCamera()
    Component.onDestruction: _detachCamera()

    BarcodeScanner {
        videoSink: previewId.videoSink
        active: scannerRoot.active
        // QR codes only: a Wi-Fi code is never a product barcode, and a
        // linear code read off a box in the background is just noise here.
        onDecoded: (text, format) => {
            if (format === "QR-Code")
                scannerRoot.codeRead(text);
        }
    }

    VideoOutput {
        id: previewId
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop

        /*
         * What is in the square is what the scanner looks at hardest; a code
         * filling the whole screen loses its quiet zone off the edges and
         * will not read.
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
    }
}
