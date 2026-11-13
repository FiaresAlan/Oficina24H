# C9 — Extrato financeiro e histórico confiável na HUD

**Data:** 12/11/2026  
**Base:** `main` após C8 (schema v5)  
**Status:** código, testes Luau e contratos CI escritos. Studio/mobile ainda não validados.

## Objetivo
No painel Ordens > Concluídas, o histórico já mostrava avaliações e valor estimado da OS, mas esse número não correspondia necessariamente ao valor realmente creditado ao jogador (qualidade, bônus, gorjeta ou trabalho colaborativo). Após desconexão, quem atuava como contratado tinha pouca visibilidade do próprio pagamento.

## UX implementada
- Novo **Extrato de Reparos** na aba Concluídas, baseado somente nos últimos 12 lançamentos reais do ledger C8.
- Totais mostram claramente **quanto foi creditado** nesse recorte, quanto veio da **própria oficina** e quanto de **trabalhos como contratado**.
- Linhas mostram serviço, veículo, valor efetivo creditado, função do jogador, qualidade do trabalho (se existente) e há quanto tempo ocorreu.
- Em telas compactas, os dados de cada linha mudam para uma disposição vertical, em vez de extrapolar a largura do celular.
- Histórico de clientes permanece em seção própria e mantém miniatura, avaliação e preço registrado da OS. Evita apresentar preço da OS como pagamento do trabalhador.
- Uma oficina sem ordens próprias, mas com trabalho colaborativo remunerado, continua vendo o extrato, sem estado vazio incorreto.

## Privacidade e dados
- `WorkshopService.GetSnapshot` cria uma cópia superficial do perfil e **remove `RepairLedger`** antes da replicação. Chaves GUID e dados financeiros privados do ledger bruto não são enviados para a interface.
- Somente `RecentSettlements` é enviado (até 12, já sem `Token`/`JobId`), com serviço, veículo, valor, papel, momento, qualidade e estrelas.
- `RepairStatementRules.Build` saneia valores, limita 20 linhas e ordena datas, com resumo determinístico; nunca exibe tokens, JobId ou atributos inesperados.
- Assinatura reativa do painel considera mudanças no extrato para atualizar o conteúdo quando o servidor confirma um novo crédito.
- Nenhuma ação de interface altera saldo, parcelas, gorjetas ou conteúdo de DataStore.

## Arquivos
- `src/shared/RepairStatementRules.lua`: cálculo e apresentação do extrato dos últimos registros.
- `src/server/WorkshopService.lua`: snapshot do perfil sem ledger bruto e campo `RecentSettlements`.
- `src/client/UI/Panels/Orders.lua`: aba Concluídas com resumo e recibos responsivos, sem overlay adicional.
- `tools/RepairStatementTest.luau`: **23 testes escritos** de soma, papel, média, ordenação, saneamento, privacidade e limites.
- `tools/RunAllTests.luau` e `tools/ci/verify_contracts.py`: registro da suite e verificações de integração.

## Portões de qualidade pendentes
- [ ] Executar `RunAllTests` com `SettlementLedgerTest`, `PersistenceTest` e `RepairStatementTest` no Studio.
- [ ] Concluir OS como proprietário; verificar crédito real e histórico do cliente.
- [ ] Concluir como trabalhador contratado; verificar valor da parte recebida sem misturar com preço total do cliente.
- [ ] Desconectar e entrar em outro servidor; o extrato deve recuperar lançamentos previamente salvos.
- [ ] Confirmar que `GetSnapshot` não inclui `RepairLedger`, `Token`, nem chave financeira privada.
- [ ] Comparar números de extrato com `DataService.Transactions`; separar promoções, gorjetas e combos.
- [ ] Testar 320×568, 390×844, 844×390, 1366×768 e 1920×1080.
- [ ] Verificar scroll, corte de textos, leitura com gamepad, touch e acessibilidade.
- [ ] Executar 20+ atendimentos, reconexões e duas contas simultâneas; verificar impacto em desempenho e DataStore.

**Nota:** o extrato resume somente os **últimos 12 créditos**, não o faturamento total da carreira. O ledger C8 tem no máximo 64 entradas recentes. Testes Luau/Studio e publicação permanecem pendentes.
