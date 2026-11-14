-- Linha da rota no MINIMAPA (estilo GPS) + checkpoints no TomTom ao longo do caminho
local _, RX = ...
local MM = { lines = {}, cps = {} }
RX.MiniLine = MM
local T = RX.T

-- diâmetro visível do minimapa em jardas por nível de zoom (valores do HereBeDragons)
local SIZE_OUT = { [0] = 466 + 2 / 3, 400, 333 + 1 / 3, 266 + 2 / 3, 200, 133 + 1 / 3 }
local SIZE_IN = { [0] = 300, 240, 180, 120, 80, 50 }
local CP_STEP = 350   -- jardas entre checkpoints numa caminhada longa
local CP_MAX = 5      -- máximo de checkpoints no TomTom (para não poluir)
local RING_R, RING_SEG = 7, 14   -- raio (px) e segmentos do anel do destino

function MM:ShowRing(x, y)
    for i, l in ipairs(self.ring) do
        local a1, a2 = (i - 1) / RING_SEG * 2 * math.pi, i / RING_SEG * 2 * math.pi
        l:SetStartPoint("CENTER", self.overlay, x + RING_R * math.cos(a1), y + RING_R * math.sin(a1))
        l:SetEndPoint("CENTER", self.overlay, x + RING_R * math.cos(a2), y + RING_R * math.sin(a2))
        l:Show()
    end
end

function MM:Init()
    if self.overlay or not Minimap then return end
    local o = CreateFrame("Frame", "RouteXPMiniOverlay", Minimap)
    o:SetAllPoints(Minimap)
    o:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 5)
    self.overlay = o
    -- destino: anel fino e vazado (o "!"/"?" do NPC continua visível no meio)
    self.ring = {}
    for i = 1, RING_SEG do
        local l = o:CreateLine(nil, "OVERLAY")
        l:SetThickness(1.5)
        l:SetColorTexture(1, 0.55, 0.1, 0.9)
        l:Hide()
        self.ring[i] = l
    end
    local acc = 0
    o:SetScript("OnUpdate", function(_, e)
        acc = acc + e
        if acc < 0.1 then return end
        acc = 0
        MM:Draw()
    end)
end

-- converte um ponto do mundo para pixels no minimapa (centro = você); devolve também se ficou dentro
local function toMini(me, p, radiusYd, radiusPx, rot, square)
    local dx = -(p.wy - me.wy)           -- leste = positivo
    local dy = (p.wx - me.wx)            -- norte = positivo
    if rot then
        local c, s = math.cos(rot), math.sin(rot)
        dx, dy = dx * c - dy * s, dx * s + dy * c
    end
    local x, y = dx / radiusYd * radiusPx, dy / radiusYd * radiusPx
    local inside = true
    if square then
        local m = math.max(math.abs(x), math.abs(y))
        if m > radiusPx * 0.95 then x, y = x / m * radiusPx * 0.95, y / m * radiusPx * 0.95; inside = false end
    else
        local d = math.sqrt(x * x + y * y)
        if d > radiusPx * 0.95 then x, y = x / d * radiusPx * 0.95, y / d * radiusPx * 0.95; inside = false end
    end
    return x, y, inside
end

local LINE_PX, EDGE_PX = 3.5, 1.2

-- desenha pts (mundo) no minimapa a partir da sua posição 'me'; para no primeiro ponto fora do minimapa
local function drawMini(pool, me, pts, first, view, col, ringAtEnd)
    local PL = RX.Polyline
    local hasRoad = false
    for _, p in ipairs(pts) do if p.road then hasRoad = true break end end
    local px, py, pin = toMini(me, pts[first], view.r, view.px, view.rot, view.sq)
    local joint = false
    for i = first + 1, #pts do
        if pts[i].cont ~= me.cont then break end
        local x, y, inside = toMini(me, pts[i], view.r, view.px, view.rot, view.sq)
        local ex, ey = x, y
        if ringAtEnd and i == #pts and inside then
            -- a linha para na borda do anel, sem cobrir o NPC
            local dx, dy = x - px, y - py
            local dd = math.sqrt(dx * dx + dy * dy)
            if dd > RING_R + 1 then ex, ey = x - dx / dd * RING_R, y - dy / dd * RING_R end
        end
        local straight = hasRoad and not (pts[i].road or pts[i - 1].road)
        local air = pts[i - 1].noRoad
        if ringAtEnd or inside or pin then
            PL:Seg(pool, "CENTER", px, py, ex, ey, air and LINE_PX * 0.6 or LINE_PX, EDGE_PX, col[1], col[2], col[3], (straight or air) and 0.5 or 0.95, joint and pin and not air)
            joint = true
        else
            joint = false
        end
        -- rota até o objetivo: começa em você e para na borda; rota marcada: desenha só o pedaço que cai no minimapa
        if ringAtEnd and not inside then break end
        px, py, pin = x, y, inside
        if ringAtEnd and i == #pts then MM:ShowRing(x, y) end
    end
