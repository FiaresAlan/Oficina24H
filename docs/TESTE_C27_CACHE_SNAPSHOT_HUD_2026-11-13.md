# Oficina 24H — V1 C27 | Sincronização do HUD após alterações

**Data:** 13/11/2026 · **Escopo:** cache de estados por jogador no servidor, sem mudanças de assets ou de mecânicas V2.  
**Testes realizados:** contratos estáticos e build Rojo em CI. **Não realizado:** execução da suíte Luau em Roblox Studio, testes visuais e multiplayer.

## Bug comprovado por inspeção

`Main.server.lua` usava dois caches independentes: `snapshotCache` por até 0,4 segundo e `lastSnapshotBuild` por até 0,25 segundo. Ao aceitar uma compra ou ação, o código limpava somente o primeiro. A consulta `GetSnapshot` seguinte podia então devolver o valor antigo guardado em `lastSnapshotBuild`, mesmo com a ação já processada. Isso gerava estado de UI temporariamente obsoleto (moedas, peças, upgrades, ordens e progresso) e criava dois caminhos de expiração para manter.

Algumas ações feitas **por prompts físicos**, em vez do RemoteEvent genérico, também invalidavam somente o cache principal. A compra de upgrade por `EquipmentUpgradePads` não invalidava o snapshot de forma explícita.

## Correção C27

- Criado `src/shared/SnapshotCacheRules.lua`, com **um** cache por usuário e TTL de 0,4 segundo. A função `Invalidate` incrementa a geração e descarta o snapshot; a próxima consulta passa a executar `WorkshopService.GetSnapshot` imediatamente, mesmo menos de 0,25 s após a anterior.
- O resultado só pode ser salvo na mesma geração em que a montagem começou. Se uma ação invalidou o estado ou o usuário saiu durante uma montagem com yield, o snapshot antigo **não volta ao cache**.
- `Main.server.lua` elimina `lastSnapshotBuild`, usa `SnapshotCacheRules.Get` e invalida o estado ao receber ações do jogador, ao interagir com equipamentos/carros/estação, ao comprar upgrades nos pads físicos, nos eventos de avaliação/reparo, nos avisos pessoais de progresso/contratos e ao terminar a sessão do usuário.
- `PlayerRemoving` remove o estado individual por completo. A invalidação de um jogador não modifica o cache de outro.
- A suíte `tools/SnapshotCacheRulesTest.luau` verifica repetição de leitura, expiração, atualização forçada antes de 250 ms, isolamento entre jogadores, mudança durante o build, saída e reconexão. Registrada no `RunAllTests`. `verify_contracts.py` exige módulo, integração e suíte.

## Roteiro de homologação Roblox Studio (a executar)

- [ ] Rodar `tools/RunAllTests.luau` no Studio Edit e comprovar os casos de `SnapshotCacheRulesTest` com resultados reais.
- [ ] Com a loja física, comprar peça via `BuyPart` e `Checkout`: imediatamente após a resposta do servidor, o próximo snapshot deve conter moedas e estoque atualizados.
- [ ] Comprar um upgrade de equipamento entrando em seu pad na oficina: verificar atualização imediata do nível, moedas e painel de upgrades.
- [ ] Aceitar/recusar uma OS e abrir Ordens imediatamente: não deve reaparecer estado antigo de `lastSnapshotBuild`.
- [ ] Concluir serviço e receber avaliação: reputação, estrelas, histórico, XP e saldo devem se atualizar; conferir progressão e notificação.
- [ ] Contratar e demitir mecânico pelo prompt da estação: quantidade, custo e estado apresentados corretamente.
- [ ] Abrir duas contas A e B; fazer compras e reparos em A sem invalidar o snapshot de B (a evolução do ranking compartilhado ainda pode aparecer por expiração de até 400 ms).
- [ ] Sair/reentrar com a mesma conta após compra ou reparo; não deve haver estado do jogador anterior no cache.
- [ ] Verificar spam de `GetSnapshot` e RemoteEvents, em PC e mobile, para confirmar que o TTL reduz processamento sem deixar a interface desatualizada depois de ações.

## Limites e pendências

1. O TTL de 0,4 s permanece para **mudanças assíncronas sem evento de invalidação** (por exemplo, chegada de cliente/NPC). Isso não é garantia de notificação instantânea para todo evento do mundo; a atualização periódica continua necessária.
2. Essa fase não altera DataStore, economia, regras de minijogo ou suas provas financeiras. Não substitui testes de Studio.
3. Os cinco pacotes 3D estão baixados/organizados pelo proprietário, **não importados no place**. É necessário executar `StudioPlaceAudit` após importação. **V2 permanece apenas documental.**

## Próximo alvo V1
Fechar questões concretas de integração/QA com o place real, verificando os 15 serviços e a cadeia de equipamentos/NPCs em multiplayer; não liberar V2 até que os portões de publicação da V1 sejam homologados.
