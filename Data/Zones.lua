-- Onde upar (Horda) + dicas de speedrun  /  Where to level (Horde) + speedrun tips
local _, RX = ...

RX.Zones = {
    { map = 1434, sufPT = " (norte)", sufEN = " (north)", min = 30, max = 40, name = "Stranglethorn Vale (norte)", nameEn = "Stranglethorn Vale (north)", hub = "Grom'gol",
      note = "Nesingwary (tigres/panteras/raptors), trolls Bloodscalp, quests novas do Forever na Drowned City. Zepelim direto de Orgrimmar/Undercity.",
      noteEn = "Nesingwary (tigers/panthers/raptors), Bloodscalp trolls, new Forever quests in the Drowned City. Direct zeppelin from Orgrimmar/Undercity." },
    { map = 1443, min = 30, max = 40, name = "Desolace", hub = "Shadowprey Village",
      note = "Centauros (Khan), Kodo Graveyard, demônios de Mannoroc. Bom para emendar com Thousand Needles.",
      noteEn = "Centaurs (Khans), Kodo Graveyard, Mannoroc demons. Pairs well with Thousand Needles." },
    { map = 1417, min = 33, max = 40, name = "Arathi Highlands", hub = "Hammerfall",
      note = "Raptors, sigilos de Thoradin/Trollbane. Fácil de combinar com Hillsbrad.",
      noteEn = "Raptors, the Thoradin/Trollbane sigils. Easy to combine with Hillsbrad." },
    { map = 1441, sufPT = " (Shimmering Flats)", sufEN = " (Shimmering Flats)", min = 35, max = 42, name = "Thousand Needles (Shimmering Flats)", hub = "Mirage Raceway",
      note = "Quests de goblins/gnomos, muitas entregas rápidas.", noteEn = "Goblin/gnome quests, lots of quick deliveries." },
    { map = 2548, sufPT = "  [NOVO no Forever]", sufEN = "  [NEW in Forever]", min = 36, max = 46, name = "Riverglades  [NOVO no Forever]", nameEn = "Riverglades  [NEW in Forever]", hub = "Rog'mar", forever = true,
      note = "Zona nova! Navio de Tanaris para Powderfuse Port, a pé pelo norte de Redridge, ou 'Report to Rog'mar' em Grom'gol. Muitas quests juntas = XP rápido.",
      noteEn = "New zone! Ship from Tanaris to Powderfuse Port, on foot north of Redridge, or 'Report to Rog'mar' in Grom'gol. Lots of quests close together = fast XP." },
    { map = 2652, sufPT = "  [NOVO no Forever]", sufEN = "  [NEW in Forever]", min = 38, max = 43, name = "Shen'dralas / Valley of Bones  [NOVO no Forever]", nameEn = "Shen'dralas / Valley of Bones  [NEW in Forever]", hub = "Desolace (Uthek the Wise)", forever = true,
      note = "Quests novas de reputação Gelkis/Magram ao sul de Desolace.", noteEn = "New Gelkis/Magram reputation quests south of Desolace." },
    { map = 1445, min = 35, max = 45, name = "Dustwallow Marsh", hub = "Brackenwall Village",
      note = "Cadeia do Escudo Negro, ninhos de dragões. Voo para Brackenwall.", noteEn = "Black Shield chain, dragon nests. Fly to Brackenwall." },
    { map = 1418, min = 36, max = 45, name = "Badlands", hub = "Kargath",
      note = "Uldaman fica aqui. Quests do Lotwil e Rigglefuzz.", noteEn = "Uldaman is here. Lotwil and Rigglefuzz quests." },
    { map = 1435, min = 36, max = 45, name = "Swamp of Sorrows", hub = "Stonard",
      note = "Pequena, junte com Badlands. Sunken Temple fica aqui (50+).", noteEn = "Small, pair it with Badlands. Sunken Temple is here (50+)." },
    { min = 40, max = 40, name = "MONTARIA no nível 40", nameEn = "MOUNT at level 40", hub = "Capital da sua raça", hubEn = "Your race's capital",
      note = "No Forever há a quest 'Learning to Ride' / 'Your First Riding ...' no 40. Custa ~100 de ouro. É o maior ganho de velocidade do leveling.",
      noteEn = "Forever has the 'Learning to Ride' / 'Your First Riding ...' quest at 40. Costs ~100 gold. It's the biggest speed boost of the whole leveling." },
    { map = 1446, min = 40, max = 48, name = "Tanaris", hub = "Gadgetzan",
      note = "Wastewander, Steamwheedle Port, piratas. Zona central do 44-48.", noteEn = "Wastewander, Steamwheedle Port, pirates. The core 44-48 zone." },
    { map = 1444, min = 40, max = 48, name = "Feralas", hub = "Camp Mojache",
      note = "Ogros Gordunni, gnolls Woodpaw. Junte com Tanaris.", noteEn = "Gordunni ogres, Woodpaw gnolls. Pair it with Tanaris." },
    { map = 1425, min = 41, max = 50, name = "The Hinterlands", hub = "Revantusk Village",
      note = "Trolls Vilebranch, Wildhammer. Pegue o voo em Revantusk.", noteEn = "Vilebranch trolls, Wildhammer. Get the Revantusk flight path." },
    { map = 1434, sufPT = " (sul)", sufEN = " (south)", min = 42, max = 50, name = "Stranglethorn Vale (sul)", nameEn = "Stranglethorn Vale (south)", hub = "Booty Bay",
      note = "Piratas Bloodsail, Zanzil, capítulos de Nesingwary.", noteEn = "Bloodsail pirates, Zanzil, Nesingwary chapters." },
    { map = 1447, min = 45, max = 52, name = "Azshara", hub = "Valormok",
      note = "Várias quests novas do Forever em Valormok (Kurll, Izvi, Jediga).", noteEn = "Many new Forever quests in Valormok (Kurll, Izvi, Jediga)." },
    { map = 1427, min = 45, max = 52, name = "Searing Gorge", hub = "Thorium Point",
      note = "Quests de Kalaran e Thorium Brotherhood. Porta do Blackrock.", noteEn = "Kalaran and Thorium Brotherhood quests. Gateway to Blackrock." },
    { map = 1448, min = 47, max = 55, name = "Felwood", hub = "Bloodvenom Post",
      note = "Jaedenar, Timbermaw. Corrupted Songflower dá buff ótimo.", noteEn = "Jaedenar, Timbermaw. Corrupted Songflower gives a great buff." },
    { map = 1449, min = 48, max = 55, name = "Un'Goro Crater", hub = "Marshal's Refuge",
      note = "Muito XP, pilões de cristal, A-Me 01. Voo de Gadgetzan ou Cenarion Hold.", noteEn = "Lots of XP, crystal pylons, A-Me 01. Fly from Gadgetzan or Cenarion Hold." },
    { map = 1428, min = 50, max = 56, name = "Burning Steppes", hub = "Flame Crest",
      note = "Dragonkin, Blackrock. BRD/LBRS ao lado.", noteEn = "Dragonkin, Blackrock. BRD/LBRS next door." },
    { map = 1422, min = 50, max = 58, name = "Western Plaguelands", hub = "The Bulwark",
      note = "Cadeias de Andorhal e Scholomance.", noteEn = "Andorhal and Scholomance chains." },
    { map = 1452, min = 53, max = 60, name = "Winterspring", hub = "Everlook",
      note = "Yetis, Frostsaber, cadeia de Donova Snowden.", noteEn = "Yetis, Frostsabers, the Donova Snowden chain." },
    { map = 2482, sufPT = "  [NOVO no Forever]", sufEN = "  [NEW in Forever]", min = 54, max = 60, name = "Mount Hyjal  [NOVO no Forever]", nameEn = "Mount Hyjal  [NEW in Forever]", hub = "Elderwild", forever = true,
      note = "Zona nova do Forever para 54-60. Ao sul de Winterspring por Darkwhisper Gorge. Voos: Summit of Eternity e Tainted Foothills.",
      noteEn = "New Forever zone for 54-60. South of Winterspring through Darkwhisper Gorge. Flight points: Summit of Eternity and Tainted Foothills." },
    { map = 1423, min = 53, max = 60, name = "Eastern Plaguelands", hub = "Light's Hope Chapel",
      note = "Muitas quests de matar = ótimo em grupo.", noteEn = "Lots of kill quests = great in a group." },
    { map = 1451, min = 55, max = 60, name = "Silithus", hub = "Cenarion Hold",
      note = "Final do leveling, quests de Cenarion Circle.", noteEn = "End of leveling, Cenarion Circle quests." },
}