end

function MM:Draw()
    for _, l in ipairs(self.ring) do l:Hide() end
    self.pool = self.pool or RX.Polyline:New(self.overlay, 1)
    self.mpool = self.mpool or RX.Polyline:New(self.overlay, 2)
    RX.Polyline:Clear(self.pool); RX.Polyline:Clear(self.mpool)
    if RX.db and RX.db.miniLine == false then return end
    local me = RX.Travel:PlayerPos()
    if not me then return end
    local zoom = Minimap:GetZoom() or 0
    local indoors = IsIndoors and IsIndoors()
    local view = {
        r = ((indoors and SIZE_IN[zoom]) or SIZE_OUT[zoom] or 466) / 2,
        px = (Minimap:GetWidth() or 140) / 2,
        rot = (GetCVar and GetCVar("rotateMinimap") == "1") and GetPlayerFacing and -(GetPlayerFacing() or 0) or nil,
        sq = GetMinimapShape and GetMinimapShape() == "SQUARE",
    }
    -- rota marcada (sua ou do grupo), em azul
    local mpts = RX.Mark and RX.Mark:Points()
    if mpts and #mpts >= 2 and mpts[1].cont == me.cont then drawMini(self.mpool, me, mpts, 1, view, { 0.25, 0.8, 1 }, false) end
    local dest = RX.Arrow and (RX.Arrow.finalStep or RX.Arrow.step)
    if not dest or not dest.m then return end
    local pts = RX.Travel:RoutePoints(dest)
    if not pts or #pts < 2 then return end
    drawMini(self.pool, pts[1], pts, 1, view, { 1, 0.62, 0.1 }, true)
end

----------------------------------------------------------------------
-- Checkpoints no TomTom: pontos de voo/porto da viagem + alguns pontos nas caminhadas longas
----------------------------------------------------------------------
local function worldToMap(p, mapHint)
    if not (C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    for _, m in ipairs({ mapHint, p.m }) do
        if m then
            local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, p.cont, CreateVector2D(p.wx, p.wy), m)
            if ok and pos then
                local x, y = pos:GetXY()
                if x and x >= 0 and x <= 1 and y >= 0 and y <= 1 then return m, x, y end
            end
        end
    end
    return nil
end

function MM:ClearCheckpoints()
    if TomTom and TomTom.RemoveWaypoint then
        for _, uid in ipairs(self.cps) do RX:Quiet(TomTom.RemoveWaypoint, TomTom, uid) end
    end
    wipe(self.cps)
end

function MM:SetCheckpoints(dest)
    self:ClearCheckpoints()
    if not (RX.db.useTomTom and RX.db.checkpoints ~= false and TomTom and TomTom.AddWaypoint and dest and dest.m) then return end
    local pts = RX.Travel:RoutePoints(dest)
    if not pts or #pts < 2 then return end
    local marks = {}
    for i = 2, #pts - 1 do
        if not pts[i].road then table.insert(marks, { p = pts[i], name = T("Etapa", "Leg") .. " " .. (#marks + 1) }) end   -- só voo/porto, não cada curva da estrada
    end
    -- caminhada longa até o destino: pontos intermediários
    local a, b = pts[#pts - 1], pts[#pts]
    if a.cont == b.cont then
        local d = math.sqrt((b.wx - a.wx) ^ 2 + (b.wy - a.wy) ^ 2)
        local k = math.min(3, math.floor(d / CP_STEP))
        for j = 1, k do
            local t = j / (k + 1)
            table.insert(marks, { p = { cont = a.cont, wx = a.wx + (b.wx - a.wx) * t, wy = a.wy + (b.wy - a.wy) * t, m = b.m },
                name = T("Checkpoint", "Checkpoint") .. " " .. j })
        end
    end
    for i = 1, math.min(CP_MAX, #marks) do
        local mk = marks[i]
        local m, x, y = worldToMap(mk.p, mk.p.m or dest.m)
        if m then
            local ok, uid = RX:Quiet(TomTom.AddWaypoint, TomTom, m, x, y, {
                title = "RouteXP: " .. mk.name, persistent = false, minimap = false, world = true, crazy = false, silent = true, cleardistance = 25,
            })
            if ok and uid then table.insert(self.cps, uid) end
        end
    end
end
