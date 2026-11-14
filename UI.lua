-- Interface do RouteXP
local _, RX = ...
local UI = {}
RX.UI = UI
local T, LF = RX.T, RX.LF

local ORANGE = "|cffff7f00"
local ICON = {
    A = "Interface\\GossipFrame\\AvailableQuestIcon",
    C = "Interface\\Icons\\Ability_DualWield",
    T = "Interface\\GossipFrame\\ActiveQuestIcon",
    G = "Interface\\Icons\\INV_Misc_Map_01",
    F = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    H = "Interface\\Icons\\INV_Misc_Rune_01",
    R = "Interface\\Icons\\Spell_Holy_Restoration",
    L = "Interface\\Icons\\Spell_Holy_WordFortitude",
    N = "Interface\\Icons\\INV_Misc_Note_01",
    B = "Interface\\Icons\\INV_Misc_Coin_01",
}
local function flagText(f)
    local t = {
        coleta = { "|cffff9050[coleta]|r", "|cffff9050[collect]|r" },
        drop = { "|cffff6030[muito drop]|r", "|cffff6030[many drops]|r" },
        long = { "|cffaaaaaa[lenta]|r", "|cffaaaaaa[slow]|r" },
        opt = { "|cffaaaaaa[pouco XP]|r", "|cffaaaaaa[low XP]|r" },
        elite = { "|cffff4040[Elite]|r", "|cffff4040[Elite]|r" },
        group = { "|cffff4040[Grupo]|r", "|cffff4040[Group]|r" },
        dungeon = { "|cff8080ff[Masmorra]|r", "|cff8080ff[Dungeon]|r" },
        escolta = { "|cffaaaaaa[escolta]|r", "|cffaaaaaa[escort]|r" },
    }
    local e = t[f]
    return e and T(e[1], e[2])
end
local MIN_W, MIN_H, MAX_W, MAX_H = 260, 150, 900, 1000
local BTN_GAP = 6

local function backdrop(f, alpha)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.07, alpha or 0.85)
    f:SetBackdropBorderColor(1, 0.5, 0, 0.9)
end

-- texto pode ser string ou função (para trocar de idioma sem recriar)
local function tip(frame, text)
    frame:SetScript("OnEnter", function(self)
        local t = type(text) == "function" and text() or text
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(t, 1, 1, 1, true); GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function smallButton(parent, text, w, onClick, tooltip)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, 22)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    if tooltip then tip(b, tooltip) end
    return b
end

-- largura do botão ajustada ao texto
-- fonte dos botões da tela principal: um pouco menor que a pequena do jogo
local btnFonts = {}
function UI.BtnFont(hl)
    local key = hl and "hl" or "n"
    if btnFonts[key] then return btnFonts[key] end
    local f = CreateFont(hl and "RouteXPBtnFontHL" or "RouteXPBtnFont")
    local base = hl and GameFontHighlightSmall or GameFontNormalSmall
    if base and base.GetFont then
        local path, _, flags = base:GetFont()
        if path then f:SetFont(path, 9.5, flags) end
        if base.GetTextColor then f:SetTextColor(base:GetTextColor()) end
    end
    btnFonts[key] = f
    return f
end

local function fitButton(b, minW)
    local fs = b.GetFontString and b:GetFontString()
    local w = fs and fs.GetStringWidth and fs:GetStringWidth() or 0
    b:SetWidth(math.max(minW or 30, (w or 0) + 22))
end

local function fmtXP(x)
    if x >= 1000 then return string.format("%.0fk", x / 1000) end
    return tostring(math.floor(x))
end

----------------------------------------------------------------------
-- Fontes
----------------------------------------------------------------------
function UI:ApplyFonts()
    local file, _, flags = GameFontHighlight:GetFont()
    file = file or "Fonts\\FRIZQT__.TTF"
    local size = RX.db.fontSize or 12
    if not self.fontNormal then
        self.fontNormal = CreateFont("RouteXPFontNormal")
        self.fontSmall = CreateFont("RouteXPFontSmall")
        self.fontTitle = CreateFont("RouteXPFontTitle")
    end
    self.fontNormal:SetFont(file, size, flags or "")
    self.fontNormal:SetTextColor(1, 1, 1)
    self.fontSmall:SetFont(file, math.max(8, size - 2), flags or "")
    self.fontSmall:SetTextColor(0.85, 0.85, 0.85)
    self.fontTitle:SetFont(file, size + 1, flags or "")
    self.fontTitle:SetTextColor(1, 0.82, 0)
end

