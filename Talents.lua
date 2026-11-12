-- Talentos: lê as builds populares do Talents Forever (abas Leveling / PvE / PvP, numeradas #1, #2...)
-- e recomenda qual usar para cada objetivo (upar com quests, grind solo, duo, masmorra), pela sua classe.
-- Clicar numa build carrega o plano no Talents Forever (/talents load <código>) — o personagem não muda nada.
local _, RX = ...
local TL = {}
RX.Talents = TL
local T = RX.T

-- Spec preferida por classe para cada objetivo (em ordem de preferência; nomes em inglês como no Talents Forever)
local PREF = {
    PALADIN = { leveling = { "Retribution" }, grind = { "Protection", "Retribution" }, duo = { "Protection", "Retribution" },
        tank = { "Protection" }, dps = { "Retribution" }, healer = { "Holy" } },
    MAGE = { leveling = { "Frost" }, grind = { "Frost", "Arcane" }, duo = { "Frost", "Arcane" }, dps = { "Frost", "Fire", "Arcane" } },
    WARRIOR = { leveling = { "Arms", "Fury" }, grind = { "Arms", "Fury" }, duo = { "Protection", "Arms" }, tank = { "Protection" }, dps = { "Fury", "Arms" } },
    PRIEST = { leveling = { "Shadow" }, grind = { "Shadow" }, duo = { "Shadow", "Discipline" }, healer = { "Holy", "Discipline" }, dps = { "Shadow" } },
    WARLOCK = { leveling = { "Affliction", "Demonology" }, grind = { "Affliction", "Demonology" }, duo = { "Affliction" }, dps = { "Destruction", "Affliction" } },
    HUNTER = { leveling = { "Beast Mastery", "Marksmanship" }, grind = { "Beast Mastery" }, duo = { "Beast Mastery", "Marksmanship" }, dps = { "Marksmanship", "Beast Mastery" } },
    ROGUE = { leveling = { "Combat" }, grind = { "Combat" }, duo = { "Combat" }, dps = { "Combat", "Assassination" } },
    DRUID = { leveling = { "Feral Combat", "Feral" }, grind = { "Feral Combat", "Feral" }, duo = { "Feral Combat", "Feral" },
        tank = { "Feral Combat", "Feral" }, healer = { "Restoration" }, dps = { "Feral Combat", "Balance" } },
    SHAMAN = { leveling = { "Enhancement" }, grind = { "Enhancement" }, duo = { "Enhancement", "Restoration" }, healer = { "Restoration" }, dps = { "Enhancement", "Elemental" } },
}

-- Resumo bem simples, por classe, de que build usar e por quê
local ADVICE = {
    PALADIN = {
        "UMA BUILD PARA TUDO (sem gastar ouro com respec): Proteção com uns 15+ pontos em Retribuição. Segura o agro para o mago fazer AoE no duo, tanka as masmorras do seu nível e ainda mata sozinho se o mago sair (Consagração + Selo + Aura de Retribuição). Mata um pouco mais devagar sozinho que Retribuição pura, mas serve para as 3 coisas.\nUpar com quests (normal): Retribuição. Mata mais rápido e é o que a comunidade do Forever mais marca para leveling. Proteção mata devagar sozinho.\nGrind de AoE (juntar vários mobs com Consagração + Aura de Retribuição): Proteção, a partir de ~40, quando você aguenta 3-6 mobs. Antes disso, fique em Retribuição.\nDuo com mago: você tanka (Proteção) e o mago faz o AoE. Masmorra: Proteção para tankar, Retribuição para dano.",
        "ONE BUILD FOR EVERYTHING (no gold on respecs): Protection with ~15+ points in Retribution. Holds aggro so the mage can AoE in the duo, tanks the dungeons for your level and still kills solo if the mage leaves (Consecration + Seal + Retribution Aura). A bit slower solo than pure Retribution, but it covers all 3.\nQuesting (normal): Retribution. Kills fastest and it's what Forever's community tags most for leveling. Protection kills slowly solo.\nAoE grinding (gathering many mobs with Consecration + Retribution Aura): Protection, from ~40 when you can hold 3-6 mobs. Before that, stay Retribution.\nDuo with a mage: you tank (Protection) and the mage AoEs. Dungeons: Protection to tank, Retribution for damage." },
    MAGE = {
        "Gelo para tudo no leveling: Nevasca Aprimorada, Barreira de Gelo e Nova Gélida deixam você juntar e matar grupos de mobs (AoE). Fogo só vale em grupo/masmorra para dano.",
        "Frost for all of leveling: Improved Blizzard, Ice Barrier and Frost Nova let you gather and kill packs (AoE). Fire is only worth it for group/dungeon damage." },
    WARRIOR = { "Armas ou Fúria para upar (arma de duas mãos lenta). Proteção só para tankar masmorra.", "Arms or Fury to level (slow two-hander). Protection only to tank dungeons." },
    PRIEST = { "Sombra para upar e farmar sozinho; Sagrado/Disciplina só se for curar em grupo.", "Shadow to level and farm solo; Holy/Discipline only to heal groups." },
    WARLOCK = { "Suplício (ou Demonologia) com o Voidwalker tankando é o leveling mais seguro.", "Affliction (or Demonology) with the Voidwalker tanking is the safest leveling." },
    HUNTER = { "Domínio das Feras: o pet faz quase tudo, é o leveling mais rápido do caçador.", "Beast Mastery: the pet does almost everything, the hunter's fastest leveling." },
    ROGUE = { "Combate para upar; mobs um a um.", "Combat to level; one mob at a time." },
    DRUID = { "Feral (gato para matar, urso para tankar) para upar e farmar.", "Feral (cat to kill, bear to tank) to level and farm." },
    SHAMAN = { "Aperfeiçoamento com arma de duas mãos lenta para upar.", "Enhancement with a slow two-hander to level." },
}

local function data(classFile)
    local D = _G.TalentsForeverBookData
    return D and D.popular and D.popular[classFile], D
end

local function treeLoc(classFile, en)
    local TF = _G.TalentsForeverBook
    if TF and TF.TreeLoc then
        local ok, n = pcall(TF.TreeLoc, classFile, en)
        if ok and n then return n end
    end
    return en
end

local function leadOf(b)
    if type(b.lead) == "table" then return b.lead[1], b.lead end
    return b.lead, { b.lead }
end

-- Melhor build da lista para uma spec preferida: devolve build, índice (#n) e nome da lista
-- Build híbrida: spec de tanque com o máximo de pontos na árvore de dano (tanka masmorra, segura agro no duo e ainda mata sozinho)
local HYBRID = { PALADIN = { tank = "Protection", dmgTree = 3 }, WARRIOR = { tank = "Protection", dmgTree = 1 }, DRUID = { tank = "Feral Combat", dmgTree = 2 } }

function TL:PickHybrid(classFile)
    local pop = data(classFile)
    local h = HYBRID[classFile]
    if not pop or not pop.fors or not h then return self:Pick(classFile, "leveling") end
    local best, bi, bk, bscore
    for _, key in ipairs({ "leveling", "pve" }) do
        for i, b in ipairs(pop.fors[key] or {}) do
            local lead = leadOf(b)
            if lead == h.tank and b.pts then
                local dmg = b.pts[h.dmgTree] or 0
                local score = dmg * 3 + (b.tags or 0) + ((key == "leveling") and 5 or 0)
                if not bscore or score > bscore then best, bi, bk, bscore = b, i, key, score end
            end
        end
    end
    if best then return best, bi, bk end
    return self:Pick(classFile, "tank")
end

function TL:Pick(classFile, goal)
    if goal == "hybrid" then return self:PickHybrid(classFile) end
    local pop = data(classFile)
    if not pop or not pop.fors then return nil end
    local prefs = (PREF[classFile] or {})[goal] or {}
    local listKey = (goal == "tank" or goal == "dps" or goal == "healer") and "pve" or "leveling"
    local function search(key, roleFilter)
        local list = pop.fors[key] or {}
        for _, spec in ipairs(prefs) do
            for i, b in ipairs(list) do
                local lead = leadOf(b)
                if lead == spec and (not roleFilter or b.role == roleFilter) then return b, i, key end
            end
        end
        return nil
    end
    local b, i, k = search(listKey, listKey == "pve" and goal or nil)
    if not b and listKey == "leveling" then b, i, k = search("pve") end
    if not b and listKey == "pve" then b, i, k = search("pve") end
    if not b then
        local list = pop.fors[listKey] or {}
        if list[1] then b, i, k = list[1], 1, listKey end
    end
    return b, i, k
end

local LIST_NAME = { leveling = { "Leveling", "Leveling" }, pve = { "PvE", "PvE" }, pvp = { "PvP", "PvP" } }
local ROLE_PT = { tank = "Tanque", dps = "Dano", healer = "Cura" }

function TL:Load(code)
    if not code then return end
    if SlashCmdList and SlashCmdList.TALENTSFOREVERBOOK then
        SlashCmdList.TALENTSFOREVERBOOK("load " .. code)
    else
        RX:Print(T("Talents Forever não está ativo. Código da build: ", "Talents Forever is not enabled. Build code: ") .. code)
    end
end

function TL:BuildItem(classFile, b, idx, key, label)
    local lead, leads = leadOf(b)
    local names = {}
    for _, l in ipairs(leads or {}) do table.insert(names, treeLoc(classFile, l)) end
    local pts = b.pts and string.format("%d/%d/%d", b.pts[1] or 0, b.pts[2] or 0, b.pts[3] or 0) or ""
    local role = b.role and (" · " .. (RX:IsPT() and ROLE_PT[b.role] or b.role)) or ""
    local tab = LIST_NAME[key] and LIST_NAME[key][RX:IsPT() and 1 or 2] or key
    return {
        text = (label and ("|cffffd100" .. label .. ":|r ") or "") .. string.format("#%d %s · %s %s", idx, tab, table.concat(names, "/"), pts),
        sub = string.format(T("%d marcações%s%s · clique: abrir no Talents Forever", "%d tags%s%s · click: open in Talents Forever"), b.tags or 0, role,
            b.plus and (" · +" .. b.plus) or ""),
        tip = string.format(T("Aba %s do Talents Forever, build #%d.\nCódigo: %s\nClique para carregar o plano no Talents Forever (seu personagem não muda). Lá ele mostra qual talento pegar em cada nível.",
            "Talents Forever %s tab, build #%d.\nCode: %s\nClick to load the plan in Talents Forever (your character doesn't change). It shows which talent to take at each level."), tab, idx, b.code or "?"),
        onClick = function() TL:Load(b.code) end,
    }
end

-- Itens do submenu "Talentos"
function TL:Items()
    local _, classFile = UnitClass("player")
    local lvl = UnitLevel("player")
    local pop = data(classFile)
    local adv = ADVICE[classFile]
    local list = { { header = true, text = T("Talentos para o seu objetivo", "Talents for your goal"),
        sub = adv and (RX:IsPT() and adv[1] or adv[2]) or nil } }
    if not pop then
        table.insert(list, { text = T("Talents Forever não encontrado", "Talents Forever not found"),
            sub = T("Instale/ative o addon Talents Forever para ver e abrir as builds.", "Install/enable the Talents Forever addon to see and open builds.") })
        return list
    end
    local goals = {
        { "hybrid", HYBRID[classFile] and T("Uma build para tudo (duo + tanque + solo)", "One build for everything (duo + tank + solo)") or T("Uma build para tudo (duo + masmorra + solo)", "One build for everything (duo + dungeon + solo)") },
        { "leveling", T("Upar com quests", "Questing") },
        { "grind", T("Grind solo / AoE", "Solo grind / AoE") },
        { "duo", T("Duo", "Duo") },
        { "tank", T("Masmorra (tanque)", "Dungeon (tank)") },
        { "dps", T("Masmorra (dano)", "Dungeon (damage)") },
        { "healer", T("Masmorra (cura)", "Dungeon (healer)") },
    }
    table.insert(list, { header = true, text = T("Recomendado para você", "Recommended for you"),
        sub = string.format(T("Builds de nível 60; o Talents Forever mostra a ordem dos pontos até lá. Você está no %d: pegue os talentos na ordem da build.", "Level 60 builds; Talents Forever shows the point order up to there. You're %d: take talents in the build's order."), lvl) })
    for _, g in ipairs(goals) do
        local prefs = (PREF[classFile] or {})[g[1]]
        if prefs or (g[1] == "hybrid" and HYBRID[classFile]) then
            local b, i, k = self:Pick(classFile, g[1])
            if b then table.insert(list, self:BuildItem(classFile, b, i, k, g[2])) end
        end
    end
    -- popularidade das specs
    if pop.spec then
        local parts = {}
        for _, sp in ipairs(pop.spec) do table.insert(parts, string.format("%s %d%%", treeLoc(classFile, sp[1]), sp[2])) end
        table.insert(list, { header = true, text = T("Todas as builds (Talents Forever)", "All builds (Talents Forever)"),
            sub = T("Specs mais usadas: ", "Most used specs: ") .. table.concat(parts, ", ") .. (pop.window and (" · " .. pop.window) or "") })
    end
    for _, key in ipairs({ "leveling", "pve", "pvp" }) do
        local l = pop.fors and pop.fors[key]
        if l and #l > 0 then
            local tab = LIST_NAME[key][RX:IsPT() and 1 or 2]
            table.insert(list, { text = string.format(T("Aba %s (%d builds)", "%s tab (%d builds)"), tab, #l), children = function()
                local sub = { { header = true, text = string.format(T("Talents Forever · %s", "Talents Forever · %s"), tab) } }
                for i, b in ipairs(l) do table.insert(sub, TL:BuildItem(classFile, b, i, key)) end
                return sub
            end })
        end
    end
    table.insert(list, { text = T("Abrir o Talents Forever", "Open Talents Forever"), onClick = function()
        if SlashCmdList and SlashCmdList.TALENTSFOREVERBOOK then SlashCmdList.TALENTSFOREVERBOOK("") end
    end })
    return list
end

-- Uma linha "Talentos: #n ..." para os submenus de Farm Solo / Duo
function TL:QuickItem(goal)
    local _, classFile = UnitClass("player")
    local b, i, k = self:Pick(classFile, goal)
    if not b then return nil end
    return self:BuildItem(classFile, b, i, k, T("Talentos", "Talents"))
end
