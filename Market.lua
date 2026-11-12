-- Leilão: para quests que pedem itens (drop de mob, etc.), mostra o preço que o Auctionator viu no leilão e,
-- quando você abre a Casa de Leilões, oferece buscar de uma vez tudo o que falta para as quests do seu log.
-- Preço vem do banco do Auctionator (última varredura). Itens de quest (vinculados) não aparecem no leilão.
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

-- linha de dica: "Leilão: Pena ~12s cada · faltam 4 = 48s"
function MK:Hint(q)
    if not api() then return nil end
    local miss = self:Missing(q)
    if not miss or #miss == 0 then return nil end
    local parts, total, any = {}, 0, false
    for _, m in ipairs(miss) do
        local p, age = self:Price(m.id)
        if p then
            any = true
            total = total + p * m.left
            parts[#parts + 1] = string.format(T("%s %s cada · faltam %d%s", "%s %s each · %d left%s"), itemName(m.id) or ("item " .. m.id), money(p), m.left,
                (age and age > 3) and string.format(T(" (preço de %d dias)", " (%d days old)"), age) or "")
        end
    end
    if not any then return nil end
    return string.format(T("Leilão: %s = %s. Mais rápido que farmar: compre na Casa de Leilões.", "AH: %s = %s. Faster than farming: buy it at the Auction House."),
        table.concat(parts, "; "), money(total))
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

function MK:Offer()
    if RX.db.marketOffer == false then return end
    local list, total = self:ShoppingList()
    if #list == 0 then return end
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

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        pcall(ev.RegisterEvent, ev, "AUCTION_HOUSE_SHOW")
    elseif event == "AUCTION_HOUSE_SHOW" then
        -- espera o Auctionator montar a aba dele
        if C_Timer then C_Timer.After(1.5, function() MK:Offer() end) else MK:Offer() end
    end
end)
