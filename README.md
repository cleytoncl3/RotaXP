# RouteXP (antigo RotaXP)

**RouteXP** é um guia de leveling e quests (Horda, 30-60) para WoW: Forever, no estilo Zygor/RestedXP: rota de speedrun, seta, linha no mapa, auto aceitar/entregar pelo ID da quest, share em duo, leilão e farm de ouro.

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
- **Leilão (segunda via)**: em cada quest que pede itens negociáveis aparece a opção de comprar no leilão em vez de dropar, com preço do Auctionator. Itens vinculados (de quest) ficam de fora.
- **Lista de compras do guia**: ao escolher um guia, abre uma janela com todos os itens das quests dele que dá para comprar, quantidade e preço, e um botão para buscar no Auctionator (`/rota compras`). Ao abrir a Casa de Leilões, oferece buscar o que falta das quests do log (`/rota leilao`).
- **Abandono automático (opcional)**: Opções > Automação. Abandona sozinho, com aviso de 8 segundos, quests que não valem a pena: lentas (escolta, 8+ drops, outra zona, profissão), de pouco XP (cinzas ou < 1,5% do nível) ou fora do guia. Cada critério liga/desliga. `/rota manter` cancela. Nunca abandona quest que abre corrente do guia, que começou com item, ou lenta cujo item está à venda no leilão.
- **Opções em abas**: Guia, Automação, Qualidade de vida, Leilão, Navegação e Aparência.
- **Minimizar**: o botão ao lado do X vira o guia numa bolinha com o ícone; clique nela para voltar. O mesmo ícone fica no minimapa.
- **Cronômetro de XP** na página principal; arraste o canto da janela do cronômetro para mudar o tamanho.
- **Farm de ouro**: cada local mostra os drops que mais rendem (chance por abate e preço do leilão/vendedor) e os raros vendáveis. Dados do cmangos classic-db.
- **Auto aceitar pelo ID da quest**: aceita só as quests do guia, decidindo pelo ID (funciona em qualquer idioma). `/rota aceite` mostra as últimas decisões e o motivo.
- **Ícone do tipo de quest** ao lado do ! / ?: saquinho (coletar/drop), espada (matar), engrenagem (pegar no chão/interagir), balão com 3 pontinhos (só falar com o NPC).
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

`/rota` (ou `/rxp`) abre/fecha · `/rota ajuda` lista os comandos · `/rota opcoes` · `/rota entregas` · `/rota perto` · `/rota farm` · `/rota timer` · `/rota itens` · `/rota compras` · `/rota manter` · `/rota aceite` · `/rota bloqueios` · `/rota atualizar`

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
