-- Otimizador de rota: reordena os próximos passos do guia pelo caminho mais curto a partir de onde você está,
-- e puxa para agora as quests do guia que estão no MESMO lugar (pegar/entregar tudo de uma vez na cidade/base).
local _, RX = ...
local OP = {}
RX.Optimize = OP

local NEAR = 140       -- jardas: considerado "o mesmo lugar" (mesma base/cidade)
local WINDOW = 10      -- quantos passos à frente o otimizador pode reorganizar
local MAX_EXTRA = 15   -- quantos passos de mais adiante podem ser puxados por estarem no mesmo lugar
local KEEP = 60        -- histerese: mantém o 1º passo se a troca ganha menos que isso (evita a lista "pular")
local RANK = { A = 1, C = 2, T = 3 }
local READY_NEAR = 250 -- jardas: entrega pronta a esta distância sobe para o topo
local WORK_NEAR = 450  -- jardas: objetivo de quest do log a esta distância vem antes de entregar longe

local function wpos(s)
    if s._wx == nil and s.m and s.x then
        local c, x, y = RX.Travel.world(s.m, s.x, s.y)
        s._cont, s._wx, s._wy = c or false, x, y
    end
    if s._cont then return s._cont, s._wx, s._wy end
    return nil
end

local function dist(s, c, x, y)
    local sc, sx, sy = wpos(s)
    if not sc then return 1e8 end          -- sem coordenada: depois dos que têm
    if sc ~= c then return 1e9 end          -- outro continente: por último
    return math.sqrt((sx - x) ^ 2 + (sy - y) ^ 2)
end

local function canPull(s, pool)
    local Q = RX.Q
    if s.t == "A" then return true end
    if Q:InLog(s.q) then
        if s.t == "T" then return Q:IsReady(s.q) end
        return true
    end
    for _, p in ipairs(pool) do if p.q == s.q and p.t == "A" then return true end end
    return false
end

function OP:Order(list)
    if #list < 2 then return list end
    local me = RX.Travel and RX.Travel:PlayerPos()
    if not me then return list end

    -- notas no topo (antes do 1º passo de quest) ficam onde estão
    local head, i = {}, 1
    while i <= #list and not list[i].q do table.insert(head, list[i]); i = i + 1 end
    -- janela: passos de quest seguidos; uma nota/nível/pedra no meio do guia é uma "barreira"
    local window = {}
    while i <= #list and #window < WINDOW and list[i].q do table.insert(window, list[i]); i = i + 1 end
    if #window == 0 then return list end
    local rest = {}
    for j = i, #list do table.insert(rest, list[j]) end

    -- pontos de referência: você + os passos da janela
    local anchors = { { me.cont, me.wx, me.wy } }
    for _, s in ipairs(window) do
        local c, x, y = wpos(s)
        if c then table.insert(anchors, { c, x, y }) end
    end
    -- puxa de mais adiante o que está no mesmo lugar
    local pool, pulled = {}, {}
    for _, s in ipairs(window) do table.insert(pool, s) end
    local extra = 0
    for _, s in ipairs(rest) do
        if extra >= MAX_EXTRA then break end
        if s.q and RANK[s.t] and wpos(s) then
            local near = false
            for _, a in ipairs(anchors) do if dist(s, a[1], a[2], a[3]) <= NEAR then near = true break end end
            if near and canPull(s, pool) then
                table.insert(pool, s); pulled[s] = true; extra = extra + 1
            end
        end
    end

    -- vizinho mais próximo, respeitando Aceitar -> Fazer -> Entregar de cada quest
    local ordered, left = {}, {}
    for idx, s in ipairs(pool) do left[idx] = s end
    local cc, cx, cy = me.cont, me.wx, me.wy
    while #left > 0 do
        local bestI, bestD
        for idx, s in ipairs(left) do
            local ok = true
            for _, o in ipairs(left) do
                if o ~= s and o.q == s.q and (RANK[o.t] or 9) < (RANK[s.t] or 9) then ok = false break end
            end
            if ok then
                local d = dist(s, cc, cx, cy)
                if not bestD or d < bestD - 0.5 then bestI, bestD = idx, d end
            end
        end
        bestI = bestI or 1
        local s = table.remove(left, bestI)
        table.insert(ordered, s)
        local c, x, y = wpos(s)
        if c then cc, cx, cy = c, x, y end
    end

    -- histerese: não troca o primeiro passo por uma diferença pequena de distância
    if self.lastFirst and ordered[1] ~= self.lastFirst then
        for idx, s in ipairs(ordered) do
            if s == self.lastFirst then
                local dNew = dist(ordered[1], me.cont, me.wx, me.wy)
                local dOld = dist(s, me.cont, me.wx, me.wy)
                local okDeps = true
                for k = 1, idx - 1 do if ordered[k].q == s.q and (RANK[ordered[k].t] or 9) < (RANK[s.t] or 9) then okDeps = false end end
                if okDeps and dOld - dNew < KEEP then table.remove(ordered, idx); table.insert(ordered, 1, s) end
                break
            end
        end
    end
    self.lastFirst = ordered[1]

    local out = {}
    for _, s in ipairs(head) do table.insert(out, s) end
    for _, s in ipairs(ordered) do table.insert(out, s) end
    for _, s in ipairs(rest) do if not pulled[s] then table.insert(out, s) end end

    -- 1) entregas PRONTAS perto de você (dá para entregar aqui) e 2) objetivos de quests do seu log que estão
    -- perto (matar/coletar aqui do lado) vêm antes de qualquer coisa longe: termina o que está ao seu redor antes de
    -- voltar para a cidade entregar. Cada grupo da mais perto para a mais longe.
    local Q = RX.Q
    local near, work, others = {}, {}, {}
    for _, s in ipairs(out) do
        local inLog = s.q and Q:InLog(s.q)
        if s.t == "T" and inLog and Q:IsReady(s.q) and dist(s, me.cont, me.wx, me.wy) <= READY_NEAR then
            s._rd = dist(s, me.cont, me.wx, me.wy); near[#near + 1] = s
        elseif s.t == "C" and inLog and not Q:IsReady(s.q) and dist(s, me.cont, me.wx, me.wy) <= WORK_NEAR then
            s._rd = dist(s, me.cont, me.wx, me.wy); work[#work + 1] = s
        else
            others[#others + 1] = s
        end
    end
    if #near == 0 and #work == 0 then return out end
    table.sort(near, function(x, y) return x._rd < y._rd end)
    table.sort(work, function(x, y) return x._rd < y._rd end)
    local res = {}
    for _, s in ipairs(near) do res[#res + 1] = s end
    for _, s in ipairs(work) do res[#res + 1] = s end
    for _, s in ipairs(others) do res[#res + 1] = s end
    self.lastFirst = res[1]
    return res
end
