-- Share em grupo: quem estiver na party/raid com o RotaXP troca, pelo canal de addon do próprio jogo
-- (sem internet), o guia escolhido, o progresso de cada quest e locais marcados.
-- Se o parceiro não tiver o RotaXP mas tiver o Questie, usamos o que o Questie recebeu dele.
local _, RX = ...
local P = { members = {}, sent = {}, queue = {}, warnedVer = {} }
RX.Party = P
local T = RX.T
local PREFIX = "RotaXP"
local PROTO = "1"

----------------------------------------------------------------------
-- utilidades
----------------------------------------------------------------------
local function short(name) return name and (Ambiguate and Ambiguate(name, "short") or name:gsub("%-.*$", "")) end
local function me() return short(UnitName("player")) end
-- é você? (nomes com espaço/servidor/maiúsculas diferentes não podem virar "parceiro")
local function norm(n) return n and tostring(n):gsub("%-.*$", ""):gsub("%s+", ""):lower() end
local function isMe(n)
    if not n then return false end
    if UnitIsUnit then local ok, r = pcall(UnitIsUnit, n, "player"); if ok and r then return true end end
    return norm(n) == norm(UnitName("player"))
end

local function channel()
    if IsInRaid and IsInRaid() then return "RAID" end
    if IsInGroup and IsInGroup() then return "PARTY" end
    return nil
end

local function enabled() return RX.db and RX.db.partyShare ~= false and channel() ~= nil end

local function inGroup(name)
    if not name then return false end
    if UnitInParty and UnitInParty(name) then return true end
    if UnitInRaid and UnitInRaid(name) then return true end
    return false
end

-- compara versões "0.14.2"
local function newer(a, b)
    local pa, pb = {}, {}
    for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x > y end
    end
    return false
end
P.Newer = newer

----------------------------------------------------------------------
-- envio (fila: no máximo ~5 mensagens por segundo, para não ser bloqueado)
----------------------------------------------------------------------
function P:Send(msg)
    if not channel() then return end
    table.insert(self.queue, msg)
    if not self.ticker and C_Timer and C_Timer.NewTicker then
        self.ticker = C_Timer.NewTicker(0.2, function() P:Flush() end)
    end
end

function P:Flush()
    local msg = table.remove(self.queue, 1)
    if not msg then
        if self.ticker then self.ticker:Cancel(); self.ticker = nil end
        return
    end
    local ch = channel()
    if not ch then wipe(self.queue); return end
    local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
    if send then pcall(send, PREFIX, msg, ch) end
end

function P:Hello(reply)
    if not channel() then return end
    local g = RX:CurrentGuide()
    local _, classFile = UnitClass("player")
    self:Send(table.concat({ "H", PROTO, RX.version, UnitLevel("player"), classFile or "?", g and g.id or "-", reply and "1" or "0",
        (RX.db and RX.db.partyShare == false) and "0" or "1" }, ";"))
end

