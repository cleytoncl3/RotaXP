-- Planejador de viagem: a pé, voo, zepelim/barco até o próximo objetivo
local _, RX = ...
local TR = {}
RX.Travel = TR
local T = RX.T

local WALK_MAX = 900      -- até isso (jardas) vale ir a pé/montado direto
local FLY_GAIN = 0.6      -- só voa se andar até o voo + do voo ao destino for < 60% da distância direta
local ARRIVE = 35         -- jardas: chegou num ponto de voo/porto

local function world(m, x, y)
    if not (m and C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(x / 100, y / 100))
    if ok and pos then return cont, pos.x, pos.y end
    return nil
end
TR.world = world

local function zoneName(m)
    local info = m and C_Map.GetMapInfo(m)
    return info and info.name or "?"
end

function TR:PlayerPos()
    local pm = C_Map.GetBestMapForUnit("player")
    local p = pm and C_Map.GetPlayerMapPosition(pm, "player")
    if not p then return nil end
    local x, y = p:GetXY()
    if not x or (x == 0 and y == 0) then return nil end
    local c, wx, wy = world(pm, x * 100, y * 100)
    if not c then return nil end
    return { cont = c, wx = wx, wy = wy, m = pm, x = x * 100, y = y * 100 }
end

-- pontos com posição no mundo (cache)
local function point(m, x, y, name, pname, kind)
    local c, wx, wy = world(m, x, y)
    if not c then return nil end
    return { m = m, x = x, y = y, cont = c, wx = wx, wy = wy, name = name, pname = pname, kind = kind }
end

function TR:Points()
    if self.fps then return self.fps, self.trans end
    self.fps, self.trans = {}, {}
    for _, f in ipairs(RX.FlightMasters or {}) do
        local p = point(f[1], f[2], f[3], f[4], f[5], "fp")
        if p then table.insert(self.fps, p) end
    end
    for _, t in ipairs(RX.Transports or {}) do
        local a = point(t[3], t[4], t[5], nil, nil, "dock")
        local b = point(t[6], t[7], t[8], nil, nil, "dock")
        if a and b then table.insert(self.trans, { pt = t[1], en = t[2], a = a, b = b, approx = t[9] }) end
    end
    return self.fps, self.trans
end

local function dist(a, b) return math.sqrt((a.wx - b.wx) ^ 2 + (a.wy - b.wy) ^ 2) end

local function nearestFP(fps, cont, p)
    local best, bd
    for _, f in ipairs(fps) do
        if f.cont == cont then
            local d = dist(f, p)
            if not bd or d < bd then best, bd = f, d end
        end
    end
    return best, bd
end

-- pernas dentro do mesmo continente: a pé direto, ou a pé -> voo -> a pé
local function samePlan(fps, from, to)
    local direct = dist(from, to)
    if direct <= WALK_MAX then return { { kind = "walk", to = to, yards = direct } }, direct end
    local fa, da = nearestFP(fps, from.cont, from)
    local fb, db = nearestFP(fps, to.cont, to)
    if fa and fb and fa ~= fb and (da + db) < direct * FLY_GAIN then
        local legs = {}
        if da > ARRIVE then table.insert(legs, { kind = "walk", to = fa, yards = da }) end
        table.insert(legs, { kind = "fly", from = fa, to = fb })
        if db > ARRIVE then table.insert(legs, { kind = "walk", to = to, yards = db }) end
        return legs, da + db + dist(fa, fb) * 0.25 -- voar é mais rápido que andar
    end
    return { { kind = "walk", to = to, yards = direct } }, direct
end

