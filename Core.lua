-- RotaXP: guia de leveling Horda (WoW: Forever)
local ADDON, RX = ...
_G.RotaXP = RX

RX.guides = {}
RX.guideOrder = {}
RX.questMeta = {}
RX.version = "0.24.2"
RX.NAME = "RouteXP"
RX.ICON = "Interface\\AddOns\\RotaXP\\Media\\icon"

local defaults = {
    style = "speedrun",
    route = "speed",
    groupMode = false,     -- pula quests com MUITOS drops (10+)
    skipCollect = false,   -- (antigo) pula quests de coletar 5+ itens de drop
    collectMax = false,    -- máximo de itens de drop por quest (false = sem limite)
    speedrun = true,       -- pula quests lentas/opcionais/cinzas
    showElite = false,
    showDungeon = false,
    turninMode = false,    -- Modo Entregas
    nearbyMode = false,    -- Modo Perto de mim
    smartOrder = true,     -- reordena os próximos passos pelo caminho mais curto
    travelPlan = true,     -- mostrar rota de viagem (a pé/voo/zepelim)
    mapLine = true,        -- linha de rota no mapa-múndi
    mapPin = true,         -- marca o destino no mapa do jogo
    miniLine = true,       -- linha da rota no minimapa
    checkpoints = true,    -- checkpoints no TomTom ao longo do caminho
    arrowScale = 1,        -- tamanho da seta
    arrowFont = 11,        -- tamanho do texto da seta
    suggestZone = true,    -- sugerir o guia da zona ao entrar nela
    autoAccept = true,
    autoTurnIn = true,
    partyShare = true,
    questItems = true,
    autoAbandon = false,   -- abandona sozinho quests que não valem a pena (opcional)
    abandonSlow = true,    --   lentas (escolta, muitos drops, outra zona)
    abandonLowXP = true,   --   pouco XP / cinzas
    abandonNotGuide = true, --  fora dos guias
    marketHint = true,     -- segunda via no leilão em cada quest
    marketOffer = true,    -- oferecer busca ao abrir a Casa de Leilões
    shopWindow = true,     -- janela de compras no leilão ao escolher um guia
    useTomTom = true,
    showArrow = true,
    langMode = "auto",     -- "auto" = idioma do cliente; "pt" ou "en"
    fontSize = 12,
    iconSize = 16,         -- ícones (! ? e tipo) na lista de quests
    width = 380,
    height = 260,
    scale = 1,
    locked = false,
    minimap = { angle = 200, hide = false },
}

local function copyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = type(dst[k]) == "table" and dst[k] or {}
            copyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

function RX:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00RotaXP|r: " .. tostring(msg))
end

----------------------------------------------------------------------
-- Registro de guias
----------------------------------------------------------------------
function RX:RegisterGuide(g)
    g.steps = g.steps or {}
    local quests = 0
    for i, s in ipairs(g.steps) do
        s.index = i
        s.flags = {}
        if s.f then for _, f in ipairs(s.f) do s.flags[f] = true end end
        if s.t == "A" then
            quests = quests + 1
            -- guarda pré-requisitos de qualquer guia, para valer também nos guias que não os têm
            if s.q and (s.pre or s.preAll or s.ex or s.req) then
                local m = self.questMeta[s.q] or {}
                m.pre, m.preAll, m.ex, m.req = m.pre or s.pre, m.preAll or s.preAll, m.ex or s.ex, m.req or s.req
                self.questMeta[s.q] = m
            end
        end
    end
    g.numQuests = quests
    if not self.guides[g.id] then table.insert(self.guideOrder, g.id) end
    self.guides[g.id] = g
end

function RX:SortedGuides()
    local list = {}
    for _, id in ipairs(self.guideOrder) do table.insert(list, self.guides[id]) end
    table.sort(list, function(a, b)
        if a.min ~= b.min then return a.min < b.min end
        return a.name < b.name
    end)
    return list
end

----------------------------------------------------------------------
-- Rotas e estilos
----------------------------------------------------------------------
function RX:CurrentRoute()
    for _, r in ipairs(self.Routes) do if r.id == self.db.route then return r end end
    return self.Routes[1]
end

function RX:SetRoute(id)
    self.db.route = id
    local r = self:CurrentRoute()
    if r.style then self:ApplyStyle(r.style, true) end
    self:Print(RX.T("Rota: ", "Route: ") .. "|cffffff00" .. RX.LF(r, "name") .. "|r")
    local g = self:BestGuideForLevel(UnitLevel("player"))
    if g then self:SetGuide(g.id) else self:Update(true) end
end

function RX:ApplyStyle(id, silent)
    for _, st in ipairs(self.Styles) do
        if st.id == id then
            self.db.style = id
            for k, v in pairs(st.set) do self.db[k] = v end
            if not silent then self:Print(RX.T("Estilo: ", "Style: ") .. "|cffffff00" .. RX.LF(st, "name") .. "|r - " .. RX.LF(st, "desc")) end
        end
    end
    self:Update(true)
end

function RX:NextGuide(g)
    local r = self:CurrentRoute()
    for i, id in ipairs(r.guides) do
        if id == g.id then
            for j = i + 1, #r.guides do
                local n = self.guides[r.guides[j]]
                if n then return n end
            end
            return nil
        end
    end
    return g.next and self.guides[g.next]
end

function RX:GuideFinishedById(id)
    local p = self:CharState().progress[id]
    local g = self.guides[id]
    return p and g and p.index and p.index > #g.steps
end

function RX:BestGuideForLevel(level)
    local r = self:CurrentRoute()
    for _, id in ipairs(r.guides) do
        local g = self.guides[id]
        if g and level < g.max and level >= g.min - 1 and not self:GuideFinishedById(id) then return g end
    end
    local best
    for _, g in ipairs(self:SortedGuides()) do
        if level >= g.min and level < g.max then
            if not best or (g.kind == "zona" and best.kind ~= "zona") then best = g end
        end
    end
    return best
