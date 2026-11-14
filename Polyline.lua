-- Pincel das linhas de rota (mapa-múndi e minimapa): linha grossa com contorno escuro e emendas
-- arredondadas (um pontinho redondo em cada curva), para a rota ficar lisa em vez de "serrilhada".
local _, RX = ...
local PL = {}
RX.Polyline = PL

local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

-- pool = conjunto de linhas de um desenho (cada desenho tem o seu)
function PL:New(parent, sub)
    return { parent = parent, sub = sub or 0, lines = {}, shadows = {}, dots = {}, sdots = {}, n = 0, nd = 0 }
end

local function getLine(pool, i)
    local l = pool.lines[i]
    if not l then
        local sh = pool.parent:CreateLine(nil, "ARTWORK", nil, pool.sub)
        sh:SetColorTexture(0, 0, 0, 0.55)
        pool.shadows[i] = sh
        l = pool.parent:CreateLine(nil, "OVERLAY", nil, pool.sub)
        pool.lines[i] = l
    end
    return l, pool.shadows[i]
end

local function getDot(pool, i)
    local d = pool.dots[i]
    if not d then
        local sd = pool.parent:CreateTexture(nil, "ARTWORK", nil, pool.sub)
        sd:SetColorTexture(0, 0, 0, 0.55)
        if sd.SetMask then sd:SetMask(MASK) end
        pool.sdots[i] = sd
        d = pool.parent:CreateTexture(nil, "OVERLAY", nil, pool.sub)
        if d.SetMask then d:SetMask(MASK) end
        pool.dots[i] = d
    end
    return d, pool.sdots[i]
end

function PL:Clear(pool)
    for i = 1, #pool.lines do pool.lines[i]:Hide(); pool.shadows[i]:Hide() end
    for i = 1, #pool.dots do pool.dots[i]:Hide(); pool.sdots[i]:Hide() end
    pool.n, pool.nd = 0, 0
end

-- ponto redondo na emenda (mesma cor da linha)
function PL:Dot(pool, anchor, x, y, thick, outline, r, g, b, a)
    pool.nd = pool.nd + 1
    local d, sd = getDot(pool, pool.nd)
    sd:SetSize(thick + outline * 2, thick + outline * 2)
    sd:ClearAllPoints(); sd:SetPoint("CENTER", pool.parent, anchor, x, y); sd:Show()
    d:SetSize(thick, thick)
    d:ClearAllPoints(); d:SetPoint("CENTER", pool.parent, anchor, x, y)
    d:SetColorTexture(r, g, b, a)
    d:Show()
end

-- trecho de (x1,y1) a (x2,y2); 'outline' = borda escura de cada lado; 'joint' = arredonda o início
function PL:Seg(pool, anchor, x1, y1, x2, y2, thick, outline, r, g, b, a, joint)
    pool.n = pool.n + 1
    local l, sh = getLine(pool, pool.n)
    sh:SetStartPoint(anchor, pool.parent, x1, y1); sh:SetEndPoint(anchor, pool.parent, x2, y2)
    sh:SetThickness(thick + outline * 2); sh:Show()
    l:SetStartPoint(anchor, pool.parent, x1, y1); l:SetEndPoint(anchor, pool.parent, x2, y2)
    l:SetThickness(thick)
    l:SetColorTexture(r, g, b, a)
    l:Show()
    if joint then self:Dot(pool, anchor, x1, y1, thick, outline, r, g, b, a) end
end
