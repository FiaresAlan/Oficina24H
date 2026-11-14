# Oficina 24H — V2-13 | Conferência pós-reparo e retrabalho sem dupla cobrança

**13/11/2026 — engenharia da V2-13 na PR #27.**  
**Gate de ativação:** `V2DriveScenarioRules.LiveEnabled=false`. Testes de física e homologação no Roblox Studio **ainda pendentes**, portanto o fluxo V1 de reparo/recebimento continua como antes para os jogadores.

## Quando a oferta surge

Apenas algumas OS com **Hatch amarelo** e defeito qualificado entram em uma amostragem única de qualidade (**24% das elegíveis**) ao serem criadas. Após diagnóstico, preparação e minijogo **concluídos e avaliados pelo servidor**, o jogador pode verificar a correção andando no bairro. A escolha nunca obriga todas as OS, não é oferecida a colaboradores e funcionários NPC e não deve ser inserida no onboarding inicial.

### Máquina de estados do mesmo JobId

`Reparo V1 em andamento` → `Offer` (avaliação do minijogo validada, **sem** consumo financeiro) → escolha:

- **“ENTREGAR SEM TESTE”** → conserva a qualidade real do minijogo, liquida pela rotina V1 normal (sem bônus/punição por pular).
- **“VERIFICAR REPARO · TEST-DRIVE”** → `Driving` → volta voluntária com 4 checkpoints/tempo mínimo. A conclusão do servidor aplica `V2QualityDriveRules.OnReturn`, decidindo:
  - `Approved`: qualidade real >=70%, pode entregar; **sem dinheiro/XP extra**.
  - `Rework`: qualidade real abaixo de 70%, **recomenda** retrabalho e explica a nota ao jogador.
  - `Incomplete`: perda de rede, rota insuficiente, abandono, colisão, falha de física ou cancelamento retornam a `Offer`, **sem penalidade**.
- `Rework` → **“REFAZER REPARO · PEÇAS GRÁTIS”** inicia um **novo minijogo** no mesmo JobId, uma única vez; ou **“ENTREGAR COM QUALIDADE ORIGINAL”** finaliza sem fingir aprovação e sem penalidade adicional.
- `Approved` → **“APROVAR E ENTREGAR OS”** → fluxo normal de recibo, histórico, rating e pagamento V1.

**Importante:** uma reprovação nunca é sorteada no momento do test-drive nem causada por colisão/latência. O único critério é a nota já calculada pelo reparo real, com limite objetivo 70%. Refazer consome tempo e exige nova execução técnica, **não** uma segunda taxa, compra automática de peças ou perda arbitrária de reputação. O cliente recebe explicação do resultado pela mensagem do servidor. Uma nota baixa entregue assim permanece baixa no `CustomerRules.RateService` existente, sem punição paralela oculta.

## Integridade financeira e recibo

A V2-13 **não possui** um segundo `DataService.SettleRepairOwnerOnce`. O antigo código de quitação foi consolidado na função privada `settleEvaluatedRepair` dentro de `WorkshopService`, chamada uma vez tanto na conclusão normal V1 quanto após `QualityReview(Skip|Finalize)`.

No `FinishRepair`, o servidor já verifica token de sessão, plano e ações do minijogo, estado de OS, equipamento, peças, tempo e qualidade. Para uma OS marcada e com gate habilitado, mantém em `PendingQuality` (memória **apenas no servidor**) a sessão selada, token, nota e resultado. `SettlingRepairs` bloqueia novos pagamentos/execuções enquanto espera a revisão. A consulta de comprovante responde `QualityPending`, **não `Completed`**, e envia evento `RepairQualityPending` às interfaces de minijogo para fecharem a janela sem mostrar crédito fictício.

O jogador decide pela aba `Ordens > Em andamento`; `QualityReview` verifica owner, JobId, estado, ausência de outro test-drive e ação permitida. Após escolher entregar, a única rotina de quitação V1 revalida a OS, DataStore, status, trabalhador e box; faz as mesmas checagens `HasRepairCredit`, consumo atômico de peças e prova de pagamento (`StageWorkerClaim`/`OwnerProofSweep`/tokens) do projeto original. `RepairDone` continua condicionado à persistência que já existia no V1. **Nunca atribuir moeda/XP/reputação pela posição, `Touched`, feedback do carro ou payload de avaliação do cliente.**

