-- Modos de leveling: Solo, Duo e Masmorra. Estima XP por run/hora, tempo e se dá para solar/fazer em duo pela classe.
local _, RX = ...
local LV = {}
RX.Leveling = LV
local T = RX.T

-- No Forever o XP dos mobs de masmorra subiu ~20% (build de 8/out) e mais 50% (hotfix de 8/nov) segundo o timesaver.gg
LV.DUNGEON_BONUS = 1.2 * 1.5
-- Divisão clássica do XP em grupo (bônus de grupo / nº de jogadores). Há guias dizendo que no Forever é por jogador.
LV.SHARE = { [1] = 1, [2] = 0.5, [3] = 1.166 / 3, [4] = 1.3 / 4, [5] = 1.4 / 5 }
-- segundos de "relógio" por morte, incluindo puxar, descansar e andar (estimativa)
LV.SEC_PER_KILL = { group = 25, duo = 30, solo = 40 }

local CLASS_PT = { PALADIN = "Paladino", MAGE = "Mago", WARRIOR = "Guerreiro", PRIEST = "Sacerdote", ROGUE = "Ladino",
    HUNTER = "Caçador", WARLOCK = "Bruxo", DRUID = "Druida", SHAMAN = "Xamã" }

function LV.ClassName(file, localized)
    if RX:IsPT() then return CLASS_PT[file] or localized or file end
    return localized or file
end

local function zeroDiff(l)
    if l <= 7 then return 5 elseif l <= 9 then return 6 elseif l <= 11 then return 7 elseif l <= 15 then return 8
    elseif l <= 19 then return 9 elseif l <= 29 then return 11 elseif l <= 39 then return 12 elseif l <= 44 then return 13
    elseif l <= 49 then return 14 elseif l <= 54 then return 15 elseif l <= 59 then return 16 end
    return 17
end

function LV.GreyLevel(l)
    if l <= 5 then return 0 elseif l <= 39 then return l - math.floor(l / 10) - 5 elseif l <= 59 then return l - math.floor(l / 5) - 1 end
    return l - 13
end

-- XP de um mob (fórmula clássica): nível do jogador pl, nível do mob ml
function LV.MobXP(pl, ml, elite)
    if ml <= LV.GreyLevel(pl) then return 0 end
    local base = pl * 5 + 45
    local xp
    if ml >= pl then xp = base * (1 + 0.05 * math.min(ml - pl, 4))
    else xp = base * (1 - (pl - ml) / zeroDiff(pl)) end
    if elite then xp = xp * 2 end
    return math.max(0, xp)
end

-- Nome da masmorra e da zona no idioma do cliente (C_Map.GetAreaInfo / GetMapInfo)
function LV.DungeonName(dg)
    local n = dg.area and C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(dg.area)
    if not n or n == "" then return dg.name end
    local wing = RX:IsPT() and dg.wingPT or dg.wingEN
    return wing and (n .. ": " .. wing) or n
end
function LV.DungeonWhere(dg)
    return RX.MapName(dg.map, dg.where) or dg.where
end

-- Você e o seu grupo (classe e nível de cada um)
function LV:Party()
    local list = {}
    local function add(unit)
        if UnitExists and not UnitExists(unit) then return end
        local loc, file = UnitClass(unit)
        if file then table.insert(list, { unit = unit, class = file, cname = loc, level = UnitLevel(unit) or 0 }) end
    end
    add("player")
    for i = 1, 4 do add("party" .. i) end
    return list
end

function LV:PartyText(party)
    local parts = {}
    for _, p in ipairs(party) do table.insert(parts, LV.ClassName(p.class, p.cname) .. " " .. p.level) end
    return table.concat(parts, " + ")
end

local function hasClass(party, c) for _, p in ipairs(party) do if p.class == c then return true end end return false end

