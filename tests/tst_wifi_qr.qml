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

import QtQuick
import QtQuick.Controls.LuneOS
import QtTest
import Connman 0.2

import "../src/qml/Connectivity"

/*
 * Wi-Fi QR codes on the Wi-Fi and hotspot pages (WiFiQrSupport): joining
 * from a scanned code, connman's agent answered from it once, and sharing a
 * saved network after the passcode. Against luneos-components' Connman
 * stand-in for the list; the luna services (com.webos.service.auth, the
 * wifi service's getPassphrase) and the agent are stand-ins here, which
 * answer as the real ones do and remember what they were asked. The camera
 * is not involved: codes go in where the scanner would hand them over.
 * Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    Component {
        id: wifiPageComponent
        WiFiPage { anchors.fill: parent }
    }

    Component {
        id: tetheringPageComponent
        TetheringPage { anchors.fill: parent }
    }

    // UserAgent's one slot the support uses.
    QtObject {
        id: fakeAgent
        property var replies: []
        function sendUserReply(reply) { replies.push(reply); }
    }

    // com.webos.service.auth and com.webos.service.wifi/getPassphrase.
    QtObject {
        id: fakeLuna
        property var calls: []
        property string lockMode: "pin"
        property string goodPasscode: "1234"
        property var passphraseReply: ({ "returnValue": true, "ssid": "My Own Wifi",
                                         "security": "psk", "passphrase": "pass;word1",
                                         "hidden": false })

        function reply(fields) { return { "payload": JSON.stringify(fields) }; }

        function call(uri, args, onReply, onError) {
            var request = JSON.parse(args);
            calls.push({ "uri": uri, "request": request });
            if (uri === "luna://com.webos.service.auth/getDeviceLockMode")
                onReply(reply({ "returnValue": true, "lockMode": lockMode }));
            else if (uri === "luna://com.webos.service.auth/matchDevicePasscode")
                onReply(reply(request.passCode === goodPasscode
                              ? { "returnValue": true, "unlockToken": "tok-1", "tokenLifetime": 30 }
                              : { "returnValue": false, "retriesLeft": 4 }));
            else if (uri === "luna://com.webos.service.wifi/getPassphrase")
                onReply(reply(passphraseReply));
            else
                onError("unrecognized call: " + uri);
        }

        function called(uri) {
            for (var i = 0; i < calls.length; ++i)
                if (calls[i].uri === uri)
                    return calls[i];
            return null;
        }
    }

    // A list with a hidden network in it, which the Connman stand-in has not.
    Component {
        id: fakeServiceComponent
        QtObject {
            property string name: ""
            property string path: ""
            property bool hidden: false
            property bool connected: false
            property bool saved: false
            property bool favorite: false
            property int securityType: NetworkService.SecurityPSK
            property int connects: 0
            function requestConnect() { connects++; }
        }
    }
    Component {
        id: fakeModelComponent
        QtObject {
            property var services: []
            property int count: services.length
            property bool powered: true
            property int scans: 0
            function get(i) { return services[i]; }
            function requestScan() { scans++; }
        }
    }

    SignalSpy {
        id: connectSpy
        signalName: "serviceConnectionStarted"
    }

    TestCase {
        name: "WiFiQr"
        when: windowShown

        property var page: null
        property var qr: null
        property var realAgent: null

        function init() {
            page = createTemporaryObject(wifiPageComponent, root);
            verify(page !== null, "the page did not load");
            qr = findChild(page, "wifiQr");
            verify(qr !== null);
            realAgent = qr.agent;
            verify(realAgent !== null);
            fakeAgent.replies = [];
            fakeLuna.calls = [];
            fakeLuna.lockMode = "pin";
            qr.agent = fakeAgent;
            qr.luna = fakeLuna;
            connectSpy.clear();
            var list = findChild(page, "wifiList");
            tryVerify(function () { return list.count >= 3; }, 2000);
        }

        function serviceNamed(name) {
            for (var i = 0; i < qr.wifiModel.count; ++i) {
                var s = qr.wifiModel.get(i);
                if (s && s.name === name)
                    return s;
            }
            return null;
        }

        // --- joining --------------------------------------------------------

        function test_aScannedCodeConnectsItsNetwork() {
            var service = serviceNamed("Someone else's wifi");
            verify(service && !service.connected);
            connectSpy.target = service;

            qr.joinCode("WIFI:S:Someone else\\'s wifi;T:WEP;P:abcde;;");
            compare(connectSpy.count, 1, "the network was not connected");
            compare(qr.pendingAnswer.path, service.path);
            compare(qr.pendingJoin, null);
        }

        // connman asks the agent: the code answers, once, WPS offered or not.
        function test_theAgentIsAnsweredFromTheCodeOnce() {
            var service = serviceNamed("Someone else's wifi");
            qr.joinCode("WIFI:S:Someone else's wifi;T:WEP;P:abcde;;");

            var fields = { "Passphrase": { "Type": "wep", "Requirement": "mandatory" },
                           "WPS": { "Type": "wpspin", "Requirement": "alternate" } };
            verify(qr.answerUserInput(service.path, fields));
            compare(fakeAgent.replies.length, 1);
            compare(fakeAgent.replies[0], { "Passphrase": "abcde" });

            // Asked again: the code's passphrase was wrong; the popup's turn.
            verify(!qr.answerUserInput(service.path, fields));
            compare(fakeAgent.replies.length, 1);
        }

        function test_anotherNetworksRequestIsNotAnswered() {
            qr.joinCode("WIFI:S:Someone else's wifi;T:WEP;P:abcde;;");
            verify(!qr.answerUserInput("/net/connman/service/other",
                                       { "Passphrase": { "Requirement": "mandatory" } }));
            compare(fakeAgent.replies.length, 0);
        }

        // An identity is nothing a code holds: leave it to the popup.
        function test_aMandatoryFieldTheCodeLacksGoesToThePopup() {
            var service = serviceNamed("Someone else's wifi");
            qr.joinCode("WIFI:S:Someone else's wifi;T:WEP;P:abcde;;");
            verify(!qr.answerUserInput(service.path, {
                "Identity": { "Requirement": "mandatory" },
                "Passphrase": { "Requirement": "mandatory" } }));
            compare(fakeAgent.replies.length, 0);
        }

        // Through the page's own UserAgent: the code answers and no passphrase
        // popup comes up; asked again, the popup does.
        function test_thePagesAgentGoesToTheCodeFirst() {
            var service = serviceNamed("Someone else's wifi");
            var loader = findChild(page, "wifiPopupLoader");
            verify(loader !== null);
            qr.joinCode("WIFI:S:Someone else's wifi;T:WEP;P:abcde;;");

            var fields = { "Passphrase": { "Type": "wep", "Requirement": "mandatory" } };
            realAgent.userInputRequested(service.path, fields);
            compare(fakeAgent.replies.length, 1);
            compare(loader.source.toString(), "", "the passphrase popup came up anyway");

            realAgent.userInputRequested(service.path, fields);
            compare(fakeAgent.replies.length, 1);
            verify(loader.source.toString().indexOf("WiFiProvidePassphrasePopup.qml") >= 0,
                   "a wrong passphrase from the code did not bring the popup up");
            loader.source = "";
        }

        function test_alreadyConnectedSaysSo() {
            var service = serviceNamed("My Own Wifi");
            verify(service.connected);
            connectSpy.target = service;
            qr.joinCode("WIFI:S:My Own Wifi;T:WPA;P:secret123;;");
            compare(connectSpy.count, 0);
            verify(qr.messagePopup.opened);
            verify(qr.messagePopup.text.indexOf("Already connected") === 0, qr.messagePopup.text);
        }

        function test_aNetworkNotInRangeGivesUp() {
            qr.joinTimeout = 100;
            qr.joinCode("WIFI:S:Far Away;T:WPA;P:secret123;;");
            verify(qr.pendingJoin !== null);
            tryVerify(function () { return qr.messagePopup.opened; }, 2000);
            verify(qr.messagePopup.text.indexOf("was not found") > 0, qr.messagePopup.text);
            compare(qr.pendingJoin, null);
        }

        function test_aCodeThatIsNotWifiSaysSo() {
            qr.joinCode("https://example.org/");
            verify(qr.messagePopup.opened);
            compare(qr.messagePopup.text, "That is not a Wi-Fi QR code.");
            compare(qr.pendingJoin, null);
        }

        function test_theScanPopupKeepsLookingAfterAWrongCode() {
            var scan = qr.scanPopup;
            scan.open();
            tryVerify(function () { return scan.opened; }, 2000);
            scan.handleCode("WIFI:S:corp;T:WPA2-EAP;E:PEAP;;");
            verify(scan.opened);
            verify(scan.status.indexOf("user name") > 0, scan.status);

            var service = serviceNamed("Someone else's wifi");
            connectSpy.target = service;
            scan.handleCode("WIFI:S:Someone else's wifi;T:WEP;P:abcde;;");
            tryVerify(function () { return !scan.opened; }, 2000);
            tryCompare(connectSpy, "count", 1);
        }

        function test_theScanRowOpensTheScanner() {
            var row = findChild(page, "wifiScanQrRow");
            verify(row !== null);
            row.clicked();
            tryVerify(function () { return qr.scanPopup.opened; }, 2000);
            qr.scanPopup.close();
        }

        function test_aCodeFromAnotherAppJoins() {
            var service = serviceNamed("Someone else's wifi");
            connectSpy.target = service;
            page.handleLaunchParams({ "wifiQrCode": "WIFI:S:Someone else's wifi;T:WEP;P:abcde;;" });
            compare(connectSpy.count, 1);
        }

        function test_aHiddenNetworkIsFoundByItsSecurity() {
            var model = createTemporaryObject(fakeModelComponent, root);
            var open = createTemporaryObject(fakeServiceComponent, root,
                { "name": "", "hidden": true, "path": "/h/open",
                  "securityType": NetworkService.SecurityNone });
            var psk = createTemporaryObject(fakeServiceComponent, root,
                { "name": "", "hidden": true, "path": "/h/psk",
                  "securityType": NetworkService.SecurityPSK });
            model.services = [open, psk];
            qr.wifiModel = model;

            qr.joinCode("WIFI:S:Secret Lab;T:WPA;P:secret123;H:true;;");
            compare(psk.connects, 1);
            compare(open.connects, 0);
            // connman asks a hidden network's name too; the code has it.
            verify(qr.answerUserInput("/h/psk", {
                "Name": { "Requirement": "mandatory" },
                "SSID": { "Requirement": "alternate" },
                "Passphrase": { "Requirement": "mandatory" } }));
            compare(fakeAgent.replies[0], { "Name": "Secret Lab", "Passphrase": "secret123" });
        }

        function test_aHiddenOneIsNotJoinedWhenTheCodeDoesNotSaySo() {
            var model = createTemporaryObject(fakeModelComponent, root);
            var psk = createTemporaryObject(fakeServiceComponent, root,
                { "name": "", "hidden": true, "path": "/h/psk" });
            model.services = [psk];
            qr.wifiModel = model;
            qr.joinCode("WIFI:S:Secret Lab;T:WPA;P:secret123;;");
            compare(psk.connects, 0);
            verify(qr.pendingJoin !== null);
            compare(model.scans, 1, "no scan was started for a network not in the list");
        }

        // --- sharing --------------------------------------------------------

        function test_shareAsksThePasscodeThenShowsTheCode() {
            var service = serviceNamed("My Own Wifi");
            qr.share(service);
            verify(fakeLuna.called("luna://com.webos.service.auth/getDeviceLockMode"));
            tryVerify(function () { return qr.passcodePopup.opened; }, 2000);
            compare(qr.passcodePopup.lockMode, "pin");
            verify(!fakeLuna.called("luna://com.webos.service.wifi/getPassphrase"),
                   "the passphrase was asked for before the passcode");

            qr.passcodePopup.verifyRequested("1234");
            var asked = fakeLuna.called("luna://com.webos.service.wifi/getPassphrase");
            verify(asked);
            compare(asked.request, { "servicePath": service.path, "unlockToken": "tok-1" });

            tryVerify(function () { return qr.sharePopup.opened; }, 2000);
            compare(qr.sharePopup.codeText, "WIFI:S:My Own Wifi;T:WPA;P:pass\\;word1;;");
            compare(findChild(qr.sharePopup.contentItem, "wifiSharePassphrase").text, "pass;word1");

            // Closed, it lets go of the passphrase.
            qr.sharePopup.close();
            tryVerify(function () { return !qr.sharePopup.opened; }, 2000);
            compare(qr.sharePopup.passphrase, "");
        }

        function test_aWrongPasscodeRevealsNothing() {
            qr.share(serviceNamed("My Own Wifi"));
            tryVerify(function () { return qr.passcodePopup.opened; }, 2000);
            qr.passcodePopup.verifyRequested("0000");
            verify(qr.passcodePopup.opened);
            compare(qr.passcodePopup.errorText, "That is not correct.");
            verify(!fakeLuna.called("luna://com.webos.service.wifi/getPassphrase"));
            verify(!qr.sharePopup.opened);
            qr.passcodePopup.close();
        }

        function test_withoutALockNoTokenIsAskedFor() {
            fakeLuna.lockMode = "none";
            var service = serviceNamed("My Own Wifi");
            qr.share(service);
            verify(!qr.passcodePopup.opened);
            verify(!fakeLuna.called("luna://com.webos.service.auth/matchDevicePasscode"));
            compare(fakeLuna.called("luna://com.webos.service.wifi/getPassphrase").request,
                    { "servicePath": service.path });
            tryVerify(function () { return qr.sharePopup.opened; }, 2000);
            qr.sharePopup.close();
        }

        function test_anOpenNetworkIsSharedWithoutAsking() {
            var service = serviceNamed("OpenBar Wifi");
            service.saved = true;
            qr.share(service);
            compare(fakeLuna.calls.length, 0);
            tryVerify(function () { return qr.sharePopup.opened; }, 2000);
            compare(qr.sharePopup.codeText, "WIFI:S:OpenBar Wifi;T:nopass;;");
            qr.sharePopup.close();
            service.saved = false;
        }

        function test_aNetworkNotSavedCannotBeShared() {
            var service = serviceNamed("Someone else's wifi");
            verify(!qr.canShare(service));
            qr.share(service);
            compare(fakeLuna.calls.length, 0);
            verify(!qr.sharePopup.opened);
        }

        function test_aRefusalFromTheWifiServiceSaysWhy() {
            fakeLuna.lockMode = "none";
            fakeLuna.passphraseReply = { "returnValue": false, "errorCode": 214,
                                         "errorText": "passcode", "passcodeRequired": true };
            qr.share(serviceNamed("My Own Wifi"));
            verify(!qr.sharePopup.opened);
            verify(qr.messagePopup.opened);
            compare(qr.messagePopup.text, "The passcode is needed to share this network.");

            qr.messagePopup.close();
            fakeLuna.passphraseReply = { "returnValue": false, "errorCode": 215, "errorText": "none" };
            qr.share(serviceNamed("My Own Wifi"));
            tryVerify(function () { return qr.messagePopup.opened; }, 2000);
            verify(qr.messagePopup.text.indexOf("No password is stored") === 0);
            fakeLuna.passphraseReply = { "returnValue": true, "ssid": "My Own Wifi",
                                         "security": "psk", "passphrase": "pass;word1",
                                         "hidden": false };
        }

        function test_theDetailsPopupHasShareForASavedNetwork() {
            var info = findChild(page, "networkInfoPopup");
            var shareButton = findChild(info.contentItem, "wifiShareButton");
            verify(shareButton !== null);

            info.service = serviceNamed("Someone else's wifi");
            info.open();
            tryVerify(function () { return info.opened; }, 2000);
            verify(!shareButton.visible, "Share offered for a network that is not saved");
            info.close();
            tryVerify(function () { return !info.opened; }, 2000);

            info.service = serviceNamed("My Own Wifi");
            info.open();
            tryVerify(function () { return info.opened; }, 2000);
            verify(shareButton.visible);
            shareButton.clicked();
            tryVerify(function () { return !info.opened; }, 2000);
            verify(fakeLuna.called("luna://com.webos.service.auth/getDeviceLockMode"),
                   "Share did not start the passcode check");
            tryVerify(function () { return qr.passcodePopup.opened; }, 2000);
            qr.passcodePopup.close();
        }
    }

    TestCase {
        name: "HotspotQr"
        when: windowShown

        function test_theHotspotIsSharedAsACode() {
            var page = createTemporaryObject(tetheringPageComponent, root);
            verify(page !== null);
            var button = findChild(page, "hotspotShareButton");
            var popup = findChild(page, "hotspotSharePopup");
            verify(button !== null && popup !== null);

            // The stand-in's technology: set the hotspot up as connman would hold it.
            var tech = findChild(page, "wifiTechnology");
            verify(tech !== null, "no wifi technology on the page");
            tech.tetheringId = "";
            tech.tetheringPassphrase = "";
            verify(!button.enabled, "a hotspot with no name can be shared");

            tech.tetheringId = "LuneOS Hotspot";
            tech.tetheringPassphrase = "short";
            verify(!button.enabled, "a hotspot with a password too short can be shared");

            tech.tetheringPassphrase = "hotspot:pw";
            verify(button.enabled);
            button.clicked();
            tryVerify(function () { return popup.opened; }, 2000);
            compare(popup.codeText, "WIFI:S:LuneOS Hotspot;T:WPA;P:hotspot\\:pw;;");
            popup.close();
        }
    }
}
