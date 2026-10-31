---
name: mc-test-server
description: "Local Fabric 1.20.1 test server for mc_bridge (2026-10-14): location, how it was started, proxy quirk"
metadata:
  node_type: memory
  type: project
  originSessionId: 0aa8bfa6-ce21-4ddf-a3e3-b3f91e190d69
  modified: 2026-10-14T10:30:51.115Z
---

Test server at `C:\Users\gdpto\Downloads\mc_test_server` (created 2026-10-14 at the user's request; user approved the download and EULA). It is a pirate server (online-mode=false). Its mods are fabric-api 0.92.6 and mcbridge; the bridge listens on 8790, and its key is in config/mcbridge.json. `start.bat` runs it.

Java on this PC has no direct internet: DNS fails. curl goes through the local proxy 127.0.0.1:10809 (HTTPS_PROXY). The first launcher run needed `-Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=10809` (plus the http.* variants).

The whole bridge protocol was verified by curl on 10-14: hello, state/join, area, chat, the auth-command whitelist, move, the jump guard, and leave. Still unverified: the Dota client itself in game. See [[engine3d-project]].
