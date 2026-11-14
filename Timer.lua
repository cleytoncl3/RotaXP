-- Cronômetro de farm: janela separada que mede, num período (masmorra, grind, quests), quanto XP e quanto OURO
-- você ganha: moedas saqueadas dos mobs (inclusive sua parte no grupo) + valor de venda dos itens saqueados.
-- Layout em coluna: nada fica por baixo dos botões; a altura acompanha o texto e o canto muda a largura.
local _, RX = ...
local TM = { running = false, elapsed = 0, xp = 0, kills = 0, coins = 0, items = 0, itemsAH = 0, nItems = 0 }
RX.Timer = TM
local T = RX.T

local PAD = 12
local MIN_W, MAX_W = 260, 620

local function fmtTime(s)
    s = math.floor(s or 0)
    return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
local function fmtXP(x) if x >= 1000 then return string.format("%.1fk", x / 1000) end return tostring(math.floor(x)) end
-- cobre -> "1g 20s 5c" colorido
local function fmtMoney(c)
    c = math.floor(c or 0)
    local g, s, cu = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
    local out = {}
    if g > 0 then out[#out + 1] = string.format("|cffffd700%dg|r", g) end
    if s > 0 or g > 0 then out[#out + 1] = string.format("|cffc7c7cf%ds|r", s) end
    out[#out + 1] = string.format("|cffeda55f%dc|r", cu)
    return table.concat(out, " ")
end
TM.fmtMoney = fmtMoney

local function backdrop(f)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
    f:SetBackdropBorderColor(0.3, 0.8, 1, 0.9)
end

local function button(parent, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22); b:SetScript("OnClick", onClick)
    return b
end

local function text(f, font)
    local s = f:CreateFontString(nil, "OVERLAY", font)
    s:SetJustifyH("LEFT")
    s:SetWordWrap(true)
    if s.SetSpacing then s:SetSpacing(2) end
    return s
end

function TM:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "RouteXPTimerFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    backdrop(f)
    f:SetSize(RX.db.timerWidth or 300, 260)
    f:SetPoint("CENTER", UIParent, "CENTER", -300, 0)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    RX.UI:MakeDraggable(f)
    f:HookScript("OnDragStop", function(self)
        local p, _, rp, x, y = self:GetPoint(); RX.db.timerPos = { p, rp, x, y }
    end)
    if RX.db.timerPos then local p = RX.db.timerPos; f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) end
    if RX.db.timerScale then f:SetScale(RX.db.timerScale) end
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)

    f.title = text(f, "GameFontNormal")
    f.title:SetPoint("TOPLEFT", PAD, -10)

    -- nome da sessão (ex.: "Zul'Farrak duo", "Grind raptors")
    local eb = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    eb:SetHeight(20); eb:SetAutoFocus(false)
    eb:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 4, -6)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.name = eb

    f.big = text(f, "GameFontNormalHuge")
    f.big:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -4, -8)
    f.stats = text(f, "GameFontHighlight")
    f.stats:SetPoint("TOPLEFT", f.big, "BOTTOMLEFT", 0, -6)
    f.gold = text(f, "GameFontHighlight")
    f.gold:SetPoint("TOPLEFT", f.stats, "BOTTOMLEFT", 0, -8)

    -- botões SEMPRE abaixo do texto (o texto empurra os botões para baixo)
    f.start = button(f, 92, function() TM:Toggle() end)
    f.start:SetPoint("TOPLEFT", f.gold, "BOTTOMLEFT", 0, -10)
    f.reset = button(f, 70, function() TM:Reset() end)
    f.reset:SetPoint("LEFT", f.start, "RIGHT", 6, 0)
    f.save = button(f, 80, function() TM:Save() end)
    f.save:SetPoint("LEFT", f.reset, "RIGHT", 6, 0)

    f.hist = text(f, "GameFontHighlightSmall")
    f.hist:SetPoint("TOPLEFT", f.start, "BOTTOMLEFT", 0, -10)

    -- canto de baixo: arraste para os lados para mudar a largura (a altura se ajusta ao texto)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function()
        local s = f:GetEffectiveScale()
        local left, top = f:GetLeft(), f:GetTop()
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        grip:SetScript("OnUpdate", function()
            local cx = GetCursorPosition() / s
            local w = math.max(MIN_W, math.min(MAX_W, cx - left))
            if math.abs(w - f:GetWidth()) >= 1 then f:SetWidth(w); TM:Layout() end
        end)
    end)
    grip:SetScript("OnMouseUp", function()
        grip:SetScript("OnUpdate", nil)
        RX.db.timerWidth = math.floor(f:GetWidth())
        local p, _, rp, x, y = f:GetPoint(); RX.db.timerPos = { p, rp, x, y }
    end)
    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(T("Arraste para os lados: largura da janela", "Drag sideways: window width"), 1, 1, 1)
        GameTooltip:AddLine(T("Ctrl + roda do mouse na janela: tamanho do texto", "Ctrl + mouse wheel on the window: text size"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Ctrl + roda: escala da janela inteira (texto maior/menor)
    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(self, d)
        if not (IsControlKeyDown and IsControlKeyDown()) then return end
        local ns = math.max(0.6, math.min(2, (self:GetScale() or 1) + d * 0.1))
        self:SetScale(ns); RX.db.timerScale = ns
    end)

    local acc = 0
    f:SetScript("OnUpdate", function(_, e)
        if TM.running then TM.elapsed = TM.elapsed + e end
        acc = acc + e
        if acc >= 1 then acc = 0; TM:Render() end
    end)
    f:Hide()
    self.frame = f
    self:Layout()
end

-- larguras dos textos acompanham a janela; altura = soma do conteúdo (nunca corta nada)
function TM:Layout()
    local f = self.frame
    if not f then return end
    local w = f:GetWidth() - PAD * 2
    f.title:SetWidth(w - 20)
    f.name:SetWidth(math.min(w - 8, 260))
    for _, fs in ipairs({ f.big, f.stats, f.gold, f.hist }) do fs:SetWidth(w) end
    local h = 10 + f.title:GetStringHeight() + 6 + 20 + 8 + f.big:GetStringHeight() + 6 + f.stats:GetStringHeight()
        + 8 + f.gold:GetStringHeight() + 10 + 22 + 10 + f.hist:GetStringHeight() + 18
    f:SetHeight(math.floor(h + 0.5))
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
    if self.running then
        self.lastMoney = GetMoney and GetMoney() or nil
        if (self.frame.name:GetText() or "") == "" then self.frame.name:SetText(self:DefaultName()) end
    end
    self:Render()
end

function TM:Reset()
    self.running, self.elapsed, self.xp, self.kills = false, 0, 0, 0
    self.coins, self.items, self.itemsAH, self.nItems = 0, 0, 0, 0
    self.frame.name:SetText("")
    self:Render()
end

function TM:Gold() return self.coins + self.items end

function TM:Save()
    if self.elapsed < 30 then RX:Print(T("Meça pelo menos 30 segundos antes de salvar.", "Measure at least 30 seconds before saving.")) return end
    RX.db.timerHistory = RX.db.timerHistory or {}
    table.insert(RX.db.timerHistory, 1, { name = self.frame.name:GetText() ~= "" and self.frame.name:GetText() or self:DefaultName(),
        secs = math.floor(self.elapsed), xp = self.xp, kills = self.kills, gold = self:Gold(), level = UnitLevel("player"), when = date and date("%d/%m %H:%M") or "" })
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

----------------------------------------------------------------------
-- Ouro: moedas dos mobs + valor dos itens saqueados
----------------------------------------------------------------------
-- padrão de mensagem do jogo ("Você saqueou: %s" / "%sx%d") -> padrão Lua que captura o link e a quantidade
local function lootPattern(fmt)
    if not fmt then return nil end
    local p = fmt:gsub("%%%d%$s", "\1"):gsub("%%%d%$d", "\2"):gsub("%%s", "\1"):gsub("%%d", "\2")
    p = p:gsub("([%(%)%.%+%-%*%?%[%]%^%$%%])", "%%%1")
    return "^" .. p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)") .. "$"