-- Avalia uma masmorra num modo: "group" (5), "duo" ou "solo"
function LV:Dungeon(dg, mode, party)
    local pl = UnitLevel("player")
    party = party or self:Party()
    local _, myClass = UnitClass("player")
    local margin = RX.SoloMargin[myClass] or 6
    local ok, why
    if mode == "group" then
        ok = pl >= dg.min - 2 and pl <= dg.max + 3
        why = ok and T("nível certo para grupo", "right level for a group") or (pl < dg.min - 2 and T("nível baixo", "too low") or T("nível alto: pouco XP", "too high: little XP"))
    elseif mode == "duo" then
        local need = math.max(1, margin - 3)
        if hasClass(party, "PALADIN") and hasClass(party, "MAGE") then need = 1 end -- tank + AoE: combo forte
        ok = pl >= dg.max + need
        why = ok and string.format(T("duo dá conta (+%d níveis acima do máx.)", "duo can handle it (+%d levels over max)"), pl - dg.max)
            or string.format(T("precisa nível %d+ para duo", "needs level %d+ for a duo"), dg.max + need)
    else
        ok = pl >= dg.max + margin
        why = ok and T("dá para solar", "soloable") or string.format(T("precisa nível %d+ para solar", "needs level %d+ to solo"), dg.max + margin)
    end
    local mobLvl = math.floor((dg.min + dg.max) / 2 + 1)
    local n = (mode == "group") and 5 or ((mode == "duo") and 2 or 1)
    local perKill = LV.MobXP(pl, mobLvl, true) * LV.DUNGEON_BONUS * (LV.SHARE[n] or 1)
    local xpRun = perKill * dg.kills
    local secs = dg.kills * LV.SEC_PER_KILL[mode]
    local grey = mobLvl <= LV.GreyLevel(pl)
    return { ok = ok and not grey, why = grey and T("mobs cinzas: 0 XP", "grey mobs: 0 XP") or why, xp = xpRun, minutes = secs / 60,
        xph = secs > 0 and xpRun / secs * 3600 or 0, mobLvl = mobLvl }
end

-- Melhores pontos de grind para o seu nível (no seu continente)
function LV:GrindSpots(mode, max)
    local pl = UnitLevel("player")
    local me = RX.Travel:PlayerPos()
    local lo, hi = pl - 3, pl + 1
    if mode == "duo" then lo, hi = pl - 4, pl + 2 end
    local res = {}
    for _, g in ipairs(RX.GrindSpots or {}) do
        local m, x, y, mlo, mhi, cnt, name, pname = g[1], g[2], g[3], g[4], g[5], g[6], g[7], g[8]
        if mhi >= lo and mlo <= hi then
            local c, wx, wy = RX.Travel.world(m, x, y)
            if c and (not me or c == me.cont) then
                local dist = me and math.sqrt((wx - me.wx) ^ 2 + (wy - me.wy) ^ 2) or 0
                local ml = math.floor((mlo + mhi) / 2)
                local xpk = LV.MobXP(pl, ml, false)
                local score = cnt * xpk / (1 + dist / 1500)
                if mode == "duo" then score = score * (1 + cnt / 20) end -- AoE gosta de grupos densos
                table.insert(res, { m = m, x = x, y = y, lo = mlo, hi = mhi, count = cnt, name = name, pname = pname,
                    dist = dist, xpk = xpk, score = score })
            end
        end
    end
    table.sort(res, function(a, b) return a.score > b.score end)
    local out = {}
    local usedZone = {}
    for _, r in ipairs(res) do
        -- no máximo 2 pontos por zona para variar
        usedZone[r.m] = (usedZone[r.m] or 0) + 1
        if usedZone[r.m] <= 2 then table.insert(out, r) end
        if #out >= (max or 6) then break end
    end
    return out
end

function LV:SpotStep(sp)
    local info = C_Map.GetMapInfo(sp.m)
    return { t = "G", m = sp.m, x = sp.x, y = sp.y, flags = {}, external = true,
        d = string.format("%s (%d-%d)", (RX:IsPT() and sp.pname) or sp.name, sp.lo, sp.hi),
        note = info and info.name or nil }
end

