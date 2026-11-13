# Oficina 24H — V1 C22 | Liberação segura de provas antigas de colaboradores

**Data:** 13/11/2026. **Implementação:** fase de código da V1. **Homologação Roblox Studio:** ainda não executada.

## Risco abordado
A C21 protege comprovantes de repasses colaborativos que ainda podem ser necessários: não os apaga ao atingir 1.024. Porém, se o dono ou o mecânico sair durante a finalização/limpeza, a prova pode ficar presa no perfil do proprietário, mesmo com pagamento do trabalhador concluído. Isso pode lotar o arquivo e bloquear novas OS colaborativas.

A C22 introduz uma **reconciliação conservadora sob demanda**, inclusive quando o colaborador está offline. **Não** utiliza idade do comprovante como autorização de exclusão.

## Alterações reais
1. Novo módulo puro `src/shared/OwnerProofSweepRules.lua` define limite de 4 leituras por passagem, intervalo mínimo de 300 segundos por dono, janela de segurança de 900 segundos e cursor circular sobre as provas, sem priorizar sempre os primeiros registros.
2. `OwnerProofSweepRules.CanRelease` só autoriza retirada se o `GetAsync` do perfil persistido do trabalhador identificado na prova trouxer:
   - `RepairLedger` com **JobId + Token exatos**, `Role = "Worker"`, mesmo valor da parcela, serviço e veículo; e
   - `PendingClaims` válida como tabela e **sem reivindicação para aquele JobId/Token**.
3. Qualquer falta de prova, dados divergentes, claim ainda aberta, ledger antigo já rotacionado (64 itens), erro de `GetAsync` ou resposta inválida preserva o arquivo do dono. **Não há exclusão por expiração**.
4. `DataService.ReconcileOwnerProofs` roda após atraso no login do dono se houver provas e depois no ciclo de autosave, com proteção de concorrência e máximo 4 leituras remotas por período de cinco minutos.
5. Após `GetAsync`, a rotina confere que a sessão/perfil original ainda é o mesmo e que o comprovante não mudou durante a espera. Se liberar alguma prova, marca o perfil do dono e faz `DataService.Save`. Falha nesse save não confirma limpeza; a cópia persistida preserva o registro.
6. Ao atingir o limite de 1.024 registros, a limpeza de provas realmente pagas permite abrir espaço para novas colaborações sem apagar possíveis dívidas.
7. Foram escritos testes em `OwnerProofSweepRulesTest.luau` (dados inválidos, claim aberta, divergências, ledger rotacionado, cursor e limite), e ampliados `PersistenceTest.luau` (GetAsync falho, Save falho, reconexão, arquivo cheio, reivindicação ativa). Registros estáticos no `verify_contracts.py` e suíte adicionada ao `RunAllTests`.

## Critérios para homologação Studio pelo proprietário
- [ ] Jogador A dono e B contratado realizam uma OS colaborativa; após confirmação dos dois perfis, B sai antes da limpeza; A faz nova sessão e a prova quitada é removida sem alterar moedas.
- [ ] Simular queda após salvar dono, antes de salvar executor; prova permanece e B consegue recuperar sua parcela ao retornar.
- [ ] Simular crédito salvo no worker, mas `PendingClaim` ainda no DataStore; prova do dono deve ficar intacta até a reivindicação ser removida e salva.
- [ ] Criar perfil de teste com provas mais antigas que 900 segundos, sem crédito matching; comprovar que a rotina não exclui por idade.
- [ ] Injectar falha de `GetAsync` e `UpdateAsync`; nenhuma exclusão não confirmada deve aparecer em DataStore.
- [ ] Testar 1.024 comprovantes, dos quais apenas alguns estão seguramente pagos; espaço só se abre para os comprovados.
- [ ] Verificar contagem/budget do DataStore, lag, save, perfis com ledger rodado e dois servidores.
- [ ] Rodar `tools/RunAllTests.luau` e `StudioPlaceAudit` com projeto e assets reais.

## Limites conhecidos que NÃO foram resolvidos
- **Não existe atomicidade entre duas contas no DataStore Roblox.** O protocolo de prova/claim e recuperação reduz a falha, mas não constitui transação distribuída.
- O ledger comum do trabalhador guarda até 64 registros. Se seu crédito saiu desse histórico antes da verificação, **C22 não pode provar quitação** e manterá o comprovante para análise/suporte. Não limpar “porque parece antigo”.
- Um contratado que **nunca recebeu** não terá ledger; o comprovante permanece e a reclamação deve ser reconciliada quando ele retornar. A C22 não credita a conta de outros jogadores: só faz leitura.
- O limite de leitura e a preservação cautelosa são deliberados. Em alto volume, uma conta pode levar vários ciclos para liberar todas as provas elegíveis. Isso evita tráfego excessivo e risco de apagar dívidas.
- Suíte LuaU escrita ≠ suíte executada no Studio. O CI deste repositório faz contratos estáticos e build Rojo, não multiplayer/DataStore real.
- A biblioteca de assets já baixada pelo proprietário permanece **aguardando importação ao Roblox Studio**; nenhum pacote 3D foi alterado.

## Próxima prioridade da V1
Definir confirmação durável de quitações que sobreviva à rotação dos 64 registros do trabalhador, ou oferecer um fluxo de auditoria/suporte verificável, sem nunca inventar pagamento. Continuar também revisão das pendências de integração e licença antes da V2.
