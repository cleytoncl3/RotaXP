-- Abandono automático (opcional, Opções > Automação): quando você aceita uma quest que não vale a pena
-- (lenta: escolta, muitos drops, outra zona, profissão; pouco XP/cinza; ou fora dos guias), avisa e abandona depois de alguns segundos.
-- "/rota manter" cancela. Nunca abandona: quest que abre corrente do guia, quest que começou com item,
-- quest já pronta, ou quando o item está barato no leilão (aí é só comprar).
local _, RX = ...
local AB = { pending = {}, why = {} }
RX.Abandon = AB
local T = RX.T
local DELAY = 8
local MANY = 8  -- itens de drop a partir disso = lenta

-- junta flags e quantidade de coleta de todos os passos da quest em todos os guias
local function info(q)
    local f, cc, found = {}, nil, false
    for _, g in pairs(RX.guides or {}) do
        for _, s in ipairs(g.steps or {}) do
            if s.q == q then
                found = true
                for k, v in pairs(s.flags or {}) do if v then f[k] = true end end
                if s.cc and (not cc or s.cc > cc) then cc = s.cc end
            end
        end
    end
    return found, f, cc
end

-- alguma quest dos guias (que não seja lenta também) depende desta? (abandonar quebraria a corrente)
local function opensChain(q)
    for _, g in pairs(RX.guides or {}) do
        for _, s in ipairs(g.steps or {}) do
            for _, key in ipairs({ "pre", "preAll" }) do
                local list = s[key]
                if type(list) == "table" then
                    for _, p in ipairs(list) do if p == q and s.q ~= q and not AB:SlowReason(s.q) then return true end end
                elseif list == q and s.q ~= q and not AB:SlowReason(s.q) then return true end
            end
        end
    end
    return false
end

local function neededItems(q)
    local n = 0
    for _, it in ipairs((RX.QuestNeeds and RX.QuestNeeds[q]) or {}) do n = n + (it[2] or 1) end
    return n
end

-- o item que falta está à venda no leilão? então compensa comprar em vez de abandonar
local function buyable(q)
    if not RX.Market then return false end
    local miss = RX.Market:Missing(q)
    if not miss or #miss == 0 then return false end
    for _, m in ipairs(miss) do if not RX.Market:Price(m.id) then return false end end
    return true
end

-- motivo para considerar a quest lenta (nil = não é)
function AB:SlowReason(q)
    local found, f, cc = info(q)
    if f.escolta then return T("escolta", "escort") end
    if f.pvp then return T("PvP", "PvP") end
    if f.craft and RX.Craft and not RX.Craft:HasSkill(q) then return T("pede profissão que você não tem", "needs a profession you don't have") end
    local items = math.max(cc or 0, neededItems(q))
    if (f.drop or f.coleta) and (items == 0 or items >= MANY) then
        return items > 0 and string.format(T("%d itens de drop", "%d dropped items"), items) or T("muitos itens de drop", "many dropped items")
    end
    if f.long then return T("entrega/objetivo longe (outra zona)", "turn-in/objective far away (another zone)") end
    if not found and items >= 10 then return string.format(T("%d itens de drop", "%d dropped items"), items) end
    return nil
end

-- pouco XP: quest cinza (6+ níveis abaixo) ou recompensa < 1,5% do XP do nível
function AB:LowXPReason(q)
    local lvl = UnitLevel and UnitLevel("player") or 0
    if lvl >= 60 then return nil end
    local qlvl
    for _, g in pairs(RX.guides or {}) do
        for _, s in ipairs(g.steps or {}) do if s.q == q and s.lvl then qlvl = s.lvl break end end
        if qlvl then break end
    end
    if not qlvl and C_QuestLog and C_QuestLog.GetQuestDifficultyLevel then
        local ok, v = pcall(C_QuestLog.GetQuestDifficultyLevel, q); if ok and type(v) == "number" and v > 0 then qlvl = v end
    end
    if qlvl and lvl - qlvl >= 6 then return string.format(T("cinza: nível %d", "grey: level %d"), qlvl) end
    local xp
    if GetQuestLogRewardXP then local ok, v = pcall(GetQuestLogRewardXP, q); if ok and type(v) == "number" and v > 0 then xp = v end end
    local max = UnitXPMax and UnitXPMax("player") or 0
    if xp and max > 0 and xp < max * 0.015 then return string.format(T("pouco XP: %d", "low XP: %d"), xp) end
    return nil
