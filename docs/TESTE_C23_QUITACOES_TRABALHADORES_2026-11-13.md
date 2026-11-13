# Oficina 24H — V1 C23 | Quitação durável do mecânico além do extrato de 64

**Data:** 13/11/2026. **Status:** código registrado no GitHub, CI Rojo e contratos estáticos; **testes Luau de Studio e DataStore real pendentes**.

## Motivo
O `RepairLedger` do perfil do contratado guarda somente 64 serviços. A C22 consulta o DataStore do contratado e libera a prova do dono somente se observar o crédito e a `PendingClaim` encerrada. Quando mais 64+ serviços acontecem, a linha de um pagamento antigo some do extrato. Mesmo que o contratado já tenha recebido, o dono pode ficar com comprovante preso para sempre. Há também risco de repetir o mesmo crédito se uma reivindicação antiga ainda existir e o marcador de 64 linhas tiver girado.

## Implementação C23
1. `src/shared/WorkerSettlementProofRules.lua` cria arquivo **privado** `WorkerSettlementProofs` com até **2.048** provas compactas de recebimento (JobId, Token, Amount, At, Service, Vehicle), separado do extrato de 64. Não possui expiração automática ou exclusão por idade. Arquivo cheio bloqueia novos créditos de contratado e requer resolução segura, em vez de perder marcador e potencialmente duplicar salário.
2. `DataService` migra o perfil para **schema v9**. Perfis v8 recebem confirmação dos créditos `Worker` **ainda presentes** no extrato. É impossível reconstruir automaticamente uma linha paga que já desapareceu **antes** da migração; tratar essas situações antigas como incertas, sem alegar prova.
3. `DataService.CreditRepairOnce` valida capacidade e token do trabalhador ANTES de registrar pagamento. Crédito, extrato e nova confirmação são alterados **no mesmo perfil e sem yield**; `DataService.Save` os persiste em uma única chave.
4. `DataService.HasRepairCredit` também pesquisa o novo arquivo: reenvio do mesmo JobId/Token após girar o ledger não recredita dinheiro. `ReconcileWorkerClaims` não remove a reivindicação em caso de falha do crédito por limite ou erro — só após confirmar crédito e Save.
5. O reparo colaborativo checa `HasWorkerProofCapacity` antes de gastar peças e registrar a parcela do dono. Isso reduz o risco de encerrar uma OS cujo contratado não conseguirá receber.
6. `OwnerProofSweepRules.CanRelease` pode validar o pagamento pelo ledger recente **OU** pelo novo arquivo privado do trabalhador consultado via `GetAsync`, mas exige `PendingClaims` ausente e mesmo token/valor/serviço/carro. Nunca libera prova por idade.
7. `WorkshopService` remove `WorkerSettlementProofs` do snapshot enviado ao cliente. Nenhum ID de token ou lista privada é replicado ao HUD.
8. Foram escritas as regressões `WorkerSettlementProofRulesTest`, alterações em `OwnerProofSweepRulesTest` e `PersistenceTest`; a suíte foi registrada no `RunAllTests` e os contratos de CI foram atualizados para schema v9 e segurança de créditos.

## Testes que o proprietário fará no Roblox Studio
- [ ] Criar 2 contas A (dono) e B (mecânico). Concluir serviço colaborativo, validar parcela de ambos e a ausência de pagamento duplicado após reabrir o jogo.
- [ ] Forçar mais de 64 novos pagamentos do mecânico; verificar que a linha antiga some do extrato, **mas `WorkerSettlementProofs` continua** e o mesmo token não pode pagar novamente.
- [ ] Sair do jogo e voltar depois; verificar saldo e arquivo preservados, e que o comprovante antigo do dono possa ser liberado pela C22 quando a claim já estiver ausente.
- [ ] Simular queda ao salvar o contratado antes/depois de criar prova; comparar valores no DataStore persistido. Se o crédito não foi salvo, a reivindicação precisa permanecer para recuperação.
- [ ] Forçar arquivo de 2.048 confirmações e testar nova colaboração: a operação deve ser recusada sem retirar peças ou pagar ao dono; simular uma claim mais antiga para verificar que continua pendente se não houver espaço.
- [ ] Testar migração schema v8→v9: ledger antigo com crédito `Worker` deve gerar prova no novo arquivo sem adicionar moedas nem XP.
- [ ] Validar cenário negativo de comprovante antigo que já foi excluído do ledger **antes da C23**; não presumir que a migração sabe se o pagamento ocorreu.
- [ ] Testar duas contas e dois servidores, muitos NPCs, mobile/gamepad, tentativas de reenvio de remotes, falhas e limitação do orçamento do DataStore.

## Limitações remanescentes — sem alegações indevidas
- **A transação entre a conta do dono e a do contratado NÃO é atômica.** A C23 melhora evidência/idempotência dentro do perfil do contratado, não oferece compromisso distribuído entre duas chaves.
- O arquivo é limitado a 2.048 confirmações por trabalhador, sem descarte silencioso. Depois de lotado, novos pagamentos colaborativos ficam bloqueados para preservar segurança. Uma etapa futura deve implementar descarte com confirmação verificada de ambas as contas ou auditoria segura.
- Para pagamentos **anteriores à C23** que já haviam girado do extrato sem um marcador, a evidência é irrecuperável por simples migração; requer análise por suporte ou evidência adicional.
- Um snapshot corrompido ou histórico antigo não é uma prova de pagamento; não remover reivindicações apenas pelo tempo.
- O CI faz contratos estáticos + build Rojo, **não** executa as suites LuaU nem garante comportamento do Roblox Studio real.
- Os assets 3D gratuitos já foram **baixados e organizados pelo proprietário**, mas ainda aguardam importação/configuração no place.

**Próxima prioridade V1:** política de compactação/arquivamento verificável do histórico de 2.048 provas do trabalhador, análise de antigos casos ambíguos e fechamento das demais pendências técnicas antes de qualquer mecânica V2.
