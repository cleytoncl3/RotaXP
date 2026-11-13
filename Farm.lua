-- Submenu "Grind & Masmorras" do menu Guias: Farm Solo, Farm Duo, Masmorras, Equipamento para farm e Cronômetro.
-- O equipamento vem do GearQuest Forever (se estiver instalado), usando a spec de farm da sua classe.
local _, RX = ...
local FM = {}
RX.Farm = FM
local T, LF = RX.T, RX.LF

local function fmt(x) if x >= 1000 then return string.format("%.1fk", x / 1000) end return tostring(math.floor(x)) end

-- Build de farm por classe (spec usada para escolher os itens no GearQuest)
FM.Build = {
    PALADIN = { spec = "protection", pt = "Proteção / AoE com Consagração", en = "Protection / AoE Consecration",
        tipPT = "Junte 3-6 mobs. Aura de Retribuição (reflete dano a cada golpe), Bênção do Santuário, Selo da Retidão e Consagração. Priorize Vigor, Armadura e Bloqueio para aguentar; Dano Mágico aumenta Consagração e o reflexo.",
        tipEN = "Gather 3-6 mobs. Retribution Aura (reflects damage on every hit), Blessing of Sanctuary, Seal of Righteousness and Consecration. Prioritize Stamina, Armor and Block to survive; Spell Damage boosts Consecration and the reflect." },
    MAGE = { spec = "frost", pt = "Gelo / AoE (Nevasca + Explosão Arcana)", en = "Frost / AoE (Blizzard + Arcane Explosion)",
        tipPT = "Junte mobs, Nova Gélida, afaste-se e use Nevasca (Nevasca Aprimorada deixa lento) ou Explosão Arcana. Priorize Dano Mágico, Intelecto e Vigor; Barreira de Gelo (talento) ajuda muito.",
        tipEN = "Gather mobs, Frost Nova, step back and use Blizzard (Improved Blizzard slows) or Arcane Explosion. Prioritize Spell Damage, Intellect and Stamina; Ice Barrier (talent) helps a lot." },
    WARRIOR = { spec = "arms", pt = "Armas", en = "Arms", tipPT = "Arma de duas mãos lenta e forte; Fender e Redemoinho em 2 mobs.", tipEN = "Slow, hard-hitting two-hander; Cleave and Whirlwind on 2 mobs." },
    HUNTER = { spec = "marksmanship", pt = "Precisão", en = "Marksmanship", tipPT = "Pet tanka; priorize Agilidade e uma arma de longo alcance boa.", tipEN = "Pet tanks; prioritize Agility and a good ranged weapon." },
    WARLOCK = { spec = "affliction", pt = "Suplício", en = "Affliction", tipPT = "Voidwalker tanka, DoTs em vários mobs, Drenar Vida.", tipEN = "Voidwalker tanks, DoTs on several mobs, Drain Life." },
    PRIEST = { spec = "shadow", pt = "Sombra", en = "Shadow", tipPT = "Escudo, Palavra das Sombras: Dor, Açoite Mental e varinha.", tipEN = "Shield, Shadow Word: Pain, Mind Flay and wand." },
    ROGUE = { spec = "combat", pt = "Combate", en = "Combat", tipPT = "Um mob por vez, Bandagens para não parar.", tipEN = "One mob at a time, bandages to cut downtime." },
    DRUID = { spec = "feral", pt = "Feral", en = "Feral", tipPT = "Forma de gato, cura entre lutas.", tipEN = "Cat form, heal between fights." },
    SHAMAN = { spec = "enhancement", pt = "Aperfeiçoamento", en = "Enhancement", tipPT = "Arma de duas mãos lenta, Golpe de Tempestade e Totens.", tipEN = "Slow two-hander, Stormstrike and totems." },
}

local SLOT_ID = { Head = 1, Neck = 2, Shoulder = 3, Shoulders = 3, Back = 15, Chest = 5, Wrist = 9, Wrists = 9, Hands = 10,
    Waist = 6, Legs = 7, Feet = 8, Finger = 11, Ring = 11, Trinket = 13, ["Main Hand"] = 16, ["Two-Hand"] = 16, ["One-Hand"] = 16,
    ["Off Hand"] = 17, Shield = 17, ["Held In Off-hand"] = 17, Ranged = 18, Relic = 18, Wand = 18 }
local SLOT_PT = { Head = "Cabeça", Neck = "Pescoço", Shoulder = "Ombros", Shoulders = "Ombros", Back = "Costas", Chest = "Peito",
    Wrist = "Pulsos", Wrists = "Pulsos", Hands = "Mãos", Waist = "Cintura", Legs = "Pernas", Feet = "Pés", Finger = "Anel", Ring = "Anel",
    Trinket = "Berloque", ["Main Hand"] = "Mão principal", ["Two-Hand"] = "Duas mãos", ["One-Hand"] = "Uma mão", ["Off Hand"] = "Mão secundária",
    Shield = "Escudo", Ranged = "À distância", Relic = "Relíquia", Wand = "Varinha" }

-- Carrega os dados da sua classe no GearQuest, se precisar (eles são "load on demand")
local function gearData(classFile)
    local GQ = _G.GearQuest
    if not GQ then return nil end
    local key = classFile:lower() .. "Picks"
    if not (GQ.Data and GQ.Data[key]) then
        local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
        if load then pcall(load, "GearQuestForever_" .. classFile) end
    end
    return GQ.Data and GQ.Data[key], GQ.Data and GQ.Data.itemFacts
end

local function itemName(id, facts)
    local n
    if C_Item and C_Item.GetItemNameByID then n = C_Item.GetItemNameByID(id) end
    if not n and GetItemInfo then n = GetItemInfo(id) end
    return n or (facts and facts.name) or ("item " .. id)
end

local function equipped(id, slotName)
    local sid = SLOT_ID[slotName]
    if not sid or not GetInventoryItemID then return false end
    if GetInventoryItemID("player", sid) == id then return true end
    if sid == 11 and GetInventoryItemID("player", 12) == id then return true end
    if sid == 13 and GetInventoryItemID("player", 14) == id then return true end
    return false
