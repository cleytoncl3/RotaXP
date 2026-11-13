-- Só é carregado quando a pasta se chama RotaXP (nome antigo, pelo RotaXP.toc).
-- Mantém as configurações antigas (RotaXPDB / RotaXPCharDB) e explica o que fazer.
-- Na pasta certa (RouteXP) este arquivo não é usado.
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
            say(T("Suas configurações do RotaXP já foram copiadas para o RouteXP. Feche o jogo e apague a pasta |cffffff00Interface\\AddOns\\RotaXP|r.",
                "Your RotaXP settings were copied to RouteXP. Close the game and delete the |cffffff00Interface\\AddOns\\RotaXP|r folder."))
        else
            say(T("|cffff6060O addon não carregou:|r a pasta se chama |cffffff00RotaXP|r, mas o nome agora é |cffffff00RouteXP|r. Feche o jogo e rode |cffffff00Atualizar-RouteXP.bat|r (nesta pasta): ele instala na pasta RouteXP, traz suas configurações e apaga esta. Ou renomeie a pasta para |cffffff00RouteXP|r (aí as configurações começam do zero).",
                "|cffff6060The addon did not load:|r the folder is called |cffffff00RotaXP|r, but the name is now |cffffff00RouteXP|r. Close the game and run |cffffff00Atualizar-RouteXP.bat|r (in this folder): it installs into the RouteXP folder, brings your settings and deletes this one. Or rename the folder to |cffffff00RouteXP|r (settings start from scratch)."))
        end
    end
    if C_Timer then C_Timer.After(6, warn) else warn() end
end)
