# V1 C21 — Provas duráveis de repasse, limpeza confirmada e limite seguro

**Data:** 13/11/2026. **Status:** código escrito e CI/Rojo verificados; **Roblox Studio e DataStore real ainda não executados**.

## Problema da C14/C15
A lista privada `OwnerSettlementProofs` retinha até 1024 provas. Ao adicionar a prova 1025, a regra anterior fazia `table.remove(raw, 1)`, mesmo sem saber se o trabalhador correspondente já havia recebido. Se a conta do proprietário continuasse gerando repasses e a conta do contratado ficasse offline/pendente, a prova necessária para recuperação financeira poderia desaparecer.

## C21 — correção executada
1. `OwnerSettlementProofRules.CanAdd/Proofs.Add` **não expulsam registros antigos**. Quando as 1024 posições estão ocupadas, recusam adicionar outra prova, sem mutar saldo/ledger. `Sanitize` conserva os registros mais recentes válidos se dados antigos estiverem acima do teto.
2. `DataService.CreditRepairOnce` faz preflight de capacidade da prova **antes** de registrar a parcela do proprietário. `WorkshopService.FinishRepair` detecta capacidade esgotada **antes** de consumir as peças, pagar ou encerrar a OS colaborativa.
3. O fluxo de sucesso da OS com dois jogadores primeiro confirma os dois perfis persistidos, então elimina a `PendingClaim` do contratado e confirma **novo Save do trabalhador**. Só depois `DiscardConfirmedOwnerProof` pode remover a prova equivalente na conta do proprietário e gravar essa limpeza.
4. Se ocorrer falha ao salvar a limpeza da claim, a prova original é preservada para resgate posterior; se o proprietário sair, a prova também é mantida. Não usar uma simples notificação de cliente como comprovante de transferência.
5. `OwnerSettlementProofRulesTest` agora cobre arquivo cheio, preservação da prova mais antiga, recusa de substituição, validação do trabalhador ao remover e reuso do espaço após a confirmação.
6. `PersistenceTest` simula falha do `UpdateAsync` por 4 tentativas, permanência da prova durante falha de remoção da claim, limpeza ordenada, reconexão, saldo único, ledger idempotente e bloqueio de novas provas com arquivo cheio.
7. `tools/ci/verify_contracts.py` exige o encadeamento de segurança de capacidade e limpeza do comprovante após `Save(worker)`.

## Critério de segurança
- Uma prova **não pode desaparecer apenas por haver muitas transações posteriores**.
- A conclusão da OS não deve gerar receita duplicada ao repetir um comando.
- Arquivo cheio deve impedir **somente novos repasses colaborativos que precisam de prova**, não serviços comuns ou NPCs mono-perfil.
- Nenhuma conta pode ser declarada “paga” após apenas um `Save` da conta do proprietário.
- Um retorno `false` do `Save(worker)` deixa a prova intacta.

## Testes que o usuário fará depois no Roblox Studio
- Jogador A como dono e B como mecânico: concluir 1 reparo colaborativo, confirmar as duas parcelas, deixar as contas serem salvas, desconectar e reconectar ambos; nenhuma claim/prova residual indevida e nenhuma moeda duplicada.
- Interromper o `Save` do contratado após o crédito do dono: prova permanece, e B recupera a parcela na próxima sessão após a janela de segurança, sem novo pagamento de A.
- Simular atraso de dados, 2 servidores com reconexão e logout durante a limpeza das claims; reconciliação não deve perder nem duplicar créditos.
- Com 1024 provas **ainda não confirmadas**, nova colaboração deve falhar ANTES de gastar peças ou pagar, com mensagem explicativa; atividades comuns continuam.
- Conferir DataStore budget/tempo de salvamento e performance em servidor real, além de `RunAllTests` e `StudioPlaceAudit`.

## Limitações que continuam abertas (não afirmar atomicidade)
- O Roblox DataStore não oferece transação atômica entre dois perfis. Ainda há janela de queda antes de a conta do dono confirmar o crédito; a claim do trabalhador sozinha **não** prova pagamento.
- Um arquivo cheio com 1024 claims/provas **realmente pendentes** bloqueia novas colaborações, em vez de perder provas: é uma contenção deliberada, não solução de capacidade infinita.
- Provas antigas de versões anteriores podem continuar no perfil até serem reconciliadas; esta fase não percorre todos os perfis de trabalhadores offline.
- Sucesso de CI/Rojo não prova funcionamento com o *place* real, scripts LuaU executados, conexões móveis, 2+ jogadores e DataStore de produção.

**Registro de assets:** os pacotes 3D organizados pelo proprietário permanecem prontos para importar segundo [GUIA_UNICO_ASSETS_V1.md](GUIA_UNICO_ASSETS_V1.md); nenhum asset foi importado nesta fase.
