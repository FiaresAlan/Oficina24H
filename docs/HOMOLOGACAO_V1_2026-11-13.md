# Oficina 24H — Homologação V1 no Roblox Studio (rodada 1)

**Data:** 13/11/2026 · **Branch:** `work/oficina24h-v1-homologacao-2026-11-13` · **Base:** `main` `2690f08` (C31)
**Escopo:** somente V1. Nenhuma mecânica V2 implementada. Nada publicado, nenhum upload de asset, nenhum dado
persistido apagado.

## 1. Onde os testes rodaram (leia antes dos números)

| Ambiente | Situação |
|---|---|
| **Place original** `Oficina24H_Teste` (placeId 98576673620657, salvo na nuvem) | **Não foi aberto nesta rodada.** O acesso de controle de tela ao Studio foi negado e o place da nuvem só abre pelo Studio. Nenhuma alteração foi feita nele, então não houve backup a fazer. |
| **Place de QA só com código** (`rojo build` → `O24_codeonly_QA.rbxlx`, pasta temporária da sessão) | Todos os testes desta rodada. Paridade conferida: **144/144 scripts idênticos ao repositório**, nenhum script extra. Mundo montado com `tools/BuildWorld.luau` (6 lotes, loja, construtora). **21 carros e 6 clientes R15 são PLACEHOLDERS** (caixas e rig padrão, atributo `QA_Placeholder`) que cumprem as regras da C31. |

Consequência: tudo abaixo prova o **código** da V1 rodando de verdade no motor do Roblox (servidor + cliente, remotes,
física, ProximityPrompts, HUD). **Não prova** os modelos reais, o mapa real, a cidade, o áudio nem o DataStore publicado.

## 2. Suítes automáticas

