-- Modo "Perto de mim": quests mais próximas de você, juntando TODOS os guias
-- (aceitar as disponíveis, fazer as que estão no log, entregar as prontas), da mais perto para a mais longe
local _, RX = ...
local NB = { skip = {} }
RX.Nearby = NB
local T = RX.T

local function zoneName(m)
    local info = m and C_Map.GetMapInfo(m)
    return info and info.name or "?"
end

local function pos(s)
    if s._wx == nil and s.m and s.x then
        local c, wx, wy = RX.Travel.world(s.m, s.x, s.y)
        s._cont, s._wx, s._wy = c or false, wx, wy
    end
    return s._cont, s._wx, s._wy
end

function NB:List(maxCount)
    local me = RX.Travel:PlayerPos()
    local Q = RX.Q
    local lvl = UnitLevel("player")
    local skipped = RX:CharState().skipped
    local seen, cands = {}, {}
    for _, g in pairs(RX.guides) do
        for _, s in ipairs(g.steps) do
            local key = s.q and (s.q .. s.t)
            if key and s.m and s.x and not seen[key] and not skipped[s.q] and not self.skip[key] then
                local ok = false
                if s.t == "A" then
                    ok = not Q:InLog(s.q) and not Q:IsCompleted(s.q) and not RX:QuestUnavailable(s)
                        and not RX:StepFilteredByOptions(s) and (s.req or 1) <= lvl
                elseif s.t == "C" then
                    ok = Q:InLog(s.q) and not Q:IsReady(s.q)
                    if ok and RX.QuestLoc then RX.QuestLoc:Resolve(s); s._wx = nil end
                elseif s.t == "T" then
                    ok = Q:InLog(s.q) and Q:IsReady(s.q)
                end
                if ok then
                    seen[key] = true
                    local c, wx, wy = pos(s)
                    if c and me and c == me.cont then
                        s.nearYards = math.sqrt((wx - me.wx) ^ 2 + (wy - me.wy) ^ 2)
                        table.insert(cands, s)
                    end
                end
            end
        end
    end
    table.sort(cands, function(a, b) return a.nearYards < b.nearYards end)
    local list = {}
    for i = 1, math.min(maxCount or 40, #cands) do
        local s = cands[i]
        s.nearby = true
        s.nearNote = string.format("%s · ~%.0f m", zoneName(s.m), s.nearYards * 0.9144)
        list[i] = s
    end
    return list
end

-- Quests do seu log que NÃO estão na lista do guia (de outras zonas ou que ficaram para trás):
-- continuam aparecendo no fim da lista, da mais perto para a mais longe, para nada "sumir"
function NB:LogExtras(shown)
    local Q = RX.Q
    local me = RX.Travel:PlayerPos()
    local skipped = RX:CharState().skipped
    local have = {}
    for _, s in ipairs(shown) do if s.q then have[s.q] = true end end
    local best = {}
    for _, g in pairs(RX.guides) do
        for _, s in ipairs(g.steps) do
            local q = s.q
            if q and not have[q] and not skipped[q] and s.m and s.x and Q:InLog(q) then
                local want = Q:IsReady(q) and "T" or "C"
                if s.t == want and not best[q] then best[q] = s end
            end
        end
    end
    local out = {}
    for _, s in pairs(best) do
        if s.t == "C" and RX.QuestLoc then RX.QuestLoc:Resolve(s); s._wx = nil end
        local c, wx, wy = pos(s)
        if me and c == me.cont then
            s.nearYards = math.sqrt((wx - me.wx) ^ 2 + (wy - me.wy) ^ 2)
            s.logNote = string.format("%s %s · ~%.0f m", T("Do seu log:", "From your log:"), zoneName(s.m), s.nearYards * 0.9144)
        else
            s.nearYards = 1e9
            s.logNote = string.format("%s %s · %s", T("Do seu log:", "From your log:"), zoneName(s.m), T("outro continente", "other continent"))
        end
        s.fromLog = true
        out[#out + 1] = s
    end
    table.sort(out, function(a, b) return a.nearYards < b.nearYards end)
    return out
end

function NB:Toggle(on)
    if on == nil then on = not RX.db.nearbyMode end
    RX.db.nearbyMode = on and true or false
    if on then
        RX.db.turninMode = false
        RX:Print(T("Modo Perto de mim: quests de todos os guias, da mais perto para a mais longe (no seu continente).",
            "Nearby mode: quests from every guide, nearest first (on your continent)."))
    else
        RX:Print(T("Voltando ao guia.", "Back to the guide."))
    end
    if RX.Arrow then RX.Arrow:ClearManual() end
    RX:Update(true)
end
