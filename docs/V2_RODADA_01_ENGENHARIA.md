# Oficina 24H — V2-00/01/02 · Relatório de engenharia

**Data:** 13/11/2026 · **Branch:** `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13` · **PR:** [#27](https://github.com/FiaresAlan/Oficina24H/pull/27) · **Base V1:** `0d00fa60` (A1–C31; V1 permanece sob QA do Claude).

## Contrato de entrega

As três frentes são engenharia de produção, **não demos**. Nenhuma lógica é declarada homologada pelo Studio. Toda a execução de V2 está em branch isolada para não alterar a `main` durante a verificação da V1. Não há force-push nem publicação.

A conclusão **de código** significa scripts, APIs, migrações, UI, testes escritos e CI Rojo aprovados. A conclusão **de produto** requer os 3 modelos reais importados e testados, as demais fases da V2 e os gates Studio. Não confundir estas situações.

## V2-00: compatibilidade com V1 e migração

**Código:** `src/shared/V2CompatibilityRules.lua`, `src/server/DataService.lua`, `tools/V2FoundationTest.luau` e blocos novos em `tools/PersistenceTest.luau`.

- Perfil do jogador sobe de schema **v11 para v12** por migração aditiva. Mantém `RepairLedger`, `WorkerSettlementProofs`, `OwnerSettlementProofs`, `WorkerPaidTombstones`, `PendingClaims`, `PendingClaimAudits` e os mecanismos C18–C31 anteriores.
- Adiciona exclusivamente `SupplyRequests` (mapa whitelist item→quantidade) e `TelemetryV2` (dois marcos booleanos). NÃO altera moeda, XP, ordens antigas, comprovantes ou IDs do DataStore.
- `V2CompatibilityRules.Profile` é preflight não destrutivo da versão **após reconciliação**; `Snapshot` bloqueia seis campos financeiros privados enviados ao cliente. `GetSnapshot` da V1 já remove esses campos; não reabrimos permissões.
- `SupplyRequests` é atualizado ao solicitar peças **sem comprar nada**. Fulfillment acontece SOMENTE em `BuyPart` ou `Checkout`, após validação e débito da loja física. `AddParts` usado para rollback não apaga pedidos.
- Provas multichave de diferentes jogadores continuam com a semântica V1 (reconciliação/recibos); este código não promete transação atômica entre chaves.
- Testes escritos: perfil novo, v11→v12, idempotência da lista, rollback de peças não paga lista, confirmação de compra, reconexão e marco único.

**Limitação de engenharia externa:** bug da V1 descoberto pelo Claude precisa ser integrado após revisão de diferenças. Nenhum Luau/Studio real executado por esta rodada.

## V2-01: três veículos piloto e pipeline de arte

**Modelos designados do catálogo V1:**
| Arquétipo | Nome exibido | `ServerStorage.Assets.Veiculos` |
|---|---|---|
| Hatch | Hatch amarelo | `Veiculo_Hatch_MG3` |
| Sedã | Sedã azul | `Veiculo_Sedan_Civic` |
| Picape | Picape antiga | `Veiculo_Picape_S10` |

**Código:** `V2VehiclePilotRules`, `V2PilotRigBuilder`, `V2PilotArtProfiles`, `V2VisualBudgetRules`, `V2PilotLOD.client.lua`, e integração de clone em `CustomerArrivalService`.

- No runtime, só o clone dos três pilotos recebe **oito** pontos de interação com `Attachment`: capô, duas portas, porta-malas e quatro rodas. Reaproveita `Raiz` e atributos de dimensão V1. Modelos não-piloto ficam intactos.
- O builder é idempotente e nunca substitui sockets `OficinaSocket_<StepId>` V1.
- Um artista pode criar/ajustar pivôs diretamente no modelo real. `tools/V2AuthorPilotRigs.luau` faz a autoria inicial no *Studio Edit* **depois de backup**, e `tools/V2PilotPlaceAudit.luau` valida os três pilotos sem alterar o place.
- Materiais são seletivos via atributo `V2ArtRole=Paint/Trim/Glass/Mechanical`. Sem tags, as peças mantêm materiais, cor e licença originais. Paleta de cada arquétipo definida em `V2PilotArtProfiles`.
- LOD: apenas elementos explicitamente marcados `V2DetailLevel=High/Medium/Always` são ocultados localmente por distância e perfil touch/desktop. Nada mexe na colisão, no casco, nas rodas funcionais ou no financeiro.
- Testes escritos: catálogo, pivôs duplicados/inválidos, idempotência, preservação de outros modelos, LOD e estilo seletivo.
- A geração de Attachments **não abre capô nem move rodas**: a ação física pertence à V2-03, usando os pivôs já mapeados. Asset GLB real pode ter partes modeladas em uma malha única e exigir separação de malhas no Blender/Studio. Essa integração visual não pode ser afirmada sem importar os modelos.

## V2-02: recepção, fila e gestão utilizáveis

**Código:** `V2ReceptionRules`, `V2SupplyRules`, `V2ManagementSummaryRules` integrados a `WorkshopService`, `DataService`, `Main.server.lua`, `StationService`, `Orders.lua`, `Shop.lua`, `Stock.lua`.

- Balcão físico procedimental ao lado da TV original de ordens; prompt `Recepcao` abre o mesmo painel, sem obrigar novo pack GLB e sem destruir a rua V1.
- Estado público das ordens: aguardando, agendado, diagnóstico, aguardando peça, colaborador, em reparo, pronto para reparar, entregue (histórico). Os estados internos da V1 continuam iguais; não há migração arriscada de OS.
- Fila ordenada por prioridade (-1, 0, +1) e tempo de espera. TV física da oficina acompanha a ordem real. `SetJobPriority` restringe dono da OS/estado Available e proximidade da recepção.
- `ScheduleJob`: **uma** remarcação de 30/60/90 s por OS, depois de chegada física. Enquanto o cliente está agendado, `AcceptJob` é bloqueado; a paciência recebe o mesmo prazo, sem loops infinitos.
- `DiscountJob`: somente **após diagnóstico**, dono presente, sem colaborador/mecânico/sessão de reparo. Calculado do `OriginalPrice` a cada tentativa, não acumula desconto duplo. A parcela/XP final continuam nos procedimentos de V1.
- `RequestJobSupplies`: pedidos apenas de peças realmente ausentes e vinculadas a OS diagnosticada. Pedido salvo em perfil, mostrado no estoque, carregável no carrinho local da loja física, sem pagamento automático, não se perde na reconexão.
- Preço exato/serviço permanecem **ocultos antes do diagnóstico**. Antes: guia de faixa geral do catálogo, não preço específico da ordem. Depois: orçamento exato, custo estimado das peças e **contribuição antes de salários**, sem chamar isso de lucro líquido.
- Dashboard: fila, alertas de impaciência, vagas realmente livres conforme o estado dos boxes, equipe, caixa, unidades de estoque, custo estimado da lista, total bruto dos últimos pedidos. O histórico financeiro v11 não traz todas as despesas; **lucro líquido fica explicitamente indisponível até V2-08**.
- Orientação contextual para a primeira expansão após serviço concluído; eventos anônimos de primeiro upgrade/primeira contratação marcados uma única vez pelo servidor.
- Respostas server-authoritative: a UI só solicita ações, não informa preço ou custo para o servidor. Remotes estão na whitelist, rate-limited pela infraestrutura V1, e verificam ator/proximidade/estado.
- Testes escritos: acesso por proprietário, valores inválidos, dois percentuais de desconto, idempotência de wishlist, estágio/estoque, prioridade, status, valor antes/depois do diagnóstico e migração.

## Procedimento de revisão e aceite externo

1. Antes de merge, comparar branch V2 com o HEAD atualizado da `main` de homologação da V1. Se Claude alterou `DataService`, `WorkshopService`, `Orders` ou `RunAllTests`, integrar manualmente as duas evoluções e repetir CI. **Não fazer force-push** ou sobrescrever trabalho da V1.
2. No place original com backup, importar/conferir os três carros (se já estiverem lá, **não baixar outra vez**), usar `tools/V2AuthorPilotRigs.luau` apenas se fizer sentido autorar os pivôs e executar `tools/V2PilotPlaceAudit.luau` (somente auditoria).
3. Rodar `tools/RunAllTests.luau` no Studio Edit; inclui seis suites V2 e `PersistenceTest` (DataStore simulado).
4. Teste de recepção no Studio: 0/1/3 ordens, cliente chegando, prioridade, agendamento, 5% e 10% de desconto, colaborador, funcionário, compra na loja, desconexão/reconexão, 1/2/4/6 boxes e toque/gamepad.
5. Confirmar licenças, imagens HUD, som e performance; publicação somente por autorização explícita.

**Entrega nesta branch:** código de 00/01/02 disponível para integração, sem mesclagem na `main`. A homologação visual e de Studio está reservada ao proprietário/Claude. **V2-03–16 seguem no Checklist Mestre V2**.
