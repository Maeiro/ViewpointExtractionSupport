# Viewpoint Extraction Support

Displays a UH-1B helicopter during Extraction Mode pickups in Project Viewpoint. The aircraft approaches the selected extraction point during the final approach countdown, descends to a hover for boarding, and flies away when the pickup ends or is cancelled.

This is a compatibility addon for **Visible Helicopter Events**. It uses that mod's existing renderer and the enabled UH-1B assets; no third-party models, textures or renderer code are redistributed.

## Requirements

- Project Zomboid Build 42.21+.
- [Extraction Mode](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275) (initial integration targets 0.9.75).
- [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528).
- ZombieBuddy 2.3.4+.
- [Project Viewpoint - Visible Helicopter Events](https://steamcommunity.com/sharedfiles/filedetails/?id=3819322670) (initial integration targets 1.3.7).
- [UH-1B Helicopter](https://steamcommunity.com/sharedfiles/filedetails/?id=3409723807).
- [Aviation Core](https://steamcommunity.com/sharedfiles/filedetails/?id=3783444342).

Enable these mods and **Viewpoint Extraction Support**, then restart the game to load its Java hooks. Keep **Show event aircraft** enabled in Visible Helicopter Events. Signal a pickup using Extraction Mode's normal controls; the final approach normally begins with 30 seconds remaining. The campaign handoff uses its own 60-second approach window.

## Settings

In **Mod Options > Viewpoint Extraction Support**:

- **Show extraction helicopter**: enabled by default.
- **Hover height (metres)**: 6–30 metres above the extraction point's floor; default 12.

English and Brazilian Portuguese interface text is included. Extraction timing, boarding interactions, zombie attraction and sound playback remain owned by Extraction Mode. With Viewpoint's directional aircraft audio enabled, the original native helicopter recording follows the extraction model's position and altitude. This addon creates visual aircraft, not physical vehicles or extra extraction destinations.

## Integration

The addon reads the existing `ExtractionMode.ClientStates` snapshots, including the selected extraction site, extraction countdown, boarding rope and publicly supplied nearby PvPvE pickups. It never queries hidden raids or sends location requests to the server. Duplicate observations from local players share one aircraft identity.

Motion uses Extraction Mode's simulation clock, so single-player pause and time acceleration follow the original extraction timer. Between countdown updates the approach continues smoothly. Ending a pickup starts an eight-second departure from the aircraft's current position. Multiplayer snapshots older than five seconds stop supplying active pickups until fresh snapshots arrive.

A small ZombieBuddy hook submits the addon flights immediately before `visiblehelicopter.LuaBridge.endFlights` removes unseen flights. It raises the custom Lua event `OnViewpointExtractionFlights`, without replacing the renderer's existing A-Life or Week One collectors. Another hook suppresses the duplicate native aircraft's visual sample only while an active shared/campaign extraction has a loaded replacement. A hook after `HelicopterAudio.update` positions the existing FMOD event at that extraction aircraft and reapplies the original volume with Visible Helicopter Events' distance attenuation, hearing checks and terrain height. This prevents a distant native event from muting a nearby extraction model. It does not start a second sound or change the engine's helicopter coordinates. Isometric audio and unrelated helicopter events retain their original behavior. Disabling the addon or missing UH-1B assets leaves native rendering available.

The code runs on clients and consumes Extraction Mode's existing synchronization. In multiplayer the addon still has to be loaded by the session's mod configuration; persistence across a Lua reset on servers that omit the addon has not been implemented or verified.

## Build and local installation

With JDK 17 or newer available:

```powershell
.\build.ps1 -ZombieBuddyJar 'D:\SteamLibrary\steamapps\common\ProjectZomboid\ZombieBuddy.jar'
```

Copy `mod.info` and the complete `42` directory into `%UserProfile%\Zomboid\mods\ViewpointExtractionSupport`. Both the root and `42` metadata files are required. The resulting Java package is `maeiro.viewpointextractionsupport`.

## Validation

The regression suite uses Python with `lupa`'s Lua 5.1 runtime and executes the installed Visible Helicopter Events compatibility collector as part of the integration checks:

```powershell
python tests/run.py --visible-helicopter-root 'D:\SteamLibrary\steamapps\workshop\content\108600\3819322670\mods\VisibleHelicopterEvent'
.\tests\test_audio.ps1 -VisibleHelicopterJar 'D:\SteamLibrary\steamapps\workshop\content\108600\3819322670\mods\VisibleHelicopterEvent\42\media\java\client\VisibleHelicopterEvent.jar'
```

It covers authoritative site selection, interpolated countdowns, delayed packets, approach/hover/departure, elevated sites, cancellation, duplicate observers, simultaneous raids, readiness fallback, disabled/missing dependencies, stale multiplayer state and cleanup without removing other mods' aircraft. Audio checks reuse the installed renderer's attenuation code with FMOD and listener fixtures to verify model coordinates, terrain/altitude conversion, hearing rules, isometric behavior and reuse of the existing event.

Helicopter visibility, flight animation and native directional extraction audio have been manually verified in single-player with the required mods enabled. Multiplayer behavior still requires an in-game test.

Credits: Zakreon (Extraction Mode), 50ShadesOfMyCow (Visible Helicopter Events), User (UH-1B Helicopter), and the authors of Project Viewpoint, ZombieBuddy and Aviation Core.
