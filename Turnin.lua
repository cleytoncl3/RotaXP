-- Modo Entregas: lista só as quests prontas do seu log e monta a melhor rota para entregar todas
local _, RX = ...
local TI = { skip = {} }
RX.Turnin = TI
local T = RX.T

local YARD_HEARTH = 900 -- se a primeira entrega estiver mais longe que isso, vale a Pedra de Regresso

-- NPC de entrega: tabela gerada (Data/Enders.lua) ou passo "Entregar" de qualquer guia
local function guideIndex()
    if TI.index then return TI.index end
    TI.index = {}
    for _, g in pairs(RX.guides) do
        for _, s in ipairs(g.steps) do
            if s.t == "T" and s.q and s.m and not TI.index[s.q] then TI.index[s.q] = s end
        end
    end
    return TI.index
end

function TI:Ender(q)
    local e = RX.Enders and RX.Enders[q]
    if e then return { m = e[1], x = e[2], y = e[3], npc = e[4], pnpc = e[5] or nil, xp = e[6], lvl = e[7] } end
    local s = guideIndex()[q]
    if s then return { m = s.m, x = s.x, y = s.y, npc = s.npc, pnpc = s.pnpc, approx = s.approx } end
    return nil
end

local function world(m, x, y)
    if not (m and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
    if ok and pos then return cont, pos.x, pos.y end
    return nil
end

local function mapName(m)
    local info = m and C_Map.GetMapInfo(m)
    return info and info.name or "?"
end

local function hasQuestItems(q)
    local objs = RX.Q:Objectives(q)
    if not objs then return false end
    for _, o in ipairs(objs) do if o.type == "item" then return true end end
    return false
end

-- Todas as quests prontas para entregar (de qualquer guia ou de fora dele)
function TI:ReadyQuests()
    local list = {}
    for id, e in pairs(RX.Q.log) do
        if not self.skip[id] and RX.Q:IsReady(id) then
            local en = self:Ender(id)
            local s = { t = "T", q = id, n = e.title or ("Quest " .. id), flags = {}, turnin = true, items = hasQuestItems(id), xpNow = self:XPFor(id) }
            if en then
                s.m, s.x, s.y, s.npc, s.pnpc, s.approx = en.m, en.x, en.y, en.npc, en.pnpc, en.approx
                s.cont, s.wx, s.wy = world(en.m, en.x, en.y)
            end
            table.insert(list, s)
        end
    end
    return list
end

-- XP que a quest vai dar para você agora
function TI:XPFor(q)
    -- o jogo informa o valor exato (já com a redução por nível) quando a função existe
    if GetQuestLogRewardXP then
        local ok, v = pcall(GetQuestLogRewardXP, q)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    local e = RX.Enders and RX.Enders[q]
    local xp, lvl = e and e[6], e and e[7]
    if not xp or xp == 0 then
        local s = guideIndex()[q]
        if s then xp, lvl = s.xp, s.lvl end
    end
    if (not xp or xp == 0) and lvl and lvl > 0 then xp = lvl * 90 end
    if not xp or xp == 0 then return 0 end
    return RX:QuestXP({ xp = xp, lvl = lvl })
end

-- Quantas quests prontas e quanto XP rendem se entregar todas
function TI:Count()
    local n, xp = 0, 0
    for id in pairs(RX.Q.log) do
        if not self.skip[id] and RX.Q:IsReady(id) then n = n + 1; xp = xp + self:XPFor(id) end
    end
    return n, xp
end

local function dist(a, bx, by) return math.sqrt((a.wx - bx) ^ 2 + (a.wy - by) ^ 2) end

-- Vizinho mais próximo, continente por continente (começa pelo seu continente)
local function order(items, startC, startX, startY)
    local route, left = {}, {}
    for _, s in ipairs(items) do if s.wx then table.insert(left, s) end end
    local c, x, y = startC, startX, startY
    while #left > 0 do
        local here = {}
        for i, s in ipairs(left) do if s.cont == c then table.insert(here, i) end end
        if #here == 0 then
            -- troca de continente: vai para o que tem mais entregas e começa pelo grupo mais denso
            local cnt = {}
            for _, s in ipairs(left) do cnt[s.cont] = (cnt[s.cont] or 0) + 1 end
            local bestC, bestN = nil, -1
            for k, v in pairs(cnt) do if v > bestN then bestC, bestN = k, v end end
            c = bestC
            local dense, denseN = nil, -1
            for _, s in ipairs(left) do
                if s.cont == c then
                    local n = 0
                    for _, o in ipairs(left) do if o.cont == c and dist(s, o.wx, o.wy) < 500 then n = n + 1 end end
                    if n > denseN then dense, denseN = s, n end
                end
            end
            x, y = dense.wx, dense.wy
            for i, s in ipairs(left) do if s == dense then here = { i } end end
            left[here[1]].newCont = (#route > 0) or (startC ~= nil and startC ~= c)
        end
        local bi, bd = nil, math.huge
        for _, i in ipairs(here) do
            local s = left[i]
            local dd = (x and y) and dist(s, x, y) or 0
            if dd < bd then bi, bd = i, dd end
        end
        local s = table.remove(left, bi)
        s.yards = (x and y and s.cont == c) and bd or nil
        table.insert(route, s)
        x, y = s.wx, s.wy
    end
    for _, s in ipairs(items) do if not s.wx then table.insert(route, s) end end
    return route
end

function TI:Route()
    local items = self:ReadyQuests()
    if #items == 0 then return {} end
    local pc, px, py
    local pmap = C_Map.GetBestMapForUnit("player")
    local pp = pmap and C_Map.GetPlayerMapPosition(pmap, "player")
    if pp then
        local x, y = pp:GetXY()
        pc, px, py = world(pmap, x, y)
    end
    local route = order(items, pc, px, py)

    -- Pedra de Regresso: se a casa tem 2+ entregas e a rota começaria longe, comece por lá
    local bind = GetBindLocation and GetBindLocation()
    if bind and not self.hearthDone then
        local atBind = {}
        for _, s in ipairs(route) do if s.m and mapName(s.m) == bind then table.insert(atBind, s) end end
        local first = route[1]
        local far = first and (first.cont ~= pc or (first.yards and first.yards > YARD_HEARTH))
        local zoneNow = pmap and mapName(pmap)
        if #atBind >= 2 and far and zoneNow ~= bind then
            local b = atBind[1]
            for _, s in ipairs(items) do s.newCont = nil; s.yards = nil end
            route = order(items, b.cont, b.wx, b.wy)
            table.insert(route, 1, { t = "H", d = bind, flags = {}, turnin = true,
                note = string.format(T("%d entregas na sua casa (%s)", "%d turn-ins at your home (%s)"), #atBind, bind) })
        end
    end

    -- textos da rota
    for i, s in ipairs(route) do
        s.index = 10000 + i
        if s.t == "T" then
            local parts = {}
            if s.m then table.insert(parts, "|cff80c0ff" .. mapName(s.m) .. "|r") else table.insert(parts, "|cffff6060" .. T("local desconhecido", "unknown location") .. "|r") end
            if s.yards and s.yards > 5 then table.insert(parts, string.format(T("~%.0f m da anterior", "~%.0f m from the previous one"), s.yards * 0.9144)) end
            if s.newCont then table.insert(parts, "|cffffd040" .. T("outro continente: zepelim/navio", "other continent: zeppelin/boat") .. "|r") end
            if s.items then table.insert(parts, "|cff40ff40" .. T("libera itens da bolsa", "frees bag items") .. "|r") end
            s.note = table.concat(parts, "  ·  ")
        end
    end
    return route
end

function TI:Toggle(on)
    if on == nil then on = not RX.db.turninMode end
    RX.db.turninMode = on and true or false
    if on then RX.db.nearbyMode = false end
    if on then
        self.hearthDone = nil
        local n = self:Count()
        RX:Print(string.format(T("Modo Entregas: %d quests prontas. Rota montada do mais perto ao mais longe.", "Turn-in mode: %d quests ready. Route built from nearest to farthest."), n))
    else
        RX:Print(T("Voltando ao guia.", "Back to the guide."))
    end
    if RX.Arrow then RX.Arrow:ClearManual() end
    RX:Update(true)
end