end

----------------------------------------------------------------------
-- Estado do personagem
----------------------------------------------------------------------
function RX:CharState()
    local c = RotaXPCharDB
    c.progress = c.progress or {}
    c.skipped = c.skipped or {}
    return c
end

function RX:GuideProgress(id)
    local c = self:CharState()
    c.progress[id] = c.progress[id] or { done = {}, index = 1 }
    return c.progress[id]
end

function RX:CurrentGuide()
    local id = self:CharState().guide
    return id and self.guides[id]
end

function RX:SetGuide(id)
    if not self.guides[id] then return end
    self:CharState().guide = id
    if self.Arrow then self.Arrow:ClearManual() end
    self:Print(RX.T("Guia ativo: ", "Active guide: ") .. "|cffffff00" .. self:GuideName(self.guides[id]) .. "|r")
    self:Update(true)
end

----------------------------------------------------------------------
-- Nomes (português / inglês)
----------------------------------------------------------------------
function RX:QName(s)
    if not s.n then return nil end
    if self.db.lang == "pt" then
        if s.pn then return s.pn end
        if s.q and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local t = C_QuestLog.GetTitleForQuestID(s.q)
            if t and t ~= "" then return t end
        end
        local logT = s.q and self.Q:Title(s.q)
        if logT then return logT end
    end
    return s.n
end

function RX:GuideName(g)
    if not g then return "" end
    -- guias de zona: nome do mapa no idioma do seu cliente
    if g.kind == "zona" and g.map and g.map > 0 and RX.MapName then
        local n = RX.MapName(g.map)
        if n then return n .. RX.T(" — completo", " — complete") end
    end
    return RX.LF(g, "name")
end

function RX:SetLang(mode)
    self.db.langMode = mode
    self:ResolveLang()
    if self.UI then self.UI:Relocalize() end
    self:Print(RX.T("Idioma: Português", "Language: English") .. (mode == "auto" and RX.T(" (automático, do cliente)", " (automatic, from the game client)") or ""))
    self:Update(true)
end

function RX:NpcName(s)
    if self.db.lang == "pt" and s.pnpc then return s.pnpc end
    return s.npc
end

function RX:ObjText(s)
    if self.db.lang == "pt" and s.pobj then return s.pobj end
    return s.obj
end

----------------------------------------------------------------------
-- Filtros (estilo + disponibilidade inteligente)
----------------------------------------------------------------------
-- o = opções a usar (padrão: as suas); permite calcular o XP de cada variante sem mudar nada
function RX:StepFilteredByOptions(s, o)
    o = o or self.db
    local f = s.flags
    local lim = o.collectMax
    if (lim == nil or lim == false) and o.skipCollect then lim = 4 end
    if lim then
        if s.cc then
            if s.cc > lim then return "coleta" end
        elseif (f.drop and lim < 10) or (f.coleta and lim < 5) then
            return "coleta"
        end
    end
    if f.drop and o.groupMode then return "drop" end
    if (f.long or f.opt) and o.speedrun then return "lenta" end
    -- quest de profissão (fabricar o item) só aparece no speedrun/sem coleta se você tiver a perícia
    if f.craft and (o.speedrun or lim) and self.Craft and not self.Craft:HasSkill(s.q) then return "profissão" end
    if f.elite and not (o.showElite or o.groupMode) then return "elite" end
    if f.group and not o.groupMode then return "grupo" end
    if f.dungeon and not o.showDungeon then return "masmorra" end
    if f.pvp then return "pvp" end
    return nil
end

local function anyDone(Q, list)
    for _, p in ipairs(list) do if Q:IsCompleted(p) or Q:InLog(p) then return true end end
    return false
end
local function anyCompleted(Q, list)
    for _, p in ipairs(list) do if Q:IsCompleted(p) then return true end end
    return false
end
local function allDone(Q, list)
    for _, p in ipairs(list) do if not Q:IsCompleted(p) then return false end end
    return true
end

-- Motivo para a quest não estar disponível agora (nil = disponível)
function RX:QuestUnavailable(s)
    local Q = self.Q
    local level = UnitLevel("player")
    local meta = s.q and self.questMeta[s.q]
    if meta then
        local orig = s
        s = setmetatable({}, { __index = function(_, k) local v = orig[k]; if v == nil then v = meta[k] end; return v end })
    end
    -- pré-requisito só vale ENTREGUE (o NPC só oferece a próxima depois da entrega; estar no log não basta)
    if s.pre and not anyCompleted(Q, s.pre) then return "pré-requisito" end
    if s.preAll and not allDone(Q, s.preAll) then return "pré-requisito" end
    if s.ex and anyDone(Q, s.ex) then return "exclusiva" end
    if s.req and s.req > level then return "nível " .. s.req end
    -- começa com um item: só aparece quando o item está na bolsa
    local si = s.q and self.QuestStart and self.QuestStart[s.q]
    if s.t == "A" and si then
        if si == 0 and s.approx then return "início desconhecido" end
        if si > 0 then
            local n = (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(si)) or (GetItemCount and GetItemCount(si)) or 0
            if n <= 0 then return "começa com item" end
        end
    end
    if self.db.speedrun and s.lvl and level - s.lvl >= 7 then return "cinza" end
    return nil
end

-- Quests que saem da rota (qualquer passo filtrado, pulada manualmente ou indisponível)
function RX:BuildQuestFilter(g)
    local blocked = {}
    local skipped = self:CharState().skipped
    local Q = self.Q
    for _, s in ipairs(g.steps) do
        if s.q and not blocked[s.q] then
            if skipped[s.q] or self:StepFilteredByOptions(s) then
                blocked[s.q] = true
            elseif s.t == "A" and not Q:InLog(s.q) and not Q:IsCompleted(s.q) and self:QuestUnavailable(s) then
                blocked[s.q] = true
            end
        end
    end
    return blocked
