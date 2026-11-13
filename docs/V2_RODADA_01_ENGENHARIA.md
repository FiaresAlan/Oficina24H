# V2 — Rodada 1: desenvolvimento incremental, sem Studio

**Branch de engenharia:** `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13` (base V1 C31, HEAD de partida `0d00fa60`).

**V2-00 parcial:** `V2CompatibilityRules` audita campos schema v11, saldo e dados privados no snapshot, somente leitura. Não realiza migrações nem substitui a auditoria financeira, o QA do Claude ou provas de atomicidade multi-perfil.

**V2-01 parcial:** `V2VehiclePilotRules` vincula três pilotos do catálogo V1: `Veiculo_Hatch_MG3`, `Veiculo_Sedan_Civic`, `Veiculo_Picape_S10`. Valida a integridade V1 e Attachment de capô/portas/rodas; pivô ausente é AVISO, não posição física fictícia. Script separado de auditoria em Studio: `tools/V2PilotPlaceAudit.luau`. Faltam assets reais, rig, materiais, renderização e LOD para concluir V2-01.

**V2-02 slice funcional:** novo resumo de operação no painel existente de Ordens. O cálculo usa snapshot já saneado pelo servidor, mostra fila, ocupação de boxes, equipe, caixa e total **bruto** do histórico recente. Não altera economia, não expõe defeito não diagnosticado e NÃO afirma lucro líquido (V2-08). Faltam recepção física, precificação, priorização, estados completos e onboarding V2-02.

**Regression suites preparadas:** `V2FoundationTest`, `V2PilotRigTest`, `V2ManagementSummaryTest`, registradas no `RunAllTests`; **não foram executadas no Roblox Studio**.

**Não iniciado:** V2-03 até V2-16; nenhum GLB V2 foi importado/baixado e o place está intacto. `main` não foi alterada por esta rodada.

**Antes de mesclar:** reler HEAD da main, respeitar correções simultâneas do Claude na V1 (Issue #15), revisar conflitos de `Orders.lua` e `RunAllTests.luau`, rodar CI Rojo/contratos, depois realizar PlayTest Studio dos 15 serviços, painel e três modelos piloto; decisões de publicação pertencem ao proprietário.

**Critério de status:** subpartes de 00/01/02 implementadas, mas **nenhuma das três fases integralmente concluída ou homologada**. Marcar [S] apenas com evidência.
