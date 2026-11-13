# Oficina 24H — V2-06 | Expansão da oficina e compras seguras

**Data:** 13/11/2026. **Código da fase:** branch work/v2-00-02-fundacao-pilotos-gestao-2026-11-13, PR #27 (rascunho). **Main:** V1 continua sob QA do Claude. Os testes Luau/Studio não foram executados nesta rodada.

## 1. Resultado de engenharia

A evolução dos quatro prédios existentes continua usando a fonte única \`WorkshopLevels.lua\` e as estações da V1 — a V2 não substitui a loja de autopeças. A construção está amarrada a requisitos reais e conferidos no servidor (saldo, nível empresarial, reputação, XP e equipamentos), a plot do proprietário, proximidade física à Construtora e **todos os boxes livres**.

| Prédio | Preço da próxima compra | Boxes após compra | Funcionários possíveis |
| --- | ---: | ---: | ---: |
| Garagem de bairro (inicial) | — | 1 | 0 |
| Oficina, nível 1 | 1.500 moedas | 2 | 1 |
| Centro automotivo, nível 2 | 6.000 moedas | 4 | 2 |
| Oficina premium, nível 3 | 18.000 moedas | 6 | 2 |

As vagas de equipamento dependem da geometria real de cada nível, calculadas com \`WorkshopLevels.MaxEquipment(level)\`. A tela mostra o aumento **exato** de boxes, possíveis funcionários e vagas de máquinas, sem inventar ROI ou lucro líquido; a contabilidade detalhada fica para V2-08.

As máquinas já compradas continuam com progressão N1–N3, usando \`EquipmentUpgradeRules\`: bônus moderado de 3% por nível adicional na recompensa dos serviços aplicáveis, +2 pontos de qualidade para NPCs por nível, e redução de duração de trabalho do NPC em 8% por nível. A economia continua validada no servidor.

## 2. Proteção contra compras acidentais

### Equipamentos — sem compras por pisar

O arquivo \`src/server/EquipmentUpgradePads.lua\` foi refeito: pads físicos **não possuem colisor, Touched nem polling de posição por frame** para comprar. Só um \`ProximityPrompt\` acionado intencionalmente começa a cotação; o segundo acionamento do mesmo prompt em até 14 segundos solicita a compra. O jogador vê máquina, nível e preço antes de decidir.

O servidor revalida: personagem vivo, distância até 7,5 studs, plot pertencente ao comprador, propriedade real do equipamento, nível, próximo preço, saldo e orçamento. Ao confirmar, o estado pendente é consumido **antes** de invocar \`WorkshopService.UpgradeOwnedEquipment\`, que delega o débito/nível para \`DataService.UpgradeOwnedEquipment\` sem yield. O pad é sincronizado após compra e perde a cotação anterior, logo um segundo nível não pode ser comprado com a confirmação do primeiro.

Os prompts usam teclado E, botão X do gamepad e interface de toque do HUD da V1. \`OwnerUserId\` é gravado no pad e prompt; interação de outro jogador é rejeitada no servidor mesmo se um client adulterar o prompt.

### Prédio — confirmação do nível exato

\`src/client/ConstrutoraPanel.client.lua\` mostra os requisitos, o preço e benefícios adicionais antes da obra; **primeiro clique = prévia, segundo clique = confirmação**. O cliente envia \`Confirm=false\` ou \`Confirm=true\`; o servidor só autoriza o segundo quando uma cotação igual (\`Kind\`, \`Id\`, \`Source\`, \`Target\`, \`Cost\`) continua válida por até 14 segundos e quando todas as condições são rechecadas.

Fechar/reabrir o painel ou ver outro nível não confirma automaticamente. Não se depende da flag enviada pelo cliente para definir valores: o servidor recalcula o prédio, custo, saldo, XP, reputação, número de equipamentos e disponibilidade de boxes. O débito e a nova versão do nível são alterados no mesmo perfil **antes** da reconstrução do mundo. Recarregar o place usa o nível persistido e recria as partes.

As ofertas são apenas temporárias no servidor, por usuário; elas não viram recibos financeiros nem geram despesa na prévia. Repetir a confirmação sem nova oferta não debita novamente. A tela utiliza ScrollingFrame para mostrar os requisitos em celular sem cobrir o gameplay.

## 3. Antes/depois visível no mundo

\`src/server/V2ExpansionVisuals.lua\` acrescenta sinalização industrial diferenciada para 1/2/4/6 boxes, recepção, capacidade do estoque/equipamentos e equipe. Essas peças são leves, ancoradas, sem colisão/toque/query; são reconstruídas junto ao prédio e sempre destroem a pasta anterior, evitando partes órfãs no logout ou upgrade.

O prédio, boxes reais, elevadores, estações físicas e capacidade de funcionários continuam sendo montados por \`StationService.ApplyLevel\` e \`WorkshopLevels\`. Não se usa geometria low-poly como asset obrigatório. O jogador já tem os GLBs/3D packs que baixou; esta fase não exige novos downloads.

## 4. Matriz de testes e segurança

- \`tools/V2UpgradePurchaseRulesTest.luau\`: primeira tentativa não cobra, segunda confirma, expiração, preço/nível/fonte adulterados, replay, quote inexistente, dados inválidos e benefícios de capacidade.
- \`tools/V2ExpansionVisualsTest.luau\`: quatro níveis, sinalização adequada, não colisão, limite de peças e reconstrução idempotente.
- \`tools/PersistenceTest.luau\`: saldo e nível mudam juntos num perfil, registro/salvamento no DataStore simulado, reconexão e confirmação repetida.
- \`tools/EquipmentUpgradeTest.luau\`: economia da máquina, nível máximo, falta de saldo, tentativa repetida, persistência; mantido.
- \`tools/ci/verify_contracts.py\`: substituiu o antigo contrato que *exigia comprar ao pisar* por verificações para os prompts, autorizações e confirmação explícita; compila place code-only via Rojo.

**QA real ainda necessário no Studio:** aproximar/sair dos pads sem comprar, pressionar prompt 1 vez, confirmar 2 vezes, mudar de plot, tentar pad de vizinho, morrer entre cliques, perder saldo entre cliques, 1→2→3 níveis, mudar o preço/nível, dois jogadores, despawn antes do save, relogar, obstruções, propriedades mobile/gamepad, FPS com 6 boxes e 2 mecânicos. Rodar \`tools/RunAllTests.luau\` e registrar relatório. **CI verde não equivale a esses testes.**

## 5. Integração da V1 e próximo passo

A V2 fica na PR #27, fora da main durante a homologação do Claude. Antes de merge: reconciliar \`Main.server.lua\`, \`WorkshopService.lua\`, \`StationService.lua\`, \`ConstrutoraPanel.client.lua\`, \`EquipmentUpgradePads.lua\` e o pipeline de testes com qualquer correção da V1, rodar CI e repetir Studio.

**V2-07** será o bairro com pedestres e tráfego ambiental sob pooling/limites de desempenho.
