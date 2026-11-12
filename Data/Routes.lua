-- Rotas (sequência de guias). Ordem das zonas inspirada nos guias da comunidade do WoW: Forever;
-- as quests de cada zona vêm do banco de dados do Questie (todas as quests da Horda do mapa).
local _, RX = ...

RX.Routes = {
    {
        id = "speed", name = "Speedrun Forever (Riverglades primeiro)",
        nameEn = "Forever Speedrun (Riverglades first)", sourceEn = "zone order from warcraftmaps.com and wowforeverinfo.com",
        descEn = "New zone Riverglades right at 36, then Eastern Kingdoms (STV, Badlands, Swamp), Dustwallow and the Tanaris/Feralas/Hinterlands loop.",
        source = "ordem de zonas do warcraftmaps.com e wowforeverinfo.com",
        desc = "Zona nova Riverglades logo no 36, depois Eastern Kingdoms (STV, Badlands, Swamp), Dustwallow e o circuito Tanaris/Feralas/Hinterlands.",
        style = "speedrun",
        guides = { "z_riverglades", "z_stv", "z_badlands", "z_swamp", "z_dustwallow", "z_tanaris", "z_feralas", "z_hinterlands",
            "z_azshara", "z_ungoro", "z_felwood", "z_burning", "z_wpl", "z_epl", "z_winterspring", "z_silithus", "z_hyjal" },
    },
    {
        id = "duo", name = "Duo / Grupo (matar > coletar)",
        nameEn = "Duo / Group (kill > collect)", sourceEn = "zones with the most kill quests (calculated by RotaXP)",
        descEn = "Favors zones where most XP comes from KILL quests (everyone gets credit). Skips Feralas and Badlands, which have lots of drop collecting.",
        source = "zonas com mais quests de matar (calculado pelo RotaXP)",
        desc = "Prioriza zonas onde a maioria do XP vem de quests de MATAR (todo mundo ganha crédito). Pula Feralas e Badlands, que têm muita coleta de drop.",
        style = "duo",
        guides = { "z_riverglades", "z_arathi", "z_stv", "z_dustwallow", "z_tanaris", "z_hinterlands", "z_searing", "z_azshara",
            "z_ungoro", "z_felwood", "z_wpl", "z_epl", "z_winterspring", "z_silithus", "z_hyjal" },
    },
    {
        id = "classic", name = "Clássica (Desolace -> Arathi -> STV -> Riverglades)",
        nameEn = "Classic (Desolace -> Arathi -> STV -> Riverglades)", sourceEn = "zone order from wowforeverinfo.com",
        descEn = "Traditional route: finish Desolace/Arathi/STV before Riverglades, then Feralas/Tanaris/Hinterlands.",
        source = "ordem de zonas do wowforeverinfo.com",
        desc = "Rota tradicional: termina Desolace/Arathi/STV antes de ir para Riverglades, depois Feralas/Tanaris/Hinterlands.",
        style = "speedrun",
        guides = { "z_desolace", "z_arathi", "z_stv", "z_riverglades", "z_feralas", "z_tanaris", "z_hinterlands", "z_ungoro",
            "z_felwood", "z_azshara", "z_wpl", "z_epl", "z_burning", "z_winterspring", "z_silithus", "z_hyjal" },
    },
    {
        id = "kalimdor", name = "Kalimdor (menos viagens entre continentes)",
        nameEn = "Kalimdor (less travel between continents)", sourceEn = "zones listed by topbuilds.gg",
        descEn = "Stays almost the whole time in Kalimdor: Thousand Needles, Desolace, Shen'dralas, Dustwallow, Tanaris, Feralas, Azshara, Un'Goro, Felwood, Winterspring, Silithus.",
        source = "zonas listadas pelo topbuilds.gg",
        desc = "Fica quase todo o tempo em Kalimdor: Thousand Needles, Desolace, Shen'dralas, Dustwallow, Tanaris, Feralas, Azshara, Un'Goro, Felwood, Winterspring, Silithus.",
        style = "speedrun",
        guides = { "z_needles", "z_desolace", "z_shendralas", "z_dustwallow", "z_tanaris", "z_feralas", "z_azshara", "z_ungoro",
            "z_felwood", "z_winterspring", "z_silithus", "z_hyjal" },
    },
    {
        id = "curada", name = "Rota curta curada (RotaXP v0.1)",
        nameEn = "Short hand-made route (RotaXP v0.1)", sourceEn = "route written by hand in RotaXP 0.1",
        descEn = "The short guides from the first version, with hand-written notes. Good for following a story, but give less XP: top up with mobs.",
        source = "rota feita à mão no RotaXP 0.1",
        desc = "Os guias curtos da primeira versão, com notas escritas à mão. Bons para seguir uma história, mas dão menos XP: complete com mobs.",
        style = "speedrun",
        guides = { "h37_stv", "h38_riverglades", "h44_feralas", "h45_tanaris", "h47_hinterlands_stv", "h49_azshara", "h51_ungoro",
            "h53_felwood", "h55_winterspring", "h56_plaguelands", "h58_silithus" },
    },
}

