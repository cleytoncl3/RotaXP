# RouteXP — Horde Leveling & Quest Guide (WoW: Forever)

**RouteXP** is an in-game leveling and questing guide for the **Horde, levels 30–60**, made for **WoW: Forever**, in the style of Zygor and RestedXP. It tells you which quest to take, where to go and what to do next. The in-game text follows your client language (English or Brazilian Portuguese). RouteXP was formerly called RotaXP.

> **Disclaimer:** RouteXP is made **exclusively for WoW: Forever** (for now). This version of WoW has many new and changed quests, so the guide **may still have some errors** (a quest in the wrong place, a missing quest, an odd step order). It is actively being improved. Please report problems in the issues, with the quest name and zone.

## Features

- **Leveling guides**: speedrun routes and full guides for every zone, including the new WoW: Forever zones (Riverglades, Shen'dralas, Mount Hyjal).
- **Styles you can combine**: Speedrun, Duo, Full, skip collecting quests with more than 10 or 5 dropped items, skip slow quests, show dungeon and elite quests.
- **Navigation**: arrow, route line on the world map and minimap, flight paths and boats, and optional TomTom waypoints.
- **Smart route**: does what is close to you before sending you back to town to turn in, and adds the quests from your log that belong to other zones.
- **Auto accept / turn in by quest ID**: only quests that belong to your guide (hold **Shift** to turn it off on the spot). `/rota accept` shows the last decisions and why.
- **Quest icons**: the ! / ? shows the quest status, and a second icon shows the type (sword = kill, bag = collect drops, gear = pick up / interact, speech bubble = talk only). A preview shows what the quest asks before you accept it.
- **Prerequisite chains**: when a quest of the guide needs earlier quests that are not in the guide (e.g. the quest line that unlocks an NPC), the guide shows those prerequisite quests in its place, marked `[prerequisite]`, with where to pick them up and which quest they unlock. It never lists a turn-in for a quest you have not taken, and it warns when an NPC does not offer a quest the guide expected.
- **Route along the terrain**: RouteXP ships a walkability map of Kalimdor and the Eastern Kingdoms, built from the WoW: Forever terrain (slopes, cliffs, deep water and road textures, in 16-yard cells). The route line on the map and minimap takes the shortest walkable way: it goes around mountains and cliffs and prefers roads, instead of a straight line. It is computed over a few frames, so it never freezes the game. Where the map cannot find a way (an elevator, a cave, a building) it also uses the trails you ran, and otherwise stays straight and dimmer. It can be turned off in Options > Navigation.
- **Pick a quest**: click a quest in the list to pick it: it moves to the top and the arrow points to it until you turn it in, skip it or pick another (Ctrl+click clears the pick).
- **Turn-in mode** and **Nearby mode** (closest quests from every guide).
- **Where to level**: advice for your current zone and level, and zone suggestions.
- **Dungeons and open-world grinding**: dungeons for your level with XP per hour, **gold + XP farming spots** (solo and duo) with estimated XP/h and gold/h and the best-paying drops, farming gear (GearQuest) and talents (Talents Forever).
- **Group sharing**: group members with RouteXP share the guide, quest progress (e.g. `Friend: Basilisk 2/10`) and marked spots through the game's own addon channel (no internet). Players who only use Questie also show up. A **Share quests** button shares every guide quest in your log with the group (`/rota share`).
- **Quest item window**: buttons to use the items your quests need, with an optional key binding (Options > Key Bindings > AddOns > RouteXP).
- **Auction House helper** (with Auctionator): each quest that needs tradeable items shows that you can buy them instead of farming, a shopping list opens when you pick a guide (`/rota shop`), and the Auction House offers a one-click search (`/rota ah`).
- **Abandon helpers**: an *abandon quest* link on every quest of the list, optional auto-abandon of slow, low-XP or off-guide quests (`/rota keep` cancels), and a one-time question about grey / low-XP quests in your log, class quests included (`/rota review`).
- **Clear current guide** empties the list so you can pick another guide, without abandoning anything in the game (`/rota clear`).
- **Show hidden quests** of the current guide when your style hides everything (good for leftovers).
- **XP timer** on the main window; drag the corner of the timer window to resize it.
- **Minimize**: the guide becomes a small round icon; click it to bring the guide back. The same icon is on the minimap.
- **Tabbed options**: Guide & style, Automation, Quality of life, Auction House, Navigation and Appearance.
- **Blocked action log**: `/rota blocked`.

## Install

1. **Download: [RouteXP.zip](https://github.com/cleytoncl3/RouteXP/releases/latest/download/RouteXP.zip)** (always the latest version).
2. **Double-click** `RouteXP.zip` to open it. Inside there is only one folder: **`RouteXP`**.
3. **Drag that `RouteXP` folder** into `World of Warcraft\_forever_\Interface\AddOns\`.
4. Check: you must end up with `Interface\AddOns\RouteXP\RouteXP.toc`. In game, type `/rota`.

> Do **not** use the green **Code → Download ZIP** button: it gives a `RouteXP-main` folder that the game won't load.
> If you used Windows **Extract All**, it adds an extra outer folder named after the zip: open it and move only the inner **`RouteXP`** folder (the one that has `RouteXP.toc` inside).

## Update

With the game closed, double-click **`Atualizar-RouteXP.bat`** inside the addon folder. It downloads the newest version into `Interface\AddOns\RouteXP` and replaces the files. Your settings live in the `WTF` folder and are kept. Then log in.

**Coming from the old name (RotaXP)?** Close the game and run `Atualizar-RouteXP.bat` from the old `RotaXP` folder: it installs RouteXP in the right folder, copies your RotaXP settings and progress, and deletes the old folder.

If WoW is installed in *Program Files* and you get a permission error, right-click the `.bat` and choose **Run as administrator**.

In game, `/rota update` shows the installed version. If someone in your group has a newer version, the addon tells you.

## Commands

`/rota` or `/routexp` shows/hides · `/rota help` lists all commands · `/rota options` · `/rota turnin` · `/rota nearby` · `/rota farm` · `/rota timer` · `/rota items` · `/rota shop` · `/rota share` · `/rota review` · `/rota clear` · `/rota keep` · `/rota accept` · `/rota blocked` · `/rota update`

## Optional addons

TomTom (arrow and waypoints), Questie (quest data and group progress), Auctionator (Auction House prices and search), GearQuest Forever (gear), Talents Forever (talents). RouteXP works without them.

## Credits and license

RouteXP is released under the **GPL-3.0** (see `LICENSE`). It uses data and code from these projects, with our thanks:

| What | Source | License |
|---|---|---|
| Quests, NPCs, objects, locations, prerequisites and Portuguese names | [Questie](https://github.com/Questie/Questie) (QuestieDB) | GPL-3.0 |
| Loot tables and vendor prices (best-paying drops of the gold farming spots) | [cmangos classic-db](https://github.com/cmangos/classic-db) | GPL-2.0 |
| Minimap button | LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 (in `Libs/`) | each library's own license |
| Zone order of the routes (reference only; the quest-by-quest guides were built for this project) | wowforeverinfo.com, warcraftmaps.com, topbuilds.gg | — |

The icon, the zone guides, the routes and the RouteXP code were made for this project.
