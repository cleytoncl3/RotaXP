-- Leilão: para quests que pedem itens (drop de mob, etc.), mostra o preço que o Auctionator viu no leilão e,
-- quando você abre a Casa de Leilões, oferece buscar de uma vez tudo o que falta para as quests do seu log.
-- Preço vem do banco do Auctionator (última varredura). Itens vinculados (de quest) não podem ser vendidos e ficam de fora.
-- Ao escolher um guia, abre a lista de compras do guia (/rota compras).
local _, RX = ...
local MK = {}
RX.Market = MK
local T = RX.T
local CALLER = "RotaXP"

local function api() return Auctionator and Auctionator.API and Auctionator.API.v1 end

function MK:Price(id)
    local a = api()
    if not (a and a.GetAuctionPriceByItemID) then return nil end
    local ok, p = pcall(a.GetAuctionPriceByItemID, CALLER, id)
    if ok and type(p) == "number" and p > 0 then
        local age
        if a.GetAuctionAgeByItemID then local ok2, d = pcall(a.GetAuctionAgeByItemID, CALLER, id); if ok2 then age = d end end
        return p, age
    end
    return nil
end

local function money(c)
    if GetCoinTextureString then return GetCoinTextureString(math.floor(c)) end
    local g, s, cp = math.floor(c / 10000), math.floor(c / 100) % 100, math.floor(c) % 100
    if g > 0 then return s > 0 and string.format("%dg %ds", g, s) or (g .. "g") end
    if s > 0 then return cp > 0 and string.format("%ds %dc", s, cp) or (s .. "s") end
    return cp .. "c"
end
MK.Money = money

local function itemName(id)
    local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and (GetItemInfo(id)))
    if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return n
end
local function count(id) return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0 end

