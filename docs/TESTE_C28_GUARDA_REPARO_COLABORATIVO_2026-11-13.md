# Oficina 24H — V1 C28 | Concorrência no salvamento de reparo colaborativo

**Data:** 13/11/2026 · **Status:** código e regressões preparados; CI de contratos estáticos + build Rojo. **Roblox Studio e DataStore real ainda não testados**.

## Problema encontrado
`WorkshopService.FinishRepair` valida a ordem e o responsável antes de executar o minijogo, mas **libera o servidor durante `DataService.Save(worker)`** para persistir uma `PendingClaim`, antes de gastar peças e pagar. Se o dono sair nesse intervalo, `WorkshopService.PlayerLeft` apaga a ordem e seu veículo (C26), porém a função `FinishRepair` pode retornar do Save com referência à OS antiga. Sem uma nova verificação seria possível tentar consumir estoque e efetuar uma liquidação para um carro inexistente.

Além disso, enquanto o salvamento aguarda, o vínculo com o colaborador ou o percentual de divisão podem mudar. A liquidação capturou valores antes do yield e não deve misturá-los com outra atribuição.

## Correção C28
1. Novo módulo puro `src/shared/RepairCommitGuard.lua`: só autoriza continuar quando a ordem **ainda é a mesma tabela dentro de `Jobs[jobId]`**, está em `InProgress`, pertence ao mesmo dono e trabalhador, ambos continuam disponíveis, a colaboração permanece autorizada e o percentual original não mudou.
2. Após salvar a reivindicação do mecânico, `FinishRepair` revalida a OS, o dono conectado e com perfil/oficina ativos, o executor conectado e com perfil ativo e o percentual acordado. **A guarda é executada antes de `SettleRepairOwnerOnce`**, portanto antes do débito de estoque e pagamento.
3. Se a ordem desapareceu ou mudou, cancela o encerramento sem conceder peças, moedas ou XP; tenta retirar a claim desta tentativa e persistir a limpeza. Se o Save da limpeza falhar, a reivindicação pode continuar registrada, mas **sem prova de pagamento do dono ela não autoriza crédito automático** (C25).
4. Se o Save inicial da claim falhar, também tenta limpar a reserva incompleta. Isso impede que uma tentativa abortada acumule reivindicações falsas.
5. `tools/RepairCommitGuardTest.luau` cobre remoção durante Save, reuso acidental do mesmo JobId com outro objeto, troca de colaborador, desconexão, OS concluída, inversão de usuários e mudança de percentual. Registrado no `RunAllTests.luau`.
6. `tools/ci/verify_contracts.py` exige a ordem correta: Save do trabalhador → guarda C28 → liquidação do proprietário.

## Testes a executar no Roblox Studio

- [ ] Abrir duas contas: A é proprietário, B é colaborador; iniciar reparo real, com valor e divisão definidos.
- [ ] Injetar latência controlada no salvamento da claim do trabalhador; fazer A desconectar antes do retorno do Save. Confirmar **zero crédito novo, zero consumo de peças**, OS removida e cliente inexistente não reaparece.
- [ ] Repetir com B desconectando e com a oficina sendo encerrada enquanto o Save está pendente.
- [ ] Tentar trocar o responsável ou percentual durante o Save. A conclusão antiga deve ser rejeitada; somente uma nova execução autorizada pode receber.
- [ ] Verificar o caso de falha do Save da claim: nenhum pagamento; eventual claim órfã fica auditável e não cria remuneração sem prova de dono.
- [ ] Repetir caso normal com duas contas, confirmando uma única parcela por usuário, recibo, XP, reputação e estoque coerentes.
- [ ] Rodar `RunAllTests` no Studio e conferir `RepairCommitGuardTest`; rodar `StudioPlaceAudit` após importação de modelos.
- [ ] Testar desconexão e retorno em dois servidores, orçamento real do DataStore e latência 200–1000 ms.

## Limites

A C28 reduz uma janela de corrida **antes do primeiro crédito ao proprietário**. Não cria transação atômica entre dois perfis. Quedas do servidor entre os diferentes Saves, claims antigas, importação de assets, UI e testes em aparelhos reais continuam sujeitos aos portões de homologação V1.

**V2:** sem implementação. **Assets:** cinco pacotes já baixados, mas não importados no Roblox Studio.
