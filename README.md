# RotaXP — Guia de Leveling Horda (WoW: Forever)

Addon de leveling no estilo Zygor / RestedXP para o **WoW: Forever** (Horda, níveis 30–60), em **português e inglês** (segue o idioma do seu cliente).

## O que tem

- **Guias de leveling**: rotas da comunidade (speedrun) e guias completos por zona, incluindo as zonas novas do Forever (Riverglades, Shen'dralas, Mount Hyjal).
- **Estilos combináveis**: speedrun, duo, sem coleta, coleta até 5/10, sem quests lentas, quests de masmorra e de elite.
- **Seta de navegação**, linha da rota no mapa e no minimapa, checkpoints do TomTom, viagens por voo e por navio.
- **Rota inteligente**: pega e entrega tudo o que está no mesmo lugar, prioriza o que está perto e mostra as quests do seu log de outras zonas.
- **Aceitar/entregar automático** só das quests do guia (segure **Shift** para desligar na hora).
- **Prévia da quest** antes de aceitar: matar ⚔, coletar 👜, usar objetos, com as quantidades.
- **Modo Entregas**, **Perto de mim**, **Agora** (dicas para onde você está).
- **Grind & Masmorras**: farm solo e duo, masmorras com XP/hora, **farm de ouro + XP** com XP/h e ouro/h estimados, equipamento do GearQuest e talentos do Talents Forever.
- **Grupo (share)**: quem está no grupo com o RotaXP troca o guia, o progresso de cada quest (ex.: `Amigo: Basilisco 2/10`) e locais marcados. Isso usa o canal de addon do próprio jogo, sem internet. Quem só usa o Questie também aparece.
- **Itens da quest**: janelinha com botões para usar os itens que as quests pedem (num mob, objeto ou local). O item da quest atual fica em destaque e dá para pôr uma tecla de atalho (Opções > Atalhos > AddOns > RotaXP). A lista de quests também avisa quando precisa usar o item.
- **Log de ações bloqueadas**: `/rota bloqueios`.
- **Cronômetro de XP** para medir XP/hora.

## Instalação

1. Baixe o zip: **Code → Download ZIP** (ou o link `https://github.com/cleytoncl3/RotaXP/archive/refs/heads/main.zip`).
2. Extraia e renomeie a pasta para **`RotaXP`**.
3. Coloque a pasta em `World of Warcraft\_forever_\Interface\AddOns\RotaXP`.
4. No jogo, digite `/rota`.

## Atualizar

Dê dois cliques em **`Atualizar-RotaXP.bat`**, dentro da pasta do addon, com o jogo fechado ou na tela de personagens. Ele baixa a versão mais nova daqui e substitui os arquivos. As suas configurações ficam na pasta `WTF` e não são apagadas. Depois entre no jogo ou digite `/reload`.

Se o WoW estiver em *Arquivos de Programas* e der erro de permissão, clique com o botão direito no `.bat` e escolha **Executar como administrador**.

No jogo, `/rota atualizar` mostra a versão instalada. Se alguém do seu grupo tiver uma versão mais nova, o addon avisa.

## Comandos

`/rota` abre/fecha · `/rota ajuda` lista os comandos · `/rota opcoes` · `/rota entregas` · `/rota perto` · `/rota farm` · `/rota timer` · `/rota itens` · `/rota bloqueios` · `/rota atualizar`

## Addons opcionais

TomTom (seta e checkpoints), Questie (dados de quest e progresso do grupo), GearQuest Forever (equipamento), Talents Forever (talentos).

## Créditos e licença

Os dados de quests, NPCs e locais foram extraídos do [Questie](https://github.com/Questie/Questie) (GPL-3.0). Por isso este addon também é distribuído sob a **GPL-3.0** (veja `LICENSE`). As bibliotecas em `Libs/` mantêm as suas próprias licenças.

---

# RotaXP — Horde Leveling Guide (WoW: Forever)

A Zygor / RestedXP style leveling addon for **WoW: Forever** (Horde, levels 30–60), in **English and Portuguese** (it follows your client language). It has leveling guides and speedrun routes, a navigation arrow with map and minimap route lines, auto accept/turn-in of guide quests only, a quest preview before accepting, turn-in and nearby modes, grind/dungeon/gold farming menus, and **group sharing**: same guide, partner quest progress and marked spots, sent over the game's addon channel.

**Install:** download the ZIP, rename the folder to `RotaXP` and put it in `Interface\AddOns`.
**Update:** run `Atualizar-RotaXP.bat` from the addon folder.
**License:** GPL-3.0 (quest data derived from Questie).
