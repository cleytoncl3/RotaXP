-- Abandono automático: quando você aceita uma quest que demora demais (escolta, muitos itens de drop,
-- entrega em outra zona, profissão que você não tem), o RotaXP avisa e abandona depois de alguns segundos.
-- "/rota manter" cancela. Nunca abandona: quest que abre corrente do guia, quest que começou com item,
-- quest já pronta, ou quando o item está barato no leilão (aí é só comprar).
local _, RX = ...
local AB = { pending = {} }
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

-- motivo para NÃO abandonar (nil = pode abandonar)
function AB:KeepReason(q)
    if RX.Q:IsReady(q) then return "pronta" end
    if RX.QuestStart and (RX.QuestStart[q] or 0) > 0 then return "começa com item" end
    if opensChain(q) then return "abre corrente" end
    if buyable(q) then return "leilão" end
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
    if not self.pending[q] then return end
    self.pending[q] = nil
    if not RX.Q:InLog(q) or RX.db.autoAbandon == false then return end
    if self:KeepReason(q) then return end
    RX.Q:Scan()
    local ok, done = pcall(abandon, q)
    if ok and done then
        RX:CharState().skipped[q] = true
        local cs = RX:CharState()
        cs.abandonLog = cs.abandonLog or {}
        table.insert(cs.abandonLog, { when = date and date("%Y-%m-%d %H:%M:%S") or "?", q = q, title = title(q) })
        while #cs.abandonLog > 50 do table.remove(cs.abandonLog, 1) end
        RX:Print(string.format(T("Abandonei |cffffff00%s|r. Ela não vai mais aparecer no guia.", "Abandoned |cffffff00%s|r. It won't show in the guide anymore."), title(q)))
        RX:Update(true)
    else
        RX:Print(string.format(T("Não consegui abandonar \"%s\": abandone pelo log de quests (L).", "Couldn't abandon \"%s\": abandon it from the quest log (L)."), title(q)))
    end
end

function AB:OnAccepted(q)
    if not q or RX.db.autoAbandon == false then return end
    local why = self:SlowReason(q)
    if not why then return end
    local keep = self:KeepReason(q)
    if keep then
        if keep == "leilão" then
            RX:Print(string.format(T("\"%s\" é lenta (%s), mas o item está à venda no leilão: mantive a quest.", "\"%s\" is slow (%s), but the item is on the AH: kept the quest."), title(q), why))
        end
        return
    end
    self.pending[q] = true
    RX:Print(string.format(T("|cffff9050\"%s\" demora demais (%s): vou abandonar em %ds.|r Digite |cffffff00/rota manter|r para ficar com ela.",
        "|cffff9050\"%s\" takes too long (%s): abandoning in %ds.|r Type |cffffff00/rota keep|r to keep it."), title(q), why, DELAY))
    if C_Timer then C_Timer.After(DELAY, function() AB:Do(q) end) end
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
