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
local LINE_PX, SHADOW_PX = 2, 4

local function canvasScale()
    local s = WorldMapFrame and WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale()
    if not s or s <= 0 then return 1 end
    return s
end

function ML:GetLine(i)
    local l = self.lines[i]
    if not l then
        -- contorno escuro fino por baixo: dá para ver de longe sem engrossar a linha
        local sh = self.overlay:CreateLine(nil, "ARTWORK")
        sh:SetColorTexture(0, 0, 0, 0.45)
        l = self.overlay:CreateLine(nil, "OVERLAY")
        l.shadow = sh
        self.lines[i] = l
    end
    return l
end

function ML:HideAll()
    for _, l in ipairs(self.lines) do l:Hide(); l.shadow:Hide() end
    if self.pin then self.pin:Hide(); self.ring:Hide(); self.label:Hide() end
end

function ML:Draw()
    if not self.overlay then return end
    self:HideAll()
    if RX.db and RX.db.mapLine == false then return end
    local dest = RX.Arrow and (RX.Arrow.finalStep or RX.Arrow.step)
    if not dest or not dest.m then return end
    local pts, to = RX.Travel:RoutePoints(dest)
    if not pts then return end
    local mapID = WorldMapFrame:GetMapID()
    local w, h = self.overlay:GetWidth(), self.overlay:GetHeight()
    if not mapID or not w or w <= 0 then return end
    local cs = canvasScale()
    local n = 0
    for i = 1, #pts - 1 do
        local x1, y1 = toMap(mapID, pts[i])
        local x2, y2 = toMap(mapID, pts[i + 1])
        if x1 and x2 then
            n = n + 1
            local l = self:GetLine(n)
            l:SetStartPoint("TOPLEFT", self.overlay, x1 * w, -y1 * h)
            l:SetEndPoint("TOPLEFT", self.overlay, x2 * w, -y2 * h)
            l:SetThickness(LINE_PX / cs)
            local sh = l.shadow
            sh:SetStartPoint("TOPLEFT", self.overlay, x1 * w, -y1 * h)
            sh:SetEndPoint("TOPLEFT", self.overlay, x2 * w, -y2 * h)
            sh:SetThickness(SHADOW_PX / cs)
            sh:Show()
            -- primeiro trecho laranja forte; os seguintes mais claros
            if n == 1 then l:SetColorTexture(1, 0.5, 0, 0.95) else l:SetColorTexture(1, 0.85, 0.3, 0.75) end
            l:Show()
        end
    end
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

-- Marca também o waypoint padrão do jogo (pino no mapa + indicador na tela), se existir
function ML:SetGameWaypoint(step)
    if not (RX.db and RX.db.mapPin ~= false) then return end
    if not (step and step.m and step.x and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates) then return end
    local ok, point = pcall(UiMapPoint.CreateFromCoordinates, step.m, step.x / 100, step.y / 100)
    if not ok or not point then return end
    pcall(C_Map.SetUserWaypoint, point)
    -- quest no log já está super-rastreada; para NPCs sem quest no log usamos o waypoint
    if InCombatLockdown and InCombatLockdown() then return end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint and not (step.q and RX.Q:InLog(step.q)) then
        pcall(C_SuperTrack.SetSuperTrackedUserWaypoint, true)
    end
end
