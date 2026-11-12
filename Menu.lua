-- Menu de guias em cascata (abre para o lado, como o RestedXP):
-- Nível 1: zona atual, faixas de nível, rota, estilo, modos
-- Nível 2: guias da faixa (ordenados pelo XP)
-- Nível 3: variantes do guia (Speedrun, coleta até 5, sem coleta, duo, completo) com o XP de cada uma, do maior para o menor
local _, RX = ...
local UI = RX.UI
local T, LF = RX.T, RX.LF
local M = { levels = {} }
UI.Cascade = M

local WIDTH = 310
local ORANGE = "|cffff7f00"

local function fmtXP(x)
    if x >= 1000 then return string.format("%.0fk", x / 1000) end
    return tostring(math.floor(x))
end

local function backdrop(f, alpha)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, alpha or 0.97)
    f:SetBackdropBorderColor(1, 0.5, 0, 0.9)
end

----------------------------------------------------------------------
-- Estrutura dos níveis
----------------------------------------------------------------------
function M:Level(n)
    local f = self.levels[n]
    if f then return f end
    local name = "RotaXPCascade" .. n
    f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate")
    backdrop(f)
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(20 + n * 5)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetWidth(WIDTH)
    f.rows = {}
    if n == 1 then
        UI:MakeDraggable(f)
        tinsert(UISpecialFrames, name)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOPLEFT", 10, -8)
        f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        f.hint:SetPoint("TOPRIGHT", -28, -10)
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() M:Close() end)
        f:SetScript("OnHide", function() M:Close(2) end)
    end
    f:Hide()
    self.levels[n] = f
    return f
end

function M:Close(from)
    for i = from or 1, #self.levels do self.levels[i]:Hide() end
end

function M:IsOpen()
    return self.levels[1] and self.levels[1]:IsShown()
end

function M:GetRow(f, i)
    local r = f.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, f)
    r:RegisterForClicks("LeftButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0.04)
    r.hl = r:CreateTexture(nil, "HIGHLIGHT")
    r.hl:SetAllPoints()
    r.hl:SetColorTexture(1, 0.5, 0, 0.18)
    r.text = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.text:SetPoint("TOPLEFT", 12, -8)
    -- barra de destaque à esquerda para o item selecionado
    r.mark = r:CreateTexture(nil, "ARTWORK")
    r.mark:SetPoint("TOPLEFT"); r.mark:SetPoint("BOTTOMLEFT"); r.mark:SetWidth(3)
    r.mark:SetColorTexture(0.3, 1, 0.3, 0.9)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(true)
    r.sub = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -3)
    r.sub:SetJustifyH("LEFT")
    r.sub:SetWordWrap(true)
    r.arrow = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.arrow:SetPoint("RIGHT", -6, 0)
    f.rows[i] = r
    UI.ForwardDrag(r, self.levels[1] or f)
    return r
end

