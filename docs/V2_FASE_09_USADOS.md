# Oficina24H — V2-09 | Compra, restauração e revenda de usados

**Engenharia:** branch `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13` · PR #27 · 13/11/2026.
**Status:** mecanismo transacional e interface codificados, regressões registradas. **Roblox Studio, rigs 3D reais, mobile e aceitação econômica ainda NÃO homologados.** A `main` permanece reservada para QA V1.

## Objetivo de produto

Mercado de veículos de revenda é atividade **secundária** à oficina de OS. O dono só pode negociar após três serviços de clientes e a primeira ampliação do prédio. Um único carro próprio pode estar em processo de restauração, **sem ocupar a vaga física nem alterar a fila das OS de clientes**. A próxima compra aguarda 10 minutos depois de revenda ou sucateamento; o mercado não concede XP, reputação, avaliações ou bônus de OS.

## Experiência implementada

A aba `Ordens > Caixa` tem seção de mercado com miniaturas 3D dos modelos já publicados em `VehiclePreviews` (ou fallback sem miniatura quando asset indisponível), três ofertas e estimativas **antes** da compra. Comprar exige estar na Loja de Autopeças; inspeção, desmontagem, reparo, pintura e venda exigem estar no lote próprio. Interface existente reutilizada, sem overlay escuro ou botão adicional na HUD.

Três variantes de preço fixo definido no **servidor**:

| Oferta | Compra | Revisão | Peças de tabela | Risco adicional | Revenda restaurado | Contribuição prévia estimada |
|---|---:|---:|---|---:|---:|---:|
| Hatch de leilão | 260 | 35 | 1 remendo (10) | 0–20 | 370 | +45 a +65 |
| Sedã sinistrado | 500 | 85 | 1 bateria + 2 velas (85) | 0–40 | 730 | +20 a +60 |
| Picape de frota | 800 | 130 | 2 pastilhas + 1 kit de suspensão (85) | 0–70 | 1090 | +5 a +75 |

O custo oculto de risco é sorteado pelo servidor na aquisição e exibido ao proprietário após a compra. Etapas obrigatórias de negócio: `Purchased → Inspected → Stripped → Restored → Sell`. Em qualquer etapa anterior a `Restored`, pode desistir, vender sucata por valor abaixo da compra e liberar o único slot. A pintura opcional custa 40 moedas e só aumenta o preço de venda em 30: não é uma exploração de dinheiro infinito.

**Limite explícito:** inspeção, desmontagem e reforma são sequências por interface (com controle de presença do jogador), **não** representam ainda montagem/desmontagem física em carro de revenda na cena. Pré-visualização 3D não prova funcionalidade no Studio. V2-10 prevê showroom e apresentação visual dedicada; não atribuir trabalho visual inexistente a V2-09.

## Segurança, dinheiro e persistência

- `V2UsedMarketRules` contém catálogo único, saneamento de estado e máquina de etapas. RemoteEvent envia **somente** `Operation`, `Id` e `Style`; preço, UID, risco e estado são definidos/validados no servidor.
- `DataService.TradeUsedCar` aplica peças, saldo e mudança de fase **sem yield** dentro do mesmo perfil. `Save` persiste todos conjuntamente. Replay de venda não reencontra o mesmo UID em `Owned`; replay de compra encontra a capacidade ocupada ou cooldown. Dados inválidos não podem criar modelos ou ganhos extras.
- Schema persistente `v15` é **aditivo** ao v14: campo `UsedMarket` com um veículo, timestamp da próxima compra e agregados. `FinanceLedger` e comprovantes/claims V1 continuam inalterados.
- O grupo de caixa `Market` separa compra, custos, pintura e revenda de `Service` (receita de OS). O total de contribuição exibido é **estimado**, pois peças legadas não têm custo histórico por lote; não equivale a lucro contábil.
- Um carro de revenda não chama `VehicleService.Spawn`, `CompleteJob`, `CreditRepairOnce` nem envolve vagas, funcionários, NPCs ou pagamentos de ordens.

## Verificações de código e critérios de QA

`tools/V2UsedMarketRulesTest.luau` cobre as três ofertas, saldo, limite de slots, requisitos, riscos inválidos, UID, replay, peça ausente, ordem de etapas, pintura, sucata, cooldown, dados corrompidos, JSON round-trip e categoria financeira. `tools/PersistenceTest.luau` exercita compra, progressão, consumo, venda, dois ciclos de relog e persistência de caixa/UID usando DataStore fake. `tools/RunAllTests.luau` registra o conjunto e o CI verifica contratos estáticos e build Rojo.

**Portão Studio obrigatório antes de homologar:** entrar com conta antiga v14 e conta nova v15; OS 1–3, upgrade nível 1, comprar Hatch/Sedã/Picape; fechar UI, desconectar após compra/etapa/saída, repetir os remotes, 2 jogadores simultâneos, stock insuficiente, dinheiro insuficiente, invadir lote de vizinho, tentativa fora da loja, mobile/gamepad; reentrar após cooldown; verificar financeiro sem duplicação, visuais dos três carros, isolamento da OS e fluxo normal de 15 serviços. Fazer playtest econômico comparando tempo/recompensa por OS vs. revenda. A decisão de manter ou cortar V2-09 permanece com o proprietário após testes reais.

## Pendência anterior V2-08

Lotes de fornecedores Econômico/Padrão/Premium com custo histórico e influência na confiabilidade **não** foram modificados nesta fase. Esse requisito precisa de contabilidade FIFO, consumo de lote em todas as rotas V1, migração e rollback antes de ser ligado ao gameplay. Não considerar V2-08 totalmente homologada nem mascarar a ausência de custo de aquisição legado.
