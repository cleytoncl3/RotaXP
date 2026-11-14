-- Rotas pelas estradas. O jogo não entrega o mapa de estradas para addons, então o RouteXP APRENDE por onde você
-- corre (a pé ou montado, fora de combate, sem voar/taxi): grava uma malha de pontos por continente e, quando
-- desenha a rota, faz o caminho mais curto POR ESSA MALHA em vez de uma linha reta por cima das montanhas.
-- Onde ainda não há trilha conhecida, a linha continua reta (e aparece mais fraca, só indicando a direção).
-- Quanto mais gente passa por um trecho, mais ele é preferido (estrada de verdade x atalho de uma vez só).
local _, RX = ...
local TL = { adj = {}, cache = {}, last = nil }
RX.Trails = TL
local T = RX.T

local CELL = 10            -- jardas: tamanho da célula da malha
local MAXN = 40000         -- máximo de pontos por continente
local MIN_SPEED = 6.5      -- jardas/s: só grava quando está correndo/montado (viagem), não mexendo no combate
local MAX_SPEED = 30
local MAX_EXP = 4000       -- limite de nós expandidos por busca
local ENTER_R = 140        -- jardas: até onde procura a trilha mais próxima da origem/destino
local DETOUR = 4           -- o caminho pela malha pode ser no máximo 4x a distância direta (+150)

local function key(ix, iy) return (ix + 4000) * 10000 + (iy + 4000) end
local function cellOf(w) return math.floor(w / CELL) end

local function store()
    if not RX.db then return nil end
    RX.db.trails = RX.db.trails or {}
    return RX.db.trails
end

local function tr(cont, create)
    local s = store()
    if not s then return nil end
    local t = s[cont]
    if not t and create then t = { n = {}, e = {}, cnt = 0 }; s[cont] = t end
    return t
end

-- vizinhança em memória (não salva): adj[cont][k1][k2] = vezes
local function graph(cont)
    local g = TL.adj[cont]
    if g then return g end
    g = {}
    local t = tr(cont)
    if t then
        for a, row in pairs(t.e) do
            for b, c in pairs(row) do
                g[a] = g[a] or {}; g[b] = g[b] or {}
                g[a][b] = c; g[b][a] = c
            end
        end
    end
    TL.adj[cont] = g
    return g
end

local function addEdge(cont, a, b)
    if a == b then return end
    local t = tr(cont, true)
    local lo, hi = a < b and a or b, a < b and b or a
    t.e[lo] = t.e[lo] or {}
    local c = (t.e[lo][hi] or 0) + 1
    t.e[lo][hi] = c
    local g = graph(cont)
    g[a] = g[a] or {}; g[b] = g[b] or {}
    g[a][b] = c; g[b][a] = c
end

-- grava um ponto da sua caminhada
function TL:Record(cont, wx, wy)
    local t = tr(cont, true)
    local ix, iy = cellOf(wx), cellOf(wy)
    local k = key(ix, iy)
    local n = t.n[k]
    if n then
        -- média móvel da posição dentro da célula (suaviza o zigue-zague)
        local c = n[3]
        n[1] = math.floor(((n[1] * c + wx) / (c + 1)) * 10) / 10
        n[2] = math.floor(((n[2] * c + wy) / (c + 1)) * 10) / 10
        if c < 50 then n[3] = c + 1 end
    else
        if t.cnt >= MAXN then return nil end
        t.n[k] = { math.floor(wx * 10) / 10, math.floor(wy * 10) / 10, 1 }
        t.cnt = t.cnt + 1
    end
    return k
end

