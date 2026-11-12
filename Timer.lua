-- Cronômetro de XP: janela separada para medir quanto XP você ganha num período (masmorra, grind, quests)
local _, RX = ...
local TM = { running = false, elapsed = 0, xp = 0, kills = 0 }
RX.Timer = TM
local T = RX.T

local function fmtTime(s)
    s = math.floor(s or 0)
    return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
local function fmtXP(x) if x >= 1000 then return string.format("%.1fk", x / 1000) end return tostring(math.floor(x)) end

local function backdrop(f)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    f:SetBackdropBorderColor(0.3, 0.8, 1, 0.9)
end

local function button(parent, text, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetText(text); b:SetScript("OnClick", onClick)
    return b
end

function TM:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "RotaXPTimerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    backdrop(f)
    f:SetSize(280, 250)
    f:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    RX.UI:MakeDraggable(f)
    f:HookScript("OnDragStop", function(self)
        local p, _, rp, x, y = self:GetPoint(); RX.db.timerPos = { p, rp, x, y }
    end)
    if RX.db.timerPos then local p = RX.db.timerPos; f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -9)

    -- nome da sessão (ex.: "Zul'Farrak duo", "Grind raptors")
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetSize(180, 20); eb:SetPoint("TOPLEFT", 16, -30); eb:SetAutoFocus(false)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.name = eb

    f.big = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.big:SetPoint("TOPLEFT", 12, -58)
    f.stats = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.stats:SetPoint("TOPLEFT", f.big, "BOTTOMLEFT", 0, -6)
    f.stats:SetWidth(256); f.stats:SetJustifyH("LEFT"); f.stats:SetSpacing(2)

    f.start = button(f, "", 90, function() TM:Toggle() end)
    f.start:SetPoint("TOPLEFT", 12, -142)
    f.reset = button(f, "", 70, function() TM:Reset() end)
    f.reset:SetPoint("LEFT", f.start, "RIGHT", 6, 0)
    f.save = button(f, "", 80, function() TM:Save() end)
    f.save:SetPoint("LEFT", f.reset, "RIGHT", 6, 0)

    f.hist = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hist:SetPoint("TOPLEFT", f.start, "BOTTOMLEFT", 0, -8)
    f.hist:SetWidth(256); f.hist:SetJustifyH("LEFT"); f.hist:SetSpacing(2)

    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        if TM.running then TM.elapsed = TM.elapsed + e end
        acc = acc + e
        if acc >= 1 then acc = 0; TM:Render() end
    end)
    f:Hide()
    self.frame = f
end

function TM:DefaultName()
    local w = RX.Advisor and RX.Advisor:Where()
    local zone = w and ((w.zone and w.zone.name) or (w.here and w.here.name)) or "?"
    local party = RX.Leveling and RX.Leveling:Party() or {}
    local who = (#party > 1) and (" · " .. RX.Leveling:PartyText(party)) or ""
    return zone .. who
end

function TM:Toggle()
    self.running = not self.running
    if self.running and (self.frame.name:GetText() or "") == "" then self.frame.name:SetText(self:DefaultName()) end
    self:Render()
end

function TM:Reset()
    self.running, self.elapsed, self.xp, self.kills = false, 0, 0, 0
    self.frame.name:SetText("")
    self:Render()
end

function TM:Save()
    if self.elapsed < 30 then RX:Print(T("Meça pelo menos 30 segundos antes de salvar.", "Measure at least 30 seconds before saving.")) return end
    RX.db.timerHistory = RX.db.timerHistory or {}
    table.insert(RX.db.timerHistory, 1, { name = self.frame.name:GetText() ~= "" and self.frame.name:GetText() or self:DefaultName(),
        secs = math.floor(self.elapsed), xp = self.xp, kills = self.kills, level = UnitLevel("player"), when = date and date("%d/%m %H:%M") or "" })
    while #RX.db.timerHistory > 10 do table.remove(RX.db.timerHistory) end
    RX:Print(T("Sessão salva no histórico do cronômetro.", "Session saved to the timer history."))
    self:Render()
end

function TM:OnXP(gained)
    if self.running and gained and gained > 0 then self.xp = self.xp + gained end
end

-- conta mortes que deram XP (mensagem de combate)
function TM:OnXPMessage(msg)
    if not self.running or not msg then return end
    if not self.killPattern and COMBATLOG_XPGAIN_FIRSTPERSON then
        local p = COMBATLOG_XPGAIN_FIRSTPERSON
        p = p:gsub("%%%d%$s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2") -- marca os campos
        p = p:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")                                       -- escapa o resto
        self.killPattern = p:gsub("\1", ".+"):gsub("\2", "%%d+")
    end
    if not self.killPattern or msg:find(self.killPattern) then self.kills = self.kills + 1 end
end

function TM:Render()
    local f = self.frame
    if not f or not f:IsShown() then return end
    f.title:SetText("|cff4fc3ff" .. T("Cronômetro de XP", "XP Timer") .. "|r" .. (self.running and ("  |cff40ff40" .. T("gravando", "recording") .. "|r") or ("  |cffaaaaaa" .. T("pausado", "paused") .. "|r")))
    f.big:SetText(fmtTime(self.elapsed))
    local perH = self.elapsed > 0 and self.xp / self.elapsed * 3600 or 0
    local left = UnitXPMax("player") - UnitXP("player")
    local eta = perH > 0 and (left / perH * 60) or nil
    f.stats:SetText(string.format(T("XP ganho: |cff40ff40%s|r   Mortes: %d\nXP/hora: |cffffd100%s|r%s\nXP por morte: %s",
        "XP gained: |cff40ff40%s|r   Kills: %d\nXP/hour: |cffffd100%s|r%s\nXP per kill: %s"),
        fmtXP(self.xp), self.kills, fmtXP(perH),
        eta and string.format(T("  ·  próximo nível em ~%.0f min", "  ·  next level in ~%.0f min"), eta) or "",
        self.kills > 0 and fmtXP(self.xp / self.kills) or "-"))
    f.start:SetText(self.running and T("Pausar", "Pause") or (self.elapsed > 0 and T("Continuar", "Resume") or T("Iniciar", "Start")))
    f.reset:SetText(T("Zerar", "Reset"))
    f.save:SetText(T("Salvar", "Save"))
    local lines = { "|cffff7f00" .. T("Histórico (compare spots e masmorras):", "History (compare spots and dungeons):") .. "|r" }
    for i, h in ipairs(RX.db.timerHistory or {}) do
        if i > 6 then break end
        local ph = h.secs > 0 and h.xp / h.secs * 3600 or 0
        table.insert(lines, string.format("%s  |cffffd100%s xp/h|r  (%s, %s xp, nv %d)", h.name or "?", fmtXP(ph), fmtTime(h.secs), fmtXP(h.xp), h.level or 0))
    end
    if #lines == 1 then table.insert(lines, T("  (vazio - clique em Salvar depois de medir)", "  (empty - click Save after measuring)")) end
    f.hist:SetText(table.concat(lines, "\n"))
    f:SetHeight(160 + f.hist:GetStringHeight() + 14)
end

function TM:Show()
    self:Create()
    self.frame:Show()
    if (self.frame.name:GetText() or "") == "" then self.frame.name:SetText(self:DefaultName()) end
    self:Render()
end

function TM:ToggleWindow()
    self:Create()
    if self.frame:IsShown() then self.frame:Hide() else self:Show() end
end