-- Dicas por classe
local TIPS = {
    PALADIN = { "Paladino: puxe 2-3 mobs, Consagração + Selo de Comando/Retidão; Bênção de Sabedoria economiza tempo de beber.",
        "Paladin: pull 2-3 mobs, Consecration + Seal of Command/Righteousness; Blessing of Wisdom saves drinking time." },
    MAGE = { "Mago: em grupos de mobs, Nova Gélida + Explosão Arcana (ou Nevasca) — foi assim o 1º 60 do Forever. Faça comida/água.",
        "Mage: on packs, Frost Nova + Arcane Explosion (or Blizzard) — that's how Forever's first 60 was done. Conjure food/water." },
    WARRIOR = { "Guerreiro: troque a arma sempre que puder; use Fender/Redemoinho em 2 mobs e coma entre as puxadas.",
        "Warrior: upgrade your weapon often; use Cleave/Whirlwind on 2 mobs and eat between pulls." },
    HUNTER = { "Caçador: pet tanka, você atira; mantenha o pet feliz e com nível igual ao seu.", "Hunter: the pet tanks, you shoot; keep it happy and at your level." },
    WARLOCK = { "Bruxo: Voidwalker tanka, DoTs em 2-3 mobs, Drenar Vida e Tap de Vida para não parar.", "Warlock: Voidwalker tanks, DoT 2-3 mobs, Drain Life and Life Tap to keep going." },
    PRIEST = { "Sacerdote: Escudo + Toque Vampírico/Palavra das Sombras; varinha para finalizar.", "Priest: Shield + Shadow Word: Pain; wand to finish." },
    ROGUE = { "Ladino: pegue mobs um a um, use o tempo de descanso com Bandagens.", "Rogue: one mob at a time, use bandages to cut downtime." },
    DRUID = { "Druida: forma de gato/urso e cura entre lutas; Viagem para andar rápido.", "Druid: cat/bear form, heal between fights; Travel Form to move fast." },
    SHAMAN = { "Xamã: Golpe de Tempestade + Totens; Lobo Fantasma (nível 20) para andar entre spots.", "Shaman: Stormstrike + totems; Ghost Wolf to move between spots." },
}
function LV:ClassTip(file)
    local t = TIPS[file]
    return t and T(t[1], t[2]) or nil
end

local function fmt(x) if x >= 1000 then return string.format("%.1fk", x / 1000) end return tostring(math.floor(x)) end

