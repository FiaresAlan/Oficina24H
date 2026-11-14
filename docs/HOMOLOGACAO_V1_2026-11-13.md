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

## 1b. Rodada 2 — place original `Oficina24H_Teste` (13/11, tarde)

O place original foi aberto (placeId 98576673620657). **Backup antes de qualquer mudança:** `backup/Oficina24H_Teste_antes_homologacao_2026-11-13.rbxl` (6,9 MB, fora do git). O código do branch foi sincronizado pelo **Rojo 7.7.1**, só nas pastas de código; mapa, `ServerStorage.Assets`, Lighting e terreno **não foram tocados**. Os módulos de QA temporários foram removidos do place antes de salvar (versão 98 no histórico do Roblox, **nada publicado**).

| Verificação no place original | Resultado |
|---|---|
| `RunAllTests` oficial | **PASSOU: 2029 OK, 0 falhas, 23 avisos** (21 carros sem sockets nativos + 2 lembretes de licença/multiplayer) |
| `StudioPlaceAudit` com assets reais | 17 OK, 0 falhas (1ª execução: **11 falhas**, todas `Eq_*` sem `PrimaryPart`) |
| Inventário `ServerStorage.Assets` | 21 carros, 17 NPCs (R15, 2 gêneros), 11 equipamentos, 50 peças de cenário, 20 props de oficina, 1 oficina: **completo** |
| Saúde do conteúdo (malhas/texturas/sons) | 5.946 verificados no Edit, **1 falha**: malha `1037633864` em `Veiculo_Picape_C1500` ("não aprovada para este solicitante"). É 1 peça de 97 (1,9×0,7×1,9 studs, alto da traseira): **P3 cosmético**, caminhão visível e íntegro |
| Texturas das máquinas em jogo (cliente) | 0 de 20 partes falhando (as mensagens do console no boot eram transitórias) |
| 3 serviços amostrais com carros, NPCs e máquinas reais | **Pneu furado, pastilhas de freio (Macaco) e falha de ignição (Scanner): qualidade 100, 5 estrelas, replay sem pagamento duplo, sem carro órfão** |
| Desempenho com o mapa real (3.622 peças, 86 mil instâncias) | servidor 59,9 Hz (pior 19 ms), cliente 59,9 fps (pior 24 ms) com o Studio em foco; `StreamingEnabled` **desligado** |

**Defeitos novos encontrados e corrigidos no place original**

| Sev. | Defeito | Correção |
|---|---|---|
| P1 (G1) | As 11 máquinas `Eq_*` (do pacote CC0 "Car Repair Garage and MOT Workshop") estavam **sem `PrimaryPart`**: a auditoria C31 reprovava e o jogo caía no pivô implícito | `PrimaryPart` = maior peça de cada modelo; pivô conferido com desvio 0,00000 nas 11 |
| P1 (G2) | O **funcionário NPC tomava a OS enquanto o dono preparava o carro**: depois de 25 s todo prompt de preparo respondia "Um funcionário já assumiu esta ordem" e o trabalho do jogador se perdia (o place de QA não pegou porque o preparo do placeholder acabava a tempo) | `OwnerTouchedAt` na conversa, exame e cada etapa de preparo; `StaffAssignmentRules.OwnerIsWorking` impede o NPC por 25 s; aceitar na TV não conta, então a ajuda imediata com 2 carros continua. `StaffAssignmentTest` 18/18 |

**Sobre os 5 pacotes que você baixou** (`assets/Assets v1 Baixados`): conferi cada pasta do guia contra o place e **nada faltava**, então **não importei nem enviei nenhuma malha à sua conta**. Eles continuam como fonte de recuperação: a máquinas do pacote CC0 já estão no place; o cenário `Cid_*` (CGTrader) e as peças Shuriken também. Reimportar exigiria *upload* para a sua conta, o que eu só faria com sua autorização e sem refazer a rua aprovada.

## 1c. Rodada 3 — G3 com 2 jogadores reais no Studio (servidor + 2 clientes)

Sessão *Servidor e clientes* do Studio com **2 clientes** (Player1 `UserId` −1, Player2 `UserId` −2), cada um endereçado pelo
MCP, DataStore de teste (`_STUDIO`, nunca o de produção) e o mapa/assets reais. **Dono = Player2, contratado = Player1.**
Os ids de teste são negativos e o `RivalService` usa `OwnerUserId = −1` para lotes de rivais; por isso o Player1 nunca foi dono.

| Cenário | Resultado |
|---|---|
| Convite com NaN, infinito, string, a si mesmo, jogador inexistente, duplicado | todos recusados; convite falso/alheio recusado |
| Reparo colaborativo, divisão 30% | **dono +76, contratado +32 = 108** (preço 90 + gorjeta 18); 1 remendo do estoque do dono; **+30 XP só do contratado**; reputação do dono +4; extrato correto de cada lado; nenhum campo privado no snapshot |
| Entrega repetida, token inventado/ausente, reabrir OS concluída, contratado convidando o dono, diagnosticar OS alheia | todos recusados; **saldo idêntico** |
| **Recuperação entre salvamentos (C13) em sessão real** | a OS que travou pelo defeito abaixo foi **paga sozinha no login seguinte** (carência de 600 s vencida): contratado 282 → **314**, XP 30 → **60**, reivindicações 1 → 0; dono **sem pagamento duplo** |
| **E1** contratado sai no meio do reparo | nenhum pagamento nem peça consumida; a OS voltou ao dono, que concluiu sozinho (+108, sem divisão, +1 peça) |
| **E2** dono sai enquanto o contratado repara | contratado recebe "O dono da oficina desconectou" e "ordem colaborativa cancelada"; ao tentar entregar: "Nenhum reparo em andamento"; saldo/XP intactos; carro removido, sem ordem fantasma |
| **Reconexão** (3 vezes) | dono 663 moedas / 458 ganhos / 2 remendos e contratado 314 / 60 XP idênticos ao fim da sessão anterior; 0 reivindicações, 0 ordens em andamento |
| Console do servidor | 0 erros de script, 0 avisos de `DataService`/`WorkshopService` na sessão E2 |

