# Oficina 24H — V1 C24 | Compactação segura de quitações finalizadas

**Data:** 13/11/2026. **Status:** fase de código concluída, homologação Roblox Studio pendente. Não foi executado teste em DataStore real ou cliente de jogo.

## Motivo
A C23 mantém até **2.048 provas detalhadas** de recebimento por mecânico, independentemente do extrato das últimas 64 operações. Isso evita um pagamento duplicado depois que a linha do extrato gira, mas com muitos serviços o arquivo enche, bloqueando novos trabalhos. Simplesmente apagar comprovantes antigos seria um risco financeiro. A C24 libera espaço **somente depois de verificar que o ciclo entre as duas contas terminou**, conservando um identificador irreversível contra repetição do pagamento.

## Implementação
1. **Schema v10** adiciona `WorkerPaidTombstones` (até **8.192** registros compactos `JobId + Token`) ao **mesmo perfil do trabalhador**, sem expiração nem descarte automático. `WorkerPaidTombstoneRules.Compact` insere o tombstone **antes** de remover a prova detalhada, no mesmo estado em memória sem yield; `Save` grava a transição na mesma chave.
2. **Novas provas C24** preservam `OwnerUserId`, extraído da claim do trabalhador que foi registrada pelo servidor. Marcadores de C23/versões anteriores que não tenham esse vínculo ficam **intactos**, pois não é possível adivinhar seu proprietário.
3. `WorkerProofArchiveRules.CanCompact` exige: marcador válido e antigo (janela mínima de 900 s); ID do proprietário consultado igual ao marcador; **nenhuma claim ativa** para o mesmo JobId/token; e **ausência da prova correspondente** no perfil do dono obtido por `Store:GetAsync`. Se não houver perfil, lista de provas, confirmação ou dados consistentes, **não compactar**.
4. `DataService.ReconcileWorkerProofs` faz primeiro `Save(worker)`, garantindo saldo, marcador e baixa da claim persistidos. Depois lê o perfil do dono no DataStore, revalida o vínculo após o yield, converte a prova em tombstone e faz novo `Save(worker)`. Falha de leitura ou salvamento mantém a evidência anterior no DataStore. Só comunica contagem positiva se a gravação final foi confirmada.
5. **Cargas limitadas:** no máximo quatro leituras de proprietários por rodada, com intervalo mínimo de 300 s por trabalhador; cursor circular; execução retardada no login e nos ciclos de autosave. Arquivo de tombstones cheio impede nova compactação e preserva os detalhes, em vez de apagar evidências.
6. `DataService.HasRepairCredit` e `CreditRepairOnce` pesquisam tombstones antes de pagar. Assim, mesmo com o extrato de 64 e a prova detalhada já removidos, **o mesmo JobId/token continua recusado** (inclusive após reconexão).
7. Na migração, `WorkerSettlementProofRules.FromLedger` ignora pagamentos **já compactados** para não recriar provas detalhadas a partir do extrato recente. `WorkshopService` não envia tombstones nem provas ao cliente.
8. Foram registrados `WorkerProofArchiveRulesTest.luau`, regressões adicionais em `PersistenceTest.luau`, `RunAllTests` e verificações em `verify_contracts.py`; testes antigos de schema atualizados para v10.

## Como validar no Roblox Studio (pendente para o proprietário)
- [ ] Com duas contas A (dono) e B (mecânico), concluir uma OS: confirmar parcela do dono, do trabalhador, recibo e `PendingClaims` ausente.
- [ ] Enquanto A ainda possui `OwnerSettlementProofs` para essa OS, B não pode compactar.
- [ ] Após confirmação de que A **salvou** a remoção da prova, a C24 pode compactar o registro de B, preservando o tombstone.
- [ ] Reenviar o token antigo após compactação, reconexão e 70 novos serviços: dinheiro e XP não podem aumentar novamente.
- [ ] Interromper `GetAsync`, o primeiro e o segundo `Save` do worker; exigir persistência coerente e ausência de dupla concessão.
- [ ] Testar worker com marca C23 legada sem `OwnerUserId`: não deve ser compactada automaticamente.
- [ ] Simular 2.048 marcadores detalhados e verificar se as quitações elegíveis liberam vagas; com 8.192 tombstones, jamais apagar marca antiga.
- [ ] Executar `tools/RunAllTests.luau` no Studio, testes com dois servidores/latência e equipamentos PC/mobile/gamepad.

## Limitações honestas
- **Não há transação atômica entre duas contas no Roblox DataStore.** A C24 exige confirmação da baixa da prova na conta do dono e grava tombstone na mesma conta do trabalhador; isso não elimina todas as janelas de queda distribuída.
- A capacidade final também é **finita** (8.192 tombstones por trabalhador). A C24 não resolve escala indefinida. Quando as estruturas estiverem cheias, o sistema recusa novos pagamentos colaborativos, priorizando a proteção dos saldos.
- Marcadores antigos **sem proprietário conhecido** não são removidos; e créditos anteriores à C23 que já haviam saído do ledger não podem ser reconstituídos por adivinhação.
- `OwnerSettlementProofs` precisa ter sido baixada com segurança antes de um marcador ser compactado. Não há descarte por tempo como substituto de autorização.
- O CI atual confere contratos estáticos e build Rojo; as suítes LuaU foram **escritas**, não executadas no Studio nesta rodada. A homologação do jogo no Studio é necessária antes de publicar.

**Assets:** cinco pacotes já baixados e organizados pelo proprietário continuam pendentes de importação no place; não alterados nesta fase. **V2:** sem implementação.
