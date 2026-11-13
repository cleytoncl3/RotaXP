-- Log de ações bloqueadas: quando o jogo mostra "RouteXP tentou executar uma ação que foi bloqueada",
-- grava qual função foi bloqueada, se você estava em combate e o que o RouteXP tinha acabado de fazer.
-- Fica salvo em RouteXPDB.blockLog (pasta WTF) e aparece com /rota bloqueios.
local ADDON, RX = ...
local BL = { crumbs = {} }
RX.BlockLog = BL
local T = RX.T
local MAX_LOG, MAX_CRUMBS = 40, 12

local function now() return GetTime and GetTime() or 0 end

-- "migalhas": as últimas coisas que o RouteXP fez (para saber o que estava rodando na hora do bloqueio)
function BL:Crumb(name)
    local c = self.crumbs
    c[#c + 1] = { t = now(), name = name, combat = InCombatLockdown and InCombatLockdown() or false }
    if #c > MAX_CRUMBS then table.remove(c, 1) end
end

local function wrap(obj, key, label)
    if type(obj) ~= "table" or type(obj[key]) ~= "function" then return end
    local orig = obj[key]
    obj[key] = function(...)
        BL:Crumb(label)
        return orig(...)
    end
end

function BL:Record(event, addon, func)
    if addon ~= ADDON then return end
    local t = now()
    local recent = {}
    for i = #self.crumbs, 1, -1 do
        local c = self.crumbs[i]
        if t - c.t <= 3 then recent[#recent + 1] = string.format("%s (%.1fs%s)", c.name, t - c.t, c.combat and ", combate" or "") end
        if #recent >= 5 then break end
    end
    local stack = debugstack and debugstack(3, 6, 0) or ""
    local entry = {
        when = date and date("%Y-%m-%d %H:%M:%S") or "?",
        event = event, func = tostring(func or "?"),
        combat = InCombatLockdown and InCombatLockdown() or false,
        zone = GetRealZoneText and GetRealZoneText() or "?",
        version = RX.version,
        recent = table.concat(recent, " <- "),
        stack = stack,
    }
    local db = RX.db
    if db then
        db.blockLog = db.blockLog or {}
        table.insert(db.blockLog, entry)
        while #db.blockLog > MAX_LOG do table.remove(db.blockLog, 1) end
    end
    -- no chat só 1 aviso a cada 60 s (o log guarda todos)
    if self.lastPrint and t - self.lastPrint < 60 then return end
    self.lastPrint = t
    RX:Print(string.format(T("|cffff6060Ação bloqueada:|r %s%s. Última ação do RouteXP: %s. Veja |cff00ff00/rota bloqueios|r.",
        "|cffff6060Blocked action:|r %s%s. Last RouteXP action: %s. See |cff00ff00/rota blocked|r."),
        entry.func, entry.combat and T(" (em combate)", " (in combat)") or "", entry.recent ~= "" and entry.recent or T("nenhuma", "none")))
end

function BL:Show()
    local log = RX.db and RX.db.blockLog or {}
    if #log == 0 then
        RX:Print(T("Nenhuma ação bloqueada registrada.", "No blocked actions logged."))
    else
        RX:Print(string.format(T("%d ações bloqueadas (mais recentes por último):", "%d blocked actions (newest last):"), #log))
        for i = math.max(1, #log - 9), #log do
            local e = log[i]
            print(string.format("|cffffd100%s|r %s |cffff6060%s|r%s  |cffaaaaaa%s · v%s|r", e.when, e.event == "ADDON_ACTION_BLOCKED" and "BLOCKED" or "FORBIDDEN",
                e.func, e.combat and " |cffff9050[combate]|r" or "", e.zone or "", e.version or "?"))
            if e.recent and e.recent ~= "" then print("    |cff80c0ff" .. e.recent .. "|r") end
        end
    end
    local on = GetCVar and GetCVar("taintLog")
    print(T("|cffaaaaaaDetalhe completo: |r/rota bloqueios taint|cffaaaaaa liga o taint.log do jogo (pasta Logs). |r/rota bloqueios limpar|cffaaaaaa apaga o log.|r",
        "|cffaaaaaaFull detail: |r/rota blocked taint|cffaaaaaa turns on the game's taint.log (Logs folder). |r/rota blocked clear|cffaaaaaa clears the log.|r")
        .. (on and on ~= "0" and T(" |cff40ff40(taint.log ligado)|r", " |cff40ff40(taint.log on)|r") or ""))
end

function BL:Command(arg)
    arg = (arg or ""):lower()
    if arg == "limpar" or arg == "clear" then
        if RX.db then RX.db.blockLog = {} end
        RX:Print(T("Log de bloqueios apagado.", "Blocked-action log cleared."))
    elseif arg == "taint" then
        local on = GetCVar and GetCVar("taintLog")
        local new = (on and on ~= "0") and "0" or "1"
        if SetCVar then SetCVar("taintLog", new) end
        RX:Print(new == "1" and T("taint.log ligado: o jogo grava em World of Warcraft\\_forever_\\Logs\\taint.log a linha exata que causou o bloqueio (vale a partir do próximo /reload).",
            "taint.log on: the game writes the exact line that caused the block to World of Warcraft\\_forever_\\Logs\\taint.log (from the next /reload).")
            or T("taint.log desligado.", "taint.log off."))
    else
        self:Show()
    end
end

----------------------------------------------------------------------
-- liga tudo depois que os outros módulos carregaram
----------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_LOGIN" then
        -- migalhas nas funções que mexem em coisas do jogo
        wrap(RX.UI, "SelectInGame", "selecionar quest no jogo (rastreador/mapa)")
        wrap(RX.MapLine, "SetGameWaypoint", "waypoint do jogo / super-rastreio")
        wrap(RX.MiniLine, "SetCheckpoints", "checkpoints do TomTom")
        wrap(RX.Arrow, "SetTarget", "seta: novo destino")
        wrap(RX.Arrow, "PointTo", "seta: apontar")
        wrap(RX.Talents, "Load", "carregar build no Talents Forever")
        for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_GREETING" }) do
            wrap(RX, e, "auto aceitar/entregar (" .. e .. ")")
        end
        wrap(RX, "SetGuide", "trocar de guia")
        wrap(RX.UI and RX.UI.Cascade, "Open", "abrir menu")
        wrap(RX.Party, "OnMessage", "mensagem do grupo")
    else
        BL:Record(event, a1, a2)
    end
end)