-- items: { text, sub, xp, onClick, children = function() return items end, selected, header, tip, keep }
function M:Open(n, items, anchor, gen)
    local f = self:Level(n)
    f.gen, f.anchor = gen, anchor
    self:Close(n + 1)
    for _, r in ipairs(f.rows) do r:Hide() end
    local y = (n == 1) and -30 or -8
    local textW = WIDTH - 36
    for i, it in ipairs(items) do
        local r = self:GetRow(f, i)
        r.item = it
        r.text:SetWidth(textW)
        r.sub:SetWidth(textW)
        local txt = it.text or ""
        if it.xp then txt = txt .. "  |cff40ff40~" .. fmtXP(it.xp) .. " xp|r" end
        if it.selected and not it.noMark then txt = "|cff40ff40> |r" .. txt end
        if it.header then
            r.text:SetText("|cffffd100" .. txt .. "|r")
            r.text:SetFontObject("GameFontNormal")
        else
            r.text:SetText(txt)
            r.text:SetFontObject("GameFontNormalSmall")
        end
        r.sub:SetText(it.sub or "")
        r.arrow:SetText(it.children and ">" or "")
        local h = r.text:GetStringHeight() + 16
        if it.sub and it.sub ~= "" then h = h + r.sub:GetStringHeight() + 3 end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", f, "TOPLEFT", 6, y)
        r:SetSize(WIDTH - 12, h)
        if it.header then r.bg:Hide(); r.hl:Hide() else r.bg:Show(); r.hl:Show() end
        if it.selected then r.bg:SetColorTexture(0.2, 1, 0.2, 0.16); r.mark:Show() else r.bg:SetColorTexture(1, 1, 1, 0.04); r.mark:Hide() end
        r:SetScript("OnEnter", function(self)
            if self.item.itemID then
                GameTooltip:SetOwner(self, M.dir == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
                pcall(GameTooltip.SetItemByID, GameTooltip, self.item.itemID)
                GameTooltip:Show()
            elseif self.item.tip then
                GameTooltip:SetOwner(self, M.dir == "left" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
                GameTooltip:AddLine(self.item.tip, 1, 1, 1, true)
                GameTooltip:Show()
            end
            if self.item.children then
                local token = {}
                M.hoverToken = token
                C_Timer.After(0.12, function()
                    if M.hoverToken == token and self:IsShown() then M:Open(n + 1, self.item.children(), self, self.item.children) end
                end)
            elseif not self.item.header then
                M:Close(n + 1)
            end
        end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        r:SetScript("OnClick", function(self)
            local item = self.item
            if item.onClick then
                item.onClick()
                if item.keep then
                    -- continua aberto e redesenha este mesmo nível (marcar várias opções)
                    if n == 1 then M:Refresh() elseif f.gen then M:Open(n, f.gen(), f.anchor, f.gen) end
                else M:Close() end
            elseif item.children then
                M:Open(n + 1, item.children(), self, item.children)
            end
        end)
        r:Show()
        y = y - h - (it.header and 4 or 7)
    end
    f:SetHeight(-y + 8)
    if n == 1 then
        if not f:IsShown() then
            UI:PlaceBeside(f)
            local main = UI.frame
            local cx = main and main:GetCenter() or 0
            local scale = main and ((main:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)) or 1
            M.dir = (cx * scale > (UIParent:GetWidth() or 1920) / 2) and "left" or "right"
        end
        f.title:SetText(ORANGE .. T("Guias", "Guides") .. "|r")
        f.hint:SetText("|cff909090" .. T("passe o mouse ou clique em >", "hover or click >") .. "|r")
    else
        f:ClearAllPoints()
        if M.dir == "left" then f:SetPoint("TOPRIGHT", anchor, "TOPLEFT", -6, 6)
        else f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 6, 6) end
    end
    f:Show()
end

----------------------------------------------------------------------
-- Conteúdo
----------------------------------------------------------------------
local function styleName(id)
    for _, st in ipairs(RX.Styles) do if st.id == id then return LF(st, "name") end end
    return T("Personalizado", "Custom")
end

-- Variantes de um guia, do maior XP para o menor
function M:VariantItems(g)
    local list = {}
    local cur = RX:CurrentGuide()
    for _, st in ipairs(RX.Styles) do
        local xp, n = RX:GuideXPWith(g, st.set)
        table.insert(list, {
            text = LF(st, "name"), xp = xp,
            sub = string.format(T("%d quests · %s", "%d quests · %s"), n, LF(st, "desc")),
            selected = (cur == g and RX.db.style == st.id),
            onClick = function() RX:SetGuide(g.id); RX:ApplyStyle(st.id) end,
        })
    end
    table.sort(list, function(a, b) return a.xp > b.xp end)
    table.insert(list, 1, { header = true, text = RX:GuideName(g), sub = string.format(T("Níveis %d-%d · escolha a variante (ordenadas por XP)", "Levels %d-%d · pick the variant (sorted by XP)"), g.min, g.max) })
    return list
end

function M:GuideItems(lo, hi)
    local cur = RX:CurrentGuide()
    local inRoute = {}
    for i, id in ipairs(RX:CurrentRoute().guides) do inRoute[id] = i end
    local stSet
    for _, st in ipairs(RX.Styles) do if st.id == RX.db.style then stSet = st.set end end
    local list = {}
    for _, g in ipairs(RX:SortedGuides()) do
        if g.min < hi and g.max > lo then
            local xp, n = RX:GuideXPWith(g, stSet)
            local prog = RX:GuideProgress(g.id)
            local pct = #g.steps > 0 and math.min(100, (prog.index - 1) / #g.steps * 100) or 0
            local tags = ""
            if inRoute[g.id] then tags = tags .. " |cff40ff40" .. T("[na rota]", "[on route]") .. "|r" end
            if g.tag == "forever" then tags = tags .. " |cff40c0ff[Forever]|r" end
            if g.kind ~= "zona" then tags = tags .. " |cffaaaaaa" .. T("[curto]", "[short]") .. "|r" end
            table.insert(list, {
                text = RX:GuideName(g) .. tags, xp = xp,
                sub = string.format(T("Níveis %d-%d · %d quests%s", "Levels %d-%d · %d quests%s"), g.min, g.max, n,
                    pct > 0 and string.format(T(" · %.0f%% feito", " · %.0f%% done"), pct) or ""),
                selected = (cur == g),
                tip = LF(g, "desc"),
                onClick = function() RX:SetGuide(g.id) end,
                children = function() return M:VariantItems(g) end,
            })
        end
    end
    table.sort(list, function(a, b) return a.xp > b.xp end)
    table.insert(list, 1, { header = true, text = string.format(T("Nível %d-%d", "Level %d-%d"), lo, hi),
        sub = string.format(T("Ordenados pelo XP no estilo atual (%s)", "Sorted by XP with the current style (%s)"), styleName(RX.db.style)) })
    return list
end

function M:RouteItems()
    local list = { { header = true, text = T("Rota (sequência de zonas até o 60)", "Route (zone sequence up to 60)") } }
    for _, r in ipairs(RX.Routes) do
        table.insert(list, {
            text = LF(r, "name"), sub = "|cffaaaaaa" .. (LF(r, "source") or "") .. "|r", tip = LF(r, "desc"),
            selected = (r.id == RX.db.route), onClick = function() RX:SetRoute(r.id) end,
        })
    end
    return list
end

function M:StyleItems()
    local g = RX:CurrentGuide()
    local db = RX.db
    local list = { { header = true, text = T("Atalhos de estilo", "Style presets"),
        sub = g and (T("XP restante no guia atual: ", "Remaining XP in the current guide: ") .. RX:GuideName(g)) or nil } }
    local presets = {}
    for _, st in ipairs(RX.Styles) do
        local xp = g and RX:GuideXPWith(g, st.set) or nil
        table.insert(presets, { text = LF(st, "name"), xp = xp, sub = LF(st, "desc"), selected = (db.style == st.id), keep = true,
            onClick = function() RX:ApplyStyle(st.id) end })
    end
    table.sort(presets, function(a, b) return (a.xp or 0) > (b.xp or 0) end)
    for _, p in ipairs(presets) do table.insert(list, p) end

    -- ajuste fino: marque várias ao mesmo tempo (o menu fica aberto)
    local cur = {}
    for _, k in ipairs({ "speedrun", "showDungeon", "showElite", "groupMode", "collectMax", "skipCollect" }) do cur[k] = db[k] end
    local curXP = g and RX:GuideXPWith(g, cur) or nil
    table.insert(list, { header = true, text = T("Ajuste fino (marque várias)", "Fine-tune (tick several)"),
        sub = curXP and string.format(T("Com a sua combinação atual: ~%s xp neste guia", "With your current combination: ~%s xp in this guide"), curXP >= 1000 and string.format("%.0fk", curXP / 1000) or tostring(math.floor(curXP))) or nil })
    local function toggle(key, label, desc)
        table.insert(list, { text = (db[key] and "|cff40ff40[x]|r " or "|cff808080[  ]|r ") .. label, sub = desc, selected = db[key] and true or false, noMark = true, keep = true,
            onClick = function() db[key] = not db[key]; db.style = "custom"; RX:Update(true) end })
    end
    toggle("speedrun", T("Pular quests lentas", "Skip slow quests"), T("escoltas, entregas longe, pouco XP, cinzas", "escorts, far deliveries, low XP, grey"))
    toggle("showDungeon", T("Mostrar quests de masmorra", "Show dungeon quests"), nil)
    toggle("showElite", T("Mostrar quests de elite", "Show elite quests"), nil)
    toggle("groupMode", T("Duo / grupo", "Duo / group"), T("pula quests de 10+ itens de drop e mostra elites", "skips 10+ dropped-item quests and shows elites"))
    local lim = db.collectMax
    local function radio(v, label)
        local on = (v == false and not lim and not db.skipCollect) or (v ~= false and lim == v)
        table.insert(list, { text = (on and "|cff40ff40(o)|r " or "|cff808080( )|r ") .. label, selected = on, noMark = true, keep = true,
            onClick = function() db.collectMax = v; db.skipCollect = false; db.style = "custom"; RX:Update(true) end })
    end
    table.insert(list, { header = true, text = T("Quests de coletar itens de drop", "Quests collecting dropped items") })
    radio(false, T("Sem limite", "No limit"))
    radio(10, T("Até 10 itens", "Up to 10 items"))
    radio(5, T("Até 5 itens", "Up to 5 items"))
    radio(2, T("Sem coleta (só 1-2 itens)", "No collecting (1-2 items only)"))
    return list
end

function M:RootItems()
    local list = {}
    local lvl = UnitLevel("player")
    -- zona atual
    local w = RX.Advisor and RX.Advisor:Where()
    local zoneName = w and ((w.zone and w.zone.name) or (w.here and w.here.name))
    local zg = w and w.zone and RX.Advisor:GuidesForMap(w.zone.mapID)[1]
    table.insert(list, {
        text = T("Aqui: ", "Here: ") .. "|cff80c0ff" .. (zoneName or "?") .. "|r",
        sub = zg and string.format(T("%s · níveis %d-%d", "%s · levels %d-%d"), RX:GuideName(zg), zg.min, zg.max) or T("sem guia para esta zona", "no guide for this zone"),
        children = zg and function() return M:VariantItems(zg) end or nil,
    })
    -- faixas
    table.insert(list, { header = true, text = T("Guias por nível", "Guides by level") })
    for _, br in ipairs(RX.Brackets) do
        local lo, hi = br[1], br[2]
        local mine = lvl >= lo and lvl < hi
        local n = 0
        for _, g in pairs(RX.guides) do if g.min < hi and g.max > lo then n = n + 1 end end
        table.insert(list, {
            text = string.format("%s%s %d-%d|r", mine and "|cff40ff40" or "|cffffffff", T("Nível", "Level"), lo, hi) .. (mine and ("  |cff40ff40" .. T("<- você", "<- you") .. "|r") or ""),
            sub = string.format(T("%d guias", "%d guides"), n),
            children = function() return M:GuideItems(lo, hi) end,
        })
    end
    -- ajustes rápidos
    table.insert(list, { header = true, text = T("Ajustes", "Settings") })
    table.insert(list, { text = T("Rota: ", "Route: ") .. "|cffffffff" .. LF(RX:CurrentRoute(), "name") .. "|r", children = function() return M:RouteItems() end })
    table.insert(list, { text = T("Estilo: ", "Style: ") .. "|cffffffff" .. styleName(RX.db.style) .. "|r", children = function() return M:StyleItems() end })
    local rc, rxp = RX.Turnin:Count()
    table.insert(list, {
        text = (RX.db.turninMode and T("Sair do Modo Entregas", "Leave Turn-in mode") or string.format(T("Modo Entregas (%d · +%s xp)", "Turn-in mode (%d · +%s xp)"), rc, fmtXP(rxp))),
        onClick = function() RX.Turnin:Toggle() end,
    })
    table.insert(list, {
        text = RX.db.nearbyMode and T("Sair do Perto de mim", "Leave Nearby") or T("Perto de mim", "Nearby"),
        onClick = function() RX.Nearby:Toggle() end,
    })
    -- grupo: share de guia/progresso com quem usa o RotaXP
    if RX.Party then
        local n = RX.Party:Count()
        table.insert(list, {
            text = T("Grupo (share)", "Group (share)") .. (n > 0 and string.format(" |cff40ff40(%d)|r", n) or ""),
            sub = T("mesmo guia, progresso do parceiro em cada quest, locais", "same guide, partner progress on each quest, spots"),
            children = function() return RX.Party:Items() end,
        })
    end
    -- outras formas de upar: grind, masmorras, equipamento e cronômetro
    table.insert(list, { header = true, text = T("Outras formas de upar", "Other ways to level") })
    table.insert(list, {
        text = T("Grind & Masmorras", "Grind & Dungeons"),
        sub = T("farm solo, farm duo, masmorras, equipamento, talentos, cronômetro", "solo farm, duo farm, dungeons, gear, talents, timer"),
        children = function() return RX.Farm:Items() end,
    })
    return list
end

function M:OpenRoot()
    self:Open(1, self:RootItems())
end

function M:Refresh()
    if self:IsOpen() then self:Close(2); self:Open(1, self:RootItems()) end
end

-- substitui o menu antigo
function UI:ToggleMenu()
    if M:IsOpen() then M:Close() else M:OpenRoot() end
end

function UI:BuildMenu()
    if M:IsOpen() then M:Refresh() else M:OpenRoot() end
end
