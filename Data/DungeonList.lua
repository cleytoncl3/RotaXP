-- Masmorras para leveling (Horda), 28-60.
-- kills = mortes aproximadas numa run completa (estimativa); níveis dos mobs: banco do Questie / guias do Forever.
-- Entradas: QuestieDB (support/Forever/Zones/dungeons.lua). Masmorras novas do Forever: níveis de timesaver.gg.
local _, RX = ...

RX.DungeonList = {
    { name = "City of Dalaran", area = 16544, forever = true, min = 28, max = 33, kills = 110, map = 1416, x = 8.5, y = 59.2, where = "Alterac" },
    { name = "Scarlet Monastery: Graveyard", area = 796, wingPT = "Cemitério", wingEN = "Graveyard", min = 30, max = 34, kills = 60, map = 1420, x = 82.5, y = 33.3, where = "Tirisfal Glades" },
    { name = "Scarlet Monastery: Library", area = 796, wingPT = "Biblioteca", wingEN = "Library", min = 32, max = 37, kills = 80, map = 1420, x = 82.5, y = 33.3, where = "Tirisfal Glades" },
    { name = "Scarlet Monastery: Armory", area = 796, wingPT = "Arsenal", wingEN = "Armory", min = 35, max = 39, kills = 90, map = 1420, x = 82.5, y = 33.3, where = "Tirisfal Glades" },
    { name = "Scarlet Monastery: Cathedral", area = 796, wingPT = "Catedral", wingEN = "Cathedral", min = 37, max = 41, kills = 100, map = 1420, x = 82.5, y = 33.3, where = "Tirisfal Glades" },
    { name = "The Drowned City", forever = true, min = 35, max = 40, kills = 110, map = 1434, x = 24.5, y = 22.6, where = "Stranglethorn (Vile Reef)" },
    { name = "Razorfen Downs", area = 722, min = 37, max = 42, kills = 120, map = 1441, x = 41.5, y = 29.4, where = "Thousand Needles" },
    { name = "Krol'dok Stronghold", area = 17780, forever = true, min = 40, max = 45, kills = 120, map = 2548, where = "Riverglades", outdoor = true },
    { name = "Uldaman", area = 1337, min = 41, max = 47, kills = 140, map = 1418, x = 41.7, y = 11.6, where = "Badlands" },
    { name = "Zul'Farrak", area = 1176, min = 44, max = 50, kills = 150, map = 1446, x = 39.2, y = 21.3, where = "Tanaris" },
    { name = "Maraudon", area = 2100, min = 46, max = 52, kills = 160, map = 1443, x = 29.1, y = 62.6, where = "Desolace" },
    { name = "Alcaz Prison", forever = true, min = 48, max = 53, kills = 130, map = 1445, x = 77, y = 18, where = "Dustwallow (Alcaz Island)", approx = true },
    { name = "Sunken Temple", area = 1477, min = 50, max = 56, kills = 150, map = 1435, x = 69.7, y = 53.5, where = "Swamp of Sorrows" },
    { name = "Blackrock Depths", area = 1584, min = 52, max = 60, kills = 260, map = 1428, x = 21, y = 37.9, where = "Blackrock Mountain" },
    { name = "Blackmaw Hold", area = 1216, forever = true, min = 55, max = 60, kills = 140, map = 1447, where = "Azshara" },
    { name = "Lower Blackrock Spire", area = 1583, wingPT = "Inferior", wingEN = "Lower", min = 55, max = 60, kills = 180, map = 1428, x = 21, y = 37.9, where = "Blackrock Mountain" },
    { name = "Dire Maul: East", area = 2557, wingPT = "Leste", wingEN = "East", min = 55, max = 60, kills = 90, map = 1444, x = 64.8, y = 30.2, where = "Feralas" },
    { name = "Dire Maul: West", area = 2557, wingPT = "Oeste", wingEN = "West", min = 57, max = 60, kills = 110, map = 1444, x = 60.3, y = 30.2, where = "Feralas" },
    { name = "Shaper's Terrace", area = 16985, forever = true, min = 58, max = 60, kills = 140, map = 1449, where = "Un'Goro Crater" },
    { name = "Stratholme", area = 2017, min = 58, max = 60, kills = 200, map = 1423, x = 27.7, y = 11.5, where = "Eastern Plaguelands" },
    { name = "Scholomance", area = 2057, min = 58, max = 60, kills = 190, map = 1422, x = 69.7, y = 73.2, where = "Western Plaguelands" },
}

-- Quantos níveis acima do nível MÁXIMO da masmorra cada classe precisa para solar com conforto (regra prática)
RX.SoloMargin = {
    PALADIN = 5, WARLOCK = 4, HUNTER = 4, MAGE = 5, DRUID = 5, SHAMAN = 5, WARRIOR = 7, PRIEST = 6, ROGUE = 6,
}
