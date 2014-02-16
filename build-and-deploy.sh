#!/bin/bash
node enyo/tools/deploy.js -o deploy/org.webosports.app.settings
adb push deploy/org.webosports.app.settings /usr/palm/applications/org.webosports.app.settings
adb push BUILD-armv7a-vfp-neon/plugin/WebosPortsSettingsAppPlugin.so /usr/palm/applications/org.webosports.app.settings/
