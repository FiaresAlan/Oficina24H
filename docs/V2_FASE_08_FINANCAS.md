# Oficina 24H — V2-08 | Gestão financeira e caixa

**Branch:** work/v2-00-02-fundacao-pilotos-gestao-2026-11-13 · **PR:** #27 (rascunho) · **Data:** 13/11/2026
**Status:** engenharia financeira e suites de testes escritas; execução Luau/Studio, QA visual e playtest econômico ainda pendentes. A main permanece sob homologação V1 do Claude.

## Caixa não é lucro

A V2-08 não substitui os comprovantes, créditos idempotentes, claims e proteções financeiras da V1. DataService.AddCoins, depois de aplicar de fato o saldo, registra a movimentação no livro de caixa categorizado do mesmo perfil. A receita de um serviço é o valor realmente liquidado, inclusive a parcela do proprietário em trabalhos colaborativos.

- **Fluxo total de caixa:** entradas menos saídas efetivas, com investimentos, premiações e folha.
- **Fluxo operacional:** créditos de OS menos compras de estoque, publicidade e salários PAGOS. Compra de peça sai do caixa no checkout; seu consumo na OS não sai de novo.
- **Preço-base referencial:** cotação atual dos 15 serviços menos custo de tabela das peças, antes de salários, descontos, qualidade e variação de recompensa.
- **Lucro contábil:** indisponível (`AccountingProfitAvailable=false`), porque estoque legado/gratuito não possui custo histórico auditável e investimentos não são amortizados. O painel não inventa essa medida.

## Persistência schema v14

O novo campo `FinanceLedger` contém data de início, saldo de abertura, entradas/saídas acumuladas, categoria e número de lançamentos. Um perfil novo não considera as moedas iniciais como faturamento. Em perfil v11/v12/v13, o livro inicia com os até 50 movimentos legados disponíveis e é marcado como HISTÓRICO PARCIAL; não declara totais completos desde a criação da conta.

Depois da migração, as categorias se acumulam mesmo quando as últimas 50 transações detalhadas são substituídas. A reconciliação de saldo (saldo real - abertura - movimentos registrados) mostra alerta se houver divergência. Nenhum token, prova financeira ou `FinanceLedger` bruto vai ao cliente; só o campo sanitizado `Finance` no snapshot.

Categorias: Serviços, Inventário/peças, Folha, Publicidade, Equipamentos, Prédio, Contratação, Recompensas e Outros. Movimentos de anúncios e todas as fontes de ProgressService são classificados. Um checkout misto separa o débito em peças e equipamentos SEM YIELD após validar o total uma única vez; o saldo final e a entrega de itens não mudam.

## Reposição e precificação

A sugestão de reposição verifica somente OS `InProgress` e `Diagnosed` e usa Requirement.Parts do snapshot sanitizado. Quantidade urgente = faltante em estoque da prateleira, que é o estoque efetivamente consumido nas OS V1; não conta itens na mochila como disponíveis para esse consumo. Buffer opcional de dois serviços futuros é proporcional ao histórico de até 30 serviços conhecidos. Nada é comprado automaticamente e defeitos secretos não são revelados.

A aba Caixa do painel Ordens mostra saldo, entradas, saídas, conciliação, reserva da próxima folha, fluxo operacional, estoque referencial, alertas, reposição, categorias, até 16 transações e preços/partes de 15 serviços. Não adiciona botão à HUD e não possui ação remota financeira. O multiplicador de preços e decisões dos clientes permanecem no sistema V1.

## Testes e segurança

- `tools/V2FinancialRulesTest.luau`: categoria, cashflow, reconciliação, 15 cotações, reposição após diagnóstico, dados inválidos, legados e avisos.
- `tools/PersistenceTest.luau`: migração v13 para v14, crédito de OS idempotente, saldo e livro no mesmo Save, relog, 50 linhas truncadas sem perder agregados.
- `tools/RunAllTests.luau`: suite registrada; `tools/ci/verify_contracts.py`: contratos estáticos de schema, privacidade, UI e não-dupla-contagem.
- CI/GitHub Actions compila Rojo code-only e valida contratos; NÃO executa Luau no Roblox Studio.

**Portão QA Studio:** conferir 15 reparos, NPC, colaboração, preço 0,7–1,5, salário, compras mistas e estoque, primeiro login, migração, falha/salvamento DataStore, reconciliação, mobile/scroll e playtest gerencial de 20–30 minutos. A integração com a main depende do QA V1.

**Limitação funcional explícita:** compra de fornecedores com graus premium/econômico de qualidade NÃO foi introduzida, pois exigiria controle de lotes, custos, consumo e rollback adicional para não alterar a contabilidade ou quebrar a V1. Permanece como requisito de código em aberto do checklist V2-08.
