-- Só é carregado pela pasta ANTIGA (Interface\AddOns\RotaXP, pelo RotaXP.toc).
-- Mantém as configurações antigas (RotaXPDB / RotaXPCharDB) carregadas para o RouteXP copiar
-- e avisa o que fazer. Na pasta nova (RouteXP) este arquivo não é usado.
local pt = (GetLocale and (GetLocale() == "ptBR" or GetLocale() == "ptPT"))
local function T(a, b) return pt and a or b end
local function say(msg) if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff7f00RouteXP|r: " .. msg) end end

local function loaded(name)
    if C_AddOns and C_AddOns.IsAddOnLoaded then return C_AddOns.IsAddOnLoaded(name) end
    return IsAddOnLoaded and IsAddOnLoaded(name)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    local function warn()
        if loaded("RouteXP") then
            say(T("Suas configurações do RotaXP já foram copiadas para o RouteXP. Pode apagar a pasta |cffffff00Interface\\AddOns\\RotaXP|r.",
                "Your RotaXP settings were copied to RouteXP. You can delete the |cffffff00Interface\\AddOns\\RotaXP|r folder."))
        else
            say(T("O RotaXP agora se chama |cffffff00RouteXP|r. Feche o jogo e rode |cffffff00Atualizar-RouteXP.bat|r (na pasta Interface\\AddOns\\RotaXP): ele instala o RouteXP. Suas configurações vêm junto.",
                "RotaXP is now called |cffffff00RouteXP|r. Close the game and run |cffffff00Atualizar-RouteXP.bat|r (in Interface\\AddOns\\RotaXP): it installs RouteXP. Your settings come along."))
        end
    end
    if C_Timer then C_Timer.After(6, warn) else warn() end
end)
