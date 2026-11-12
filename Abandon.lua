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
    RX.Q:Scan()
    local ok, done = pcall(abandon, q)
    if ok and done then
        RX:CharState().skipped[q] = true
        local cs = RX:CharState()
        cs.abandonLog = cs.abandonLog or {}
        table.insert(cs.abandonLog, { when = date and date("%Y-%m-%d %H:%M:%S") or "?", q = q, title = title(q), why = self.why[q] })
        while #cs.abandonLog > 50 do table.remove(cs.abandonLog, 1) end
        RX:Print(string.format(T("Abandonei |cffffff00%s|r. Ela não vai mais aparecer no guia.", "Abandoned |cffffff00%s|r. It won't show in the guide anymore."), title(q)))
        RX:Update(true)
    else
        RX:Print(string.format(T("Não consegui abandonar \"%s\": abandone pelo log de quests (L).", "Couldn't abandon \"%s\": abandon it from the quest log (L)."), title(q)))
    end
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