function TL:Sample()
    if RX.db and RX.db.learnTrails == false then return end
    if UnitOnTaxi and UnitOnTaxi("player") then self.last = nil return end
    if (IsFlying and IsFlying()) or (IsSwimming and IsSwimming()) then self.last = nil return end
    if (UnitAffectingCombat and UnitAffectingCombat("player")) or (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then self.last = nil return end
    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
    if type(speed) ~= "number" or speed < MIN_SPEED or speed > MAX_SPEED then self.last = nil return end
    local me = RX.Travel and RX.Travel:PlayerPos()
    if not me then self.last = nil return end
    local l = self.last
    if l and l.cont == me.cont then
        local d = math.sqrt((me.wx - l.wx) ^ 2 + (me.wy - l.wy) ^ 2)
        if d < CELL * 0.8 then return end            -- ainda não andou o bastante
        if d > 80 then l = nil end                    -- teleporte/portal: não liga com o ponto anterior
    else
        l = nil
    end
    local k = self:Record(me.cont, me.wx, me.wy)
    if k and l and l.key and l.key ~= k then addEdge(me.cont, l.key, k) end
    self.last = { cont = me.cont, wx = me.wx, wy = me.wy, key = k }
end

-- nó da malha mais perto de (wx,wy), até ENTER_R jardas
local function nearest(cont, wx, wy)
    local t = tr(cont)
    if not t or t.cnt == 0 then return nil end
    local g = graph(cont)
    local ix, iy = cellOf(wx), cellOf(wy)
    local r = math.ceil(ENTER_R / CELL)
    local best, bd
    for dx = -r, r do
        for dy = -r, r do
            local k = key(ix + dx, iy + dy)
            local n = t.n[k]
            if n and g[k] then
                local d = (n[1] - wx) ^ 2 + (n[2] - wy) ^ 2
                if not bd or d < bd then best, bd = k, d end
            end
        end
    end
    if best and math.sqrt(bd) <= ENTER_R then return best, math.sqrt(bd) end
    return nil
end

-- tira pontos que quase não mudam a linha (Ramer-Douglas-Peucker), para o desenho ficar leve
local function simplify(list, tol)
    local n = #list
    if n <= 2 then return list end
    local keep = { [1] = true, [n] = true }
    local function seg(i, j)
        local ax, ay, bx, by = list[i].wx, list[i].wy, list[j].wx, list[j].wy
        local dx, dy = bx - ax, by - ay
        local len2 = dx * dx + dy * dy
        local bestD, bestK = 0, nil
        for k = i + 1, j - 1 do
            local px, py = list[k].wx - ax, list[k].wy - ay
            local d
            if len2 == 0 then d = math.sqrt(px * px + py * py)
            else
                local t = math.max(0, math.min(1, (px * dx + py * dy) / len2))
                d = math.sqrt((px - t * dx) ^ 2 + (py - t * dy) ^ 2)
            end
            if d > bestD then bestD, bestK = d, k end
        end
        if bestK and bestD > tol then keep[bestK] = true; seg(i, bestK); seg(bestK, j) end
    end
    seg(1, n)
    local out = {}
    for i = 1, n do if keep[i] then out[#out + 1] = list[i] end end
    return out
end

-- caminho mais curto pela malha; devolve lista de pontos { cont, wx, wy, road = true }
function TL:Path(cont, ax, ay, bx, by)
    local t = tr(cont)
    if not t or t.cnt < 2 then return nil end
    local ck = string.format("%d:%d:%d:%d:%d", cont, math.floor(ax / 25), math.floor(ay / 25), math.floor(bx / 10), math.floor(by / 10))
    local now = GetTime and GetTime() or 0
    local c = self.cache[ck]
    if c and now - c.t < 3 then return c.path end

    local s, sd = nearest(cont, ax, ay)
    local e, ed = nearest(cont, bx, by)
    local res
    if s and e then
        local g = graph(cont)
        local nodes = t.n
        local function pos(k) local n = nodes[k]; return n[1], n[2] end
        local ex, ey = pos(e)
        local open, gs, came, closed = { s }, { [s] = 0 }, {}, {}
        local expanded = 0
        local function h(k) local x, y = pos(k); return math.sqrt((x - ex) ^ 2 + (y - ey) ^ 2) end
        local fs = { [s] = h(s) }
        local found
        while #open > 0 and expanded < MAX_EXP do
            local bi, bf = 1, fs[open[1]]
            for i = 2, #open do local f = fs[open[i]]; if f < bf then bi, bf = i, f end end
            local cur = table.remove(open, bi)
            if cur == e then found = true break end
            if not closed[cur] then
                closed[cur] = true
                expanded = expanded + 1
                local cx, cy = pos(cur)
                for nb, cnt in pairs(g[cur] or {}) do
                    if not closed[nb] and nodes[nb] then
                        local nx, ny = pos(nb)
                        local len = math.sqrt((nx - cx) ^ 2 + (ny - cy) ^ 2)
                        local cost = len * (1 + 2 / cnt)          -- trecho muito andado custa menos
                        local ng = gs[cur] + cost
                        if not gs[nb] or ng < gs[nb] then
                            gs[nb] = ng; came[nb] = cur; fs[nb] = ng + h(nb)
                            open[#open + 1] = nb
                        end
                    end
                end
            end
        end
        if found then
            local list, k = {}, e
            while k do
                local x, y = pos(k)
                table.insert(list, 1, { cont = cont, wx = x, wy = y, road = true })
                k = came[k]
            end
            -- tamanho real pela malha x distância direta (descarta trilhas que não têm nada a ver)
            local plen = (sd or 0) + (ed or 0)
            for i = 2, #list do plen = plen + math.sqrt((list[i].wx - list[i - 1].wx) ^ 2 + (list[i].wy - list[i - 1].wy) ^ 2) end
            local direct = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
            if plen <= direct * DETOUR + 150 then res = simplify(list, 9) end
        end
    end
    self.cache[ck] = { t = now, path = res }
    return res
end

-- troca cada trecho reto (a pé) da rota pelo caminho pelas estradas aprendidas
function TL:Refine(pts)
    if not pts or #pts < 2 or (RX.db and RX.db.useTrails == false) then return pts end
    local out = {}
    for i = 1, #pts do
        local p = pts[i]
        out[#out + 1] = p
        local q = pts[i + 1]
        if q and not p.noRoad and p.cont == q.cont then
            local path = self:Path(p.cont, p.wx, p.wy, q.wx, q.wy)
            if path then for _, n in ipairs(path) do out[#out + 1] = n end end
        end
    end
    return out
end

function TL:Stats()
    local s, total = store(), 0
    local lines = {}
    for cont, t in pairs(s or {}) do
        local edges = 0
        for _, row in pairs(t.e) do for _ in pairs(row) do edges = edges + 1 end end
        lines[#lines + 1] = string.format("  %s %s: %d %s, %d %s", T("Continente", "Continent"), tostring(cont), t.cnt, T("pontos", "points"), edges, T("trechos", "segments"))
        total = total + t.cnt
    end
    return total, lines
end

function TL:Clear()
    local s = store()
    if s then wipe(s) end
    wipe(self.adj); wipe(self.cache); self.last = nil
end

local f = CreateFrame("Frame")
local acc = 0
f:SetScript("OnUpdate", function(_, e)
    acc = acc + e
    if acc < 0.5 then return end
    acc = 0
    pcall(TL.Sample, TL)
end)
