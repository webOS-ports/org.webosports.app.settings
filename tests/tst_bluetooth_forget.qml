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
import QtTest
import LuneOS.Bluetooth 0.2
import LuneOS.Service 1.0
import LunaNext.Common 0.1

import "../src/qml/Connectivity"

/*
 * Forgetting a paired device on the Bluetooth page: press and hold on its
 * row opens BluetoothDeviceInfoPopup, whose "Forget device" unpairs it
 * through bluetooth2 (adapter/unpair) and then has bluetooth2 drop it from
 * the headsets it reconnects (autoReconnect/forget). A plain tap still
 * connects. The page is shorter than its content, so it scrolls, as on a
 * phone, and its Flickable sees the press too. bluetooth2 is a stand-in
 * LunaService; the devices are luneos-components' BluetoothDevicesModel
 * stand-in, a ListModel:
 *   0 "" (address only), 1 "Fake", 2 "Fake Paired",
 *   3 "Fake Connected", 4 "Fake Paired Connected".
 * Run with tests/run-tests.sh.
 */
Item {
    id: root
    width: 480
    height: 800

    // What the category window gives its pages.
    property string appId: "org.webosports.app.settings"
    property Component actionHeaderComponent

    readonly property string bt2: "luna://com.webos.service.bluetooth2/"

    Item {
        id: pageArea
        width: parent.width
        height: 360
    }

    Component {
        id: pageComponent
        BluetoothPage { anchors.fill: parent }
    }

    // bluetooth2: adapter/unpair answers as unpairAnswer says ("ok",
    // "refused": returnValue false, "error": the error callback), the
    // subscription to device/getConnectedDevices is kept to send to, the
    // rest is recorded and answered with returnValue true.
    Component {
        id: fakeLunaComponent
        LunaService {
            property var calls: []
            property string unpairAnswer: "ok"
            property var profilesSubscriber: null
            property int profilesCancelled: 0

            function _answer(fct, response) {
                if (fct)
                    fct({"payload": JSON.stringify(response)});
            }
            function call(uri, args, ok, err) {
                calls.push({"uri": uri, "args": JSON.parse(args)});
                if (uri === root.bt2 + "adapter/unpair" && unpairAnswer === "refused")
                    _answer(ok, {"returnValue": false, "errorCode": 122, "errorText": "Failed to unpair"});
                else if (uri === root.bt2 + "adapter/unpair" && unpairAnswer === "error")
                    _answer(err, {"returnValue": false, "errorCode": -1, "errorText": "Denied"});
                else
                    _answer(ok, {"returnValue": true});
            }
            function subscribe(uri, args, ok, err) {
                calls.push({"uri": uri, "args": JSON.parse(args)});
                var fake = this;
                if (uri === root.bt2 + "device/getConnectedDevices")
                    profilesSubscriber = ok;
                return {"cancel": function () { fake.profilesCancelled++; }};
            }
            function sendConnectedDevices(devices) {
                _answer(profilesSubscriber, {"returnValue": true, "subscribed": true, "devices": devices});
            }
            function callsTo(method) {
                return calls.filter(function (c) { return c.uri === root.bt2 + method; });
            }
        }
    }

    // BluetoothManager's connect and disconnect, recorded
    Component {
        id: managerComponent
        QtObject {
            property QtObject connectingDevice: null
            property var requests: []
            function connectDeviceAddress(address) { requests = requests.concat(["connect " + address]); return null; }
            function disconnectDeviceAddress(address) { requests = requests.concat(["disconnect " + address]); return null; }
        }
    }

    // A device as BluezQt's DevicesModel has it, with the roles the stand-in
    // model leaves out: the delegate's model entry of a one-row model, which
    // goes when the row is removed, as the page's rows do.
    ListModel {
        id: fakeDevices
    }
    Instantiator {
        id: fakeDeviceRows
        model: fakeDevices
        delegate: QtObject { readonly property var entry: model }
    }
    // BlueZ reports no battery level: what a device without one looks like
    QtObject {
        id: noBattery
        property int percentage: -1
    }
    function fakeDevice(roles) {
        var device = {"Name": "Test headset", "Address": "AA:BB:CC:DD:EE:FF",
                      "AdapterAddress": "02:00:00:00:00:02", "Paired": true, "Connected": true,
                      "Type": 4 /* BluezQt Device::Headset */, "Battery": noBattery};
        for (var k in roles)
            device[k] = roles[k];
        fakeDevices.clear();
        fakeDevices.append(device);
        return fakeDeviceRows.objectAt(0).entry;
    }

    TestCase {
        name: "BluetoothForget"
        when: windowShown

        property var page
        property var luna
        property var manager

        function findIn(item, test) {
            if (!item)
                return null;
            if (test(item))
                return item;
            var kids = item.data !== undefined ? item.data : item.children;
            if (kids) {
                for (var i = 0; i < kids.length; ++i) {
                    var found = findIn(kids[i], test);
                    if (found)
                        return found;
                }
            }
            if (item.contentItem && item.contentItem !== item && item.contentItem.parent !== item) {
                var inContent = findIn(item.contentItem, test);
                if (inContent)
                    return inContent;
            }
            return null;
        }
        function byName(item, name) { return findIn(item, function (o) { return o.objectName === name; }); }
        function byText(item, text) { return findIn(item, function (o) { return o.text === text && o.visible !== false; }); }
        function waitForLayout(item) {
            for (var it = item; it; it = it.parent) {
                if (isPolishScheduled(it))
                    waitForPolish(it);
            }
        }

        function popup() { return byName(page, "deviceInfoPopup"); }
        function list() { return byName(page, "deviceList"); }
        function row(i) { return list().itemAtIndex(i); }
        function address(i) { return list().model.get(i).Address; }
        function flickable() {
            for (var it = list().parent; it; it = it.parent) {
                if (it.contentY !== undefined && it.flick !== undefined)
                    return it;
            }
            return null;
        }
        // Bring row i on screen and hold a finger on it, near its name,
        // for ms; drift moves it that far during the hold, as a finger does
        function hold(i, ms, drift) {
            var r = row(i);
            var f = flickable();
            f.contentY = Math.max(0, Math.min(r.mapToItem(f.contentItem, 0, 0).y,
                                              f.contentHeight - f.height));
            waitForLayout(r);
            var x = Units.gu(4), y = r.height / 2;
            mousePress(r, x, y);
            if (drift) {
                mouseMove(r, x + drift / 2, y + drift / 2);
                mouseMove(r, x + drift, y + drift);
            }
            wait(ms);
            mouseRelease(r, x + (drift || 0), y + (drift || 0));
        }
        function tap(i) {
            var r = row(i);
            var f = flickable();
            f.contentY = Math.max(0, Math.min(r.mapToItem(f.contentItem, 0, 0).y,
                                              f.contentHeight - f.height));
            waitForLayout(r);
            mouseClick(r, Units.gu(4), r.height / 2);
        }
        function clickInPopup(text) {
            var button = byText(popup().contentItem, text);
            verify(button !== null, "no \"" + text + "\" in the popup");
            waitForLayout(button);
            mouseClick(button);
        }
        function openOn(device) {
            popup().device = device;
            popup().open();
            tryCompare(popup(), "opened", true, 2000);
        }

        function init() {
            BluetoothManager.discoveringMode = false;
            BluetoothManager.btManager.usableAdapter.stopDiscovery();
            luna = createTemporaryObject(fakeLunaComponent, root);
            page = createTemporaryObject(pageComponent, pageArea, {"luna": luna});
            verify(page !== null, "the page did not load");
            manager = createTemporaryObject(managerComponent, root);
            page.deviceManager = manager;
            tryCompare(BluetoothManager, "bluetoothOperational", true, 2000);
            tryVerify(function () { return list().count === 5 && row(4) !== null; }, 2000);
            verify(flickable() !== null && flickable().contentHeight > flickable().height,
                   "the page does not scroll, so the hold is not tested inside a Flickable");
        }

        function cleanup() {
            if (popup())
                popup().close();
        }

        function test_holdingAPairedDeviceOpensItsPopup() {
            hold(2, 1200);
            tryCompare(popup(), "opened", true, 2000, "no popup after holding a paired device");
            compare(byName(popup().contentItem, "deviceInfoName").text, "Fake Paired");
            compare(byName(popup().contentItem, "deviceInfoState").text, "Not connected");
            verify(byText(popup().contentItem, address(2)) !== null, "the address is not shown");
            verify(byText(popup().contentItem, "Forget device") !== null, "no \"Forget device\"");
            verify(byText(popup().contentItem, "Cancel") !== null, "no \"Cancel\"");
            compare(manager.requests, [], "the hold also connected the device");
        }

        // A finger drifts a few pixels during a hold; the page's Flickable
        // sees the press too. (A MouseArea's pressAndHold survives this
        // here as well; on the Wi-Fi page's flicking list it did not.)
        function test_theHoldSurvivesAFingerDrifting() {
            hold(4, 1200, 4);
            tryCompare(popup(), "opened", true, 2000, "a hold with 4 px of drift opened nothing");
            compare(manager.requests, [], "the hold also disconnected the device");
        }

        function test_holdingADeviceNotPairedOpensNothing() {
            hold(1, 1200);
            wait(100);
            verify(!popup().opened, "a popup for a device that is not paired");
            compare(manager.requests, [], "the hold connected the device");
        }

        function test_aTapStillConnectsOrDisconnects() {
            tap(2);
            tap(4);
            compare(manager.requests, ["connect " + address(2), "disconnect " + address(4)]);
            verify(!popup().opened, "a tap opened the popup");
        }

        function test_forgetUnpairsAndThenForgetsTheReconnect() {
            hold(4, 1200);
            tryCompare(popup(), "opened", true, 2000);
            clickInPopup("Forget device");
            var unpair = luna.callsTo("adapter/unpair");
            compare(unpair.length, 1, "no adapter/unpair");
            compare(unpair[0].args, {"address": address(4)});
            var forget = luna.callsTo("autoReconnect/forget");
            compare(forget.length, 1, "bluetooth2 still reconnects the forgotten device");
            compare(forget[0].args, {"address": address(4)});
            var order = luna.calls.map(function (c) { return c.uri; });
            verify(order.indexOf(root.bt2 + "adapter/unpair") < order.indexOf(root.bt2 + "autoReconnect/forget"),
                   "the reconnect was forgotten before the unpair went through");
            tryCompare(popup(), "opened", false, 2000, "the popup stays after \"Forget device\"");
            compare(manager.requests, [], "forgetting connected or disconnected it as well");
        }

        function test_theAdapterIsPassedOn() {
            var device = root.fakeDevice({});
            openOn(device);
            clickInPopup("Forget device");
            var expected = {"address": "AA:BB:CC:DD:EE:FF", "adapterAddress": "02:00:00:00:00:02"};
            compare(luna.callsTo("adapter/unpair")[0].args, expected);
            compare(luna.callsTo("autoReconnect/forget")[0].args, expected);
        }

        function test_aRefusedUnpairSaysSoAndKeepsTheReconnect_data() {
            return [{"tag": "returnValue false", "answer": "refused"},
                    {"tag": "error callback", "answer": "error"}];
        }
        function test_aRefusedUnpairSaysSoAndKeepsTheReconnect(data) {
            luna.unpairAnswer = data.answer;
            hold(2, 1200);
            tryCompare(popup(), "opened", true, 2000);
            clickInPopup("Forget device");
            compare(luna.callsTo("adapter/unpair").length, 1);
            compare(luna.callsTo("autoReconnect/forget").length, 0,
                    "the reconnect was forgotten for a device still paired");
            var message = byText(page, "Unable to forget the device.");
            verify(message !== null, "no \"Unable to forget the device.\"");
            page.deviceMessageMs = 100;
            tryVerify(function () { return byText(page, "Unable to forget the device.") === null; }, 2000,
                      "the message stays");
        }

        function test_cancelForgetsNothing() {
            hold(2, 1200);
            tryCompare(popup(), "opened", true, 2000);
            clickInPopup("Cancel");
            tryCompare(popup(), "opened", false, 2000, "the popup stays after \"Cancel\"");
            compare(luna.callsTo("adapter/unpair").length, 0, "\"Cancel\" unpaired");
            compare(luna.callsTo("autoReconnect/forget").length, 0);
            compare(manager.requests, []);
        }

        function test_theProfilesUpAreShown() {
            var device = root.fakeDevice({});
            openOn(device);
            compare(luna.callsTo("device/getConnectedDevices").length, 1);
            compare(luna.callsTo("device/getConnectedDevices")[0].args.subscribe, true);
            luna.sendConnectedDevices([
                {"address": "11:22:33:44:55:66", "connectedProfiles": ["pbap"]},
                {"address": "aa:bb:cc:dd:ee:ff", "connectedProfiles": ["hfp", "a2dp"]}]);
            verify(byText(popup().contentItem, "HFP, A2DP") !== null, "the profiles up are not shown");
            verify(byText(popup().contentItem, "PBAP") === null, "another device's profiles");
            luna.sendConnectedDevices([{"address": "aa:bb:cc:dd:ee:ff", "connectedProfiles": ["a2dp"]}]);
            verify(byText(popup().contentItem, "A2DP") !== null, "the profiles did not follow bluetooth2");
            luna.sendConnectedDevices([]);
            verify(byText(popup().contentItem, "Profiles") === null, "profiles of a device with none up");
            popup().close();
            tryCompare(popup(), "opened", false, 2000);
            compare(luna.profilesCancelled, 1, "the subscription outlives the popup");
        }

        function test_typeAndBattery() {
            var device = root.fakeDevice({"Battery": createTemporaryQmlObject(
                                              "import QtQuick; QtObject { property int percentage: 70 }", root)});
            openOn(device);
            verify(byText(popup().contentItem, "Headset") !== null, "no type");
            verify(byText(popup().contentItem, "70%") !== null, "no battery");
            compare(byName(popup().contentItem, "deviceInfoState").text, "Connected");
        }

        function test_nothingToSayIsLeftOut() {
            var device = root.fakeDevice({"Type": -1, "Connected": false});
            openOn(device);
            luna.sendConnectedDevices([{"address": "aa:bb:cc:dd:ee:ff", "connectedProfiles": ["hfp"]}]);
            verify(byText(popup().contentItem, "Type") === null, "a type for a device without one");
            verify(byText(popup().contentItem, "Battery") === null, "a battery for a device without one");
            verify(byText(popup().contentItem, "Profiles") === null, "profiles of a device not connected");
            verify(byText(popup().contentItem, "AA:BB:CC:DD:EE:FF") !== null);
        }

        // BlueZ drops a forgotten device; its row goes, and so does the popup
        function test_thePopupClosesWhenTheDeviceGoes() {
            var device = root.fakeDevice({});
            openOn(device);
            fakeDevices.clear();
            tryCompare(popup(), "opened", false, 2000, "a popup for a device that is gone");
        }

        function test_theHintIsThere() {
            var hint = byText(page, "Touch and hold a paired device to see its details or forget it.");
            verify(hint !== null, "nothing says a device can be held");
        }
    }
}
