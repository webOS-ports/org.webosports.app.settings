#!/bin/sh
# Run the QML tests in tests/ on a development machine.
#
# The pages import LuneOS modules, so the tests need a built luneos-components
# checkout (qmake6 && make at its top): its modules for the LuneOS style and
# components, and its test/imports for the stand-ins of what talks to the
# system (LuneOS.Bluetooth, Connman, LunaService). Point LUNEOS_COMPONENTS at
# it; it defaults to one next to this checkout.
#
# The tst_*.qml here run once. screens/tst_screens.qml opens every settings
# page at the size of a real device and runs once per screen in PROFILES - by
# default the mindphone (480x800), the Q25 (720x720), the TouchPad (1024x768)
# and the radon (720x1600) - saving each page as
# build/test-output/ui/<profile>-<page>.png. luneos-components' stand-ins read
# their profile, and with it the grid unit, once as they load, and
# qmltestrunner takes no --profile, so each profile runs against a copy of
# LunaNext.Common whose default profile is that screen. PROFILES= skips them.
#
# Override QMLTESTRUNNER if your Qt lives elsewhere; any arguments are passed
# on to qmltestrunner. On a machine without a display, run with
# QT_QPA_PLATFORM=offscreen.
cd "$(dirname "$0")" || exit 1

LUNEOS_COMPONENTS=${LUNEOS_COMPONENTS:-../../luneos-components}
PROFILES=${PROFILES-mindphone q25 tp radon}
if [ -z "${QMLTESTRUNNER:-}" ]; then
    for candidate in /usr/lib/qt6/bin/qmltestrunner \
            $(ls -d "$HOME"/Qt/6.*/gcc_64/bin/qmltestrunner 2>/dev/null | sort -V | tail -1) \
            "$(command -v qmltestrunner)"; do
        if [ -x "$candidate" ]; then
            QMLTESTRUNNER=$candidate
            break
        fi
    done
fi

if [ ! -x "$QMLTESTRUNNER" ]; then
    echo "qmltestrunner not found; set QMLTESTRUNNER to your Qt's bin/qmltestrunner" >&2
    exit 1
fi
if ! ls "$LUNEOS_COMPONENTS"/modules/QtQuick/Controls/LuneOS/libluneosstyleplugin.so >/dev/null 2>&1; then
    echo "no built luneos-components in $LUNEOS_COMPONENTS; build it or set LUNEOS_COMPONENTS" >&2
    exit 1
fi

export QT_QUICK_CONTROLS_STYLE=QtQuick.Controls.LuneOS
# As on the device, where SAM exports it for QML applications: the Buttons page
# reads the device's key file with a file:// XMLHttpRequest, which Qt refuses
# without this, and tst_buttons_page feeds it the files in data/.
export QML_XHR_ALLOW_FILE_READ=1

status=0
for t in tst_*.qml; do
    echo "--- $t"
    "$QMLTESTRUNNER" -input "$t" \
        -import "$LUNEOS_COMPONENTS/modules" \
        -import "$LUNEOS_COMPONENTS/test/imports" "$@" || status=1
done

[ -n "$PROFILES" ] || exit $status
PROFILE_DIR=$(mktemp -d) || exit 1
trap 'rm -rf "$PROFILE_DIR"' EXIT
mkdir -p ../build/test-output/ui
for profile in $PROFILES; do
    common=$PROFILE_DIR/$profile/LunaNext/Common
    mkdir -p "$common"
    cp "$LUNEOS_COMPONENTS"/test/imports/LunaNext/Common/* "$common/"
    sed -i "s/^var defaultProfile = .*/var defaultProfile = \"$profile\";/" "$common/SettingsStub.js"
    if ! grep -q "^var defaultProfile = \"$profile\";" "$common/SettingsStub.js"; then
        echo "could not select profile $profile in SettingsStub.js" >&2
        status=1
        continue
    fi
    echo "--- screens/tst_screens.qml ($profile)"
    "$QMLTESTRUNNER" -input screens/tst_screens.qml \
        -import "$LUNEOS_COMPONENTS/modules" \
        -import "$LUNEOS_COMPONENTS/test/imports" \
        -import "$PROFILE_DIR/$profile" "$@" || status=1
done

exit $status