### Recuperação, abandono e casos-limite

- **Aborto físico:** a revisão volta a `Offer`, com opção Skip; a nota original não muda e nenhuma peça foi cobrada.
- **Sem ação por 300 segundos:** watchdog tenta entregar a qualidade original pela rotina V1 sem penalidade nova, desde que o proprietário ainda esteja conectado e o carro não esteja em condução. Não finaliza uma sessão fisicamente ativa.
- **Retrabalho:** o primeiro plano é descartado **antes** da quitação; `job.V2ReworkCount` aumenta e impede uma segunda oferta/rework. Novo minijogo gera novo token normal. A primeira tentativa não consumiu estoque nem teve crédito.
- **NPC/colaborador/staff:** todos são bloqueados na OS durante `V2QualityReviewPending` para não liquidar em paralelo, inclusive dispatcher de funcionários. Expansão/reconstrução de lote não deve ocorrer durante revisão.
- **Desconexão/fechamento de servidor:** como as OS V1 são efêmeras, `PendingQuality` também não é persistida. Se o jogador sair **antes do crédito**, a ordem é cancelada sem consumo/cobrança (comportamento V1 de OS não terminada). Não declarar recuperação de sessão interservidor. Essa limitação precisa ser avaliada com usuários em beta.
- **Gate desligado:** nenhum jogador fica em `PendingQuality`; a `FinishRepair` original continua liquidando imediatamente pela função reaproveitada.

## Testes de regressão escritos

- `tools/V2QualityDriveTest.luau`: elegibilidade, não oferecer a NPC/colaborador, nota mínima, oferta, teste aprovado/reprovado/incompleto, evento forjado, rework único, custo zero, timeout, estados falsos e snapshot sem token.
- `tools/V2DriveScenarioTest.luau`: seleção por seed e condições físicas, abortos/replays e não pagamento do diagnóstico.
- `tools/RunAllTests.luau` inclui ambas; `tools/ci/verify_contracts.py` valida gate desligado, apenas **um** `SettleRepairOwnerOnce`, barreira financeira, resultado selado, eventos e fechamento de minijogos sem `RepairDone` prematuro.
- GitHub CI verifica código estático e build Rojo, **não** executa os scripts Luau nem prova que o carro dirige corretamente.

## QA obrigatório antes de ativação

1. Uma OS Hatch sorteada para qualidade baixa (<70), outra alta (>=70) e uma OS comum não selecionada: confirmar as três transições e a ausência de revisão extra.
2. Concluir minijogo, receber `RepairQualityPending`, consultar `CheckRepairResult` em rede lenta, confirmar que **saldo, XP, estoque, rating e comprovante não mudaram** ainda.
3. Escolher Skip e comparar os valores com a execução V1 normal. Repetir `QualityReview` e `FinishRepair` antigos para provar idempotência.
4. Concluir uma rota válida: aprovado/retrabalho conforme nota original; repetir com colisão ou logout; nenhum evento de falha física deve reduzir a nota, cobrar peças ou gerar recompensa.
5. Refazer uma vez, finalizar por token novo, testar falta de peças, saldo, perda de DataStore, mudança de dono, morte, 2 jogadores/NPC e pagamento colaborativo preexistente.
6. Testar watchdog 300s e abandono; confirmar nenhuma OS fantasma retida no box nem funcionários atendendo carro em revisão.
7. Mobile, gamepad, HUD sem overlay escuro e clareza da mensagem de cliente. Validação física V2-11 e de diagnóstico V2-12 **antes** de ativar o gate.

**Fora do escopo:** recuperação de minijogos não creditados entre servidores, garantia de latência de dispositivos ainda não testados, V2-08 lotes de fornecedor, publicação ou merge com `main`.