end

-- fora dos guias: nenhum guia (com o seu estilo) usa esta quest
function AB:NotGuideReason(q)
    if not RX:CurrentGuide() then return nil end
    if RX:GuideWantsQuest(q) then return nil end
    for _, g in pairs(RX.guides or {}) do
        for _, s in ipairs(g.steps or {}) do
            if s.q == q and not RX:StepFilteredByOptions(s) then return nil end
        end
    end
    return T("não está no guia", "not in the guide")
end

-- motivo para abandonar, conforme as opções ligadas (nil = fica)
function AB:Reason(q)
    local o = RX.db
    if o.abandonSlow ~= false then local w = self:SlowReason(q); if w then return w, "slow" end end
    if o.abandonLowXP ~= false then local w = self:LowXPReason(q); if w then return w, "xp" end end
    if o.abandonNotGuide ~= false then local w = self:NotGuideReason(q); if w then return w, "guide" end end
    return nil
end

-- motivo para NÃO abandonar (nil = pode abandonar)
function AB:KeepReason(q, kind)
    if RX.Q:IsReady(q) then return "pronta" end
    if RX.QuestStart and (RX.QuestStart[q] or 0) > 0 then return "começa com item" end
    if opensChain(q) then return "abre corrente" end
    if kind == "slow" and buyable(q) then return "leilão" end
    return nil
end

local function title(q)
    return (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)) or RX.Q:Title(q) or ("#" .. q)
end

-- abandona pela API (moderna ou clássica)
local function abandon(q)
    if C_QuestLog and C_QuestLog.SetSelectedQuest and C_QuestLog.SetAbandonQuest and C_QuestLog.AbandonQuest then
        C_QuestLog.SetSelectedQuest(q)
        C_QuestLog.SetAbandonQuest()
        C_QuestLog.AbandonQuest()
        return true
    end
    local e = RX.Q.log[q]
    if e and e.index and SelectQuestLogEntry and SetAbandonQuest and AbandonQuest then
        SelectQuestLogEntry(e.index)
        SetAbandonQuest()
        AbandonQuest()
        return true
    end
    return false
end

function AB:Do(q)
    local kind = self.pending[q]
    if not kind then return end
    self.pending[q] = nil
    if not RX.Q:InLog(q) or not RX.db.autoAbandon then return end
    if self:KeepReason(q, kind) then return end
    self:AbandonNow(q, self.why[q])
end

-- abandona já (botão "X" da lista ou automático); a quest sai do guia
function AB:AbandonNow(q, why)
    if not (q and RX.Q:InLog(q)) then return false end
    RX.Q:Scan()
    local name = title(q)
    local ok, done = pcall(abandon, q)
    if ok and done then
        RX:CharState().skipped[q] = true
        local cs = RX:CharState()
        cs.abandonLog = cs.abandonLog or {}
        table.insert(cs.abandonLog, { when = date and date("%Y-%m-%d %H:%M:%S") or "?", q = q, title = name, why = why })
        while #cs.abandonLog > 50 do table.remove(cs.abandonLog, 1) end
        RX:Print(string.format(T("Abandonei |cffffff00%s|r. Ela não vai mais aparecer no guia (desfazer: Opções > Voltar quests puladas).",
            "Abandoned |cffffff00%s|r. It won't show in the guide anymore (undo: Options > Restore skipped quests)."), name))
        RX:Update(true)
        return true
    end
    RX:Print(string.format(T("Não consegui abandonar \"%s\": abandone pelo log de quests (L).", "Couldn't abandon \"%s\": abandon it from the quest log (L)."), name))
    return false
end

-- pergunta antes (botão da lista)
function AB:Confirm(q)
    if not (q and RX.Q:InLog(q)) then return end
    if StaticPopup_Show then
        StaticPopup_Show("ROUTEXP_ABANDON", title(q), nil, q)
    else
        self:AbandonNow(q, T("manual", "manual"))
    end
end

