-- Quests que pedem um item FABRICADO (ex.: "Not My Circus" pede 10 Ensopado Salgado de Frutos do Mar = Culinária 200).
-- Mostra a profissão, a perícia que você tem e os ingredientes; esconde a quest nos estilos speedrun/sem coleta
-- se você não tiver a profissão no nível certo. Dados em Data/Crafted.lua (gerado por _fonte/craft.js).
local _, RX = ...
local CR = {}
RX.Craft = CR
local T = RX.T

local PROF = {
    [1] = { "Primeiros Socorros", "First Aid" }, [2] = { "Ferraria", "Blacksmithing" }, [3] = { "Couraria", "Leatherworking" },
    [4] = { "Alquimia", "Alchemy" }, [6] = { "Culinária", "Cooking" }, [7] = { "Mineração", "Mining" },
    [8] = { "Alfaiataria", "Tailoring" }, [9] = { "Engenharia", "Engineering" }, [10] = { "Encantamento", "Enchanting" },
}

function CR:Info(q) return q and RX.QuestCraft and RX.QuestCraft[q] end

function CR:ProfName(p)
    local n = PROF[p]
    return n and T(n[1], n[2]) or "?"
end

-- perícia que você tem na profissão (nil = não tem / não deu para ler)
function CR:Skill(p)
    local names = PROF[p]
    if not names or not GetNumSkillLines or not GetSkillLineInfo then return nil end
    for i = 1, GetNumSkillLines() do
        local name, header, _, rank = GetSkillLineInfo(i)
        if name and not header and (name == names[1] or name == names[2]) then return rank end
    end
    return nil
end

function CR:HasSkill(q)
    local c = self:Info(q)
    if not c then return true end
    local r = self:Skill(c.p)
    return r and r >= c.s
end

local function itemName(id)
    local n = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or (GetItemInfo and (GetItemInfo(id)))
    if not n and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
    return n or ("item " .. id)
end

local function count(id) return (C_Item and C_Item.GetItemCount and C_Item.GetItemCount(id)) or (GetItemCount and GetItemCount(id)) or 0 end

-- linhas de dica para o passo
function CR:Hint(q)
    local c = self:Info(q)
    if not c then return nil end
    local r = self:Skill(c.p)
    local mine = r and string.format(T("você tem %d", "you have %d"), r) or T("você não tem", "you don't have it")
    local ok = r and r >= c.s
    local head = string.format(T("%sProfissão: %s %d|r (%s). Fabrique %dx %s (tem %d).", "%sProfession: %s %d|r (%s). Craft %dx %s (have %d)."),
        ok and "|cff40ff40" or "|cffff6060", self:ProfName(c.p), c.s, mine, c.n, itemName(c.i), count(c.i))
    local parts = {}
    for _, rg in ipairs(c.r or {}) do
        parts[#parts + 1] = string.format("%d %s |cffaaaaaa(%d/%d)|r", rg[2], itemName(rg[1]), count(rg[1]), rg[2] * c.n)
    end
    local need = T("Cada um: ", "Each: ") .. table.concat(parts, ", ")
    local alt = ok and nil or T("Sem a profissão: compre o item no Leilão ou peça para alguém fabricar, ou pule a quest.",
        "Without the profession: buy it on the AH, ask someone to craft it, or skip the quest.")
    return head, need, alt
end

-- marca os passos das quests de profissão quando os guias são registrados
local origRegister = RX.RegisterGuide
function RX:RegisterGuide(g, ...)
    local r = origRegister(self, g, ...)
    for _, s in ipairs(g.steps or {}) do
        if s.q and s.flags and RX.QuestCraft and RX.QuestCraft[s.q] then s.flags.craft = true end
        if s.q and s.flags and RX.QuestPvP and RX.QuestPvP[s.q] then s.flags.pvp = true end
        -- quest que começa com item: não há NPC para onde ir
        local si = s.q and RX.QuestStart and RX.QuestStart[s.q]
        if s.t == "A" and si and si > 0 then s.startItem = si; s.noNav = true end
        if s.n == "undefined" then s.n = "Quest " .. s.q end
    end
    return r
end