RX.Dungeons = {
    { min = 30, max = 40, name = "Scarlet Monastery", where = "Tirisfal Glades", whereEn = "Tirisfal Glades" },
    { min = 34, max = 42, name = "Razorfen Downs", where = "Barrens/Thousand Needles" },
    { min = 41, max = 47, name = "Uldaman", where = "Badlands" },
    { min = 44, max = 50, name = "Zul'Farrak", where = "Tanaris" },
    { min = 46, max = 55, name = "Maraudon", where = "Desolace" },
    { min = 50, max = 56, name = "Sunken Temple", where = "Swamp of Sorrows" },
    { min = 52, max = 60, name = "Blackrock Depths", where = "Blackrock Mountain" },
    { min = 55, max = 60, name = "Dire Maul / LBRS / Stratholme / Scholomance", where = "Feralas / Blackrock / Plaguelands" },
}

-- Nome da zona no idioma do SEU cliente (o jogo informa pelo ID do mapa)
function RX.MapName(m, fallback)
    local info = m and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(m)
    return (info and info.name and info.name ~= "") and info.name or fallback
end
function RX.ZoneDisplayName(z)
    local n = RX.MapName(z.map)
    if n then return n .. ((RX:IsPT() and z.sufPT) or z.sufEN or "") end
    return RX.LF(z, "name")