----------------------------------------------------------------------
-- Texto do passo
----------------------------------------------------------------------
-- Tipo do objetivo: "k" matar, "d" item que cai de mob, "g" item pego clicando (chão/objeto),
-- "i" item (origem desconhecida), "o" usar/interagir, "e" explorar/falar
-- de onde vêm os itens que a quest ainda pede (Data/QuestItemSource.lua)
local function itemKind(q)
    local need = q and RX.QuestNeeds and RX.QuestNeeds[q]
    if not need or not RX.ItemSource then return "i" end
    local list = (RX.Market and RX.Q:InLog(q)) and RX.Market:Missing(q) or nil
    local ids = {}
    if list and #list > 0 then for _, m in ipairs(list) do ids[#ids + 1] = m.id end
    else for _, n in ipairs(need) do ids[#ids + 1] = n[1] end end
    local mob, obj = false, false
    for _, id in ipairs(ids) do
        local src = RX.ItemSource[id]
        if src then
            if src:find("m") then mob = true end
            if src:find("o") then obj = true end
        end
    end
    if mob then return "d" elseif obj then return "g" end
    return "i"
end
UI.ItemKind = itemKind

function UI:ObjectiveType(s)
    if s.q and RX.Q:InLog(s.q) then
        local objs = RX.Q:Objectives(s.q)
        if objs and #objs > 0 then
            local has = {}
            for _, o in ipairs(objs) do if not o.finished then has[o.type or ""] = true end end
            if has.item then return itemKind(s.q) elseif has.monster then return "k" elseif has.object then return "o"
            elseif next(has) then return "e" end
        end
    end
    local ot = s.ot or ((s.cc and s.cc > 0) and "i") or nil
    if ot == "i" then return itemKind(s.q) end
    return ot
end

local TYPE_ICON = {
    k = "Interface\\CURSOR\\Attack",                  -- espada: só matar mobs
    d = "Interface\\Icons\\INV_Misc_Bag_10_Green",   -- saco verde: coletar item que cai de mob
    i = "Interface\\Icons\\INV_Misc_Bag_10_Green",   -- saco verde: coletar itens
    g = "Interface\\CURSOR\\Interact",                -- engrenagem: pegar no chão / clicar em objeto
    o = "Interface\\CURSOR\\Interact",                -- engrenagem: interagir com objeto
    e = "Interface\\GossipFrame\\GossipGossipIcon",   -- balão com 3 pontinhos: só falar com NPC e entregar
}
local TYPE_LABEL = {
    k = { "Matar mobs", "Kill mobs" }, d = { "Coletar (drop de mobs)", "Collect (mob drops)" }, g = { "Pegar no chão/objeto", "Pick up from ground/object" },
    o = { "Interagir/clicar", "Interact/click" }, i = { "Coletar itens", "Collect items" }, e = { "Falar com NPC", "Talk to NPC" },
}
UI.TYPE_ICON, UI.TYPE_LABEL = TYPE_ICON, TYPE_LABEL

-- passo "Fazer" de uma quest em qualquer guia (para mostrar a prévia já no "Aceitar")
local cByQ
local function doStepFor(q)
    if not cByQ then
        cByQ = {}
        for _, g in pairs(RX.guides) do
            for _, st in ipairs(g.steps) do
                if st.t == "C" and st.q and (not cByQ[st.q] or (not cByQ[st.q].pobj and st.pobj)) then cByQ[st.q] = st end
            end
        end
    end
    return cByQ[q]
end

-- tipo do objetivo sem a quest no log: dado do guia ou pelo texto do objetivo
local function guessType(c)
    if c.ot == "i" or (not c.ot and c.cc and c.cc > 0) then return itemKind(c.q) end
    if c.ot then return c.ot end
    local o = (c.obj or ""):lower()
    if o:find("^kill") or o:find("^slay") or o:find("^destroy") or o:find(" kill ") then return "k" end
    if o:find("^bring") or o:find("^collect") or o:find("^gather") or o:find("^retrieve") or o:find("^get ") or o:find("^recover") then return itemKind(c.q) end
    if o:find("^use") or o:find("^place") or o:find("^light") or o:find("^search") then return "o" end
    if o:find("^find") or o:find("^explore") or o:find("^speak") or o:find("^talk") or o:find("^travel") or o:find("^go ") then return "e" end
    return nil
end

-- "Mate 10 Basiliscos ... para o Mestre X no Salar." -> corta o "para o/a NPC" do fim
local function shortObj(txt)
    if not txt or txt == "" then return nil end
    local cut = txt:find(" para [oa]s? [%u]") or txt:find(" para [%u]") or txt:find(" for [%u]") or txt:find(" to [%u][%l]+ [%u]")
    if cut and cut > 12 then txt = txt:sub(1, cut - 1) end
    txt = txt:gsub("%.$", "")
    if #txt > 140 then txt = txt:sub(1, 137) .. "..." end
    return txt
end

-- Prévia da quest antes de aceitar: tipo (espadinha/bolsinha/...) + o que pede, com quantidades
function UI:QuestPreview(s)
    if not s.q then return nil end
    local c = doStepFor(s.q)
    if not c then
        return "|T" .. TYPE_ICON.e .. ":14|t " .. T("Sem objetivo: só levar/falar com o NPC da entrega", "No objective: just deliver/talk to the turn-in NPC")
    end
    local ot = guessType(c)
    local obj = shortObj(RX:IsPT() and (c.pobj or c.obj) or c.obj)
    local lab = ot and TYPE_LABEL[ot]
    local head = ot and ("|T" .. TYPE_ICON[ot] .. ":14|t " .. T(lab[1], lab[2])) or ""
    if obj then return head .. (head ~= "" and ": " or "") .. obj end
    if head ~= "" then return head end
    return nil
end

local LEG_ICON = {
    walk = "Interface\\Icons\\Ability_Tracking", fly = "Interface\\Icons\\Ability_Mount_Wyvern_01",
    ship = "Interface\\Icons\\INV_Misc_Spyglass_02", unknown = "Interface\\Icons\\INV_Misc_QuestionMark",
}

function UI:StepIcon(s)
    if s.t == "V" then return LEG_ICON[s.leg] or LEG_ICON.walk end
    if s.t == "C" then return ICON.T end   -- "?" (cinza: em andamento)
    return ICON[s.t] or ICON.N
end

-- tipo da quest para o ícone ao lado do ! / ?: espada, saquinho, engrenagem ou 3 pontinhos (só falar)
function UI:QuestTypeIcon(s)
    if not s.q then return nil end
    local ot
    if s.t == "C" then ot = self:ObjectiveType(s)
    elseif s.t == "A" or (s.t == "T" and not RX.Q:InLog(s.q)) then
        local c = doStepFor(s.q)
        if c then ot = guessType(c) else ot = "e" end
    end
    return ot and TYPE_ICON[ot] or nil
end

-- etiqueta no título quando dá para comprar o item da quest no leilão
function UI:MarketTag(s)
    local tag = s.chain and (" |cff40c0ff" .. T("[pré-quest]", "[prerequisite]") .. "|r") or ""
    if not (s.q and RX.Market and RX.db.marketHint ~= false) then return tag end
    if s.t == "A" and RX.Q:InLog(s.q) then return tag end
    if not RX.Market:Buyable(s.q) then return tag end
    return tag .. " |T" .. RX.Market.ICON .. ":14|t|cff33ddff" .. T("leilão", "AH") .. "|r"
end

function UI:StepText(s)
    if s.t == "V" then
        return "|cff80c0ff" .. (s.d or "") .. "|r", s.note and ("|cffb0b0b0" .. s.note .. "|r") or nil
    end
    local t = s.t
    local qn = RX:QName(s)
    local name = qn and ("|cffffff00" .. qn .. "|r") or ""
    local npc = RX:NpcName(s)
    local d = LF(s, "d") or ""
    local note = LF(s, "note")
    local txt
    if t == "A" then
        txt = T("Aceitar ", "Accept ") .. name .. self:MarketTag(s)
    elseif t == "C" then
        txt = T("Fazer ", "Complete ") .. name .. self:MarketTag(s)
    elseif t == "T" then
        txt = T("Entregar ", "Turn in ") .. name
    elseif t == "G" then
        txt = T("Ir para ", "Go to ") .. (s.x and string.format("|cff80ff80%.1f, %.1f|r ", s.x, s.y) or "") .. (note or "")
    elseif t == "F" then
        txt = T("Voar para ", "Fly to ") .. "|cff80c0ff" .. d .. "|r"
    elseif t == "H" then
        txt = T("Usar Pedra de Regresso -> ", "Use Hearthstone -> ") .. "|cff80c0ff" .. d .. "|r"
    elseif t == "R" then
        txt = T("Definir Pedra de Regresso em ", "Set Hearthstone at ") .. "|cff80c0ff" .. d .. "|r " ..
            T("(fale com o taverneiro)", "(talk to the innkeeper)")
    elseif t == "L" then
        txt = T("Upe até o nível ", "Level up to ") .. "|cff40ff40" .. (s.lv or "?") .. "|r " .. T("matando mobs no caminho", "by killing mobs on the way")
    elseif t == "B" then
        txt = T("Comprar: ", "Buy: ") .. d
    else
        txt = (d ~= "" and d) or note or ""
    end
    local xpv = s.xpNow or (s.xp and (t == "T" or t == "A" or t == "C") and RX:QuestXP(s))
    if xpv and xpv > 0 and (t == "T" or t == "A" or t == "C") then txt = txt .. string.format("  |cff40ff40+%s xp|r", fmtXP(xpv)) end

    -- linha(s) de dica abaixo do nome: NPC/local, progresso e recomendações
    local hints = {}
    local function add(color, text) table.insert(hints, color .. text .. "|r") end
    if s.nearby and RX.db.nearbyMode and s.nearNote then add("|cff40c0ff", s.nearNote) end
    if s.fromLog and s.logNote and not RX.db.nearbyMode then add("|cff40c0ff", s.logNote) end
    -- pré-quest de uma cadeia: diz qual quest ela libera
    if s.chainFor then add("|cff40c0ff", T("Pré-quest para liberar: ", "Prerequisite to unlock: ") .. "|cffffff00" .. (RX:QName(s.chainFor) or "?") .. "|r") end
    if s.chainNoLoc then add("|cffff9050", T("Sem local de início conhecido: veja no mapa do jogo / Questie ou pergunte a um amigo.", "No known start location: check the game map / Questie or ask a friend.")) end
    if s.t == "A" and s.q and RX.notOffered and RX.notOffered[s.q] then
        add("|cffff6060", T("Este NPC não ofereceu a quest: falta uma pré-quest que o guia não conhece (siga a linha de quests do NPC no jogo).", "This NPC did not offer the quest: a prerequisite quest is missing that the guide doesn't know (follow the NPC's quest line in game)."))
    end
    -- progresso de quem está no seu grupo (RouteXP ou Questie)
    if s.q and (t == "A" or t == "C" or t == "T") and RX.Party then
        local pl = RX.Party:LinesFor(s)
        if pl then for _, l in ipairs(pl) do add("|cffffffff", l) end end
    end
    -- itens à venda no leilão (preço do Auctionator): comprar em vez de farmar
    if s.q and RX.Market and RX.db.marketHint ~= false and (t == "C" or (t == "A" and not RX.Q:InLog(s.q))) then
        local mh = RX.Market:Hint(s.q)
        if mh then add("", mh) end
    end
    -- quest de profissão: o que fabricar e os ingredientes
    if s.q and RX.Craft and RX.Craft:Info(s.q) and (t == "A" or t == "C" or (t == "T" and not RX.Q:IsReady(s.q))) then
        local h1, h2, h3 = RX.Craft:Hint(s.q)
        if h1 then add("|cffffd040", h1) end
        if h2 then add("|cffd0d0d0", h2) end
        if h3 then add("|cffaaaaaa", h3) end
    elseif s.synth and not s.locSrc then
        add("|cffaaaaaa", T("O guia não tem o local deste objetivo: veja o objetivo no mapa do jogo/Questie.", "The guide has no location for this objective: check the game map/Questie."))
    end
    -- quest que precisa USAR um item (num mob, objeto ou local): manda clicar no botão da janela de itens
    if s.q and (t == "C" or (t == "T" and not RX.Q:IsReady(s.q))) and RX.QuestItems and RX.db.questItems ~= false then
        local iid = RX.QuestItems:ItemFor(s.q)
        if iid then
            local icon = (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(iid)) or (GetItemIcon and GetItemIcon(iid)) or 134400
            local nm = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(iid)) or (GetItemInfo and (GetItemInfo(iid))) or T("item da quest", "quest item")
            local key = GetBindingKey and GetBindingKey("CLICK RouteXPQuestItem1:LeftButton")
            add("|cffffb040", "|T" .. icon .. ":16|t " .. string.format(T("Use o item %s: clique no ícone dele na janela Itens da quest%s", "Use the item %s: click its icon in the Quest items window%s"), nm,
                key and string.format(T(" (ou tecla %s)", " (or key %s)"), key) or ""))
        end
    end
    if t == "A" and s.startItem then
        local nm = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(s.startItem)) or (GetItemInfo and (GetItemInfo(s.startItem))) or T("o item", "the item")
        add("|cffffb040", string.format(T("Esta quest começa com o item %s, que está na sua bolsa: clique com o botão direito nele (ou no ícone da janela Itens da quest).", "This quest starts from the item %s in your bags: right-click it (or click it in the Quest items window)."), nm))
    end
    if t == "A" then
        local pv = (not s.chain) and UI:QuestPreview(s) or nil
        if pv then add("|cffffe0a0", pv) end
    end
    if npc and (t == "A" or t == "T") then
        add("|cffb0b0b0", npc .. (s.approx and ("  ·  " .. T("local aproximado: procure o \"!\" na base", "approximate spot: look for the \"!\" at the hub")) or ""))
    elseif s.approx and not s.startItem then
        add("|cffb0b0b0", T("Local aproximado: procure o \"!\" na base", "Approximate spot: look for the \"!\" at the hub"))
    end
    if t == "C" and s.q then
        if RX.Q:InLog(s.q) then
            local prog = RX.Q:ProgressText(s.q)
            if prog then table.insert(hints, prog) end
        else
            add("|cffff6060", T("Quest não está no seu log: aceite-a ou marque o quadradinho para pular.",
                "Quest is not in your log: accept it or tick the checkbox to skip it."))
        end
    end
    -- de onde veio o local do objetivo
    if t == "C" and s.locSrc == "poi" then add("|cff80c0ff", T("Local tirado da quest no mapa do jogo", "Location taken from the quest on the game map"))
    elseif t == "C" and s.locSrc == "obj" and s.locName then add("|cff80c0ff", T("Seta no que ainda falta: ", "Arrow on what's still missing: ") .. s.locName) end
    -- entregar: avisa se ainda não está pronta
    if t == "T" and s.q and RX.Q:InLog(s.q) and not RX.Q:IsReady(s.q) then
        add("|cffff6060", T("Ainda não está pronta: termine os objetivos primeiro.", "Not ready yet: finish the objectives first."))
    end
    -- adiantar: outra quest pede itens que caem destes mesmos mobs
    if t == "C" and s.ahead and s.q and RX.Q:InLog(s.q) then
        for _, a in ipairs(s.ahead) do
            if not RX.Q:IsCompleted(a.q) then
                local qn = (RX:IsPT() and a.pn) or a.n
                local item = (RX:IsPT() and a.ip) or a.i
                if RX.Q:InLog(a.q) then
                    add("|cff40ff40", string.format(T("Faça junto: \"%s\" pede %d %s destes mesmos mobs.", "Do it together: \"%s\" needs %d %s from these same mobs."), qn, a.c, item))
                elseif a.qi then
                    local gv = RX.QuestLoc and RX.QuestLoc:Giver(a.q)
                    local who = gv and (RX:NpcName(gv) or "") .. (gv.m and (" - " .. (RX.MapName(gv.m) or "")) or "") or ""
                    add("|cffffd040", string.format(T("Dica: \"%s\" pede %d %s destes mobs. Esse item só cai com a quest ativa: pegue-a antes%s.",
                        "Tip: \"%s\" needs %d %s from these mobs. It only drops with the quest active: grab it first%s."), qn, a.c, item, who ~= "" and (" (" .. who .. ")") or ""))
                else
                    add("|cffffd040", string.format(T("Opcional: guarde %d %s destes mobs — \"%s\" vai pedir depois.", "Optional: keep %d %s from these mobs — \"%s\" will ask for it later."), a.c, item, qn))
                end
            end
        end
    end
    -- recomendações (uma vez por quest: no Aceitar e no Fazer)
    if t ~= "T" or s.turnin then
        local f = s.flags
        local kindI = (s.cc and s.cc >= 3) and itemKind(s.q) or nil
        if kindI == "g" then
            add("|cffff9050", string.format(T("Pegar %d itens clicando no chão/objetos", "Pick up %d items by clicking on the ground/objects"), s.cc))
        elseif kindI then
            add("|cffff9050", string.format(T("Coletar %d itens que caem de mobs%s", "Collect %d items dropped by mobs%s"), s.cc,
                f.drop and T(" - lento em duo/grupo (cada um precisa do seu)", " - slow in duo/group (everyone needs their own)") or ""))
        elseif f.drop or f.coleta then
            add("|cffff9050", T("Muitos itens de drop: lento em duo/grupo", "Many dropped items: slow in duo/group"))
        end
        if t == "C" then
            local ot = UI:ObjectiveType(s)
            local lab = ot and TYPE_LABEL[ot]
            local ic = ot and ("|T" .. TYPE_ICON[ot] .. ":14|t ") or ""
            if ot == "k" then add("|cffd0d0d0", ic .. T("Matar mobs: em duo/grupo todos ganham o crédito", "Kill mobs: in a duo/group everyone gets credit"))
            elseif ot == "d" then add("|cffd0d0d0", ic .. T("Item que cai de mobs: mate e saqueie", "Item dropped by mobs: kill and loot"))
            elseif ot == "g" then add("|cffd0d0d0", ic .. T("Item no chão/objeto: só clicar para pegar", "Item on the ground/object: just click to pick it up"))
            elseif ot == "o" then add("|cffd0d0d0", ic .. T("Usar/clicar em objetos no local", "Use/click objects at the spot"))
            elseif lab then add("|cffd0d0d0", ic .. T(lab[1], lab[2])) end
        end
        if f.elite then add("|cffff5050", T("Mobs de elite: recomendado fazer em duo ou grupo", "Elite mobs: recommended in a duo or group")) end
        if s.lvl and s.lvl - UnitLevel("player") >= 3 then
            add("|cffff5050", string.format(T("Quest nível %d: mobs fortes para o seu nível - vá em duo ou volte depois", "Level %d quest: strong mobs for your level - bring a friend or come back later"), s.lvl))
        end
        if f.escolta then add("|cffaaaaaa", T("Escolta: demorada, vale a pena só se estiver no caminho", "Escort: slow, only worth it if it's on your way"))
        elseif f.long then add("|cffaaaaaa", T("Lenta: entrega ou objetivo em outra zona", "Slow: turn-in or objective in another zone")) end
        if f.opt then add("|cffaaaaaa", T("Pouco XP para o tempo gasto", "Low XP for the time spent")) end
        if f.dungeon then add("|cff8080ff", T("Quest de masmorra: faça com grupo", "Dungeon quest: do it with a group")) end
    end
    if note and t ~= "G" and t ~= "N" and t ~= "L" then add("|cffc8c8c8", note) end
    local sub = #hints > 0 and table.concat(hints, "\n") or nil
    return txt, sub
end

----------------------------------------------------------------------
-- Janela principal
----------------------------------------------------------------------
local BAR = {
    { key = "guides", pt = "Guias", en = "Guides", tipPT = "Escolher rota, estilo de leveling e guia por nível", tipEN = "Pick route, leveling style and guide by level", click = function() UI:ToggleMenu() end },
    { key = "turnin", pt = "Entregas", en = "Turn-ins", tipPT = "Modo Entregas: lista só as quests prontas e monta a melhor rota para entregar todas (libera a bolsa). Clique de novo para voltar ao guia.",
      tipEN = "Turn-in mode: lists only ready quests and builds the best route to turn them all in (frees bag space). Click again to go back to the guide.", click = function() RX.Turnin:Toggle() end },
    { key = "share", pt = "Compartilhar quests", en = "Share quests", tipPT = "Compartilha com o seu grupo todas as quests do seu log que fazem parte do guia atual (uma por vez).", tipEN = "Shares with your group every quest in your log that belongs to the current guide (one at a time).", click = function() RX.Party:ShareGuideQuests() end },
    { key = "timer", pt = "Cronômetro", en = "Timer", tipPT = "Cronômetro de XP: mede quanto XP por hora você ganha num local ou masmorra.", tipEN = "XP timer: measures how much XP per hour you get at a spot or dungeon.", click = function() RX.Timer:ToggleWindow() end },
    { key = "options", pt = "Opções", en = "Options", tipPT = "Estilo, fonte, idioma, auto aceitar...", tipEN = "Style, font, language, auto accept...", click = function() UI:ShowPanel("options") end },
}

-- Botões dentro de uma janela também a arrastam (clique continua funcionando; arrastar move)
function UI.ForwardDrag(widget, target)
    widget:RegisterForDrag("LeftButton")
    widget:SetScript("OnDragStart", function()
        local fn = target:GetScript("OnDragStart"); if fn then fn(target) end
    end)
    widget:SetScript("OnDragStop", function()
        local fn = target:GetScript("OnDragStop"); if fn then fn(target) end
    end)
end

