-- Rota marcada no mapa (GPS para o grupo):
--   Ctrl + botão DIREITO no mapa-múndi = ponto de saída
--   Ctrl + botão ESQUERDO             = destino -> traça o caminho (a pé pelo terreno/estradas, voo, zepelim/barco)
-- A rota aparece em azul no mapa e no minimapa, com uma janelinha das etapas (voo, barco...), e vai na hora para
-- todo mundo do grupo que tem o RouteXP (sem pedir confirmação). Sem saída marcada, a saída é onde você está.
local _, RX = ...
local MR = {}
RX.Mark = MR
local T = RX.T

local function short(n) return n and (Ambiguate and Ambiguate(n, "short") or n:gsub("%-.*$", "")) end

-- ponto {m, x(0-100), y(0-100)} -> com posição no mundo
local function worldPt(m, x, y)
    if not (RX.Travel and RX.Travel.world) then return nil end
    local c, wx, wy = RX.Travel.world(m, x, y)
    if not c then return nil end
    return { m = m, x = x, y = y, cont = c, wx = wx, wy = wy }
end

local function zoneName(m)
    local info = m and C_Map and C_Map.GetMapInfo(m)
    return info and info.name or "?"
end

function MR:Active() return self.to ~= nil end

-- pontos da rota (para desenhar); recalcula quando a saída/destino mudam
function MR:Points()
    if not self.to then return nil end
    local from = self.from or (RX.Travel and RX.Travel:PlayerPos())
    if not from then return nil end
    local pts = RX.Travel:RoutePoints({ m = self.to.m, x = self.to.x, y = self.to.y }, { m = from.m, x = from.x, y = from.y })
    return pts
end

function MR:Steps()
    if not self.to then return nil end
    local from = self.from or (RX.Travel and RX.Travel:PlayerPos())
    if not from then return nil end
    local steps, legs = RX.Travel:Steps({ m = self.to.m, x = self.to.x, y = self.to.y }, { m = from.m, x = from.x, y = from.y })
    return steps, legs
end

-- define a rota; send = mandar para o grupo; owner = quem marcou (nil = você)
function MR:Set(from, to, owner, send)
    self.from = from and worldPt(from.m, from.x, from.y) or nil
    self.to = to and worldPt(to.m, to.x, to.y) or nil
    self.owner = owner
    if to and not self.to then self.to = { m = to.m, x = to.x, y = to.y } end
    self.label = owner and string.format(T("Destino de %s", "%s's destination"), owner) or T("Destino marcado", "Marked destination")
    if send and RX.Party and RX.Party.SendMark then RX.Party:SendMark(self.from, self.to) end
    self:ShowPanel()
    if RX.MapLine and RX.MapLine.Draw then pcall(RX.MapLine.Draw, RX.MapLine) end
end

function MR:Clear(send)
    local had = self.to ~= nil
    self.from, self.to, self.owner, self.pendingFrom = nil, nil, nil, nil
    if self.panel then self.panel:Hide() end
    if send and had and RX.Party and RX.Party.SendMark then RX.Party:SendMark(nil, nil) end
    if RX.MapLine and RX.MapLine.Draw then pcall(RX.MapLine.Draw, RX.MapLine) end
end

-- clique no mapa
function MR:OnMapClick(button, m, x, y)
    if RX.db and RX.db.markRoute == false then return end
    if button == "RightButton" then
        self.pendingFrom = { m = m, x = x, y = y }
        -- se já tem destino, troca só a saída
        if self.to and not self.owner then self:Set(self.pendingFrom, self.to, nil, true) end
        self.flash = T("Saída marcada. Agora Ctrl + clique ESQUERDO no destino.", "Start marked. Now Ctrl + LEFT click the destination.")
        self:ShowPanel()
    else
        local from = self.pendingFrom or (self.to and not self.owner and self.from) or nil
        self.flash = nil
        self:Set(from, { m = m, x = x, y = y }, nil, true)
    end
end

----------------------------------------------------------------------
-- Janelinha: etapas da rota marcada
----------------------------------------------------------------------
function MR:CreatePanel()
    if self.panel then return end
    local f = CreateFrame("Frame", "RouteXPMarkPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    if not f.SetBackdrop and BackdropTemplateMixin then Mixin(f, BackdropTemplateMixin) end
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.04, 0.06, 0.09, 0.95)
        f:SetBackdropBorderColor(0.25, 0.8, 1, 0.95)
    end
    f:SetWidth(300)
    f:SetPoint("TOP", UIParent, "TOP", 0, -120)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    if RX.UI and RX.UI.MakeDraggable then RX.UI:MakeDraggable(f) end
    f:HookScript("OnDragStop", function(s) local p, _, rp, x, y = s:GetPoint(); RX.db.markPos = { p, rp, x, y } end)
    if RX.db.markPos then local p = RX.db.markPos; f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10); f.title:SetJustifyH("LEFT")
    f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.body:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)
    f.body:SetJustifyH("LEFT"); f.body:SetWordWrap(true)
    if f.body.SetSpacing then f.body:SetSpacing(3) end
    local function btn(text, w, fn)
        local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", fn)
        return b
    end
    f.follow = btn(T("Seguir (seta)", "Follow (arrow)"), 110, function() MR:Follow() end)
    f.follow:SetPoint("TOPLEFT", f.body, "BOTTOMLEFT", 0, -8)
    f.clear = btn(T("Apagar rota", "Clear route"), 100, function() MR:Clear(not MR.owner) end)
    f.clear:SetPoint("LEFT", f.follow, "RIGHT", 6, 0)
    f:Hide()
    self.panel = f