-- Plano completo da posição atual até o destino (m, x, y)
function TR:Plan(dest)
    if not dest or not dest.m or not dest.x then return nil end
    local me = self:PlayerPos()
    if not me then return nil end
    local to = point(dest.m, dest.x, dest.y, dest.name, dest.pname, "dest")
    if not to then return nil end
    local fps, trans = self:Points()
    if me.cont == to.cont then
        local legs = samePlan(fps, me, to)
        return legs, me, to
    end
    -- outro continente: escolhe o zepelim/barco que dá o menor caminho total
    local best, bestCost
    for _, t in ipairs(trans) do
        for _, dir in ipairs({ { t.a, t.b }, { t.b, t.a } }) do
            local s, e = dir[1], dir[2]
            if s.cont == me.cont and e.cont == to.cont then
                local l1, c1 = samePlan(fps, me, s)
                local l2, c2 = samePlan(fps, e, to)
                local cost = c1 + c2
                if not bestCost or cost < bestCost then
                    best, bestCost = { l1 = l1, l2 = l2, s = s, e = e, t = t }, cost
                end
            end
        end
    end
    if not best then return { { kind = "unknown", to = to } }, me, to end
    local legs = {}
    for _, l in ipairs(best.l1) do table.insert(legs, l) end
    table.insert(legs, { kind = "ship", from = best.s, to = best.e, t = best.t })
    for _, l in ipairs(best.l2) do table.insert(legs, l) end
    -- pernas de 0 metros (já está no ponto) somem
    local clean = {}
    for _, l in ipairs(legs) do if not (l.kind == "walk" and l.yards and l.yards < ARRIVE) then table.insert(clean, l) end end
    return clean, me, to
end

local function fpName(p)
    if not p then return "?" end
    local n = (RX:IsPT() and p.pname) or p.name or "?"
    return n .. " (" .. zoneName(p.m) .. ")"
end

-- Transforma o plano em passos "Viagem" para a janela (só quando há mais que uma caminhada simples)
function TR:Steps(dest)
    local legs = self:Plan(dest)
    if not legs or #legs == 0 then return nil end
    if #legs == 1 and legs[1].kind == "walk" then return nil, legs end
    local steps = {}
    for i, l in ipairs(legs) do
        local s = { t = "V", flags = {}, travel = true, index = 20000 + i, leg = l.kind }
        local target = l.to
        if l.kind == "walk" then
            local last = (i == #legs)
            if last then
                s.d = string.format(T("Siga até o objetivo (~%.0f m)", "Head to the objective (~%.0f m)"), (l.yards or 0) * 0.9144)
            elseif target.kind == "fp" then
                s.d = string.format(T("Vá até o mestre de voo %s (~%.0f m)", "Go to the flight master %s (~%.0f m)"), fpName(target), (l.yards or 0) * 0.9144)
            else
                s.d = string.format(T("Vá até o porto/torre de zepelim em %s (~%.0f m)", "Go to the dock/zeppelin tower in %s (~%.0f m)"), zoneName(target.m), (l.yards or 0) * 0.9144)
            end
        elseif l.kind == "fly" then
            s.d = string.format(T("Voe para %s", "Fly to %s"), fpName(target))
            s.note = T("Se ainda não tem esse voo, voe até o mais próximo que conhece e siga.", "If you don't have this flight path yet, fly to the closest one you know and continue.")
        elseif l.kind == "ship" then
            local isZep = (l.t.en or ""):find("Zeppelin")
            s.d = (isZep and T("Zepelim", "Zeppelin") or T("Barco", "Boat")) .. ": " .. zoneName(l.from.m) .. " -> " .. zoneName(l.to.m)
            s.note = string.format(T("Embarque em %s e desça em %s.", "Board in %s and get off in %s."), zoneName(l.from.m), zoneName(l.to.m)) ..
                (l.t.approx and T(" (posição do porto aproximada)", " (dock position approximate)") or "")
        else
            s.d = T("Destino em outro continente sem rota conhecida: use zepelim/barco.", "Destination on another continent with no known route: use a zeppelin/boat.")
        end
        s.m, s.x, s.y = target.m, target.x, target.y
        if l.kind == "ship" then s.m, s.x, s.y = l.from.m, l.from.x, l.from.y end
        if l.kind == "fly" then s.m, s.x, s.y = l.from.m, l.from.x, l.from.y end
        s.d = string.format("%s %d/%d: ", T("Viagem", "Travel"), i, #legs) .. s.d
        table.insert(steps, s)
    end
    return steps, legs
end

-- Pontos da rota (mundo) para desenhar a linha no mapa
function TR:RoutePoints(dest)
    local legs, me, to = self:Plan(dest)
    if not legs or not me then return nil end
    local pts = { me }
    for _, l in ipairs(legs) do
        if l.kind == "fly" or l.kind == "ship" then
            if l.from then table.insert(pts, l.from) end
            table.insert(pts, l.to)
        elseif l.to then
            table.insert(pts, l.to)
        end
    end
    return pts, to
end