function UI:Create()
    self:ApplyFonts()
    local f = CreateFrame("Frame", "RouteXPFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    backdrop(f)
    f:SetSize(RX.db.width, RX.db.height)
    f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
    f:SetMovable(true)
    f:SetResizable(true)
    if f.SetResizeBounds then f:SetResizeBounds(MIN_W, MIN_H, MAX_W, MAX_H)
    elseif f.SetMinResize then f:SetMinResize(MIN_W, MIN_H); f:SetMaxResize(MAX_W, MAX_H) end
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetClampedToScreen(true)
    f:SetScript("OnDragStart", function(self) if not RX.db.locked then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        RX.db.pos = { p, rp, x, y }
    end)
    if RX.db.pos then
        local p = RX.db.pos
        f:ClearAllPoints(); f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    f:SetScale(RX.db.scale or 1)
    self.frame = f

    -- botão do menu de guias (título)
    local gb = CreateFrame("Button", nil, f)
    gb:SetPoint("TOPLEFT", 8, -6)
    gb:SetPoint("TOPRIGHT", -125, -6)   -- espaço para "minimizar" e o X
    gb:SetHeight(18)
    local arrowTex = gb:CreateTexture(nil, "ARTWORK")
    arrowTex:SetSize(16, 16)
    arrowTex:SetPoint("LEFT")
    arrowTex:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    local title = gb:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(self.fontTitle)
    title:SetPoint("LEFT", arrowTex, "RIGHT", 2, 0)
    title:SetPoint("RIGHT")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    gb:SetScript("OnClick", function() UI:ToggleMenu() end)
    UI.ForwardDrag(gb, f)
    tip(gb, function() return T("Clique: escolher rota, estilo e guia por nível. Segure e arraste: mover a janela.", "Click: pick route, style and guide by level. Hold and drag: move the window.") end)
    self.title = title

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() UI:Toggle() end)
    -- minimizar: vira uma bolinha com o ícone num canto da tela
    -- botão com o ícone do addon + "minimizar", afastado do X
    local mini = CreateFrame("Button", nil, f)
    mini:SetHeight(18)
    mini:SetPoint("RIGHT", close, "LEFT", -8, 0)
    local mic = mini:CreateTexture(nil, "ARTWORK")
    mic:SetSize(16, 16); mic:SetPoint("LEFT")
    mic:SetTexture(RX.ICON)
    local mtx = mini:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mtx:SetPoint("LEFT", mic, "RIGHT", 3, 0)
    mtx:SetTextColor(1, 0.6, 0.15)
    mini.label = mtx
    function mini:Relabel()
        mtx:SetText(T("minimizar", "minimize"))
        self:SetWidth(16 + 3 + (mtx:GetStringWidth() or 50) + 2)
    end
    mini:Relabel()
    local mhl = mini:CreateTexture(nil, "HIGHLIGHT")
    mhl:SetAllPoints(); mhl:SetColorTexture(1, 0.6, 0.15, 0.15)
    mini:SetScript("OnClick", function() UI:Minimize() end)
    self.miniBtn = mini
    tip(mini, function() return T("Minimizar: o guia vira uma bolinha com o ícone (clique nela para voltar).", "Minimize: the guide becomes a small icon button (click it to come back).") end)

    local xp = f:CreateFontString(nil, "OVERLAY")
    xp:SetFontObject(self.fontSmall)
    xp:SetPoint("TOPLEFT", gb, "BOTTOMLEFT", 2, -2)
    xp:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    xp:SetJustifyH("LEFT")
    self.xp = xp
    local est = f:CreateFontString(nil, "OVERLAY")
    est:SetFontObject(self.fontSmall)
    est:SetPoint("TOPLEFT", xp, "BOTTOMLEFT", 0, -2)
    est:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    est:SetJustifyH("LEFT")
    est:SetWordWrap(true)
    self.est = est
    -- linha de local (zona/cidade detectada); clique usa o guia desta zona
    local loc = CreateFrame("Button", nil, f)
    UI.ForwardDrag(loc, f)
    loc:SetPoint("TOPLEFT", est, "BOTTOMLEFT", 0, -2)
    loc:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    loc:SetHeight(13)
    local ltxt = loc:CreateFontString(nil, "OVERLAY")
    ltxt:SetFontObject(self.fontSmall)
    ltxt:SetAllPoints(); ltxt:SetJustifyH("LEFT"); ltxt:SetWordWrap(false)
    loc:SetScript("OnClick", function()
        if UI.locGuide and UI.locGuide ~= RX:CurrentGuide() then RX:SetGuide(UI.locGuide.id) else UI:ShowPanel("now") end
    end)
    tip(loc, function() return T("Onde você está. Clique: usar o guia desta zona (ou abrir os conselhos 'Agora').",
        "Where you are. Click: use this zone's guide (or open the 'Now' advice).") end)
    self.loc = ltxt
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(1, 0.5, 0, 0.35)
    sep:SetHeight(1)
    self.headSep = sep

    self.lines = {}
    -- lista de passos com rolagem (barra, roda do mouse ou clicar e arrastar)
    local scroll = CreateFrame("ScrollFrame", "RouteXPStepScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -48)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 70)
    scroll:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(300, 10)
    scroll:SetScrollChild(content)
    self.scroll, self.content = scroll, content
    self.scrollBar = _G["RouteXPStepScrollScrollBar"]

    -- barra inferior (layout em fluxo, com espaçamento; quebra linha se a janela for estreita)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("BOTTOMLEFT", 8, 6)
    bar:SetPoint("BOTTOMRIGHT", -22, 6)
    bar:SetHeight(22)
    self.bar = bar
    self.barButtons = {}
    for _, def in ipairs(BAR) do
        local b = smallButton(bar, def.pt, 40, def.click, function() return T(def.tipPT, def.tipEN) end)
        b.def = def
        table.insert(self.barButtons, b)
    end

    -- linha de modos (clicável) + prontas para entregar
    local modes = CreateFrame("Button", nil, f)
    modes:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", 0, 4)
    modes:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    modes:SetHeight(14)
    local mtxt = modes:CreateFontString(nil, "OVERLAY")
    mtxt:SetFontObject(self.fontSmall)
    mtxt:SetAllPoints(); mtxt:SetJustifyH("LEFT")
    modes:SetScript("OnClick", function() UI:ToggleMenu() end)
    UI.ForwardDrag(modes, f)
    self.modes = mtxt
    local readyBtn = CreateFrame("Button", nil, f)
    readyBtn:SetPoint("BOTTOMLEFT", modes, "TOPLEFT", 0, 2)
    readyBtn:SetPoint("RIGHT", f, "RIGHT", -10, 0)
    readyBtn:SetHeight(13)
    local ready = readyBtn:CreateFontString(nil, "OVERLAY")
    ready:SetFontObject(self.fontSmall)
    ready:SetAllPoints(); ready:SetJustifyH("LEFT"); ready:SetWordWrap(false)
    readyBtn:SetScript("OnClick", function() RX.Turnin:Toggle() end)
    UI.ForwardDrag(readyBtn, f)
    tip(readyBtn, function() return T("Clique: Modo Entregas (lista só as quests prontas, em rota).", "Click: Turn-in mode (lists only ready quests, routed).") end)
    self.ready = ready

    -- alça de redimensionar (canto inferior direito)
    local grip = CreateFrame("Button", nil, f)
    grip:SetSize(16, 16)
    grip:SetPoint("BOTTOMRIGHT", -3, 3)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() if not RX.db.locked then f:StartSizing("BOTTOMRIGHT") end end)
    grip:SetScript("OnMouseUp", function()
        f:StopMovingOrSizing()
        RX.db.width, RX.db.height = math.floor(f:GetWidth()), math.floor(f:GetHeight())
        local p, _, rp, x, y = f:GetPoint()
        RX.db.pos = { p, rp, x, y }
        UI:Refresh()
    end)
    tip(grip, function() return T("Arraste para aumentar/diminuir a janela. Mais altura = mais passos visíveis.",
        "Drag to resize the window. More height = more visible steps.") end)
    f:SetScript("OnSizeChanged", function() if UI.sizing then return end UI.sizing = true; UI:Refresh(); UI.sizing = false end)

    self:Relocalize()
    self:CreateMinimapButton()
    if RouteXPCharDB.hidden or RouteXPCharDB.minimized then f:Hide() end
    if RouteXPCharDB.minimized then self:ShowBall() end
end