-- Estilos (variantes de cada guia). collectMax = máximo de itens de DROP que uma quest pode pedir (false = sem limite)
RX.Styles = {
    { id = "speedrun", name = "Speedrun", nameEn = "Speedrun",
      desc = "Pula quests lentas: escoltas, entregas em outra zona, pouco XP e quests cinzas.",
      descEn = "Skips slow quests: escorts, deliveries to another zone, low XP and grey quests.",
      set = { speedrun = true, groupMode = false, skipCollect = false, collectMax = false, showElite = false } },
    { id = "coleta5", name = "Speedrun · coleta até 5 itens", nameEn = "Speedrun · collect up to 5 items",
      desc = "Speedrun, mas só mantém quests que pedem no máximo 5 itens de drop.",
      descEn = "Speedrun, but only keeps quests asking for at most 5 dropped items.",
      set = { speedrun = true, groupMode = false, skipCollect = false, collectMax = 5, showElite = false } },
    { id = "semcoleta", name = "Speedrun sem coleta", nameEn = "Speedrun no collecting",
      desc = "Pula quests de juntar itens que caem de mobs (mantém só as de 1-2 itens, tipo cabeça de chefe).",
      descEn = "Skips quests to gather items dropped by mobs (keeps only 1-2 item ones, like a boss head).",
      set = { speedrun = true, groupMode = false, skipCollect = false, collectMax = 2, showElite = false } },
    { id = "duo", name = "Duo / grupo (matar mobs)", nameEn = "Duo / group (kill mobs)",
      desc = "Foca em quests de matar (todos ganham crédito), pula coleta de drop e mostra elites.",
      descEn = "Focuses on kill quests (everyone gets credit), skips drop collection and shows elites.",
      set = { speedrun = true, groupMode = true, skipCollect = false, collectMax = 2, showElite = true } },
    { id = "completo", name = "Completo", nameEn = "Full",
      desc = "Todas as quests da zona (elites e masmorras têm opção própria).",
      descEn = "Every quest in the zone (elites and dungeons have their own option).",
      set = { speedrun = false, groupMode = false, skipCollect = false, collectMax = false, showElite = false } },
}

RX.Brackets = { { 30, 37 }, { 37, 40 }, { 40, 45 }, { 45, 50 }, { 50, 55 }, { 55, 60 } }

-- XP para passar de nível (tabela clássica; estimativa)
RX.XPNeed = { [30] = 47400, [31] = 50800, [32] = 54500, [33] = 58600, [34] = 62800, [35] = 67100, [36] = 71600, [37] = 76100,
    [38] = 80800, [39] = 85700, [40] = 90700, [41] = 95800, [42] = 101000, [43] = 106300, [44] = 111800, [45] = 117500,
    [46] = 123200, [47] = 129100, [48] = 135100, [49] = 141200, [50] = 147500, [51] = 153900, [52] = 160400, [53] = 167100,
    [54] = 173900, [55] = 180800, [56] = 187900, [57] = 195000, [58] = 202300, [59] = 209800 }
