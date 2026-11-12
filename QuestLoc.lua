-- Onde fazer uma quest AGORA: lê a própria quest no jogo e aponta para o objetivo que ainda falta.
-- Ordem: 1) marcação da quest no mapa do jogo (POI) na sua zona; 2) waypoint do jogo (outra zona);
--        3) local do mob/item/objeto do objetivo que falta (banco do Questie); 4) local fixo do guia.
local _, RX = ...
local QL = {}
RX.QuestLoc = QL

local function lower(s) return s and s:lower() or nil end

local function remainingObjective(s)
    if not s.objs then return nil end
    local objs = RX.Q:Objectives(s.q)
    if not objs then return nil end
    for _, o in ipairs(objs) do
        if not o.finished then
            local txt = lower(o.text or "")
            for _, p in ipairs(s.objs) do
                if (p.p and txt:find(lower(p.p), 1, true)) or (p.n and txt:find(lower(p.n), 1, true)) then return p end
            end
        end
    end
    return nil
end

local function gamePOI(q)
    if not (C_QuestLog and C_QuestLog.GetQuestsOnMap) then return nil end
    local pm = C_Map.GetBestMapForUnit("player")
    if not pm then return nil end
    local ok, list = pcall(C_QuestLog.GetQuestsOnMap, pm)
    if ok and type(list) == "table" then
        for _, e in ipairs(list) do
            if e.questID == q and e.x and e.y and (e.x > 0 or e.y > 0) then return pm, e.x * 100, e.y * 100 end
        end
    end
    return nil
end

local function gameWaypoint(q)
    if not (C_QuestLog and C_QuestLog.GetNextWaypoint) then return nil end
    local ok, m, x, y = pcall(C_QuestLog.GetNextWaypoint, q)
    if ok and type(m) == "number" and type(x) == "number" and type(y) == "number" and (x > 0 or y > 0) then
        return m, x * 100, y * 100
    end
    return nil
end

-- Atualiza s.m / s.x / s.y de um passo "Fazer" conforme o progresso real da quest
function QL:Resolve(s)
    if s.t ~= "C" or not s.q then return end
    if s.om == nil then s.om, s.ox, s.oy = s.m or false, s.x, s.y end
    local m, x, y, src
    if RX.Q:InLog(s.q) and not RX.Q:IsReady(s.q) then
        local p = remainingObjective(s)
        local pm, px, py = gamePOI(s.q)
        if pm then
            m, x, y, src = pm, px, py, "poi"
            -- se o objetivo que falta é em outro lugar desta mesma zona, o banco é mais preciso que o centro do POI
            if p and p.m == pm then m, x, y, src = p.m, p.x, p.y, "obj" end
            s.locName = p and ((RX:IsPT() and p.p) or p.n) or nil
        elseif p then
            m, x, y, src = p.m, p.x, p.y, "obj"
            s.locName = (RX:IsPT() and p.p) or p.n
        else
            local wm, wx, wy = gameWaypoint(s.q)
            if wm then m, x, y, src = wm, wx, wy, "poi" end
        end
    end
    if not m then
        if s.om then m, x, y = s.om, s.ox, s.oy else m = nil end
    end
    if m ~= s.m or x ~= s.x or y ~= s.y then
        s.m, s.x, s.y = m, x, y
        s._wx, s._cont, s._wy = nil, nil, nil
    end
    s.locSrc = src
end

function QL:ResolveList(list, max)
    for i = 1, math.min(max or 25, #list) do
        local s = list[i]
        if s.t == "C" then self:Resolve(s) end
    end
end

-- Quem dá uma quest (primeiro passo "Aceitar" encontrado em qualquer guia)
function QL:Giver(q)
    if not self.giverIdx then
        self.giverIdx = {}
        for _, g in pairs(RX.guides) do
            for _, s in ipairs(g.steps) do
                if s.t == "A" and s.q and not self.giverIdx[s.q] then self.giverIdx[s.q] = s end
            end
        end
    end
    return self.giverIdx[q]
end
