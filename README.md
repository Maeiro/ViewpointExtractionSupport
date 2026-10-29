# Viewpoint Extraction Support

Displays a randomly selected, enabled aircraft during Extraction Mode pickups in Project Viewpoint. The aircraft approaches the selected extraction point during the final approach countdown, lowers a 3D rope as it settles into a hover, and flies away with the rope retracting when the pickup ends or is cancelled. A translucent yellow cylindrical marker identifies the boarding area in the 3D world.

This is a compatibility addon for **Visible Helicopter Events**. It uses that mod's existing renderer and the selected aircraft assets; no third-party models, textures or renderer code are redistributed.

## Requirements

- Project Zomboid Build 42.21+.
- [Extraction Mode](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275) (initial integration targets 0.9.75).
- [Project Viewpoint](https://steamcommunity.com/sharedfiles/filedetails/?id=3809306528).
- ZombieBuddy 2.3.4+.
- [Project Viewpoint - Visible Helicopter Events](https://steamcommunity.com/sharedfiles/filedetails/?id=3819322670) (initial integration targets 1.3.7).
- Aircraft are optional. Enable only the aircraft mods you want to use, then select those aircraft in this addon's options. An aircraft is used only when its checkbox is selected and its model assets are available.
- Optional aircraft supported by Visible Helicopter Events: UH-1B Helicopter (also needs Aviation Core), MH-92 Nightfang (`AircraftMod`), Little Bird (`LittleBird`), Chinook (`Chinook`), Black Hawk (`BlackHawk`), UH-1 Huey (`UH1`), and AH-1 SuperCobra (`AH1SuperCobra`).
- Optional FTZ aircraft: Hummingbird, Orca and Hellcat from [FTZ Helicopters](https://steamcommunity.com/sharedfiles/filedetails/?id=3825500218), which also requires [FTZ Flying](https://steamcommunity.com/sharedfiles/filedetails/?id=3825500587). These three models are registered into the existing Visible Helicopter Events renderer at runtime. Selecting an FTZ model also makes it available to Visible Helicopter Events' own random model selection when that setting is enabled.

Enable these mods and **Viewpoint Extraction Support**, then restart the game to load its Java hooks. Keep **Show event aircraft** enabled in Visible Helicopter Events. Signal a pickup using Extraction Mode's normal controls; the final approach normally begins with 30 seconds remaining. The campaign handoff uses its own 60-second approach window.

## Settings

In **Mod Options > Viewpoint Extraction Support**:

- **Show extraction helicopter**: enabled by default.
- **Hover height (metres)**: 6–30 metres above the extraction point's floor; default 12.
- **Show extraction area in 3D**: enabled by default. Displays every known extraction point as a yellow cylinder fading toward its top, even before a pickup is active. During boarding, the active rope's authoritative interaction radius replaces the point marker. This option works independently of the addon's helicopter display option. The matching extraction arrow is hidden in Viewpoint when the marker is rendered.
- **Show Extraction Mode HUD only with inventory open**: disabled by default. When enabled, hides Extraction Mode's top panel unless the player inventory, loot window or supported inventory interface is open.
- **Use NeatUI styling for Extraction Mode menus**: enabled by default. When `NeatUI_Framework` is installed, applies its panel and button styling to the Extraction Mode HUD and menus. If NeatUI is missing, the normal Extraction Mode interface is used automatically; disabling this option always uses the normal interface.
- **Aircraft selection**: UH-1B is enabled by default to preserve the previous behavior. Other aircraft are off by default. Each extraction flight randomly selects one of the checked aircraft whose assets are currently available. If none of the selected models are available, the addon does not create a helicopter for that flight.

English and Brazilian Portuguese interface text is included. Extraction timing, boarding interactions, zombie attraction and sound playback remain owned by Extraction Mode. With Viewpoint's directional aircraft audio enabled, the original native helicopter recording follows the extraction model's position and altitude. This addon creates visual aircraft, not physical vehicles or extra extraction destinations.

## Integration

The addon reads the existing `ExtractionMode.ClientStates` snapshots, including the selected extraction site, extraction countdown, boarding rope and publicly supplied nearby PvPvE pickups. It never queries hidden raids or sends location requests to the server. Duplicate observations from local players share one aircraft identity.

Motion uses Extraction Mode's simulation clock, so single-player pause and time acceleration follow the original extraction timer. Between countdown updates the approach continues smoothly. Ending a pickup starts an eight-second departure from the aircraft's current position. Multiplayer snapshots older than five seconds stop supplying active pickups until fresh snapshots arrive.

A small ZombieBuddy hook submits the addon flights immediately before `visiblehelicopter.LuaBridge.endFlights` removes unseen flights. It raises the custom Lua event `OnViewpointExtractionFlights`, without replacing the renderer's existing A-Life or Week One collectors. Another hook suppresses the duplicate native aircraft's visual sample only while an active shared/campaign extraction has a loaded replacement. A hook after `HelicopterAudio.update` positions the existing FMOD event at that extraction aircraft and reapplies the original volume with Visible Helicopter Events' distance attenuation, hearing checks and terrain height. This prevents a distant native event from muting a nearby extraction model. It does not start a second sound or change the engine's helicopter coordinates. Isometric audio and unrelated helicopter events retain their original behavior. Disabling the addon or missing UH-1B assets leaves native rendering available.

The code runs on clients and consumes Extraction Mode's existing synchronization. In multiplayer the addon still has to be loaded by the session's mod configuration; persistence across a Lua reset on servers that omit the addon has not been implemented or verified.

Extraction point areas use the server-supplied site coordinates and radius and remain visible while the site is inactive. An active boarding rope temporarily replaces the matching point with its authoritative boarding radius. A 32-segment cylinder, 2.2 metres high, uses a small alpha-gradient texture in Viewpoint's decal batch. Its vertical segments follow terrain relief instead of relying on a single flat circle that can intersect uneven terrain. Both surface orientations are submitted to support viewpoints inside and outside the marker. It is added after the regular decal snapshot, including when blood decals are disabled, and does not create world objects or blood data. Areas are drawn only within 100 tiles on a loaded floor.

The extraction rope starts as a small coil beneath the helicopter, unspools during the final approach, reaches the extraction floor while boarding, and retracts as the aircraft departs. Viewpoint renders it as a six-sided 3D tube whose 12 constrained segments respond to gravity, wind and ground contact. This is a client-side visual simulation: it does not create a world object, add server physics, or change boarding rules. Its texture and geometry are included with this addon.

Arrow filtering tracks arrows created with Extraction Mode's `Item_Rope2` texture, then checks their exact destination against successfully rendered boarding areas. Only their draw-time active state is temporarily changed, with restoration on method exit. Isometric arrows, other destinations, inactive arrows and unrelated arrow textures retain their existing behavior. A missing marker texture or full render batch leaves the original extraction arrow available. Boarding input remains managed by Extraction Mode.

When the player aims at the rendered boarding area in Viewpoint, the interaction menu also exposes Extraction Mode's `Board Extraction Helicopter` action. While the helicopter is actually boarding, temporary invisible passable client-only targets cover empty outdoor tiles inside the rope radius so the Viewpoint ray picker can open the menu even when no world object is under the crosshair. They are removed as soon as boarding is unavailable and never enter the save or server world. The action uses the original client boarding helper and remains limited to the participant's active rope, its floor and its interaction radius. Vehicle and already-boarding states remain disabled as in the vanilla menu.

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
.\tests\test_ground.ps1 -ViewpointJar 'D:\SteamLibrary\steamapps\workshop\content\108600\3809306528\mods\Viewpoint\42\media\java\client\Viewpoint.jar'
```

It covers authoritative site selection, interpolated countdowns, delayed packets, approach/hover/departure, elevated sites, cancellation, duplicate observers, simultaneous raids, readiness fallback, disabled/missing dependencies, stale multiplayer state and cleanup without removing other mods' aircraft. Audio checks reuse the installed renderer's attenuation code with FMOD and listener fixtures to verify model coordinates, terrain/altitude conversion, hearing rules, isometric behavior and reuse of the existing event. Marker checks submit to the installed Viewpoint decal batch and verify a closed cylinder, inside/outside faces, radius, gradient UVs, camera motion, elevated floors, unavailable assets and independent option handling. Arrow checks cover destination/texture matching, isometric fallback, original active state and restoration after drawing.

The UH-1B flight, rope, positional audio and extraction markers have been manually verified in single-player. The optional aircraft model integrations, including FTZ aircraft, still need an in-game visual check. Multiplayer behavior also remains to be verified.

Credits: Zakreon (Extraction Mode), 50ShadesOfMyCow (Visible Helicopter Events), User (UH-1B Helicopter), the FTZ Helicopters authors, and the authors of Project Viewpoint, ZombieBuddy and Aviation Core.
