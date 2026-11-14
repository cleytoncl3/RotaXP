-- Linha de rota e marcação do destino no mapa-múndi (M)
local _, RX = ...
local ML = { lines = {} }
RX.MapLine = ML
local T = RX.T

local function toMap(mapID, p)
    if not (C_Map and C_Map.GetMapPosFromWorldPos and CreateVector2D) then return nil end
    local ok, _, pos = pcall(C_Map.GetMapPosFromWorldPos, p.cont, CreateVector2D(p.wx, p.wy), mapID)
    if not ok or not pos then return nil end
    local x, y = pos:GetXY()
    if not x or x < -0.2 or x > 1.2 or y < -0.2 or y > 1.2 then return nil end
    return x, y
end

function ML:Init()
    if self.overlay or not WorldMapFrame or not WorldMapFrame.GetCanvas then return end
    local canvas = WorldMapFrame:GetCanvas()
    if not canvas then return end
    local o = CreateFrame("Frame", "RouteXPMapOverlay", canvas)
    o:SetAllPoints(canvas)
    o:SetFrameStrata("HIGH")
    o:SetFrameLevel((canvas:GetFrameLevel() or 1) + 50)
    self.overlay = o
    -- a marca fica num frame próprio com escala 1/zoom, para ter sempre o mesmo tamanho na tela
    local mk = CreateFrame("Frame", nil, o)
    mk:SetSize(1, 1)
    self.marker = mk
    -- marcação do destino: círculo transparente por dentro + ponto do TomTom no centro
    local hasTT = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("TomTom")
    local ring = mk:CreateTexture(nil, "ARTWORK")
    if hasTT then
        ring:SetTexture("Interface\\AddOns\\TomTom\\Images\\PurpleRing")
        ring:SetVertexColor(1, 0.6, 0.15, 0.8)
    else
        ring:SetColorTexture(1, 0.6, 0.15, 0.18)
        if ring.SetMask then ring:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    end
    ring:SetSize(26, 26)
    self.ring = ring
    local pin = mk:CreateTexture(nil, "OVERLAY")
    if hasTT then
        pin:SetTexture("Interface\\AddOns\\TomTom\\Images\\GoldGreenDot")
    else
        pin:SetColorTexture(1, 0.6, 0.15, 1)
        if pin.SetMask then pin:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
    end
    pin:SetSize(9, 9)
    self.pin = pin
    local label = mk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetTextColor(1, 0.7, 0.2)
    self.label = label
    local elapsed = 0
    o:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed < 0.2 then return end
        elapsed = 0
        ML:Draw()
    end)
end

-- espessura em pixels de TELA (o mapa amplia tudo que está no canvas; compensamos o zoom)
local LINE_PX, EDGE_PX = 4.5, 1.5

local function canvasScale()
    local s = WorldMapFrame and WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()
    if not s or s <= 0 then return 1 end
    return s
end

function ML:HideAll()
    if self.pool then RX.Polyline:Clear(self.pool) end
    if self.mpool then RX.Polyline:Clear(self.mpool) end
    if self.pin then self.pin:Hide(); self.ring:Hide(); self.label:Hide() end
    if self.mark then for _, m in pairs(self.mark) do m:Hide() end end
end

-- desenha uma rota (lista de pontos do mundo) no mapa aberto; cores: principal, trecho reto (sem caminho)
local function drawRoute(pool, pts, mapID, w, h, cs, col)
    local PL = RX.Polyline
    local hasRoad = false
    for _, p in ipairs(pts) do if p.road then hasRoad = true break end end
    local th, ed = LINE_PX / cs, EDGE_PX / cs
    local prevOk = false
    for i = 1, #pts - 1 do
        local x1, y1 = toMap(mapID, pts[i])
        local x2, y2 = toMap(mapID, pts[i + 1])
        if x1 and x2 then
            local straight = hasRoad and not (pts[i].road or pts[i + 1].road)
            local air = pts[i].noRoad      -- voo/barco: linha reta mais fina
            local a = straight and 0.45 or 0.95
            PL:Seg(pool, "TOPLEFT", x1 * w, -y1 * h, x2 * w, -y2 * h, air and th * 0.6 or th, ed, col[1], col[2], col[3], air and 0.7 or a, prevOk and not air)
            prevOk = true
        else
            prevOk = false
        end
    end
end

