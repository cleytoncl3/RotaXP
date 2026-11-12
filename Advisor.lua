-- Conselheiro: detecta onde você está (cidade, zona, continente) e diz o que fazer para upar mais rápido
local _, RX = ...
local AD = { seen = {} }
RX.Advisor = AD
local T, LF = RX.T, RX.LF

local CITIES = { [1454] = "Orgrimmar", [1456] = "Thunder Bluff", [1458] = "Undercity", [1453] = "Stormwind", [1455] = "Ironforge", [1457] = "Darnassus" }
local HORDE_CITIES = { [1454] = true, [1456] = true, [1458] = true }

-- Ritmo do primeiro 60 do Forever (grupo de 5, AoE), horas de /played por nível (endgametools.com)
local RECORD = { [30] = 13.5, [40] = 22.35, [50] = 34.6, [55] = 40.4, [60] = 52.2 }

-- Masmorras novas do Forever por nível (timesaver.gg)
AD.ForeverDungeons = {
    { 28, 33, "City of Dalaran", "Alterac" }, { 35, 40, "The Drowned City", "Stranglethorn" },
    { 40, 45, "Krol'dok Stronghold", "Riverglades" }, { 48, 53, "Alcaz Prison", "Dustwallow" },
    { 55, 60, "Blackmaw Hold", "Mount Hyjal?" }, { 58, 60, "Shaper's Terrace", "Silithus?" },
}

-- Sobe na hierarquia de mapas até achar a zona (tipo 3) e o continente (tipo 2)
function AD:Where()
    local m = C_Map.GetBestMapForUnit("player")
    if not m then return nil end
    local zone, cont, cur = nil, nil, m
    local guard = 0
    while cur and cur ~= 0 and guard < 8 do
        local info = C_Map.GetMapInfo(cur)
        if not info then break end
        if info.mapType == 3 and not zone then zone = info end
        if info.mapType == 2 then cont = info end
        cur = info.parentMapID
        guard = guard + 1
    end
    local here = C_Map.GetMapInfo(m)
    return { mapID = m, here = here, zone = zone, cont = cont, city = CITIES[(zone and zone.mapID) or m] and ((zone and zone.mapID) or m) }
end

function AD:GuidesForMap(mapID)
    local list = {}
    if not mapID then return list end
    for _, g in pairs(RX.guides) do if g.map == mapID then table.insert(list, g) end end
    return list
end

-- Linha curta para a janela principal
function AD:Line()
    local w = self:Where()
    if not w then return nil end
    local lvl = UnitLevel("player")
    local name = (w.zone and w.zone.name) or (w.here and w.here.name) or "?"
    if w.city then
        local txt = "|cff80c0ff" .. name .. "|r " .. T("(cidade)", "(city)")
        if HORDE_CITIES[w.city] then txt = txt .. " · |cffaaaaaa" .. T("treine, leilão, banco; depois saia para a zona do guia", "train, auction house, bank; then head to the guide's zone") .. "|r" end
        return txt
    end
    local gs = self:GuidesForMap(w.zone and w.zone.mapID)
    local g = gs[1]
    local cur = RX:CurrentGuide()
    if g then
        local status
        if lvl < g.min - 1 then status = "|cffff6060" .. T("alta para você", "too high for you") .. "|r"
        elseif lvl >= g.max then status = "|cff909090" .. T("baixa para você (pouco XP)", "too low for you (little XP)") .. "|r"
        else status = "|cff40ff40" .. T("boa para o seu nível", "good for your level") .. "|r" end
        local txt = string.format("|cff80c0ff%s|r %d-%d · %s", name, g.min, g.max, status)
        if cur ~= g and lvl >= g.min - 1 and lvl < g.max then txt = txt .. " · |cffffd040" .. T("clique p/ usar o guia desta zona", "click to use this zone's guide") .. "|r" end
        return txt, g
    end
    return "|cff80c0ff" .. name .. "|r" .. (w.cont and (" · " .. w.cont.name) or "")
end

