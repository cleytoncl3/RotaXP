-- Janela "Itens da quest": botões para usar os itens que as quests dão (usar num mob, num objeto ou num local).
-- Os botões são seguros do jogo (SecureActionButtonTemplate), então clicar realmente usa o item.
-- Regras do jogo: em combate os botões não podem ser trocados/mostrados/escondidos; a lista é atualizada fora de combate.
local _, RX = ...
local QI = { buttons = {}, byQuest = {}, list = {} }
RX.QuestItems = QI
local T = RX.T
local MAX, SIZE, GAP = 6, 34, 5

BINDING_HEADER_ROTAXP = "RouteXP"
_G["BINDING_NAME_CLICK RotaXPQuestItem1:LeftButton"] = "Usar o item da quest atual / Use current quest item"

local function inCombat() return InCombatLockdown and InCombatLockdown() end

local function logIndex(q)
    if C_QuestLog and C_QuestLog.GetLogIndexForQuestID then return C_QuestLog.GetLogIndexForQuestID(q) end
    if GetQuestLogIndexByID then return GetQuestLogIndexByID(q) end
end

local function itemCount(id) return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0 end
local function itemIcon(id) return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or (GetItemIcon and GetItemIcon(id)) or 134400 end
local function itemName(id) return (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and (GetItemInfo(id))) end

-- item "especial" que o próprio jogo associa à quest (o mesmo do botão do rastreador da Blizzard)
function QI:SpecialItem(q)
    local idx = logIndex(q)
    if not idx or idx <= 0 or not GetQuestLogSpecialItemInfo then return nil end
    local link, _, _, showWhenComplete = GetQuestLogSpecialItemInfo(idx)
    local id = link and tonumber(link:match("item:(%d+)"))
    if not id then return nil end
    if RX.Q:IsReady(q) and not showWhenComplete then return nil end
    return id
end