-- o que falta de cada item da quest (pelo progresso do jogo quando a quest está no log)
function MK:Missing(q)
    local need = RX.QuestNeeds and RX.QuestNeeds[q]
    if not need then return nil end
    local objs = RX.Q:InLog(q) and RX.Q:Objectives(q) or nil
    local itemObjs = {}
    if objs then for _, o in ipairs(objs) do if o.type == "item" then itemObjs[#itemObjs + 1] = o end end end
    local out = {}
    for i, n in ipairs(need) do
        local id, total = n[1], n[2]
        local have = itemObjs[i] and itemObjs[i].numFulfilled or count(id)
        local req = itemObjs[i] and itemObjs[i].numRequired or total
        local left = math.max(0, req - have)
        if left > 0 then out[#out + 1] = { id = id, left = left, req = req } end
    end
    return out
end

-- o item pode ser vendido no leilão? (vinculado ao pegar / item de quest = não). nil = ainda carregando
function MK:Tradeable(id)
    local bind
    if C_Item and C_Item.GetItemInfo then bind = select(14, C_Item.GetItemInfo(id)) end
    if bind == nil and GetItemInfo then bind = select(14, GetItemInfo(id)) end
    if bind == nil then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
        return nil
    end
    return bind ~= 1 and bind ~= 4
end

-- segunda via: "Ou compre no leilão: 4x Pena (12s cada = 50s)" para os itens que podem ser negociados
function MK:Hint(q)
    local miss = self:Missing(q)
    if not miss or #miss == 0 then return nil end
    local parts, total, priced = {}, 0, true
    for _, m in ipairs(miss) do
        if self:Tradeable(m.id) then
            local p, age = self:Price(m.id)
            local name = itemName(m.id) or ("item " .. m.id)
            if p then
                total = total + p * m.left
                parts[#parts + 1] = string.format(T("%dx %s (%s cada%s)", "%dx %s (%s each%s)"), m.left, name, money(p),
                    (age and age > 3) and string.format(T(", preço de %d dias", ", %d days old"), age) or "")
            else
                priced = false
                parts[#parts + 1] = string.format("%dx %s", m.left, name)
            end
        end
    end
    if #parts == 0 then return nil end
    local tail
    if total > 0 then tail = string.format(T(" = %s", " = %s"), money(total)) else tail = "" end
    if not priced then
        tail = tail .. (api() and T(" (sem preço no Auctionator: faça uma varredura)", " (no Auctionator price: run a scan)")
            or T(" (instale o Auctionator para ver o preço)", " (install Auctionator to see the price)"))
    end
    return string.format(T("Segunda via: compre no leilão em vez de dropar: %s%s", "Alternative: buy it on the AH instead of farming: %s%s"), table.concat(parts, "; "), tail)
end

-- tudo o que falta para as quests do log e tem preço no leilão
function MK:ShoppingList()
    local list, total, seen = {}, 0, {}
    for q in pairs(RX.Q.log or {}) do
        if not RX.Q:IsReady(q) then
            for _, m in ipairs(self:Missing(q) or {}) do
                local p = self:Price(m.id)
                local name = itemName(m.id)
                if p and name and not seen[m.id] then
                    seen[m.id] = true
                    list[#list + 1] = { id = m.id, name = name, left = m.left, price = p, q = q }
                    total = total + p * m.left
                end
            end
        end
    end
    return list, total
end

function MK:Search(list)
    local a = api()
    if not (a and a.MultiSearchExact) then RX:Print(T("Precisa do addon Auctionator para buscar.", "Needs the Auctionator addon to search.")) return end
    local terms = {}
    for _, it in ipairs(list) do terms[#terms + 1] = it.name end
    if #terms == 0 then return end
    local ok, err = pcall(a.MultiSearchExact, CALLER, terms)
    if not ok then RX:Print(T("Abra a Casa de Leilões (aba do Auctionator) e tente de novo.", "Open the Auction House (Auctionator tab) and try again.")) end
end

function MK:Offer(force)
    if not force and RX.db.marketOffer == false then return end
    local list, total = self:ShoppingList()
    if #list == 0 then
        if force then RX:Print(T("Nada à venda para as quests do seu log (ou sem preço no Auctionator).", "Nothing on sale for your log quests (or no Auctionator price).")) end
        return
    end
    local lines = {}
    for i, it in ipairs(list) do
        if i <= 8 then lines[#lines + 1] = string.format("%dx %s (%s)", it.left, it.name, money(it.price)) end
    end
    local text = string.format(T("|cffff7f00RotaXP|r\nItens das suas quests à venda (~%s no total):\n\n%s\n\nBuscar no Auctionator?", "|cffff7f00RotaXP|r\nItems for your quests on sale (~%s total):\n\n%s\n\nSearch them in Auctionator?"),
        money(total), table.concat(lines, "\n"))
    self.pending = list
    if StaticPopup_Show then StaticPopup_Show("ROTAXP_MARKET", text) end
end

if StaticPopupDialogs then
    StaticPopupDialogs["ROTAXP_MARKET"] = {
        text = "%s", button1 = YES or "Sim", button2 = NO or "Não", timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function() if MK.pending then MK:Search(MK.pending) end end,
    }
end

----------------------------------------------------------------------
-- Lista de compras do guia: ao escolher um guia, abre uma janela com todos os itens que as quests
-- dele pedem e que podem ser comprados no leilão (nome, quantidade, preço). Reabrir: /rota compras
----------------------------------------------------------------------
function MK:GuideList(g)
    g = g or RX:CurrentGuide()
    if not g then return {}, 0, 0 end
    local blocked = RX:BuildQuestFilter(g)
    local byItem, order, seenQ, loading = {}, {}, {}, 0
    for _, s in ipairs(g.steps or {}) do
        local q = s.q
        if q and not seenQ[q] and (s.t == "A" or s.t == "C") and not RX.Q:IsCompleted(q) and not RX:IsStepHidden(s, blocked)
            and not (RX.Q:InLog(q) and RX.Q:IsReady(q)) then
            seenQ[q] = true
            for _, m in ipairs(self:Missing(q) or {}) do
                local tr = self:Tradeable(m.id)
                if tr == nil then loading = loading + 1
                elseif tr then
                    local e = byItem[m.id]
                    if not e then e = { id = m.id, left = 0, quests = {} }; byItem[m.id] = e; order[#order + 1] = e end
                    e.left = e.left + m.left
                    e.quests[#e.quests + 1] = RX:QName(s) or s.n
                end
            end
        end
    end
    local total = 0
    for _, e in ipairs(order) do
        e.name = itemName(e.id) or ("item " .. e.id)
        e.price = self:Price(e.id)
        if e.price then total = total + e.price * e.left end
    end
    table.sort(order, function(a, b)
        local va, vb = (a.price or 0) * a.left, (b.price or 0) * b.left
        if va ~= vb then return va > vb end
        return a.id < b.id
    end)
    return order, total, loading
end

local ROWS = 14
function MK:CreateWindow()
    if self.win then return self.win end
    local f = CreateFrame("Frame", "RotaXPShoppingFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(380, 90)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(fr) fr:StartMoving() end)
    f:SetScript("OnDragStop", function(fr)
        fr:StopMovingOrSizing()
        local p, _, rp, x, y = fr:GetPoint()
        RX.db.shopPos = { p, rp, x, y }
    end)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.05, 0.05, 0.07, 0.92)
        f:SetBackdropBorderColor(1, 0.5, 0, 0.9)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -8)
    f.title:SetPoint("RIGHT", -28, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetTextColor(1, 0.6, 0.15)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 0, 0)
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.sub:SetPoint("TOPLEFT", 10, -26)
    f.sub:SetPoint("RIGHT", -10, 0)
    f.sub:SetJustifyH("LEFT")
    f.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Frame", nil, f)
        r:SetSize(360, 16)
        r:SetPoint("TOPLEFT", 10, -44 - (i - 1) * 17)
        r:EnableMouse(true)
        r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(14, 14); r.icon:SetPoint("LEFT")
        r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0); r.text:SetJustifyH("LEFT"); r.text:SetWidth(240)
        r.price = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.price:SetPoint("RIGHT"); r.price:SetJustifyH("RIGHT")
        r:SetScript("OnEnter", function(row)
            if not row.e or not GameTooltip then return end
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if GameTooltip.SetItemByID then GameTooltip:SetItemByID(row.e.id) else GameTooltip:AddLine(row.e.name) end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("Para: ", "For: ") .. table.concat(row.e.quests, ", "), 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        f.rows[i] = r
    end
    f.foot = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.foot:SetJustifyH("LEFT")
    f.btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.btn:SetSize(150, 20)
    f.btn:SetText(T("Buscar no Auctionator", "Search in Auctionator"))
    f.btn:SetScript("OnClick", function() MK:Search(MK.winList or {}) end)
    local p = RX.db.shopPos
    if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER", UIParent, "CENTER", -250, 120) end
    f:Hide()
    self.win = f
    return f
end

function MK:RefreshWindow()
    local f = self.win
    if not f or not f:IsShown() then return end
    local g = RX:CurrentGuide()
    local list, total, loading = self:GuideList(g)
    self.winList = list
    f.title:SetText(T("Comprar no leilão: ", "Buy on the AH: ") .. (g and RX:GuideName(g) or ""))
    f.sub:SetText(#list > 0 and T("Itens das quests deste guia que dá para comprar em vez de dropar:", "Quest items for this guide you can buy instead of farming:")
        or (loading > 0 and T("Carregando itens...", "Loading items...") or T("Nenhum item deste guia pode ser comprado no leilão.", "No item for this guide can be bought on the AH.")))
    local shown = math.min(#list, ROWS)
    for i, r in ipairs(f.rows) do
        local e = list[i]
        r.e = e
        if e then
            r.icon:SetTexture((C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(e.id)) or (GetItemIcon and GetItemIcon(e.id)) or 134400)
            r.text:SetText(string.format("|cffffffff%dx|r %s", e.left, e.name))
            r.price:SetText(e.price and money(e.price * e.left) or ("|cff888888" .. T("sem preço", "no price") .. "|r"))
            r:Show()
        else r:Hide() end
    end
    local y = -44 - shown * 17 - 6
    f.foot:ClearAllPoints(); f.foot:SetPoint("TOPLEFT", 10, y)
    local foot = total > 0 and string.format(T("Total com preço: %s", "Total with price: %s"), money(total)) or ""
    if #list > ROWS then foot = foot .. string.format(T("  (+%d itens)", "  (+%d items)"), #list - ROWS) end
    if not api() then foot = T("Instale o Auctionator para ver preços e buscar.", "Install Auctionator to see prices and search.") end
    f.foot:SetText(foot)
    f.btn:ClearAllPoints(); f.btn:SetPoint("TOPRIGHT", -10, y + 4)
    if #list > 0 and api() then f.btn:Show() else f.btn:Hide() end
    f:SetHeight(-y + 30)
end

-- abre a janela; auto = true só abre se houver algo para comprar
function MK:ShowWindow(auto)
    if auto and RX.db.shopWindow == false then return end
    local list = self:GuideList()
    if auto and #list == 0 then return end
    self:CreateWindow():Show()
    self:RefreshWindow()
end

function MK:ToggleWindow()
    if self.win and self.win:IsShown() then self.win:Hide() else self:ShowWindow(false) end
end

-- ao trocar de guia (não no login), mostra a lista de compras dele
local loginAt
local origSetGuide = RX.SetGuide
function RX:SetGuide(id, ...)
    local before = self:CharState().guide
    local r = origSetGuide(self, id, ...)
    if self.guides[id] and id ~= before and loginAt and GetTime and GetTime() - loginAt > 5 then
        if C_Timer then C_Timer.After(1, function() MK:ShowWindow(true) end) else MK:ShowWindow(true) end
    elseif MK.win and MK.win:IsShown() then MK:RefreshWindow() end
    return r
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        loginAt = GetTime and GetTime() or 0
        pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
        pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        -- item carregou: atualiza a janela (no máximo a cada meio segundo)
        if MK.win and MK.win:IsShown() and not MK.refreshing then
            MK.refreshing = true
            local function go() MK.refreshing = nil; MK:RefreshWindow() end
            if C_Timer then C_Timer.After(0.5, go) else go() end
        end
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- espera o Auctionator montar a aba dele
        if C_Timer then C_Timer.After(1.5, function() MK:Offer() end) else MK:Offer() end
    end
end)