-- Ao entrar numa zona nova: sugere o guia dela (uma vez por zona)
function AD:OnZone()
    if not RX.db or RX.db.suggestZone == false then return end
    local w = self:Where()
    if not w or not w.zone or self.seen[w.zone.mapID] then return end
    self.seen[w.zone.mapID] = true
    local lvl = UnitLevel("player")
    local cur = RX:CurrentGuide()
    for _, g in ipairs(self:GuidesForMap(w.zone.mapID)) do
        if g ~= cur and lvl >= g.min - 1 and lvl < g.max then
            RX:Print(string.format(T("Você entrou em |cff80c0ff%s|r: existe o guia |cffffff00%s|r para o seu nível. Clique na linha de local da janela (ou /rota aqui) para usar.",
                "You entered |cff80c0ff%s|r: there is a guide |cffffff00%s|r for your level. Click the location line in the window (or /rota here) to use it."), w.zone.name, RX:GuideName(g)))
            return
        end
    end
end

function AD:UseHere()
    local w = self:Where()
    local g = w and w.zone and self:GuidesForMap(w.zone.mapID)[1]
    if g then RX:SetGuide(g.id) else RX:Print(T("Não há guia para esta zona.", "There is no guide for this zone.")) end
end

local function fmtH(h) return string.format("%dh%02d", math.floor(h), math.floor((h % 1) * 60)) end

