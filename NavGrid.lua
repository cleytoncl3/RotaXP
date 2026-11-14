-- Rota pelo terreno de verdade. Data/NavGrid_*.lua traz, para cada pedaço de 16 jardas de Kalimdor e dos
-- Reinos do Leste (gerado do terreno do WoW: Forever), por onde dá para andar (sem penhasco ou montanha íngreme),
-- onde há estrada e onde a água é funda. A linha da rota faz o caminho mais curto por essa malha: contorna
-- montanhas e penhascos e prefere as estradas. O cálculo roda aos poucos (alguns quadros), sem travar o jogo.
local _, RX = ...
local NG = { tiles = {}, cache = {}, jobs = {}, nCache = 0 }
RX.Nav = NG

local TILE = 1600 / 3
local CELL = TILE / 32
local ORIG = 32 * TILE
local floor, sqrt, abs, min = math.floor, math.sqrt, math.abs, math.min

local COST_ROAD, COST_LAND, COST_WATER = 0.5, 1, 5
local HWEIGHT = 0.75          -- heurística (um pouco gulosa: acha rápido, quase sempre o melhor caminho)
local BUDGET = 2500           -- células por quadro
local MAX_EXP = 70000         -- desiste (linha reta) depois disso
local MAX_DIST = 4500         -- jardas: trechos maiores ficam retos
local SNAP = 40               -- jardas: você ainda está "em cima" do caminho calculado
local RESTART = 70            -- jardas: saiu tanto do caminho que recalcula

local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&'()*+,-"
local VAL = {}
for i = 1, #ALPHA do VAL[ALPHA:byte(i)] = i - 1 end

local function has(v, b) return floor(v / b) % 2 == 1 end

function NG:Has(cont) return RX.NavData and RX.NavData[cont] ~= nil end

local function decode(s)
    local t, n, i, len = {}, 0, 1, #s
    while i <= len do
        local v = VAL[s:byte(i)] or 0
        i = i + 1
        local j = i
        while j <= len do
            local b = s:byte(j)
            if b < 48 or b > 57 then break end
            j = j + 1
        end
        local run = 1
        if j > i then run = tonumber(s:sub(i, j - 1)) end
        i = j
        for _ = 1, run do n = n + 1; t[n] = v end
    end
    return t
end

-- valor da célula (nil = fora do mapa)
local function cellVal(cont, gx, gy)
    if gx < 0 or gy < 0 or gx >= 2048 or gy >= 2048 then return nil end
    local tk = floor(gy / 32) * 64 + floor(gx / 32)
    local ct = NG.tiles[cont]
    if not ct then ct = {}; NG.tiles[cont] = ct end
    local t = ct[tk]
    if t == nil then
        local src = RX.NavData and RX.NavData[cont] and RX.NavData[cont][tk]
        t = src and decode(src) or false
        ct[tk] = t
    end
    if not t then return nil end
    return t[(gy % 32) * 32 + (gx % 32) + 1]
end
NG.cellVal = cellVal

local function toCell(wx, wy) return floor((ORIG - wy) / CELL), floor((ORIG - wx) / CELL) end
local function toWorld(gx, gy) return ORIG - (gy + 0.5) * CELL, ORIG - (gx + 0.5) * CELL end
NG.toCell, NG.toWorld = toCell, toWorld

-- dá para ir da célula (gx,gy) para a vizinha (gx+dx, gy+dy)?
local function canMove(cont, gx, gy, dx, dy)
    if dy == 0 then
        if dx == 1 then local v = cellVal(cont, gx, gy); return v and has(v, 1) end
        local v = cellVal(cont, gx - 1, gy); return v and has(v, 1)
    elseif dx == 0 then
        if dy == 1 then local v = cellVal(cont, gx, gy); return v and has(v, 2) end
        local v = cellVal(cont, gx, gy - 1); return v and has(v, 2)
    elseif dx == dy then
        if dx == 1 then local v = cellVal(cont, gx, gy); return v and has(v, 4) end
        local v = cellVal(cont, gx - 1, gy - 1); return v and has(v, 4)
    else
        if dx == -1 then local v = cellVal(cont, gx, gy); return v and has(v, 8) end
        local v = cellVal(cont, gx + 1, gy - 1); return v and has(v, 8)
    end
end
NG.canMove = canMove

local function cost(v)
    if not v then return COST_LAND end
    if has(v, 32) then return COST_WATER end
    if has(v, 16) then return COST_ROAD end
    return COST_LAND
end

local DIRS = { { 1, 0, 1 }, { -1, 0, 1 }, { 0, 1, 1 }, { 0, -1, 1 }, { 1, 1, 1.4142 }, { -1, -1, 1.4142 }, { -1, 1, 1.4142 }, { 1, -1, 1.4142 } }

local function key(gx, gy) return gy * 4096 + gx end
local function unkey(k) return k % 4096, floor(k / 4096) end

