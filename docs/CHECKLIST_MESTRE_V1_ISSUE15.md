# Oficina 24H — CHECKLIST MESTRE (fonte de verdade)

> **NOVA DIREÇÃO V2 — APENAS DOCUMENTAÇÃO:** [CHECKLIST MESTRE V2 (Issue #26)](https://github.com/FiaresAlan/Oficina24H/issues/26) · [direção híbrida](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/DIRECAO_JOGO_V2_2026-11-13.md) · [especificação de test-drive FUTURO](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/PROPOSTA_TEST_DRIVE_V2_FUTURO.md). Nenhuma **mecânica V2** foi implementada; seguimos concluindo as pendências de código da V1 antes de iniciar a V2. Esta Issue #15 permanece como **histórico V1**, não deve marcar tarefas V2.

**Revisado em:** 13/11/2026 (homologação V1 — rodada 1 no Studio)  
**Último desenvolvimento integrado:** homologação V1 rodadas 1 e 2 ([relatório](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/HOMOLOGACAO_V1_2026-11-13.md)). Antes: [V1 C31 — auditoria estrutural de modelos](https://github.com/FiaresAlan/Oficina24H/commit/0ef749b5c56d769fac46c2bea9262d5f65e7efba) e [C30 — sanitização preventiva](https://github.com/FiaresAlan/Oficina24H/commit/a972b386454d60456dac56f61bae3578c96ad0cf) em `main` (13/11/2026).  
**Branch principal de desenvolvimento:** [`main`](https://github.com/FiaresAlan/Oficina24H/tree/main), atualizada por fast-forward com V1 C29 (5 commits). Homologação no Studio continua pendente.  
**`main` atual:** `5b15eac` — A1–C31 + homologação rodadas 1 e 2; [CI C30 aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43478961090) e [CI C31 aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43479613749). **Rodadas 1–2 no Studio: place de QA 2014/0 + 15 serviços; place original 2029/0 + 3 serviços reais. Duas contas, aparelho físico, licenças e publicação pendentes.**

> **Como ler:** `[x]` = o item foi comprovadamente registrado no GitHub (código ou documentação); `[ ]` = ainda não cumprido ou não verificado. **Código escrito não é funcionalidade aprovada em Roblox Studio.** O texto é atualizado por edições desta issue/commits, não automaticamente nem em background. Clique em **History** (edições) ou recarregue a página para conferir os check-ins.

### Foto geral

- **[PRs #20](https://github.com/FiaresAlan/Oficina24H/pull/20), [#21](https://github.com/FiaresAlan/Oficina24H/pull/21) , [#22](https://github.com/FiaresAlan/Oficina24H/pull/22) , [#23](https://github.com/FiaresAlan/Oficina24H/pull/23), [#24](https://github.com/FiaresAlan/Oficina24H/pull/24) e [#25](https://github.com/FiaresAlan/Oficina24H/pull/25), além de C10–C29 por fast-forward, foram integrados à `main`.** PRs anteriores (#2–#14, #17–#19) podem permanecer abertos, porém são redundantes para merge; não mesclar duas vezes.
- **Studio (13/11):** `RunAllTests` **2014 OK, 0 falhas** no place de QA ([relatório](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/HOMOLOGACAO_V1_2026-11-13.md)); não vale como place original.
- **[PR #7 — integração A1/A2](https://github.com/FiaresAlan/Oficina24H/pull/7)** reúne correções para homologação; **#8–#14 e #17–#19** são PRs empilhados sobre branches de trabalho. Não mesclar PRs redundantes uns sobre os outros sem reconciliar.
- **#1** é somente a proposta do Product Master v3; não é aprovação formal do v3 nem execução do produto.
- **Bloqueio de lançamento:** falta place original, aparelhos físicos, 2 jogadores, DataStore publicado e assets reais. Merge de código foi autorizado pelo Product Owner, separadamente da homologação.

---

## Plano original de 14 fases — check-in tarefa por tarefa

Os números 01–14 seguem o plano do Claude. Os códigos A1, A2, B1 etc. são **incrementos de implementação**, portanto não representam um novo plano de 14 fases.

### Fase 01 — A0: auditoria estática
- [x] Ler os módulos de oficina, clientes, persistência, diagnóstico, reparos e testes.
- [x] Documentar os riscos prioritários e limites da auditoria — [PR #2](https://github.com/FiaresAlan/Oficina24H/pull/2).
- [ ] Revisar e encerrar/mesclar o PR de documentação quando a integração for definida.

### Fase 02 — A1: correções de integridade (rivais e estabelecimentos)
- [x] Evitar crédito antecipado de faturamento/nota de concorrentes NPC — [PR #3](https://github.com/FiaresAlan/Oficina24H/pull/3).
- [x] Negar compras/ampliações quando loja/construtora estiver ausente em produção.
- [x] Escrever regressões de regras de rival/proximidade.
- [ ] Executar regressões, cenários de falha e 2 jogadores no Studio.
- [ ] Integrar na `main` após homologação.

### Fase 03 — A1: sessões, idempotência e persistência
- [x] Bloquear duas sessões de reparo simultâneas e limpar sessões expiradas/abandonadas — [PR #6](https://github.com/FiaresAlan/Oficina24H/pull/6).
- [x] Escrever testes de ciclo de vida das sessões.
- [ ] Auditar e testar duplicações de compra, pagamento, RemoteEvent, cancelamento e rollback de todas as OS.
- [ ] Testar migrações e compatibilidade do DataStore v4 em homologação.
- [ ] Integrar na `main` após homologação.

### Fase 04 — A2: diagnóstico com evidências
- [x] Criar exames de pneu, bateria e arrefecimento com validação no servidor — [PR #4](https://github.com/FiaresAlan/Oficina24H/pull/4).
- [x] Adicionar pontos físicos de inspeção e exigir exame relevante — [PR #8](https://github.com/FiaresAlan/Oficina24H/pull/8).
- [x] Integrar painéis, marcadores e testes escritos.
- [ ] Conferir diagnóstico de ponta a ponta, permissões e posição real dos pontos no Studio.
- [ ] Integrar na `main` após homologação.

### Fase 05 — A2: reparos distintos e integração
- [x] Pneu: localização do furo e pressão; bateria: terminais; arrefecimento: fluido/sangria/ventoinha — [PR #5](https://github.com/FiaresAlan/Oficina24H/pull/5).
- [x] Manter minijogo legado nos demais defeitos para preservar especializações.
- [x] Adicionar duas etapas físicas de preparo por reparo-piloto — [PR #10](https://github.com/FiaresAlan/Oficina24H/pull/10).
- [x] Implementar props/feedback visual local e sockets opcionais por modelo — [PR #11](https://github.com/FiaresAlan/Oficina24H/pull/11).
- [ ] Integrar e verificar 3 ciclos completos no Studio; alinhar sockets às malhas dos carros.
- [ ] Integrar na `main` após homologação.

### Fase 06 — A3: onboarding e HUD
- [x] Redesenhar HUD com navegação única por dispositivo, objetivo contextual e menus sem overlay escuro — [PR #12](https://github.com/FiaresAlan/Oficina24H/pull/12).
- [x] Corrigir dock de celulares pequenos com alvos maiores/rolagem — [PR #13](https://github.com/FiaresAlan/Oficina24H/pull/13).
- [x] Orientar jogador a carro/loja/máquina e incluir preparo no onboarding — [PR #14](https://github.com/FiaresAlan/Oficina24H/pull/14).
- [ ] Playtest visual da HUD em PC, touch, gamepad e acessibilidade.
- [ ] Validar primeiro atendimento completo em 30–60 s e ausência de sobreposição.
- [ ] Integrar na `main` após homologação.

### Fase 07 — A4: testes completos e performance
- [x] Registrar 225 checks novos em 13 suítes Luau, incorporadas ao `RunAllTests` (branch B4).
- [x] Preparar roteiros de QA das mudanças A1–B4 na pasta `docs`.
- [x] Executar `RunAllTests` e corrigir **todos** os FAIL/ERRO/AUSENTE — **2014/0** (place de QA, 13/11).
- [ ] Medir FPS, memória, carga de NPCs e veículos, comportamento com StreamingEnabled. *(parcial)*
- [ ] Fazer testes de segurança, latência e repetição de remotes. *(parcial)*

### Fase 08 — A5: homologação no Roblox Studio
- [ ] Sincronizar branch B4 com Rojo preservando `ServerStorage/Assets` existente.
- [x] Testar o ciclo cliente → diagnóstico → preparo → reparo → pagamento → avaliação — 15 serviços (place de QA).
- [ ] Testar 2 jogadores e contratos, saída/reconexão, inventário, progressão e DataStore publicado.
- [ ] Testar PC/celular real/gamepad e confirmar licenças dos assets.
- [x] Registrar resultados, prints e bugs com severidade — [relatório](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/HOMOLOGACAO_V1_2026-11-13.md).

### Fase 09 — A6/A7: beta fechado e decisão de lançamento
- [ ] Rodar beta fechado com 15–20 jogadores e feedback de diversão.
- [ ] Corrigir problemas críticos de UX, economia, retenção e performance.
- [ ] Tomar decisão de lançamento por métricas observadas, não por quantidade de features.
- [ ] Preparar release e validação de publicação.

### Fase 10 — B1: cooperação de verdade
- [x] Remover conclusão/pagamento instantâneo de colaborador e exigir reparo efetivo — [PR #9](https://github.com/FiaresAlan/Oficina24H/pull/9).
- [x] Dividir remuneração e separar estoque/reputação do dono e XP do executor no código.
- [ ] Homologar contratos com 2 jogadores e casos de desconexão, fraude e latência.
- [ ] Implementar cooperação **simultânea** por tarefa, se aprovada após teste do núcleo.

### Fase 11 — B2: carros, máquinas e componentes modulares
- [x] Criar sockets de `Attachments` opcionais para componentes e ferramentas — [PR #11](https://github.com/FiaresAlan/Oficina24H/pull/11).
- [x] Criar props provisórios locais e mudanças visuais de roda/capô.
- [ ] Alinhar sockets em pelo menos **um carro real** no Studio.
- [ ] Desenvolver desmontagem física modular, animações e ferramentas 3D definitivas, se viável e aprovada.
- [ ] Testar desempenho de modelos/componentes por dispositivo.

### Fase 12 — B3: guincho de motor e dupla operação
- [ ] Definir interação física com guincho, riscos e cooperação por papéis.
- [ ] Prototipar guincho e extração do motor no Studio.
- [ ] Testar sincronização/física com dois jogadores.

### Fase 13 — B4/B5: arquétipos de NPC e logística
- [ ] Priorizar arquétipos com comportamentos distintos após playtest.
- [ ] Especificar e implementar logística de peças/serviços somente com validação de diversão e custo.
- [ ] Testar impacto em performance, progressão e ritmo das ordens.

### Fase 14 — B6–B9: expansões futuras
- [ ] Revisar escopo de guincho externo, restauração, tuning/ECU/dinamômetro e regiões maiores.
- [ ] Aprovar cada expansão separadamente; **nenhuma é bloqueadora do MVP**.
- [ ] Implementar somente funcionalidades com justificativa de produto.

---

## Continuação autorizada — meta de PRODUTO FINAL (C1–C3)

> O Product Owner pediu o produto final de alta qualidade, não apenas um MVP. O escopo inclui arte, áudio, estabilidade, diversidade e acabamento. Estes check-ins significam **código escrito**, e não publicação aprovada.

### C1 — diagnóstico contextual para todas as especializações — [PR #17](https://github.com/FiaresAlan/Oficina24H/pull/17)
- [x] Criar laudos relevantes para os **15 defeitos** e 9 categorias de exame.
- [x] Adicionar nove pontos físicos de inspeção e grade 3×3 no painel.
- [x] Limitar marcadores próximos para evitar UI poluída.
- [x] Escrever regressões de cobertura e regras de acesso.
- [ ] Executar diagnósticos dos 15 defeitos no Studio, com 2 jogadores e carros de portes diferentes.
- [ ] Alinhar sockets e modelos 3D reais, medir latência e ajustar game feel.
- [ ] Integrar na `main` somente após QA.

### C2 — procedimentos de reparo para os 15 serviços — [PR #18](https://github.com/FiaresAlan/Oficina24H/pull/18)
- [x] Substituir o timing genérico em 12 serviços por quatro famílias com receitas específicas.
- [x] Integrar UI de sequência, calibração, circuito e acabamento ao fluxo existente.
- [x] Manter qualidade, pagamento, XP e consumo sob autoridade do servidor.
- [x] Escrever testes de cobertura para todos os serviços e payloads inválidos.
- [x] Executar TODOS os 15 reparos em Studio, com estoque, nível e máquinas — 15/15 (place de QA).
- [ ] Testar abuso de remotes, conclusão dupla, nível incorreto, performance e touch/gamepad. *(parcial)*
- [ ] Substituir controles provisórios por interação física de peças/animações 3D onde necessário.
- [ ] Integrar na `main` após homologação.

### C3 — critérios de qualidade e auditoria do place — [PR #19](https://github.com/FiaresAlan/Oficina24H/pull/19)
- [x] Corrigir o runner para mostrar erros de `require`, suites ausentes e resumo final REPROVADO.
- [x] Criar `StudioPlaceAudit.luau` para verificar carros/NPCs, locais físicos, scripts em assets e cobertura do catálogo.
- [x] Documentar critérios além do MVP em `docs/QUALIDADE_PRODUTO_FINAL_2026-11-12.md`.
- [ ] Executar a auditoria em Roblox Studio com o place real.
- [ ] Corrigir toda falha de inicialização/asset e toda regressão de jogo.
- [ ] Obter autoria/licenças pendentes, créditos e publicação segura.

### Integração geral — [PR #20](https://github.com/FiaresAlan/Oficina24H/pull/20)
- [x] Consolidar **o código versionado** A1–C3 numa branch única que pode ser sincronizada pelo Rojo.
- [x] Abrir PR único **draft para main**, separado dos PRs empilhados de engenharia.
- [ ] Executar a branch integrada no Studio e corrigir qualquer erro de compilação, fluxo ou asset.
- [x] Verificar merge limpo em `main` (PR #20, commit `8e0182b3`). Revisão de Studio e conflitos futuros permanece pendente.
- [ ] Aprovar **publicação** apenas quando os gates de produto final estiverem satisfeitos.

### C4 — build e contrato automático de código — [PR #20](https://github.com/FiaresAlan/Oficina24H/pull/20)
- [x] Criar `.github/workflows/code-health.yml` para build Rojo e verificação em push/PR.
- [x] Criar `tools/ci/verify_contracts.py` para auditar as 15 receitas, 9 exames, remotes e suites.
- [x] Disparar a primeira execução de CI da branch integrada — [ver ações](https://github.com/FiaresAlan/Oficina24H/actions/workflows/code-health.yml).
- [x] **CI PASSOU** no commit `b8805152f482dda67666644fddb029a97cf39ab9`: [execução #43330892000](https://github.com/FiaresAlan/Oficina24H/actions/runs/43330892000). Verificador de contratos + setup Rokit + build de código Rojo concluídos com sucesso.
- [ ] Executar `RunAllTests` em Studio e `StudioPlaceAudit` com os assets do place. *(parcial)*
- [ ] Confirmar qualidade visual e funcional em aparelhos reais antes de publicar.

### C5 — operações de reparo autorizadas no servidor — [PR #21 merged](https://github.com/FiaresAlan/Oficina24H/pull/21)

- [x] Criar `RepairActionRules` com estado incremental de 7 famílias de interação e revisão crescente.
- [x] Exigir sessão GUID/token por reparo e validar profissional, proximidade, equipamentos e estoque a cada comando.
- [x] Usar confirmação `RepairActionAck` antes de atualizar os controles na HUD; rejeitar replay e valores fora dos passos permitidos.
- [x] Ignorar formulário final do cliente: servidor reconstrói o resultado a partir das ações previamente confirmadas.
- [x] Escrever `RepairActionRulesTest`, integrá-lo a `RunAllTests` e incluir verificações no CI.
- [x] **CI Rojo/contratos aprovado** no commit `f6def6e4` — [execução #43334374170](https://github.com/FiaresAlan/Oficina24H/actions/runs/43334374170).
- [x] **Fase C5 integrada à `main`** no commit `db6557f5`, preservando histórico.
- [ ] Executar regressões no Roblox Studio, com latência/rede móvel, gamepad e dois jogadores.
- [ ] Auditar abuso de remotes, cancelamento/desconexão, timeout, duplicação de pagamentos e economia real no place.
- [ ] Confirmar a experiência de reparo com jogadores reais: o protocolo é server-authoritative, mas não impede automação legítima de comandos por bots.

### C6 — resiliência de reparos a rede lenta — [PR #22 merged](https://github.com/FiaresAlan/Oficina24H/pull/22)

- [x] Implementar detecção de repetição exata da última ação confirmada sem executá-la novamente.
- [x] Revalidar autorização, distância e equipamento antes de confirmar retransmissão.
- [x] Correlacionar ACK pelo `RequestRevision` para ignorar respostas atrasadas de comandos anteriores.
- [x] Tentar novamente a mesma revisão até três vezes sem duplicar uma operação.
- [x] Vincular `CancelRepair` a `JobId` + token; preservar compatibilidade do minijogo timing.
- [x] Acrescentar regressões de replay, revisão e cancelamento; incorporar invariantes ao CI.
- [x] **CI Rojo e contratos da branch aprovado**, [execução #43336476694](https://github.com/FiaresAlan/Oficina24H/actions/runs/43336476694), commit `1d76d6f7`.
- [x] **PR #22 integrado à `main`**, commit `428d69d6`; [CI do merge aprovado — execução #43336580408](https://github.com/FiaresAlan/Oficina24H/actions/runs/43336580408).
- [ ] Executar regressões Luau no Studio com simulação de perda de ACK e latências de 200–1000 ms.
- [ ] Validar os 15 serviços, cancelamentos, expiração, modo mobile/gamepad e contratos com 2 jogadores.
- [ ] Validar entrega com ACK perdido e reconciliação de saldo/OS no servidor, sem pagamento duplicado.

### C7 — comprovantes de entrega e recuperação de pagamento — [PR #23 merged](https://github.com/FiaresAlan/Oficina24H/pull/23)

- [x] Criar comprovantes privados por `UserId + JobId + Token` com expiração em 15 minutos e limite de oito por jogador.
- [x] Registrar o comprovante após o efeito econômico e antes do evento de resultado `RepairDone`.
- [x] Recuperar conclusão duplicada devolvendo **o mesmo** comprovante, sem retirar peças ou pagar novamente.
- [x] Implementar `CheckRepairResult` somente leitura e estados `Completed/Processing/Active/Unknown`.
- [x] Permitir à HUD consultar a entrega quando a confirmação se perde, sem cancelar automaticamente a sessão incerta.
- [x] Resubmeter o pacote original apenas quando o servidor indicar sessão `Active`, com limite de tentativas.
- [x] Escrever 27 casos de teste para recibos, registrar no `RunAllTests` e proteger contratos no CI.
- [x] **CI Rojo/contratos da branch aprovado** no commit `cb1b1668` — [execução #43339247018](https://github.com/FiaresAlan/Oficina24H/actions/runs/43339247018).
- [x] **PR #23 integrado à `main`**, commit `ec217420`.
- [x] Executar `RepairReceiptTest` e o conjunto inteiro de testes Luau no Studio — 38/38; conjunto 2014/0.
- [ ] Simular perda de `FinishRepair` e `RepairDone`, repetição de comandos e pagamento de OS colaborativa com dois jogadores.
- [ ] Validar o fluxo em celulares, gamepad, latência real e expiração de comprovantes.
- [ ] Implementar posteriormente um livro-caixa durável e idempotente entre servidores no DataStore; comprovantes C7 são **temporários por servidor**.

### C8 — ledger persistente por usuário — [PR #24 integrado](https://github.com/FiaresAlan/Oficina24H/pull/24)
- [x] Schema v5 no `DataService` com `RepairLedger` reconciliado e limite de 64 lançamentos.
- [x] Creditar no mesmo perfil junto da marca idempotente `JobId + token`, evitando reaplicar crédito repetido nesse perfil.
- [x] Vincular comprovante ao lançamento; permitir recuperação após novo servidor se `Save` foi confirmado.
- [x] Registrar separadamente as parcelas do dono e do contratado, com papéis próprios.
- [x] Tentar salvar imediatamente os perfis após a liquidação, antes de confirmar o resultado.
- [x] Escrever `SettlementLedgerTest` e ampliar `PersistenceTest` com reentrada em segundo servidor e duas contas.
- [x] **CI da branch aprovado:** [execução #43341179431](https://github.com/FiaresAlan/Oficina24H/actions/runs/43341179431).
- [x] **CI da `main` após PR #24 aprovado:** [execução #43341281142](https://github.com/FiaresAlan/Oficina24H/actions/runs/43341281142), commit `2eca8d0d`.
- [ ] Executar testes Luau de ledger/migração no Studio com DataStore de homologação e simulação de `UpdateAsync` falhando.
- [ ] **Garantir atomicidade multi-perfil:** pagamento de dono e executor usa chaves DataStore distintas; ainda não há transação distribuída nem recuperação completa de compensação.
- [ ] Medir budget/latência DataStore, perda de lock, queda no meio do salvamento e conflitos de sessões.

### C9 — extrato de pagamentos reais na HUD — [PR #25 integrado](https://github.com/FiaresAlan/Oficina24H/pull/25)
- [x] `GetSnapshot` omite `RepairLedger` bruto para não replicar GUIDs e comprovantes privados.
- [x] Enviar somente até 12 `RecentSettlements` públicos, sem token nem ID privado.
- [x] Criar `RepairStatementRules`: total do recorte, valores como dono/contratado, qualidade e ordenação cronológica.
- [x] Separar `Ordens > Concluídas` em extrato dos créditos efetivos e histórico de clientes/avaliações.
- [x] Adaptar linhas do recibo para layout vertical em tela compacta.
- [x] Escrever 23 testes da apresentação financeira e vincular a suite/CI.
- [x] **CI da branch aprovado:** [execução #43341869989](https://github.com/FiaresAlan/Oficina24H/actions/runs/43341869989).
- [x] **PR #25 integrado à `main`**, commit `c821bb23`.
- [ ] Testar visualmente interface de extrato em PC, celular vertical/horizontal e gamepad.
- [ ] Comparar extrato/valor recebido após 20 OS, reconexão e contrato entre dois jogadores.
- [ ] Confirmar visualmente ausência de sobreposição, travamento do painel e vazamento de tokens no snapshot.

### C10 — entrega confirmada após salvamento dos beneficiários — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/78b9c3de873b0a8ea76c388ac03d5c340ec68d57)
- [x] Criar `SettlementDeliveryRules` com portão de confirmação de ambos os perfis (dono/executor).
- [x] Fazer `CheckRepairOutcome` responder `Processing` quando o recibo existe só em memória e a gravação ainda não terminou.
- [x] Bloquear repetição de `FinishRepair` e início de outro reparo do executor durante uma entrega pendente.
- [x] Impedir que `DataService.Save` e `writeProfile` confirmem sucesso quando não houver perfil/Store.
- [x] Integrar C10 na `main` e validar contratos/build Rojo no [CI #43396387948](https://github.com/FiaresAlan/Oficina24H/actions/runs/43396387948).
- [ ] Verificar em Roblox Studio que a UI apresenta `Processing` antes do recebimento efetivo e só recebe `RepairDone` após o save.

### C11 — retentativas seguras após falha de persistência — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/78b9c3de873b0a8ea76c388ac03d5c340ec68d57)
- [x] Tentar novamente, de forma espaçada, salvar apenas os perfis ainda sem confirmação.
- [x] Evitar reaplicar moedas, peças, XP e avaliações no reenvio.
- [x] Acrescentar `SettlementDeliveryRulesTest` e cenários de falha injetada em `PersistenceTest`, vinculados ao runner e aos contratos estáticos.
- [x] Documentar QA e limitações em [TESTE_C10_C11_ENTREGA_FINANCEIRA](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C10_C11_ENTREGA_FINANCEIRA_2026-11-13.md).
- [x] Corrigir README desatualizado sobre integrações antigas.
- [ ] Rodar novas suites Luau dentro do Roblox Studio com DataStore de testes e falhas de UpdateAsync.
- [ ] Executar OS individual e contratada com 2 jogadores, perda de ACK, saída durante o save e reconexão.
- [ ] **P0 ainda aberto:** não há atomicidade entre perfis nem confirmação independente de todos os efeitos auxiliares; o fluxo de timing sem token foi **corrigido em C18**, mas o risco multi-conta permanece.

### C12 — reivindicação persistida antes de pagar o colaborador — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/2293e74190b7509f714c75d8b6a9377f94579678)
- [x] Criar `SettlementClaimRules`, validar identidade/valores/serviço e limitar a 64 reivindicações por contratado.
- [x] Migrar perfil para schema v6, sanitizar `PendingClaims` e bloquear sua replicação no snapshot.
- [x] Antes de `TakeParts` e de qualquer crédito, registrar e `Save` da reivindicação do contratado em OS com token.
- [x] Bloquear consumo de peças/crédito se não for possível persistir a reivindicação.
- [x] Escrever testes de regras, limite, ausência e divergência de prova, vinculados a `RunAllTests` e aos contratos estáticos.
- [x] Integrar na `main`; [CI da branch aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43398713684).
- [ ] Executar Luau no Studio e verificar interrupção ANTES do crédito do proprietário; reivindicação isolada jamais deve gerar pagamento.

### C13 — recuperação após crash entre salvamentos — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/2293e74190b7509f714c75d8b6a9377f94579678)
- [x] Na entrada e no autosave, consultar `GetAsync` do perfil durável do proprietário e verificar ledger (JobId/token/valor/papel/serviço/veículo).
- [x] Recuperar remuneração, XP e comprovante mínimo do contratado com `CreditRepairOnce`, sem segunda concessão.
- [x] Persistir saldo/ledger do contratado antes de remover a reivindicação e limitar verificações a 8 por passagem.
- [x] Acrescentar casos simulados de reconexão, leitura falha, proprietário não pago e valores divergentes em `PersistenceTest`.
- [x] Registrar limites e roteiros em [QA C12/C13](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C12_C13_CLAIMS_2026-11-13.md).
- [ ] Validar no Studio com dois jogadores, DataStore de testes, latência, queda entre gravações e reconexão real.
- [ ] **P0:** preservar a prova do proprietário além das últimas 64 operações e implementar investigação/limpeza segura de reivindicações órfãs.
- [ ] **P0:** não existe transação distribuída atômica; conferir também missões, avaliação, inventário e timing legado.

### C14 — arquivo privado e ampliado de provas de pagamento — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/2b105bfcceac315d9d1e96a783598936bb35837c)
- [x] Criar `OwnerSettlementProofRules` com retenção de até 1024 provas compactas, independente do extrato comum de 64 operações.
- [x] Migrar perfil para schema v7 e salvar prova de repasse com o mesmo perfil/Saldo do proprietário.
- [x] Vincular prova a JobId/token, UserId do mecânico, valores, serviço e veículo; negar reaplicação de token ainda retido.
- [x] Consultar prova ampliada antes de usar o fallback legado; não aceitar divergência de identidade ou valor.
- [x] Omitir arquivo privado do snapshot da HUD.
- [x] Acrescentar `OwnerSettlementProofRulesTest` e regressão de rotação do extrato com 70 operações.
- [x] Integrar na `main`; [CI da branch aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43400460678).
- [x] **C21:** não expulsar prova ainda pendente ao alcançar 1024; limpar apenas após `Save` da claim removida do contratado.
- [x] **C22:** varredura controlada de provas antigas com leitura persistida do trabalhador, crédito compatível e claim ausente; libera somente comprovantes seguramente quitados, mesmo que o mecânico esteja offline.
- [ ] **P0 remanescente:** arquivos realmente cheios com débitos ainda não comprovados continuam bloqueando novas colaborações; pagamentos antigos que já saíram do ledger de 64 itens não podem ser certificados pela varredura e exigem outro protocolo/auditoria, sem presumir atomicidade multi-conta.
- [ ] Testar 2 jogadores/servidores reais com DataStore, incluindo 70+ operações do dono antes de o mecânico reconectar.

### C15 — proteção contra recuperação prematura e monitoramento — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/2b105bfcceac315d9d1e96a783598936bb35837c)
- [x] Aguardar 600 segundos desde a criação da reivindicação antes de tentar recuperar pagamento pelo processo assíncrono.
- [x] Expor somente contagens agregadas (total/mais de 24h) em `Ordens > Concluídas`, sem revelar tokens/JobId.
- [x] Registrar alerta privado limitado a um por usuário/dia quando houver reivindicação com mais de 24h.
- [x] Não eliminar reivindicações não confirmadas automaticamente.
- [x] Acrescentar regressões de janela de segurança, migração v7, contagens e resumo sem vazamento.
- [x] Atualizar [relatório QA C14/C15](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C14_C15_PROVAS_ALERTAS_2026-11-13.md), README e PROGRESSO.
- [ ] Rodar `RunAllTests`, `StudioPlaceAudit`, testes mobile/gamepad e falhas reais no Roblox Studio.
- [ ] Verificar UX do atraso intencional de dez minutos e política de resolução administrativa de reivindicações órfãs.

### C16 — upgrade de ferramentas e máquinas ao pisar em plataforma — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/df3f1a66f12aa85afa8b2a09ba50af41106fee9b)
- [x] Auditar sistemas existentes de equipamentos, loja, prédio e funcionários antes de duplicar mecânicas.
- [x] Criar `EquipmentUpgradeRules` para nível I–III, custo escalonado, eficiência/recompensa e ganhos moderados de NPC.
- [x] Evoluir persistência para schema v8, migrar equipamento antigo para nível I e registrar saldo/upgrade no perfil.
- [x] Criar `EquipmentUpgradePads`: placas verdes com preço/nome/nível em frente às máquinas instaladas; uma compra por entrada do proprietário no volume físico, com validação do servidor.
- [x] Reposicionar plataformas ao comprar máquinas ou ampliar prédio; ocultar pad no nível máximo e sinalizar máquinas nível II/III.
- [x] Mostrar o nível da máquina instalada no catálogo da Loja.
- [x] Testes escritos em `EquipmentUpgradeTest`, `PersistenceTest`, `CatalogTest` e contratos estáticos.
- [x] CI da branch aprovado: [GitHub Actions #43404216290](https://github.com/FiaresAlan/Oficina24H/actions/runs/43404216290).
- [ ] Testar preço, colisão espacial do pad, reclamações de compra acidental, migração real e economia no Roblox Studio (1–2 jogadores, mobile/gamepad).

### C17 — mecânico NPC caminhando, trabalhando e gerando renda — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/df3f1a66f12aa85afa8b2a09ba50af41106fee9b)
- [x] Permitir primeiro mecânico na oficina nível 1 com 2 boxes; 2 mecânicos no nível 2.
- [x] Calcular caminho para o carro via `PathfindingService`; tentar caminhar com animação existente e fallback ao travar.
- [x] Mostrar ferramenta procedural (chave), mensagens de trabalho e progresso por atributo do NPC.
- [x] Permitir atendimento de 1 ordem após 25 s de prioridade do dono; 2 ordens liberam ajuda imediata.
- [x] Aplicar tempo/qualidade/recompensa moderados conforme nível da máquina do dono, mantendo consumo de peças e salários.
- [x] Evitar pagar reparo de NPC dispensado antes da conclusão.
- [x] Escrever `StaffAssignmentTest`, ampliar testes de regressão e registrar [QA C16/C17](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C16_C17_UPGRADES_EQUIPE_2026-11-13.md).
- [ ] Comprovar caminhada, chave, assets, animações, física NPC, 25 s, salário, peças, orçamento e balanceamento no Roblox Studio.
- [ ] Validar se a automação não reduz excessivamente o desafio do jogador em sessões de 15–30 minutos.

### C18 — proteção durável para o minijogo de timing — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/494e963fa241cb24688cfd2469657002b749ed36)
- [x] Gerar GUID para toda sessão (`Timing` e `Operations`), sem exceções.
- [x] Exigir JobId/token em `FinishRepair` e `CancelRepair` antes de consumir peças ou encerrar uma OS.
- [x] Encaminhar timing pelo ledger de crédito e recibo durável, remover pagamento direto sem idempotência.
- [x] Ajustar UI timing para correlacionar resultado ao token/JobId e consultar `CheckRepairResult` após erro/latência, em vez de fechar após 4 s.
- [x] Ampliar `RepairSessionTest`, `RepairTest` e contratos do CI.
- [x] CI e Rojo da [branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43436461807) e da [main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43436586544) aprovados.
- [x] Documentar riscos e roteiro em [QA C18](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C18_TIMING_TOKEN_2026-11-13.md).
- [ ] Executar timing e todos os 15 serviços no Studio, com token velho/ausente, cancelamento, perda de ACK e reconexão.
- [ ] Testar duas contas e falhas reais do DataStore; confirmar saldo, XP, peças, nota, recibo e ausência de duplicação.
- [ ] **P0 remanescente:** auditar efeito de créditos de NPC, cooperação e rollback após falha de persistência; não há atomicidade multi-chave.

### C19 — guia único de importação dos assets V1 — [documento integrado](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/GUIA_UNICO_ASSETS_V1.md)
- [x] Enumerar os **21 veículos** com nome EXATO exigido pelo catálogo e seus IDs de origem.
- [x] Enumerar **11 máquinas**, NPCs oficiais, cenário `Cid_*`, props, áudio, sprites e peças procedurais, sem links pagos inventados.
- [x] Explicar pastas `ServerStorage.Assets` e fluxo de importação via Creator Store/GLB, evitando substituir a rua existente.
- [x] Verificar fontes gratuitas do pacote CC0 3DAssets e licença Shuriken (não redistribuir GLBs soltos).
- [x] Anotar pendências jurídicas: HUD de referências, marcas/logos e esportivo privado sem licença comprovada.
- [ ] O proprietário conferir o *place* original e importar **somente os modelos ausentes**.
- [ ] Validar `StudioPlaceAudit`: todos 21 veículos com `PrimaryPart`, clientes funcionais e assets sem scripts embutidos.
- [ ] Confirmar direitos dos sprites, marcas e do modelo esportivo antes de publicar.

### C20 — NPC com OS exclusiva e pagamento idempotente — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/7364f04cfd493cab5bdb92867cafb9d9ed2bbe82)
- [x] Criar reserva `TryReserve` de JobId ANTES da `task.spawn` do funcionário NPC.
- [x] Evitar iniciar, abandonar, preparar, terceirizar ou pagar via NPC avulso uma ordem que o mecânico empregado já assumiu.
- [x] Verificar proprietário, funcionário presente, estado da OS e sessão manual antes do débito de peças do NPC.
- [x] Em erro de trabalho/pathfinding, liberar reserva e restaurar estado de reparo do carro ainda ativo.
- [x] Criar `DataService.SettleNpcRepairOnce` para validar peças e crédito JobId+GUID no mesmo perfil de forma idempotente.
- [x] Encaminhar funcionário empregado e NPC avulso ao ledger persistível, anexar comprovante e confirmar `Save` antes da **mensagem de sucesso**; retentativa sem recreditar.
- [x] Testes escritos em `StaffAssignmentTest` e `PersistenceTest` (dupla reserva, replay, 4 falhas `UpdateAsync`, recarga), contratos e build Rojo.
- [x] [CI da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43440973900) **e da [main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43441229751)** aprovados; documento de [QA C20](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C20_ORDEM_NPC_EXCLUSIVA_2026-11-13.md).
- [x] Registrar que o proprietário **baixou e organizou** `Car Repair Garage and MOT Workshop.glb`, `CGTrader Low Poly City`, `Shuriken Town Streets & Park v1`, `Shuriken Houses` e `Shuriken City` no [Guia Único de Assets V1](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/GUIA_UNICO_ASSETS_V1.md).
- [ ] Importar/configurar esses pacotes dentro do Studio (proprietário, etapa futura); não substituir a rua sem backup.
- [ ] Executar os testes Luau e integração real no Roblox Studio: 2 jogadores, NPC em execução/cancelamento, efeitos, peças, saldo, DataStore sob falha e animações.
- [ ] **P0 remanescente:** queda irrecuperável antes do `Save` ainda pode perder operação em memória; liquidação colaborativa continua sem atomicidade multi-conta e provas têm retenção finita.
- [ ] Decidir sobre o `HireNpc` avulso legado, que ainda conclui serviço imediatamente, após avaliação da jogabilidade com funcionários físicos.

### C21 — preservar provas e garantir rollback após concorrência — [commit final integrado](https://github.com/FiaresAlan/Oficina24H/commit/0a2046e650d5786e55cd51c110214d4622ce9ee1)
- [x] Substituir a exclusão automática das provas antigas ao atingir 1024 por contenção: não descartar comprovante pendente.
- [x] Verificar capacidade ANTES de gastar peças ou creditar a parcela do dono numa OS colaborativa.
- [x] Fazer `CreditRepairOnce` recusar lançamento quando não é possível armazenar prova correspondente, sem modificar moedas ou ledger.
- [x] Revalidar a capacidade após o `Save` da claim do contratado, com `DataService.SettleRepairOwnerOnce`: debitar estoque e creditar o dono no mesmo perfil sem yield; devolver estoque em falha de criação de prova.
- [x] Registrar parcela do dono ANTES do crédito do mecânico, mas não marcar `RepairDone` até ambas serem persistidas. Se o crédito do mecânico falhar, retentar usando o mesmo token e anexar recibo/XP antes de salvar, sem dobrar ganhos.
- [x] Exigir exclusão da `PendingClaim` do contratado **e confirmação do `Save(worker)`** antes de retirar a prova do perfil do proprietário.
- [x] Vincular retirada a JobId/token/WorkerUserId e marcar perfil do dono para persistência após limpeza.
- [x] Preparar regressões de arquivo cheio, salvamento falho, reconexão e pagamento único em `OwnerSettlementProofRulesTest` e `PersistenceTest`.
- [x] Integrar contratos CI em `verify_contracts.py`, com [CI final da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43444838907) aprovado e [CI da main aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43444977533).
- [x] Registrar roteiro de [QA C21](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C21_PROVAS_REPASSE_2026-11-13.md), critérios de regressão e riscos restantes.
- [ ] Executar as suites LuaU e dois servidores com usuários reais em Roblox Studio, incluindo falha `UpdateAsync`, reconexão, 1024 pendências e tentativa de pagamento duplicado.
- [ ] **Limitação persistente:** não há atomicidade entre dois perfis no DataStore; a varredura C22 existe, mas não consegue atestar recebimentos cujo histórico do trabalhador já girou ou dados estejam incompletos; arquivo cheio ainda pode bloquear colaboração para não perder dívida.
- [ ] Importar/configurar depois os cinco pacotes 3D já baixados; teste com modelos reais fica para o proprietário.

### C22 — reconciliação conservadora de provas com colaborador offline — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/617564dbe1b173cf035f241a6b2cd7e877dfb8e3)
- [x] Criar `OwnerProofSweepRules.Batch` com cursor, intervalo mínimo de 300 s, janela de 900 s e limite de quatro leituras por passagem.
- [x] Verificar perfil do contratado exclusivamente no DataStore persistido; somente crédito `Worker` correto e `PendingClaim` ausente liberam prova, inclusive se colaborador estiver offline.
- [x] Recusar limpeza quando faltarem dados, quando o crédito/serviço/valor divergir ou a claim ainda estiver aberta; idade sozinha jamais concede autorização.
- [x] Validar identidade do proprietário e da prova após a espera de `GetAsync`; confirmar `Save` do dono antes de considerar limpeza persistida.
- [x] Agendar limpeza após login e nos ciclos de autosave sem depender da presença do contratado, com leituras limitadas para conter carga do DataStore.
- [x] Ampliar `PersistenceTest`, adicionar `OwnerProofSweepRulesTest` e registrar a suite no `RunAllTests`, incluindo falha de Get/Save, histórico rotacionado, arquivo cheio, replay e reconexão.
- [x] Verificações de CI e build Rojo aprovadas na [branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43447500152) e na [main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43447637911).
- [x] Registrar o roteiro de [QA C22](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C22_LIMPEZA_PROVAS_OFFLINE_2026-11-13.md) com pré-condições e limitações.
- [ ] Executar as suites LuaU/Studio, falhas reais do DataStore e teste de duas contas com colaborador desconectado.
- [x] **C23:** arquivo privado e durável de até 2048 quitações do contratado; a C22 pode validar uma quitação mesmo quando a linha de 64 do ledger girou.
- [x] **C24:** compactação segura de comprovantes de trabalhador com proprietário confirmado, claim encerrada e tombstone de JobId/Token persistido; abre espaço nos 2048 registros detalhados sem perder proteção contra replay.
- [x] **C25:** recuperação financeira automática só aceita `OwnerSettlementProofs` com WorkerUserId correto. Ledger legado sozinho é classificado `LegacyUnverified` e a reivindicação permanece, com auditoria privada persistente.
- [ ] **P0 remanescente:** pagamentos verdadeiros anteriores à prova vinculada podem continuar inconclusivos até auditoria manual com evidência confiável; marcadores sem OwnerUserId não são compactados e tombstones continuam finitos (8192). Não há ferramenta administrativa auditada para esses casos nem atomicidade multi-conta.
- [ ] Integrar/configurar os cinco pacotes 3D já baixados no place e homologar o mundo real, sob responsabilidade do proprietário.

### C23 — comprovante de quitação do contratado além do extrato de 64 — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/02695e0907a132a83ef06d620415f230599e91ea)
- [x] Criar `WorkerSettlementProofRules`: arquivo privado com até 2048 confirmações por trabalhador (JobId, Token, valor, data, serviço e veículo), sem expiração por idade e sem rotação silenciosa.
- [x] Migrar perfil para **schema v9**, reconstituindo marcadores de pagamentos `Worker` ainda presentes no ledger v8 sem conceder dinheiro novo.
- [x] Alterar `CreditRepairOnce` para registrar marcador do trabalhador, ledger e moedas no **mesmo perfil**, sem yield, e recusar novos créditos caso a prova não possa ser armazenada.
- [x] Incluir o arquivo durável em `HasRepairCredit` para impedir replays mesmo depois que as 64 linhas do ledger girarem.
- [x] Atualizar `OwnerProofSweepRules` para verificar pagamento no arquivo do trabalhador quando o ledger não o contém mais, exigindo reivindicação encerrada e valor/serviço/veículo compatíveis.
- [x] Impedir que `ReconcileWorkerClaims` apague uma reivindicação quando o crédito não pôde ser aplicado e salvo; validar capacidade antes da liquidação colaborativa e esconder arquivo privado do cliente.
- [x] Criar `WorkerSettlementProofRulesTest`, ampliar `OwnerProofSweepRulesTest` e `PersistenceTest`, registrar no `RunAllTests` e corrigir testes de migração que ainda esperavam schemas antigos.
- [x] [CI final da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43450943406) e [CI da main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43451121413) aprovados (contratos estáticos + build Rojo).
- [x] Registrar [documentação e roteiro de QA C23](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C23_QUITACOES_TRABALHADORES_2026-11-13.md).
- [ ] Executar suites Luau no Roblox Studio, migração real v8→v9, 65+ pagamentos, salvamentos sob falha e dois servidores/jogadores.
- [ ] **Limitação restante:** não há atomicidade entre perfis; o arquivo de 2048 pode encher e bloquear novas colaborações, e créditos históricos já rotacionados antes da C23 não são reconstruíveis automaticamente.
- [ ] Assets já baixados pelo proprietário aguardam importação/configuração no Studio; homologação permanece pendente.

### C24 — compactação de comprovantes quitados com proteção de replay — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/fd26aec8e82c9f0bd196b57a854051001131c354)
- [x] Migrar perfis ao schema v10 com `WorkerPaidTombstones` (limite 8192) na mesma conta do mecânico, sem descarte por tempo.
- [x] Anexar `OwnerUserId` nas novas provas de recebimento a partir da reivindicação registrada pelo servidor; não inventar vínculos para provas antigas.
- [x] Criar `WorkerProofArchiveRules` para selecionar até quatro provas por passagem, com intervalo mínimo de 300 s, 900 s de segurança e cursor circular.
- [x] Exigir **claim do mecânico ausente** e **prova do proprietário já removida do DataStore persistido** antes de permitir compactação; falha de GetAsync ou dado incompleto conserva comprovante detalhado.
- [x] Salvar o perfil do mecânico antes de consultar o proprietário e depois de converter prova em tombstone, com validação de sessão e prevenção de concorrência.
- [x] Garantir inserção do tombstone ANTES da exclusão do comprovante detalhado, sem yield e com recusa segura ao atingir 8192 registros.
- [x] Impedir `CreditRepairOnce` de pagar novamente um token já compactado; `HasRepairCredit` e migração do ledger reconhecem tombstones sem ressuscitar o comprovante detalhado.
- [x] Ocultar arquivo de tombstones no snapshot enviado à UI, preservando privacidade de JobId/token.
- [x] Criar `WorkerProofArchiveRulesTest` e ampliar `PersistenceTest` para baixa do dono, falha de leitura/Save, reconexão, 70 novos serviços, idempotência, arquivos cheios e histórico sem vínculo.
- [x] [CI final da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43454824392) e [CI da main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43454921357) aprovados: contratos estáticos + build Rojo.
- [x] Atualizar [documentação de QA C24](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C24_COMPACTACAO_QUITACOES_2026-11-13.md), README e PROGRESSO.
- [ ] Rodar as suítes LuaU no Studio e testar de fato com dois perfis/servidores, falhas de DataStore e 2048/8192 registros.
- [ ] **Limitação de projeto:** tokens quitados antes da C23, sem prova no extrato, ainda exigem auditoria. Tombstones permanentes são finitos e, quando lotados, retêm a prova detalhada; não há transação atômica entre duas contas.
- [ ] Importar e validar no Studio os cinco pacotes de assets já baixados pelo proprietário, sem alterar a rua aprovada sem backup.

### C25 — auditoria conservadora de reivindicações históricas — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/ae3ba4a68a5d7377fdc3c6708a929e1bec9dc628)
- [x] Remover autorização de pagamento automático quando o único comprovante é uma linha antiga de `RepairLedger` do dono, que não identifica WorkerUserId.
- [x] Exigir `OwnerSettlementProofs` do dono com JobId, token, trabalhador, valor, serviço e veículo corretos para considerar uma claim `Verified`.
- [x] Classificar evidência legada/inconclusiva em `LegacyUnverified`, `Conflict`, `Missing` e `ReadError`, sem conceder dinheiro ou apagar a reivindicação.
- [x] Adicionar schema v11 com `PendingClaimAudits` persistente no perfil do trabalhador e sanitização de auditorias órfãs, sem expor IDs ao cliente.
- [x] Registrar/atualizar estado de auditoria durante `ReconcileWorkerClaims`; remover anotação quando a claim for encerrada e salva.
- [x] Expor apenas contagens `NeedsReview`, `LegacyUnverified` e `Conflicts` no resumo; ocultar dados de auditoria em `GetSnapshot` e não registrar tokens em alertas agregados.
- [x] Adicionar `SettlementClaimAuditRulesTest`, reforçar `SettlementClaimRulesTest` e `PersistenceTest` para beneficiário divergente, legado sem vínculo, erro de leitura, reconexão e migração v11.
- [x] [CI final da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43459733449) e [CI da main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43459877512) aprovados: contratos estáticos e build Rojo.
- [x] Registrar [roteiro de QA e auditoria operacional C25](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C25_AUDITORIA_CLAIMS_LEGADAS_2026-11-13.md), sem criar ferramenta de compensação insegura.
- [ ] Executar suítes Luau e cenário de multiplayer real com DataStore, trabalhador incorreto, dono offline, claims legadas e reconexão no Studio.
- [ ] **P0 remanescente:** disputas históricas sem prova vinculada exigem análise humana e procedimento administrativo auditável; não autorizar pagamento por suposição nem apagar reivindicações.
- [ ] Importar/configurar os cinco pacotes 3D já baixados e homologar o mundo e os 15 serviços no Studio.

### C26 — ordens fantasma e integração das regras de 15 reparos — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/30f42f6aca95506e935569ac56e66123f3e1ee43)
- [x] Identificar e corrigir a inconsistência: `PlayerLeft` convertia ordens `InProgress` do proprietário desconectado em `Available` depois que seu carro desaparecia.
- [x] Remover toda OS do proprietário que saiu, inclusive `Available`, `InProgress` e `Completed`, evitando dados fantasmas após reentrada.
- [x] Cancelar minijogo ativo do contratado da oficina encerrada mesmo com atributos do avatar já limpos; não gerar dinheiro no cancelamento.
- [x] Quando apenas o colaborador sai, devolver a OS ao dono, limpar percentual e timestamp, mantendo o veículo do proprietário.
- [x] Criar `JobExitRules.lua` e `JobExitRulesTest.luau` para estados, dono, colaborador, terceiros e IDs inválidos.
- [x] Criar `AllServiceActionFlowTest.luau` com os **15 serviços**: plano → comandos sequenciais aceitos pelo servidor → ACK/revisão → `FinalInput` → avaliação de qualidade, sem vazamento do gabarito no plano público.
- [x] Adicionar as duas suítes ao `RunAllTests`, reforçar `verify_contracts.py` e integrar em [CI de branch aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43463971636) e [CI de main aprovado](https://github.com/FiaresAlan/Oficina24H/actions/runs/43464093469).
- [x] Publicar [matriz e roteiro de homologação C26](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C26_CICLO_OS_15_SERVICOS_2026-11-13.md), com 15 serviços e equipamentos correspondentes, critérios de saída/reconexão e dispositivos-alvo.
- [x] Executar `RunAllTests` e `StudioPlaceAudit` no Studio — 2014/0 (place de QA, 13/11).
- [ ] Confirmar com dois jogadores e assets reais as saídas/reentradas, o ciclo completo dos 15 serviços, NPC contratado, estoque, avaliações e ausência de ordem fantasma.
- [ ] P0 ainda pendente: modelos 3D (já baixados, ainda não importados), telas mobile, duas contas, DataStore real, licença/áudio/FPS e auditoria de código remanescente.
- [ ] A V2 continua apenas documental e não recebeu implementações desta fase.

### C27 — coerência imediata do HUD após compras/ações — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/ccc022845d70a81496aa0e6f2f78160af7b5f412)
- [x] Identificar bug: `Main.server.lua` invalidava `snapshotCache`, mas `lastSnapshotBuild` ainda podia devolver o estado velho por até 250 ms após compra, reparo ou interação física.
- [x] Consolidar o cache por jogador em `SnapshotCacheRules` com TTL de 0,4 s e invalidação explícita por geração, sem segundo cache independente.
- [x] Proteger contra resposta obsoleta de montagem com yield: só armazenar se a mesma sessão/geração ainda estiver ativa, e limpar estado completo ao sair.
- [x] Invalidar ao executar ações remotas, prompts de carro/cliente/equipamento/estação, compras de upgrades por pads físicos, avaliações, eventos de reparo, avisos pessoais de progressão e contratos.
- [x] Adicionar `SnapshotCacheRulesTest` no `RunAllTests`: leitura repetida, invalidação antes de 250 ms, TTL, isolamento entre jogadores, corrida durante build e reentrada.
- [x] Reforçar `verify_contracts.py`; [CI da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43467030196) e [CI da main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43467169767) aprovados (contratos estáticos e build Rojo).
- [x] Publicar [documento de QA C27](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C27_CACHE_SNAPSHOT_HUD_2026-11-13.md), com roteiro para loja, upgrades, OS, avaliação, funcionários, dois jogadores e reentrada.
- [x] Rodar `RunAllTests` e os cenários de snapshot/HUD no Roblox Studio — 2014/0 e HUD ao vivo nos 15 serviços.
- [ ] Validar FPS/latência da UI, StreamingEnabled e mobile após importação dos assets reais; mudanças do mundo sem evento continuam sujeitos ao TTL de 0,4 s.
- [ ] As pendências da V1 de QA do place, dados financeiros históricos e importação dos assets permanecem abertas; V2 não recebeu código.

### C28 — guarda de liquidação após o Save de claim do trabalhador — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/16386835104ede98dd6fb1579c5d161cba00101b)
- [x] Identificar janela de concorrência: `FinishRepair` salvava a claim com yield, mas podia usar OS capturada mesmo após `PlayerLeft` a remover.
- [x] Criar `RepairCommitGuard` validando instância da OS, dono e colaborador conectados, vínculo autorizado, estado `InProgress` e percentual capturado antes do Save.
- [x] Chamar a guarda **depois de `DataService.Save(worker)` e antes de `SettleRepairOwnerOnce`**, sem gastar peça nem creditar moedas para uma OS cancelada ou atribuída a outro trabalhador.
- [x] Tentar limpar a claim criada caso o Save falhe ou a OS mude; dívida órfã sem prova do dono permanece auditável e não autoriza pagamento por inferência (C25).
- [x] Adicionar `RepairCommitGuardTest` ao `RunAllTests`: dono sai durante Save, nova OS com mesmo ID, trabalhador desconecta, transferência de papel, variação do percentual e dados inválidos.
- [x] Verificar ordem das operações no `verify_contracts.py`; [CI da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43469424964) e [CI da main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43469552748) aprovados.
- [x] Documentar [QA C28](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C28_GUARDA_REPARO_COLABORATIVO_2026-11-13.md) e [portões finais da V1](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/PORTOES_FINALIZACAO_V1_2026-11-13.md).
- [ ] Executar no Roblox Studio suíte `RepairCommitGuardTest` e cenário real de duas contas com atraso/falha DataStore e desconexão no momento do Save. *(parcial)*
- [ ] **Risco residual:** não existe transação atômica entre duas contas; quedas entre Saves e históricos ambíguos exigem mitigação e auditoria.
- [ ] Assets baixados ainda precisam ser importados/configurados no Studio e homologados em todos os 15 serviços.

### C29 — limpeza de cenas de cliente e veículo durante logout — [commit integrado](https://github.com/FiaresAlan/Oficina24H/commit/ffd46c198c2b09acf35b77eab379c16c41d0a979)
- [x] Corrigir corrida em `CustomerArrivalService.Arrive`: coroutine de chegada só pode construir o modelo se o estado original da OS ainda existir; após construção, descartar clone tardio de carro/NPC.
- [x] Criar `VehicleSceneRules.IsCurrentArrival` e `IsOwnedBy` com testes de cancelamento, substituição de JobId e isolamento por proprietário.
- [x] Em `CustomerArrivalService.Clear`, limpar cenas ativas e registros `lingering` do dono sem destruir veículos já entregues à oficina.
- [x] Manter `curbDeparting` até o fim da saída da rua; logout encontra o veículo mesmo quando a vaga no meio-fio já foi liberada.
- [x] Manter `departing` em `VehicleService` após remover o carro de `byJob`; ao sair o dono, destruir carro/NPC em despedida e liberar somente a marca da vaga correspondente.
- [x] Registrar `VehicleSceneRulesTest` em `RunAllTests` e incluir verificações de integração em `verify_contracts.py`.
- [x] Publicar [roteiro QA C29](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/TESTE_C29_CENAS_CLIENTES_DESCONEXAO_2026-11-13.md) e atualizar README/PROGRESSO.
- [x] [CI final da branch](https://github.com/FiaresAlan/Oficina24H/actions/runs/43471676468) e [CI da main](https://github.com/FiaresAlan/Oficina24H/actions/runs/43471810454) aprovados (contratos estáticos + Rojo).
- [ ] Executar testes Luau, chegada, saída, NPCs e logout de dois jogadores no Roblox Studio com assets reais; nenhum desses testes de Studio foi executado nesta fase.
- [ ] Confirmar que a remoção durante `LotPath.Drive` e a troca rápida de sessão não produzem mensagens de erro, carros órfãos ou perda de vaga.
- [ ] Assets ainda baixados, mas não importados/configurados no Studio; G1–G5 continuam pendentes e V2 sem gameplay.

### C30–C31 — Preparação segura e auditoria de assets G1
- [x] **C30:** sanitizar cópias de carro, NPC, equipamento e miniatura antes de replicar; [commit](https://github.com/FiaresAlan/Oficina24H/commit/a972b386454d60456dac56f61bae3578c96ad0cf), [CI verde](https://github.com/FiaresAlan/Oficina24H/actions/runs/43478961090).
- [x] **C31:** verificar 21 modelos, Raiz/Casco, dimensões, soldas, sockets, clientes R15, gênero e equipamento opcional; [commit/correção](https://github.com/FiaresAlan/Oficina24H/commit/0ef749b5c56d769fac46c2bea9262d5f65e7efba), [CI verde](https://github.com/FiaresAlan/Oficina24H/actions/runs/43479613749).
- [x] Registrar suítes `AssetSafetyRulesTest` e `AssetIntegrityRulesTest` e QA em `docs/TESTE_C30_*` / `docs/TESTE_C31_*`.
- [ ] Rodar testes e auditoria no Studio com os **assets reais importados**; corrigir falhas e validar visual, áudio, licença, performance. **G1 não homologado.**

### Homologação V1 — rodada 1 no Studio (13/11) — [relatório](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/HOMOLOGACAO_V1_2026-11-13.md)
> Place de QA = build só com código (144/144 scripts), carros/NPCs placeholders; place original não aberto.

- [x] 41 suítes: 1593 OK/60 falhas na 1ª execução → **`RunAllTests` 2014 OK, 0 falhas**.
- [x] Testes que nunca rodavam corrigidos (C12–C25, C20, C22, `CompactHudTest`).
- [x] **15 serviços ao vivo** pelos remotes do HUD: qualidade 100, sem pagamento duplo, sem carro órfão, console limpo.
- [x] Ataques a remotes recusados; auditoria de segurança sem P0.
- [x] P1: gabaritos dos minijogos no servidor. P2: limites por segundo, estações, modo memória.
- [x] HUD: pads, METAS sobre o guia, toque < 44 px, guia vazando.
- [x] CI verde na `main` `4e39f3a`; contratos 231/231.
- [x] Place original (backup antes): `RunAllTests` 2029/0, auditoria 17/0, 3 serviços reais, 59,9 fps no mapa; 2 P1 corrigidos (`PrimaryPart` das máquinas, NPC tomando a OS do dono).
- [x] Pacotes baixados conferidos: nada faltava no place, nenhum upload feito.
- [ ] 2 jogadores, DataStore de teste, saída/reconexão.
- [ ] Celular e gamepad físicos, FPS real, StreamingEnabled.
- [ ] Licenças e decisão de publicar.

### Portões resumidos para encerrar a V1 (não substituir histórico; todos ainda pendentes)
- [ ] **G1 Assets:** estrutura homologada no place real (inventário completo, auditoria 17/0); faltam licenças (Corvette, sprites HUD, CC BY) e áudio.
- [x] **G2 Atendimento:** `RunAllTests` 2029/0 e `StudioPlaceAudit` 17/0 no place original; 3 serviços reais OK e 15/15 no place de QA.
- [ ] **G3 Multiplayer/DataStore:** dois jogadores e servidores, desconexões, claims, idempotência, economia e falhas de salvamento.
- [ ] **G4 UX/performance:** mobile, gamepad, PC, StreamingEnabled, FPS, memória e acessibilidade. *(parcial)*
- [ ] **G5 Publicação:** segurança, licenças, remotes e revisão dos bloqueios P0; publicar somente após decisão do proprietário. *(parcial)*

**Leitura do progresso:** existem muitos checkboxes históricos repetidos de QA e ideias opcionais. Esses cinco portões são a medida operacional de término da V1; **não é correto converter 219 itens feitos e 128 abertos em percentual de jogo pronto**. [Plano de fechamento](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/PORTOES_FINALIZACAO_V1_2026-11-13.md). **Rodada 1 no place de QA (13/11); place original pendente.**

### Portões de PRODUTO FINAL (todos pendentes)
- [ ] Arte PBR e componentes reais auditados para o conjunto de veículos publicado; licenças/créditos comprovados.
- [ ] Áudio e feedback mecânico licenciados, com animações que correspondem aos passos.
- [ ] Fluxo completo dos 15 serviços aprovado com usuários reais e dispositivos alvo.
- [ ] Economia/contratos/DataStore seguros contra duplicação e perda.
- [ ] 2 jogadores simultâneos, reconexão, latência e streaming testados.
- [ ] FPS, memória, carregamento e percepção de qualidade medidos e corrigidos.
- [ ] Segurança, acessibilidade, monetização e regras Roblox auditadas.
- [ ] Revisão de PRs empilhados, merge seguro e build publicado homologado.

---

## Próximo checkpoint obrigatório

- [x] **P0:** executar testes Luau e corrigir incompatibilidades da pilha A1–C3 — 2014/0 (13/11).
- [ ] **P0:** executar um atendimento completo no Studio com um modelo real de carro. *(parcial)*
- [x] **P0:** inspecionar e corrigir HUD em 390×844, 320×568, 844×390 e 1920×1080 — simulador (jogo só paisagem): 844×390, 800×360, 568×320, 1920×1080; 4 correções.
- [ ] **P0:** testar pagamento, estoque, cancelamentos e cooperação de dois jogadores.
- [x] **Integração de código na `main`:** PR #20 integrado por autorização explícita, mantendo os gates de Studio/arte/segurança como pendentes antes de publicar.

### Registro dos próximos check-ins

| Revisão | Alteração |
|---|---|
| 12/11/2026 | Issue criada; A0–C9 integradas (PRs #2–#25, CI verde) — detalhes de cada PR nas seções acima e em [PROGRESSO](https://github.com/FiaresAlan/Oficina24H/blob/main/docs/PROGRESSO.md) |
| 13/11/2026 | **C10/C11 integradas à main** commit 78b9c3de; portão de salvamento para duas contas e retentativas limitadas. CI da main #43396387948 PASSOU; Studio/compensação entre contas ainda pendentes |
| 13/11/2026 | **C12/C13 integradas à main** commit 2293e741; reivindicação prévia e verificação de crédito do dono antes de recuperar remuneração/XP do contratado. CI da branch #43398713684 e da main #43398855474 aprovados; execução Studio pendente |
| 13/11/2026 | **C14/C15 integradas à main** commit 2b105bfc; arquivo privado de provas de 1024 repasses e monitoramento de claims com janela conservadora. CI da branch #43400460678 e da main #43400540633 aprovados; Studio não executado |
| 13/11/2026 | **C16/C17 integradas à main** commit df3f1a66; upgrades por plataforma no chão, ferramentas nível I–III, NPC com deslocamento/animação e contratação na oficina de 2 boxes. CI da branch #43404216290 e da main #43404292920 aprovados; teste Studio pendente |
| 13/11/2026 | **V1 C18/C19 integradas à main** commit 494e963f; timing usa GUID e recibo persistente com consulta de resultado, guia único de 21 carros/11 equipamentos. CI da branch #43436461807 e da main #43436586544 aprovados; Studio e assets reais pendentes. V2 não iniciada |
| 13/11/2026 | **V1 C20 integrada à main** commit 7364f04c; reserva de OS por NPC, guardas contra reparo concorrente, crédito idempotente com débito de peças e salvamento confirmado. CI da branch #43440973900 e da main #43441229751 aprovados; Studio/QA ainda pendente. Cinco pacotes 3D baixados pelo proprietário, importação futura. V2 não iniciada |
| 13/11/2026 | **V1 C21 final integrada à main** commit 0a2046e; nenhuma prova pendente é apagada por rotação; cleanup só após worker Save; transação owner peças + crédito tem rollback mesmo com duas OS simultâneas e retry worker recebe recibo. CI final da branch #43444838907 aprovado, main #43444977533; Studio pendente. V2 não iniciada |
| 13/11/2026 | **V1 C22 integrada à main** commit 617564db; sweep limitado de comprovantes offline: 4 leituras/300 s e confirmação persistida do trabalhador antes de remover provas; falha ou ledger rotacionado mantém arquivo. CI branch #43447500152 e main #43447637911 aprovados. Studio/QA pendente; V2 não iniciada |
| 13/11/2026 | **V1 C23 integrada à main** commit 02695e0; schema v9 com arquivo privado de até 2048 quitações do contratado, proteção contra pagamento repetido após giro das 64 linhas e varredura de comprovantes antigos pela C22. CI branch #43450943406 e main #43451121413 aprovados; Studio pendente e V2 não iniciada |
| 13/11/2026 | **V1 C24 integrada à main** commit fd26aec8; schema v10, compactação de quitações comprovadamente encerradas para tombstones (8192), replay seguro depois da baixa do dono, regresso de falhas/limites. CI branch #43454824392 e main #43454921357 aprovados; Studio e assets pendentes, V2 não iniciada |
| 13/11/2026 | **V1 C25 integrada à main** commit ae3ba4a6; schema v11, desabilita pagamento baseado só no ledger legado sem WorkerUserId e grava auditoria privada das reivindicações ambíguas. CI branch #43459733449 e main #43459877512 aprovados; Studio e assets pendentes, V2 não iniciada |
| 13/11/2026 | **V1 C26 integrada à main** commit 30f42f6; ordens do dono removidas após desconexão e colaborador cancelado sem pagamento; regressão incremental de ações para os 15 serviços, com matriz de homologação. CI branch #43463971636 e main #43464093469 aprovados; Studio/QA pendente, V2 não iniciada |
| 13/11/2026 | **V1 C27 integrada à main** commit ccc02284; cache do HUD unificado com invalidação por geração, sem recuperar estado anterior após compra/OS/prompt e com testes para 250 ms, yield e reconexão. CI branch #43467030196 e main #43467169767 aprovados; Studio/QA pendente, V2 não iniciada |
| 13/11/2026 | **V1 C28 integrada à main** commit 16386835; revalida OS/ator/divisão após salvar a reivindicação, antes de pagar/retirar peças. CI branch #43469424964 e main #43469552748 aprovados; resumo dos cinco portões G1–G5 publicado. Studio pendente, V2 não iniciada |
| 13/11/2026 | **V1 C29 integrada à main** commit ffd46c19; limpa chegada cancelada, carros e NPCs saindo do meio-fio ou oficina mesmo após perda do registro principal, preservando cenas de outros jogadores. CI branch #43471676468 e main #43471810454 aprovados; Studio/QA pendente, G1–G5 abertos e V2 não iniciada |

| 13/11/2026 | **Homologação V1 rodada 1** — `main` `4e39f3a`, [CI #43498308216](https://github.com/FiaresAlan/Oficina24H/actions/runs/43498308216): 2014/0 e 15 serviços ao vivo (place de QA); P1/P2 e HUD corrigidos; place original e publicação pendentes |

**Regra de atualização:** em cada fase futura, atualizar esta issue (marcar checkboxes, PR vinculado, testes executados e riscos) no mesmo ciclo dos commits. Não marcar `[x]` com base somente em planos ou arquivos de teste ainda não executados.