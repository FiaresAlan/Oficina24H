# Oficina 24H — Auditoria pré-entrega para Claude | V2-00–V2-16

**Data:** 13/11/2026 (horário São Paulo; trabalhos continuaram na madrugada UTC de 14/11).  
**Branch exclusiva da V2:** `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13`  
**PR:** [#27](https://github.com/FiaresAlan/Oficina24H/pull/27) — **draft; conflitos com main; não mesclar automaticamente.**  
**Issue:** [#26](https://github.com/FiaresAlan/Oficina24H/issues/26). **Main V1 auditada:** `a3a1279fc409f1997255f6fb5d97c2788b121388` (refrescar antes do merge). **Estado de release: NO-GO.**

## Escopo e rigor de evidências

Auditoria de leitura dos serviços centrais e regras de negócio, inspeção das diferenças com os **13 commits novos da V1 no main**, correções de problemas concretos e varredura automática do repositório. Os instrumentos CI de execução são `tools/ci/verify_contracts.py`, `tools/ci/audit_repo_integrity.py`, `tools/ci/release_gate.py --self-test` e `rojo build default.project.json` (Actions: `.github/workflows/code-health.yml`).

**Medição em CI:** **222 fontes Lua/Luau, 81 suítes, 395 checks do scanner de imports, 393 contratos estáticos no verificador anterior**; 0 falhas nesses escopos na rodada verificada. Duas advertências explícitas: V2-08 FIFO e verificação real Studio/legal ainda pendentes. `RunAllTests` em Luau, gameplay, FPS, física, DataStore de testes, UI e licenças **não são executados em GitHub Actions**. Nenhuma fase [S] ou gate de publicação foi marcada concluída.

## Achados e correções efetivamente aplicadas (código da V2)

### P0-S1 — Gabaritos completos de reparo acessíveis ao cliente: **corrigido no código**

**Antes:** `src/shared/RepairOperations.lua` e `src/shared/WorkshopProcedures.lua` estavam em `ReplicatedStorage.Shared`. O cliente poderia extrair ordem correta das 15 receitas, sequências e parâmetros de avaliação. A V1 homologada pelo Claude já os havia movido para o servidor, mas a V2 estava defasada.

**Depois:** ambos os módulos foram movidos **somente** para `src/server`, usando os arquivos V1 atualizados; ambos os originais de `src/shared` foram excluídos. `WorkshopService`, `StudioPlaceAudit`, testes legados e `V2ProcedureIntegrationTest` agora usam `ServerScriptService.Server`. CI falha se surgir uma cópia em Shared ou um require do cliente para esses gabaritos. Não alegar impossibilidade de bot: o cliente ainda pode observar inputs e outputs normais.

### P0-F1 — Save da frota interrompia liquidação de OS: **corrigido no código, QA de concorrência pendente**

**Antes:** `rateService` invocava `ContractService.FleetDone` enquanto montava estrela, reputação, recibo e progresso da OS. Quando contrato alcançava a meta, `FleetDone` fazia `DataService.Save` com yield, intercalando o Save com a construção do recibo.

**Depois:** nenhum bônus de frota é lançado dentro de `rateService`. Progresso de frota só é agendado com `completeFleetPostSave`, via `task.spawn`, **após confirmação do salvamento da OS**. Manual/colaboração: em `confirmDelivery`, depois do Save de dono e executor; NPC avulso: depois de Save confirmado ou retentativa; staff NPC: pelo `confirmNpcSave`, após Save confirmado. Não bloqueia `RepairDone`/resposta de reparo esperando Save extra da frota. `ContractService` continua protegendo JobId único e prêmio idempotente.

**Risco remanescente que o Claude precisa testar:** se o dono desconectar ou contrato expirar depois do Save de OS mas antes da tarefa assíncrona, a OS estará paga e o contrato (em memória) pode deixar de contar o serviço. A V2 não possui contrato persistido entre reconnects. Decidir se o produto aceita isso ou requer um inbox/recibo durável para a frota; **não chamar esse cenário de resolvido sem teste e decisão**.

### P0-V1 — Correções homologadas da V1 não presentes na branch V2: **reaproveitadas parcialmente, com revisão de compatibilidade**

- `WorkerSettlementProofRules`: compatibilidade de IDs não zero negativos dos jogadores de teste do Roblox; suíte atualizada, sem alterar usuários reais.
- `StaffAssignmentRules.OwnerIsWorking` + `WorkshopService.OwnerTouchedAt` ao diagnosticar/examinar/preparar e filtro de funcionário automático: não toma a OS do dono enquanto ele trabalha; atribuição manual mantém prioridade própria.
- `nearStation`: autorizar ações de TV/prateleira sem estação física só no Studio; em produção falta de objeto **nega** uso remoto.
- `LocationRules`: margem de float32 `1e-3` na borda da loja.
- `DataService`: se API Services falhar com erro identificado no Studio, usar **modo memória com aviso**; em produção não carregar dados fictícios nem sobrescrever perfil real; os mocks continuam independentes.
- `Main.server.lua`: teto secundário de 30 RepairActions/s e oito rebuilds de snapshot/s, sanitização do echo de ACK, limpeza dos budgets ao sair; tudo junto ao orçamento transversal de V2-15. QA exclusivo Studio `ForceJob` e `SkillXP` permite testar 15 reparos determinísticos.
- `Onboarding` e `MetasPanel`: correções V1 de UX touch e ordem de exibição da diária. `EquipmentUpgradePads`: letreiros medidos em studs para evitar colisão visual. `Stock`: alpha dos thumbnails.
- `ProgressService`: descarte de entradas do cache de amigos ao sair.
- Suítes `CompactHudTest` e `PersistenceTest` atualizadas: Id real de OS, e a especialização válida `Suspension` em vez de `Freios` em fixtures de claims/XP.

**Atenção:** estas correções foram integradas estaticamente na V2, mas os testes Play Solo que o Claude realizou na V1 **não equivalem a testes da V2**. É obrigatório repetir os 15 fluxos com a V2 importada e integração final.

### P1-CI — cobertura insuficiente do CI de integridade: **reforçada**

`tools/ci/audit_repo_integrity.py` inspeciona os fontes Lua/Luau, os requires diretos resolvíveis, ausência de soluções privadas em Shared, 81 suites no runner e as dependências obrigatórias. O workflow roda scanner, contratos, autoverificação do gate Go/No-Go e Rojo. Um CI verde significa **código montado e essas verificações estáticas**, não scripts Luau executados, ausência de bugs runtime ou experiência de jogo aprovada.

## Resultado GO/NO-GO e bloqueios que NÃO foram corrigidos

| Severidade | Bloqueio | Estado da auditoria / responsável |
|---|---|---|
| P0 | **Conflitos PR #27 contra `main`** | `mergeable=false`, `mergeable_state=dirty` no checkpoint; Claude resolver com 3-way merge preservando correções V1 |
| P0 | **V2-08 tiers de fornecedores e lotes FIFO** | Ainda não implementados. `Parts`/`Bag` seguem agregados, sem trilha de lote/qualidade; requer regra, migração, UX, idempotência, tests e Save/Load reais |
| P0 | **Direitos comerciais dos assets** | Sprites HUD, ícones, esportivo vermelho, marcas e eventuais CC BY. Créditos na UI não substituem licença/consentimento |
| P0 | **RunAllTests/StudioPlaceAudit com V2 e assets** | Não executados por este assistente; Claude precisa executar no place real e registrar as saídas completas |
| P0 | **V2-11 física/veículo** | Testar direção Hatch real, física, retorno seguro, multiplayer, touch/gamepad e áudio; V2-12/13 `LiveEnabled=false` continua |
| P0 | **Beta fechado, DataStore de homologação, 2 jogadores e latência** | Faltam evidências reais de FPS/memória, clientes reais, colaboração, save falho/retentativas, qualidade dos 15 serviços e métricas do novato |
| P1 | **Contrato de frota após Save** | Possível serviço não contado se jogador desconectar/contrato vencer antes da task pós-save; decidir política e criar teste de concorrência |
| P1 | **Limitadores de remotos e UI V2** | Verificar 10 Hz de gestos, snapshots, cliente touch e maior carrinho sob RTT. Budget estático não prova sensação real |
| P1 | **Build internacional** | `Locale.lua` mantém `pt-BR` apenas; só declarar inglês se traduzido e validado |

## Recomendação específica de merge para Claude

**NÃO usar `git checkout --ours/--theirs` em massa** para resolver os conflitos da PR. A V1 em `main` mudou 13 commits enquanto V2 avançava; existem colidem em `DataService.lua`, `WorkshopService.lua`, `Main.server.lua`, `EquipmentUpgradePads.lua`, `Stock.lua`, `RunAllTests.luau`, `PersistenceTest.luau` e `tools/ci/verify_contracts.py`. Módulos de gabarito precisam permanecer **somente** em `src/server`, não podem reaparecer em `src/shared`; preservar `RequestBudgetRules`, rate limit V2, claims/ledger, novos remotes V2 e os testes novos. `main` atual avança: confirme SHA novamente antes de integrar, use **branch temporária de integração**, nenhum force-push na main. **A PR #27 permanece draft**.

**Ordem recomendada para Claude:**

1. Fixar SHAs do `main` e V2; criar branch de integração saindo da `main`; revisar diferenças e preservar V1 G1–G5 já homologada. Usar `git merge --no-ff work/v2-00-02-fundacao-pilotos-gestao-2026-11-13` apenas nessa branch temporária, resolver conflitos **manualmente**, garantir path server-only dos gabaritos.
2. Executar `python tools/ci/verify_contracts.py`, `python tools/ci/audit_repo_integrity.py`, `python tools/ci/release_gate.py --self-test` e `rojo build default.project.json -o <caminho-local.rbxlx>`. Rodar análise Selene/StyLua se disponível no ambiente Claude e revisar diffs de estilização/Luau, não assumir que Rojo compilou todo o Luau.
3. Fechar **V2-08 FIFO**. Reconciliar estoque inicial `Parts` existente com lotes sem duplicar itens/margem. Testar migração/reconnect, transferência `Bag`, consumo único e rollback de OS em falha de crédito.
4. Sincronizar build integrado no **place privado de homologação** com assets organizados. Rodar no **Command Bar do Studio (servidor/Edit)**:
   ```luau
   print(require(game.ServerStorage.Tools.RunAllTests))
   print(require(game.ServerStorage.Tools.StudioPlaceAudit))
   print(require(game.ServerStorage.Tools.V2ReleasePlaceAudit))
   print(require(game.ServerStorage.Tools.V2BetaSmokeAudit))
   ```
   Não mascarar `FAIL`/erros de require como sucesso, inspecionar avisos.
5. Testar **15 defeitos**, 2 jogadores reais/Start Server, NPC staff e avulso, collab, expiração/desconexão após Save, Save falho e replay de prova. No Studio a função `ServerStorage.QA:Invoke("ForceJob", player, "FlatTire")` permite forçar cada um dos 15 defeitos sem RNG. Confirmar permissões Studio, sem endpoint QA publicado.
6. Preencher `docs/release/V2_TEST_MATRIX_15_SERVICOS.csv` com **provas verdadeiras** e SHA de build. Registrar os 16 gates em `docs/release/V2_RELEASE_EVIDENCE.json`, rodar `python tools/ci/release_gate.py --mode enforce --sha SHA_DO_BUILD`. Somente passar após verificação humana de links, licenças e `owner_go`. O manifesto não publica o jogo e o CLI não autentica a veracidade dos links.
7. Realizar beta fechado e corrigir falhas P0/P1. Não ativar V2-12/13 antes de QA físico específico e decisão do proprietário.

## Conclusão para transferência

**Código V2 auditado estaticamente e corrigido nos P0 identificados; a PR #27 é o material recomendado para Claude iniciar integração/homologação.** Não é uma certificação de que todos os módulos Luau executam sem falhas. Os bloqueios P0 acima impedem declarar a V2 terminada para lançamento. A entrega correta ao Claude é branch + PR #27 + Issue #26 + este documento, para integrar e testar **sem refazer do zero o código entregue**.
