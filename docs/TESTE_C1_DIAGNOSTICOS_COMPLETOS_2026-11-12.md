# C1 — Diagnóstico profundo em todos os serviços

**Branch:** `work/oficina24h-c1-diagnosticos-completos-2026-11-12`  
**Base:** `work/oficina24h-b4-orientacao-ordens-2026-11-12`  
**Status:** código no GitHub, testes Luau escritos; sem execução no Roblox Studio.

## Escopo entregue

Antes, apenas pneu furado, bateria fraca e superaquecimento obrigavam o jogador a coletar evidência. Agora os **15 defeitos** do catálogo exigem um exame coerente antes de confirmar a hipótese. Os laudos são server-side; o cliente não recebe o DefectId nem o ID de diagnóstico correto pela ação de exame.

| Exame físico | Defeitos cobertos |
|---|---|
| Pressão do pneu | Pneu furado |
| Tensão da bateria | Bateria fraca |
| Temperatura do motor | Superaquecimento |
| Rodas e pneus | Pneu desgastado, roda desbalanceada |
| Sistema de freios | Pastilha desgastada |
| Suspensão e geometria | Folga de suspensão, braço quebrado, desalinhamento |
| Diagnóstico do motor | Falha de ignição, retífica |
| Teste elétrico | Falha no circuito |
| Lataria e pintura | Amassado, colisão, pintura danificada |

- `DiagnosisEvidence.Coverage` percorre o catálogo para impedir que novos defeitos sejam criados sem exame relevante.
- `InspectionPointRules` define 9 pontos espaciais. `VehicleService` já os cria automaticamente a partir da tabela; sem exigir MeshParts novos.
- `DiagnosisGame` usa grade 3×3 com rolagem e laudos acumulados.
- `InspectionMarkers.client` mostra no máximo 3 marcadores próximos ao jogador e só durante a conversa/inspeção da própria OS, sem cobrir o carro com 9 etiquetas simultâneas.
- `WorkshopService` mantém as verificações de proprietário da OS, posição física, ordem em andamento e evidência de exame específico.
- Os procedimentos de reparo existentes, pagamentos, DataStore e estoque não foram alterados nesta fase.

## Validação de produto obrigatória

- [ ] Executar `RunAllTests`: verificar especialmente as suítes DiagnosisEvidenceTest e InspectionPointTest.
- [ ] Para cada defeito (15), conversar com o cliente, executar o exame adequado e concluir a hipótese.
- [ ] Antes do exame, confirmar que a hipótese correta não é aceita.
- [ ] Exame irrelevante não pode liberar diagnóstico; respostas não contêm IDs secretos do servidor.
- [ ] Testar as nove posições em modelos hatch/SUV/picape/esportivo com StreamingEnabled.
- [ ] Testar 2 jogadores: outro jogador não pode examinar OS que não lhe pertence.
- [ ] Verificar que os marcadores não cobrem os prompts e que os botões da grade cabem em PC e celular.
- [ ] Medir FPS, renderização de nove sockets e ciclo de vida de carros abandonados.

## Limites

Os laudos são simulados para gameplay. Não são medições automotivas certificadas. Os pontos físicos são aproximações relativas às dimensões do carro até os modelos receberem sockets aferidos no Studio. Esta fase aprofunda diagnóstico em todas as especializações, mas ainda não substitui o minijogo de reparo genérico dos 12 serviços restantes.

**Não marcar como testado/homologado** sem execução no Studio, multiplayer e celular.
