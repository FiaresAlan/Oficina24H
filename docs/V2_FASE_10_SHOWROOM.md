# Oficina24H — V2-10 | Personalização comercial, coleção e showroom

**Branch:** `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13` · **PR:** #27 · **Data:** 13/11/2026.  
**Estado:** engenharia integrada na branch, regressões e build Rojo em CI. Roblox Studio, jogos reais e QA de dispositivos ainda **não** foram executados nesta rodada. A `main` segue reservada para V1.

## Objetivo

Dar ao jogador uma razão **secundária** para restaurar e colecionar veículos, preservando a prioridade das ordens de serviço (OS). Um carro pode estar na área de restauração V2-09 e **dois** carros concluídos podem ser exibidos no showroom. Nenhum ocupa `BayN`, toma equipamento de OS, usa física de corrida ou paga como reparo de cliente. O sistema é intencionalmente finito, sem investimento que gere moeda automaticamente.

## Personalização transparente, com prévia não cobrada

A interface existente `Ordens > Caixa` exibe custos, pequeno bônus de revenda e **duas câmeras locais** antes/depois para o mesmo modelo 3D real ou fallback. `PRÉVIA` só altera estado da interface; `CANCELAR PRÉVIA` restaura visualmente o original, sem RemoteEvent e sem cobrança. `CONFIRMAR PERSONALIZAÇÃO` envia **uma** ação ao servidor, que recalcula o custo. Apenas veículos restaurados podem receber uma opção por categoria, sem cobrança repetida, troca infinita ou valores enviados pelo cliente.

| Categoria | Escolhas e custo | Acréscimo máximo de revenda |
|---|---|---:|
| Pintura | Azul metálico 40; Vermelho rubi 40; Grafite 50 | +30/+30/+35 |
| Acabamento | Brilhante 45; Fosco 55 | +25/+30 |
| Rodas | Esportivas 75; Clássicas 60 | +40/+30 |

Toda opção **custa mais do que aumenta o valor de revenda**. Personalizações visuais não conferem mais XP, bônus de OS, classificação instantânea de cliente ou aumento ilimitado de renda. A pintura Azul/Vermelho da V2-09 mantém seus valores antigos e o campo persistente `Style`; `Finish` e `Wheels` são campos adicionados de forma compatível no mesmo perfil v15.

## Coleção e reputação limitadas

- `Showcase`: após `Restored`, move o veículo da área de preparação para `Showroom` (até 2), sem cobrar ou conceder receita. Na **primeira exposição histórica de cada variante** Hatch/Sedã/Picape, concede +1 de reputação ao proprietário, até +3 no total.
- `Recall`: tira o carro do showroom, sem cobrança nem prêmio; exige que o único slot de restauração esteja livre. Mantém UID e aparência.
- `SellExhibit`: vende diretamente um dos dois veículos expostos, calcula preço e contribuição pelo servidor, remove UID, aumenta contador de vendas, lança crédito em `Market` e inicia cooldown de 600 s para novas compras.
- `Sell` V2-09 continua válido para o carro ativo; `Scrap` continua permitido somente antes da restauração. Um mesmo UID não aparece em ambos os estoques.
- `ShowroomSeen` guarda as três variantes já recompensadas. Reentrar, retirar, revender e recomprar **não** reativa o bônus. O marcador e a reputação são atualizados no **mesmo perfil**, sem `yield`.

A reputação ganho é **pontual**, não uma mecânica de satisfação permanente. Ratings reais ainda pertencem somente aos clientes e serviços concluídos; nenhum VIP é garantido pela exposição.

## Exposição física e performance

`src/server/V2UsedMarketDisplay.lua` mantém a exibição ativa em local lateral frontal x=31, z=-16 e o showroom em duas posições independentes x=-32/z=-36 e x=31/z=-36, no referencial do lote. São clones **ancorados, sem colisão, toque nem consulta**, sem script de modelo externo, sem network ownership, sem mudança nos veículos reais da V1. A vitrine se atualiza após ação do proprietário, carrega no `ClaimWorkshop` e é removida no `PlayerLeft`. Prompts da exposição permitem **retirar** o carro; os botões de venda ficam no painel.

`V2ShowroomVisual` classifica corpo, aros, pneus, vidro e partes ignoradas; aplica cor, reflexo/material e desgaste somente aos **clones**. `V2ShowroomPreview` reutiliza as mesmas regras, prevenindo diferenças artificiais entre a prévia e o carro exposto. Fallback procedural mantém a experiência legível quando o asset estiver ausente. Modelos com `SurfaceAppearance`/texturas PBR específicas podem exigir ajustes dos materiais/atributos `V2CosmeticRole` para que o tingimento seja visualmente fiel — **validar os três carros no Studio**.

## Contratos financeiros, persistência e privacidade

Apenas `WorkshopService.UsedMarketAction` autoriza ação de venda/compra via remoto já limitado por jogador; exige presença na loja para comprar e presença no lote próprio para modificar, mostrar, retirar ou vender. `DataService.TradeUsedCar` calcula débito/crédito e marca de reputação, aplicando alterações no mesmo perfil sem `yield`. Não há remoto para prévia nem ação de dinheiro no cliente. `UsedMarket` bruto permanece privado; o snapshot `UsedMarket.Public` entrega somente opções permitidas, preços, slots, estado visual e carros próprios.

Os campos `Showroom`, `ShowroomSeen`, `Finish` e `Wheels` são **aditivos dentro do schema v15** da V2-09, normalizados mesmo em perfis v14/15 legados sem esses campos. Não altera `RepairLedger`, claims, provas de pagamentos nem `FinanceLedger`. `TotalContribution` continua sendo contribuição **estimada usando peças ao custo de tabela**, não lucro contábil/competência de estoque.

## Testes e gate real

- `tools/V2ShowroomRulesTest.luau`: preços, opções falsas, prévia sem mutação, limites, 3 variantes, reputação histórica, UID, venda e replay.
- `tools/V2ShowroomVisualTest.luau`: não mutar asset original, corpo/aros/vidro/pneu, tintura, fosco e brilhante.
- `tools/V2ShowroomDisplayTest.luau`: 1 carro ativo + 2 expostos em lote temporário, segurança de colisão, scripts, prompts, posições, limpeza e ressíncronia.
- `tools/PersistenceTest.luau`: compra, três personalizações, duplicidade rejeitada, exposição +1 reputação, reentradas, retirar/reexibir sem prêmio, vender exibido e impossibilidade de replay após Save/Load.
- `tools/RunAllTests.luau` registra as suites; `tools/ci/verify_contracts.py` valida os contratos estáticos; GitHub Actions compila o Rojo code-only, **mas não executa o Luau no Roblox Studio**.

**QA Roblox Studio obrigatório:** importar/validar Hatch, Sedã e Picape; verificar todas as cores, aros e materiais reais; preview/cancelamento e preço; alterações salvas no DataStore; lotes em todas as orientações da rua; entrada de 2 jogadores, vizinho acionando prompts, relog após colocar 2 carros e antes da venda; mobile/gamepad e desempenho com 6 lotes ocupados; 15 serviços simultâneos preservados; limite +3 de reputação sem replay. Confirmar que os carros decorativos não interceptam a rota de entrada, equipamentos ou anexo e que a UI continua legível. Só após os testes pode ser marcada a fase como homologada.

**Itens fora desta fase:** condução de OS (V2-11), testes de direção (V2-12/13), materiais PBR faltantes, arquivos 3D não importados, lotes de fornecedores Econômico/Padrão/Premium pendentes V2-08 e integração com `main` condicionada ao QA V1 do Claude.
