# TA: Escalation for Open Annihilation

Play [Total Annihilation: Escalation](https://taesc.tauniverse.com) (TAESC)
in [Open Annihilation](https://github.com/open-annihilation/open-annihilation),
the open re-implementation of Total Annihilation, through its
[mod system](https://github.com/open-annihilation/open-annihilation/tree/main/docs/mods).

This repository holds an Open Annihilation mod profile (`mod/oamod.yaml`) for
TAESC GOLD 10.2.0 and scripts that build the mod from your own TAESC install.
It holds no TAESC or Total Annihilation files.

> Unofficial. Not made by, or affiliated with, the TA Escalation team, the
> Open Annihilation project, or the owners of Total Annihilation.

## What you need

- **Total Annihilation** with **Core Contingency** and **Battle Tactics**
  (the GOG or Steam release has all three), set up in Open Annihilation.
- **Open Annihilation 0.9.1** or later.
- **TAESC GOLD 10.2.0**, installed from [taesc.tauniverse.com](https://taesc.tauniverse.com).
  The scripts can't download it for you: the site checks for bots, and TAESC's
  files are the TAESC team's to distribute. Install it the usual way first, on
  Windows or in CrossOver, Wine, Bottles or Lutris.

## Install

macOS or Linux:

```bash
git clone https://github.com/itconor/taesc-open-annihilation.git
cd taesc-open-annihilation
./install.sh
```

Windows (PowerShell):

```powershell
git clone https://github.com/itconor/taesc-open-annihilation.git
cd taesc-open-annihilation
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

The script finds TAESC (CrossOver bottles, `~/.wine`, Bottles, Lutris,
`~/Games`, `C:\GOG Games` and the usual Windows folders), copies its archives,
`TAESC.ini`, megamap icons and music next to the profile, checks the profile with
Open Annihilation when it finds the game, and installs the mod in
`Documents/Open Annihilation/Mods/taesc`. A copy already there is moved to
`Documents/Open Annihilation/Mod backups/taesc-<date>`, never deleted.

Options:

| macOS / Linux | Windows | What it does |
| --- | --- | --- |
| `--source PATH` | `-Source PATH` | Use the TAESC folder, or TAESC `.zip`, at `PATH` instead of searching |
| `--package FILE` | `-Package FILE` | Build a `.oamod` file instead; open it with Open Annihilation to install it |
| `--mods-dir DIR` | `-ModsDir DIR` | Install into `DIR` instead of the usual Mods folder |

Then in Open Annihilation: **OA** on the main menu, **Mods**, **TA: Escalation**,
**Play now**. Core Contingency and Battle Tactics must be switched on.

## What the profile does

Everything was read from TAESC 10.2.0 itself: the strings in its `TotalA.exe`,
the data in its archives, `taesc.dll`'s start-up log, its demo recorder and its
release notes.

- **Archives and folders:** `TAESC.gp3` is the revision archive (`rev31.gp3` is not
  mounted). Data comes from TAESC's renamed folders (`unitsE`, `weaponE`,
  `gamedatE`, `aE`, `guiE`, `unitpicE`, `downloadsE`), and maps place units
  under `[unitsE]`.
- **Settings:** read from `TAESC.ini`, registry values kept under `Software\TA Esc`.
- **Limits:** unit types (TAESC has 549, past 3.1c's 512) and category masks,
  1,000 units a player, TAESC's effect, pathfinding and model-buffer sizes,
  and unlimited build lists.
- **Unit scripts:** values 32, 69, 70 and 71 (kills, unit ids).
- **Unit and weapon keys:** veterancy thresholds, build-preview pieces,
  `nottoair`, `surfacefire`, `nottounderwater`.
- **About 40 standard hacks** that TAESC has, among them:
  - veterancy by thresholds, the repair-rate fix, the share-abuse guard and
    the unit-ID reuse delay;
  - mobile factories, vote-to-reject, team start positions;
  - the megamap, whiteboard, line and ring building, click-snap and nanoframe
    previews;
  - the TA Demo Recorder's commands (`.cmdwarp`, `.take`, `.syncon`,
    `.autopause` and the rest).

### Not confirmed yet

About 20 exe-level hacks are listed, commented out, at the bottom of
`mod/oamod.yaml`, among them weapons-free while building, high-arc fire,
retargeting and the AI tweaks. TAESC's patched exe may carry them, but nothing
published says so. To try one, turn on **Settings → Developer → Enable Developer
Mode**, switch the hack on, and compare with TAESC itself. If it matches, open
an issue or a pull request.

## Tested

- **macOS:** `install.sh` against a CrossOver install of TAESC 10.2.0, and
  against a `.zip` of it, with Open Annihilation 0.9.1. The profile resolves,
  the main menu shows TAESC's art, and a skirmish starts with all 549 TAESC
  unit types and their weapons.
- **`--package`:** builds the `.oamod` file, but installing it through Open
  Annihilation's own installer hasn't been tried yet. The default folder install
  is the tested route.
- **Windows:** `install.ps1` has not been run on Windows yet. Reports welcome.
- **Network play** against players on TAESC's own `TotalA.exe` has not been tested.

## Credits

TA: Escalation is the work of the TA Escalation team; see their site and
Discord for the mod itself. Open Annihilation is the work of its contributors.
Total Annihilation was made by Cavedog Entertainment. All trademarks belong to
their owners.

The scripts and profile here are under the MIT licence (`LICENSE`).