end

function MR:ShowPanel()
    self:CreatePanel()
    local f = self.panel
    local lines = {}
    if self.flash and not self.to then
        f.title:SetText("|cff40ccff" .. T("Rota marcada", "Marked route") .. "|r")
        lines[#lines + 1] = self.flash
    elseif self.to then
        f.title:SetText("|cff40ccff" .. (self.owner and string.format(T("Rota de %s", "%s's route"), self.owner) or T("Sua rota marcada", "Your marked route")) .. "|r")
        local from = self.from
        lines[#lines + 1] = "|cff40ff60" .. T("Saída: ", "Start: ") .. "|r" .. (from and string.format("%s %.0f, %.0f", zoneName(from.m), from.x, from.y) or T("onde você está", "where you are"))
        lines[#lines + 1] = "|cff40ccff" .. T("Destino: ", "Destination: ") .. "|r" .. string.format("%s %.0f, %.0f", zoneName(self.to.m), self.to.x, self.to.y)
        local steps, legs = self:Steps()
        if steps then
            for _, s in ipairs(steps) do
                local icon = (s.leg == "fly" and "|TInterface\\Minimap\\Tracking\\FlightMaster:14|t ")
                    or (s.leg == "ship" and "|cff40ccff>>|r ") or "|cff40ff60•|r "
                lines[#lines + 1] = icon .. (s.d or "")
            end
        elseif legs and legs[1] then
            lines[#lines + 1] = string.format(T("A pé: ~%.0f m pelo caminho do mapa (contorna montanhas)", "On foot: ~%.0f m along the map path (around mountains)"), (legs[1].yards or 0) * 0.9144)
        end
        if not self.owner and RX.Party and RX.Party.InGroup and RX.Party:InGroup() then
            lines[#lines + 1] = "|cffaaaaaa" .. T("Enviada para o grupo (quem tem RouteXP vê a mesma rota).", "Sent to the group (everyone with RouteXP sees the same route).") .. "|r"
        end
    else
        f:Hide()
        return
    end
    lines[#lines + 1] = "|cff888888" .. T("Ctrl+direito no mapa: saída · Ctrl+esquerdo: destino", "Ctrl+right on the map: start · Ctrl+left: destination") .. "|r"
    f.body:SetWidth(276)
    f.body:SetText(table.concat(lines, "\n"))
    f.follow:SetShown(self.to ~= nil)
    f.clear:SetShown(self.to ~= nil)
    f:SetHeight(10 + f.title:GetStringHeight() + 6 + f.body:GetStringHeight() + (self.to and 38 or 12))
    f:Show()
end

-- a seta passa a apontar para o destino marcado (com voo/barco no caminho, como no guia)
function MR:Follow()
    if not self.to or not RX.Arrow then return end
    RX.Arrow:PointTo({ t = "G", m = self.to.m, x = self.to.x, y = self.to.y, flags = {}, external = true,
        d = self.label or T("Destino marcado", "Marked destination") }, true)
    RX:Update(true)
end

----------------------------------------------------------------------
-- Ctrl + clique no mapa-múndi
----------------------------------------------------------------------
function MR:HookMap()
    if self.hooked or not (WorldMapFrame and WorldMapFrame.ScrollContainer) then return end
    self.hooked = true
    local sc = WorldMapFrame.ScrollContainer
    sc:HookScript("OnMouseDown", function(s, button)
        if not (IsControlKeyDown and IsControlKeyDown()) or (RX.db and RX.db.markRoute == false) then MR.down = nil return end
        local x, y = s:GetNormalizedCursorPosition()
        MR.down = { button = button, m = WorldMapFrame:GetMapID(), x = x, y = y }
    end)
    sc:HookScript("OnMouseUp", function(_, button)
        local d = MR.down
        MR.down = nil
        if not d or d.button ~= button or not d.m or not d.x then return end
        if d.x < 0 or d.x > 1 or d.y < 0 or d.y > 1 then return end
        MR:OnMapClick(button, d.m, d.x * 100, d.y * 100)
        -- o botão direito normalmente afasta o zoom do mapa: volta para o mapa onde você clicou
        if button == "RightButton" and C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if WorldMapFrame:GetMapID() ~= d.m then pcall(WorldMapFrame.SetMapID, WorldMapFrame, d.m) end
            end)
        end
    end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function() pcall(MR.HookMap, MR) end)
