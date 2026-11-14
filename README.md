# RouteXP — Horde Leveling & Quest Guide (WoW: Forever)

**RouteXP** is a free leveling guide for the **Horde, from level 1 to 60**, made for **WoW: Forever**. It is still being worked on: **the guides from level 30 to 60 are ready today**, and the guides for levels 1 to 30 are coming next. For now it is **Horde only**.

RouteXP **detects your character's level in game and gives you the right guide for it**. It tells you which quest to take, where to go and what to do next, and it **draws the way on the map like a GPS** (the route a Google Maps would give you), so players who don't know the World of Warcraft map can reach every place the fastest way. Hold **Ctrl** and click on the world map to mark a route from one point to another: it is shared at once with everyone in your group who also uses RouteXP.

**Languages:** English (enUS), Portuguese (ptBR) and Spanish (esES / esMX). The addon follows your game client language automatically, with quest and NPC names in your language. RouteXP was formerly called RotaXP.

## Features

- **Leveling guides**: speedrun routes and full guides for every zone, including the new WoW: Forever zones (Riverglades, Shen'dralas, Mount Hyjal).
- **Styles you can combine**: Speedrun, Duo, Full, skip collecting quests with more than 10 or 5 dropped items, skip slow quests, show dungeon and elite quests.
- **Navigation**: arrow, route line on the world map and minimap, flight paths and boats, and optional TomTom waypoints.
- **Smart route**: does what is close to you before sending you back to town to turn in, and adds the quests from your log that belong to other zones.
- **Auto accept / turn in by quest ID**: only quests that belong to your guide (hold **Shift** to turn it off on the spot). `/rota accept` shows the last decisions and why.
- **Quest icons**: the ! / ? shows the quest status, and a second icon shows the type (sword = kill, bag = collect drops, gear = pick up / interact, speech bubble = talk only). A preview shows what the quest asks before you accept it.
- **Prerequisite chains**: when a quest of the guide needs earlier quests that are not in the guide (e.g. the quest line that unlocks an NPC), the guide shows those prerequisite quests in its place, marked `[prerequisite]`, with where to pick them up and which quest they unlock. It never lists a turn-in for a quest you have not taken, and it warns when an NPC does not offer a quest the guide expected.
- **Route along the terrain**: RouteXP ships a walkability map of Kalimdor and the Eastern Kingdoms, built from the WoW: Forever terrain (slopes, cliffs, deep water and road textures, in 16-yard cells). The route line on the map and minimap takes the shortest walkable way: it goes around mountains and cliffs and prefers roads, instead of a straight line. It is computed over a few frames, so it never freezes the game. Where the map cannot find a way (an elevator, a cave, a building) it also uses the trails you ran, and otherwise stays straight and dimmer. It can be turned off in Options > Navigation.
- **Pick a quest**: click a quest in the list to pick it: it gets a gold border, moves to the top, and the arrow and route line lead to it (on foot along the terrain, or by flight/boat when needed) until you turn it in, skip it or pick another (Ctrl+click clears the pick).
- **Marked route for the group**: on the world map, **Ctrl + right click** marks the start and **Ctrl + left click** the destination. RouteXP draws the way in blue (on foot along the terrain and roads, plus any flight, zeppelin or boat), lists the legs in a small window, and sends it at once to everyone in your group who has RouteXP.
- **Turn-in mode** and **Nearby mode** (closest quests from every guide).
- **Quest log counter**: the top of the window always shows how many quests you have, e.g. *Quests 23/25* (green, yellow when almost full, red when full).
- **Where to level**: advice for your current zone and level, and zone suggestions.
- **Dungeons and open-world grinding**: dungeons for your level with XP per hour, **gold + XP farming spots** (solo and duo) with estimated XP/h and gold/h and the best-paying drops, farming gear (GearQuest) and talents (Talents Forever).
- **Group sharing**: group members with RouteXP share the guide, quest progress (e.g. `Friend: Basilisk 2/10`) and marked spots through the game's own addon channel (no internet). Players who only use Questie also show up. A **Share quests** button shares every guide quest in your log with the group (`/rota share`).
- **Quest item window**: buttons to use the items your quests need, with an optional key binding (Options > Key Bindings > AddOns > RouteXP).
- **Auction House helper** (with Auctionator): each quest that needs tradeable items shows that you can buy them instead of farming, a shopping list opens when you pick a guide (`/rota shop`), and the Auction House offers a one-click search (`/rota ah`).
- **Abandon helpers**: an *abandon quest* link on every quest of the list, optional auto-abandon of slow, low-XP or off-guide quests (`/rota keep` cancels), and a one-time question about grey / low-XP quests in your log, class quests included (`/rota review`).
- **Clear current guide** empties the list so you can pick another guide, without abandoning anything in the game (`/rota clear`).
- **Show hidden quests** of the current guide when your style hides everything (good for leftovers).
- **Farm timer**: XP per hour and **gold per hour** (coins looted from mobs, your share in a group, and the vendor value of looted items, plus the Auction House value with Auctionator). The buttons always sit below the text; drag the corner to change the width, Ctrl + mouse wheel for the text size.
- **Minimize**: the guide becomes a small round icon; click it to bring the guide back. The same icon is on the minimap.
- **Quiet chat**: RouteXP only writes to chat when you type a `/rota` command, and TomTom / map pin waypoint notices are hidden (Options > Quality of life > Chat).
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

---

> **Disclaimer:** RouteXP is made **exclusively for WoW: Forever** (for now) and is an independent project, not affiliated with other leveling guides such as RestedXP or Zygor. This version of WoW has many new and changed quests, so the guide **may still have some errors** (a quest in the wrong place, a missing quest, an odd step order). It is actively being improved. Please report problems in the issues, with the quest name and zone.
