# Extraction Mode PDA Integration

An optional companion mod that places Extraction Mode's interface inside the Extraction tab of the ProjectRPGExpanded Survivor PDA. It also provides an overview dashboard, mission tracking, the PDA start-tab option, and Brazilian Portuguese text based on the PDA's selected language.

## Requirements

- Project Zomboid Build 42.21 or newer.
- [Extraction Mode](https://steamcommunity.com/sharedfiles/filedetails/?id=3785397275).
- [ProjectRPGExpanded](https://steamcommunity.com/sharedfiles/filedetails/?id=3826426915).

The integration checks the PDA methods it uses before installing hooks. If the installed PDA version is incompatible, Extraction Mode's original screens remain available. Administrative and debug actions continue to use Extraction Mode's own permission checks and commands.

The integration is independent of Viewpoint Extraction Support. Install this mod alongside its two requirements to add the PDA interface.

## Features

- Adds an Extraction tab and makes it available as the PDA's initial screen.
- Routes Extraction Mode's destination, upgrade, contact, garage, deploy, social, administrative, and debug screens through the PDA.
- Provides a dashboard with destination selection, raid readiness, hideout generator controls, and a mission summary.
- Shows a contextual board button in Operation Status while Extraction Mode makes boarding available, using its native action.
- Lets each character select an unfinished mission to track, showing its objectives and requirements on the dashboard.
- Explains that raids have no fixed end time and shows the next horde or wave timing when Extraction Mode provides it.
- Adds a Zombies category to ProjectRPGExpanded's server settings with per-stage Custom World Danger controls for zombie behavior, perception, infection, and respawn rules.
- Uses the PDA's internal language selection for English and Brazilian Portuguese text.
- Keeps Extraction Mode's native HUD hidden while its interface is active in the PDA, hides the ProjectRPGExpanded player portrait while the world map is open to prevent map icon rendering issues, and keeps the player card behind Ergonomic UI.

## Local installation

Copy `content\mods\ExtractionModePDA` into `%UserProfile%\Zomboid\mods\ExtractionModePDA`, then enable **Extraction Mode PDA Integration**, **Extraction Mode**, and **ProjectRPGExpanded** in the same game or server configuration and restart the game.

For Workshop packaging, use the `content` folder as the upload content folder. It contains the required `mods\ExtractionModePDA` directory.

## Validation

The source repository's integration specifications use Python with `lupa`'s Lua 5.1 runtime:

```powershell
python tests/extraction_mode_pda/run.py
```