-- Texto de cada modo para o painel "Agora"
function LV:Text(mode)
    local pl = UnitLevel("player")
    local party = self:Party()
    local _, myClass = UnitClass("player")
    local out = {}
    local function add(s) table.insert(out, s) end
    local function h(s) add("\n|cffff7f00" .. s .. "|r") end
    add(string.format(T("Você: |cffffd100%s|r   Grupo atual: |cffffd100%s|r", "You: |cffffd100%s|r   Current group: |cffffd100%s|r"),
        LV.ClassName(myClass, (UnitClass("player"))) .. " " .. pl, self:PartyText(party)))
    local mobsGrey = LV.GreyLevel(pl)
    add(string.format(T("Mobs nível %d ou menos são cinzas para você (0 XP).", "Mobs level %d or lower are grey for you (0 XP)."), mobsGrey))

    local function dungeonList(m)
        local n = 0
        for _, dg in ipairs(RX.DungeonList or {}) do
            if pl >= dg.min - 3 and pl <= dg.max + 12 then
                local r = self:Dungeon(dg, m, party)
                if m == "group" or r.ok then
                    n = n + 1
                    add(string.format("  %s%s|r %d-%d (%s)%s", r.ok and "|cff40ff40" or "|cffaaaaaa", LV.DungeonName(dg), dg.min, dg.max, LV.DungeonWhere(dg), dg.forever and " |cff40c0ff[Forever]|r" or ""))
                    add(string.format(T("     ~%s xp por run · ~%.0f min · ~%s xp/h · %s", "     ~%s xp per run · ~%.0f min · ~%s xp/h · %s"),
                        fmt(r.xp), r.minutes, fmt(r.xph), r.why))
                end
            end
        end
        if n == 0 then add(T("  (nenhuma viável agora)", "  (none viable right now)")) end
    end

    if mode == "dungeon" then
        h(T("MASMORRA EM GRUPO DE 5 (seu nível)", "DUNGEON WITH A 5-PLAYER GROUP (your level)"))
        dungeonList("group")
        h(T("MASMORRA EM DUO", "DUNGEON AS A DUO"))
        dungeonList("duo")
        h(T("MASMORRA SOLO", "DUNGEON SOLO"))
        dungeonList("solo")
        h(T("COMO O CÁLCULO É FEITO", "HOW IT IS CALCULATED"))
        add(T("  XP por mob pela fórmula clássica (elite = 2x), com +80% de XP de mobs de masmorra no Forever (timesaver.gg) e divisão do XP pelo grupo. Tempo = mortes x segundos por morte (estimativa).",
            "  Mob XP from the classic formula (elite = 2x), +80% Forever dungeon mob XP (timesaver.gg) and XP split by group size. Time = kills x seconds per kill (estimate)."))
        add(T("  Faça a masmorra UMA vez com as quests dela (o bônus das quests de masmorra caiu 50%, mas ainda vale). Use o Cronômetro de XP para medir o real.",
            "  Run the dungeon ONCE with its quests (dungeon quest bonus was cut 50%, still worth it). Use the XP Timer to measure the real value."))
    elseif mode == "duo" then
        h(T("DUO", "DUO"))
        if #party < 2 then add(T("  Você não está em grupo agora: os cálculos assumem um duo do seu nível.", "  You're not in a group: calculations assume a duo at your level.")) end
        if hasClass(party, "PALADIN") and hasClass(party, "MAGE") or (myClass == "PALADIN" or myClass == "MAGE") then
            add(T("  |cff40ff40Paladino + Mago:|r o paladino junta 4-6 mobs (Consagração segura a atenção), o mago congela (Nova Gélida) e usa Explosão Arcana/Nevasca. É o combo do 1º 60 do Forever (paladino puxando + magos com AoE).",
                "  |cff40ff40Paladin + Mage:|r the paladin gathers 4-6 mobs (Consecration holds aggro), the mage freezes (Frost Nova) and uses Arcane Explosion/Blizzard. It's the combo of Forever's first 60 (paladin pulling + AoE mages)."))
        end
        add(T("  Mantenham o MESMO nível: no Forever, se um for muito mais alto que os mobs, ninguém ganha XP.", "  Stay at the SAME level: in Forever, if one is far above the mobs, nobody gets XP."))
        add(T("  Quests de MATAR dão crédito para os dois; use o estilo Duo nos guias.", "  KILL quests credit both; use the Duo style in the guides."))
        h(T("PONTOS DE GRIND PARA DUO (grupos densos para AoE)", "DUO GRIND SPOTS (dense packs for AoE)"))
        add(T("  (use os botões abaixo para apontar a seta)", "  (use the buttons below to point the arrow)"))
        h(T("MASMORRAS QUE O DUO DÁ CONTA", "DUNGEONS THE DUO CAN HANDLE"))
        dungeonList("duo")
    else
        h(T("SOLO", "SOLO"))
        local tip = self:ClassTip(myClass)
        if tip then add("  " .. tip) end
        add(T("  Quests + matar no caminho é quase sempre o mais rápido solo. Grind puro vale quando acabam as quests do seu nível ou para fechar o nível.",
            "  Quests + killing on the way is almost always fastest solo. Pure grinding is worth it when you run out of quests or to finish a level."))
        h(T("PONTOS DE GRIND PARA VOCÊ", "GRIND SPOTS FOR YOU"))
        add(T("  (use os botões abaixo para apontar a seta)", "  (use the buttons below to point the arrow)"))
        h(T("MASMORRAS QUE DÁ PARA SOLAR", "DUNGEONS YOU CAN SOLO"))
        dungeonList("solo")
    end
    return table.concat(out, "\n")
end