function ML:Draw()
    if not self.overlay then return end
    self:HideAll()
    if RX.db and RX.db.mapLine == false then return end
    local mapID = WorldMapFrame:GetMapID()
    local w, h = self.overlay:GetWidth(), self.overlay:GetHeight()
    if not mapID or not w or w <= 0 then return end
    local cs = canvasScale()
    self.pool = self.pool or RX.Polyline:New(self.overlay, 1)
    self.mpool = self.mpool or RX.Polyline:New(self.overlay, 2)
    -- rota marcada (Ctrl+clique no mapa, sua ou de alguém do grupo): azul
    if RX.Mark then self:DrawMark(mapID, w, h, cs) end
    local dest = RX.Arrow and (RX.Arrow.finalStep or RX.Arrow.step)
    if not dest or not dest.m then return end
    local pts, to = RX.Travel:RoutePoints(dest)
    if not pts then return end
    drawRoute(self.pool, pts, mapID, w, h, cs, { 1, 0.62, 0.1 })
    local dx, dy = toMap(mapID, to)
    if dx then
        local mk = self.marker
        mk:SetScale(1 / cs)
        mk:ClearAllPoints(); mk:SetPoint("CENTER", self.overlay, "TOPLEFT", dx * w * cs, -dy * h * cs)
        self.pin:ClearAllPoints(); self.pin:SetPoint("CENTER", mk, "CENTER"); self.pin:Show()
        self.ring:ClearAllPoints(); self.ring:SetPoint("CENTER", self.pin, "CENTER"); self.ring:Show()
        self.label:ClearAllPoints(); self.label:SetPoint("TOP", self.pin, "BOTTOM", 0, -2)
        self.label:SetText(RX:NpcName(dest) or RX:QName(dest) or RX.LF(dest, "d") or T("Destino", "Destination"))
        self.label:Show()
    end
end

-- marcador redondo (início/fim da rota marcada), sempre do mesmo tamanho na tela
function ML:MarkDot(key, x, y, cs, r, g, b, text)
    self.mark = self.mark or {}
    local f = self.mark[key]
    if not f then
        f = CreateFrame("Frame", nil, self.overlay)
        f:SetSize(1, 1)
        f:SetFrameLevel(self.overlay:GetFrameLevel() + 5)
        local d = f:CreateTexture(nil, "OVERLAY")
        d:SetSize(14, 14); d:SetPoint("CENTER")
        if d.SetMask then d:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
        local e = f:CreateTexture(nil, "ARTWORK")
        e:SetSize(18, 18); e:SetPoint("CENTER"); e:SetColorTexture(0, 0, 0, 0.7)
        if e.SetMask then e:SetMask("Interface\\CharacterFrame\\TempPortraitAlphaMask") end
        local l = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        l:SetPoint("TOP", d, "BOTTOM", 0, -2)
        f.dot, f.label = d, l
        self.mark[key] = f
    end
    f:SetScale(1 / cs)
    f:ClearAllPoints(); f:SetPoint("CENTER", self.overlay, "TOPLEFT", x * cs, y * cs)
    f.dot:SetColorTexture(r, g, b, 1)
    f.label:SetText(text or ""); f.label:SetTextColor(r, g, b)
    f:Show()
end

function ML:DrawMark(mapID, w, h, cs)
    local M = RX.Mark
    local col = { 0.25, 0.8, 1 }
    if M.from then
        local x, y = toMap(mapID, M.from)
        if x then self:MarkDot("from", x * w, -y * h, cs, 0.3, 1, 0.4, T("Saída", "Start")) end
    end
    if M.to then
        local x, y = toMap(mapID, M.to)
        if x then self:MarkDot("to", x * w, -y * h, cs, col[1], col[2], col[3], M.label or T("Destino marcado", "Marked destination")) end
    end
    local pts = M:Points()
    if pts then drawRoute(self.mpool, pts, mapID, w, h, cs, col) end
end

-- Marca também o waypoint padrão do jogo (pino no mapa + indicador na tela), se existir
function ML:SetGameWaypoint(step)
    if not (RX.db and RX.db.mapPin ~= false) then return end
    if not (step and step.m and step.x and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, step.m, step.x / 100, step.y / 100)
    if not ok or not point then return end
    RX:Quiet(C_Map.SetUserWaypoint, point)
    -- quest no log já está super-rastreada; para NPCs sem quest no log usamos o waypoint
    if InCombatLockdown and InCombatLockdown() then return end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint and not (step.q and RX.Q:InLog(step.q)) then
        RX:Quiet(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
end