end

----------------------------------------------------------------------
-- Pontuação própria para builds de AoE/farm (lê os stats dos itens do GearQuest em tempo real)
----------------------------------------------------------------------
-- pesos por stat (chaves do GearQuest: sta, armor, str, agi, int, spi, damageDone, spHoly, spFrost, blockPct, blockValue, defense, dodge...)
FM.Weights = {
    PALADIN = { sta = 1.0, armor = 0.05, str = 0.45, blockValue = 0.7, blockPct = 9, defense = 1.2, dodge = 6,
        damageDone = 1.1, spHoly = 1.1, int = 0.35, spi = 0.2, heal = 0.05, dps = 1.2, thorns = 3.0 },
    MAGE = { damageDone = 1.3, spFrost = 1.3, spArcane = 0.8, int = 0.6, sta = 0.8, spi = 0.35, armor = 0.01, thorns = 0.5 },
}
local STAT_PT = { sta = "Vigor", armor = "Armadura", str = "Força", agi = "Agilidade", int = "Intelecto", spi = "Espírito",
    damageDone = "Dano mágico", spHoly = "Dano sagrado", spFrost = "Dano de gelo", spArcane = "Dano arcano", blockPct = "% bloqueio",
    blockValue = "Valor de bloqueio", defense = "Defesa", dodge = "% esquiva", heal = "Cura", dps = "DPS", thorns = "Reflete dano" }
local STAT_EN = { sta = "Stamina", armor = "Armor", str = "Strength", agi = "Agility", int = "Intellect", spi = "Spirit",
    damageDone = "Spell damage", spHoly = "Holy damage", spFrost = "Frost damage", spArcane = "Arcane damage", blockPct = "% block",
    blockValue = "Block value", defense = "Defense", dodge = "% dodge", heal = "Healing", dps = "DPS", thorns = "Reflects damage" }

-- dano refletido ("When struck in combat inflicts X damage" / "Quando atingido em combate..."): texto do GearQuest ou do tooltip do jogo
local function thornsValue(id)
    local GQ = _G.GearQuest
    local tips = {}
    local a = GQ and GQ.Data and GQ.Data.foreverAudit and GQ.Data.foreverAudit[id]
    if a and a.tip then table.insert(tips, a.tip) end
    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
        if ok and data and data.lines then for _, l in ipairs(data.lines) do if l.leftText then table.insert(tips, l.leftText) end end end
    end
    for _, t in ipairs(tips) do
        for line in tostring(t):gmatch("[^\n]+") do
            local low = line:lower()
            if low:find("when struck") or low:find("atingido em combate") or low:find("ao ser atingido") then
                local a1, b1 = low:match("(%d+) to (%d+)")
                if not a1 then a1, b1 = low:match("(%d+) a (%d+)") end
                local chance = tonumber(low:match("(%d+)%%")) or 100
                local dmg = a1 and (tonumber(a1) + tonumber(b1)) / 2 or tonumber(low:match("(%d+)")) or 0
                return dmg * chance / 100
            end
        end
    end
    return 0
end

