-- Cadeias de pré-quests: uma quest do guia só aparece depois que as pré-quests dela foram ENTREGUES.
-- Quando a pré-quest não faz parte do guia (linhas de quest do jogo que liberam um NPC, masmorra etc.), em vez de
-- esconder a quest e deixar você sem saber o que falta, o guia coloca no lugar dela os passos da pré-quest
-- (onde pegar e, depois de pegar, o que fazer e onde entregar), marcados "Pré-quest para liberar: ...".
-- Dados em Data/QuestChains.lua (gerado por _fonte/chains.js).
local _, RX = ...
local CH = { wanted = {} }
RX.Chain = CH
local T = RX.T

-- início conhecido pelos guias (quests que estão em outro guia)
local guideA
local function guideStart(q)
    if not guideA then
        guideA = {}
        for _, g in pairs(RX.guides) do
            for _, s in ipairs(g.steps) do
                if s.t == "A" and s.q and s.m and s.x and not guideA[s.q] then guideA[s.q] = s end
            end
        end
    end
    return guideA[q]
end

local function info(q) return RX.QuestChains and RX.QuestChains[q] end
local function startOf(q) local c = info(q); if c and (c.m or c.startItem) then return c end return guideStart(q) end

local function preOf(q)
    local m, c = RX.questMeta[q], info(q)
    return (m and m.pre) or (c and c.pre), (m and m.preAll) or (c and c.preAll)
end

-- pré-quests que faltam para liberar a quest q, na ordem de fazer (a mais profunda primeiro)
local function collect(q, out, seen, depth)
    if depth > 8 then return end
    local Q = RX.Q
    local pre, all = preOf(q)
    local skipped = RX:CharState().skipped
    local function handle(p)
        if seen[p] or Q:IsCompleted(p) or skipped[p] then return end
        seen[p] = true
        if Q:InLog(p) then out[#out + 1] = { q = p, inLog = true } return end
        collect(p, out, seen, depth + 1)
        out[#out + 1] = { q = p }
    end
    if all then for _, p in ipairs(all) do handle(p) end end
    if pre then
        for _, p in ipairs(pre) do if Q:IsCompleted(p) then return end end   -- uma delas já feita: liberado
        local pick
        for _, p in ipairs(pre) do if Q:InLog(p) then pick = p break end end
        if not pick then for _, p in ipairs(pre) do if startOf(p) then pick = p break end end end
        handle(pick or pre[1])
    end
end

local function mkStep(p, forStep)
    local src = startOf(p) or info(p)
    local nm = src and src.n
    if not nm then
        local m = RX.questMeta[p]; nm = m and m.n
    end
    local s = {
        t = "A", q = p, n = nm or ("Quest " .. p), pn = src and src.pn, lvl = src and src.lvl, xp = src and src.xp,
        npc = src and src.npc, pnpc = src and src.pnpc, m = src and src.m, x = src and src.x, y = src and src.y,
        flags = {}, chain = true, chainFor = forStep, index = -p,
    }
    local c = info(p)
    if c and c.startItem then s.startItem = c.startItem; s.noNav = true end
    if not s.m then s.noNav = true; s.chainNoLoc = true end
    return s
end

-- chamado pelo VisibleSteps: a quest do passo "Aceitar" s está bloqueada por pré-requisito? devolve os passos
-- das pré-quests (nenhum se não há o que fazer). have[q] = quests que já aparecem na lista.
local MAX_STEPS = 8   -- no máximo isto de pré-quests injetadas de uma vez (para não encher a lista)

function CH:StepsFor(s, have)
    local out, steps = {}, {}
    self.count = self.count or 0
    collect(s.q, out, {}, 0)
    for _, e in ipairs(out) do
        self.wanted[e.q] = true
        if not e.inLog and not have[e.q] and self.count < MAX_STEPS then
            have[e.q] = true
            self.count = self.count + 1
            steps[#steps + 1] = mkStep(e.q, s)
        elseif e.inLog then
            self.waitFor = self.waitFor or {}
            self.waitFor[e.q] = s
        end
    end
    return steps
end

function CH:Reset() wipe(self.wanted); self.waitFor = {}; self.count = 0 end
function CH:IsWanted(q) return q and self.wanted[q] and true or false end

-- pré-quests que já estão no seu log (aceitas): mostra "Fazer"/"Entregar" delas mesmo fora do guia
function CH:LogSteps(have)
    local Q = RX.Q
    local out = {}
    for q, forStep in pairs(self.waitFor or {}) do
        if Q:InLog(q) and not have[q] and not RX:CharState().skipped[q] then
            local c = info(q)
            local nm = (c and c.n) or (RX.questMeta[q] and RX.questMeta[q].n) or ("Quest " .. q)
            local pn = c and c.pn
            local st
            if Q:IsReady(q) then
                local e = RX.Enders and RX.Enders[q]
                if e then st = { t = "T", q = q, n = nm, pn = pn, m = e[1], x = e[2], y = e[3], npc = e[4], pnpc = e[5], xp = e[6], lvl = e[7], flags = {}, chain = true, chainFor = forStep, index = -q } end
            else
                st = { t = "C", q = q, n = nm, pn = pn, lvl = c and c.lvl, xp = c and c.xp, flags = {}, synth = true, chain = true, chainFor = forStep, index = -q }
                if RX.QuestLoc then pcall(RX.QuestLoc.Resolve, RX.QuestLoc, st) end
            end
            if st then out[#out + 1] = st end
        end
    end
    return out
end