-- fila de prioridade (heap binário)
local function hpush(h, k, f)
    local n = h.n + 1
    h.n = n
    local ks, fs = h.k, h.f
    while n > 1 do
        local p = floor(n / 2)
        if fs[p] <= f then break end
        ks[n], fs[n] = ks[p], fs[p]
        n = p
    end
    ks[n], fs[n] = k, f
end
local function hpop(h)
    local n = h.n
    if n == 0 then return nil end
    local ks, fs = h.k, h.f
    local top = ks[1]
    local lk, lf = ks[n], fs[n]
    ks[n], fs[n] = nil, nil
    n = n - 1
    h.n = n
    if n > 0 then
        local i = 1
        while true do
            local c = i * 2
            if c > n then break end
            if c < n and fs[c + 1] < fs[c] then c = c + 1 end
            if fs[c] >= lf then break end
            ks[i], fs[i] = ks[c], fs[c]
            i = c
        end
        ks[i], fs[i] = lk, lf
    end
    return top
end

local function octile(ax, ay, bx, by)
    local dx, dy = abs(ax - bx), abs(ay - by)
    if dx > dy then return dx + 0.4142 * dy end
    return dy + 0.4142 * dx
end

local function newJob(cont, sx, sy, ex, ey)
    local j = { cont = cont, sx = sx, sy = sy, ex = ex, ey = ey, g = {}, came = {}, closed = {}, h = { n = 0, k = {}, f = {} }, exp = 0 }
    local s = key(sx, sy)
    j.g[s] = 0
    hpush(j.h, s, octile(sx, sy, ex, ey) * COST_ROAD * HWEIGHT * 2)
    j.goal = key(ex, ey)
    return j
end

-- anda a busca até 'budget' células; devolve "done", "fail" ou nil (continua depois)
local function stepJob(j, budget)
    local cont, g, came, closed, h = j.cont, j.g, j.came, j.closed, j.h
    local ex, ey, goal = j.ex, j.ey, j.goal
    local hw = COST_ROAD * HWEIGHT * 2
    while budget > 0 do
        local cur = hpop(h)
        if not cur then return "fail" end
        if cur == goal then return "done" end
        if not closed[cur] then
            closed[cur] = true
            budget = budget - 1
            j.exp = j.exp + 1
            if j.exp > MAX_EXP then return "fail" end
            local cx, cy = unkey(cur)
            -- o ponto alcançável mais perto do destino (ex.: o pé de uma mesa com elevador)
            local hd = octile(cx, cy, ex, ey)
            if not j.bestH or hd < j.bestH then j.bestH, j.best = hd, cur end
            local gc = g[cur]
            local cc = cost(cellVal(cont, cx, cy))
            for i = 1, 8 do
                local d = DIRS[i]
                local nx, ny = cx + d[1], cy + d[2]
                local nk = key(nx, ny)
                if not closed[nk] and canMove(cont, cx, cy, d[1], d[2]) then
                    local ng = gc + d[3] * (cc + cost(cellVal(cont, nx, ny))) * 0.5
                    local og = g[nk]
                    if not og or ng < og then
                        g[nk] = ng
                        came[nk] = cur
                        hpush(h, nk, ng + octile(nx, ny, ex, ey) * hw)
                    end
                end
            end
        end
    end
    return nil
end

