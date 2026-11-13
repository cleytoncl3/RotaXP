-- Idioma do RouteXP: segue o idioma do cliente (ptBR/ptPT = português, resto = inglês),
-- mas pode ser trocado nas Opções. Só existem Português e English.
local _, RX = ...

function RX:ClientLang()
    local l = GetLocale and GetLocale() or "enUS"
    if l == "ptBR" or l == "ptPT" then return "pt" end
    return "en"
end

-- Resolve o idioma efetivo a partir de db.langMode ("auto" | "pt" | "en")
function RX:ResolveLang()
    local db = self.db
    if not db then return self:ClientLang() end
    if db.langMode ~= "pt" and db.langMode ~= "en" then db.langMode = "auto" end
    db.lang = (db.langMode == "auto") and self:ClientLang() or db.langMode
    return db.lang
end

function RX:IsPT()
    local db = self.db
    if db and db.lang then return db.lang == "pt" end
    return self:ClientLang() == "pt"
end

-- Nomes de lugares (zonas, vilas, masmorras) escritos em inglês nos textos dos guias são trocados pelo
-- nome que o PRÓPRIO jogo usa no idioma do cliente (C_Map), ex.: "Thousand Needles" -> "Mil Agulhas".
local placeList, placeCache, placeName = nil, {}, {}
local function localPlace(en)
    local v = placeName[en]
    if v == nil then
        local id = RX.PlaceIDs and RX.PlaceIDs[en]
        local name
        if id and C_Map then
            if id < 0 and C_Map.GetMapInfo then
                local ok, info = pcall(C_Map.GetMapInfo, -id); name = ok and info and info.name
            elseif id > 0 and C_Map.GetAreaInfo then
                local ok, n = pcall(C_Map.GetAreaInfo, id); name = ok and n
            end
        end
        v = (type(name) == "string" and name ~= "") and name or false
        placeName[en] = v
    end
    return v or nil
end

function RX:Places(text)
    if type(text) ~= "string" or text == "" or not RX.PlaceIDs then return text end
    -- só faz sentido quando o texto é mostrado no idioma do cliente (o jogo dá os nomes nesse idioma)
    if not (self:IsPT() and self:ClientLang() == "pt") then return text end
    local c = placeCache[text]
    if c then return c end
    if not placeList then
        placeList = {}
        for en in pairs(RX.PlaceIDs) do placeList[#placeList + 1] = en end
        table.sort(placeList, function(a, b) return #a > #b end)   -- maiores primeiro ("Stranglethorn Vale" antes de "Stranglethorn")
    end
    local out, slots = text, {}
    for _, en in ipairs(placeList) do
        if out:find(en, 1, true) then
            local loc = localPlace(en)
            if loc and loc ~= en then
                local pat = "%f[%w']" .. en:gsub("[%%%-%.%+%*%?%[%]%^%$%(%)]", "%%%0") .. "%f[^%w']"
                local n
                out, n = out:gsub(pat, function() slots[#slots + 1] = loc; return "\001" .. #slots .. "\002" end)
            end
        end
    end
    out = out:gsub("\001(%d+)\002", function(i) return slots[tonumber(i)] end)
    placeCache[text] = out
    return out
end

-- T("texto em português", "english text")
function RX.T(pt, en)
    if RX:IsPT() then return RX:Places(pt) end
    return en or pt
end

-- Campo traduzido de uma tabela de dados: L(t, "name") usa t.nameEn em inglês
function RX.LF(t, key)
    if not t then return nil end
    if RX:IsPT() then return RX:Places(t[key]) end
    return t[key .. "En"] or t[key]
end
