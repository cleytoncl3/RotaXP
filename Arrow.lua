-- Seta de navegação (estilo Zygor/TomTom)
local _, RX = ...
local Arrow = {}
RX.Arrow = Arrow

local atan2, sqrt, pi = math.atan2 or function(y, x) return math.atan(y, x) end, math.sqrt, math.pi
local GO_RADIUS_YARDS = 12
local GO_RADIUS_PCT = 0.6

local function worldPos(mapID, x, y)
    if not (C_Map and C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local ok, cont, pos = pcall(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(x, y))
    if not ok or not pos then return nil end
    return cont, pos.x, pos.y -- pos.x = norte, pos.y = oeste
end

local function playerMapPos()
    local map = C_Map.GetBestMapForUnit("player")
    if not map then return nil end
    local p = C_Map.GetPlayerMapPosition(map, "player")
    if not p then return map end
    local x, y = p:GetXY()
    if not x or (x == 0 and y == 0) then return map end
    return map, x, y
end

function Arrow:Create()
    local f = CreateFrame("Button", "RotaXPArrow", UIParent)
    f:SetSize(56, 56)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:RegisterForClicks("RightButtonUp")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(self) if not RX.db.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        RX.db.arrowPos = { p, rp, x, y }
    end)
    f:SetScript("OnClick", function() RX.UI:SkipCurrent() end)
    if RX.db.arrowPos then
        local p = RX.db.arrowPos
        f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end

    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture("Interface\\Minimap\\MinimapArrow")
    tex:SetVertexColor(1, 0.55, 0.1)
    f.tex = tex

    local dist = f:CreateFontString(nil, "OVERLAY")
    dist:SetPoint("TOP", f, "BOTTOM", 0, 2)
    f.dist = dist
    local label = f:CreateFontString(nil, "OVERLAY")
    label:SetPoint("TOP", dist, "BOTTOM", 0, -1)
    label:SetWidth(220)
    f.label = label

    f:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(RX.T("Seta RouteXP", "RouteXP arrow"))
        GameTooltip:AddLine(RX.T("Arraste para mover. Clique direito: pular passo.", "Drag to move. Right-click: skip step."), 1, 1, 1)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed < 0.05 then return end
        elapsed = 0
        Arrow:Tick()
        -- durante uma viagem, replaneja a cada 3s conforme você anda
        Arrow.replan = (Arrow.replan or 0) + 0.05
        if Arrow.replan > 3 then Arrow.replan = 0; if (Arrow.step and Arrow.step.travel) or RX.db.smartOrder ~= false then RX:Update(true) end end
    end)
    self.frame = f
    f:Hide()
    self:ApplySize()
end

-- step = para onde a seta aponta agora (pode ser uma perna da viagem)
-- final = o objetivo de verdade (marcado no TomTom e no mapa do jogo)
-- Tamanho da seta e do texto embaixo dela (Opções > Aparência)
function Arrow:ApplySize()
    local f = self.frame
    if not f then return end
    local sc = RX.db.arrowScale or 1
    f:SetSize(56 * sc, 56 * sc)
    if not self.fontDist then
        self.fontDist = CreateFont("RotaXPArrowFontDist")
        self.fontLabel = CreateFont("RotaXPArrowFontLabel")
    end
    local file, _, flags = GameFontHighlight:GetFont()
    file = file or "Fonts\\FRIZQT__.TTF"
    local size = RX.db.arrowFont or 11
    self.fontDist:SetFont(file, size + 4, "OUTLINE")
    self.fontDist:SetTextColor(1, 0.82, 0)
    self.fontLabel:SetFont(file, size, flags or "")
    self.fontLabel:SetTextColor(1, 1, 1)
    f.dist:SetFontObject(self.fontDist)
    f.label:SetFontObject(self.fontLabel)
    f.label:SetWidth(math.max(220, size * 20))
end

