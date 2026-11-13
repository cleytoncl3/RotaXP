-- De onde esta cópia do addon veio e como atualizar. O pacote do CurseForge troca este arquivo
-- inteiro (gerado por _fonte/package.js), então os textos do GitHub/atualizador só existem aqui.
local _, RX = ...
RX.DIST = "github"
function RX:UpdateHow()
    return RX.T("Para atualizar: feche o jogo e dê dois cliques em |cffffff00Atualizar-RouteXP.bat|r, na pasta Interface\\AddOns\\RouteXP. Página: github.com/cleytoncl3/RouteXP",
        "To update: close the game and double-click |cffffff00Atualizar-RouteXP.bat|r in Interface\\AddOns\\RouteXP. Page: github.com/cleytoncl3/RouteXP")
end