end

function RX.ZonesText(level)
    local T, LF = RX.T, RX.LF
    local out = {}
    table.insert(out, T("Seu nível: ", "Your level: ") .. "|cff40ff40" .. level .. "|r. " ..
        T("Zonas em |cff40ff40verde|r são as ideais agora.\n", "Zones in |cff40ff40green|r are the best right now.\n"))
    table.insert(out, "|cffff7f00" .. T("ZONAS DE QUEST", "QUEST ZONES") .. "|r")
    for _, z in ipairs(RX.Zones) do
        local col
        if level >= z.min and level <= z.max then col = "|cff40ff40"
        elseif level < z.min then col = "|cffaaaaaa"
        else col = "|cff707070" end
        table.insert(out, string.format("%s%d-%d  %s|r\n   |cffffd100%s|r %s\n   |cffd0d0d0%s|r", col, z.min, z.max, RX.ZoneDisplayName(z),
            T("Base:", "Hub:"), LF(z, "hub"), LF(z, "note")))
    end
    table.insert(out, "\n|cffff7f00" .. T("MASMORRAS (bom para grupo)", "DUNGEONS (good for groups)") .. "|r")
    for _, d in ipairs(RX.DungeonList or {}) do
        local col = (level >= d.min and level <= d.max) and "|cff40ff40" or "|cffaaaaaa"
        table.insert(out, string.format("%s%d-%d  %s|r  |cffd0d0d0(%s)|r%s", col, d.min, d.max, RX.Leveling.DungeonName(d), RX.Leveling.DungeonWhere(d), d.forever and " |cff40c0ff[Forever]|r" or ""))
    end
    return table.concat(out, "\n")
end