if StaticPopupDialogs then
    StaticPopupDialogs["ROUTEXP_ABANDON"] = {
        text = "Abandonar a quest\n|cffffff00%s|r?", button1 = YES or "Sim", button2 = NO or "Não",
        timeout = 0, whileDead = true, hideOnEscape = true, showAlert = true,
        OnShow = function(self) if RX.db and RX.db.lang ~= "pt" and self.text then self.text:SetText(string.format("Abandon the quest\n|cffffff00%s|r?", self.data and title(self.data) or "")) end end,
        OnAccept = function(_, q) AB:AbandonNow(q, T("manual", "manual")) end,
    }
end

function AB:OnAccepted(q)
    if not q or not RX.db.autoAbandon then return end
    local why, kind = self:Reason(q)
    if not why then return end
    local keep = self:KeepReason(q, kind)
    if keep then
        if keep == "leilão" then
            RX:Print(string.format(T("\"%s\" é lenta (%s), mas o item está à venda no leilão: mantive a quest.", "\"%s\" is slow (%s), but the item is on the AH: kept the quest."), title(q), why))
        end
        return
    end
    self.pending[q] = kind
    self.why[q] = why
    RX:Print(string.format(T("|cffff9050\"%s\" não vale a pena (%s): vou abandonar em %ds.|r Digite |cffffff00/rota manter|r para ficar com ela.",
        "|cffff9050\"%s\" isn't worth it (%s): abandoning in %ds.|r Type |cffffff00/rota keep|r to keep it."), title(q), why, DELAY))
    if C_Timer then C_Timer.After(DELAY, function() AB:Do(q) end) end
end