function Arrow:SetTarget(step, final)
    final = final or step
    local finalChanged = final ~= self.finalStep
    self.step = step
    self.finalStep = final
    if finalChanged then
        if self.tomtomUID and TomTom and TomTom.RemoveWaypoint then
            pcall(TomTom.RemoveWaypoint, TomTom, self.tomtomUID)
            self.tomtomUID = nil
        end
        if final and final.m and final.x then
            if RX.db.useTomTom and TomTom and TomTom.AddWaypoint then
                local ok, uid = pcall(TomTom.AddWaypoint, TomTom, final.m, final.x / 100, final.y / 100, {
                    title = "RouteXP: " .. (RX:NpcName(final) or RX:QName(final) or RX.LF(final, "d") or RX.T("destino", "destination")),
                    persistent = false, minimap = false, world = true, crazy = false, silent = true,  -- minimapa: o RouteXP desenha um anel fino
                })
                if ok then self.tomtomUID = uid end
            end
            if RX.MapLine then RX.MapLine:SetGameWaypoint(final) end
            if RX.MiniLine then RX.MiniLine:SetCheckpoints(final) end
        end
    end
    if not step or not step.m or not step.x then
        self.frame:Hide()
        return
    end
    if RX.db.showArrow then self.frame:Show() else self.frame:Hide() end
    self:Tick()
end

-- Objetivo final: o passo clicado (se ainda estiver na lista) ou o primeiro com coordenadas
function Arrow:FinalTarget(steps)
    if self.manual then
        if self.manual.external then return self.manual.step end
        for _, s in ipairs(steps) do if s == self.manual.step then return s end end
        self.manual = nil
    end
    for _, s in ipairs(steps) do
        if s.m and s.x and not s.noNav then return s end
        if not s.noNav and (s.q or s.t == "G") then return nil end -- não aponta além de um passo de quest sem coordenada
    end
    return nil
end

function Arrow:Retarget()
    if not self.frame then return end
    local steps, final, travel = RX:StepsWithTravel(RX.db.numSteps or 4)
    local target = (travel and travel[1]) or final
    if target ~= self.step or final ~= self.finalStep then self:SetTarget(target, final) end
    if target and RX.db.showArrow then self.frame:Show() else self.frame:Hide() end
end

function Arrow:PointTo(step, external)
    -- external = alvo fora da lista (ex.: ponto de grind); fica até você clicar em "Parar de apontar" ou noutro passo
    self.manual = { step = step, valid = true, external = external }
    self:SetTarget(step)
end

function Arrow:ClearManual()
    self.manual = nil
end

local function zoneName(mapID)
    local info = mapID and C_Map.GetMapInfo(mapID)
    return info and info.name or "?"
end

function Arrow:Tick()
    local s = self.step
    local f = self.frame
    if not s or not f:IsShown() then return end
    local pmap, px, py = playerMapPos()
    if not px then
        f.tex:Hide()
        f.dist:SetText("")
        f.label:SetText((RX:NpcName(s) or RX:QName(s) or RX.LF(s, "d") or "") .. "\n|cffaaaaaa" .. zoneName(s.m) .. string.format(" %.1f, %.1f|r", s.x, s.y))
        return
    end
    local tx, ty = s.x / 100, s.y / 100
    local pc, pN, pW = worldPos(pmap, px, py)
    local tc, tN, tW = worldPos(s.m, tx, ty)
    local angle, yards
    if pc and tc and pc == tc then
        local dN, dW = tN - pN, tW - pW
        yards = sqrt(dN * dN + dW * dW)
        angle = atan2(dW, dN)
    elseif pmap == s.m then
        local dx, dy = tx - px, ty - py
        angle = atan2(-dx, -dy)
        local pct = sqrt(dx * dx + dy * dy) * 100
        if pct < GO_RADIUS_PCT then yards = 0 end
    end
    local facing = GetPlayerFacing and GetPlayerFacing()
    if angle and facing then
        f.tex:Show()
        f.tex:SetRotation(angle - facing)
        f.tex:SetVertexColor(1, 0.55, 0.1)
    else
        f.tex:Hide()
    end
    if yards then
        f.dist:SetText(string.format("%.0f m", yards * 0.9144))
    elseif pmap ~= s.m then
        f.dist:SetText("|cffff8080" .. RX.T("Vá para ", "Go to ") .. zoneName(s.m) .. "|r")
    else
        f.dist:SetText("")
    end
    f.label:SetText(RX:NpcName(s) or RX:QName(s) or RX.LF(s, "d") or "")

    -- Chegou ao destino de um passo "Ir para"
    if yards and yards < GO_RADIUS_YARDS then
        if s.t == "G" and not self.manual then
            RX:MarkStep(s, true)
        else
            f.tex:SetVertexColor(0.2, 1, 0.2)
        end
    end
end