end

function RX:IsStepHidden(s, blocked)
    if s.q and self:CharState().skipped[s.q] then return true end
    local why = self:StepFilteredByOptions(s)
    -- quest que você JÁ pegou sempre aparece (Fazer/Entregar), qualquer que seja o estilo: você escolheu fazê-la
    if why and not (s.q and self.Q:InLog(s.q) and s.t ~= "A") then return true end
    if s.q and blocked[s.q] and not self.Q:IsCompleted(s.q) and not self.Q:InLog(s.q) then return true end
    return false
end

----------------------------------------------------------------------
-- Conclusão de passos
----------------------------------------------------------------------
function RX:IsStepComplete(g, s, prog)
    if prog.done[s.index] then return true end
    local Q = self.Q
    local t = s.t
    if t == "A" then
        return Q:InLog(s.q) or Q:IsCompleted(s.q)
    elseif t == "C" then
        if Q:IsCompleted(s.q) then return true end
        return Q:InLog(s.q) and Q:IsReady(s.q)
    elseif t == "T" then
        return Q:IsCompleted(s.q)
    elseif t == "L" then
        return UnitLevel("player") >= (s.lv or 0)
    end
    return false
end

-- Passos + pernas de viagem até o objetivo atual (a pé, voo, zepelim/barco)
function RX:StepsWithTravel(maxCount)
    local steps, g = self:VisibleSteps(maxCount)
    local final = self.Arrow and self.Arrow.FinalTarget and self.Arrow:FinalTarget(steps)
    local travel
    if final and self.db.travelPlan ~= false and self.Travel and self.Travel.offFor ~= final then
        travel = self.Travel:Steps(final)
    end
    if travel then
        local all = {}
        for _, s in ipairs(travel) do all[#all + 1] = s end
        for _, s in ipairs(steps) do all[#all + 1] = s end
        return all, final, travel, g
    end
    return steps, final, nil, g
end

function RX:VisibleSteps(maxCount)
    if self.db.nearbyMode and self.Nearby then
        return self.Nearby:List(maxCount), self:CurrentGuide()
    end
    if self.db.turninMode and self.Turnin then
        local route = self.Turnin:Route()
        local list = {}
        for i = 1, math.min(maxCount, #route) do list[i] = route[i] end
        return list, self:CurrentGuide()
    end
    local g = self:CurrentGuide()
    if not g then return {}, nil end
    -- cache por atualização (a lista otimizada é calculada uma vez por Update)
    local c = self.visCache
    if c and c.guide == g and c.serial == self.updateSerial then
        local out = {}
        for i = 1, math.min(maxCount, #c.list) do out[i] = c.list[i] end
        return out, g
    end
    local prog = self:GuideProgress(g.id)
    local blocked = self:BuildQuestFilter(g)
    self.lastBlocked = blocked
    local list = {}
    local first
    -- notas/viagens anteriores a um passo de quest já concluído contam como feitas
    local lastAuto = 0
    for i = #g.steps, 1, -1 do
        local s = g.steps[i]
        if (s.q or s.t == "L") and not self:IsStepHidden(s, blocked) and self:IsStepComplete(g, s, prog) then lastAuto = i break end
    end
    for i = 1, #g.steps do
        local s = g.steps[i]
        local passed = i < lastAuto and not s.q and s.t ~= "L"
        if not passed and not self:IsStepHidden(s, blocked) and not self:IsStepComplete(g, s, prog) then
            first = first or i
            table.insert(list, s)
        end
    end
    prog.index = first or (#g.steps + 1)
    -- "Entregar" só aparece quando dá para entregar: se a quest ainda tem um passo "Aceitar" ou
    -- "Fazer" pendente na lista (ou está no log sem estar pronta), o passo de entrega fica escondido
    -- até lá. Sem nenhum passo "Fazer" no guia ele continua aparecendo, com o aviso de não pronta.
    do
        local pending = {}
        for _, s in ipairs(list) do
            if s.q and (s.t == "A" or s.t == "C") then pending[s.q] = true end
        end
        local kept = {}
        self.synthC = self.synthC or {}
        for _, s in ipairs(list) do
            local hide = false
            if s.t == "T" and s.q and pending[s.q] then
                local inLog = self.Q:InLog(s.q)
                hide = (not inLog) or not self.Q:IsReady(s.q)
            elseif s.t == "T" and s.q and self.Q:InLog(s.q) and not self.Q:IsReady(s.q) then
                -- quest no log, ainda não pronta e o guia não tem o passo "Fazer": cria um (local vem do jogo)
                local c = self.synthC[s.q]
                if not c then
                    c = { t = "C", q = s.q, n = s.n, pn = s.pn, lvl = s.lvl, req = s.req, xp = s.xp, cc = s.cc, f = s.f, flags = s.flags or {},
                          m = s.m, x = s.x, y = s.y, synth = true, index = s.index }
                    self.synthC[s.q] = c
                end
                kept[#kept + 1] = c
                hide = true
            end
            if not hide then kept[#kept + 1] = s end
        end
        list = kept
    end
    -- passos "Fazer": local real do objetivo que falta (lido da quest no jogo)
    if self.QuestLoc then pcall(self.QuestLoc.ResolveList, self.QuestLoc, list, 25) end
    -- quests do log que não estão no guia continuam na lista (no fim; as que estão perto sobem na rota)
    if self.Nearby and self.Nearby.LogExtras then
        local ok, extra = pcall(self.Nearby.LogExtras, self.Nearby, list)
        if ok and extra then for _, s in ipairs(extra) do list[#list + 1] = s end end
    end
    -- rota inteligente: pega/entrega o que está no mesmo lugar e segue pelo caminho mais curto
    if self.db.smartOrder ~= false and self.Optimize then
        local ok, res = pcall(self.Optimize.Order, self.Optimize, list)
        if ok and res then list = res end
    end
    self.visCache = { guide = g, serial = self.updateSerial, list = list }
    local out = {}
    for i = 1, math.min(maxCount, #list) do out[i] = list[i] end
    return out, g
end

-- Quests do guia que estão prontas para entregar, mas cujo passo de entrega ainda está mais à frente
function RX:ReadyElsewhere(g, shown)
    local res = {}
    if not g then return res end
    local inShown = {}
    for _, s in ipairs(shown) do if s.q then inShown[s.q] = true end end
    for _, s in ipairs(g.steps) do
        if s.t == "T" and s.q and not inShown[s.q] and self.Q:InLog(s.q) and self.Q:IsReady(s.q) and not self:CharState().skipped[s.q] then
            table.insert(res, s)
        end
    end
    return res
end

function RX:MarkStep(s, value)
    if s.travel then
        -- esconde a viagem sugerida para este objetivo
        self.Travel.offFor = self.Arrow and self.Arrow.finalStep
        self:Update(true)
        return
    end
    if s.nearby and self.db.nearbyMode then
        if s.q then self.Nearby.skip[s.q .. s.t] = true end
        self:Update(true)
        return
    end
    if s.turnin then
        if s.t == "H" then self.Turnin.hearthDone = true elseif s.q then self.Turnin.skip[s.q] = true end
        self:Update(true)
        return
    end
    local g = self:CurrentGuide()
    if not g then return end
    local prog = self:GuideProgress(g.id)
    prog.done[s.index] = value and true or nil
    self:Update(true)
end

function RX:SkipQuest(q, value)
    if not q then return end
    if value == false then
        self:CharState().skipped[q] = nil
    else
        self:CharState().skipped[q] = true
    end
    self:Update(true)
end

function RX:ResetGuide(id)
    local c = self:CharState()
    c.progress[id] = { done = {}, index = 1 }
    self:Update(true)
end

function RX:UnskipAll()
    wipe(self:CharState().skipped)
    self:Update(true)
end

function RX:GuideFinished()
    local g = self:CurrentGuide()
    if not g then return false end
    return self:GuideProgress(g.id).index > #g.steps
end

function RX:CheckNextGuide()
    local g = self:CurrentGuide()
    if g and self:GuideFinished() then
        local n = self:NextGuide(g)
        if n then
            self:Print(RX.T("Guia concluído! Próximo da rota: ", "Guide complete! Next on the route: ") .. self:GuideName(n))
            self:SetGuide(n.id)
        end
    end
end

function RX:GuideWantsQuest(q, kind)
    if self.db.turninMode and kind ~= "A" and q and self.Q:InLog(q) and self.Q:IsReady(q) and not self.Turnin.skip[q] then return true end
    local g = self:CurrentGuide()
    if not g or not q then return false end
    local blocked = self:BuildQuestFilter(g)
    if blocked[q] or self:CharState().skipped[q] then return false end
    for _, s in ipairs(g.steps) do
        if s.q == q and (kind == nil or s.t == kind) and not self:StepFilteredByOptions(s) then return true end
    end
    return false
end

----------------------------------------------------------------------
-- Estimativa de XP
----------------------------------------------------------------------
function RX:QuestXP(s)
    local base = s.xp or ((s.lvl or 0) * 90)
    local diff = UnitLevel("player") - (s.lvl or 0)
    local mult = 1
    if diff >= 10 then mult = 0.1 elseif diff >= 6 then mult = 1 - (diff - 5) * 0.2 end
    return base * mult
end

-- XP das quests restantes do guia (com filtros atuais) e nível estimado ao terminar
function RX:GuideXPEstimate(g)
    g = g or self:CurrentGuide()
    if not g then return 0 end
    local prog = self:GuideProgress(g.id)
    local blocked = self:BuildQuestFilter(g)
    local total = 0
    for _, s in ipairs(g.steps) do
        if s.t == "T" and s.q and not self:IsStepHidden(s, blocked) and not self:IsStepComplete(g, s, prog) then
            total = total + self:QuestXP(s)
        end
    end
    return total
end

-- XP (e nº de quests) que um guia ainda rende com um estilo (variante), sem mudar suas opções
function RX:GuideXPWith(g, set)
    local o = setmetatable({}, { __index = self.db })
    for k, v in pairs(set or {}) do o[k] = v end
    local skipped = self:CharState().skipped
    local blocked = {}
    for _, s in ipairs(g.steps) do
        if s.q and not blocked[s.q] and (skipped[s.q] or self:StepFilteredByOptions(s, o)) then blocked[s.q] = true end
    end
    local lvl = UnitLevel("player")
    local xp, n = 0, 0
    for _, s in ipairs(g.steps) do
        if s.t == "T" and s.q and not blocked[s.q] and not self.Q:IsCompleted(s.q)
            and not (o.speedrun and s.lvl and lvl - s.lvl >= 7) then
            xp = xp + self:QuestXP(s); n = n + 1
        end
    end
    return xp, n
end

-- Considera que matar mobs durante as quests rende ~50% a mais
function RX:LevelAfterXP(xp)
    local level = UnitLevel("player")
    local max = UnitXPMax("player")
    xp = xp * 1.5 + UnitXP("player")
    while level < 60 and max > 0 and xp >= max do
        xp = xp - max
        level = level + 1
        max = self.XPNeed[level] or 210000
    end
    if level >= 60 or max <= 0 then return 60 end
    return level + xp / max
end

----------------------------------------------------------------------
-- Atualização
----------------------------------------------------------------------
local pending = false
function RX:Update(now)
    if now then
        pending = false
        self.updateSerial = (self.updateSerial or 0) + 1
        self.Q:Scan()
        if self.UI then self.UI:Refresh() end
        if self.Arrow then self.Arrow:Retarget() end
        self:CheckNextGuide()
        return
    end
    if pending then return end
    pending = true
    C_Timer.After(0.25, function() if pending then RX:Update(true) end end)
end

----------------------------------------------------------------------
-- XP / hora
----------------------------------------------------------------------
RX.session = { start = 0, xp = 0, lastXP = 0, lastMax = 0 }
function RX:XPTick()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    local s = self.session
    if s.lastMax > 0 then
        local gained = cur - s.lastXP
        if gained < 0 then gained = (s.lastMax - s.lastXP) + cur end
        if gained > 0 then
            s.xp = s.xp + gained
            if self.Timer then self.Timer:OnXP(gained) end
        end
    end
    s.lastXP, s.lastMax = cur, max
end

function RX:XPPerHour()
    local s = self.session
    local elapsed = GetTime() - s.start
    if elapsed < 60 or s.xp <= 0 then return nil end
    local perHour = s.xp / elapsed * 3600
    local left = UnitXPMax("player") - UnitXP("player")
    return perHour, left / perHour * 60
end

----------------------------------------------------------------------
-- Eventos
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
RX.eventFrame = ev
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, ...)
    if RX[event] then RX[event](RX, ...) end
end)

function RX:ADDON_LOADED(name)
    if name ~= ADDON then return end
    RotaXPDB = RotaXPDB or {}
    RotaXPCharDB = RotaXPCharDB or {}
    copyDefaults(defaults, RotaXPDB)
    self.db = RotaXPDB
    -- janela padrão antiga (340x260) era estreita demais para os botões
    if RotaXPDB.width == 340 and RotaXPDB.height == 260 then RotaXPDB.width = 380 end
    self:ResolveLang()
end

function RX:PLAYER_LOGIN()
    local faction = UnitFactionGroup("player")
    self.session.start = GetTime()
    self.session.lastXP, self.session.lastMax = UnitXP("player"), UnitXPMax("player")
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_REMOVED", "PLAYER_LEVEL_UP",
        "ZONE_CHANGED_NEW_AREA", "PLAYER_XP_UPDATE", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
        "GOSSIP_SHOW", "QUEST_GREETING", "PLAYER_ENTERING_WORLD", "CHAT_MSG_COMBAT_XP_GAIN" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    self.UI:Create()
    self.Arrow:Create()
    if self.MapLine then pcall(self.MapLine.Init, self.MapLine) end
    if self.MiniLine then pcall(self.MiniLine.Init, self.MiniLine) end
    if faction ~= "Horde" then
        self:Print(RX.T("Aviso: estes guias foram feitos para a |cffff0000Horda|r.", "Warning: these guides are made for the |cffff0000Horde|r."))
    end
    local cur = self:CurrentGuide()
    if not cur then
        local g = self:BestGuideForLevel(UnitLevel("player"))
        if g then
            self:CharState().guide = g.id
            self:Print(RX.T("Escolhi o guia ", "Picked the guide ") .. "|cffffff00" .. self:GuideName(g) .. "|r (" .. RX.LF(self:CurrentRoute(), "name") .. "). " .. RX.T("Clique no nome do guia para trocar.", "Click the guide name to change it."))
        end
    end
    self:Print("v" .. self.version .. RX.T(" carregado. |cff00ff00/rota|r abre/fecha, |cff00ff00/rota ajuda|r mostra os comandos.", " loaded. |cff00ff00/rota|r shows/hides, |cff00ff00/rota help|r lists the commands."))
    -- outro addon aceitando TODAS as quests atrapalha o guia (só o RotaXP deve escolher)
    -- outro addon aceitando quests sozinho pega quests fora do guia: avisa toda vez que entrar (até ser desligado)
    if C_Timer then C_Timer.After(4, function() RX:WarnConflicts() end) else self:WarnConflicts() end
    self:Update(true)
end

function RX:PLAYER_ENTERING_WORLD() self:Update() end
function RX:CHAT_MSG_COMBAT_XP_GAIN(msg) if self.Timer then self.Timer:OnXPMessage(msg) end end
function RX:QUEST_LOG_UPDATE() self:Update() end
function RX:QUEST_ACCEPTED(q) pcall(self.OnQuestAccepted, self, q); if self.Abandon then pcall(self.Abandon.OnAccepted, self.Abandon, q) end; self:Update() end
function RX:QUEST_REMOVED() self:Update() end
function RX:QUEST_TURNED_IN(q)
    if q then self.Q.completedCache[q] = true end
    self:Update()
end
function RX:ZONE_CHANGED_NEW_AREA()
    self:Update()
    if self.Advisor then C_Timer.After(2, function() RX.Advisor:OnZone() end) end
end
function RX:PLAYER_LEVEL_UP()
    self:Update()
    C_Timer.After(1, function() RX:Update(true) end)
end
function RX:PLAYER_XP_UPDATE() self:XPTick(); if self.UI then self.UI:RefreshXP() end end

----------------------------------------------------------------------
-- Auto aceitar / entregar (segure SHIFT para desativar na hora)
----------------------------------------------------------------------
local function autoOff() return IsShiftKeyDown() end

-- Decisão de aceitar SEMPRE pelo ID da quest (o nome muda com o idioma do jogo).
-- Se o NPC está oferecendo a quest, o jogo já disse que ela está disponível: não confere pré-requisito/nível aqui
-- (essa conferência do guia às vezes erra e fazia o addon não aceitar uma quest do guia).
function RX:AcceptDecision(q)
    if not q or q <= 0 then return false, RX.T("sem ID da quest", "no quest ID") end
    local g = self:CurrentGuide()
    if not g then return false, RX.T("nenhum guia ativo", "no active guide") end
    if self.Q:InLog(q) then return false, RX.T("já está no log", "already in the log") end
    if self:CharState().skipped[q] then return false, RX.T("você pulou/abandonou", "you skipped/abandoned it") end
    local found, why = false, nil
    for _, s in ipairs(g.steps) do
        if s.q == q then
            found = true
            local f = self:StepFilteredByOptions(s)
            if not f then return true, RX.T("está no guia", "in the guide") end
            why = why or f
        end
    end
    if not found then return false, RX.T("não está no guia", "not in the guide") end
    return false, RX.T("o seu estilo pula: ", "your style skips it: ") .. tostring(why)
end

-- Entregar: quest do log que está no guia (mesmo que o estilo pularia: você já fez) ou Modo Entregas
function RX:TurnInDecision(q)
    if not q or q <= 0 then return false, "sem ID" end
    if self.Turnin and self.Turnin.skip[q] then return false, "pulada" end
    if self.db.turninMode and self.Q:InLog(q) then return true, "modo entregas" end
    local g = self:CurrentGuide()
    if not g then return false, "sem guia" end
    for _, s in ipairs(g.steps) do if s.q == q then return true, "no guia" end end
    return false, "fora do guia"
end

-- registro das decisões (para conferir: /rota aceite)
function RX:LogDecision(src, q, title, ok, why)
    local cs = self:CharState()
    cs.acceptDebug = cs.acceptDebug or {}
    table.insert(cs.acceptDebug, { when = date and date("%H:%M:%S") or "?", src = src, q = q, title = title, ok = ok and true or false, why = why })
    while #cs.acceptDebug > 60 do table.remove(cs.acceptDebug, 1) end
end

function RX:ShowDecisions()
    local log = self:CharState().acceptDebug or {}
    if #log == 0 then self:Print(RX.T("Nenhuma decisão registrada ainda: fale com um NPC de quest.", "No decision logged yet: talk to a quest NPC.")) return end
    self:Print(RX.T("Últimas decisões de aceitar/entregar (pelo ID da quest):", "Last accept/turn-in decisions (by quest ID):"))
    for i = math.max(1, #log - 14), #log do
        local e = log[i]
        self:Print(string.format("  %s %s |cffffff00%s|r #%s: %s%s|r (%s)", e.when, e.src, e.title or "?", tostring(e.q),
            e.ok and "|cff40ff40" or "|cffff6060", e.ok and RX.T("sim", "yes") or RX.T("não", "no"), e.why or ""))
    end
end

local function qtitle(q, fallback)
    return (q and C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)) or fallback or (q and ("#" .. q)) or "?"
end

function RX:QUEST_DETAIL()
    if not self.db.autoAccept or autoOff() then return end
    local q = GetQuestID and GetQuestID()
    local ok, why = self:AcceptDecision(q)
    self:LogDecision(RX.T("aceitar", "accept"), q, qtitle(q, GetTitleText and GetTitleText()), ok, why)
    if ok then
        self.autoAccepting = q
        if QuestGetAutoAccept and QuestGetAutoAccept() then
            if AcknowledgeAutoAcceptQuest then AcknowledgeAutoAcceptQuest() end
        else
            AcceptQuest()
        end
    end
end

function RX:QUEST_PROGRESS()
    if not self.db.autoTurnIn or autoOff() then return end
    local q = GetQuestID and GetQuestID()
    if q and self:TurnInDecision(q) and IsQuestCompletable() then CompleteQuest() end
end

function RX:QUEST_COMPLETE()
    if not self.db.autoTurnIn or autoOff() then return end
    local q = GetQuestID and GetQuestID()
    local okT, whyT = self:TurnInDecision(q)
    self:LogDecision(RX.T("entregar", "turn in"), q, qtitle(q, GetTitleText and GetTitleText()), okT, whyT)
    if q and okT then
        local choices = GetNumQuestChoices and GetNumQuestChoices() or 0
        if choices <= 1 then
            GetQuestReward(choices)
        else
            self:Print(RX.T("Escolha sua recompensa (o guia não escolhe itens por você).", "Pick your reward (the guide does not choose items for you)."))
        end
    end
end

-- ordem da quest na lista que você está vendo (o NPC com várias quests: pega primeiro a que o guia mostra primeiro)
function RX:StepRank()
    local rank = {}
    local ok, steps = pcall(self.VisibleSteps, self, 60)
    if ok and steps then
        for i, s in ipairs(steps) do
            if s.q then
                local k = s.q .. s.t
                if not rank[k] then rank[k] = i end
            end
        end
    end
    return rank
end

-- escolhe, entre as opções do NPC, a quest que o guia quer e que aparece mais cedo na lista
local function pick(self, options, kind)
    local rank = self:StepRank()
    local best, bestR
    for _, o in ipairs(options) do
        local ok, why
        if kind == "A" then ok, why = self:AcceptDecision(o.q) else ok, why = self:TurnInDecision(o.q) end
        if o.byName then why = (why or "") .. RX.T(" (achada pelo nome: o jogo não deu o ID)", " (matched by name: the game gave no ID)") end
        self:LogDecision(kind == "A" and RX.T("NPC: aceitar", "NPC: accept") or RX.T("NPC: entregar", "NPC: turn in"), o.q, qtitle(o.q, o.title), ok, why)
        if ok then
            local r = rank[o.q .. kind] or rank[o.q .. "C"] or rank[o.q .. "T"] or 1000
            if not bestR or r < bestR then best, bestR = o, r end
        end
    end
    return best
end

function RX:GOSSIP_SHOW()
    if autoOff() then return end
    if not (C_GossipInfo and C_GossipInfo.GetActiveQuests) then return end
    if self.db.autoTurnIn then
        local opts = {}
        for _, info in ipairs(C_GossipInfo.GetActiveQuests() or {}) do
            if info.isComplete then opts[#opts + 1] = { q = info.questID, title = info.title } end
        end
        local o = pick(self, opts, "T")
        if o then C_GossipInfo.SelectActiveQuest(o.q); return end
    end
    if self.db.autoAccept then
        local opts = {}
        for _, info in ipairs(C_GossipInfo.GetAvailableQuests() or {}) do opts[#opts + 1] = { q = info.questID, title = info.title } end
        local o = pick(self, opts, "A")
        if o then self.autoAccepting = o.q; C_GossipInfo.SelectAvailableQuest(o.q); return end
    end
end

-- tela de saudação (placas "PROCURA-SE", NPCs sem conversa): usa o ID da quest quando o jogo informa,
-- senão o título no idioma do cliente; sempre respeitando os filtros do estilo (GuideWantsQuest)
function RX:QUEST_GREETING()
    if autoOff() then return end
    local g = self:CurrentGuide()
    if not g then return end
    local byTitle = {}
    for _, s in ipairs(g.steps) do
        if s.q and (s.t == "A" or s.t == "T") then
            local titles = { s.n, s.pn }
            if C_QuestLog and C_QuestLog.GetTitleForQuestID then titles[#titles + 1] = C_QuestLog.GetTitleForQuestID(s.q) end
            for _, t in pairs(titles) do if t and t ~= "" then byTitle[s.t .. t] = s.q end end
        end
    end
    if self.db.autoTurnIn then
        local opts = {}
        for i = 1, (GetNumActiveQuests() or 0) do
            local title, complete = GetActiveTitle(i)
            local q = GetActiveQuestID and GetActiveQuestID(i)
            local byName = false
            if not q or q <= 0 then q = byTitle["T" .. (title or "")]; byName = q ~= nil end
            if complete and q then opts[#opts + 1] = { q = q, i = i, title = title, byName = byName } end
        end
        local o = pick(self, opts, "T")
        if o then SelectActiveQuest(o.i); return end
    end
    if self.db.autoAccept then
        local opts = {}
        for i = 1, (GetNumAvailableQuests() or 0) do
            local q
            if GetAvailableQuestInfo then q = select(5, GetAvailableQuestInfo(i)) end
            local title = GetAvailableTitle(i)
            local byName = false
            if not q or q <= 0 then q = byTitle["A" .. (title or "")]; byName = q ~= nil end
            if q then opts[#opts + 1] = { q = q, i = i, title = title, byName = byName } end
        end
        local o = pick(self, opts, "A")
        if o then self.autoAccepting = o.q; SelectAvailableQuest(o.i); return end
    end
end

-- Outros addons que aceitam quests sozinhos (pegam quests fora do guia)
function RX:Conflicts()
    local out = {}
    local eqt = _G.EllesmereUIQuestTracker
    if eqt and eqt.Cfg then
        local ok, v = pcall(eqt.Cfg, "autoAccept")
        if ok and v then out[#out + 1] = RX.T("EllesmereUI Quest Tracker: digite /eqt e desmarque 'Aceitar missões automaticamente' e 'Entregar missões automaticamente'",
            "EllesmereUI Quest Tracker: type /eqt and untick 'Auto Accept Quests' and 'Auto Turn In Quests'") end
    end
    local AA = LibStub and LibStub("AceAddon-3.0", true)
    if AA then
        local ok, rxp = pcall(AA.GetAddon, AA, "RXPGuides", true)
        local p = ok and rxp and rxp.settings and rxp.settings.profile
        if p and p.enableQuestAutomation then out[#out + 1] = RX.T("RestedXP: nas opções do RestedXP desmarque a automação de quests (ou desative o RestedXP enquanto usa o RouteXP)",
            "RestedXP: untick quest automation in the RestedXP options (or disable RestedXP while using RouteXP)") end
    end
    return out
end

function RX:WarnConflicts()
    if not self.db.autoAccept then return end
    local c = self:Conflicts()
    if #c == 0 then return end
    self:Print(RX.T("|cffff6060Atenção:|r outro addon também aceita quests sozinho e pega quests que NÃO são do guia:",
        "|cffff6060Warning:|r another addon also auto-accepts quests and takes quests that are NOT in the guide:"))
    for _, l in ipairs(c) do self:Print("  - " .. l) end
end

-- Toda quest aceita fica registrada (para conferir depois) e avisa se ela não é do guia
function RX:OnQuestAccepted(q)
    if not q then return end
    local cs = self:CharState()
    local byUs = self.autoAccepting == q
    self.autoAccepting = nil
    local g = self:CurrentGuide()
    local inGuide = false
    if g then for _, s in ipairs(g.steps) do if s.q == q then inGuide = true break end end end
    local title = (C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(q)) or self.Q:Title(q) or ("#" .. q)
    cs.acceptLog = cs.acceptLog or {}
    table.insert(cs.acceptLog, { when = date and date("%Y-%m-%d %H:%M:%S") or "?", q = q, title = title, guide = g and g.id, inGuide = inGuide and true or false, byRotaXP = byUs })
    while #cs.acceptLog > 80 do table.remove(cs.acceptLog, 1) end
    if g and not inGuide then
        local c = self:Conflicts()
        self:Print(string.format(RX.T("|cffffd040Você aceitou \"%s\", que não faz parte deste guia%s.|r", "|cffffd040You accepted \"%s\", which is not part of this guide%s.|r"), title,
            (#c > 0) and RX.T(" (outro addon aceitou sozinho: veja o aviso)", " (another addon auto-accepted it: see the warning)") or ""))
        if #c > 0 then self:WarnConflicts() end
    end
    -- mesmo NPC com mais quests do guia: o jogo fecha a janela depois de aceitar, então avisa para falar de novo
    if g then
        local src
        for _, s in ipairs(g.steps) do if s.q == q and s.t == "A" then src = s break end end
        if src and src.npc then
            local more = {}
            for _, s in ipairs(g.steps) do
                if s.t == "A" and s.q ~= q and s.npc == src.npc and not self.Q:InLog(s.q) and not self.Q:IsCompleted(s.q)
                    and self:GuideWantsQuest(s.q, "A") and not self:QuestUnavailable(s) then
                    more[#more + 1] = self:QName(s) or s.n
                end
            end
            if #more > 0 then
                self:Print(string.format(RX.T("Fale de novo com |cffffff00%s|r: ainda tem %d quest(s) do guia: %s", "Talk to |cffffff00%s|r again: %d more guide quest(s): %s"),
                    self:NpcName(src) or src.npc, #more, table.concat(more, ", ")))
            end
        end
    end
end

----------------------------------------------------------------------
-- Comandos
----------------------------------------------------------------------
SLASH_ROTAXP1 = "/rota"
SLASH_ROTAXP2 = "/rotaxp"
SLASH_ROTAXP3 = "/routexp"
SlashCmdList.ROTAXP = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local UI = RX.UI
    if msg == "" then UI:Toggle()
    elseif msg == "guias" or msg == "guia" or msg == "guides" then UI:ToggleMenu()
    elseif msg == "zonas" or msg == "onde" or msg == "zones" then UI:ShowPanel("zones")
    elseif msg == "dicas" or msg == "tips" then UI:ShowPanel("tips")
    elseif msg == "log" then UI:ShowPanel("log")
    elseif msg == "opcoes" or msg == "opções" or msg == "config" or msg == "options" then UI:ShowPanel("options")
    elseif msg == "duo" or msg == "grupo" then RX:ApplyStyle("duo")
    elseif msg == "speed" then RX:ApplyStyle("speedrun")
    elseif msg == "semcoleta" or msg == "nocollect" then RX:ApplyStyle("semcoleta")
    elseif msg == "completo" or msg == "full" then RX:ApplyStyle("completo")
    elseif msg == "en" or msg == "pt" or msg == "auto" then RX:SetLang(msg)
    elseif msg == "entregas" or msg == "turnin" or msg == "turnins" then RX.Turnin:Toggle()
    elseif msg == "timer" or msg == "cronometro" or msg == "cronômetro" then RX.Timer:ToggleWindow()
    elseif msg == "masmorra" or msg == "dungeon" or msg == "farm" or msg == "grind" then UI:ToggleMenu()
    elseif msg == "perto" or msg == "nearby" then RX.Nearby:Toggle()
    elseif msg == "aqui" or msg == "here" then RX.Advisor:UseHere()
    elseif msg == "agora" or msg == "now" then UI:ShowPanel("now")
    elseif msg == "pular" or msg == "skip" then UI:SkipCurrent()
    elseif msg == "itens" or msg == "items" then RX.QuestItems:Toggle()
    elseif msg == "compras" or msg == "comprar" or msg == "shop" then RX.Market:ToggleWindow()
    elseif msg == "aceite" or msg == "aceitar" or msg == "accept" then RX:ShowDecisions()
    elseif msg == "manter" or msg == "keep" then RX.Abandon:Keep()
    elseif msg == "leilao" or msg == "leilão" or msg == "ah" then RX.Market:Offer(true)
    elseif msg:match("^bloqueio") or msg:match("^blocked") then RX.BlockLog:Command(msg:match("^%S+%s+(.*)$"))
    elseif msg == "atualizar" or msg == "update" then
        RX:Print(RX.T("Versão instalada: v" .. RX.version .. ". Para atualizar: feche o jogo (ou fique no menu de personagens) e dê dois cliques em |cffffff00Atualizar-RotaXP.bat|r, na pasta Interface\\AddOns\\RotaXP. Depois entre no jogo (ou /reload). Página: github.com/cleytoncl3/RotaXP",
            "Installed version: v" .. RX.version .. ". To update: close the game (or stay at character select) and double-click |cffffff00Atualizar-RotaXP.bat|r in Interface\\AddOns\\RotaXP. Then log in (or /reload). Page: github.com/cleytoncl3/RotaXP"))
    elseif msg == "reset" then local g = RX:CurrentGuide(); if g then RX:ResetGuide(g.id); RX:Print(RX.T("Progresso do guia reiniciado.", "Guide progress reset.")) end
    elseif msg == "seta" or msg == "arrow" then RX.db.showArrow = not RX.db.showArrow; RX.Arrow:Retarget()
    else
        local T = RX.T
        RX:Print(T("Comandos:", "Commands:"))
        RX:Print(T("/rota - abre/fecha | /rota guias - menu de guias | /rota log - suas quests | /rota zonas | /rota dicas | /rota opcoes",
            "/rota - show/hide | /rota guides - guide menu | /rota log - your quests | /rota zones | /rota tips | /rota options"))
        RX:Print(T("Estilos: /rota speed | /rota duo | /rota semcoleta | /rota completo", "Styles: /rota speed | /rota duo | /rota nocollect | /rota full"))
        RX:Print(T("Idioma: /rota auto | /rota pt | /rota en  -  /rota pular | /rota seta | /rota reset", "Language: /rota auto | /rota pt | /rota en  -  /rota skip | /rota arrow | /rota reset"))
        RX:Print(T("/rota entregas - Modo Entregas (só quests prontas, em rota) | /rota agora - conselhos para onde você está | /rota aqui - usar o guia desta zona",
            "/rota turnin - Turn-in mode (ready quests only, routed) | /rota now - advice for where you are | /rota here - use this zone's guide"))
    end
end