-- custo de ir em linha reta de a até b pelas células (nil se tem penhasco no meio)
local function lineCost(cont, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local n = math.max(abs(dx), abs(dy)) * 2
    if n == 0 then return 0 end
    local px, py = ax, ay
    local total = 0
    local pc = cost(cellVal(cont, ax, ay))
    for k = 1, n do
        local fx, fy = ax + dx * k / n, ay + dy * k / n
        local cx, cy = floor(fx + 0.5), floor(fy + 0.5)
        if cx ~= px or cy ~= py then
            local sx, sy = cx - px, cy - py
            if abs(sx) > 1 or abs(sy) > 1 then return nil end
            if not canMove(cont, px, py, sx, sy) then return nil end
            if sx ~= 0 and sy ~= 0 then
                -- diagonal: também não pode raspar num canto bloqueado
                if not (canMove(cont, px, py, sx, 0) or canMove(cont, px, py, 0, sy)) then return nil end
            end
            local nc = cost(cellVal(cont, cx, cy))
            total = total + ((sx ~= 0 and sy ~= 0) and 1.4142 or 1) * (pc + nc) * 0.5
            pc = nc
            px, py = cx, cy
        end
    end
    return total
end
NG.lineCost = lineCost

-- caminho de células -> pontos do mundo, tirando os degraus (só corta caminho onde não fica mais caro nem passa em penhasco)
local function finish(j, last)
    local cells = {}
    local k = last or j.goal
    while k do
        local x, y = unkey(k)
        table.insert(cells, 1, { x, y, j.g[k] or 0 })
        k = j.came[k]
    end
    local out = {}
    local i, n = 1, #cells
    while i <= n do
        local c = cells[i]
        local wx, wy = toWorld(c[1], c[2])
        out[#out + 1] = { cont = j.cont, wx = wx, wy = wy, road = true }
        if i == n then break end
        local best = i + 1
        local miss = 0
        for t = i + 2, min(n, i + 60) do
            local lc = lineCost(j.cont, c[1], c[2], cells[t][1], cells[t][2])
            if lc and lc <= (cells[t][3] - c[3]) * 1.04 + 0.01 then best = t; miss = 0
            else miss = miss + 1; if miss > 4 then break end end
        end
        i = best
    end
    return out
end

local function trimFrom(path, ax, ay)
    local bi, bd
    for i = 1, #path do
        local p = path[i]
        local d = (p.wx - ax) ^ 2 + (p.wy - ay) ^ 2
        if not bd or d < bd then bi, bd = i, d end
    end
    if not bi or sqrt(bd) > SNAP then return nil end
    -- o ponto mais perto pode ficar atrás de você: começa no seguinte se estiver mais adiante
    local out = {}
    local start = bi
    if bi < #path then
        local p, q = path[bi], path[bi + 1]
        local vx, vy = q.wx - p.wx, q.wy - p.wy
        if (ax - p.wx) * vx + (ay - p.wy) * vy > 0 then start = bi + 1 end
    end
    for i = start, #path do out[#out + 1] = path[i] end
    return out
end

local function purge()
    if NG.nCache < 24 then return end
    local oldK, oldT
    for k, e in pairs(NG.cache) do if not oldT or e.t < oldT then oldK, oldT = k, e.t end end
    if oldK then NG.cache[oldK] = nil; NG.nCache = NG.nCache - 1 end
end

-- caminho de (ax,ay) até (bx,by) pelo terreno. Devolve a lista de pontos do meio do caminho,
-- ou nil (sem dados, longe demais, ainda calculando ou sem caminho: a linha fica reta)
function NG:Path(cont, ax, ay, bx, by)
    if not self:Has(cont) then return nil end
    local dist = sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    if dist < CELL * 2 or dist > MAX_DIST then return nil end
    local sx, sy = toCell(ax, ay)
    local ex, ey = toCell(bx, by)
    if not cellVal(cont, sx, sy) or not cellVal(cont, ex, ey) then return nil end
    local ck = cont .. ":" .. key(ex, ey)
    local now = GetTime and GetTime() or 0
    local e = self.cache[ck]
    if e then
        e.t = now
        if e.path then
            local tp = trimFrom(e.path, ax, ay)
            if tp then return tp end
        elseif e.fail then
            -- sem caminho daqui: só tenta de novo se você andou bastante
            if sqrt((ax - e.ax) ^ 2 + (ay - e.ay) ^ 2) < RESTART then return nil end
        end
    end
    local j = self.jobs[ck]
    if j then
        local jx, jy = toWorld(j.sx, j.sy)
        if sqrt((ax - jx) ^ 2 + (ay - jy) ^ 2) < RESTART then return nil end   -- já está calculando
    end
    self.jobs[ck] = newJob(cont, sx, sy, ex, ey)
    self.jobs[ck].ax, self.jobs[ck].ay = ax, ay
    self:Kick()
    return nil
end

function NG:Pending() return next(self.jobs) ~= nil end

-- processa as buscas pendentes (chamado a cada quadro); 'budget' opcional (testes)
function NG:Run(budget)
    for ck, j in pairs(self.jobs) do
        local r
        if budget then
            r = stepJob(j, budget)
        else
            -- no jogo: até ~4 ms por quadro, para não engasgar
            local clock = debugprofilestop
            local t0 = clock and clock()
            local n = 0
            repeat
                r = stepJob(j, 150)
                n = n + 150
            until r or n >= BUDGET or (t0 and clock() - t0 > 4)
        end
        if r then
            self.jobs[ck] = nil
            local e = self.cache[ck]
            if not e then self.nCache = self.nCache + 1; purge() end
            e = { t = GetTime and GetTime() or 0, ax = j.ax, ay = j.ay }
            if r == "done" then
                e.path = finish(j)
            elseif j.best and j.bestH and j.bestH < octile(j.sx, j.sy, j.ex, j.ey) * 0.5 then
                -- não dá para chegar andando (elevador, caverna, prédio): vai até o ponto mais perto; o resto fica reto
                e.path = finish(j, j.best)
                if #e.path > 0 then e.path[#e.path].road = false end
            else
                e.fail = true
            end
            self.cache[ck] = e
            self.changed = true
        end
        return
    end
end

function NG:Clear() wipe(self.cache); wipe(self.jobs); self.nCache = 0 end

local driver = CreateFrame("Frame")
driver:Hide()
driver:SetScript("OnUpdate", function(f)
    pcall(NG.Run, NG)
    if not next(NG.jobs) then f:Hide() end   -- as linhas se redesenham sozinhas e já pegam o caminho novo
end)
function NG:Kick() driver:Show() end
