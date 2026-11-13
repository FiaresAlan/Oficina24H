# V1 — C20: ordem exclusiva do funcionário e liquidação do serviço NPC

**13/11/2026.** Escopo entregue em código, pendente de homologação no Studio. Nenhuma fase de gameplay V2 foi iniciada.

## Problemas encontrados na base anterior
- Enquanto um funcionário NPC caminhava e trabalhava numa OS, o dono podia iniciar reparo manual, abandonar a ordem, iniciar reparo NPC avulso ou tentar convidar colaborador; competição tornava resultado imprevisível.
- `Staff.Busy` era marcado somente depois que a `task.spawn` de trabalho iniciava; o despacho não reservava a OS de forma sincrônica.
- Erro não tratado durante pathfinding/reparo podia manter a OS como ocupada, sem soltar o funcionário.
- O reparo autônomo e a contratação avulsa NPC creditavam com `AddCoins` diretamente. Não existia recibo idempotente para o serviço NPC e mensagem de sucesso podia chegar antes da confirmação persistente do perfil.

## C20 — mudanças
1. `StaffAssignmentRules.TryReserve/IsReserved/Release` fazem reserva atômica em memória antes da `task.spawn`. Somente uma rotina NPC assume cada JobId; testes cobrem dupla reserva e liberação.
2. `WorkshopService` recusa abandono, reparo manual, preparação física, contratação avulsa, convite e aceite de colaboração se a OS estiver reservada ao funcionário. O funcionário confere estado real, dono, reserva e existência de sessão manual antes de consumir peças.
3. Em erro interno na rotina de trabalho, `xpcall` remove a reserva e restaura o estado visual do carro ainda ativo. Dispensa/desconexão cancela conclusão e impede pagamento de NPC removido.
4. `DataService.SettleNpcRepairOnce`: valida catálogo e estoque, debita as peças e cria crédito idempotente por JobId+GUID no **mesmo perfil** sem yield. Se o ledger recusa, restaura as peças.
5. O empregado e o NPC avulso utilizam essa transação. Salvamento por `DataService.Save` confirma o mesmo perfil (peças/saldo/ledger/avaliação) antes de comunicar pagamento como sucesso; em falha faz retentativas sem reaplicar crédito.
6. `PersistenceTest` inclui falta de peças, quantidade inválida, replay de token, teste de `UpdateAsync` falhando por 4 tentativas, segunda gravação e reconexão. `StaffAssignmentTest` inclui reserva, concorrência e liberação. `tools/ci/verify_contracts.py` verifica o encadeamento real dos módulos.
7. A biblioteca de assets do proprietário foi registrada como **baixada, organizada e ainda não importada** em `GUIA_UNICO_ASSETS_V1.md`, sem duplicar downloads.

## QA Studio — ainda NÃO executado
- Atribuir uma OS a mecânico NPC: antes e depois dos 25 s (quando só há um carro) e com dois carros.
- Tentar simultaneamente reparar, cancelar, convidar profissional, aceitar convite pendente e usar NPC avulso. Operações concorrentes devem ser recusadas enquanto NPC está no carro.
- Demitir trabalhador durante o caminho e durante o reparo: nenhuma moeda ou peça pode ser creditada/consumida pelo serviço interrompido.
- Simular erro de modelo/pathfinding e confirmar que reserva e `Trabalhando` são liberados.
- Concluir serviço via funcionário e NPC avulso: saldo, peças, lançamento privado e avaliação devem aparecer uma vez, mesmo com reenvios de comando.
- Testar DataStore desligado, latência, saída durante `Save`, reconexão e duas contas com ordens simultâneas. Mensagem de êxito só após confirmação do `Save`.
- Controles de celular/gamepad e FPS com os assets reais em `ServerStorage.Assets`.

## Riscos/P0 ainda abertos
- Um crash antes da gravação do perfil ainda pode perder o trabalho in-memory; o DataStore simples não garante transações envolvendo múltiplos perfis. O caminho NPC é mono-perfil e usa retentativa, mas não é garantia de entrega entre quedas irrecuperáveis.
- Contas de colaborador continuam em duas chaves sem atomicidade distribuída e provas têm retenção finita.
- O “NPC avulso” legado continua concluindo de forma imediata (sob custo de 55%); é um produto distinto do mecânico empregado fisicamente visível. Decidir se será removido após playtest.
- Testes Luau foram **escritos**, não executados em Studio; o CI valida contratos e build Rojo.