RX.TipsPT = [[
|cffff7f001. Pegue tudo de uma vez.|r Antes de sair de uma cidade/base, aceite todas as quests da área. Faça várias ao mesmo tempo matando os mesmos mobs.

|cffff7f002. Não ande vazio.|r Mate mobs que estão no caminho. Grind entre quests dá muito XP.

|cffff7f003. Pedra de Regresso = teleporte grátis.|r Coloque a pedra na base onde você vai entregar várias quests e use-a quando terminar.

|cffff7f004. Pegue TODOS os voos (flight paths).|r Sempre que passar perto de um mestre de voo, fale com ele.

|cffff7f005. Pule quest ruim.|r Escoltas, muitos drops raros ou atravessar o mundo por pouco XP atrasam. O estilo Speedrun já pula as piores.

|cffff7f006. DUO:|r jogue com alguém do SEU nível — no Forever o XP cai quando há um jogador bem mais alto no grupo. Use o estilo |cff40ff40Duo|r: tira quests de coleta de drop e prioriza quests de MATAR (crédito para os dois).

|cffff7f007. Sem coleta e ainda assim upar:|r o topo da janela mostra "Quests restantes -> chega ~nível X". Se ficar amarelo, complete com mobs, uma masmorra ou o próximo guia da rota.

|cffff7f008. Montaria no 40:|r custa ~100 de ouro. Comece a guardar no 30 e poucos.

|cffff7f009. XP descansado:|r deslogue sempre numa estalagem ou cidade.

|cffff7f0010. Masmorras:|r com grupo, faça a masmorra do seu nível junto com as quests dela.

|cffff7f0011. Equipamento:|r troque a arma sempre que puder — é o que mais acelera o leveling.

|cffff7f0012. Riverglades:|r navio de Steamwheedle Port (Tanaris) para Powderfuse Port, a pé pelo norte de Redridge, ou a quest "Report to Rog'mar" em Grom'gol. Depois use o voo de Rog'mar (tem voo para Stonard).

|cffff7f0013. Mount Hyjal:|r ao sul de Winterspring, por Darkwhisper Gorge.

|cffff7f0014. Controles:|r clique num passo para apontar a seta; o quadradinho da esquerda pula a quest; botão direito marca o passo como feito; arraste o canto inferior direito para aumentar a janela; segure SHIFT ao falar com NPC para não auto aceitar/entregar.

|cffaaaaaaRotas inspiradas na ordem de zonas de wowforeverinfo.com, warcraftmaps.com e topbuilds.gg. As quests de cada zona vêm do banco de dados do Questie.|r
]]

RX.TipsEN = [[
|cffff7f001. Grab everything at once.|r Before leaving a town/hub, accept every quest in the area. Do several at the same time by killing the same mobs.

|cffff7f002. Never walk empty.|r Kill mobs on your way. Grinding between quests gives a lot of XP.

|cffff7f003. Hearthstone = free teleport.|r Set it at the hub where you will turn in many quests and use it when you are done.

|cffff7f004. Get EVERY flight path.|r Whenever you pass near a flight master, talk to them.

|cffff7f005. Skip bad quests.|r Escorts, lots of rare drops or crossing the world for little XP slow you down. The Speedrun style already skips the worst ones.

|cffff7f006. DUO:|r play with someone at YOUR level — in Forever XP drops when a much higher-level player is in the group. Use the |cff40ff40Duo|r style: it removes drop-collection quests and favors KILL quests (credit for both).

|cffff7f007. No collecting and still level up:|r the top of the window shows "Remaining quests -> reach ~level X". If it turns yellow, top up with mobs, a dungeon or the next guide on the route.

|cffff7f008. Mount at 40:|r costs ~100 gold. Start saving in your low 30s.

|cffff7f009. Rested XP:|r always log out in an inn or a city.

|cffff7f0010. Dungeons:|r with a group, run the dungeon for your level together with its quests.

|cffff7f0011. Gear:|r upgrade your weapon whenever you can — it speeds up leveling the most.

|cffff7f0012. Riverglades:|r ship from Steamwheedle Port (Tanaris) to Powderfuse Port, on foot north of Redridge, or the quest "Report to Rog'mar" in Grom'gol. Then use the Rog'mar flight path (it flies to Stonard).

|cffff7f0013. Mount Hyjal:|r south of Winterspring, through Darkwhisper Gorge.

|cffff7f0014. Controls:|r click a step to point the arrow; the left checkbox skips the quest; right-click marks the step done; drag the bottom-right corner to enlarge the window; hold SHIFT when talking to an NPC to stop auto accept/turn-in.

|cffaaaaaaRoutes follow the zone order from wowforeverinfo.com, warcraftmaps.com and topbuilds.gg. The quests in each zone come from the Questie database.|r
]]

function RX.TipsText()
    return RX:IsPT() and RX.TipsPT or RX.TipsEN
end