-- lista as últimas quests abandonadas no chat
function AB:ShowLog()
    local log = RX:CharState().abandonLog or {}
    if #log == 0 then RX:Print(T("Nenhuma quest abandonada ainda.", "No quest abandoned yet.")) return end
    RX:Print(T("Últimas quests abandonadas:", "Last abandoned quests:"))
    for i = math.max(1, #log - 9), #log do
        local e = log[i]
        RX:Print(string.format("  %s  %s%s", e.when or "?", e.title or ("#" .. tostring(e.q)), e.why and (" |cffaaaaaa(" .. e.why .. ")|r") or ""))
    end
end

-- /rota manter: cancela os abandonos pendentes e tira a quest dos "pulados"
function AB:Keep()
    local n = 0
    for q in pairs(self.pending) do
        self.pending[q] = nil
        RX:CharState().skipped[q] = nil
        n = n + 1
    end
    RX:Print(n > 0 and T("Ok, mantive a quest.", "Ok, kept the quest.") or T("Nenhuma quest para abandonar agora.", "No quest pending abandon."))
    if n > 0 then RX:Update(true) end
end


----------------------------------------------------------------------
-- Revisão do quest log: quests ativas que já dão pouco XP (cinzas ou < 1,5% do nível).
-- Pergunta uma de cada vez se quer abandonar; a resposta fica salva e não pergunta de novo.
-- Quest de classe também é perguntada, com o aviso de que pode valer pela recompensa.
----------------------------------------------------------------------
local function qlevel(q)
    local e = RX.Q.log[q]
    if e and type(e.level) == "number" and e.level > 0 then return e.level end
    for _, g in pairs(RX.guides or {}) do
        for _, s in ipairs(g.steps or {}) do if s.q == q and s.lvl then return s.lvl end end
    end
    return nil
end

local function qxp(q)
    if GetQuestLogRewardXP then
        local ok, v = pcall(GetQuestLogRewardXP, q)
        if ok and type(v) == "number" and v > 0 then return v end
    end
    for _, g in pairs(RX.guides or {}) do
        for _, s in ipairs(g.steps or {}) do if s.q == q and s.t == "T" then return math.floor(RX:QuestXP(s)) end end
    end
    return nil
end

function AB:IsClassQuest(q)
    local e = RX.Q.log[q]
    local cls = UnitClass and (UnitClass("player"))
    return e and e.header and cls and e.header == cls or false
end

-- lista do que vale perguntar agora
function AB:LowXPList()
    local lvl = UnitLevel and UnitLevel("player") or 0
    if lvl >= 60 then return {} end
    RX.Q:Scan()
    local asked = RX:CharState().lowXPAsked or {}
    local max = UnitXPMax and UnitXPMax("player") or 0
    local out = {}
    for q, e in pairs(RX.Q.log or {}) do
        if not asked[q] and not e.ready and not self.pending[q] then
            local ql, xp = qlevel(q), qxp(q)
            local grey = ql and lvl - ql >= 6
            local low = xp and max > 0 and xp < max * 0.015
            if grey or low then
                out[#out + 1] = { q = q, title = e.title or ("#" .. q), level = ql, xp = xp, class = self:IsClassQuest(q), grey = grey }
            end
        end
    end
    table.sort(out, function(x, y) return (x.level or 0) < (y.level or 0) end)
    return out
end

function AB:ReviewLog()
    if RX.db.askLowXP == false or self.reviewing then return end
    if InCombatLockdown and InCombatLockdown() then self.reviewAfterCombat = true return end
    self.reviewQueue = self:LowXPList()
    if #self.reviewQueue == 0 then return end
    self.reviewing = true
    self:AskNext()
end

function AB:AskNext()
    local it = self.reviewQueue and table.remove(self.reviewQueue, 1)
    if not it then self.reviewing = nil return end
    if not RX.Q:InLog(it.q) then return self:AskNext() end
    self.asking = it
    local lines = {}
    lines[#lines + 1] = string.format(T("Você tem a quest |cffffff00%s|r%s ativa.", "You have the quest |cffffff00%s|r%s active."),
        it.title, it.level and string.format(T(" (nível %d)", " (level %d)"), it.level) or "")
    lines[#lines + 1] = it.xp and string.format(T("Ela dá só ~%d de XP para o seu nível%s.", "It only gives ~%d XP at your level%s."), it.xp, it.grey and T(" (já está cinza)", " (it is grey already)") or "")
        or T("Ela já está cinza: dá pouco XP para o seu nível.", "It is grey already: little XP at your level.")
    if it.class then
        lines[#lines + 1] = "|cffff9050" .. T("É uma quest de CLASSE: pode valer a pena fazer pela recompensa (habilidade/item).", "It is a CLASS quest: it may be worth doing for the reward (skill/item).") .. "|r"
    end
    lines[#lines + 1] = T("Quer abandonar?", "Do you want to abandon it?")
    if StaticPopup_Show then StaticPopup_Show("ROUTEXP_LOWXP", table.concat(lines, "\n"), nil, it.q) end
end

function AB:Answer(q, abandonIt)
    local c = RX:CharState()
    c.lowXPAsked = c.lowXPAsked or {}
    c.lowXPAsked[q] = abandonIt and "abandon" or "keep"
    if abandonIt then self:AbandonNow(q, T("pouco XP (revisão do log)", "low XP (log review)")) end
    if C_Timer then C_Timer.After(0.3, function() AB:AskNext() end) else self:AskNext() end
end

function AB:ResetLowXPAnswers()
    RX:CharState().lowXPAsked = {}
    RX:Print(T("Ok: vou perguntar de novo sobre as quests de pouco XP que você manteve.", "Ok: I will ask again about the low-XP quests you kept."))
end

if StaticPopupDialogs then
    StaticPopupDialogs["ROUTEXP_LOWXP"] = {
        text = "%s", button1 = T("Abandonar", "Abandon"), button2 = T("Manter", "Keep"),
        timeout = 0, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, q) AB:Answer(q, true) end,
        OnCancel = function(_, q) AB:Answer(q, false) end,
    }
end

local rev = CreateFrame("Frame")
rev:RegisterEvent("PLAYER_LOGIN")
rev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        pcall(rev.RegisterEvent, rev, "PLAYER_LEVEL_UP")
        pcall(rev.RegisterEvent, rev, "PLAYER_REGEN_ENABLED")
        pcall(rev.RegisterEvent, rev, "AUCTION_HOUSE_SHOW")
        if C_Timer then C_Timer.After(15, function() AB:ReviewLog() end) end
    elseif event == "PLAYER_LEVEL_UP" then
        if C_Timer then C_Timer.After(4, function() AB:ReviewLog() end) end
    elseif event == "AUCTION_HOUSE_SHOW" then
        AB:ReviewLog()
    elseif event == "PLAYER_REGEN_ENABLED" and AB.reviewAfterCombat then
        AB.reviewAfterCombat = nil
        if C_Timer then C_Timer.After(2, function() AB:ReviewLog() end) end
    end
end)