| Execução | Resultado |
|---|---|
| `RunAllTests` oficial (Edit, place de QA com mundo e placeholders) | **PASSOU — 2014 verificações OK, 0 falhas, 24 avisos** (61 s) |
| `StudioPlaceAudit` (dentro do RunAllTests) | 17 OK, 0 falhas. Avisos esperados: 21 carros sem sockets nativos (placeholders), 11 equipamentos ausentes (fallback procedural), revisão manual de licenças, homologação multiplayer/celular/DataStore |
| Primeira execução real das suítes (antes das correções) | 1593 OK / 60 falhas. As falhas reais estão na seção 4; as demais vinham de assets ausentes no place só de código |
| `tools/ci/verify_contracts.py` | 231/231 (eram 227; +4 contratos novos) |
| CI GitHub do branch | [verde](https://github.com/FiaresAlan/Oficina24H/actions/runs/43495459717) |
| selene (std roblox) | 0 erros |
| luau-lsp estrito | 21 avisos de tipagem, os mesmos de antes (inferência de `string?`/gradientes em painéis), sem efeito em runtime: dívida técnica, não bloqueio |

## 3. Atendimento completo dos 15 serviços (G2) — Play real, remotes do HUD

Cada OS foi jogada pelo cliente com os **mesmos remotes do HUD** (`qa/drive_job.luau`): aceite na TV de ordens →
carro estaciona → conversa com o NPC → 9 exames nos pontos físicos → diagnóstico → preparo físico (ProximityPrompts) →
reparo no carro ou na máquina (≤ 12 studs) → comandos com revisão/ACK → entrega → avaliação → saída. O defeito de cada OS
foi forçado pelo comando de QA `ForceJob` (só existe no Studio).

| # | Defeito | Máquina | Qualidade | Estrelas | Replay do `FinishRepair` |
|---|---|---|---|---|---|
| 1 | Bateria fraca | Kit básico | 100 | 5 | sem pagamento duplo |
| 2 | Pneu furado | Kit básico | 100 | 5 (4 no 1º teste manual) | sem pagamento duplo |
| 3 | Superaquecimento | Kit básico | 100 | 5 | sem pagamento duplo |
| 4 | Amassado | Kit básico | 100 | 5 | sem pagamento duplo |
| 5 | Pastilhas de freio | Macaco | 100 | 5 | sem pagamento duplo |
| 6 | Pneu gasto | Desmontadora | 100 | 5 | sem pagamento duplo |
| 7 | Suspensão solta | Macaco | 100 | 5 | sem pagamento duplo |
| 8 | Balanceamento | Balanceadora | 100 | 5 | sem pagamento duplo |
| 9 | Alinhamento | Alinhamento | 100 | 5 | sem pagamento duplo |
| 10 | Falha de ignição | Scanner | 100 | 4 | sem pagamento duplo |
| 11 | Colisão na carroceria | Kit de funilaria | 100 | 4 | sem pagamento duplo |
| 12 | Braço de suspensão | Elevador | 100 | 5 | sem pagamento duplo |
| 13 | Pane elétrica | Bancada elétrica | 100 | 5 | sem pagamento duplo |
| 14 | Pintura | Compressor | 100 | 5 | sem pagamento duplo |
| 15 | Retífica de motor | Bancada de motor | 100 | 5 | sem pagamento duplo |

Depois dos 15 atendimentos: **0 carros/NPCs órfãos** em `Workspace.Vehicles`, **0 erros de script** no console.
Economia conferida no 1º atendimento manual: 250 + 108 (serviço + gorjeta) + 40 (bônus do 1º serviço) + 50 (conquista)
= 448 moedas; 1 `TirePatch` consumido; +30 XP em `Tires`. Compras: 10 máquinas e 14 peças na loja física, 24/24 aceitas.

**Ataques executados no servidor real (todos recusados):** exame longe do ponto, exame com ID de 3000 caracteres,
diagnóstico com opção inexistente, revisão de comando repetida (devolve o mesmo ACK sem reaplicar), pressão fora do
passo, pressão `NaN`, `FinishRepair` repetido (devolve o comprovante, sem novo crédito).

## 4. Defeitos encontrados e corrigidos

| Sev. | Defeito | Correção | Verificação |
|---|---|---|---|
| P1 | Gabaritos dos minijogos (ordem das etapas, circuito correto, alvos de funilaria, sequência da bateria) ficavam em `ReplicatedStorage`: um exploit podia ler e automatizar qualidade 100 | `WorkshopProcedures` e `RepairOperations` movidos para `ServerScriptService.Server`; contrato de CI impede voltar para `shared` ou ser exigido pelo cliente | 4 suítes + 15 serviços ao vivo |
| P2 | `RepairAction` sem limite por jogador e ecoando strings do cliente; `GetSnapshot` podia forçar remontagens em laço | `RequestBudgetRules`: 30 ações/s e 8 montagens/s; eco só de strings ≤ 64 e números finitos | `RequestBudgetRulesTest` 14/14 |
| P2 | Checagem de distância da TV/prateleira pulada se o lote não tivesse `Estacoes` | Falha fechada; ausência só tolerada no Studio (igual à loja) | AcceptJob ao vivo |
| P2 | Studio com acesso às APIs desligado expulsava o testador | Cai para modo memória (avisado) só no Studio | código + suíte de persistência |
| P2 | Cache de amizades crescia por toda a vida do servidor | Limpo ao sair | revisão |
| P2 | Borda exata da loja recusada por erro de float | Tolerância de 0,001 stud | `LocationTest` 11/11 |
| G4 | Letreiros "MELHORAR … PISE AQUI" dos pads (C16) sobrepostos e ilegíveis com várias máquinas | Tamanho em studs (5,4×2,2) e alcance de 35 studs | captura antes/depois |
| G4 | Painel METAS abria sozinho por cima do guia do 1º atendimento e cobria a tela do celular | Abre só depois que o guia termina | iPhone 14 |
| G4 | "X" do METAS (~21 px) e "Pular guia" (34 px) abaixo de 44 px no celular | Alvo efetivo ≥ 44 px mesmo com UIScale | medição em Play |
| G4 | 568×320: guia com 671 px numa tela de 566 (botão cortado) | Empilha em coluna acima do dock | medição em Play |
| G4 | 1920×1080 (PC/Xbox): guia invadia o painel "Clientes aguardando" | Centraliza no espaço livre e começa abaixo dos cartões do topo | medição em Play |
| Teste | `PersistenceTest` usava `"Freios"` como especialização: os blocos C12–C25 de reivindicação nunca rodavam | `Suspension` (especialização real do freio) | 232/232 |
| Teste | C20 dependia de tarefas de fundo; C22 contradizia a C23; `CompactHudTest` sem `Id` | Asserções corrigidas mantendo a intenção | 232/232 e 15/15 |

Auditoria independente de segurança (agente `roblox-dev:roblox-reviewer`, somente leitura): **nenhum P0**. Nenhum
caminho duplica moedas, peças ou XP e nenhum valor do cliente chega ao saldo. Sobram 2 P2 aceitos: o ramo legado do
minijogo de timing é inalcançável hoje (os 15 defeitos têm procedimento próprio), e um Save final que falha mantém a
trava de sessão até o timeout de 360 s (sem perda além do último autosave).

## 5. HUD por dispositivo (G4) — Play com simulador do Studio

O jogo é **somente paisagem** (`StarterGui.ScreenOrientation = LandscapeSensor`). As metas "390×844" e "320×568" do
portão viram 844×390 e 568×320 no aparelho.

| Dispositivo | Viewport | Resultado após correções |
|---|---|---|
| iPhone 14 (844×390) | 749×388 | Nenhum elemento fora da tela, nenhuma sobreposição; "Pular guia" 124×45 px |
| Samsung Galaxy A06 (800×360) | 705×338 | Nenhum elemento fora da tela; alvos ≥ 40 px |
| Personalizado 568×320 | 566×297 | Nada fora da tela; guia em coluna acima do dock; **cobre os cartões de status enquanto o guia está ativo (P3 aceito)** |
| Xbox One (1920×1080) | 1919×1079 | Nenhuma sobreposição; textos ≥ 14 px; 60 botões selecionáveis. Cartões a < 5 % da borda (área segura de TV) — **aviso** |

**Não testável pelo simulador:** gamepad real (o simulador mantém `GamepadEnabled = false`), toque real e aparelho físico.

## 6. Desempenho (G4) — indicativo

Place de QA com 6 clientes chegando ao mesmo tempo: servidor 59,9 Hz (pior quadro 21 ms), cliente 59,9 fps (pior
quadro 19 ms), 862 peças no Workspace. **Não representa o place real** (cidade CGTrader, bairro, assets).
`StreamingEnabled` está desligado no place de QA; o valor do place real precisa ser conferido.

## 7. Situação dos portões

| Portão | Situação | O que falta |
|---|---|---|
| **G1 Assets** | **Aberto** | Abrir o place original; rodar `StudioPlaceAudit` com os 21 carros/NPCs reais; importar os 5 pacotes baixados (envolve upload de malhas para a sua conta Roblox → **precisa da sua autorização**); conferir licenças e áudio |
| **G2 Atendimento** | **Código homologado no place de QA**; aberto no place real | Repetir `RunAllTests` e 3 serviços amostrais no place original (modelos reais podem mudar sockets, pivôs e colisão) |
| **G3 Multiplayer/DataStore** | **Aberto** | Exige 2 contas/clientes e DataStore de homologação (roteiro na seção 8). A lógica de dados passou 232/232 com DataStore simulado e falhas injetadas |
| **G4 UX/Desempenho** | **HUD homologado no simulador**; aberto em aparelho real | Celular físico, gamepad físico, FPS/memória no place real, StreamingEnabled |
| **G5 Publicação** | **Aberto** | Segurança revisada e corrigida (sem P0); faltam licenças (sprites do HUD, esportivo, CC BY), privacidade e a **sua decisão** de publicar |

**Conclusão honesta:** a V1 **não está pronta para publicação**. O código passou em tudo que dá para executar sem o
place real e sem uma segunda conta. Os bloqueios restantes exigem o place original, duas contas e a sua autorização.

## 8. O que você precisa fazer (passo a passo)

1. **Abrir o place original** no Roblox Studio: *File → Open from Roblox* → `Oficina24H_Teste`. Antes de qualquer
   mudança: *File → Save to File As…* → `Documents\Oficina24H-v2\backup\Oficina24H_Teste_antes_homologacao_2026-11-13.rbxl`
   (a pasta de backup fica fora do git). Avise no chat: eu confiro pelo MCP, sincronizo o código do branch (o
   `qa/sync.luau` nunca apaga nada; os dois módulos movidos da C-homolog eu apago à mão, com sua confirmação) e rodo
   `RunAllTests` + `StudioPlaceAudit` + 3 serviços com os modelos reais.
2. **DataStore de homologação:** *Game Settings → Security → Enable Studio Access to API Services* (o código usa a chave
   `_STUDIO`, nunca a de produção).
3. **Dois jogadores (G3):** *Test → Clients and Servers → 2 Players → Start*. Roteiro: jogador A convida B para uma OS
   (divisão 30 %), B repara, A sai no meio do reparo, B sai durante o salvamento; reentrar com os dois e conferir saldo,
   XP, peças e extrato (Ordens → Concluídas). Registre prints do extrato antes e depois.
4. **Aparelho real (G4):** publicar numa experiência **privada de teste** (não na pública) só com sua autorização, abrir
   no celular e no console/gamepad e jogar o 1º atendimento.
5. **Licenças (G5):** confirmar os direitos dos sprites do HUD (`assets/hud_sprites`), do esportivo `Veiculo_VIP_Corvette`
   e créditos CC BY dos pacotes (veja `docs/ORIGEM_ASSETS.md`).

## 9. Evidências

- Saídas completas de `RunAllTests`, `drive_job` (15 serviços) e medições de HUD: registradas nesta rodada (resumo acima).
- Capturas locais (não versionadas porque mostram sprites do HUD com licença a confirmar): `qa/evidencias/` —
  pads antes/depois, iPhone 14 antes/depois, Galaxy A06, Xbox antes.
- Harness reutilizável: `qa/README.md`.
