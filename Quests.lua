-- Camada de compatibilidade do log de quests (API moderna e clássica)
local _, RX = ...
local Q = { log = {}, completedCache = {} }
RX.Q = Q

function Q:Scan()
    wipe(self.log)
    if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
        local n = C_QuestLog.GetNumQuestLogEntries()
        for i = 1, n do
            local info = C_QuestLog.GetInfo(i)
            if info and not info.isHeader and info.questID and info.questID > 0 then
                local ready = false
                if C_QuestLog.IsComplete then ready = C_QuestLog.IsComplete(info.questID) and true or false end
                if not ready and C_QuestLog.ReadyForTurnIn then ready = C_QuestLog.ReadyForTurnIn(info.questID) and true or false end
                self.log[info.questID] = { title = info.title, ready = ready, index = i }
            end
        end
    elseif GetNumQuestLogEntries then
        local n = GetNumQuestLogEntries()
        for i = 1, n do
            local title, _, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
            if not isHeader and questID and questID > 0 then
                self.log[questID] = { title = title, ready = (isComplete == 1 or isComplete == true), index = i }
            end
        end
    end
end

function Q:InLog(q) return q and self.log[q] ~= nil end

function Q:IsReady(q)
    local e = q and self.log[q]
    if not e then return false end
    if e.ready then return true end
    -- quests sem objetivos (só falar com alguém) contam como prontas
    local objs = self:Objectives(q)
    if objs and #objs == 0 then return true end
    return false
end

function Q:IsCompleted(q)
    if not q then return false end
    if self.completedCache[q] then return true end
    local done
    if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
        done = C_QuestLog.IsQuestFlaggedCompleted(q)
    elseif IsQuestFlaggedCompleted then
        done = IsQuestFlaggedCompleted(q)
    end
    if done then self.completedCache[q] = true end
    return done and true or false
end

function Q:Objectives(q)
    if C_QuestLog and C_QuestLog.GetQuestObjectives then
        local ok, objs = pcall(C_QuestLog.GetQuestObjectives, q)
        if ok then return objs end
    end
    return nil
end

function Q:Title(q)
    local e = self.log[q]
    if e then return e.title end
    if C_QuestLog and C_QuestLog.GetTitleForQuestID then return C_QuestLog.GetTitleForQuestID(q) end
    return nil
end

-- Texto de progresso "3/10 Tal coisa"
function Q:ProgressText(q)
    local objs = self:Objectives(q)
    if not objs or #objs == 0 then return nil end
    local parts = {}
    for _, o in ipairs(objs) do
        local txt = o.text or ""
        if o.finished then
            table.insert(parts, "|cff40ff40" .. txt .. "|r")
        else
            table.insert(parts, "|cffd0d0d0" .. txt .. "|r")
        end
    end
    return table.concat(parts, "\n")
end

function Q:Count()
    local n = 0
    for _ in pairs(self.log) do n = n + 1 end
    return n
end

function Q:Max()
    if C_QuestLog and C_QuestLog.GetMaxNumQuestsCanAccept then
        local ok, m = pcall(C_QuestLog.GetMaxNumQuestsCanAccept)
        if ok and m and m > 0 then return m end
    end
    return MAX_QUESTLOG_QUESTS or 25
end
