# Viewpoint Extraction Support

Displays a randomly selected, enabled aircraft during Extraction Mode pickups in Project Viewpoint. The aircraft approaches the selected extraction point during the final approach countdown, lowers a 3D rope as it settles into a hover, and flies away with the rope retracting when the pickup ends or is cancelled. A translucent yellow cylindrical marker identifies the boarding area in the 3D world.

This is a compatibility addon for **Visible Helicopter Events**. Aircraft use that mod's existing renderer and the selected aircraft assets; aircraft models, textures and renderer code are not redistributed. The extraction flare gun uses an included CC0 model by Quaternius, adapted for Zomboid, with its source and credits in `assets/flaregun`.

The Extraction Mode interface for ProjectRPGExpanded is available separately as the optional [Extraction Mode PDA Integration](https://steamcommunity.com/sharedfiles/filedetails/?id=3831366933). It requires ProjectRPGExpanded and does not add a dependency to this addon.

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
- **Show red extraction flares**: enabled by default. Firing Extraction Mode's flare gun produces an emissive red signal that rises and slowly descends, with a red smoke trail, for 20 simulation seconds. The effect uses Viewpoint's native flame/smoke batch, including depth occlusion. It is visible in Viewpoint and does not create fire, damage, extra noise or additional extraction requests. The gun also has a dedicated 3D model and inventory icon; existing carried guns are updated on player creation or equipping. Its original ammunition, sound, damage and extraction behavior are preserved. In multiplayer, the shooter's effect starts immediately and the server relays the visual to other players within 150 tiles; the addon must be enabled on both sides for those remote effects. The server supplies the position and direction and limits repeated requests.
- **Hide PDA player HUD in Viewpoint inventory**: enabled by default. Temporarily hides the optional ProjectRPGExpanded player card, battery panel, portrait and level badge while the Viewpoint UI inventory screen is open. Restores the card according to the PDA visibility settings when closed. Vanilla and Ergonomic UI inventories do not trigger this option.
- **Show Extraction Mode HUD only with inventory open**: disabled by default. When enabled, hides Extraction Mode's top panel unless the player inventory, loot window or supported inventory interface is open.
- **Use NeatUI styling for Extraction Mode menus**: enabled by default. When `NeatUI_Framework` is installed, applies its panel and button styling to the Extraction Mode HUD and menus. If NeatUI is missing, the normal Extraction Mode interface is used automatically; disabling this option always uses the normal interface.
- During a deployment countdown, a green on-screen notice repeats the destination and remaining seconds, updating as the timer counts down.
- During an active raid, an amber radio warning appears once when the next horde is within one in-game hour.
- **Aircraft selection**: UH-1B is enabled by default to preserve the previous behavior. Other aircraft are off by default. Each extraction flight randomly selects one of the checked aircraft whose assets are currently available. If none of the selected models are available, the addon does not create a helicopter for that flight.

Night Events, including configurable loot bonuses and sprinter chances, are provided by the separate **Survivor PDA Orchestrator** mod.

On the Project Viewpoint beta, full height hideout walls use the room color on the reverse face when the renderer selects a short Bunker or Railroad panel for that face.

English and Brazilian Portuguese interface text is included. Extraction timing, boarding interactions, zombie attraction and sound playback remain owned by Extraction Mode. With Viewpoint's directional aircraft audio enabled, the original native helicopter recording follows the extraction model's position and altitude. This addon creates visual aircraft, not physical vehicles or extra extraction destinations.

The flare effect follows Extraction Mode's simulation clock, including single-player pause and time acceleration. It is a cosmetic signal launched upward from the shooter, rather than a damaging ballistic projectile or a source of terrain lighting. Its visibility option is independent of the aircraft display. Lua resets, disconnection and returning to the main menu clear active signals. Flare assets require the addon on the server and clients in multiplayer; no original Extraction Mode files are replaced.

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

Flare Lua checks cover appearance migration, unchanged native commands, SP pause/expiry, MP position authority, duplicate requests, observer range and cleanup. `tests/test_flares.ps1` runs the new renderer against Viewpoint's actual `FlameDraws` class, checking native-card preservation, emissive flags, atlas UVs, terrain/floor height, capacity and asset readiness. Pass `-ViewpointJar`, `-CompileViewpointJar` and, if needed, `-JavaExe`; use a JDK/runtime that can read the installed Viewpoint class version, or a header-compatible compile JAR with the original JAR at runtime. The flare's final in-game alignment and appearance still need a visual check in SP and multiplayer.

The UH-1B flight, rope, positional audio and extraction markers have been manually verified in single-player. The optional aircraft model integrations, including FTZ aircraft, still need an in-game visual check. Multiplayer behavior also remains to be verified.

Credits: Zakreon (Extraction Mode), 50ShadesOfMyCow (Visible Helicopter Events), User (UH-1B Helicopter), the FTZ Helicopters authors, and the authors of Project Viewpoint, ZombieBuddy and Aviation Core.

Flare gun: [Quaternius, CC0](https://poly.pizza/m/44H9OBUqTC). Asset conversion, inventory icon and procedural signal textures are included with this addon. Rebuild them with `py tools/build_flare_assets.py` (NumPy and Pillow).