local function scoreItem(id, slot, w)
    local GQ = _G.GearQuest
    local st = GQ and GQ.Data and GQ.Data.itemStats and GQ.Data.itemStats[id]
    if not st then return nil end
    local score, parts = 0, {}
    for k, wt in pairs(w) do
        local v = (k == "thorns") and thornsValue(id) or st[k]
        if type(v) == "number" and v > 0 then
            score = score + v * wt
            table.insert(parts, { k = k, v = v, s = v * wt })
        end
    end
    -- paladino de farm usa escudo: armas de duas mãos valem menos
    if w == FM.Weights.PALADIN and slot == "Two-Hand" then score = score * 0.6 end
    table.sort(parts, function(a, b) return a.s > b.s end)
    local names = RX:IsPT() and STAT_PT or STAT_EN
    local txt = {}
    for i = 1, math.min(4, #parts) do
        local p = parts[i]
        table.insert(txt, string.format(p.k == "dps" and "%.1f %s" or "+%.0f %s", p.v, names[p.k] or p.k))
    end
    return score, table.concat(txt, ", ")
end

-- Para paladino e mago: escolhe o melhor item de cada espaço pela pontuação acima, entre os itens que o GearQuest lista
function FM:CustomGear(classFile, picks, facts)
    local w = self.Weights[classFile]
    if not w then return nil end
    local lvl = UnitLevel("player")
    local seen, bySlot = {}, {}
    for _, r in ipairs(picks) do
        local id, slot, fac = r[1], r[2], r[7]
        if not seen[id] and (fac == "Horde" or fac == nil) then
            seen[id] = true
            local f = facts and facts[id]
            local req = (f and f.reqLevel) or r[3] or 1
            if req <= lvl and req >= lvl - 12 then
                local score, desc = scoreItem(id, slot, w)
                if score and score > 0 then
                    bySlot[slot] = bySlot[slot] or {}
                    table.insert(bySlot[slot], { id = id, slot = slot, score = score, desc = desc, req = req })
                end
            end
        end
    end
    for _, l in pairs(bySlot) do table.sort(l, function(a, b) return a.score > b.score end) end
    -- build de farm do paladino é arma de uma mão + escudo
    if classFile == "PALADIN" and (bySlot["Shield"] or bySlot["Off Hand"]) then bySlot["Two-Hand"] = nil end
    return bySlot
end

local function openGearQuest()
    local GQ = _G.GearQuest
    if GQ and GQ.Log and GQ.Log.Toggle then GQ.Log:Toggle()
    elseif SlashCmdList and SlashCmdList.GEARQUEST then SlashCmdList.GEARQUEST("") end
end

-- Itens recomendados para a build de farm no seu nível (melhor de cada espaço) + próximos upgrades
function FM:GearItems()
    local _, classFile = UnitClass("player")
    local picks, facts = gearData(classFile or "")
    if picks and self.Weights[classFile] then
        return self:CustomGearItems(classFile, picks, facts)
    end
    return self:GQGearItems()
end

function FM:CustomGearItems(classFile, picks, facts)
    local build = self.Build[classFile]
    local list = { { header = true, text = T("Equipamento para farm", "Farming gear") .. ": " .. (RX:IsPT() and build.pt or build.en),
        sub = T("Pontuação do RouteXP lendo os stats do GearQuest: ", "RouteXP scoring from GearQuest stats: ") ..
            (classFile == "PALADIN" and T("Vigor, Armadura, Bloqueio, Defesa, Dano mágico/sagrado (Consagração) e Reflexo de dano.",
                "Stamina, Armor, Block, Defense, Spell/Holy damage (Consecration) and damage reflect.")
            or T("Dano mágico/de gelo, Intelecto, Vigor e Espírito.", "Spell/Frost damage, Intellect, Stamina and Spirit.")) } }
    table.insert(list, { text = T("Abrir o GearQuest", "Open GearQuest"), sub = T("veja os itens, stats e como conseguir", "see items, stats and how to get them"), onClick = openGearQuest })
    local bySlot = self:CustomGear(classFile, picks, facts)
    local slots = {}
    for slot in pairs(bySlot) do table.insert(slots, slot) end
    table.sort(slots, function(a, b) return (SLOT_ID[a] or 99) < (SLOT_ID[b] or 99) end)
    local have, total = 0, 0
    for _, slot in ipairs(slots) do
        local best = bySlot[slot][1]
        local f = facts and facts[best.id]
        local ok = equipped(best.id, slot)
        total = total + 1; if ok then have = have + 1 end
        local where = f and ((f.instructions or "") .. (f.zone and (" (" .. f.zone .. ")") or "")) or ""
        table.insert(list, {
            text = string.format("%s|cffaaaaaa%s:|r %s |cff909090(nv %d)|r", ok and "|cff40ff40[ok] |r" or "", RX:IsPT() and (SLOT_PT[slot] or slot) or slot,
                itemName(best.id, f), best.req),
            sub = "|cff40ff40" .. best.desc .. "|r" .. (where ~= "" and ("\n" .. where) or ""),
            itemID = best.id,
            selected = ok,
            onClick = function() if IsShiftKeyDown() and ChatEdit_InsertLink then local _, link = GetItemInfo(best.id); if link then ChatEdit_InsertLink(link) end else openGearQuest() end end,
        })
    end
    if total == 0 then
        table.insert(list, { text = T("Nenhum item no seu nível com esses stats na lista do GearQuest.", "No item at your level with these stats in GearQuest's list.") })
    else
        list[1].sub = list[1].sub .. "\n" .. string.format(T("|cff40ff40%d de %d|r espaços já com o item recomendado. Passe o mouse para ver o item; clique abre o GearQuest; Shift+clique coloca o link no chat.",
            "|cff40ff40%d of %d|r slots already have the recommended item. Hover to see the item; click opens GearQuest; Shift+click links it in chat."), have, total)
    end
    return list
end

-- Outras classes: usa o ranking do próprio GearQuest para a spec de farm
function FM:GQGearItems()
    local _, classFile = UnitClass("player")
    local build = self.Build[classFile]
    local list = { { header = true, text = T("Equipamento para farm", "Farming gear") .. (build and (": " .. (RX:IsPT() and build.pt or build.en)) or ""),
        sub = build and (RX:IsPT() and build.tipPT or build.tipEN) or nil } }
    local picks, facts = gearData(classFile or "")
    if not picks then
        table.insert(list, { text = T("GearQuest Forever não encontrado", "GearQuest Forever not found"),
            sub = T("Instale/ative o GearQuest Forever e o módulo da sua classe para ver os itens recomendados.", "Install/enable GearQuest Forever and your class module to see recommended items.") })
        return list
    end
    local lvl = UnitLevel("player")
    local spec = build and build.spec
    local best, soon = {}, {}
    for _, r in ipairs(picks) do
        local id, slot, minL, maxL, rank, rspec, fac = r[1], r[2], r[3], r[4], r[5], r[6], r[7]
        if (not spec or rspec == spec) and (fac == "Horde" or fac == nil) and rank == 1 then
            if lvl >= minL and lvl <= maxL then
                if not best[slot] then best[slot] = r end
            elseif minL > lvl and minL <= lvl + 3 then
                if not soon[slot] or minL < soon[slot][3] then soon[slot] = r end
            end
        end
    end
    local slots = {}
    for slot in pairs(best) do table.insert(slots, slot) end
    table.sort(slots, function(a, b) return (SLOT_ID[a] or 99) < (SLOT_ID[b] or 99) end)
    local have, total = 0, 0
    for _, slot in ipairs(slots) do
        local r = best[slot]
        local f = facts and facts[r[1]]
        local ok = equipped(r[1], slot)
        total = total + 1; if ok then have = have + 1 end
        local where = f and ((f.instructions or "") .. (f.zone and (" (" .. f.zone .. ")") or "")) or ""
        local s = soon[slot]
        if s and s[1] ~= r[1] then
            local fs = facts and facts[s[1]]
            where = where .. "\n|cffffd040" .. string.format(T("Upgrade no nível %d: %s", "Upgrade at level %d: %s"), s[3], itemName(s[1], fs)) .. "|r"
        end
        table.insert(list, {
            text = string.format("%s|cffaaaaaa%s:|r %s%s", ok and "|cff40ff40[ok] |r" or "", RX:IsPT() and (SLOT_PT[slot] or slot) or slot,
                itemName(r[1], f), r.suffix and (" " .. r.suffix) or ""),
            sub = where ~= "" and where or nil,
            itemID = r[1],
            selected = ok,
            onClick = function() local GQ = _G.GearQuest; if GQ and GQ.Log and GQ.Log.Toggle then GQ.Log:Toggle() end end,
        })
    end
    if total == 0 then
        table.insert(list, { text = T("Nenhuma recomendação para o seu nível nesta spec.", "No recommendation for your level in this spec.") })
    else
        list[1].sub = (list[1].sub and (list[1].sub .. "\n") or "") ..
            string.format(T("|cff40ff40%d de %d|r espaços já com o item recomendado (GearQuest, spec %s).", "|cff40ff40%d of %d|r slots already have the recommended item (GearQuest, %s spec)."), have, total, spec or "?")
    end
    return list
end

----------------------------------------------------------------------
-- Pontos de grind e masmorras como itens do menu
----------------------------------------------------------------------
local function spotItem(sp)
    local info = C_Map.GetMapInfo(sp.m)
    return {
        text = string.format("%s |cffaaaaaa(%d-%d)|r", (RX:IsPT() and sp.pname) or sp.name, sp.lo, sp.hi),
        sub = string.format(T("%s · %d juntos · ~%.0f xp por mob%s", "%s · %d together · ~%.0f xp per mob%s"), info and info.name or "?", sp.count, sp.xpk,
            sp.dist > 0 and string.format(T(" · ~%.0f m", " · ~%.0f m"), sp.dist * 0.9144) or ""),
        tip = T("Clique: apontar a seta, a rota e o mapa para este ponto.", "Click: point the arrow, route and map to this spot."),
        onClick = function() RX.Arrow:PointTo(RX.Leveling:SpotStep(sp), true); RX:Update(true) end,
    }
end

local function dungeonStep(dg)
    if not (dg.map and dg.x) then return nil end
    return { t = "G", m = dg.map, x = dg.x, y = dg.y, flags = {}, external = true, d = RX.Leveling.DungeonName(dg), note = RX.Leveling.DungeonWhere(dg) }
end

function FM:DungeonDetail(dg)
    local LV = RX.Leveling
    local party = LV:Party()
    local list = { { header = true, text = RX.Leveling.DungeonName(dg) .. (dg.forever and " |cff40c0ff[Forever]|r" or ""),
        sub = string.format(T("Níveis %d-%d · %s · ~%d mortes por run", "Levels %d-%d · %s · ~%d kills per run"), dg.min, dg.max, RX.Leveling.DungeonWhere(dg), dg.kills) } }
    for _, mode in ipairs({ { "group", "Grupo de 5", "5-player group" }, { "duo", "Duo", "Duo" }, { "solo", "Solo", "Solo" } }) do
        local r = LV:Dungeon(dg, mode[1], party)
        table.insert(list, {
            text = string.format("%s%s|r  ~%s xp/h", r.ok and "|cff40ff40" or "|cffaaaaaa", T(mode[2], mode[3]), fmt(r.xph)),
            sub = string.format(T("~%s xp por run · ~%.0f min · %s", "~%s xp per run · ~%.0f min · %s"), fmt(r.xp), r.minutes, r.why),
        })
    end
    local step = dungeonStep(dg)
    if step then
        table.insert(list, { text = T("Apontar a seta para a entrada", "Point the arrow to the entrance") .. (dg.approx and T(" (aprox.)", " (approx.)") or ""),
            onClick = function() RX.Arrow:PointTo(step, true); RX:Update(true) end })
    else
        table.insert(list, { text = T("Entrada ainda não mapeada: ", "Entrance not mapped yet: ") .. RX.Leveling.DungeonWhere(dg) })
    end
    table.insert(list, { text = T("Iniciar o Cronômetro de XP", "Start the XP Timer"), onClick = function()
        RX.Timer:Show(); RX.Timer.frame.name:SetText(RX.Leveling.DungeonName(dg) .. " · " .. LV:PartyText(party)); if not RX.Timer.running then RX.Timer:Toggle() end
    end })
    return list
end

local function dungeonItems(mode, title)
    local LV = RX.Leveling
    local party = LV:Party()
    local pl = UnitLevel("player")
    local list = { { header = true, text = title } }
    local rows = {}
    for _, dg in ipairs(RX.DungeonList or {}) do
        if pl >= dg.min - 3 and pl <= dg.max + 12 then
            local r = (mode ~= "all") and LV:Dungeon(dg, mode, party) or nil
            if mode == "all" or r.ok then
                if mode == "all" then
                    local g, d, s = LV:Dungeon(dg, "group", party), LV:Dungeon(dg, "duo", party), LV:Dungeon(dg, "solo", party)
                    local best = math.max(g.ok and g.xph or 0, d.ok and d.xph or 0, s.ok and s.xph or 0)
                    table.insert(rows, { xph = best, item = {
                        text = string.format("%s|r %d-%d%s", (g.ok or d.ok or s.ok) and "|cff40ff40" .. RX.Leveling.DungeonName(dg) or "|cffaaaaaa" .. RX.Leveling.DungeonName(dg), dg.min, dg.max, dg.forever and " |cff40c0ff[Forever]|r" or ""),
                        sub = string.format(T("Grupo %s · Duo %s · Solo %s  (xp/h)", "Group %s · Duo %s · Solo %s  (xp/h)"),
                            g.ok and fmt(g.xph) or "-", d.ok and fmt(d.xph) or "-", s.ok and fmt(s.xph) or "-") .. " · " .. RX.Leveling.DungeonWhere(dg),
                        children = function() return FM:DungeonDetail(dg) end } })
                else
                    table.insert(rows, { xph = r.xph, item = {
                        text = string.format("%s %d-%d%s", RX.Leveling.DungeonName(dg), dg.min, dg.max, dg.forever and " |cff40c0ff[Forever]|r" or ""), xp = r.xp,
                        sub = string.format(T("~%.0f min · ~%s xp/h · %s", "~%.0f min · ~%s xp/h · %s"), r.minutes, fmt(r.xph), r.why),
                        children = function() return FM:DungeonDetail(dg) end } })
                end
            end
        end
    end
    table.sort(rows, function(a, b) return a.xph > b.xph end)
    for _, r in ipairs(rows) do table.insert(list, r.item) end
    if #rows == 0 then
        table.insert(list, { text = mode == "solo" and T("Nenhuma masmorra possível de solar no seu nível agora.", "No dungeon you can solo at your level right now.")
            or T("Nenhuma masmorra viável agora.", "No viable dungeon right now."),
            sub = mode == "solo" and T("Para solar com conforto, sua classe precisa estar alguns níveis acima do máximo da masmorra (e os mobs ainda não podem ser cinzas).",
                "To solo comfortably your class needs to be a few levels above the dungeon's max (and mobs must not be grey yet).") or nil })
    end
    return list
end

function FM:SoloItems()
    local LV = RX.Leveling
    local _, classFile = UnitClass("player")
    local build = self.Build[classFile]
    local list = { { header = true, text = T("Farm Solo", "Solo farming") .. " · " .. LV.ClassName(classFile, (UnitClass("player"))) .. " " .. UnitLevel("player"),
        sub = build and (RX:IsPT() and build.tipPT or build.tipEN) or nil } }
    table.insert(list, { header = true, text = T("Pontos de grind (clique para a seta)", "Grind spots (click for the arrow)") })
    for _, sp in ipairs(LV:GrindSpots("solo", 6)) do table.insert(list, spotItem(sp)) end
    local tq = RX.Talents and RX.Talents:QuickItem("grind"); if tq then table.insert(list, tq) end
    table.insert(list, { text = T("Masmorras para solar", "Dungeons to solo"), children = function() return dungeonItems("solo", T("Masmorras que dá para solar", "Dungeons you can solo")) end })
    table.insert(list, { text = T("Equipamento para farm", "Farming gear"), children = function() return FM:GearItems() end })
    table.insert(list, { text = T("Cronômetro de XP", "XP Timer"), onClick = function() RX.Timer:ToggleWindow() end })
    return list
end

function FM:DuoItems()
    local LV = RX.Leveling
    local party = LV:Party()
    local tactic
    local _, me = UnitClass("player")
    local DUO_TIP = {
        PALADIN = { "Paladino + Mago: o paladino junta 4-6 mobs (Consagração segura a atenção), o mago congela (Nova Gélida) e usa Explosão Arcana/Nevasca. É o combo do 1º 60 do Forever.",
            "Paladin + Mage: the paladin gathers 4-6 mobs (Consecration holds aggro), the mage freezes (Frost Nova) and uses Arcane Explosion/Blizzard. It's the combo of Forever's first 60." },
        MAGE = { "Mago no duo: deixe o parceiro (de preferência paladino/guerreiro) juntar 4-6 mobs; você usa Nova Gélida, se afasta e solta Nevasca/Explosão Arcana. Faça água/comida para os dois.",
            "Mage in a duo: let your partner (ideally a paladin/warrior) gather 4-6 mobs; Frost Nova, step back and cast Blizzard/Arcane Explosion. Conjure water/food for both." },
        WARRIOR = { "Guerreiro: você tanka (Trovoada + Fender em grupos) e o parceiro faz dano; com curador, dá para puxar 3-4.", "Warrior: you tank (Thunder Clap + Sunder on packs) and your partner deals damage; with a healer you can pull 3-4." },
        PRIEST = { "Sacerdote: Escudo no parceiro, Palavra das Sombras: Dor em vários mobs e cura quando precisar.", "Priest: Shield your partner, Shadow Word: Pain on several mobs and heal when needed." },
        WARLOCK = { "Bruxo: Voidwalker tanka, DoTs em todos; com um parceiro de AoE vocês limpam grupos.", "Warlock: Voidwalker tanks, DoT everything; with an AoE partner you clear packs." },
        HUNTER = { "Caçador: o pet segura um mob, vocês dois focam o mesmo alvo.", "Hunter: the pet holds one mob, you both focus the same target." },
        ROGUE = { "Ladino: deixe o parceiro puxar e bata pelas costas; mobs um a um.", "Rogue: let your partner pull and hit from behind; one mob at a time." },
        DRUID = { "Druida: urso para tankar grupos pequenos, ou gato + cura no parceiro.", "Druid: bear to tank small packs, or cat + heals on your partner." },
        SHAMAN = { "Xamã: totens para os dois, Choque de Terra e cura rápida; bom parceiro para qualquer classe.", "Shaman: totems for both, Earth Shock and quick heals; a good partner for any class." },
    }
    if DUO_TIP[me] then tactic = RX:IsPT() and DUO_TIP[me][1] or DUO_TIP[me][2] end
    local list = { { header = true, text = T("Farm Duo", "Duo farming") .. " · " .. LV:PartyText(party),
        sub = (tactic and (tactic .. "\n") or "") .. T("Fiquem no MESMO nível: se um for muito mais alto que os mobs, ninguém ganha XP.", "Stay at the SAME level: if one is far above the mobs, nobody gets XP.") } }
    if #party < 2 then table.insert(list, { text = T("(você não está em grupo: cálculos para um duo do seu nível)", "(not in a group: calculated for a duo at your level)") }) end
    table.insert(list, { header = true, text = T("Pontos com grupos densos para AoE", "Spots with dense packs for AoE") })
    for _, sp in ipairs(LV:GrindSpots("duo", 6)) do table.insert(list, spotItem(sp)) end
    local tq = RX.Talents and RX.Talents:QuickItem("duo"); if tq then table.insert(list, tq) end
    table.insert(list, { text = T("Masmorras para o duo", "Dungeons for the duo"), children = function() return dungeonItems("duo", T("Masmorras que o duo dá conta", "Dungeons the duo can handle")) end })
    table.insert(list, { text = T("Equipamento para farm", "Farming gear"), children = function() return FM:GearItems() end })
    table.insert(list, { text = T("Cronômetro de XP", "XP Timer"), onClick = function() RX.Timer:ToggleWindow() end })
    return list
end

-- Itens do 2º nível do menu
----------------------------------------------------------------------
-- Farm de OURO + XP: locais clássicos por nível, posição real dos mobs, adaptado à sua classe
----------------------------------------------------------------------
local AOE_CLASS = { MAGE = true, PALADIN = true, WARLOCK = true, WARRIOR = true, DRUID = true }

local function howHere(classFile, entry, lvl, mode)
    local aoe = false
    for _, t in ipairs(entry.tags) do if t == "aoe" then aoe = true end end
    if classFile == "MAGE" then
        return aoe and T("Mago: junte 3-5, Nova Gélida e Explosão Arcana/Nevasca.", "Mage: gather 3-5, Frost Nova and Arcane Explosion/Blizzard.")
            or T("Mago: 1-2 de cada vez com Gelo; poupe mana com a varinha.", "Mage: 1-2 at a time with Frost; save mana with the wand.")
    elseif classFile == "PALADIN" then
        return (aoe and lvl >= 40) and T("Paladino: junte 3-4 com Consagração e Aura de Retribuição (build Proteção).", "Paladin: gather 3-4 with Consecration and Retribution Aura (Protection build).")
            or T("Paladino: 1-2 de cada vez com Selo + Julgamento.", "Paladin: 1-2 at a time with Seal + Judgement.")
    elseif classFile == "WARLOCK" then return T("Bruxo: DoTs em 2-3, Voidwalker tanka, Drenar Vida.", "Warlock: DoT 2-3, Voidwalker tanks, Drain Life.")
    elseif classFile == "HUNTER" then return T("Caçador: pet tanka, um de cada vez.", "Hunter: pet tanks, one at a time.")
    elseif classFile == "PRIEST" then return T("Sacerdote: Escudo + DoT, varinha para finalizar.", "Priest: Shield + DoT, wand to finish.")
    elseif classFile == "WARRIOR" then return T("Guerreiro: 1-2 de cada vez, coma entre as puxadas.", "Warrior: 1-2 at a time, eat between pulls.")
    end
    return T("Um ou dois de cada vez.", "One or two at a time.")
end

-- Tipo de ataque do mob pelo nome (inglês): conjurador (magia), à distância ou corpo a corpo
local CASTER = { "Mystic", "Shaman", "Witch Doctor", "Mage", "Priest", "Necromancer", "Warlock", "Geomancer", "Oracle", "Seer",
    "Shadowcaster", "Conjurer", "Sorcerer", "Enchanter", "Hexer", "Medicine Man", "Spellbinder", "Summoner", "Thaumaturge",
    "Acolyte", "Elementalist", "Pyromancer", "Flamecaller", "Channeler", "Tidehunter", "Darkweaver", "Shadowmage", "Invoker",
    "Chanter", "Cleric", "Augur", "Firecaller", "Mage", "Neophyte", "Adept", "Shadow Priest", "Ritualist", "Felcaller", "Wizard",
    "Storm", "Spirit", "Ghost", "Wraith", "Banshee", "Lava", "Blaze", "Fire", "Ice Thistle Patriarch" }
local RANGED = { "Hunter", "Headhunter", "Axe Thrower", "Archer", "Marksman", "Rifleman", "Sharpshooter", "Shadowhunter",
    "Trapper", "Bowman", "Gunner", "Sniper", "Spearthrower", "Javelineer", "Dune Smasher", "Gunsmith", "Blaster", "Bombardier" }

local function mobRole(en)
    for _, k in ipairs(CASTER) do if en:find(k, 1, true) then return "c" end end
    for _, k in ipairs(RANGED) do if en:find(k, 1, true) then return "r" end end
    return "m"
end

-- pano que cai pelo nível do mob e um valor médio aproximado (em ouro) por peça
local function clothFor(lvl)
    if lvl >= 50 then return T("Tecido de Runas", "Runecloth"), 0.5 end
    if lvl >= 40 then return T("Tecido Mágico", "Mageweave"), 0.3 end
    if lvl >= 28 then return T("Seda", "Silk"), 0.15 end
    return T("Lã", "Wool"), 0.08
end

local function fmtK(n)
    if n >= 1000 then return string.format("%.1fk", n / 1000) end
    return string.format("%.0f", n)
end

local GOLD_ICON = "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t"

-- mobs mortos por hora (estimativa) por classe e tipo de local
local function killsPerHour(classFile, lvl, aoe, mode)
    local aoeClass = classFile == "MAGE" or (classFile == "PALADIN" and lvl >= 40) or classFile == "WARLOCK"
    if mode == "duo" then return aoe and 130 or 95 end
    if aoe and aoeClass then return 75 end
    if classFile == "WARRIOR" or classFile == "PRIEST" then return 45 end
    return 55
end

-- drops mais valiosos do local (Data/GoldDrops.lua): nome no idioma do jogo com a cor da qualidade,
-- chance por abate e preço (leilão pelo Auctionator, senão vendedor)
local QCOLOR = { [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd", [4] = "ffa335ee" }
local function coin(c)
    if RX.Market and RX.Market.Money then return RX.Market.Money(c) end
    return string.format("%.2fg", c / 10000)
end
local function dropLine(d)
    local id, chance, sell, q, en = d[1], d[2], d[3], d[4], d[5]
    local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and (GetItemInfo(id)))
    if not name and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    local ah = RX.Market and RX.Market:Price(id)
    local price = ah and (T("leilão ", "AH ") .. coin(ah)) or (T("vende ", "sells ") .. coin(sell))
    local pct = chance >= 1 and string.format("%.0f%%", chance) or (chance >= 0.1 and string.format("%.1f%%", chance) or string.format("%.2f%%", chance))
    return string.format("|c%s%s|r |cffaaaaaa%s · %s|r", QCOLOR[q] or QCOLOR[1], name or en, pct, price)
end
function FM:DropLines(e)
    local d = RX.GoldDrops and RX.GoldDrops[e.map .. ":" .. e.mob]
    if not d then return nil end
    local lines = {}
    if d.top and #d.top > 0 then
        local p = {}
        for _, x in ipairs(d.top) do p[#p + 1] = dropLine(x) end
        lines[#lines + 1] = "|cffffd100" .. T("Drops que mais rendem: ", "Best-paying drops: ") .. "|r" .. table.concat(p, ", ")
    end
    if d.rare and #d.rare > 0 then
        local p = {}
        for _, x in ipairs(d.rare) do p[#p + 1] = dropLine(x) end
        lines[#lines + 1] = "|cffffd100" .. T("Raros (vendem bem): ", "Rare (sell well): ") .. "|r" .. table.concat(p, ", ")
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

function FM:GoldItems(mode)
    local LV = RX.Leveling
    local _, classFile = UnitClass("player")
    local pl = UnitLevel("player")
    local me = RX.Travel:PlayerPos()
    local rows = {}
    for _, e in ipairs(RX.GoldSpots or {}) do
        if pl >= e.min - 2 and pl <= e.max + 4 then
            local tags = {}
            for _, t in ipairs(e.tags) do tags[t] = true end
            -- todos os mobs desse grupo na zona (banco do Questie): composição e o ponto mais denso
            local best, bestN
            local mobs, seen = {}, {}
            for _, g in ipairs(RX.GrindSpots or {}) do
                if g[1] == e.map and g[7] and g[7]:find(e.mob, 1, true) then
                    if not bestN or g[6] > bestN then best, bestN = g, g[6] end
                    if not seen[g[7]] then
                        seen[g[7]] = true
                        mobs[#mobs + 1] = { en = g[7], name = (RX:IsPT() and g[8]) or g[7], lo = g[4], hi = g[5], role = mobRole(g[7]) }
                    end
                end
            end
            local mlo = best and best[4] or e.min
            local mhi = best and best[5] or e.max
            local mobLvl = math.floor((mlo + mhi) / 2)
            local maxOK = (mode == "duo") and pl + 3 or pl + 1
            -- solo: mobs muito acima do seu nível ficam de fora; duo aguenta mais
            if mobLvl <= maxOK and mobLvl >= LV.GreyLevel(pl) + 1 then
                local xpk = LV.MobXP(pl, mobLvl, false)
                local kph = killsPerHour(classFile, pl, tags.aoe, mode)
                if bestN and bestN < 12 then kph = kph * 0.8 end            -- poucos mobs: anda mais entre um e outro
                local xph = xpk * kph * ((mode == "duo") and 0.5 or 1)       -- em duo o XP é dividido
                -- ouro/hora (estimativa): moedas de humanoides + pano + materiais
                local coinKill = tags.coin and (mobLvl * mobLvl * 0.3 / 10000) or 0
                local share = (mode == "duo") and 0.5 or 1
                local coinH = coinKill * kph * share
                local clothName, clothVal = clothFor(mobLvl)
                local clothH = tags.cloth and (kph * 0.3 * share) or 0
                local matH = (tags.elemental and kph * 0.12 * share or 0) + (tags.leather and kph * 0.8 * share or 0)
                local goldH = coinH + clothH * clothVal + (tags.elemental and matH * 1.0 or 0) + (tags.leather and matH * 0.15 or 0)

                -- composição do grupo de mobs
                local nm, nr, nc = 0, 0, 0
                for _, m in ipairs(mobs) do if m.role == "c" then nc = nc + 1 elseif m.role == "r" then nr = nr + 1 else nm = nm + 1 end end
                local comp = {}
                if nm > 0 then comp[#comp + 1] = string.format(T("%d corpo a corpo", "%d melee"), nm) end
                if nr > 0 then comp[#comp + 1] = string.format(T("|cffffb060%d à distância|r", "|cffffb060%d ranged|r"), nr) end
                if nc > 0 then comp[#comp + 1] = string.format(T("|cffb090ff%d conjurador(es) - dano mágico|r", "|cffb090ff%d caster(s) - magic damage|r"), nc) end
                table.sort(mobs, function(a, b) return a.lo < b.lo end)
                local names = {}
                for i, m in ipairs(mobs) do
                    if i <= 5 then
                        local tag = (m.role == "c") and T(" magia", " magic") or (m.role == "r") and T(" distância", " ranged") or ""
                        names[#names + 1] = string.format("%s |cffaaaaaa%d-%d%s|r", m.name, m.lo, m.hi, tag)
                    end
                end

                local drops = {}
                if tags.coin then drops[#drops + 1] = string.format(T("moedas ~%.1f ouro/h", "coin ~%.1fg/h"), coinH) end
                if tags.cloth then drops[#drops + 1] = string.format(T("~%d %s/h", "~%d %s/h"), math.floor(clothH + 0.5), clothName) end
                if tags.elemental then drops[#drops + 1] = string.format(T("~%d materiais elementais/h (leilão)", "~%d elemental mats/h (AH)"), math.floor(matH + 0.5)) end
                if tags.leather then drops[#drops + 1] = string.format(T("~%d couros/h com Esfolar", "~%d leathers/h with Skinning"), math.floor(matH + 0.5)) end

                local dist, cont
                if best and me then
                    local c, wx, wy = RX.Travel.world(best[1], best[2], best[3])
                    cont = c
                    if c == me.cont then dist = math.sqrt((wx - me.wx) ^ 2 + (wy - me.wy) ^ 2) end
                end
                -- nota: XP/h e ouro/h juntos; duo valoriza grupos (AoE); solo penaliza muitos conjuradores/à distância
                local score = 1  -- multiplicador; a nota final (XP/h + ouro/h normalizados) é calculada depois
                if mode == "duo" and tags.aoe then score = score * 1.25 end
                if mode ~= "duo" and nc + nr >= 3 then score = score * 0.85 end
                if dist then score = score * (1 - math.min(0.25, dist / 40000)) elseif best then score = score * 0.75 end   -- outro continente
                local zoneName = RX.MapName(e.map, "?")
                local mobName = best and ((RX:IsPT() and best[8]) or best[7]) or e.mob
                local step = best and { t = "G", m = best[1], x = best[2], y = best[3], flags = {}, external = true, d = mobName, note = zoneName } or nil
                table.insert(rows, { score = score, xph = xph, goldH = goldH, zone = zoneName, mob = mobName, item = {
                    text = string.format("%s |cffaaaaaa(%d-%d)|r", mobName, mlo, mhi),
                    sub = table.concat({
                        string.format("|cff40ff40XP ~%s/h|r   %s|cffffd100~%.1f/h|r   |cffaaaaaa%s|r", fmtK(xph), GOLD_ICON, goldH,
                            (mode == "duo") and T("(por pessoa)", "(per person)") or ""),
                        string.format("%s%s", zoneName, best and string.format(" (%.0f, %.0f) · %d %s", best[2], best[3], best[6], T("mobs", "mobs")) or ""),
                        T("Mobs: ", "Mobs: ") .. table.concat(comp, " · "),
                        "|cffd0d0d0" .. table.concat(names, ", ") .. "|r",
                        T("Drop: ", "Loot: ") .. table.concat(drops, " · "),
                        FM:DropLines(e) or "",
                        "|cffc8c8c8" .. ((RX:IsPT() and e.pt) or e.en) .. "|r",
                        "|cff80c0ff" .. howHere(classFile, e, pl, mode) .. "|r",
                        dist and string.format(T("~%.0f m de você", "~%.0f m from you"), dist * 0.9144) or (best and ("|cffff9050" .. T("outro continente", "other continent") .. "|r") or ""),
                    }, "\n"),
                    tip = T("Clique: apontar a seta, a rota e o mapa para este local.", "Click: point the arrow, route and map to this spot."),
                    onClick = step and function() RX.Arrow:PointTo(step, true); RX:Update(true); if RX.Party then RX.Party:SendSpot(step) end end or nil,
                } })
            end
        end
    end
    -- nota: metade XP/h, metade ouro/h (cada um em relação ao melhor da lista) x ajustes de modo/distância
    local mx, mg = 1, 0.01
    for _, r in ipairs(rows) do mx = math.max(mx, r.xph); mg = math.max(mg, r.goldH) end
    for _, r in ipairs(rows) do r.score = (r.xph / mx + r.goldH / mg) * r.score end
    table.sort(rows, function(a, b) return a.score > b.score end)
    -- tabela resumo no topo: o que mais rende
    local tbl = {}
    for i, r in ipairs(rows) do
        if i <= 6 then
            tbl[#tbl + 1] = string.format("|cffffd100%d.|r %s |cffaaaaaa- %s|r  |cff40ff40%s xp/h|r  |cffffd100%.1f ouro/h|r", i, r.mob, r.zone, fmtK(r.xph), r.goldH)
        end
    end
    local list = { { header = true, text = (mode == "duo") and T("Farm de ouro + XP em duo", "Gold + XP farming as a duo") or T("Farm de ouro + XP solo", "Solo gold + XP farming"),
        sub = string.format(T("Para %s nível %d. Valores por hora são estimativas (moedas + pano/materiais pelo preço médio). Meça com o Cronômetro.",
            "For %s level %d. Per-hour values are estimates (coin + cloth/mats at average prices). Measure with the Timer."), LV.ClassName(classFile, (UnitClass("player"))), pl)
            .. ((mode == "duo") and T("\nDuo: o XP e o loot são divididos; prefere locais com mobs em grupo (AoE).", "\nDuo: XP and loot are split; prefers packed spots (AoE).")
                or T("\nSolo: prefere mobs corpo a corpo e espalhados; até 1 nível acima do seu.", "\nSolo: prefers melee, spread-out mobs; up to 1 level above you."))
            .. (#tbl > 0 and ("\n\n" .. table.concat(tbl, "\n")) or "") } }
    for i, r in ipairs(rows) do if i <= 10 then table.insert(list, r.item) end end
    if #rows == 0 then table.insert(list, { text = T("Nenhum local conhecido para o seu nível agora.", "No known spot for your level right now.") }) end
    table.insert(list, { text = T("Cronômetro de XP (meça o local)", "XP Timer (measure the spot)"), onClick = function() RX.Timer:ToggleWindow() end })
    return list
end

function FM:Items()
    local LV = RX.Leveling
    local pl = UnitLevel("player")
    return {
        { header = true, text = T("Masmorras", "Dungeons"),
          sub = string.format(T("Mobs nível %d ou menos são cinzas para você (0 XP).", "Mobs level %d or lower are grey for you (0 XP)."), LV.GreyLevel(pl)) },
        { text = T("Masmorras do seu nível", "Dungeons for your level"), sub = T("grupo / duo / solo com XP por hora", "group / duo / solo with XP per hour"),
          children = function() return dungeonItems("all", T("Masmorras (melhor XP/h primeiro)", "Dungeons (best XP/h first)")) end },
        { text = T("Equipamento para farm", "Farming gear"), sub = T("itens do GearQuest para a build de farm da sua classe", "GearQuest items for your class farming build"), children = function() return FM:GearItems() end },
        { text = T("Talentos (Talents Forever)", "Talents (Talents Forever)"), sub = T("qual build #n usar para quests, grind, duo e masmorra", "which #n build to use for questing, grind, duo and dungeons"), children = function() return RX.Talents:Items() end },
    }
end

-- Grind no mundo aberto: farm de ouro + XP solo e duo
function FM:OpenWorldItems()
    local pl = UnitLevel("player")
    return {
        { header = true, text = T("Grind no mundo aberto", "Open-world grinding"),
          sub = string.format(T("Mobs nível %d ou menos são cinzas para você (0 XP). Meça o XP/h com o botão Cronômetro.", "Mobs level %d or lower are grey for you (0 XP). Measure XP/h with the Timer button."), RX.Leveling.GreyLevel(pl)) },
        { text = T("Farm de ouro + XP (solo)", "Gold + XP farming (solo)"), sub = T("locais com muito mob e bom drop para a sua classe", "spots with many mobs and good loot for your class"), children = function() return FM:GoldItems("solo") end },
        { text = T("Farm de ouro + XP (duo)", "Gold + XP farming (duo)"), sub = T("locais com grupos de mobs para AoE", "spots with packs for AoE"), children = function() return FM:GoldItems("duo") end },
    }
end
