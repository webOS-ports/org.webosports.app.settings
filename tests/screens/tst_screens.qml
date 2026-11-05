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

import LunaNext.Common 0.1

/*
 * Every settings page as the device opens it: GenericCategoryWindow with the
 * page's appId (each category is its own application there), at the size of
 * the screen this run pretends to be - tests/run-tests.sh runs it once per
 * profile in PROFILES. luneos-components' test/imports stand in for the
 * services the pages call. Each page is checked for the basics a layout
 * break shows up as - the header and the page are there, have a size and sit
 * inside the window, the page's own scroll area does not run wider than
 * the window, the header's title is not cut off, no text runs to the edge of
 * the screen, and on a wide screen the page is a column in the middle - and
 * saved as build/test-output/ui/<profile>-<page>.png to look at.
 */
TestCase {
    id: test
    name: "Screens"
    when: windowShown

    readonly property string shotDir: decodeURIComponent(Qt.resolvedUrl("../../build/test-output/ui").toString()
                                                         .replace(/^file:\/\//, ""))
    readonly property url windowUrl: Qt.resolvedUrl("../../src/qml/GenericCategoryWindow.qml")
    property var app: null

    function makeWindow(appId) {
        var component = Qt.createComponent(windowUrl);
        if (component.status === Component.Error)
            fail(component.errorString());
        var window = component.createObject(null, { appId: appId, launchParams: "{}" });
        verify(window !== null, "the window for " + appId + " was not made");
        return window;
    }

    // One row per page the category window knows, by its appId; the short
    // name ("org.webosports.app.settings.wifi" -> "wifi") names the picture.
    function test_page_data() {
        var window = makeWindow("org.webosports.app.settings.example");
        var rows = [];
        for (var appId in window.categories)
            rows.push({ tag: appId.replace(/^org\.webosports\.app\.settings\./, ""), appId: appId });
        window.destroy();
        return rows;
    }

    function cleanup() {
        if (app) {
            app.destroy();
            app = null;
        }
        wait(20);
    }

    function shot(name) {
        var done = false;
        verify(app.contentItem.grabToImage(function(result) {
            result.saveToFile(shotDir + "/" + Settings.profileName + "-" + name + ".png");
            done = true;
        }), "grab " + name);
        tryVerify(function() { return done; }, 5000, "saved " + name);
    }

    // The item's rectangle in the window.
    function inWindow(item) {
        return item.mapToItem(app.contentItem, 0, 0, item.width, item.height);
    }

    function verifyInside(item, what) {
        verify(item.visible, what + " is not visible");
        verify(item.width > 0 && item.height > 0, what + " has no size (" + item.width + "x" + item.height + ")");
        var r = inWindow(item);
        verify(r.x >= -0.5 && r.y >= -0.5 && r.x + r.width <= app.width + 0.5 && r.y + r.height <= app.height + 0.5,
               what + " is not inside the " + app.width + "x" + app.height + " window: "
               + r.x + "," + r.y + " " + r.width + "x" + r.height);
    }

    // The page's scroll areas that fill (most of) its width: those scroll
    // up and down, and anything wider than they are is cut off at the edge.
    // Narrower ones (a row of pictures, a picker) may well scroll sideways.
    function pageFlickables(item, page, out) {
        if (!item || !item.visible)
            return out;
        if (item.flickableDirection !== undefined && item.contentWidth !== undefined
                && item.width >= page.width * 0.8)
            out.push(item);
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++)
            pageFlickables(kids[i], page, out);
        return out;
    }

    // The visible pieces of text on the page that can be seen: a tab
    // swiped away sits beside the page, outside what its view shows. left
    // and right are where the text itself starts and ends, in the page.
    function pageTexts(item, page, out, clipLeft, clipRight) {
        if (!item || !item.visible || item.opacity === 0)
            return out;
        var r = item.mapToItem(page, 0, 0, item.width, item.height);
        if (item.clip) {
            clipLeft = Math.max(clipLeft, r.x);
            clipRight = Math.min(clipRight, r.x + r.width);
        }
        if (item.text !== undefined && typeof item.text === "string" && item.text !== ""
                && item.contentWidth !== undefined && item.width > 0 && item.height > 0
                && r.x < clipRight - 0.5 && r.x + r.width > clipLeft + 0.5)
            out.push({ item: item, left: r.x + (item.leftPadding || 0),
                       right: r.x + r.width - (item.rightPadding || 0) });
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++)
            pageTexts(kids[i], page, out, clipLeft, clipRight);
        return out;
    }

    // The header's title label: the item with its title that elides.
    function headerTitle(header) {
        var kids = header.contentChildren;
        for (var i = 0; i < kids.length; i++)
            if (kids[i].text === header.title && kids[i].elide !== undefined)
                return kids[i];
        return null;
    }

    function itemByText(item, text) {
        if (!item)
            return null;
        if (item.text === text)
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var found = itemByText(kids[i], text);
            if (found)
                return found;
        }
        return null;
    }

    function itemByObjectName(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; i++) {
            var found = itemByObjectName(kids[i], name);
            if (found)
                return found;
        }
        return null;
    }

    function test_page(data) {
        app = makeWindow(data.appId);
        app.requestActivate();
        compare(app.width, Settings.displayWidth);
        compare(app.height, Settings.displayHeight);
        var loader = app._categoryLoader;
        tryCompare(loader, "status", Loader.Ready, 5000, data.tag + " did not load");
        var page = loader.item;
        verify(page !== null);
        // Service replies from the stand-ins, lists filling and the style's
        // transitions come on their own time.
        wait(400);
        waitForItemPolished(page);
        // The picture first, so a page that fails below can still be seen.
        shot(data.tag);

        verifyInside(loader, data.tag + "'s page area");
        verifyInside(page, data.tag + "'s page");
        var header = null;
        for (var k = 0; k < app.contentItem.children.length; k++)
            if (app.contentItem.children[k].title === app.categoryTitle)
                header = app.contentItem.children[k];
        verify(header !== null, data.tag + ": no header");
        verifyInside(header, data.tag + "'s header");
        verify(loader.y >= header.y + header.height - 0.5, data.tag + ": the page starts under the header");
        // The whole title, at whichever of the header's two sizes it fits.
        // "System Updates (placeholder)" is too long for a phone's header
        // even at the small size, and the header elides rather than wraps;
        // the placeholders may, as long as it is at the small size.
        var title = headerTitle(header);
        verify(title !== null, data.tag + ": no title in the header");
        if (!/\(placeholder\)$/.test(app.categoryTitle) || !header.compact)
            verify(!title.truncated, data.tag + ": the title \"" + app.categoryTitle + "\" is cut off in its "
                   + title.width + " px");

        // No text runs to the edge of the screen: every page keeps the
        // margin SettingsPageContent gives it. On a wide screen the page is a
        // column in the middle, not the full width.
        var texts = pageTexts(page, page, [], 0, page.width);
        verify(texts.length > 0, data.tag + ": no text on the page");
        var minLeft = page.width, maxRight = 0;
        for (var t = 0; t < texts.length; t++) {
            verify(texts[t].left >= Units.gu(1) - 0.5,
                   data.tag + ": \"" + texts[t].item.text + "\" starts " + texts[t].left + " px from the left edge");
            verify(texts[t].right <= page.width - Units.gu(1) + 0.5,
                   data.tag + ": \"" + texts[t].item.text + "\" ends " + (page.width - texts[t].right)
                   + " px from the right edge");
            minLeft = Math.min(minLeft, texts[t].left);
            maxRight = Math.max(maxRight, texts[t].right);
        }
        if (page.width > Units.gu(80))
            verify(minLeft > page.width * 0.1 && maxRight < page.width * 0.9,
                   data.tag + ": the page runs the width of the screen (" + minLeft + " to " + maxRight + " of "
                   + page.width + ") instead of a column in the middle");

        // Tabs are the size of every other page's.
        var tab = data.tag === "esim" ? itemByText(page, "Profiles")
                : data.tag === "nfc" ? itemByText(page, "Tag") : null;
        if (tab)
            compare(tab.font.pixelSize, FontUtils.sizeToPixels("medium"), data.tag + "'s tabs");

        // The list of networks has the page's room: on a short screen the
        // explanation line under it makes way.
        if (data.tag === "wifi") {
            var list = itemByObjectName(page, "wifiList");
            verify(list !== null, "no Wi-Fi list");
            verify(list.height >= page.height * 2 / 3,
                   "the Wi-Fi list has " + list.height + " px of the page's " + page.height);
        }

        var flicks = pageFlickables(page, page, []);
        for (var i = 0; i < flicks.length; i++) {
            var f = flicks[i];
            if (f.flickableDirection === Flickable.HorizontalFlick
                    || (f.orientation !== undefined && f.orientation === ListView.Horizontal))
                continue;
            verify(f.contentWidth <= f.width + 1,
                   data.tag + ": a scroll area (" + f + " in " + f.parent + ") is wider inside (" + f.contentWidth + ") than it is (" + f.width + ")");
        }
    }
}