end

function TM:ItemValue(link, count)
    if not GetItemInfo then return nil end
    local _, _, quality, _, _, _, _, _, _, _, sell = GetItemInfo(link)
    if sell == nil then return nil end
    local id = tonumber(link:match("item:(%d+)"))
    local ah = RX.Market and RX.Market.Price and id and quality and quality >= 1 and RX.Market:Price(id)
    return (sell or 0) * count, ah and ah * count or nil
end

function TM:AddItem(link, count, tries)
    local v, ah = self:ItemValue(link, count)
    if v == nil then
        -- item ainda não está no cache do jogo: tenta de novo daqui a pouco
        if (tries or 0) < 5 and C_Timer and C_Timer.After then C_Timer.After(1, function() TM:AddItem(link, count, (tries or 0) + 1) end) end
        return
    end
    self.items = self.items + v
    self.itemsAH = self.itemsAH + (ah or v)
    self.nItems = self.nItems + count
end

function TM:OnLoot(msg)
    if not self.running or not msg then return end
    if not self.lootPats then
        self.lootPats = { lootPattern(LOOT_ITEM_SELF_MULTIPLE), lootPattern(LOOT_ITEM_SELF) }
    end
    for _, p in ipairs(self.lootPats) do
        local link, n = msg:match(p)
        if link and link:find("|Hitem:") then self:AddItem(link, tonumber(n) or 1) return end
    end
end