-- Texto completo do painel "Agora"
function AD:Text()
    local w = self:Where()
    local lvl = UnitLevel("player")
    local out = {}
    local function add(s) table.insert(out, s) end
    local function h(s) add("\n|cffff7f00" .. s .. "|r") end

    -- onde estou
    h(T("ONDE VOCÊ ESTÁ", "WHERE YOU ARE"))
    if w then
        add(string.format("%s: |cff80c0ff%s|r   %s: |cff80c0ff%s|r", T("Zona", "Zone"), (w.zone and w.zone.name) or (w.here and w.here.name) or "?",
            T("Continente", "Continent"), w.cont and w.cont.name or "?"))
        if w.city then
            add(T("Você está numa |cffffd100cidade|r. Lista rápida antes de sair:", "You are in a |cffffd100city|r. Quick checklist before leaving:"))
            add(T("  - Treine as habilidades novas (o treino 1-60 custa ~206 de ouro no total).", "  - Train your new skills (1-60 training costs ~206 gold in total)."))
            add(T("  - Leilão: troque a arma por um verde melhor (é o maior ganho de velocidade de matar).", "  - Auction house: replace your weapon with a better green (biggest kill-speed gain)."))
            add(T("  - Banco/correio: guarde o que não usa e esvazie a bolsa. Bolsa cheia mata o ritmo.", "  - Bank/mail: store what you don't use and empty your bags. Full bags kill your pace."))
            add(T("  - Compre comida/água e, se puder, comida cozida (+5% XP de mobs, dado de datamine).", "  - Buy food/water and, if possible, cooked food (+5% mob XP, datamined)."))
            add(T("  - Deslogue aqui para acumular XP descansado.", "  - Log out here to build rested XP."))
            if lvl >= 40 then add(T("  - Já tem a montaria do nível 40? É o maior ganho do leveling (~100 de ouro).", "  - Got your level 40 mount? It's the biggest boost of the leveling (~100 gold).")) end
        else
            local line, g = self:Line()
            if line then add(line) end
            if g then add(LF(g, "desc") or "") end
        end
    end

    -- o que fazer no seu nível
    h(string.format(T("MELHORES ZONAS PARA O NÍVEL %d", "BEST ZONES FOR LEVEL %d"), lvl))
    local nz = 0
    for _, z in ipairs(RX.Zones) do
        if lvl >= z.min and lvl <= z.max and nz < 5 then
            nz = nz + 1
            add(string.format("  |cff40ff40%s|r (%d-%d) - %s", LF(z, "name"), z.min, z.max, LF(z, "hub")))
        end
    end
    local route = RX:CurrentRoute()
    local best = RX:BestGuideForLevel(lvl)
    if best then add(string.format(T("  Guia recomendado na sua rota (%s): |cffffff00%s|r", "  Recommended guide on your route (%s): |cffffff00%s|r"), LF(route, "name"), RX:GuideName(best))) end

    -- masmorras
    h(T("MASMORRAS DO SEU NÍVEL (com grupo)", "DUNGEONS FOR YOUR LEVEL (with a group)"))
    local nd = 0
    for _, d in ipairs(RX.DungeonList or {}) do
        if lvl >= d.min - 1 and lvl <= d.max then
            nd = nd + 1
            add(string.format("  %s %d-%d (%s)%s", RX.Leveling.DungeonName(d), d.min, d.max, RX.Leveling.DungeonWhere(d), d.forever and " |cff40c0ff[Forever]|r" or ""))
        end
    end
    if nd == 0 then add(T("  (nenhuma no seu nível agora)", "  (none at your level right now)")) end
    add(T("  Faça cada masmorra UMA vez, já com as quests dela, e volte a questar. No Forever o XP de mobs em masmorra foi aumentado, mas o bônus das quests de masmorra caiu 50%.",
        "  Run each dungeon ONCE, with its quests already picked up, then go back to questing. In Forever dungeon mob XP was increased, but the dungeon quest bonus was cut 50%."))

    -- ritmo
    h(T("SEU RITMO", "YOUR PACE"))
    local left = UnitXPMax("player") - UnitXP("player")
    add(string.format(T("  Para upar em 1 hora você precisa de |cffffd100%d xp/h|r (faltam %d XP).", "  To level in 1 hour you need |cffffd100%d xp/h|r (%d XP left)."), left, left))
    local ph, mins = RX:XPPerHour()
    if ph then add(string.format(T("  Seu ritmo nesta sessão: |cff40ff40%.0f xp/h|r -> ~%.0f min para o próximo nível.", "  Your pace this session: |cff40ff40%.0f xp/h|r -> ~%.0f min to the next level."), ph, mins))
    else add(T("  (jogue alguns minutos para medir seu XP/hora)", "  (play a few minutes to measure your XP/hour)")) end
    add(T("  Meça um ciclo inteiro de 10-15 min (matar, saquear, andar, curar): é o número real.", "  Measure a full 10-15 min loop (kill, loot, travel, heal): that's the real number."))
    local recPer = lvl < 39 and 45 or (lvl < 56 and 72 or 150)
    add(string.format(T("  Referência: o 1º 60 do Forever (grupo de 5 com AoE) fez ~%d min por nível nesta faixa e chegou ao 60 em %s de jogo.",
        "  Reference: Forever's first 60 (5-player AoE group) took ~%d min per level in this range and hit 60 in %s played."), recPer, fmtH(RECORD[60])))
    add(T("  Para um jogador solo bom, 2-3x esse tempo já é um ótimo ritmo.", "  For a good solo player, 2-3x that time is already a great pace."))

    -- regras do Forever
    h(T("REGRAS DE XP DO FOREVER (para decidir melhor)", "FOREVER XP RULES (to decide better)"))
    add(T("  - XP de mob em grupo é calculado pelo nível de CADA jogador; jogador de nível baixo não atrapalha.", "  - Group mob XP is computed from EACH player's level; a lower-level member doesn't hurt you."))
    add(T("  - Se alguém do grupo for MUITO mais alto que os mobs, ninguém ganha XP. Duo com nível parecido!", "  - If someone in the group is FAR above the mobs, nobody gets XP. Duo with similar levels!"))
    add(T("  - XP descansado dobra só o XP de mobs (não o de quests). O talento de Legado 'Well Rested' aumenta o limite.", "  - Rested XP doubles only mob XP (not quest XP). The Legacy talent 'Well Rested' raises the cap."))
    add(T("  - Quests cinzas quase não dão XP: o estilo Speedrun já as esconde.", "  - Grey quests give almost no XP: the Speedrun style already hides them."))
    add(T("  - Bolsa cheia? Use o Modo Entregas (botão Entregas) para limpar as quests prontas numa rota só.", "  - Bags full? Use Turn-in mode (Turn-ins button) to clear ready quests in one route."))
    add("\n|cffaaaaaa" .. T("Fontes: endgametools.com (1º 60), timesaver.gg (regras de XP e masmorras), wowforeverbuilds.com e leprestore.com (dicas). Números de terceiros, não oficiais da Blizzard.",
        "Sources: endgametools.com (first 60), timesaver.gg (XP rules and dungeons), wowforeverbuilds.com and leprestore.com (tips). Third-party numbers, not official Blizzard data.") .. "|r")
    return table.concat(out, "\n")
end
