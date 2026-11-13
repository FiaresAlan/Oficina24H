# C10 e C11 — confirmação financeira e recuperação de salvamentos (13/11/2026)

## Problema observado em C9
Após aplicar saldo, peças e XP em memória, `FinishRepair` gravava dono/executor no DataStore e emitia `RepairDone` **mesmo se um salvamento retornasse false**. A consulta `CheckRepairOutcome` lia o recibo em memória antes da variável de liquidação e portanto podia mostrar `Completed` sem durabilidade comprovada. Um `Save` de perfil ausente também retornava sucesso.

## C10 — entrega condicionada ao salvamento confirmado
- `SettlementDeliveryRules` mantém por sessão JobId/token e confirma `OwnerSaved` e `WorkerSaved`, exigindo **ambas** as respostas positivas (mesmo quando dono e executor são a mesma pessoa).
- `CheckRepairOutcome` devolve `Processing` antes de considerar recibo em memória enquanto a barreira está pendente.
- `FinishRepair` não reemite um recibo enquanto a sessão está pendente e bloqueia novo reparo do executor neste estado.
- `DataService.Save` responde `false` para perfil ausente; `writeProfile` não declara sucesso sem `Store`.
- A confirmação `RepairDone` ao executor e o aviso financeiro ao dono são enviados somente após o resultado positivo das gravações.
- O fluxo **legado de timing**, sem GUID, permanece separado: falta migrá-lo para comprovantes duráveis.

## C11 — recuperação sem reaplicação de crédito
- Após uma falha, o servidor retém o resultado em memória sob o token original, avisa que a gravação está pendente e inicia retentativas limitadas e espaçadas por executor.
- A cada retentativa salva somente os perfis ainda não confirmados. **Não chama novamente** `TakeParts`, `CreditRepairOnce`, notas ou XP.
- Se não recuperar após 6 retentativas externas, mantém `Processing` sem fabricar sucesso. Sessões pendentes impedem novos reparos até resolver ou desconectar.
- Testes adicionados: regras de barreira de entrega e falha injetada de `UpdateAsync` no mock DataStore, seguida de recuperação sem duplicação.
- O CI inclui contratos da nova barreira; build Rojo na branch deve ser registrado antes da promoção à main.

## Portões para o Studio (AINDA NÃO EXECUTADOS)
1. Rodar `tools/RunAllTests.luau` e registrar o relatório de `SettlementDeliveryRulesTest` e `PersistenceTest`.
2. Validar uma OS com dono=executor, recebendo um único `RepairDone` e um único crédito.
3. Em teste de **dois jogadores**, completar OS contratada e simular (por mock/QA) falha do DataStore só do executor depois do save do proprietário. Conferir `Processing` antes de `Completed` e que não se duplica saldo ao consultar ou retransmitir.
4. Desconectar dono ou executor durante a falha; verificar resultados após reconexão e eventual perda de uma parcela; reproduzir falha na liberação do lock.
5. Checar tela mobile/gamepad e latência de 200–1000 ms; monitorar budget de `UpdateAsync`.

## Limitação financeira de arquitetura (P0 ABERTA)
Roblox DataStore não oferece transação atômica envolvendo as duas chaves de jogador. Se o primeiro perfil for salvo e o segundo não, e o servidor cair nesse intervalo, uma parcela pode sobreviver sem a outra. Essas fases **não garantem compensação automática após falha definitiva do servidor**. O passo seguinte necessário é um protocolo com intenção/outbox persistente e reconciliação interservidor, testado sob falhas de processo. Não se deve publicar contratos de jogadores com promessa de liquidação infalível antes desse P0.
