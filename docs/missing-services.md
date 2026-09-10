# Services these pages are written against but LuneOS does not have

Some settings are written against something the device cannot answer yet. Those
pages show a "Not available on this device" notice rather than offering switches
that go nowhere, and come to life on their own once something answers — nothing
in the page has to change.

This file is what each of them expects, so the service can be written to fit.
The README points here; it is the contract, not a wish list.

Anything **not** listed here works today. In particular Battery, Storage,
Encryption, Developer Mode, USB, Tethering, Emergency Broadcast, Applications,
Notifications, Display, Appearance and Accessibility all reach real services —
though four of them needed those services extending first, which is recorded at
the bottom.

---

## Battery saver

**Page:** Battery
**Service:** `com.webos.service.battery`
**Method:** `batterySaverOnOff`

The name is already in batteryd's ACG file, so an application may ask for
permission to call it, but no such method is registered in the service — the
LSMethod table has `batteryStatusQuery` and `chargerStatusQuery` and nothing
else. There is also no power policy behind it: nothing on the device would
change behaviour if it were switched on.

A useful implementation would need both halves — the method, and something that
acts on it (a brightness cap, background activity limits, a slower poll
interval). Until then the Battery page deliberately has no switch for it rather
than a switch that reports success and does nothing.

## Wi-Fi hotspot address range and channel

**Page:** Tethering
**Interface:** `net.connman.Technology`
**Properties:** `TetheringIPAddress`, `TetheringChannel`

LuneOS's connman *does* have these — meta-webos-ports carries
`0002-technology-add-TetheringIPAddress-and-TetheringChannel.patch`. What is
missing is the binding: `libconnman-qt`'s `NetworkTechnology` exposes
`tethering`, `tetheringId` and `tetheringPassphrase` and nothing else, so
reaching the other two from QML would mean raw D-Bus from a settings page.

The fix belongs in libconnman-qt, as two more properties on
`NetworkTechnology`, after which the Tethering page can grow the rows.

## Leaving USB media transfer

**Page:** USB
**Service:** `com.palm.storage`
**Category:** `/diskmode`

`enterMSM` has no counterpart. Mass storage mode ends when the host ejects the
volume or the cable is pulled, which is what storaged's cable and eject handlers
act on; there is no method a settings page can call to end it deliberately.

The USB panel therefore offers a button and not a switch, and says how the mode
ends. A `leaveMSM` taking the same `user-confirmed` argument would let it become
a switch.

## Screen reader, contrast and colour inversion

**Page:** Accessibility
**Service:** none

There is no screen reader on the device, no contrast or colour-inversion control
in the compositor, and no per-application accessibility service. The
Accessibility page offers interface scaling, which does now work end to end, and
does not draw switches for the rest.

Colour inversion is the most tractable of the three: it is a shader on the
compositor's output, so it would live in luna-next-cardshell with a preference
in front of it, the same shape as the `uiScale` plumbing described below.

---

## Services that were extended rather than worked around

Four of these panels needed a service to grow something first. Recorded here so
that a build without those changes is recognisable: in each case the page shows
its "Not available" notice rather than misbehaving.

| Panel | Needs | Where |
|---|---|---|
| Storage | `com.palm.storage/volumes/getSpaceInfo` | storaged |
| Encryption | `com.palm.storage/volumes/getEncryptionStatus` | storaged |
| Notifications | per-app `disableToast` that persists, and `getToastSettings` | notificationmgr, via meta-webos-ports `0011-notificationmgr-remember-which-applications-may-not-show-a-toast.patch` |
| Accessibility | a `uiScale` preference that reaches every process | luneos-components (`Units`) and luna-next-cardshell (`Preferences`) |

Before those changes:

- nothing on the bus could say how full a volume was. `luna-prefs` has
  `storageCapacity` and `storageFreeSpace`, but each is a single `statfs` of
  `/media/internal` with no units, no device, and no way to ask about the root
  filesystem or a card; `com.webos.service.pdm` knows only about attached USB
  and SD devices.
- nothing could say whether a volume was encrypted.
- `disableToast` had taken a `source` since it was written and had always
  accepted it, answered success and done nothing:
  `Settings::disableToastNotificationForApp` was `return true;` and no more.
- the grid unit every size in the interface resolves through came from
  `luna.conf` or the `GRID_UNIT_PX` environment variable, and could not be
  changed from anywhere a person can reach.