----------------------------------------------------------------------
-- Bolinha (addon minimizado)
----------------------------------------------------------------------
function UI:CreateBall()
    if self.ball then return self.ball end
    local b = CreateFrame("Button", "RouteXPBall", UIParent)
    b:SetSize(40, 40)
    b:SetFrameStrata("MEDIUM")
    b:SetClampedToScreen(true)
    b:SetMovable(true)
    b:EnableMouse(true)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local ic = b:CreateTexture(nil, "ARTWORK")
    ic:SetAllPoints()
    ic:SetTexture(RX.ICON)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(RX.ICON)
    hl:SetBlendMode("ADD")
    hl:SetAlpha(0.35)
    b:SetScript("OnDragStart", function(self) self.moved = true; self:StartMoving() end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        RX.db.ballPos = { p, rp, x, y }
    end)
    b:SetScript("OnClick", function(self, button)
        if button == "RightButton" then UI:ToggleMenu() else UI:Restore() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ORANGE .. RX.NAME .. "|r")
        GameTooltip:AddLine(T("Clique: abrir o guia", "Click: open the guide"), 1, 1, 1)
        GameTooltip:AddLine(T("Botão direito: menu de guias", "Right-click: guide menu"), 1, 1, 1)
        GameTooltip:AddLine(T("Arraste para mover", "Drag to move"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local p = RX.db.ballPos
    if p then b:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else b:SetPoint("RIGHT", UIParent, "RIGHT", -40, 160) end
    b:Hide()
    self.ball = b
    return b
end

function UI:ShowBall() self:CreateBall():Show() end
function UI:HideBall() if self.ball then self.ball:Hide() end end

function UI:Minimize()
    self.frame:Hide()
    if self.menu then self.menu:Hide() end
    RouteXPCharDB.minimized = true
    RouteXPCharDB.hidden = false
    self:ShowBall()
end

function UI:Restore()
    self:HideBall()
    RouteXPCharDB.minimized = false
    RouteXPCharDB.hidden = false
    self.frame:Show()
    RX:Update(true)
end

-- Atualiza textos fixos quando o idioma muda
function UI:Relocalize()
    if not self.barButtons then return end
    if self.miniBtn then self.miniBtn:Relabel() end
    for _, b in ipairs(self.barButtons) do
        b:SetText(T(b.def.pt, b.def.en))
        fitButton(b, b.def.small and 28 or 50)
    end
    if self.menu then self.menu:Hide() end
    if self.panel then self.panel:Hide() end
    self:LayoutBar()
end

-- Coloca os botões em fileiras com espaço entre eles; devolve a altura usada
function UI:LayoutBar()
    if not self.barButtons then return 22 end
    -- grade uniforme: todos os botões com a mesma largura e altura (3 por linha; 5 se a janela for larga)
    local avail = (self.frame:GetWidth() or 300) - 34
    local n = #self.barButtons
    -- 3 por fileira (cabem 6 em 2 fileiras); janela bem larga: todos numa fileira
    local cols = (avail >= 120 * n) and n or math.min(3, n)
    local bw = math.floor((avail - (cols - 1) * BTN_GAP) / cols)
    local bh = 28
    local rows = math.ceil(n / cols)
    for i, b in ipairs(self.barButtons) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        b:SetSize(bw, bh)
        -- letra pequena; quebra em até 2 linhas para caber no botão em qualquer idioma
        if b.SetNormalFontObject then b:SetNormalFontObject(UI.BtnFont()); b:SetHighlightFontObject(UI.BtnFont(true)) end
        local fs = b:GetFontString()
        if fs then
            fs:ClearAllPoints(); fs:SetPoint("LEFT", 4, 0); fs:SetPoint("RIGHT", -4, 0)
            fs:SetWordWrap(true); if fs.SetMaxLines then fs:SetMaxLines(2) end; fs:SetJustifyH("CENTER")
        end
        b:ClearAllPoints()
        -- última fileira incompleta fica centralizada
        local inRow = math.min(cols, n - row * cols)
        local off = (cols - inRow) * (bw + BTN_GAP) / 2
        b:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", off + col * (bw + BTN_GAP), (rows - 1 - row) * (bh + 3))
    end
    local h = rows * (bh + 3) - 3
    self.bar:SetHeight(h)
    return h
end

function UI:Toggle()
    if self.frame:IsShown() then
        self.frame:Hide(); RouteXPCharDB.hidden = true; RouteXPCharDB.minimized = false
        self:HideBall()
        if self.menu then self.menu:Hide() end
    else
        self:Restore()
    end
end

-- Rolagem da lista
function UI:ScrollMax()
    local view = self.scroll:GetHeight() or 0
    local h = self.content:GetHeight() or 0
    return math.max(0, h - view)
end

function UI:ScrollTo(v)
    v = math.max(0, math.min(self:ScrollMax(), v or 0))
    self.scroll:SetVerticalScroll(v)
    if self.scrollBar and self.scrollBar.SetValue then self.scrollBar:SetValue(v) end
end

function UI:ScrollBy(delta)
    self:ScrollTo((self.scroll:GetVerticalScroll() or 0) + delta)
end

-- clicar e arrastar a lista: arrastar para cima desce a lista
local function startDragScroll(line)
    local _, cy = GetCursorPosition()
    UI.dragScroll = { y = cy, start = UI.scroll:GetVerticalScroll() or 0, moved = false }
    line:SetScript("OnUpdate", function()
        local d = UI.dragScroll
        if not d then return end
        local _, y = GetCursorPosition()
        local dy = (y - d.y) / (UI.frame:GetEffectiveScale() or 1)
        if math.abs(dy) > 4 then d.moved = true end
        if d.moved then UI:ScrollTo(d.start + dy) end
    end)
end
local function stopDragScroll(line)
    line:SetScript("OnUpdate", nil)
    local moved = UI.dragScroll and UI.dragScroll.moved
    UI.dragScroll = nil
    return moved
end

function UI:GetLine(i)
    local l = self.lines[i]
    if l then return l end
    l = CreateFrame("Button", nil, self.content)
    l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function(_, delta) UI:ScrollBy(-delta * 40) end)
    l:SetScript("OnMouseDown", function(self, button) if button == "LeftButton" then startDragScroll(self) end end)
    l:SetScript("OnMouseUp", function(self, button) if button == "LeftButton" then self.wasDrag = stopDragScroll(self) end end)
    -- quadradinho para pular / já fiz
    local cb = CreateFrame("CheckButton", nil, l, "UICheckButtonTemplate")
    cb:SetSize(18, 18)
    cb:SetPoint("TOPLEFT", -2, 1)
    cb:SetScript("OnClick", function(self)
        local s = l.step
        self:SetChecked(false)
        if not s then return end
        if s.turnin then
            RX:MarkStep(s, true) -- Modo Entregas: só tira da lista de entregas
        elseif s.q then
            RX:SkipQuest(s.q)
            RX:Print(T("Pulada: ", "Skipped: ") .. (RX:QName(s) or s.q) ..
                T("  (desfazer em Opções > Voltar quests puladas)", "  (undo in Options > Restore skipped quests)"))
        else
            RX:MarkStep(s, true)
        end
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(T("Pular / já fiz", "Skip / already done"), 1, 1, 1)
        GameTooltip:AddLine(T("Marque para tirar esta quest da rota (não quero fazer ou já fiz).",
            "Tick to remove this quest from the route (don't want it or already did it)."), 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l.check = cb
    -- botão "abandonar" (texto pequeno, no canto de baixo à direita, longe do quadradinho de pular)
    local ab = CreateFrame("Button", nil, l)
    ab:SetPoint("BOTTOMLEFT", l, "BOTTOMLEFT", 40, 3)   -- embaixo do texto, à esquerda (sempre visível, longe do quadradinho)
    local abt = ab:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    abt:SetPoint("LEFT")
    abt:SetText("[" .. T("abandonar quest", "abandon quest") .. "]")
    abt:SetTextColor(1, 0.35, 0.35)
    ab:SetSize(abt:GetStringWidth() + 6, 12)
    -- em toda quest da lista: vermelho = está no seu log (abandona); cinza = você ainda não pegou
    function ab:Paint(hover)
        if self.inLog then abt:SetTextColor(1, hover and 0.6 or 0.35, hover and 0.6 or 0.35) else abt:SetTextColor(0.5, 0.5, 0.5) end
    end
    ab:SetScript("OnClick", function()
        local s = l.step
        if not (s and s.q) then return end
        if ab.inLog and RX.Abandon then RX.Abandon:Confirm(s.q)
        else RX:Print(T("Você ainda não pegou esta quest, então não tem o que abandonar. Para tirar ela da lista, marque o quadradinho.",
            "You haven't taken this quest yet, so there is nothing to abandon. To remove it from the list, tick the checkbox.")) end
    end)
    ab:SetScript("OnEnter", function(self)
        self:Paint(true)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(T("Abandonar a quest", "Abandon the quest"), 1, 0.3, 0.3)
        if self.inLog then
            GameTooltip:AddLine(T("Tira a quest do seu log e do guia (pede confirmação).", "Removes the quest from your log and the guide (asks first)."), 0.8, 0.8, 0.8, true)
        else
            GameTooltip:AddLine(T("Você ainda não pegou esta quest. Para tirar da lista, use o quadradinho.", "You haven't taken this quest yet. To remove it from the list, use the checkbox."), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    ab:SetScript("OnLeave", function(self) self:Paint(false); GameTooltip:Hide() end)
    ab:Hide()
    l.abandon = ab
    l.icon = l:CreateTexture(nil, "ARTWORK")
    l.icon:SetSize(16, 16)
    l.icon:SetPoint("TOPLEFT", 18, -1)
    l.typeIcon = l:CreateTexture(nil, "ARTWORK")
    l.typeIcon:SetSize(14, 14)
    l.typeIcon:SetPoint("LEFT", l.icon, "RIGHT", 2, 0)
    l.typeIcon:Hide()
    l.text = l:CreateFontString(nil, "OVERLAY")
    l.text:SetFontObject(self.fontNormal)
    l.text:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", 4, 0)
    l.text:SetJustifyH("LEFT")
    l.text:SetWordWrap(true)
    l.sub = l:CreateFontString(nil, "OVERLAY")
    l.sub:SetFontObject(self.fontSmall)
    l.sub:SetPoint("TOPLEFT", l.text, "BOTTOMLEFT", 2, -4)
    l.sub:SetSpacing(2)
    l.sub:SetJustifyH("LEFT")
    l.sub:SetWordWrap(true)
    l.hl = l:CreateTexture(nil, "BACKGROUND")
    l.hl:SetAllPoints()
    l.hl:SetColorTexture(1, 0.5, 0, 0.12)
    -- linha separadora entre os passos
    l.sep = l:CreateTexture(nil, "BORDER")
    l.sep:SetColorTexture(1, 1, 1, 0.08)
    l.sep:SetHeight(1)
    l.sep:SetPoint("BOTTOMLEFT", 0, -5)
    l.sep:SetPoint("BOTTOMRIGHT", 0, -5)
    l:SetScript("OnClick", function(self, button)
        local s = self.step
        if self.wasDrag then self.wasDrag = false; return end
        if not s then if self.emptyAction then self.emptyAction() end return end
        if button == "RightButton" then
            if IsShiftKeyDown() and s.q then RX:SkipQuest(s.q) else RX:MarkStep(s, true) end
        else
            if s.m then RX.Arrow:PointTo(s) end
            UI:SelectInGame(s)
        end
    end)
    l:SetScript("OnEnter", function(self)
        local s = self.step
        if not s then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine((UI:StepText(s)), 1, 1, 1, true)
        if s.pn and RX:IsPT() then GameTooltip:AddLine("English: " .. s.n, 0.6, 0.6, 0.6, true)
        elseif s.pn then GameTooltip:AddLine("Português: " .. s.pn, 0.6, 0.6, 0.6, true) end
        local obj = RX:ObjText(s)
        if obj then GameTooltip:AddLine(obj, 0.8, 0.8, 0.8, true) end
        if s.lvl then GameTooltip:AddLine(T("Nível da quest: ", "Quest level: ") .. s.lvl .. (s.req and (T("  (requer ", "  (requires ") .. s.req .. ")") or ""), 0.6, 0.8, 1) end
        if s.xp then GameTooltip:AddLine(string.format(T("XP: %d (para você agora: %d)", "XP: %d (for you now: %d)"), s.xp, RX:QuestXP(s)), 0.4, 1, 0.4) end
        if s.cc then GameTooltip:AddLine(T("Itens de drop para coletar: ", "Dropped items to collect: ") .. s.cc, 1, 0.6, 0.3) end
        if s.m and s.x then
            local info = C_Map.GetMapInfo(s.m)
            GameTooltip:AddLine(string.format("%s %.1f, %.1f", info and info.name or "", s.x, s.y), 0.5, 1, 0.5)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(T("Clique: apontar a seta aqui", "Click: point the arrow here"), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(T("Botão direito: marcar este passo como feito", "Right-click: mark this step done"), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(T("Quadradinho: pular a quest inteira", "Checkbox: skip the whole quest"), 0.7, 0.7, 0.7)
        GameTooltip:AddLine(T("Arrastar ou roda do mouse: rolar a lista", "Drag or mouse wheel: scroll the list"), 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.lines[i] = l
    return l
end

-- Altura do cabeçalho (título + XP + estimativa + local), para a lista nunca ficar por baixo dele
function UI:HeaderHeight()
    local h = 6 + 18 + 2
    h = h + (self.xp:GetStringHeight() or 12) + 2
    local e = self.est:GetText()
    if e and e ~= "" then h = h + (self.est:GetStringHeight() or 12) + 2 end
    h = h + 13 + 14 -- espaço extra + linha separadora antes da lista
    return math.floor(h + 0.5)
end

-- Ao clicar numa quest: seleciona a mesma quest no log/rastreador/mapa do jogo
function UI:SelectInGame(s)
    local q = s and s.q
    if not q or not RX.Q:InLog(q) then return end
    -- em combate o rastreador/mapa do jogo ficam protegidos: não mexe neles (evita "ação bloqueada")
    if InCombatLockdown and InCombatLockdown() then self.selectedQuest = q; return end
    if C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID then
        pcall(C_SuperTrack.SetSuperTrackedQuestID, q)          -- destaca no mapa e no rastreador
    end
    if C_QuestLog and C_QuestLog.SetSelectedQuest then
        pcall(C_QuestLog.SetSelectedQuest, q)                   -- seleciona no log de quests
    elseif GetQuestLogIndexByID and SelectQuestLogEntry then
        local idx = GetQuestLogIndexByID(q)
        if idx and idx > 0 then pcall(SelectQuestLogEntry, idx) end
    end
    -- garante que ela aparece na lista de objetivos (rastreador)
    if C_QuestLog and C_QuestLog.AddQuestWatch then
        pcall(C_QuestLog.AddQuestWatch, q)
    elseif AddQuestWatch and GetQuestLogIndexByID then
        local idx = GetQuestLogIndexByID(q)
        if idx and idx > 0 then pcall(AddQuestWatch, idx) end
    end
    if QuestMapFrame and QuestMapFrame.IsShown and QuestMapFrame:IsShown() and QuestMapFrame_ShowQuestDetails then
        pcall(QuestMapFrame_ShowQuestDetails, q)
    end
    self.selectedQuest = q
end

function UI:RefreshXP()
    if not self.xp then return end
    local lvl = UnitLevel("player")
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local rest = GetXPExhaustion and GetXPExhaustion() or 0
    local txt = string.format("%s %d  |cffaaaaaa%.0f%%|r", T("Nível", "Level"), lvl, max > 0 and (cur / max * 100) or 0)
    if rest and rest > 0 and max > 0 then txt = txt .. string.format("  |cff4080ff%s %.0f%%|r", T("descansado", "rested"), rest / max * 100) end
    local ph, mins = RX:XPPerHour()
    if ph then txt = txt .. string.format(T("  |cff40ff40%.1fk xp/h|r ~%.0f min p/ upar", "  |cff40ff40%.1fk xp/h|r ~%.0f min to level"), ph / 1000, mins) end
    self.xp:SetText(txt)
end

function UI:Refresh()
    if not self.frame or not self.frame:IsShown() then return end
    local f = self.frame
    local W, Hh = f:GetWidth(), f:GetHeight()
    local barH = self:LayoutBar()
    local steps, final, travel, g = RX:StepsWithTravel(40)
    local turnin = RX.db.turninMode
    local nearby = RX.db.nearbyMode
    local readyCount, readyXP = RX.Turnin:Count()
    -- Modo Entregas sem nada para entregar: volta sozinho para o guia
    if turnin and #steps == 0 then
        RX.db.turninMode = false
        RX:Print(T("Nenhuma quest pronta para entregar. Voltando ao guia.", "No quests ready to turn in. Back to the guide."))
        return RX:Update(true)
    end
    -- textos dos botões que mudam com o modo
    for _, b in ipairs(self.barButtons) do
        if b.def.key == "turnin" then
            -- 2 linhas: "Entregas (N)" e embaixo o XP total de entregar tudo
            if turnin then
                b:SetText(T("Voltar ao guia", "Back to guide"))
            elseif readyCount > 0 then
                b:SetText(T("Entregas", "Turn-ins") .. " |cffffffff(" .. readyCount .. ")|r\n|cff40ff40+" .. fmtXP(readyXP) .. " xp|r")
            else
                b:SetText(T("Entregas", "Turn-ins"))
            end
            fitButton(b, 70)
        elseif b.def.key == "nearby" then
            b:SetText(T(nearby and "Voltar ao guia" or "Perto de mim", nearby and "Back to guide" or "Nearby"))
            fitButton(b, 50)
        end
    end
    barH = self:LayoutBar()
    if turnin then
        self.title:SetText("|cff40ff40" .. T("Modo Entregas", "Turn-in mode") .. "|r  " .. string.format(T("%d prontas · +%s xp", "%d ready · +%s xp"), readyCount, fmtXP(readyXP)))
    elseif nearby then
        self.title:SetText("|cff40c0ff" .. T("Perto de mim", "Nearby") .. "|r  " .. T("quests de todos os guias, mais perto primeiro", "quests from every guide, nearest first"))
    else
        self.title:SetText((g and RX:GuideName(g) or T("Nenhum guia - clique aqui", "No guide - click here")) .. (g and g.tag == "forever" and " |cff40c0ff[Forever]|r" or "")
            .. (RX:ShowAllHere() and (" |cff40ff40" .. T("[tudo]", "[all]") .. "|r") or ""))
    end
    self:RefreshXP()
    -- local detectado
    local locText, locGuide = RX.Advisor:Line()
    self.loc:SetText(locText and ("|cffaaaaaa" .. T("Local:", "Location:") .. "|r " .. locText) or "")
    self.locGuide = locGuide
    if nearby then
        self.est:SetText(T("Mostra até 40 quests no seu continente. Quadradinho tira uma quest desta lista.", "Shows up to 40 quests on your continent. The checkbox removes a quest from this list."))
    elseif turnin then
        self.est:SetText(T("Siga a seta: entregue de uma em uma. Quadradinho tira a quest desta lista.", "Follow the arrow: turn them in one by one. The checkbox removes a quest from this list."))
    elseif g then
        local xp = RX:GuideXPEstimate(g)
        local lv = RX:LevelAfterXP(xp)
        local col = (lv + 0.001 >= (g.max or 60)) and "|cff40ff40" or "|cffffd040"
        self.est:SetText(string.format(T("Quests restantes: |cff40ff40%s xp|r  -> %schega ~nível %.1f|r%s", "Remaining quests: |cff40ff40%s xp|r  -> %sreach ~level %.1f|r%s"),
            fmtXP(xp), col, lv, lv + 0.001 < (g.max or 60) and ("  |cffaaaaaa" .. T("(complete com mobs ou o próximo guia)", "(top up with mobs or the next guide)") .. "|r") or ""))
    else
        self.est:SetText("")
    end
    -- prontas para entregar
    local ready = turnin and {} or RX:ReadyElsewhere(g, steps)
    local bottomReserve = barH + 30
    if not turnin and readyCount >= 4 then
        -- muitas quests prontas: sugere o Modo Entregas
        self.ready:SetText(string.format("|cff40ff40" .. T("%d quests prontas para entregar - clique para o Modo Entregas", "%d quests ready to turn in - click for Turn-in mode") .. "|r", readyCount))
        bottomReserve = bottomReserve + 14
    elseif #ready > 0 then
        local names = {}
        for i = 1, math.min(3, #ready) do table.insert(names, RX:QName(ready[i])) end
        self.ready:SetText("|cff40ff40" .. T("Prontas p/ entregar:", "Ready to turn in:") .. "|r " .. table.concat(names, ", ") .. (#ready > 3 and (" +" .. (#ready - 3)) or ""))
        bottomReserve = bottomReserve + 14
    else
        self.ready:SetText("")
    end
    -- área rolável: do topo (abaixo do XP/local) até acima do rodapé
    self.scroll:ClearAllPoints()
    local headH = self:HeaderHeight()
    self.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -headH)
    -- linha que separa o cabeçalho da lista
    self.headSep:ClearAllPoints()
    self.headSep:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -(headH - 5))
    self.headSep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -(headH - 5))
    self.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, bottomReserve)
    local lineW = W - 40
    local textW = lineW - 44
    self.content:SetWidth(lineW)
    local y = 0
    local shown = 0
    for i = 1, #steps do
        local s = steps[i]
        local l = self:GetLine(i)
        l.step = s
        local isz = RX.db.iconSize or 16
        l.icon:SetSize(isz, isz)
        l.typeIcon:SetSize(isz, isz)
        l.icon:SetTexture(self:StepIcon(s))
        l.icon:SetDesaturated(s.t == "C")
        local ti = self:QuestTypeIcon(s)
        l.text:ClearAllPoints()
        if ti then
            l.typeIcon:SetTexture(ti); l.typeIcon:Show()
            -- ícones de item têm borda: corta a borda para o desenho ficar maior
            if ti:find("Icons", 1, true) then l.typeIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else l.typeIcon:SetTexCoord(0, 1, 0, 1) end
            l.text:SetPoint("TOPLEFT", l.typeIcon, "TOPRIGHT", 3, 0)
        else
            l.typeIcon:Hide()
            l.text:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", 4, 0)
        end
        local tw = ti and (textW - isz - 3) - (isz - 16) or textW - (isz - 16)
        l.text:SetWidth(tw)
        l.sub:SetWidth(tw - 4)   -- mesma largura do título: não passa da borda da janela
        local txt, sub = self:StepText(s)
        l.text:SetText(txt)
        l.sub:SetText(sub or "")
        local h = l.text:GetStringHeight() + (sub and (l.sub:GetStringHeight() + 6) or 0) + 6
        h = math.max(h, isz + 4)
        -- "[abandonar quest]" em toda quest da lista (igual ao quadradinho); só abandona se estiver no seu log
        if s.q then
            l.abandon.inLog = RX.Q:InLog(s.q) and true or false
            l.abandon:Paint(false)
            l.abandon:Show(); h = h + 12
        else l.abandon:Hide() end
        if s.q and s.q == self.selectedQuest then l.hl:SetColorTexture(0.2, 0.6, 1, 0.18); l.hl:Show()
        elseif i == 1 then l.hl:SetColorTexture(1, 0.5, 0, 0.12); l.hl:Show()
        else l.hl:Hide() end
        l.check:SetChecked(false)
        l.check:Show()
        l:ClearAllPoints()
        l:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
        l:SetSize(lineW - 4, h)
        l:Show()
        y = y - h - 10
        shown = i
    end
    for i = shown + 1, #self.lines do self.lines[i].step = nil; self.lines[i]:Hide() end
    for _, ln in ipairs(self.lines) do ln.emptyAction = nil end
    if not g and #steps == 0 and not turnin and not nearby then
        local l = self:GetLine(1)
        l.step = nil
        l.check:Hide()
        l.abandon:Hide()
        l.icon:SetTexture(RX.ICON); l.icon:SetDesaturated(false); l.typeIcon:Hide()
        l.text:ClearAllPoints(); l.text:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", 4, 0)
        l.text:SetWidth(textW)
        l.text:SetText("|cffffd100" .. T("Nenhum guia selecionado.", "No guide selected.") .. "|r " .. T("Clique em Guias para escolher o próximo.", "Click Guides to pick the next one."))
        l.sub:SetText("")
        l:ClearAllPoints(); l:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
        l:SetSize(lineW - 4, 30); l:Show()
        y = y - 34
    end
    if g and #steps == 0 then
        local l = self:GetLine(1)
        l.step = nil
        l.check:Hide()
        l.abandon:Hide()
        l.icon:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready"); l.icon:SetDesaturated(false); l.typeIcon:Hide()
        l.text:ClearAllPoints(); l.text:SetPoint("TOPLEFT", l.icon, "TOPRIGHT", 4, 0)
        local n = RX:NextGuide(g)
        local hs = RX:HiddenSummary(g)
        l.text:SetWidth(textW)
        l.sub:SetWidth(textW - 4)
        if hs.total > 0 and not turnin and not nearby then
            -- ainda há quests não feitas, mas o estilo/nível/corrente esconde: explica e oferece mostrar
            l.icon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
            l.text:SetText("|cffffd100" .. string.format(T("Nada para você aqui com o seu estilo (%d quests escondidas).", "Nothing for you here with your style (%d hidden quests)."), hs.total) .. "|r")
            local parts = {}
            if hs.estilo > 0 then parts[#parts + 1] = string.format(T("%d lentas/de coleta (o estilo pula)", "%d slow/collecting (your style skips)"), hs.estilo) end
            if hs.cinza > 0 then parts[#parts + 1] = string.format(T("%d cinzas (pouco XP)", "%d grey (little XP)"), hs.cinza) end
            if hs.pre > 0 then parts[#parts + 1] = string.format(T("%d precisam de uma quest anterior que você não fez", "%d need an earlier quest you haven't done"), hs.pre) end
            if hs.outro > 0 then parts[#parts + 1] = string.format(T("%d por outro motivo (nível, item, masmorra...)", "%d for another reason (level, item, dungeon...)"), hs.outro) end
            local canShow = (hs.estilo + hs.cinza) > 0 and not RX:ShowAllHere()
            l.sub:SetText("|cffd0d0d0" .. table.concat(parts, " · ") .. "|r" ..
                (canShow and ("\n|cff40ff40" .. T("Clique aqui para mostrar as lentas e cinzas deste guia.", "Click here to show the slow and grey quests of this guide.") .. "|r") or ""))
            if canShow then l.emptyAction = function() RX:ToggleShowAll() end end
            local h = l.text:GetStringHeight() + l.sub:GetStringHeight() + 12
            l:ClearAllPoints(); l:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
            l:SetSize(lineW - 4, h); l:Show()
            y = y - h - 4
        else
            l.text:SetText("|cff40ff40" .. T("Guia concluído!", "Guide complete!") .. "|r " ..
                (n and (T("Próximo: ", "Next: ") .. RX:GuideName(n)) or T("Abra o menu de guias para escolher o próximo.", "Open the guide menu to pick the next one.")))
            l.sub:SetText("")
            l:ClearAllPoints(); l:SetPoint("TOPLEFT", self.content, "TOPLEFT", 4, y)
            l:SetSize(lineW - 4, 30); l:Show()
            y = y - 34
        end
    end
    self.content:SetHeight(math.max(1, -y))
    -- barra de rolagem só aparece quando há mais passos do que cabem
    local need = self:ScrollMax() > 1
    if self.scrollBar then
        if need then self.scrollBar:Show() else self.scrollBar:Hide() end
    end
    self:ScrollTo(self.scroll:GetVerticalScroll() or 0)
    -- modos
    local o = RX.db
    local styleName = T("Personalizado", "Custom")
    for _, st in ipairs(RX.Styles) do if st.id == o.style then styleName = LF(st, "name") end end
    local m = { "|cffffd100" .. styleName .. "|r" }
    if o.skipCollect then table.insert(m, "|cffff9050" .. T("sem coleta", "no collecting") .. "|r") end
    if o.collectMax then table.insert(m, "|cffff9050" .. string.format(T("coleta até %d", "collect up to %d"), o.collectMax) .. "|r") end
    if o.speedrun and o.style == "custom" then table.insert(m, "|cffd0d0d0" .. T("sem lentas", "no slow") .. "|r") end
    if o.showElite then table.insert(m, "|cffff6060" .. T("elites", "elites") .. "|r") end
    if o.showDungeon then table.insert(m, "|cff8080ff" .. T("masmorras", "dungeons") .. "|r") end
    table.insert(m, RX:IsPT() and "PT" or "EN")
    if g then
        local prog = RX:GuideProgress(g.id)
        table.insert(m, string.format("|cffaaaaaa%s %d/%d|r", T("passo", "step"), math.min(prog.index, #g.steps), #g.steps))
    end
    self.modes:SetText(table.concat(m, "  "))
end

function UI:SkipCurrent()
    local steps = RX:VisibleSteps(1)
    if steps[1] then RX:MarkStep(steps[1], true) end
end

function UI:StepBack()
    local g = RX:CurrentGuide()
    if not g then return end
    local prog = RX:GuideProgress(g.id)
    for i = (prog.index or 1) - 1, 1, -1 do
        if prog.done[i] then prog.done[i] = nil; RX:Update(true); return end
    end
end

----------------------------------------------------------------------
-- Menu suspenso de guias (rota / estilo / faixas de nível)
----------------------------------------------------------------------
local function guideXP(g)
    if g.totalXP then return g.totalXP end
    local t = 0
    for _, s in ipairs(g.steps) do if s.t == "T" then t = t + (s.xp or (s.lvl or 0) * 90) end end
    g.totalXP = t
    return t
end

-- Qualquer janela pode ser arrastada pelo fundo/título
function UI:MakeDraggable(frame)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) if not RX.db.locked then self:StartMoving() end end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); self.userMoved = true end)
end

-- Abre a janela AO LADO da janela do guia (lado com mais espaço), sem cobrir a lista
function UI:PlaceBeside(frame)
    local main = self.frame
    frame:ClearAllPoints()
    if not main or not main:IsShown() then frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0) return end
    local cx = main:GetCenter() or 0
    local scale = (main:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    local screenW = UIParent:GetWidth() or 1920
    if cx * scale > screenW / 2 then
        frame:SetPoint("TOPRIGHT", main, "TOPLEFT", -6, 0)   -- guia está na direita: abre à esquerda
    else
        frame:SetPoint("TOPLEFT", main, "TOPRIGHT", 6, 0)    -- guia está na esquerda: abre à direita
    end
end

function UI:ToggleMenu()
    if self.menu and self.menu:IsShown() then self.menu:Hide() return end
    self:BuildMenu()
end

function UI:BuildMenu()
    if not self.menu then
        local m = CreateFrame("Frame", "RouteXPMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate")
        backdrop(m, 0.97)
        m:SetFrameStrata("DIALOG")
        m:SetSize(420, 520)
        m:SetClampedToScreen(true)
        m:EnableMouse(true)
        UI:MakeDraggable(m)
        tinsert(UISpecialFrames, "RouteXPMenu")
        local close = CreateFrame("Button", nil, m, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", 2, 2)
        local sf = CreateFrame("ScrollFrame", "RouteXPMenuScroll", m, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 8, -24)
        sf:SetPoint("BOTTOMRIGHT", -28, 8)
        local child = CreateFrame("Frame", nil, sf)
        child:SetSize(380, 10)
        sf:SetScrollChild(child)
        m.titleText = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        m.titleText:SetPoint("TOPLEFT", 10, -8)
        m.child, m.scroll, m.widgets = child, sf, {}
        m.expanded = {}
        m:Hide() -- frames nascem visíveis; esconder para que a primeira abertura posicione ao lado
        self.menu = m
    end
    local m = self.menu
    m.titleText:SetText(ORANGE .. T("Escolha seu guia", "Choose your guide") .. "|r  |cff909090" .. T("(arraste aqui para mover)", "(drag here to move)") .. "|r")
    for _, w in ipairs(m.widgets) do w:Hide(); w:SetParent(nil) end
    wipe(m.widgets)
    -- só reposiciona ao abrir; ao clicar numa opção o menu fica onde você deixou
    if not m:IsShown() then self:PlaceBeside(m) end
    m:Show()

    local child = m.child
    local y = -2
    local function label(text, font, indent)
        local holder = CreateFrame("Frame", nil, child)
        local fs = holder:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
        fs:SetPoint("TOPLEFT", child, "TOPLEFT", indent or 2, y)
        fs:SetWidth(370 - (indent or 2)); fs:SetJustifyH("LEFT")
        fs:SetText(text)
        table.insert(m.widgets, holder)
        y = y - fs:GetStringHeight() - 6
        return fs
    end
    local function row(text, sub, onClick, selected, indent, tooltipText)
        local rowW = 375 - (indent or 0)
        local b = CreateFrame("Button", nil, child, BackdropTemplateMixin and "BackdropTemplate")
        backdrop(b, selected and 0.9 or 0.45)
        if selected then b:SetBackdropBorderColor(1, 1, 0, 1) end
        b:SetPoint("TOPLEFT", indent or 0, y)
        b:SetWidth(rowW)
        local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", 8, -7); t:SetWidth(rowW - 16); t:SetJustifyH("LEFT"); t:SetWordWrap(true)
        t:SetText(text)
        local h = t:GetStringHeight() + 14
        if sub then
            local d = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4); d:SetWidth(rowW - 16); d:SetJustifyH("LEFT"); d:SetWordWrap(true)
            d:SetSpacing(2)
            d:SetText(sub)
            h = h + d:GetStringHeight() + 4
        end
        b:SetHeight(h)
        b:SetScript("OnClick", onClick)
        UI.ForwardDrag(b, m)
        if tooltipText then tip(b, tooltipText) end
        table.insert(m.widgets, b)
        y = y - h - 6
        return b
    end

    -- MODO ENTREGAS
    local rc = RX.Turnin:Count()
    label("|cffffd100" .. T("ENTREGAS", "TURN-INS") .. "|r " .. T("(limpar quests prontas e liberar a bolsa)", "(clear ready quests and free bag space)"), "GameFontNormal")
    row((RX.db.turninMode and "|cff40ff40> |r" or "") .. string.format(T("Modo Entregas - %d quests prontas", "Turn-in mode - %d quests ready"), rc),
        "|cffaaaaaa" .. T("Mostra só as quests prontas do seu log e monta a rota mais curta: seu continente primeiro, do NPC mais perto ao mais longe, e sugere a Pedra de Regresso quando compensa.",
            "Shows only ready quests from your log and builds the shortest route: your continent first, nearest NPC to farthest, and suggests the Hearthstone when worth it.") .. "|r",
        function() RX.Turnin:Toggle(); UI:BuildMenu() end, RX.db.turninMode, 0)
    y = y - 6
    -- ROTA
    label("|cffffd100" .. T("ROTA", "ROUTE") .. "|r " .. T("(sequência de zonas até o 60)", "(zone sequence up to 60)"), "GameFontNormal")
    for _, r in ipairs(RX.Routes) do
        row((r.id == RX.db.route and "|cff40ff40> |r" or "") .. LF(r, "name"), "|cffaaaaaa" .. (LF(r, "source") or "") .. "|r", function()
            RX:SetRoute(r.id); UI:BuildMenu()
        end, r.id == RX.db.route, 0, LF(r, "desc"))
    end
    -- ESTILO
    y = y - 6
    label("|cffffd100" .. T("ESTILO", "STYLE") .. "|r " .. T("(o que pular)", "(what to skip)"), "GameFontNormal")
    local holder = CreateFrame("Frame", nil, child)
    holder:SetPoint("TOPLEFT", 0, y); holder:SetSize(375, 24)
    table.insert(m.widgets, holder)
    local x = 0
    for _, st in ipairs(RX.Styles) do
        local b = smallButton(holder, (st.id == RX.db.style and "* " or "") .. LF(st, "name"), 60, function() RX:ApplyStyle(st.id); UI:BuildMenu() end, LF(st, "desc"))
        fitButton(b, 60)
        b:SetPoint("LEFT", x, 0)
        x = x + b:GetWidth() + BTN_GAP
    end
    y = y - 32

    -- GUIAS POR FAIXA
    label("|cffffd100" .. T("GUIAS POR NÍVEL", "GUIDES BY LEVEL") .. "|r  " .. T("(clique na faixa para abrir/fechar)", "(click a range to open/close)"), "GameFontNormal")
    local lvl = UnitLevel("player")
    local inRoute = {}
    for i, id in ipairs(RX:CurrentRoute().guides) do inRoute[id] = i end
    local cur = RX:CurrentGuide()
    for _, br in ipairs(RX.Brackets) do
        local lo, hi = br[1], br[2]
        local mine = lvl >= lo and lvl < hi
        if m.expanded[lo] == nil then m.expanded[lo] = mine end
        local list = {}
        for _, g in ipairs(RX:SortedGuides()) do
            if g.min < hi and g.max > lo then table.insert(list, g) end
        end
        table.sort(list, function(a, b)
            local ra, rb = inRoute[a.id] or 99, inRoute[b.id] or 99
            if ra ~= rb then return ra < rb end
            if (a.kind == "zona") ~= (b.kind == "zona") then return a.kind == "zona" end
            return a.min < b.min
        end)
        row(string.format("%s%s %d-%d|r  |cffaaaaaa(%d %s)|r%s", mine and "|cff40ff40" or "|cffffffff", T("Nível", "Level"), lo, hi, #list,
            T("guias", "guides"), mine and ("  |cff40ff40" .. T("<- você", "<- you") .. "|r") or ""), nil, function()
            m.expanded[lo] = not m.expanded[lo]; UI:BuildMenu()
        end, false, 0)
        if m.expanded[lo] then
            for _, g in ipairs(list) do
                local prog = RX:GuideProgress(g.id)
                local pct = #g.steps > 0 and math.min(100, (prog.index - 1) / #g.steps * 100) or 0
                local tags = ""
                if inRoute[g.id] then tags = tags .. " |cff40ff40" .. T("[na rota]", "[on route]") .. "|r" end
                if g.tag == "forever" then tags = tags .. " |cff40c0ff[Forever]|r" end
                if g.kind ~= "zona" then tags = tags .. " |cffaaaaaa" .. T("[curto]", "[short]") .. "|r" end
                local sub = string.format("%d-%d  |  %d quests  |  ~%s xp%s", g.min, g.max, g.numQuests or 0, fmtXP(guideXP(g)),
                    pct > 0 and string.format(T("  |  %.0f%% feito", "  |  %.0f%% done"), pct) or "")
                row(RX:GuideName(g) .. tags .. (cur == g and ("  |cffffff00" .. T("(ativo)", "(active)") .. "|r") or ""), sub, function()
                    RX:SetGuide(g.id); m:Hide()
                end, cur == g, 14, LF(g, "desc"))
            end
        end
    end
    child:SetHeight(-y + 10)
end

----------------------------------------------------------------------
-- Painel (log / zonas / dicas / opções)
----------------------------------------------------------------------
local TABS = {
    { "zones", "Onde upar", "Where to level" }, { "tips", "Dicas", "Tips" }, { "options", "Opções", "Options" },
}

function UI:CreatePanel()
    local p = CreateFrame("Frame", "RouteXPPanel", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    backdrop(p, 0.95)
    p:SetSize(560, 490)
    p:SetPoint("CENTER")
    p:SetFrameStrata("DIALOG")
    UI:MakeDraggable(p)
    p.hint = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.hint:SetPoint("TOPRIGHT", -30, -14)
    p:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "RouteXPPanel")
    local close = CreateFrame("Button", nil, p, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    p.title:SetPoint("TOPLEFT", 12, -10)
    p.tabs = {}
    for _, t in ipairs(TABS) do
        local b = smallButton(p, t[2], 90, function() UI:ShowPanel(t[1]) end)
        b.def = t
        UI.ForwardDrag(b, p)
        table.insert(p.tabs, b)
    end

    local sf = CreateFrame("ScrollFrame", "RouteXPPanelScroll", p, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -66)
    sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(510, 10)
    sf:SetScrollChild(child)
    p.scroll, p.child = sf, child
    p.widgets = {}
    p:Hide()
    self.panel = p
end

function UI:LayoutTabs()
    -- abas do mesmo tamanho (a maior manda), com a letra cabendo em qualquer idioma
    local w = 90
    for _, b in ipairs(self.panel.tabs) do
        b:SetText(T(b.def[2], b.def[3]))
        fitButton(b, 70)
        w = math.max(w, b:GetWidth())
    end
    local x = 12
    for _, b in ipairs(self.panel.tabs) do
        b:SetWidth(w)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", self.panel, "TOPLEFT", x, -36)
        x = x + w + BTN_GAP
    end
end

function UI:ClearPanel()
    local p = self.panel
    for _, w in ipairs(p.widgets) do w:Hide(); w:SetParent(nil) end
    wipe(p.widgets)
    p.scroll:SetVerticalScroll(0)
end

function UI:AddText(text, y, font)
    local p = self.panel
    local holder = CreateFrame("Frame", nil, p.child)
    local fs = holder:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetPoint("TOPLEFT")
    fs:SetWidth(500)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    local h = fs:GetStringHeight()
    holder:SetSize(500, h)
    holder:SetPoint("TOPLEFT", 4, y)
    table.insert(p.widgets, holder)
    return y - h - 6
end

function UI:LogText()
    local Q = RX.Q
    local g = RX:CurrentGuide()
    local where = {}
    if g then
        for _, s in ipairs(g.steps) do
            if s.q and not where[s.q] and s.t ~= "A" then where[s.q] = s end
        end
    end
    local blocked = g and RX:BuildQuestFilter(g) or {}
    local lines = {}
    table.insert(lines, string.format(T("Quests no log: |cffffffff%d / %d|r   Guia: |cffffff00%s|r\n", "Quests in log: |cffffffff%d / %d|r   Guide: |cffffff00%s|r\n"),
        Q:Count(), Q:Max(), g and RX:GuideName(g) or T("nenhum", "none")))
    local inGuide, outGuide = {}, {}
    for id, e in pairs(Q.log) do
        local s = where[id]
        local status = e.ready and ("|cff40ff40" .. T("PRONTA p/ entregar", "READY to turn in") .. "|r") or ("|cffd0d0d0" .. T("em andamento", "in progress") .. "|r")
        local title = e.title or ("Quest " .. id)
        if s then
            local extra = ""
            if RX:CharState().skipped[id] then extra = " |cffff6060" .. T("(pulada por você)", "(skipped by you)") .. "|r"
            elseif blocked[id] then extra = " |cffff9050" .. T("(fora do estilo atual)", "(outside the current style)") .. "|r" end
            table.insert(inGuide, string.format("|cff40ff40%s|r %s - %s%s", T("[no guia]", "[in guide]"), title, status, extra))
        else
            table.insert(outGuide, string.format("|cffaaaaaa%s|r %s - %s", T("[fora do guia]", "[not in guide]"), title, status))
        end
    end
    table.sort(inGuide); table.sort(outGuide)
    table.insert(lines, "|cffff7f00" .. T("QUESTS DO SEU LOG QUE ESTÃO NO GUIA", "QUESTS IN YOUR LOG THAT ARE IN THE GUIDE") .. "|r")
    if #inGuide == 0 then table.insert(lines, T("  (nenhuma)", "  (none)")) end
    for _, l in ipairs(inGuide) do table.insert(lines, "  " .. l) end
    table.insert(lines, "\n|cffff7f00" .. T("QUESTS DO LOG FORA DESTE GUIA", "LOG QUESTS NOT IN THIS GUIDE") .. "|r  |cffaaaaaa" ..
        T("(considere abandonar se estiverem cinzas ou longe)", "(consider abandoning them if grey or far away)") .. "|r")
    if #outGuide == 0 then table.insert(lines, T("  (nenhuma)", "  (none)")) end
    for _, l in ipairs(outGuide) do table.insert(lines, "  " .. l) end
    if g then
        local total, done = 0, 0
        for _, s in ipairs(g.steps) do
            if s.t == "T" and s.q then total = total + 1; if Q:IsCompleted(s.q) then done = done + 1 end end
        end
        table.insert(lines, string.format(T("\nQuests deste guia já entregues: |cff40ff40%d / %d|r", "\nQuests of this guide already turned in: |cff40ff40%d / %d|r"), done, total))
        local sk = 0
        for _ in pairs(RX:CharState().skipped) do sk = sk + 1 end
        table.insert(lines, string.format(T("Quests que você pulou (todas as rotas): %d", "Quests you skipped (all routes): %d"), sk))
    end
    table.insert(lines, "\n|cffaaaaaa" .. T("O guia lê o seu log o tempo todo: quest aceita some do 'Aceitar', objetivo completo some do 'Fazer' e quest entregue sai da rota.",
        "The guide reads your log all the time: an accepted quest leaves 'Accept', completed objectives leave 'Complete' and a turned-in quest leaves the route.") .. "|r")
    return table.concat(lines, "\n")
end

function UI:ShowPanel(which, sub)
    if which == "guides" then return self:ToggleMenu() end
    if not self.panel then self:CreatePanel() end
    local p = self.panel
    self:LayoutTabs()
    self:ClearPanel()
    if not p:IsShown() then self:PlaceBeside(p) end
    p.hint:SetText("|cff909090" .. T("arraste para mover", "drag to move") .. "|r")
    p:Show()
    local y = -4
    if which == "now" then which = "zones" end
    if which == "zones" then
        -- Onde upar: primeiro onde você está agora e o que fazer, depois as sugestões por nível
        p.title:SetText(ORANGE .. T("Onde upar", "Where to level") .. "|r")
        y = self:AddText("|cffff7f00" .. T("AGORA: ONDE VOCÊ ESTÁ", "NOW: WHERE YOU ARE") .. "|r", y, "GameFontNormal")
        y = self:AddText(RX.Advisor:Text(), y - 2)
        local hb = CreateFrame("Frame", nil, p.child); hb:SetSize(500, 26); hb:SetPoint("TOPLEFT", 4, y - 4)
        table.insert(p.widgets, hb)
        local b1 = smallButton(hb, T("Usar o guia desta zona", "Use this zone's guide"), 150, function() RX.Advisor:UseHere(); UI:ShowPanel("zones") end)
        fitButton(b1, 150); b1:SetPoint("LEFT")
        local b2 = smallButton(hb, T("Modo Entregas", "Turn-in mode"), 120, function() RX.Turnin:Toggle(true) end)
        fitButton(b2, 120); b2:SetPoint("LEFT", b1, "RIGHT", BTN_GAP, 0)
        local b3 = smallButton(hb, T("Atualizar", "Refresh"), 90, function() UI:ShowPanel("zones") end)
        fitButton(b3, 90); b3:SetPoint("LEFT", b2, "RIGHT", BTN_GAP, 0)
        y = y - 40
        y = self:AddText("|cffff7f00" .. T("SUGESTÕES: ONDE UPAR NO SEU NÍVEL", "SUGGESTIONS: WHERE TO LEVEL AT YOUR LEVEL") .. "|r", y, "GameFontNormal")
        y = self:AddText(RX.ZonesText(UnitLevel("player")), y - 2)
    elseif which == "now_old" then
        -- sub-abas: Visão geral / Solo / Duo / Masmorra
        -- Solo/Duo/Masmorra e o Cronômetro agora ficam no menu Guias > Grind & Masmorras
        sub = "overview"
        p.title:SetText(ORANGE .. T("Agora: onde você está e o que fazer", "Now: where you are and what to do") .. "|r")
        if sub == "overview" then
            y = self:AddText(RX.Advisor:Text(), y)
            local hb = CreateFrame("Frame", nil, p.child); hb:SetSize(500, 26); hb:SetPoint("TOPLEFT", 4, y - 4)
            table.insert(p.widgets, hb)
            local b1 = smallButton(hb, T("Usar o guia desta zona", "Use this zone's guide"), 150, function() RX.Advisor:UseHere(); UI:ShowPanel("now") end)
            fitButton(b1, 150); b1:SetPoint("LEFT")
            local b2 = smallButton(hb, T("Modo Entregas", "Turn-in mode"), 120, function() RX.Turnin:Toggle(true) end)
            fitButton(b2, 120); b2:SetPoint("LEFT", b1, "RIGHT", BTN_GAP, 0)
            local b3 = smallButton(hb, T("Atualizar", "Refresh"), 90, function() UI:ShowPanel("now") end)
            fitButton(b3, 90); b3:SetPoint("LEFT", b2, "RIGHT", BTN_GAP, 0)
            y = y - 36
        else
            y = self:AddText(RX.Leveling:Text(sub), y)
            if sub == "solo" or sub == "duo" then
                y = self:AddText("|cffff7f00" .. T("PONTOS DE GRIND (do mais rendoso para o menos)", "GRIND SPOTS (best first)") .. "|r", y - 4, "GameFontNormal")
                local spots = RX.Leveling:GrindSpots(sub, 6)
                if #spots == 0 then y = self:AddText(T("  (nenhum ponto conhecido no seu continente para o seu nível)", "  (no known spot on your continent for your level)"), y) end
                for _, sp in ipairs(spots) do
                    local row = CreateFrame("Frame", nil, p.child); row:SetSize(500, 34); row:SetPoint("TOPLEFT", 4, y)
                    table.insert(p.widgets, row)
                    local info = C_Map.GetMapInfo(sp.m)
                    local fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    fs:SetPoint("TOPLEFT", 0, -2); fs:SetWidth(400); fs:SetJustifyH("LEFT")
                    fs:SetText(string.format(T("|cffffd100%s|r nv %d-%d · %d juntos · %s (%.0f, %.0f)\n~%.0f xp por mob · %s", "|cffffd100%s|r lvl %d-%d · %d together · %s (%.0f, %.0f)\n~%.0f xp per mob · %s"),
                        (RX:IsPT() and sp.pname) or sp.name, sp.lo, sp.hi, sp.count, info and info.name or "?", sp.x, sp.y, sp.xpk,
                        sp.dist > 0 and string.format(T("~%.0f m de você", "~%.0f m from you"), sp.dist * 0.9144) or ""))
                    local bt = smallButton(row, T("Seta", "Arrow"), 60, function()
                        RX.Arrow:PointTo(RX.Leveling:SpotStep(sp), true); RX:Update(true)
                    end, T("Aponta a seta, a rota e o mapa para este ponto", "Points the arrow, route and map to this spot"))
                    bt:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
                    y = y - 38
                end
            end
            local hb = CreateFrame("Frame", nil, p.child); hb:SetSize(500, 26); hb:SetPoint("TOPLEFT", 4, y - 4)
            table.insert(p.widgets, hb)
            local b3 = smallButton(hb, T("Atualizar", "Refresh"), 90, function() UI:ShowPanel("now", sub) end)
            fitButton(b3, 90); b3:SetPoint("LEFT")
            local b4 = smallButton(hb, T("Parar de apontar", "Stop pointing"), 120, function() RX.Arrow:ClearManual(); RX:Update(true) end)
            fitButton(b4, 120); b4:SetPoint("LEFT", b3, "RIGHT", BTN_GAP, 0)
            y = y - 36
        end
    elseif which == "log" then
        p.title:SetText(ORANGE .. T("Meu log x guia", "My log vs guide") .. "|r")
        y = self:AddText(self:LogText(), y)
        local r = smallButton(p.child, T("Atualizar", "Refresh"), 90, function() RX:Update(true); UI:ShowPanel("log") end)
        fitButton(r, 90)
        r:SetPoint("TOPLEFT", 2, y - 4); table.insert(p.widgets, r); y = y - 32
    elseif which == "tips" then
        p.title:SetText(ORANGE .. T("Dicas de speedrun e duo", "Speedrun and duo tips") .. "|r")
        y = self:AddText(RX.TipsText(), y)
    elseif which == "options" then
        p.title:SetText(ORANGE .. T("Opções", "Options") .. "|r")
        local function section(text, sub)
            y = y - 8
            y = self:AddText("|cffffd100" .. text .. "|r" .. (sub and ("  |cff909090" .. sub .. "|r") or ""), y, "GameFontNormal")
            local line = CreateFrame("Frame", nil, p.child); line:SetSize(500, 1); line:SetPoint("TOPLEFT", 4, y + 2)
            local tx = line:CreateTexture(nil, "ARTWORK"); tx:SetAllPoints(); tx:SetColorTexture(1, 0.5, 0, 0.3)
            table.insert(p.widgets, line)
            y = y - 6
        end
        local function check(key, label, desc, onChange, indent)
            local holder = CreateFrame("Frame", nil, p.child)
            holder:SetPoint("TOPLEFT", 4 + (indent or 0), y)
            local cb = CreateFrame("CheckButton", nil, holder, "UICheckButtonTemplate")
            cb:SetPoint("TOPLEFT", -4, 2)
            cb:SetChecked(RX.db[key] and true or false)
            local lab = holder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lab:SetPoint("TOPLEFT", 28, -4); lab:SetWidth(460 - (indent or 0)); lab:SetJustifyH("LEFT")
            lab:SetText(label)
            local d = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            d:SetPoint("TOPLEFT", lab, "BOTTOMLEFT", 0, -3); d:SetWidth(450 - (indent or 0)); d:SetJustifyH("LEFT"); d:SetSpacing(2)
            d:SetText(desc or "")
            local h = 4 + lab:GetStringHeight() + 3 + (desc and d:GetStringHeight() or 0) + 4
            holder:SetSize(500 - (indent or 0), math.max(26, h))
            -- fundo quando ligado: mostra o que está ativo
            local bg = holder:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.2, 0.9, 0.2, 0.07)
            if cb:GetChecked() then bg:Show() else bg:Hide() end
            cb:SetScript("OnClick", function(selfcb)
                RX.db[key] = selfcb:GetChecked() and true or false
                if selfcb:GetChecked() then bg:Show() else bg:Hide() end
                if onChange then onChange() end
                RX:Update(true)
            end)
            table.insert(p.widgets, holder)
            y = y - math.max(26, h) - 8
        end
        local function buttonRow(defs, selectedKey)
            local holder = CreateFrame("Frame", nil, p.child); holder:SetSize(500, 26); holder:SetPoint("TOPLEFT", 4, y)
            table.insert(p.widgets, holder)
            local x = 0
            for _, d in ipairs(defs) do
                local sel = d.selected
                local b = smallButton(holder, (sel and "|cff40ff40> |r" or "") .. d.text, 70, d.onClick, d.tip)
                fitButton(b, 70)
                b:SetHeight(24)
                if x + b:GetWidth() > 495 then y = y - 30; holder = CreateFrame("Frame", nil, p.child); holder:SetSize(500, 26); holder:SetPoint("TOPLEFT", 4, y); table.insert(p.widgets, holder); b:SetParent(holder); x = 0 end
                b:SetPoint("LEFT", holder, "LEFT", x, 0)
                x = x + b:GetWidth() + BTN_GAP * 2
            end
            y = y - 34
        end
        local function stepper(label, get, set, minv, maxv, step)
            local h = CreateFrame("Frame", nil, p.child)
            h:SetSize(500, 28); h:SetPoint("TOPLEFT", 4, y)
            local t = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            t:SetPoint("LEFT")
            local function upd() t:SetText(label .. ": |cffffffff" .. get() .. "|r") end
            local minus = smallButton(h, "-", 28, function() set(math.max(minv, get() - step)); upd() end)
            minus:SetPoint("LEFT", 300, 0)
            local plus = smallButton(h, "+", 28, function() set(math.min(maxv, get() + step)); upd() end)
            plus:SetPoint("LEFT", minus, "RIGHT", BTN_GAP * 2, 0)
            upd()
            table.insert(p.widgets, h)
            y = y - 34
        end
        local function custom() RX.db.style = "custom" end

        -- abas: cada assunto no seu lugar
        local TABS = {
            { "guia", T("Guia e estilo", "Guide & style") }, { "auto", T("Automação", "Automation") }, { "qol", T("Qualidade de vida", "Quality of life") },
            { "leilao", T("Leilão", "Auction House") }, { "nav", T("Navegação", "Navigation") }, { "visual", T("Aparência", "Appearance") },
        }
        local tab = UI.optTab or "guia"
        local tabDefs = {}
        for _, t in ipairs(TABS) do
            table.insert(tabDefs, { text = t[2], selected = tab == t[1], onClick = function() UI.optTab = t[1]; UI:ShowPanel("options") end })
        end
        buttonRow(tabDefs)

        if tab == "guia" then
            -- 1) guia atual
            local g = RX:CurrentGuide()
            section(T("Guia atual", "Current guide"), g and RX:GuideName(g) or T("nenhum", "none"))
            buttonRow({
                { text = T("Escolher guia", "Pick a guide"), onClick = function() UI:ToggleMenu() end },
                { text = RX:ShowAllHere() and T("Voltar ao meu estilo", "Back to my style") or T("Mostrar quests escondidas", "Show hidden quests"),
                  tip = T("Só neste guia: mostra também as lentas, de coleta e cinzas (bom para pegar o que ficou para trás).", "This guide only: also shows slow, collecting and grey quests (good for leftovers)."),
                  onClick = function() RX:ToggleShowAll(); UI:ShowPanel("options") end },
                { text = "|cffff8080" .. T("Limpar guia atual", "Clear current guide") .. "|r", tip = T("Esvazia a lista para escolher outro guia. Não abandona nenhuma quest do jogo.", "Empties the list so you can pick another guide. Does not abandon any in-game quest."),
                  onClick = function() RX:ClearGuide(); UI:ShowPanel("options") end },
            })
            buttonRow({
                { text = RX.db.turninMode and T("Sair do Modo Entregas", "Leave Turn-in mode") or T("Modo Entregas", "Turn-in mode"), selected = RX.db.turninMode,
                  tip = T("Lista só as quests prontas, em rota.", "Lists only ready quests, routed."), onClick = function() RX.Turnin:Toggle(); UI:ShowPanel("options") end },
                { text = RX.db.nearbyMode and T("Sair do Perto de mim", "Leave Nearby") or T("Perto de mim", "Nearby"), selected = RX.db.nearbyMode,
                  tip = T("Quests mais próximas de todos os guias.", "Closest quests from every guide."), onClick = function() RX.Nearby:Toggle(); UI:ShowPanel("options") end },
            })

            -- 2) quests de coleta: uma escolha só
            section(T("Quests de coleta", "Collecting quests"), T("itens que caem de mobs", "items dropped by mobs"))
            local lim = RX.db.collectMax
            if (lim == nil or lim == false) and RX.db.skipCollect then lim = 4 end
            local function setLim(v) RX.db.collectMax = v; RX.db.skipCollect = false; custom(); RX:Update(true); UI:ShowPanel("options") end
            buttonRow({
                { text = T("Aceitar todas", "Accept all"), selected = not lim, onClick = function() setLim(false) end },
                { text = T("Não aceitar mais de 10", "Skip more than 10"), selected = lim == 10, onClick = function() setLim(10) end },
                { text = T("Não aceitar mais de 5", "Skip more than 5"), selected = lim == 5, onClick = function() setLim(5) end },
                { text = T("Não aceitar coleta", "Skip collecting"), selected = lim == 2, onClick = function() setLim(2) end },
            })

            -- 3) outras quests que o guia mostra ou pula
            section(T("Outras quests", "Other quests"))
            check("speedrun", T("Pular quests lentas", "Skip slow quests"), T("Escoltas, entregas em outra zona, pouco XP e quests cinzas.", "Escorts, deliveries to another zone, low XP and grey quests."), custom)
            check("showElite", T("Mostrar quests de elite", "Show elite quests"), T("Mobs fortes: melhor em duo/grupo.", "Strong mobs: better in a duo/group."), custom)
            check("showDungeon", T("Mostrar quests de masmorra", "Show dungeon quests"), T("Uldaman, ZF, Maraudon, ST, BRD...", "Uldaman, ZF, Maraudon, ST, BRD..."), custom)
            check("groupMode", T("Estou em duo / grupo", "I'm in a duo / group"), T("Pula quests de muito drop (cada um precisa do seu) e mostra elites.", "Skips heavy-drop quests (everyone needs their own) and shows elites."), custom)

            -- 4) estilo pronto e rota (atalhos que ligam as opções acima de uma vez)
            section(T("Atalhos de estilo", "Style presets"), T("ligam várias opções acima de uma vez", "set several options above at once"))
            local presets = {}
            for _, st in ipairs(RX.Styles) do
                table.insert(presets, { text = LF(st, "name"), selected = (st.id == RX.db.style), tip = LF(st, "desc"),
                    onClick = function() RX:ApplyStyle(st.id); UI:ShowPanel("options") end })
            end
            buttonRow(presets)
            section(T("Rota até o 60", "Route to 60"), T("ordem das zonas", "zone order"))
            local routes = {}
            for _, r in ipairs(RX.Routes) do
                table.insert(routes, { text = LF(r, "name"), selected = (r.id == RX.db.route), tip = LF(r, "desc"),
                    onClick = function() RX:SetRoute(r.id); UI:ShowPanel("options") end })
            end
            buttonRow(routes)
            check("smartOrder", T("Rota inteligente (pegar tudo no mesmo lugar)", "Smart route (grab everything at the same spot)"), T("Faz o que está perto antes de voltar para entregar.", "Does nearby objectives before going back to turn in."))
            check("suggestZone", T("Sugerir o guia da zona ao entrar nela", "Suggest the zone guide when entering it"), nil)

        elseif tab == "auto" then
            section(T("Aceitar e entregar", "Accept and turn in"))
            check("autoAccept", T("Auto aceitar quests do guia", "Auto accept guide quests"), T("Só aceita as do guia. Segure SHIFT para desativar na hora.", "Only accepts guide quests. Hold SHIFT to disable it on the spot."))
            check("autoTurnIn", T("Auto entregar quests do guia", "Auto turn in guide quests"), T("Quando há só uma recompensa. Segure SHIFT para desativar.", "When there is only one reward. Hold SHIFT to disable."))
            section(T("Abandonar quests que não valem a pena", "Abandon quests that aren't worth it"))
            check("askLowXP", T("Perguntar sobre quests de pouco XP no log", "Ask about low-XP quests in my log"), T("Ao entrar no jogo, ao subir de nível e ao abrir o leilão: pergunta, uma por vez, se quer abandonar quests que já dão pouco XP (inclusive de classe). A resposta fica salva. |cffffff00/rota revisar|r pergunta agora.", "On login, level up and when opening the AH: asks, one at a time, whether to abandon quests that give little XP now (class quests too). Your answer is saved. |cffffff00/rota review|r asks now."))
            buttonRow({ { text = T("Perguntar de novo sobre as mantidas", "Ask again about kept ones"), onClick = function() RX.Abandon:ResetLowXPAnswers() end } })
            check("autoAbandon", T("Abandonar automaticamente", "Abandon automatically"), T("Quando você aceita uma quest assim, avisa no chat e abandona em 8 segundos. |cffffff00/rota manter|r cancela.", "When you accept such a quest, warns in chat and abandons it in 8 seconds. |cffffff00/rota keep|r cancels."), function() UI:ShowPanel("options") end)
            if RX.db.autoAbandon then
                check("abandonSlow", T("Lentas", "Slow"), T("Escolta, 8+ itens de drop, entrega em outra zona, profissão que você não tem, PvP.", "Escort, 8+ dropped items, turn-in in another zone, a profession you don't have, PvP."), nil, 24)
                check("abandonLowXP", T("Pouco XP", "Low XP"), T("Quest cinza (6+ níveis abaixo) ou que dá menos de 1,5% do XP do seu nível.", "Grey quest (6+ levels below) or under 1.5% of your level's XP."), nil, 24)
                check("abandonNotGuide", T("Fora do guia", "Not in the guide"), T("Nenhum guia do RouteXP usa a quest com o seu estilo atual.", "No RouteXP guide uses the quest with your current style."), nil, 24)
                y = self:AddText("|cffaaaaaa" .. T("Nunca abandona: quest que abre corrente do guia, que começou com item, que já está pronta, ou lenta cujo item está à venda no leilão.", "Never abandons: quests that open a guide chain, started from an item, already complete, or slow ones whose item is on the AH.") .. "|r", y - 2)
                buttonRow({ { text = T("Ver últimas abandonadas", "Show last abandoned"), onClick = function() RX.Abandon:ShowLog() end } })
            end

        elseif tab == "qol" then
            section(T("Janelas e atalhos", "Windows and shortcuts"))
            check("questItems", T("Janela de itens da quest (clicar para usar)", "Quest item window (click to use)"), T("Botões para usar os itens que as quests dão. Atalho: Opções > Atalhos > AddOns > RouteXP.", "Buttons to use quest items. Hotkey: Options > Keybindings > AddOns > RouteXP."), function() RX.QuestItems:Refresh() end)
            section(T("Duo / grupo", "Duo / group"))
            check("partyShare", T("Compartilhar com quem usa RouteXP no grupo", "Share with RouteXP users in your group"), T("Mesmo guia, progresso do parceiro em cada quest e pontos de farm.", "Same guide, partner progress on each quest and farm spots."))
            section(T("Quests puladas", "Skipped quests"))
            buttonRow({
                { text = T("Voltar quests puladas", "Restore skipped quests"), onClick = function() RX:UnskipAll(); RX:Print(T("Todas as quests puladas voltaram para a rota.", "All skipped quests are back on the route.")) end },
            })

        elseif tab == "leilao" then
            local hasAuc = Auctionator and Auctionator.API and Auctionator.API.v1
            y = self:AddText(hasAuc and ("|cff40ff40" .. T("Auctionator encontrado: preços da última varredura.", "Auctionator found: prices from the last scan.") .. "|r")
                or ("|cffff6060" .. T("Auctionator não está ligado: sem preços e sem busca automática.", "Auctionator is not enabled: no prices and no automatic search.") .. "|r"), y - 2)
            section(T("Comprar em vez de dropar", "Buy instead of farming"))
            check("marketHint", T("Segunda via em cada quest", "Alternative on each quest"), T("Mostra embaixo da quest os itens que dá para comprar no leilão, com preço e quanto falta.", "Shows under the quest the items you can buy on the AH, with price and how many are left."))
            check("shopWindow", T("Lista de compras ao escolher um guia", "Shopping list when choosing a guide"), T("Janela com todos os itens das quests do guia que dá para comprar.", "Window with every quest item for the guide that can be bought."))
            check("marketOffer", T("Oferecer busca ao abrir a Casa de Leilões", "Offer a search when opening the Auction House"), T("Lista o que falta das quests do seu log e busca tudo no Auctionator.", "Lists what your log quests still need and searches it all in Auctionator."))
            buttonRow({
                { text = T("Abrir lista de compras", "Open shopping list"), onClick = function() RX.Market:ShowWindow(false) end },
                { text = T("Buscar o que falta (log)", "Search what's missing (log)"), onClick = function() RX.Market:Offer(true) end },
            })

        elseif tab == "nav" then
            section(T("Navegação", "Navigation"))
            check("showArrow", T("Seta de navegação", "Navigation arrow"), nil, function() RX.Arrow:Retarget() end)
            check("travelPlan", T("Rota de viagem (a pé, voo, zepelim/barco)", "Travel route (walk, flight, zeppelin/boat)"), nil)
            check("mapLine", T("Linha da rota no mapa-múndi", "Route line on the world map"), nil)
            check("miniLine", T("Linha da rota no minimapa", "Route line on the minimap"), nil)
            check("mapPin", T("Pino de destino do próprio jogo", "The game's own waypoint pin"), nil)
            section(T("Estradas", "Roads"))
            check("useTrails", T("Rota pelas estradas aprendidas", "Route along learned roads"), T("A linha segue as estradas por onde você já correu, em vez de uma reta por cima das montanhas. Onde ainda não há estrada aprendida a linha fica reta e mais fraca.", "The line follows the roads you have already run along instead of a straight line over mountains. Where no road is learned yet the line stays straight and dimmer."))
            check("learnTrails", T("Aprender estradas enquanto eu corro", "Learn roads while I run"), T("Grava por onde você corre (a pé ou montado, fora de combate). Quanto mais você viaja, melhor ficam as rotas. /rota trilhas mostra o que foi aprendido.", "Records where you run (on foot or mounted, out of combat). The more you travel, the better the routes get. /rota trails shows what was learned."))
            section("TomTom")
            check("useTomTom", T("Destino no TomTom", "Destination in TomTom"), nil)
            check("checkpoints", T("Checkpoints no TomTom pelo caminho", "TomTom checkpoints along the way"), T("Poucos pontos: etapas de voo/porto e até 3 pontos nas caminhadas longas.", "Few points: flight/dock legs and up to 3 points on long walks."))

        elseif tab == "visual" then
            section(T("Tamanhos", "Sizes"))
            stepper(T("Tamanho da letra da lista", "List font size"), function() return RX.db.fontSize end, function(v) RX.db.fontSize = v; UI:ApplyFonts(); RX:Update(true) end, 8, 22, 1)
            stepper(T("Escala da janela", "Window scale"), function() return RX.db.scale end, function(v) RX.db.scale = math.floor(v * 10 + 0.5) / 10; UI.frame:SetScale(RX.db.scale) end, 0.6, 1.6, 0.1)
            stepper(T("Tamanho dos ícones da lista", "List icon size"), function() return RX.db.iconSize or 16 end, function(v) RX.db.iconSize = v; RX:Update(true) end, 12, 32, 2)
            stepper(T("Tamanho da seta", "Arrow size"), function() return RX.db.arrowScale or 1 end, function(v) RX.db.arrowScale = math.floor(v * 10 + 0.5) / 10; RX.Arrow:ApplySize() end, 0.5, 2.5, 0.1)
            stepper(T("Texto da seta (distância e destino)", "Arrow text (distance and target)"), function() return RX.db.arrowFont or 11 end, function(v) RX.db.arrowFont = v; RX.Arrow:ApplySize() end, 8, 24, 1)
            section(T("Idioma", "Language"), T("interface e nomes das quests", "interface and quest names"))
            buttonRow({
                { text = T("Automático", "Automatic") .. " (" .. (RX:ClientLang() == "pt" and "Português" or "English") .. ")", selected = RX.db.langMode == "auto", onClick = function() RX:SetLang("auto"); UI:ShowPanel("options") end },
                { text = "Português", selected = RX.db.langMode == "pt", onClick = function() RX:SetLang("pt"); UI:ShowPanel("options") end },
                { text = "English", selected = RX.db.langMode == "en", onClick = function() RX:SetLang("en"); UI:ShowPanel("options") end },
            })
            section(T("Janela do guia", "Guide window"))
            check("locked", T("Travar janelas", "Lock windows"), T("Impede mover/redimensionar.", "Prevents moving/resizing."))
            buttonRow({
                { text = T("Tamanho padrão da janela", "Default window size"), onClick = function() RX.db.width, RX.db.height = 380, 260; UI.frame:SetSize(380, 260); RX:Update(true) end },
            })
            y = self:AddText("|cffaaaaaa" .. T("Dica: arraste o canto inferior direito da janela do guia para aumentá-la.", "Tip: drag the bottom-right corner of the guide window to make it bigger.") .. "|r", y - 4)
        end
    end
    p.child:SetHeight(-y + 10)
end

----------------------------------------------------------------------
-- Botão no minimapa
----------------------------------------------------------------------
local function iconClick(button)
    if button == "RightButton" then UI:ToggleMenu() else UI:Toggle() end
end
local function iconTooltip(tt)
    tt:AddLine(ORANGE .. "RouteXP|r")
    tt:AddLine(T("Clique: mostrar/esconder o guia", "Click: show/hide the guide"), 1, 1, 1)
    tt:AddLine(T("Botão direito: menu de guias", "Right-click: guide menu"), 1, 1, 1)
end

-- Compartimento de addons (botão de addons do minimapa no cliente moderno)
function RouteXP_OnAddonCompartmentClick(_, button) iconClick(button) end
function RouteXP_OnAddonCompartmentEnter(_, frame)
    GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT"); iconTooltip(GameTooltip); GameTooltip:Show()
end
function RouteXP_OnAddonCompartmentLeave() GameTooltip:Hide() end

function UI:CreateMinimapButton()
    -- 1) LibDBIcon: ícone padrão de minimapa, que o EllesmereUI e outros coletores de botões reconhecem
    local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
    local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
    if LDB and DBI then
        local obj = LDB:NewDataObject("RouteXP", {
            type = "launcher",
            text = "RouteXP",
            icon = RX.ICON,
            OnClick = function(_, button) iconClick(button) end,
            OnTooltipShow = function(tt) iconTooltip(tt) end,
        })
        if obj and not DBI:IsRegistered("RouteXP") then
            local ok = pcall(DBI.Register, DBI, "RouteXP", obj, RX.db.minimap)
            if ok then
                if RX.db.minimap.hide then DBI:Hide("RouteXP") else DBI:Show("RouteXP") end
                self.usingDBIcon = true
                return
            end
        end
    end
    -- 2) Reserva: botão próprio em volta do minimapa
    local b = CreateFrame("Button", "RouteXPMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    local overlay = b:CreateTexture(nil, "OVERLAY")
    overlay:SetSize(53, 53)
    overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    overlay:SetPoint("TOPLEFT")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(21, 21)
    icon:SetTexture(RX.ICON)
    icon:SetPoint("TOPLEFT", 5, -5)
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local function place()
        local a = math.rad(RX.db.minimap.angle or 200)
        b:ClearAllPoints()
        b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
    end
    place()
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local s = Minimap:GetEffectiveScale()
            RX.db.minimap.angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
            place()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then UI:ToggleMenu() else UI:Toggle() end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(ORANGE .. "RouteXP|r")
        GameTooltip:AddLine(T("Clique: mostrar/esconder o guia", "Click: show/hide the guide"), 1, 1, 1)
        GameTooltip:AddLine(T("Botão direito: menu de guias", "Right-click: guide menu"), 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if RX.db.minimap.hide then b:Hide() end
end