**Defeito encontrado e corrigido (P1 de consistência, só visível com ids negativos):** `WorkerSettlementProofRules.Valid`
exigia `OwnerUserId >= 1`, enquanto `SettlementClaimRules` e `OwnerSettlementProofRules` aceitam −1e15..1e15 (≠ 0). A
reivindicação passava, o dono era pago e salvo, e o crédito do contratado era recusado: ele nunca recebia e o HUD ficava em
"pagamento em processamento". Jogadores reais têm id positivo, então não ocorre em produção, mas os três módulos precisam
concordar e o teste padrão de 2 jogadores do Studio ficava inutilizado. Corrigido; `WorkerSettlementProofRulesTest` 14 → 20,
`PersistenceTest` 232/232.

**Não coberto:** duas instâncias de **servidor** com a mesma conta (o Studio local não cria; a trava de sessão está em
`PersistenceTest`, DataStore simulado com 2 servidores), latência real de rede e o DataStore de **produção**.

## 1d. Rodada 4 — G1 completo no place original (assets, áudio, sprites, sockets)

Licenças **não verificadas por decisão do proprietário** ("já fiz isto"); o resto do G1 foi executado em `Oficina24H_Teste`.

| Verificação | Resultado |
|---|---|
| Inventário contra os manifestos (`pipeline/prop_ids.json` 57 + `city_ids.json` 24) | **81/81 nomes na pasta certa** (`Cenario`, `Equipamentos`, `Oficina`), 0 ausentes, 0 extras fora do manifesto |
| Carros do catálogo | 21/21 em `Veiculos` |
| Pacotes baixados (`assets/Assets v1 Baixados`) | nada faltava no place, **nenhuma malha enviada**; as 11 máquinas vêm do pacote CC0 "Car Repair Garage" e os `Cid_*` da cidade CGTrader |
| **Áudio** (`SoundIds`) | **16/16 carregam** (7 efeitos, 3 ambientes, 6 músicas), durações reais de 1,7 s a 200 s |
| Áudio em jogo (escutador no cliente durante atendimentos completos) | **todos os 16 ouvidos na hora certa**: motor ao estacionar, elevador e catraca no preparo/reparo, faíscas e zumbido no defeito elétrico, **Hiss só depois do diagnóstico de motor**, **AirWrench só no reparo de pneu**, 3 ambientes e música (vol. 0,18) |
| **Sprites do HUD** (`HudAssets`) | **69/69 carregam** |
| Conteúdo dos carros e máquinas no cliente em jogo | 3.923 + 124 conteúdos, **0 falhas** |
| **Sockets dos 21 carros** (aviso "sem sockets nativos") | o jogo usa deslocamentos pelas dimensões; conferi cada carro: **dimensões declaradas = geometria real (0% de erro) em todos, centrados na `Raiz`, e os 14 pontos (9 de inspeção + 5 de preparo) caem a ≤ 0,6 stud da carroceria**. Sockets nativos continuam opcionais |
| Peça quebrada do `Veiculo_Picape_C1500` | malha `1037633864` ("não aprovada para este solicitante", 1 de 97 peças, bloco cinza do cofre do motor) trocada por um bloco liso de mesmo tamanho, cor, material e posição, com a solda religada, na cópia de `ServerStorage` e na do bairro. Sem upload. Marcada com o atributo `SubstituiMesh` |
| `RunAllTests` depois da troca | **PASSOU: 2035 OK, 0 falhas** |

**Observação de comportamento (não é defeito, C17):** com 2 carros esperando, o mecânico NPC assume o carro novo assim que ele estaciona, antes de o dono falar com o cliente (a regra "ajuda imediata com 2 carros"). A proteção `OwnerTouchedAt` só vale depois do primeiro toque do dono.

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
| **G1 Assets** | **Homologado no place original** | Inventário 81/81, áudio 16/16 em jogo, sprites 69/69, sockets/pontos dos 21 carros OK, peça do C1500 resolvida. Licenças fora do escopo a pedido do proprietário |
| **G2 Atendimento** | **Homologado no place original (amostra)** | `RunAllTests` 2029/0 e 3 serviços reais OK; os 15 já passaram no place de QA. Opcional: repetir os 12 restantes com modelos reais |
| **G3 Multiplayer/DataStore** | **Homologado com 2 clientes reais no Studio** | Faltam só 2 servidores simultâneos com a mesma conta, latência real e o DataStore de produção (não testável localmente) |
| **G4 UX/Desempenho** | **HUD no simulador + 59,9 fps no mapa real**; aberto em aparelho físico | Celular e gamepad físicos, memória do servidor (~3,8 GB no Studio), `StreamingEnabled` |
| **G5 Publicação** | **Aberto** | Segurança revisada e corrigida (sem P0); faltam licenças (sprites do HUD, esportivo, CC BY), privacidade e a **sua decisão** de publicar |

**Conclusão honesta:** a V1 **ainda não está pronta para publicação**. G1, G2 e G3 estão homologados no Studio;
sobram G4 em aparelho físico e a **sua** decisão de publicar (licenças: confirmadas por você, não verifiquei).

## 8. O que você precisa fazer (passo a passo)

1. ~~Abrir o place original e fazer backup~~ — **feito na rodada 2**. Opcional: me avisar para repetir os 12 serviços
   restantes com os modelos reais.
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