function TM:OnMoney()
    local now = GetMoney and GetMoney() or 0
    local last = self.lastMoney
    self.lastMoney = now
    if not self.running or not last then return end
    local d = now - last
    if d <= 0 then return end
    -- só conta dinheiro de saque (janela de loot aberta ou mensagem "sua parte do saque"), não venda nem recompensa de quest
    local t = GetTime and GetTime() or 0
    if self.lootOpen or (self.moneyMsgAt and t - self.moneyMsgAt < 2) or (self.lootClosedAt and t - self.lootClosedAt < 0.5) then
        self.coins = self.coins + d
    end
end

local ev = CreateFrame("Frame")
for _, e in ipairs({ "PLAYER_MONEY", "CHAT_MSG_MONEY", "CHAT_MSG_LOOT", "LOOT_OPENED", "LOOT_CLOSED", "PLAYER_ENTERING_WORLD" }) do pcall(ev.RegisterEvent, ev, e) end
ev:SetScript("OnEvent", function(_, e, msg)
    if e == "PLAYER_MONEY" then TM:OnMoney()
    elseif e == "CHAT_MSG_MONEY" then TM.moneyMsgAt = GetTime and GetTime() or 0
    elseif e == "CHAT_MSG_LOOT" then pcall(TM.OnLoot, TM, msg)
    elseif e == "LOOT_OPENED" then TM.lootOpen = true
    elseif e == "LOOT_CLOSED" then TM.lootOpen = false; TM.lootClosedAt = GetTime and GetTime() or 0
    elseif e == "PLAYER_ENTERING_WORLD" then TM.lastMoney = GetMoney and GetMoney() or nil end
end)

function TM:Render()
    local f = self.frame
    if not f or not f:IsShown() then return end
    f.title:SetText("|cff4fc3ff" .. T("Cronômetro de farm (XP e ouro)", "Farm timer (XP and gold)") .. "|r" .. (self.running and ("  |cff40ff40" .. T("gravando", "recording") .. "|r") or ("  |cffaaaaaa" .. T("pausado", "paused") .. "|r")))
    f.big:SetText(fmtTime(self.elapsed))
    local hours = self.elapsed / 3600
    local perH = hours > 0 and self.xp / hours or 0
    local left = UnitXPMax("player") - UnitXP("player")
    local eta = perH > 0 and (left / perH * 60) or nil
    f.stats:SetText(string.format(T("XP ganho: |cff40ff40%s|r   Mortes: %d\nXP/hora: |cffffd100%s|r%s\nXP por morte: %s",
        "XP gained: |cff40ff40%s|r   Kills: %d\nXP/hour: |cffffd100%s|r%s\nXP per kill: %s"),
        fmtXP(self.xp), self.kills, fmtXP(perH),
        eta and string.format(T("\nPróximo nível em ~%.0f min", "\nNext level in ~%.0f min"), eta) or "",
        self.kills > 0 and fmtXP(self.xp / self.kills) or "-"))
    local gold = self:Gold()
    local gl = {
        T("Moedas dos mobs: ", "Coins from mobs: ") .. fmtMoney(self.coins),
        string.format(T("Itens saqueados (%d): ", "Looted items (%d): "), self.nItems) .. fmtMoney(self.items) .. T(" no vendedor", " at the vendor"),
    }
    if self.itemsAH > self.items then gl[#gl + 1] = T("   no leilão: ~", "   at the AH: ~") .. fmtMoney(self.itemsAH) end
    gl[#gl + 1] = T("Total: ", "Total: ") .. fmtMoney(gold) .. "   |cffffd100" .. T("Ouro/hora: ", "Gold/hour: ") .. "|r" .. fmtMoney(hours > 0 and gold / hours or 0)
    if self.kills > 0 then gl[#gl + 1] = T("Por morte: ", "Per kill: ") .. fmtMoney(gold / self.kills) end
    f.gold:SetText(table.concat(gl, "\n"))
    f.start:SetText(self.running and T("Pausar", "Pause") or (self.elapsed > 0 and T("Continuar", "Resume") or T("Iniciar", "Start")))
    f.reset:SetText(T("Zerar", "Reset"))
    f.save:SetText(T("Salvar", "Save"))
    local lines = { "|cffff7f00" .. T("Histórico (compare spots e masmorras):", "History (compare spots and dungeons):") .. "|r" }
    for i, h in ipairs(RX.db.timerHistory or {}) do
        if i > 6 then break end
        local hh = h.secs > 0 and h.secs / 3600 or 0
        local ph = hh > 0 and h.xp / hh or 0
        local gh = (hh > 0 and h.gold) and (h.gold / hh) or nil
        table.insert(lines, string.format("%s  |cffffd100%s xp/h|r%s  (%s, %s xp, %s %d)", h.name or "?", fmtXP(ph),
            gh and ("  " .. fmtMoney(gh) .. "/h") or "", fmtTime(h.secs), fmtXP(h.xp), T("nv", "lv"), h.level or 0))
    end
    if #lines == 1 then table.insert(lines, T("  (vazio - clique em Salvar depois de medir)", "  (empty - click Save after measuring)")) end
    f.hist:SetText(table.concat(lines, "\n"))
    self:Layout()
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