-- itens de quest usáveis na bolsa (classe 12 = Quest e com efeito de "Usar:")
local function bagQuestItems()
    local out = {}
    local getInfo = C_Container and C_Container.GetContainerItemInfo
    local numSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots
    if not (getInfo and numSlots) then return out end
    for bag = 0, 4 do
        for slot = 1, (numSlots(bag) or 0) do
            local info = getInfo(bag, slot)
            local id = info and info.itemID
            if id and GetItemInfoInstant then
                local _, _, _, _, _, classID = GetItemInfoInstant(id)
                if classID == 12 and GetItemSpell and GetItemSpell(id) then out[#out + 1] = id end
            end
        end
    end
    return out
end

-- monta a lista: primeiro os itens das quests dos próximos passos do guia, depois o resto do log, depois a bolsa
function QI:Collect()
    local list, seen, byQuest = {}, {}, {}
    local order, qseen = {}, {}
    local ok, steps = pcall(RX.VisibleSteps, RX, 40)
    if ok and steps then for _, s in ipairs(steps) do if s.q and not qseen[s.q] and RX.Q:InLog(s.q) then qseen[s.q] = true; order[#order + 1] = s.q end end end
    for q in pairs(RX.Q.log or {}) do if not qseen[q] then qseen[q] = true; order[#order + 1] = q end end
    for _, q in ipairs(order) do
        local id = self:SpecialItem(q)
        if id and itemCount(id) > 0 then
            byQuest[q] = id
            if not seen[id] then seen[id] = true; list[#list + 1] = { id = id, q = q } end
        end
    end
    -- itens que COMEÇAM uma quest do guia (ex.: um relatório que caiu de um mob)
    for q, id in pairs(RX.QuestStart or {}) do
        if id > 0 and not seen[id] and itemCount(id) > 0 and not RX.Q:InLog(q) and not RX.Q:IsCompleted(q) then
            seen[id] = true; list[#list + 1] = { id = id, q = q, starts = true }
        end
    end
    for _, id in ipairs(bagQuestItems()) do
        if not seen[id] then seen[id] = true; list[#list + 1] = { id = id } end
    end
    self.byQuest = byQuest
    return list
end

-- item da quest (para a dica na lista do guia)
function QI:ItemFor(q)
    if not q then return nil end
    local id = self.byQuest[q]
    if id == nil and RX.Q:InLog(q) then
        id = self:SpecialItem(q)
        if id and itemCount(id) <= 0 then id = nil end
    end
    return id
end

----------------------------------------------------------------------
-- janela
----------------------------------------------------------------------
function QI:Create()
    if self.frame then return end
    local f = CreateFrame("Frame", "RotaXPQuestItemsFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(SIZE + 16, 60)
    f:SetFrameStrata("MEDIUM")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(fr) if not inCombat() then fr:StartMoving() end end)
    f:SetScript("OnDragStop", function(fr)
        fr:StopMovingOrSizing()
        local p, _, rp, x, y = fr:GetPoint()
        RX.db.questItemsPos = { p, rp, x, y }
    end)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.05, 0.05, 0.07, 0.85)
        f:SetBackdropBorderColor(1, 0.5, 0, 0.9)
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -6)
    title:SetTextColor(1, 0.6, 0.15)
    title:SetText(T("Itens da quest", "Quest items"))
    f.title = title
    local p = RX.db.questItemsPos
    if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER", UIParent, "CENTER", 260, -140) end
    f:Hide()
    self.frame = f

    for i = 1, MAX do
        local b = CreateFrame("Button", "RotaXPQuestItem" .. i, f, "SecureActionButtonTemplate")
        b:SetSize(SIZE, SIZE)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", 8 + (i - 1) * (SIZE + GAP), -22)
        b:RegisterForClicks("AnyUp")
        b:SetAttribute("type", "item")
        local icon = b:CreateTexture(nil, "ARTWORK"); icon:SetAllPoints(); b.icon = icon
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.2)
        local count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal"); count:SetPoint("BOTTOMRIGHT", -2, 2); b.count = count
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); cd:SetAllPoints(); b.cd = cd
        local glow = b:CreateTexture(nil, "OVERLAY")
        glow:SetPoint("TOPLEFT", -3, 3); glow:SetPoint("BOTTOMRIGHT", 3, -3)
        glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border"); glow:SetBlendMode("ADD"); glow:SetVertexColor(1, 0.6, 0.1)
        glow:SetTexCoord(0.2, 0.8, 0.2, 0.8)
        glow:Hide(); b.glow = glow
        b:SetScript("OnEnter", function(btn)
            if not btn.itemID then return end
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(btn.itemID) else GameTooltip:SetHyperlink("item:" .. btn.itemID) end
            if btn.questID then
                local s = { q = btn.questID, n = RX.Q:Title(btn.questID) or "" }
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(T("Quest: ", "Quest: ") .. (RX:QName(s) or s.n), 1, 0.82, 0)
            end
            GameTooltip:AddLine(T("Clique para usar (no alvo/local certo).", "Click to use (on the right target/spot)."), 0.5, 0.8, 1)
            if i == 1 then
                local key = GetBindingKey and GetBindingKey("CLICK RotaXPQuestItem1:LeftButton")
                GameTooltip:AddLine(key and (T("Atalho: ", "Hotkey: ") .. key) or T("Dá para pôr uma tecla em Opções > Atalhos > AddOns > RouteXP.", "You can bind a key in Options > Keybindings > AddOns > RouteXP."), 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:Hide()
        self.buttons[i] = b
    end
end

-- contagem e recarga podem ser atualizadas a qualquer momento (não são protegidas)
function QI:UpdateCounts()
    for _, b in ipairs(self.buttons) do
        if b.itemID then
            local n = itemCount(b.itemID)
            b.count:SetText(n > 1 and n or "")
            local start, dur, en
            if C_Container and C_Container.GetItemCooldown then start, dur, en = C_Container.GetItemCooldown(b.itemID)
            elseif GetItemCooldown then start, dur, en = GetItemCooldown(b.itemID) end
            if start and dur and dur > 0 and en ~= 0 then b.cd:SetCooldown(start, dur) else b.cd:Clear() end
        end
    end
end

-- quest do passo atual do guia (para destacar o item dela)
local function currentQuest()
    local ok, steps = pcall(RX.VisibleSteps, RX, 5)
    if not ok or not steps then return nil end
    for _, s in ipairs(steps) do if s.q and s.t == "C" then return s.q end end
    return nil
end

function QI:Refresh()
    if not self.frame then return end
    if inCombat() then self.pending = true; return end
    self.pending = nil
    local list = (RX.db.questItems ~= false) and self:Collect() or {}
    self.list = list
    -- o item da quest atual vai para o 1º botão (o da tecla de atalho)
    local cq = currentQuest()
    if cq then
        for i, it in ipairs(list) do if it.q == cq and i > 1 then table.insert(list, 1, table.remove(list, i)) break end end
    end
    local n = math.min(#list, MAX)
    for i, b in ipairs(self.buttons) do
        local it = list[i]
        if it then
            b.itemID, b.questID = it.id, it.q
            b:SetAttribute("type", "item")
            b:SetAttribute("item", "item:" .. it.id)
            b.icon:SetTexture(itemIcon(it.id))
            if it.q and it.q == cq then b.glow:Show() else b.glow:Hide() end
            b:Show()
        else
            b.itemID, b.questID = nil, nil
            b:SetAttribute("item", nil)
            b:Hide()
        end
    end
    if n > 0 then
        self.frame:SetWidth(math.max(16 + n * SIZE + (n - 1) * GAP, 110))
        self.frame:SetHeight(SIZE + 30)
        self.frame:Show()
        self:UpdateCounts()
    else
        self.frame:Hide()
    end
end

function QI:Toggle()
    RX.db.questItems = RX.db.questItems == false
    RX:Print(RX.db.questItems and T("Janela de itens da quest ligada.", "Quest item window on.") or T("Janela de itens da quest desligada.", "Quest item window off."))
    self:Refresh()
end

----------------------------------------------------------------------
-- eventos
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        QI:Create()
        for _, e in ipairs({ "BAG_UPDATE_DELAYED", "QUEST_LOG_UPDATE", "PLAYER_REGEN_ENABLED", "BAG_UPDATE_COOLDOWN", "QUEST_ACCEPTED", "QUEST_REMOVED" }) do
            pcall(ev.RegisterEvent, ev, e)
        end
        QI:Refresh()
        -- trocar de passo no guia também pode mudar o item em destaque
        local origUpdate = RX.Update
        RX.Update = function(self, ...)
            local r = origUpdate(self, ...)
            if not QI.queued and C_Timer then
                QI.queued = true
                C_Timer.After(0.3, function() QI.queued = nil; QI:Refresh() end)
            end
            return r
        end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        QI:UpdateCounts()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if QI.pending then QI:Refresh() end
    else
        if not QI.queued and C_Timer then
            QI.queued = true
            C_Timer.After(0.3, function() QI.queued = nil; QI:Refresh() end)
        end
    end
end)