-- estado de uma quest para mandar: L = no log (com contagens), R = pronta, D = já feita, N = não tem
local function questState(q)
    local Q = RX.Q
    if Q:InLog(q) then
        if Q:IsReady(q) then return "R" end
        local parts = {}
        for _, o in ipairs(Q:Objectives(q) or {}) do
            parts[#parts + 1] = string.format("%d/%d", o.numFulfilled or 0, o.numRequired or 0)
        end
        return "L", table.concat(parts, ",")
    end
    if Q:IsCompleted(q) then return "D" end
    return "N"
end

-- manda só o que mudou: quests do log + quests dos próximos passos do guia (para o parceiro saber se você já fez/pegou)
function P:SyncQuests(force)
    if not enabled() then return end
    if force then wipe(self.sent) end
    local want = {}
    for q in pairs(RX.Q.log or {}) do want[q] = true end
    local ok, steps = pcall(RX.VisibleSteps, RX, 30)
    if ok and steps then for _, s in ipairs(steps) do if s.q then want[s.q] = true end end end
    for q in pairs(want) do
        local st, objs = questState(q)
        local msg = "Q;" .. q .. ";" .. st .. (objs and objs ~= "" and (";" .. objs) or "")
        if self.sent[q] ~= msg then
            self.sent[q] = msg
            self:Send(msg)
        end
    end
    for q in pairs(self.sent) do
        if not want[q] then self.sent[q] = nil; self:Send("X;" .. q) end
    end
end

function P:SendGuide(id)
    if not enabled() or not id then return end
    self:Send("G;" .. id)
end

-- local de farm/destino marcado por você (o parceiro pode ir para o mesmo lugar)
function P:SendSpot(step)
    if not enabled() or not (step and step.m and step.x) then return end
    local name = tostring(step.d or ""):gsub(";", ",")
    self:Send(string.format("S;%d;%.2f;%.2f;%s", step.m, step.x, step.y, name:sub(1, 120)))
end

----------------------------------------------------------------------
-- recebimento
----------------------------------------------------------------------
local function split(msg)
    local t = {}
    for part in (msg .. ";"):gmatch("([^;]*);") do t[#t + 1] = part end
    return t
end

function P:Member(name)
    local m = self.members[name]
    if not m then m = { quests = {} }; self.members[name] = m end
    m.seen = GetTime and GetTime() or 0
    return m
end

-- NUNCA reatribuir a global StaticPopupDialogs (contamina o código da Blizzard: ESC dá "ação bloqueada");
-- só adicionamos as nossas chaves na tabela que já existe.
if StaticPopupDialogs then
    StaticPopupDialogs["ROTAXP_PARTY_GUIDE"] = {
        text = "%s", button1 = YES or "Sim", button2 = NO or "Não", timeout = 60, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, data) if data and RX.guides[data] then RX:SetGuide(data, true) end end,
    }
    StaticPopupDialogs["ROTAXP_PARTY_SPOT"] = {
        text = "%s", button1 = YES or "Sim", button2 = NO or "Não", timeout = 60, whileDead = true, hideOnEscape = true,
        OnAccept = function(_, data) if data and RX.Arrow then RX.Arrow:PointTo(data, true); RX:Update(true) end end,
    }
end

function P:OnMessage(prefix, msg, _, sender)
    if prefix ~= PREFIX or not msg then return end
    local who = short(sender)
    if not who or isMe(who) or isMe(sender) then return end
    local f = split(msg)
    local kind = f[1]
    local m = self:Member(who)
    if kind == "H" then
        local first = not m.ver
        m.ver, m.lvl, m.class, m.guide, m.share = f[3], tonumber(f[4]), f[5], (f[6] ~= "-" and f[6] or nil), f[8] ~= "0"
        if m.ver and newer(m.ver, RX.version) and not self.warnedVer[m.ver] then
            self.warnedVer[m.ver] = true
            RX:Print(string.format(T("%s usa o RouteXP |cff40ff40v%s|r (o seu é v%s). Para atualizar: feche o jogo e rode |cffffff00Atualizar-RotaXP.bat|r na pasta do addon.",
                "%s has RouteXP |cff40ff40v%s|r (yours is v%s). To update: close the game and run |cffffff00Atualizar-RotaXP.bat|r in the addon folder."), who, m.ver, RX.version))
        end
        if f[7] ~= "1" then self:Hello(true) end          -- responde quem chegou agora
        if first then self:SyncQuests(true) end            -- e manda tudo para ele
    elseif kind == "Q" then
        local q = tonumber(f[2])
        if q then
            local objs = {}
            for c, n in (f[4] or ""):gmatch("(%d+)/(%d+)") do objs[#objs + 1] = { c = tonumber(c), n = tonumber(n) } end
            m.quests[q] = { st = f[3], objs = objs }
        end
    elseif kind == "X" then
        local q = tonumber(f[2]); if q then m.quests[q] = nil end
    elseif kind == "G" then
        local id = f[2]
        m.guide = id
        local g = id and RX.guides[id]
        local cur = RX:CurrentGuide()
        if g and (not cur or cur.id ~= id) and RX.db.partyShare ~= false then
            local text = string.format(T("|cffff7f00RotaXP|r\n%s escolheu o guia:\n|cffffff00%s|r\n\nUsar o mesmo guia?", "|cffff7f00RotaXP|r\n%s picked the guide:\n|cffffff00%s|r\n\nUse the same guide?"), who, RX:GuideName(g))
            if StaticPopup_Show then StaticPopup_Show("ROTAXP_PARTY_GUIDE", text, nil, id) end
        end
    elseif kind == "S" then
        local mp, x, y = tonumber(f[2]), tonumber(f[3]), tonumber(f[4])
        if mp and x and y and RX.db.partyShare ~= false then
            local step = { t = "G", m = mp, x = x, y = y, flags = {}, external = true, d = f[5] ~= "" and f[5] or who, note = RX.MapName and RX.MapName(mp, "") }
            local text = string.format(T("|cffff7f00RotaXP|r\n%s marcou um local:\n|cffffff00%s|r (%s %.0f, %.0f)\n\nApontar a seta para lá?", "|cffff7f00RotaXP|r\n%s marked a spot:\n|cffffff00%s|r (%s %.0f, %.0f)\n\nPoint the arrow there?"),
                who, step.d, step.note or "", x, y)
            if StaticPopup_Show then StaticPopup_Show("ROTAXP_PARTY_SPOT", text, nil, step) end
        end
    elseif kind == "R" then
        self:Hello(true); self:SyncQuests(true)
    end
    if kind ~= "H" and RX.UI and RX.UI.Refresh then RX:Update() end
end

----------------------------------------------------------------------
-- quem está no grupo e o progresso deles numa quest
----------------------------------------------------------------------
function P:Prune()
    for name in pairs(self.members) do if not inGroup(name) then self.members[name] = nil end end
end

-- Dados do Questie (parceiro sem RotaXP): remoteQuestLogs[q][nome] = objetivos {fulfilled, required}
local function questieFor(q)
    local QL = _G.QuestieLoader
    if not (QL and QL.ImportModule) then return nil end
    local ok, comms = pcall(QL.ImportModule, QL, "QuestieComms")
    local logs = ok and comms and comms.remoteQuestLogs and comms.remoteQuestLogs[q]
    return logs
end

local function colored(name, classFile)
    local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if c and c.colorStr then return "|c" .. c.colorStr .. name .. "|r" end
    return "|cff40c0ff" .. name .. "|r"
end

-- nomes dos objetivos: da sua quest (se você tem) ou do guia
local function objNames(q, s)
    local names = {}
    for i, o in ipairs(RX.Q:Objectives(q) or {}) do
        local n = tostring(o.text or ""):gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", ""):gsub("^%d+%s*/%s*%d+%s*", "")
        n = n:gsub(" mort[oa]s?$", ""):gsub(" slain$", ""):gsub(" killed$", "")
        names[i] = n ~= "" and n or nil
    end
    if #names == 0 and s and s.objs then
        for i, o in ipairs(s.objs) do names[i] = RX:IsPT() and o.p or o.n end
    end
    return names
end

-- linhas "Fulano: 2/4 Basilisco" para mostrar abaixo do passo
function P:LinesFor(s)
    if not (s and s.q) or (RX.db and RX.db.partyShare == false) then return nil end
    local q = s.q
    local out, done = {}, {}
    local names
    local function line(name, classFile, st, objs)
        local txt
        if st == "R" then txt = "|cff40ff40" .. T("pronta para entregar", "ready to turn in") .. "|r"
        elseif st == "D" then txt = "|cff808080" .. T("já fez", "already done") .. "|r"
        elseif st == "N" then
            txt = (s.t == "T" or s.t == "C") and ("|cffff6060" .. T("não tem a quest", "doesn't have the quest") .. "|r") or ("|cffffd040" .. T("ainda não pegou", "hasn't picked it up") .. "|r")
        else
            names = names or objNames(q, s)
            local parts = {}
            for i, o in ipairs(objs or {}) do
                local col = (o.c >= o.n) and "|cff40ff40" or "|cffffffff"
                parts[#parts + 1] = (names[i] and (names[i] .. " ") or "") .. col .. o.c .. "/" .. o.n .. "|r"
            end
            txt = #parts > 0 and table.concat(parts, ", ") or T("com a quest", "has the quest")
        end
        out[#out + 1] = colored(name, classFile) .. ": " .. txt
    end
    for name, m in pairs(self.members) do
        local d = m.quests[q]
        if d then done[name] = true; line(name, m.class, d.st, d.objs) end
    end
    local logs = questieFor(q)
    if logs then
        for name, objs in pairs(logs) do
            local n = short(name)
            if not done[n] and not isMe(n) and not isMe(name) and inGroup(n) then
                local list, all = {}, true
                for i, o in pairs(objs) do
                    if type(o) == "table" and o.required then
                        list[i] = { c = o.fulfilled or 0, n = o.required }
                        all = all and (o.fulfilled or 0) >= o.required
                    end
                end
                local _, cf = UnitClass(n)
                line(n, cf, (all and #list > 0) and "R" or "L", list)
            end
        end
    end
    if #out == 0 then return nil end
    table.sort(out)
    return out
end

function P:Count()
    local n = 0
    for _ in pairs(self.members) do n = n + 1 end
    return n
end

----------------------------------------------------------------------
-- menu "Grupo"
----------------------------------------------------------------------
function P:Items()
    local share = RX.db.partyShare ~= false
    local list = { { header = true, text = T("Grupo (share)", "Group (share)"),
        sub = T("Quem está no grupo com o RouteXP troca o guia, o progresso das quests e locais marcados (pelo canal de addon do jogo, sem internet).",
            "Group members with RouteXP share the guide, quest progress and marked spots (through the game's addon channel, no internet).") } }
    table.insert(list, { text = (share and "|cff40ff40[x]|r " or "|cff808080[ ]|r ") .. T("Compartilhar com o grupo", "Share with the group"), noMark = true, keep = true,
        sub = T("guia, progresso e locais; mostra o progresso deles embaixo de cada quest", "guide, progress and spots; shows their progress under each quest"),
        onClick = function() RX.db.partyShare = not share; if RX.db.partyShare then P:Hello(); P:SyncQuests(true) end; RX:Update(true) end })
    if not channel() then
        table.insert(list, { text = "|cffaaaaaa" .. T("Você não está em grupo.", "You are not in a group.") .. "|r", noMark = true })
        return list
    end
    local g = RX:CurrentGuide()
    if g then
        table.insert(list, { text = T("Enviar meu guia para o grupo", "Send my guide to the group"), sub = RX:GuideName(g),
            onClick = function() P:SendGuide(g.id); RX:Print(T("Guia enviado ao grupo.", "Guide sent to the group.")) end })
    end
    local dest = RX.Arrow and (RX.Arrow.finalStep or RX.Arrow.step)
    if dest and dest.m and dest.x then
        table.insert(list, { text = T("Enviar o destino da seta", "Send the arrow's destination"), sub = string.format("%s (%.0f, %.0f)", RX.MapName(dest.m, "?"), dest.x, dest.y),
            onClick = function() P:SendSpot({ m = dest.m, x = dest.x, y = dest.y, d = RX:NpcName(dest) or RX:QName(dest) or dest.d }) end })
    end
    table.insert(list, { text = T("Sincronizar agora", "Sync now"), onClick = function() P:Send("R"); P:Hello(); P:SyncQuests(true) end })
    table.insert(list, { header = true, text = T("Membros com RouteXP", "Members with RouteXP") })
    local any = false
    for name, m in pairs(self.members) do
        any = true
        local mg = m.guide and RX.guides[m.guide]
        local same = mg and g and mg.id == g.id
        table.insert(list, {
            text = colored(name, m.class) .. string.format(" |cffaaaaaa%s %s · v%s|r", T("nível", "level"), m.lvl or "?", m.ver or "?"),
            sub = mg and ((same and "|cff40ff40" .. T("mesmo guia: ", "same guide: ") or T("guia: ", "guide: ")) .. RX:GuideName(mg) .. (same and "|r" or "")) or T("sem guia", "no guide"),
            tip = (mg and not same) and T("Clique: usar o mesmo guia.", "Click: use the same guide.") or nil,
            onClick = (mg and not same) and function() RX:SetGuide(mg.id, true) end or nil,
        })
    end
    if not any then
        table.insert(list, { text = "|cffaaaaaa" .. T("Ninguém do grupo com o RouteXP ainda (ou esperando resposta).", "Nobody in the group has RouteXP yet (or waiting for a reply).") .. "|r", noMark = true,
            sub = T("Quem só usa o Questie também aparece embaixo das quests.", "Members who only use Questie still show under the quests.") })
    end
    return list
end

----------------------------------------------------------------------
-- eventos
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
P.frame = ev
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(PREFIX) end
        for _, e in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "QUEST_LOG_UPDATE", "PLAYER_LEVEL_UP" }) do pcall(ev.RegisterEvent, ev, e) end
        if channel() then P:Hello() end
    elseif event == "CHAT_MSG_ADDON" then
        P:OnMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        P:Prune()
        if channel() and not P.helloPending and C_Timer then
            P.helloPending = true
            C_Timer.After(2, function() P.helloPending = nil; P:Hello(); P:SyncQuests(true) end)
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "PLAYER_LEVEL_UP" then
        if channel() and not P.syncPending and C_Timer then
            P.syncPending = true
            C_Timer.After(1, function() P.syncPending = nil; if event == "PLAYER_LEVEL_UP" then P:Hello() end; P:SyncQuests() end)
        end
    end
end)

-- escolher um guia avisa o grupo (quem recebe decide se usa o mesmo)
local origSetGuide = RX.SetGuide
function RX:SetGuide(id, fromParty)
    origSetGuide(self, id)
    if not fromParty and self.guides[id] then P:SendGuide(id) end
end
