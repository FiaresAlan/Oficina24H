# Oficina 24H — V2-07: Bairro vivo e escalável

**Engenharia implementada na PR #27, 13/11/2026.** Nenhum teste de jogabilidade, streaming ou FPS foi executado no Roblox Studio nesta rodada. A main permanece reservada à homologação V1 do Claude.

## Arquitetura de implementação

A V1 já possui clientes reais chegando dirigindo, NPCs e rivais. A V2-07 preserva essas operações e adiciona exclusivamente ao cliente figurantes de tráfego e pedestres. Não há nova física, pathfinding, inventário, economia ou criação de clientes no servidor. Todos os modelos ambientais têm colisão, toque e consultas desativados. Os loops de trabalho/chegada de clientes continuam totalmente separados.

- **src/shared/V2NeighborhoodRules.lua:** 15 trechos fixos — 6 corredores de trânsito na rua principal e lateral e 9 trechos de caminhada nas calçadas e comércio. Definições de faixa, direção, distância, seleção de rotas e limites por dispositivo/quantidade de jogadores/FPS.
- **src/server/V2NeighborhoodAssets.lua:** publica no máximo 3 avatares com Humanoid/PrimaryPart de ServerStorage.Assets.Clientes, após AssetSafetyRules.StripScripts. Nunca publica scripts ou prompts de interação. Se modelos não forem importados, os pedestres ficam desativados em vez de receberem modelos low-poly genéricos.
- **src/client/V2NeighborhoodAmbient.client.lua:** clona apenas alguns modelos 3D existentes de ReplicatedStorage.VehiclePreviews e V2PedestrianPreviews. Usa um único Heartbeat limitado, pool global, LOD por distância, orientação, caminhada R15 com animação já registrada, e encerra/remova os visuais locais ao sair.
- **src/server/Main.server.lua:** apenas inicializa a publicação de templates. Os rivais e clientes V1 continuam intactos.

## Densidade e performance

| Cenário | Limite de pedestres | Limite de carros | Intervalo de atualização |
| --- | ---: | ---: | --- |
| PC, FPS estável e poucos jogadores | 6 | 3 | 90 ms |
| Touch, FPS estável | 3 | 1 | 90 ms |
| FPS abaixo de 36, ou servidor com 7+ jogadores | Redução automática | 1 ou redução | 180 ms para FPS baixo |

Máximo de 9 entidades ambientais ativas e pool global com até 12 modelos reutilizáveis. O cliente cria ou recolhe atores conforme a proximidade da câmera (210 studs PC / 145 studs touch), com cooldown por rota. As rotas são limitadas por origem/destino na geometria oficial de BuildCity, BuildNeighborhood e LotPath. Não cobrem calçadas com colisores nem bloqueiam entradas de lote. A entidade de tráfego desaparece quando se aproxima de veículos reais em Workspace.Vehicles ou Arrivals.

Ao sair, as instâncias visuais, modelos em pool e tracks são destruídos. Luzes, partículas e emissão adicional dos figurantes são desligadas para poupar dispositivos móveis. Esses limites reduzem o custo esperado, mas não são medição de FPS.

## Entregador de peças (visual, após compra real)

Quando BuyPart ou Checkout efetua pagamento e registra estoque no perfil V1, WorkshopService emite um evento no canal de eventos do servidor, apenas para o proprietário: V2NeighborhoodCourier com PartCount. O cliente cria uma passagem curta de um entregador na frente da autopeças, de no máximo 14 segundos. Essa animação tem prioridade sobre outros figurantes dentro do teto global de 9.

**A peça já foi comprada e registrada antes do evento.** A entrega não cria saldos, não adiciona peças, não retira material, não entrega segunda vez e não afeta o sucesso da compra. Se faltar modelo de NPC ou o jogador estiver longe, o evento visual é ignorado sem impacto na economia. Não representa um novo prazo/logística real de entrega.

O RivalService existente mantém atendimentos reais das oficinas rivais, sem modelos V2 simulando pagamentos ou ordens falsas.

## Testes e QA

- tools/V2NeighborhoodRulesTest.luau: rotas, direção, ID, culling, limites desktop/mobile/FPS baixo, recusa de valores inválidos, sem criação fora de alcance.
- tools/V2NeighborhoodPlaceAudit.luau: verifica Bairro, Map.Ground, assets de carros, avatares e importação dos três veículos piloto. Ausências de arte geram WARN, nunca PASS.
- tools/RunAllTests.luau: registra as duas suites e preserva todos os testes V1 e V2.
- tools/ci/verify_contracts.py: protege isolamento client-only, limites do pool, reuso de modelos reais, validação de scripts, evento de compra concluída e cleanup.
- GitHub Actions: CI estático e compilação Rojo code-only. Não executa a simulação Roblox Studio.

**QA Studio pendente:** conferir o tamanho/altura/pivôs dos modelos, animação de caminhada R15, convivência com carros reais de clientes e rivais, compra de peça válida/inválida, retorno a zonas distantes, limpeza e streaming, FPS de celular de entrada/alto desempenho e contagem de 1/2/6/10 jogadores. Ajustar limites conforme medições, não presumir performance.

**Integração:** não mesclar diretamente com main sem conciliar alterações recentes do Claude e refazer testes. Próxima engenharia: V2-08 — gestão de caixa, despesas, estoque e lucro líquido.
