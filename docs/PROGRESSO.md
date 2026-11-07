# Progresso — Oficina 24H

Atualizado: 2026-11-05

## Ambiente
- Roblox Studio com MCP (`roblox-studio`) e Blender 5.4 alpha com MCP (`blender`) conectados via `.mcp.json`.
- Rojo 7.7.1 fixado em `rokit.toml`. `rojo serve default.project.json` + plugin no Studio (porta 34872).
- Place de trabalho: `C:\Users\Administrador\Downloads\Oficina24H_Teste.rbxlx` (local; nada publicado).

## Auditoria do código existente (Etapa 1)
Funciona/esqueleto: DataService (DataStore load/save/autosave/BindToClose), WorkshopService (ordens, diagnóstico,
conclusão, compra de equipamento, convite, NPC), Catalog (5 especializações, 6 defeitos/serviços, 7 equipamentos),
Main.server (remotes com rate limit 0.25s), Main.client (UI de teste).

Lacunas identificadas (a tratar nas etapas seguintes):
- Oficinas/ordens/equipamentos não persistem (só moedas, reputação, XP).
- Sem terrenos físicos, veículos 3D, validação de distância.
- Save usa UpdateAsync sem retry nem session lock; sem schema versionado além de v1.
- Convite aceito não faz contraproposta; funcionário sem acesso restrito por ordem no mundo.
- Reclamação sempre igual ao defeito real (requisito pede diagnóstico que pode divergir).
- Sem histórico de transações, ranking, concorrência entre oficinas.

## Assets
- Bairro: 129 GLB no total (Shuriken Town Streets, Kenney Industrial, Polyfork Garage, Grab3D Warehouse).
- Oficina: garage kit CC0 (54 módulos + cena) e 3 veículos Grab3D CC0.
- Licenças: ver `Oficina24H_Bairro_GLBS/ASSETS_E_LICENCAS.md` e `Oficina24H_GLB_Starter/fontes_e_licencas.txt`.
  Polyfork: licença Polyfork ou CC BY 4.0 (conferir antes de publicar). Shuriken: licença gratuita do autor.

## Importação de GLB (método descoberto)
- Não há API Luau para importar GLB. Método que funciona: botão Importar (aba Início) > diálogo de arquivo > Importar.
  O Studio sobe as malhas para a conta do criador (opção "Fazer o upload para a Roblox"). Rojo não sincroniza esses modelos.
- No diálogo de arquivo só é possível digitar no campo "Nome"; seleção múltipla com shift+clique funciona.
- Importados e salvos em `ServerStorage.Assets`: `Oficinas.Garagem_Polyfork` (12x7,2x8 studs),
  `Veiculos.Veiculo_Compacto/Hatch/Sedan` (~1,8x1,5x4 studs; precisam de escala ~3,5x). A atribuição de nomes aos três
  carros foi feita pela ordem de importação/comprimento e deve ser conferida visualmente.
- O place está vazio de iluminação/chão; o modelo da garagem aparece escuro até configurar Lighting.

## Status
- [x] Etapa 1 — auditoria; Rojo sincronizado com o Studio (5 scripts confirmados no DataModel)
- [~] Etapa 2 — 4 de 129 GLB importados (garagem Polyfork + 3 carros). Faltam kit de oficina (54), ruas, industrial.
- [ ] Etapas 3 a 9

## Mundo (Etapa 3, parcial)
- `tools/BuildWorld.luau` (sincronizado por Rojo em `ServerStorage.Tools`) gera: iluminação, chão, rua principal,
  rua secundária, calçadas, `Workspace.Plots.Plot1..6` (Base, Entry, Bay1/2, ExpansionZone, Spawn, Sign; atributos
  PlotId/OwnerUserId/Side), loja de autopeças, distribuidora e estacionamento (blocos simples, sem modelos ainda).
- Rodar no Edit: clonar o módulo e dar `require` no clone (um require que falhou fica em cache no módulo original).
- Plot1 tem a garagem Polyfork escalada 3,5x (42x25x28 studs). Os plots 2 a 6 ainda estão sem edifício.
- A garagem importada está escura; revisar materiais/cores. A orientação da fachada precisa ser verificada.
- Rojo: ao mudar `default.project.json` é preciso reiniciar `rojo serve` e reconectar o plugin no Studio.

## PlotService (Etapa 6, parcial)
- `src/server/PlotService.lua`: Assign/Release/GetPlot/IsInsidePlot; atribuição síncrona (sem corrida); placa e spawn
  por dono; limpa donos ao iniciar. Integrado ao `WorkshopService.ClaimWorkshop` e ao `Main.server`.
- Testado em Play com 1 jogador: recebeu o Plot1, placa "OFICINA DE FALCONREV", teleporte ao spawn do lote, RespawnLocation ok.
- NÃO testado: 2+ jogadores simultâneos, liberação ao sair e reatribuição, lotes lotados (7º jogador).
- Terreno ainda não é recuperado como o mesmo número após reconexão (não persiste PlotId).

## VehicleService (Etapa 4, parcial)
- `src/server/VehicleService.lua`: ao aceitar uma ordem, clona o carro (escala 3,5x), centraliza pelo bounding box e o
  coloca numa vaga livre (`BayN`) do lote; reserva por atributo `JobId`; ao concluir, libera a vaga e o carro sai (tween).
  Capacidade = nº de vagas (2 por lote). Dono saindo devolve ordens a `Available` e remove os carros.
- Testado em Play, via RemoteEvents reais (cliente -> servidor), 1 jogador: oficina, 3 clientes, aceite de 2 (3ª recusada
  por falta de vaga), conclusão sem diagnóstico recusada, diagnóstico, conclusão (+120 moedas, +30 XP, +2 rep),
  vaga liberada, carro posicionado com a base no piso (y=1,00).
- Limitações: não há picape nos assets (usa o compacto); veículos sem componentes removíveis; sem interação física
  (diagnóstico/reparo ainda por UI de teste); nomes dos 3 carros por ordem de importação.
- Nota de teste: `require` em execute_luau (Server) cria cópia separada dos módulos; testar pelos remotes (Client).

## Sessão autônoma (usuário ausente ~3 h) — resumo
- Plano: `docs/PLANO_DESENVOLVIMENTO.md` (roadmap, riscos, dependências do usuário).
- Testes automáticos (Edit via MCP, `tools/RunAllTests.luau`): CatalogTest 177, PlotTest 27 (jogadores simulados: 6 lotes,
  7º recusado, liberar/reaproveitar, sem dono duplicado), PersistenceTest 27 — todos aprovados.
- Novo: `EquipmentService` + `EquipmentModels` (11 equipamentos construídos em Parts, posicionados em slots do lote, com
  animação de compra, removidos ao liberar o lote); registro automático da oficina quando os dados carregam; `DeclineJob`
  (recusar/abandonar, -1 rep) e paciência do cliente (300 s); reclamação divergente do defeito real (35%);
  catálogo expandido para 15 defeitos/serviços (Funilaria agora tem serviços) e 11 equipamentos.
- Correções por revisão: colaborador duplicado sobrescrevia o primeiro; colaborador que saía prendia a ordem; convites
  nunca eram limpos; oficina guardava tabela de perfil antigo após sair/entrar (`Workshops[userId]` agora é limpo).
- Testes de abuso (Play): 18 payloads inválidos/maliciosos sem efeito e sem erros; rajada de 40 disparos -> 1 resposta.
- Limitações novas: o upload de GLB por Open Cloud exige aprovar a pasta no Assistant (não contornado); modelos de
  equipamento são procedurais (Parts), não os GLB do kit; único asset externo novo é o Cone oficial da Roblox (id 23153487).
- Incidente: um diálogo de importação abriu no OUTRO place do usuário (janela errada em foco); foi fechado sem importar nada
  e o prompt do Rojo nesse place foi dispensado. Nenhuma alteração foi feita nesse place.

### Adições posteriores da sessão autônoma
- **Peças**: `Catalog.Parts` (14), `Defect.Parts`, `Profile.Parts` (estoque inicial TirePatch 3/Battery 1/Fuse 2), funções
  `GetPartCount/AddParts/HasParts/TakeParts` (tudo-ou-nada) no DataService, ação `BuyPart` (1..20, validada), consumo em
  CompleteJob/CompleteCollaborativeJob (do estoque do dono)/HireNpc; UI: seção de peças na Loja e linha "Peças x/y" nas ordens.
  Play: compra de 3 pneus (-90), 9 compras inválidas sem efeito, consumo exato de 1 bateria no reparo, bloqueio por falta de peça.
- **JobRules** (`src/shared/JobRules.lua`, pura): peso por capacidade (nível/equipamento). Teste: novo jogador 68% atendíveis,
  oficina completa 100%, todo defeito continua possível. Play: 14 de 16 clientes concluídos (antes 1 de 14).
- **Anti-farm**: `Config.ManualCustomerCooldownSeconds` = 20 (Play: 1 aceito, 2 recusados com mensagem).
- **Faíscas** (ParticleEmitter) no carro ao diagnosticar/concluir. Sons NÃO implementados: os áudios do Creator Store são de
  terceiros sem licença clara e os sons nativos do Studio não servem; precisa de áudio original/CC0 e upload aprovado.
- `RunAllTests.luau` agora troca `Shared` por uma cópia nova durante os testes (cache de require do Edit) e restaura no fim.
- Pendente de limpeza futura: `tools/glb_bounds.py` calcula limites em escala errada para GLBs quantizados (não usar).

### Avaliações dos clientes
- `CustomerRules.RateService`: nota de 1 a 5 = 4,0 base; preço (<=0,9: +0,5; >1,1: -0,5; >1,3: -1), espera relativa à paciência
  (<25%: +0,5; >=60%: -0,5; >=90%: -1), sobra de nível de quem executou (+0,25/+0,5), mecânico NPC (-0,5), variação ±0,5.
  `ReputationDelta` (5:+2 ... 1:-2, piso 0), `AverageRating` (média bayesiana, prior 3,5 com peso 5), `RatingFactor` (0,5..1,5),
  `StarsText`. A nota média entra no `Score` do cliente (fator de atratividade).
- Perfil v2 ganhou `RatingCount`, `RatingSum`, `RecentRatings` (10 últimas); `DataService.AddRating`; `reconcile` limita a soma
  entre count e 5x count e limpa a lista. A nota é registrada na oficina do dono (também quando o colaborador ou o NPC executa).
- `WorkshopService.rateService` é chamado em CompleteJob, CompleteCollaborativeJob e HireNpc; a mensagem de resultado mostra
  as estrelas. `job.PriceMultiplier` guarda o preço do momento da chegada. Ranking e Perfil mostram nota média e últimas notas.
- Testes: CustomerTest 51 (notas ótimas/péssimas/comuns, cada fator isolado, limites, fator de atratividade), PersistenceTest 50
  (registro, inválidas, limite de 10, persistência, dados corrompidos).
- Play (1 jogador, 6 serviços): 6 avaliações registradas (4,5,5,5,4,4), reputação bateu com serviço + ajuste em todos os 6 casos,
  ranking e média bayesiana (4,05) coerentes, sem erros de script.
- NÃO testado: avaliações de oficinas diferentes competindo; efeito da nota na escolha do cliente em tempo real (só regra pura);
  nota exibida ao colaborador/dono quando outro executa (só o executor vê a mensagem).
- Observação: as mensagens "Asset content representation is being generated" no console vêm das malhas importadas ainda
  sendo processadas pela Roblox; não são erros do código.

### Interior da oficina
- `tools/WorkshopBuilding.luau` (chamado por `BuildScenery`, que cria uma cópia nova do módulo a cada lote) constrói em Parts
  um prédio acessível no fundo de cada lote: piso, paredes com janela de vidro (frente e lateral), porta de pessoa e portão
  aberto, teto com beiral, faixa luminosa na cor do lote, 4 luminárias com PointLight por prédio, recepção (balcão,
  monitor, banco, máquina de café), 3 estantes de peças com caixas, bancada com morsa e painel de ferramentas, carrinho,
  extintor, relógio e **quadro de preços na fachada** (SurfaceGui `PriceText`, atualizado pelo servidor ao registrar a
  oficina e ao mudar o preço; volta a "OFICINA LIVRE" quando o lote é liberado).
- Substitui a casca fechada da garagem Polyfork (o asset continua em ServerStorage.Assets mas não é mais usado).
- Verificado por capturas do Studio (fachada, recepção, janela com vista da rua, estantes, bancada) e por Play: o
  personagem entra pela porta de pessoa e pelo portão (chegou a ~1 stud do destino), a parede lateral e o vidro da janela
  bloqueiam, e o quadro mostrou "PREÇO 100%" e depois "PREÇO 130%".
- Custo: o Workspace foi de 299 para 1055 partes; 42 PointLights (18 postes + 24 interiores), sem sombras. Desempenho em
  celular NÃO medido.
- Ajuste visual: paredes mais escuras e exposição 0 (interior estourava em branco com +0,3).
- Limitações: o relógio é só um disco e dois ponteiros; sem teto transparente/corte para câmera; o prédio é de uma cor só.

### Veículos no prédio
- Novo `src/shared/Layout.lua`: fonte única do referencial do prédio (origem no centro do lote, +X rumo ao portão, +Z ao fundo):
  interior, 2 vagas (9×18, em x=15 e x=4, z=19,5) e espaços de equipamento. `WorkshopBuilding` reposiciona os marcadores
  `Bay1/Bay2` do lote para dentro do prédio; `VehicleService` não mudou (usa a posição do marcador).
- Fachada refeita: portão aberto agora de x=-1 a 21 (cabem 2 carros), porta de pessoa em x=-8..-3, janela maior à esquerda;
  quadro de preços acima da janela; carrinho e extintor deslocados para não ficarem no caminho dos carros; cones agora ficam
  do lado de fora, na frente do portão.
- Equipamentos: pequenos dentro (Kit básico, Macaco, Scanner, Bancadas elétrica e de motor, Compressor, Balanceadora);
  grandes no pátio ao lado (Máquina de pneus, Alinhador, Elevador, Kit de funilaria). `EquipmentService` agora espelha o
  eixo X nos lotes ao norte (o prédio é girado 180° lá), corrigindo posições que antes eram em referencial do mundo.
- Testes: `CatalogTest` ganhou checagem de geometria (vagas dentro do prédio, sem sobreposição de vagas/equipamentos, cada
  equipamento todo dentro ou todo fora). Total agora 486 verificações (358 + 51 + 27 + 50), todas passam.
- Play (Plot1, lote norte): carro job_1 apareceu na Bay1 em x=-215, z=-92,5 (dentro do prédio, apoiado no piso, visível pelo
  portão na captura); Macaco comprado apareceu em x=-2,5 / z=17 local, como definido. Sem erros de script.
- Não testado: as demais compras (só Macaco e o já incluso Kit básico foram vistos no Play); 2 carros ao mesmo tempo
  visualmente (a Bay2 foi checada só por posição); prompts de interação com o carro dentro do prédio pelo lado do portão.

### Mercado de clientes e preços
- `src/shared/CustomerRules.lua` (puro): `Score` (preço^-2, reputação em log, nível na especialização, distância, fila,
  capacidade), `Choose` (sorteio proporcional + opção "ir embora" de peso 0,35), `ClampPrice` (0,7 a 1,5, passo 0,05, NaN->1), `Rank`.
- `WorkshopService.DispatchCustomers`: a cada 12 s chegam clientes; cada um sorteia uma especialização, as oficinas são
  pontuadas e uma é escolhida (ou ele desiste); o defeito vem de `JobRules.PickDefectId(..., especialização)`.
  Ponto de chegada `Config.CustomerArrivalPoint`; distância até `Plot.Entry`.
- Preço da oficina em `Profile.PriceMultiplier` (persistido, reconciliado); ação `SetPrice`; o preço é gravado na ordem
  (`job.Price`) quando o cliente chega e usado em pagamento, divisão com colaborador e custo do NPC.
- Botão "Receber cliente" virou "Panfletos (-15)": custa moedas e mantém cooldown de 20 s. Ranking no snapshot e no Perfil.
- Testes: `tools/CustomerTest.luau` (32). Achados de balanceamento corrigidos: com elasticidade 1,6 cobrar o teto rendia
  igual à tabela; solo sem opção de desistir permitia cobrar 1,5x sem perder clientes. Agora elasticidade 2 + desistência:
  tabela (1,0) maximiza a receita sozinho ou contra rival igual; dumping e teto rendem menos.
- Play (1 jogador): SetPrice 1,12->110%, 99->150%, -5->70%, NaN->100%, tipos inválidos ignorados; panfletos cobraram 15;
  ordem a 120% pagou 144 (tabela 120) e manteve 144 após o preço cair para 70%; ranking com 1 oficina (IsMe); chegada
  automática observada. Ritmo medido: com leva de 20 s era ~1 cliente/100 s; ajustado para 12 s e desistência 0,35
  (simulação: ~1 cliente a cada 32 s para novato solo).
- NÃO testado: competição entre 2+ oficinas reais (só as regras puras e simulações), efeito de reputação/preço em
  tempo real, avaliações dos clientes (não implementadas).

## Cenário (Etapa 3, continuação)
- `tools/BuildScenery.luau` (rodar depois do BuildWorld, mesmo método do clone+require): oficina em cada um dos 6 lotes
  (garagem Polyfork 3,5x, fachada para a rua, lotes do sul girados 180°), faixa luminosa em cor própria por lote, muros
  de divisa (fundo e laterais), 24 postes de luz, 48 árvores, letreiros "AUTOPEÇAS 24H" e "DISTRIBUIDORA".
  275 partes no Workspace.
- Verificado por captura de tela do Studio: 6 lotes com oficinas voltadas para a rua, postes, árvores e muros.
- Limitações: a garagem Polyfork é escura por natureza (cor da malha); interior não modelado nem acessível; loja de
  autopeças e distribuidora ainda são blocos com letreiro; não foram importados modelos de rua do Shuriken/Kenney.
- Lighting ajustado (ambient mais claro, exposição +0,3) e gravado no BuildWorld. Perf: não medida em dispositivo móvel.
- Janelas do Studio: se a tela inicial/servidor de teste cobrir o place, minimizar essas janelas (botão —) em vez de
  usar `open_application`; só então Ctrl+S e conferir o LastWriteTime.

## Interação física com o veículo (Etapa 4)
- `VehicleService` cria no carro um `InteractPoint` com dois `ProximityPrompt` (Diagnosticar 1,2 s, Reparar 2,5 s, tecla E,
  alcance 14 studs). Só um fica ativo por vez (`SetStage`). O servidor trata `Triggered` via
  `WorkshopService.Interact`, que decide por participação (dono ou colaborador) e reutiliza as mesmas regras de
  `DiagnoseJob`/`CompleteJob`/`CompleteCollaborativeJob`.
- Validação de distância no servidor para TODAS as vias (prompt e botões da UI): `VehicleService.IsNear` mede até a
  caixa do carro (`Config.InteractDistance` = 22 studs). Realce (Highlight) azul ao diagnosticar, verde ao concluir.
- Testado em Play (1 jogador): diagnóstico pela UI a 55 studs é recusado; após aproximar, segurar o prompt de
  diagnóstico revela o defeito e troca o prompt para Reparar; segurar Reparar concluiu o serviço (+120 moedas, +30 XP).
- NÃO testado: prompt usado por colaborador/estranho (precisa de 2 jogadores), toque em celular, sons, animações de reparo.
- Os testes de remotes agora precisam posicionar o personagem perto do carro.
- Tentativa de teste com 2 jogadores (Teste > Iniciar teste de sessão > Servidor e clientes): abriu só a janela do
  servidor, com 0 clientes. Falta adicionar 2 clientes (menu Teste da janela do servidor ou "Clientes e servidores" na
  faixa Teste). Não chamar `open_application` de novo: abre outra janela inicial do Studio em vez de focar a existente.
- Salvar o place sem o usuário: trazer a janela do `.rbxlx` para frente e Ctrl+S; confirmar pelo LastWriteTime do arquivo.

## Interface (Etapa 7, parcial)
- Substituiu a UI de teste. `src/client/Main.client.lua` só chama `UI/HUD`. Módulos: `UI/Theme`, `UI/Kit` (botão, cartão,
  chip, barra, painel modal), `UI/Store` (snapshot + remotes), `UI/HUD` (barra de moedas/reputação/nível, avisos, número
  flutuante de moedas, navegação inferior, convite de trabalho), `UI/Panels/{Orders,Skills,Shop,Profile}`.
- Textos em `src/shared/Locale.lua` (pt-BR; estrutura pronta para en-US). Nomes de itens do Catalog ainda são pt-BR fixos.
- Responsivo: UIScale pela viewport (0,7x a 1,25x), painéis 92%x82% limitados a 620x560, alvos de toque 48 px em touch,
  ScreenInsets de área segura.
- Servidor: `GetSnapshot` agora envia `Requirement` (só após diagnosticar) e `CollabJobs`; `Catalog.BusinessLevel`.
- Testado em Play (cliente real, 1 jogador): HUD criado sem erros no console; os 4 painéis renderizam com dados reais
  (ordens com requisitos após diagnóstico, 5 habilidades, 7 equipamentos, perfil), sem texto vazando da janela e com
  rolagem. Fluxo ClaimWorkshop/GenerateCustomer/AcceptJob/DiagnoseJob pelo `Store.Act` OK.
- NÃO verificado: aparência por captura de tela (a janela do place ficou inacessível ao computer-use), layout em
  celular/tablet real ou emulado, clique real nos botões da navegação, convite entre 2 jogadores, sons.
- Não implementado (sem backend ainda): loja de peças, contratação de NPC fixo, ranking, perfil de outros jogadores,
  expansão de terreno, configurações, árvore de habilidades com ramos.

## Persistência (Etapa 8, parcial) — DataService schema v2
- Reescrito `src/server/DataService.lua`: retentativas com backoff (4x), trava de sessão por JobId (timeout 360 s,
  espera até 20 s), save com UpdateAsync que se recusa a sobrescrever se outro servidor tem a trava, liberação da trava
  ao sair, BindToClose paralelo (até 25 s), save serializado por jogador, descarte seguro se o jogador sai durante o load,
  falha de leitura = kick (nunca perfil padrão). Modo memória só no Studio sem DataStore.
- Dados persistidos: moedas, reputação, XP por especialização, equipamentos da oficina (`Equipment`, agora o mesmo
  objeto usado pelo WorkshopService), histórico das últimas 50 transações (`Transactions`), `TotalEarned`.
- Migração v1 -> v2 por `reconcile` (preserva dados, cria campos novos, remove equipamentos que saíram do catálogo).
- Testes: `tools/PersistenceTest.luau` com DataStore simulado, 27 verificações, TODAS PASSARAM (perfil novo, salvar/sair/
  recarregar em outro servidor, espera de trava, trava presa/expirada, trava perdida, retry, falha total, migração,
  limite do histórico, saldo não negativo).
- Regressão em Play (remotes reais, modo memória): equipamento exigido para o reparo, compra de equipamento debita e
  registra transação, compra duplicada e sem saldo recusadas.
- NÃO testado: DataStore real (place não publicado), dois servidores reais, BindToClose real.
- Ainda não persiste: PlotId preferido, expansão de oficina, funcionários NPC contratados, ordens em andamento.

## DataService corrigido (histórico)
- Falhava ao carregar em place não publicado (GetDataStore sem pcall) e derrubava todo o servidor.
- Agora: pcall; no Studio sem DataStore usa MODO MEMÓRIA (aviso no console, nada é salvo); fora do Studio mantém o kick.
- Persistência real só pode ser testada após publicar o place e habilitar API Services (ação do usuário).
- Malhas importadas dão "Invalid place ID" no Play enquanto o place não for publicado; publicar resolve.

## Não testado ainda
Nenhum teste de gameplay, multiplayer ou DataStore foi executado. Persistência exige API Services habilitado.

## Próxima tarefa
Importar o kit de oficina e peças de rua prioritárias, escalar tudo, configurar Lighting/baseplate e montar o primeiro lote.

### Novo HUD (referência visual azul-marinho)
- **Arquitetura:** `UI/Theme` (paleta navy), `UI/HudParts` (só visual: painel, botão de menu com 4 estados, barra, miniatura 3D),
  `UI/HUD` (monta o layout e liga ao `Store`), painéis novos `Panels/Stock`, `Ranking`, `Notifications`. Nada de regra de jogo
  no cliente: o servidor continua decidindo dinheiro, ordens, reputação e XP.
- **Barra superior:** nível profissional + XP (`Catalog.BusinessProgress`: o XP da oficina é o total ganho; nível N começa em
  (N-1)²·100), saldo em moedas, reputação (pontos) e média de avaliações. Tudo vem do snapshot real.
- **Menu lateral** (Ordens, Habilidades, Loja, Estoque, Perfil) e **barra inferior** (Ordens, Habilidades, Loja, Estoque,
  Ranking): estados normal/hover/pressionado/selecionado/indisponível (desabilitados até o 1º snapshot). Selo vermelho de
  Ordens = clientes aguardando (ordens `Available`). Menu lateral minimizável («/»); botão ▤ mostra/oculta a coluna direita.
- **Clientes aguardando:** ViewportFrame com o modelo real do veículo (`ReplicatedStorage.VehiclePreviews`, publicado em
  runtime por `VehicleService.PublishPreviews`), nome do cliente (`Catalog.CustomerNames`, sorteado ao criar a ordem), tempo de
  espera e barra de paciência animados localmente entre snapshots, aviso abaixo de 25% de paciência. Não revela o defeito.
- **Painel de ordem:** etapas reais da ordem em andamento (aceitar → diagnosticar → reparar e entregar). A etapa 3 só fecha
  quando a ordem some (concluída no servidor).
- **Perfil da oficina:** nome, nível, média e nº de avaliações, clientes atendidos (= avaliações, pois cada serviço concluído
  gera uma). "Ver detalhes" abre o Perfil completo.
- **Notificação de avaliação:** evento `Rated` enviado pelo servidor (estrelas, reputação, serviço e chave de comentário). O
  comentário é derivado dos fatores reais da nota (`CustomerRules.CommentKey`: espera, preço, nível, NPC), sem texto livre.
  Some em 7 s; clicar abre o Perfil.
- **Notificações (sino):** histórico da sessão das mensagens do servidor + contador de não lidas.
- **Responsividade:** UIScale por tela (celular usa referência menor e escala mínima 0,85 para áreas de toque maiores, botões de
  54 px); layout compacto abaixo de 760 px lógicos (logo/ícones extras ocultos, menu minimizado, coluna direita oculta,
  barra inferior só com ícones). Atributo `ViewportOverride` no ScreenGui simula outras telas em testes.
- **Validação (Play, 1 jogador):** capturas do HUD completo, estoque, ranking, sino, menu minimizado, coluna direita oculta,
  layout compacto (375×812 simulado) e paisagem de celular (812×375 simulado); notificação de avaliação com 5 estrelas,
  comentário e +2 reputação vindos do servidor; painel de ordem refletindo diagnóstico; sem erros de script. Testes: 499
  verificações (363 + 59 + 27 + 50), todas passam.
- **Não conectado / pendências:** Configurações e Sair (botões desabilitados: não há painel de configurações nem fluxo de
  saída); "Conversar com o cliente" e prompt "Falar com o Cliente" (não existem NPCs de cliente; a interação continua nos
  ProximityPrompts do carro, que no celular viram botão de toque nativo); Mapa, Menu rápido e Correr (não existem);
  horário/temperatura (não há ciclo dia/noite nem clima); taxa de retorno (sem cálculo definido no servidor); som da
  avaliação (sem asset de áudio com licença conferida); ranking persistente entre servidores; ícones são emojis do sistema
  (alguns glifos não renderizam, por isso moeda e menu usam texto) — trocar por imagens quando houver arte própria.
- **Não testado:** aparelho de toque real (só simulação de tamanho), vários clientes em fila longa (mostra no máximo 2),
  gamepad.

### HUD v2: reprodução da imagem de referência (animado)
- **Fonte do visual:** `assets/hud_ref/reference.webp` (1672×941, com transparência). `tools/slice_hud_reference.py` recorta os ícones e fotos
  da própria imagem (fundo removido por brancura/diferença de cor, ampliados 4×) em `assets/hud_sprites/` (25 PNG). `tools/upload_hud_sprites.py`
  envia como Decal pela Open Cloud (chave em `~/.oficina24h/secrets.env`, nunca impressa) e os ids de IMAGEM (via `InsertService:LoadAsset`) ficam
  em `src/shared/HudAssets.lua`. Os painéis, botões, barras, selos e textos são nativos (UIGradient/UIStroke/Oswald), com cores amostradas da imagem.
- **Arquitetura:** `UI/Theme` (paleta e fontes), `UI/Motion` (tokens de animação, respeita Reduzir Movimento), `UI/HudParts` (componentes visuais),
  `UI/HUD` (layout + dados reais do `Store`). Painéis modais continuam em `UI/Panels/*` (Kit), já na paleta nova.
- **Elementos:** barra superior (logo, nível/XP, saldo, reputação + média), controles (painéis, sino com contador, engrenagem e sair desabilitados),
  menu lateral com 5 botões (selecionado = degradê laranja com brilho pulsante, selo vermelho com clientes aguardando) e botão de minimizar,
  coluna direita (Clientes aguardando com miniatura 3D real e barra de paciência, Painel de ordem com etapas reais, Perfil da oficina),
  barra inferior (Ordens, Habilidades, Loja, Estoque, Ranking; selecionado azul), aviso de avaliação (sprites de check/estrelas, comentário e reputação
  vindos do servidor), prompt contextual desenhado pelo HUD a partir dos `ProximityPrompt` do carro (`Style = Custom`; tecla, ação, objeto e barra de
  espera; no toque, tocar na tecla segura o prompt).
- **Animações:** hover 1,04 / pressionado 0,96 / soltar com recuo (UIScale `Pop` por botão), realce laranja/azul por transparência, brilho pulsante do
  selecionado, selo que "estoura" ao subir, toasts entrando, aviso de avaliação deslizando, prompt entrando com recuo, barras com tween.
- **Telas:** UIScale por tela (piso 0,70; 0,78 no toque); layouts wide (≥1500 lógicos), compact (<1500: logo e extras ocultos, menu minimizado,
  coluna direita sob demanda e rolável, barra inferior só com ícones) e tight (<760: barra superior encolhida). Medido em 7 tamanhos
  (1920×1080, 1366×768, 1024×600, 932×430, 844×390, 667×375, 375×812 simulados com `ViewportOverride`): barra superior × controles sem
  sobreposição, menu e coluna dentro da tela, texto mínimo desenhado 14 px, alvo de toque mínimo 56 px.
- **Gamepad:** `SelectionImageObject` nos botões, foco vai ao botão de fechar ao abrir painel e volta ao fechar, B fecha o painel (lógica
  escrita, NÃO testada com gamepad real).
- **Honesto sobre a fidelidade:** fonte é Oswald (a da referência é outra, mais leve); ícones são recortes 4× de ~50 px (um pouco macios);
  brilho externo do botão selecionado é aproximado; "OFICINA 24H" não é itálico; a tecla E do prompt é desenhada, não a arte da referência.
- **Fora (não existe no jogo, não inventado):** atalhos Mapa/Menu rápido/Correr, horário e temperatura (sem dia/noite), "Taxa de retorno",
  "Falar com o cliente" (não há NPC de cliente; o prompt mostra Diagnosticar/Reparar do carro), som de avaliação (sem áudio licenciado).
- **Nota:** auto-avaliação apenas (sem revisor cego, sem celular real, sem gamepad): abaixo de 8,5 até esses três testes. Registro em `.fwjelaa/ledger.jsonl`.
- Comparação lado a lado: `docs/hud_comparacao.png`.

### Cinco painéis (Perfil, Estoque, Loja de Peças, Habilidades, Ordens de Serviço)
- **Referência:** `assets/hud_ref/panels_reference.webp`. `tools/slice_panel_reference.py` recorta 46 ícones/imagens (`pn_*`), `tools/upload_hud_sprites.py`
  envia, ids em `src/shared/HudAssets.lua`. A imagem inteira NÃO é usada como fundo: tudo é reconstruído com Frames/UIGradient/UIStroke.
- **Arquitetura:** `UI/PanelKit` (janela com cabeçalho/minimizar/fechar, abas, busca, filtro em lista, botões, cartões, estado vazio);
  cada painel em `UI/Panels/*` recebe só dados do `Store`. O gerenciador (`HUD.openPanel`) mantém UM painel aberto, fecha ao abrir outro,
  Escape/B fecham, o botão "-" minimiza, e todas as janelas se ajustam à tela (`Fit`). Painéis só recriam a tela quando os dados que mostram mudam
  (evita perder cliques a cada snapshot).
- **Servidor (mudanças mínimas, sem duplicar serviços):** `DataService` guarda `OrderHistory` (30) e comentário/cliente nas avaliações;
  `WorkshopService.Checkout` (nova ação `Checkout`): compra TODOS os itens do carrinho ou nenhum, recalcula preços, valida saldo, limites,
  quantidade inteira e posse; `Catalog` ganhou categorias DERIVADAS (`PartCategory`, `EquipmentCategory`, `CategoryOrder`) e `VehicleModels`;
  `Main` publica miniaturas (`EquipmentPreviews`), envia o nome da ação no resultado e cria o prompt "Abrir loja" na Loja de Autopeças do bairro.
- **Perfil:** abas Visão Geral (nível/XP, reputação e média, clientes atendidos, desempenho com as últimas avaliações reais, controle de preço),
  Avaliações (estrelas, comentário derivado dos fatores reais, cliente, serviço, "há N min"), Histórico (serviços concluídos e movimentações);
  Conquistas desabilitada (não existe no jogo). "Taxa de retorno" não existe (sem cálculo definido no servidor).
- **Estoque:** abas Peças/Equipamentos/Consumíveis (vazia: não há consumíveis separados das peças), busca por nome, filtro (todos, em estoque, categorias),
  grade com miniatura, quantidade e "Sem estoque", detalhes ao selecionar (categoria, onde é usada, o que libera). Somente leitura.
- **Loja de Peças:** abas Peças/Equipamentos/Ferramentas/Acessórios (as duas últimas vazias: não existem no catálogo), categorias da barra lateral só quando
  existem itens, miniaturas (modelos 3D das 14 peças em `shared/PartModels`, equipamentos reais; Bateria e Vela usam a foto da referência),
  carrinho com quantidades, total, "Finalizar Compra" ligado ao servidor; o carrinho só esvazia quando o servidor confirma. Qualidades
  Econômica/Padrão/Premium NÃO existem no catálogo (cada peça tem um preço): não exibidas. Loja física: prompt "Abrir loja" na fachada.
- **Habilidades:** lista das 5 especializações (nível, barra), detalhe (imagem, descrição, próximo nível com os serviços que o catálogo realmente libera,
  XP atual, nível profissional geral). Sem botão de evolução (o XP vem dos serviços). "Suspensão e Freios" é uma só especialização no jogo.
- **Ordens:** Em Aberto / Em Andamento / Concluídas, miniatura 3D (ViewportFrame), cliente, estado, espera e paciência ao vivo; Conversar mostra a
  reclamação (não o defeito), Aceitar Ordem/Dispensar/Abandonar/Diagnosticar/Concluir/Mecânico NPC/Convidar profissional/colaboração preservados.
  A nota "4,5" do cliente da referência não existe (clientes não têm nota antes do serviço): não exibida.
- **Testes:** 419 (Catalog: categorias, modelos das 14 peças, veículos) + 59 + 27 + 53 (Persistence: histórico e comentário) = 558, todos passam. Play:
  Perfil/Estoque/Loja/Habilidades/Ordens abrem e fecham; compra real (moedas e estoque mudam, equipamento aparece no lote); 12 payloads
  maliciosos de Checkout (quantidade negativa/NaN/fracionária/enorme, item inexistente, equipamento já possuído, duplicado, tipos errados)
  recusados sem alterar moedas nem estoque; compra sem saldo recusada por inteiro; busca no Estoque; Conversar; aceitar → Em Andamento →
  diagnosticar → concluir → Concluídas com estrelas; prompt da loja física abre a Loja; Escape fecha; minimizar (altura 86).
- **Telas:** 7 tamanhos simulados (1920×1080 a 375×812): todas as janelas dentro da tela. Celular: abas sem ícones, categorias da Loja em lista
  de seleção, Habilidades com lista horizontal. NÃO testado em aparelho real nem com gamepad.
- **Apenas visual / pendente:** ferramentas e acessórios, consumíveis, conquistas, taxa de retorno, qualidades de peça, nota prévia do cliente, som.

### Minijogo de reparo "Apertar na hora certa"
- **Como funciona:** ao começar o reparo (botão "Iniciar reparo" ou prompt E no carro) o servidor valida tudo (responsável, diagnóstico, distância,
  equipamento, nível, peças) SEM cobrar, sorteia um plano (semente) e guarda o instante de início. A tela mostra uma barra com uma zona verde e um
  núcleo dourado; o marcador vai e volta e o jogador aperta Espaço / botão A / clique / toque em APERTAR. 3 a 5 etapas conforme o nível do defeito;
  nível alto = barra mais rápida e zona menor; sobra de nível alarga a zona. Resultado por etapa: Perfeito, Bom ou Errou (sem toque em 4 s = erro).
- **Qualidade (0-100)** = 75% precisão + 25% rapidez (tempo REAL medido pelo servidor). Efeitos: nota do cliente (+0,75 estrela em ≥90, +0,25 em ≥70,
  −0,75 em <40, −1,25 em <20); pagamento 85% se <40; **gorjeta de 5% a 20% do preço em ≥90** (variável pela qualidade); +20% de XP em serviço perfeito;
  comentários novos ("Serviço perfeito, nem uma folga!" / "Ficou meio mal feito..."). Mecânico NPC e colaborador continuam sem minijogo.
- **Segurança (skills secure-remotes e anti-exploit):** o cliente só envia os instantes dos toques; o servidor recalcula Perfeito/Bom/Errou a partir
  do plano, exige tempos finitos em [0,25; 4] s, quantidade igual ao número de etapas, sessão única (reenviar não paga duas vezes), expiração de 90 s,
  e que a soma dos toques não passe do tempo real da sessão (+0,6 s). O remote `CompleteJob` agora apenas INICIA o minijogo: não existe conclusão
  direta. Ataques testados no Play (todos recusados, moedas intactas): finalizar sem sessão, CompleteJob cru, toques maiores que a sessão (esta
  falha foi encontrada no teste e corrigida), reenvio, NaN/negativo/enorme/tipo errado/quantidade errada, cancelar e enviar, job errado, payload
  malformado. Limite honesto: um cliente adulterado pode calcular os toques perfeitos a partir do plano (inerente a jogos de habilidade no cliente);
  o ganho máximo é limitado (gorjeta ≤ 20%, +0,75 estrela) e ele precisa esperar o tempo real.
- **Acessibilidade:** "Reduzir movimento" do Roblox deixa a barra 30% mais lenta e a zona maior (preferência enviada ao servidor por `RepairPrefs`);
  Espaço/A não fazem o personagem pular durante o jogo (ContextAction com Sink); afastar-se do carro cancela sem custo.
- **Testes:** `tools/RepairTest.luau` (36 verificações: plano determinista e faixas, barra, resultado por toque, validação dos toques, qualidade,
  pagamento, gorjeta, XP, efeito na nota, comentários). Total 594 (419 + 59 + 36 + 27 + 53). Verificador `fwjelaa-check.ps1 -Scan`: 0 erros, 0 avisos.
- **Telas:** 7 tamanhos simulados: largura e altura cabem, texto mínimo 12,8 px, botão APERTAR ≥ 46 px. Capturas do jogo, do feedback "BOM" e do resultado.
- **Não testado:** celular real, gamepad real, balanceamento da dificuldade com jogadores reais (números iniciais), som (sem áudio licenciado ainda).

## 2026-11-06 — Fechamento P0, lote 1 (diagnóstico por escolha + qualidade com 6 fatores)
- **Qualidade com 6 fatores** (decisão do Product Owner): `RepairRules.Evaluate` soma execução (precisão + rapidez), erros (corrigido −6, não corrigido −14; até 2 correções por reparo), habilidade (até +6), equipamento (+0 a +4), peça (−8 a +4 pela confiabilidade) e diagnóstico (+6 de primeira, 0 no 2º palpite, −6 depois). O resumo do reparo mostra cada fator. Faixas de peça (Econômica/Padrão/Premium) ficam para depois.
- **Diagnóstico por escolha** (`DiagnosisRules`, `DiagnoseJob`, tela `DiagnosisGame`): 3 candidatos, sintoma pode enganar, o servidor guarda as opções e valida; palpite errado bloqueia a opção e reduz a qualidade. Testado no Play: abrir, escolha inválida/NaN/tipo errado/outro job recusados, errado → bloqueado e reenviado, certo → libera o serviço.
- **Correções de auditoria:** Motor com serviço de nível 1; Studio usa o DataStore `_STUDIO`; botões sem função removidos; prompts "E" só para o dono do carro; ordem parada >15 min é liberada; cliente que cansa de esperar sai com aviso; limitador por ação (não descarta mais ações diferentes).
- **Bug achado pelo teste novo:** `Evaluate` indexava toque inexistente quando faltava toque de etapa (erro em vez de recusa) — corrigido.
- **Testes:** 623 verificações passam (Catalog 424, Customer 59, Repair 60, Plot 27, Persistence 53). Verificador: nenhum achado novo nos arquivos de hoje (único erro é de `tools/PersistenceTest.luau`, ferramenta de teste).
- **Assistente 3D:** 3 avatares de cliente gerados e guardados em `ServerStorage/Assets/Customers` (Homem30, Homem60, Mulher28). Ainda não aparecem no jogo.
- **Pendente (P0):** cliente NPC físico (spawn, fala, saída), onboarding do 1º atendimento, reduzir polígonos dos carros, `docs/ORIGEM_ASSETS.md`, reset do perfil de produção do dono (precisa de OK), testes humanos (2 jogadores, celular, teste fechado).

## 2026-11-06 — Fechamento P0, lote 2 (cliente NPC físico + guia do 1º atendimento)
- **Cliente NPC físico** (`CustomerNpcService`, ligado a `VehicleService.Spawn/Despawn`): ao aceitar uma ordem, um cliente (modelos do assistente 3D) aparece ao lado do carro, de frente para ele, e conta o problema num balão. O prompt "Conversar" (só para o dono) abre o diagnóstico. Depois do diagnóstico ele diz "Pode consertar" e some com "Até mais!" quando a ordem acaba (concluída, dispensada, abandonada, expirada ou dono saiu). Como o NPC nasce e morre junto com o veículo, não há duplicata nem órfão. Sem modelo em `ServerStorage/Assets/Customers` o jogo segue sem NPC.
- **Guia do 1º atendimento** (`client/UI/Onboarding.lua` + `DataService.CompleteOnboarding`): 5 passos derivados do estado real do servidor (aceitar → aguardar → conversar → comprar peça se faltar → reparar), um objetivo (≤ 8 palavras) e um ponteiro por vez (Highlight no NPC/carro ou contorno pulsante no botão do menu; sem pulso com "Reduzir movimento"). Retomável por natureza. "Pular guia" pede confirmação e não paga. O servidor encerra o guia no 1º serviço concluído e paga **+40 moedas uma vez**. Perfis antigos que já atenderam clientes não veem o guia.
- **Testado no Play (jogador novo simulado):** banner → NPC aparece, fala e fica em pé → diagnóstico → reparo perfeito → bônus +40 pago uma vez → guia some → NPC sai. Achado e corrigido no teste: NPC aparecia inclinado (mirava o carro de um ponto mais baixo).
- **Testes:** 631 verificações (Catalog 424, Customer 59, Repair 60, Plot 27, Persistence 61 — 8 novas do guia). Verificador sem achados novos.
- **Gancho de QA:** `ServerStorage.QA` (BindableFunction), criado só no Studio, para simular jogador novo nos testes.
- **Registro de assets:** `docs/ORIGEM_ASSETS.md` criado; sprites do HUD e pacote de ícones continuam **A CONFIRMAR** (licença).
- **Lição de ferramenta:** apagar arquivo temporário dentro de `tools/` derruba o Rojo (watcher); scripts de patch vão para a pasta temporária.
- **Não testado:** NPC com 2 jogadores, celular real, animações do NPC (ele fica parado, sem animação de idle), pulso dos botões em tela pequena.

## 2026-11-06 — Revisão de segurança de lançamento (agente roblox-reviewer) e correções
Relatório do revisor: nenhum crítico; 4 altos, 6 médios, 10 baixos. Cada item alto foi conferido no código antes de corrigir.
- **A1 (corrigido, atacado no Play):** `CompleteCollaborativeJob` deixava o DONO concluir sem minijogo (ele já é o responsável ao aceitar a ordem). Agora exige colaborador convidado e diferente do dono. Ataque no Play: recusado, moedas e ordem intactas.
- **A2 (corrigido, 2 testes novos):** saída do último jogador cortava o save em voo e reentrada rápida lia dado antigo e apagava o perfil novo. Agora há `Removing`: `Load` espera o save anterior, `Remove` só apaga o próprio perfil e o `BindToClose` aguarda saídas em andamento.
- **A3 (corrigido):** colaborador não prende mais a vaga: convite só em ordem diagnosticada, um convite pendente por ordem e colaboração vence em 180 s (a ordem volta ao dono, com aviso).
- **A4 (corrigido, testes + Play):** NaN/infinito rejeitados em `InviteWorker`; `AddCoins`, `AddReputation` e `AddSkillXP` ignoram valores não finitos; reconcile sanea reputação e total ganho.
- **M1 (convites pendentes), M3 (GetSnapshot em cache 0,4 s, invalidado a cada ação), M6 (sessão de reparo esquecida expira), B2/B3 (perfil antigo com ganhos não repete o guia):** corrigidos.
- **Abertos (aceitos para o P0):** M2 minijogo aceita bot perfeito (inerente ao jogo de habilidade no cliente; ganho limitado, já documentado); M4 trava perdida não expulsa o jogador; M5 ordens fantasmas do dono que saiu duram até a paciência; B1 prompts sem limitador próprio; B4–B10 (migração por versão, tipos exportados, tweens no servidor).
- **Testes:** 636 verificações (Catalog 424, Customer 59, Repair 60, Plot 27, Persistence 66). Verificador sem achados novos.
- **Animações do assistente 3D (prontas, ainda não usadas):** caminhada `rbxassetid://99232109851461`, espera `rbxassetid://114394899846985`.

## 2026-11-06 — Chegada do cliente (exceção P0 aprovada pelo Product Owner, versão menor)
Classificação: tráfego e carros dirigíveis seguem **P1**; esta entrega é só a chegada VISUAL de cada cliente, sem dirigir de verdade.
- **Fluxo:** o carro entra pela rua principal e para no meio-fio em frente ao lote → o cliente desce, atravessa a calçada com animação de caminhada e espera na entrada com um balão contando o problema → **a ordem só abre (lista, aceitar, dispensar) quando ele chega**. A paciência conta a partir da chegada e o jogador recebe o aviso "X chegou com Y".
- **Ao aceitar:** o carro da rua vai embora, o carro entra na vaga e o cliente aparece ao lado dele (como antes), agora com animação de espera. **Dispensado ou sem atendimento (paciência):** o cliente volta ao carro, os dois vão embora. **Dono saiu:** tudo some na hora.
- **Estrutura:** `CustomerArrivalService` (cena da rua, tempo estimado → `job.ArrivesAt`), `NpcKit` (modelo, posição, animação, caminhada, balão, sumir), `CustomerNpcService` (cliente na vaga), `shared/NpcAnimations` (ids). Até 3 clientes por oficina lado a lado; carro da rua é uma peça-raiz com solda (anima 1 peça, não 17 mil triângulos por quadro); NPCs não colidem e não têm dono de rede.
- **Testado no Play:** 3 chegadas simultâneas; ordem fechada durante a chegada; aceitar (carro e cliente da rua saem, cliente da vaga aparece de pé, parado, com a animação de espera); dispensar (cliente volta e vai embora); sem objetos órfãos.
- **Não testado:** expiração por paciência (mesmo caminho do dispensar), 2 jogadores, celular, desempenho com 6 oficinas × 3 carros de ~17 mil triângulos na rua mais 3 na vaga (a tarefa de redução de polígonos está em suas mãos), colisão visual entre 3 carros lado a lado de modelos maiores.
- **Decisões de design:** cliente da rua e cliente da vaga são a mesma pessoa (mesmo modelo pelo nome) mas não andam juntos até a vaga (exigiria pathfinding dentro do prédio): o cliente "entra" e reaparece ao lado do carro.

## 2026-11-06 — Multiplayer local (servidor + 2 clientes no Studio)
Ambiente: teste de sessão do Studio (servidor local + Player1 e Player2), **não** é homologação publicada: não valida DataStore em place publicado, latência real nem 2 servidores.
- **Lotes:** cada jogador ganhou o seu (Plot1 e Plot2); o lote de quem saiu foi liberado (`OwnerUserId` 0).
- **Isolamento de ordens:** cada um só vê as suas (Player1 3 ordens, Player2 1 no início); ids globais, ordens separadas.
- **Ataques cruzados (Player2 ao lado do carro do Player1):** AcceptJob, DeclineJob, DiagnoseJob (sem e com escolha), CompleteJob, FinishRepair, HireNpc, CompleteCollaborativeJob, InviteWorker e CancelRepair → todos recusados; moedas intactas; a ordem do outro nem aparece no snapshot.
- **Prompt "E":** só o dono vê "Conversar" no cliente da sua vaga; o outro jogador, a 7 studs, não vê nada.
- **Chegada do cliente:** cada oficina recebeu seus carros e clientes na faixa e calçada do próprio lado da rua (z negativo e positivo), sem mistura.
- **Saída:** com Player2 expulso (`Kick`), os carros e clientes dele sumiram, o lote foi liberado e o Player1 seguiu intacto.
- **Perfis:** jogadores de teste do Studio (ids −1 e −2) começam do zero e viram "jogador novo" (guia ativo).
- **Limites do teste:** sem latência, sem dois servidores, sem DataStore publicado, sem celular. Continuam obrigatórios antes do lançamento (tarefas 11 a 13).

## 2026-11-06 — Pendências de segurança (M4, M5, B1) e expiração testada
- **M4:** se a trava de sessão do DataStore é perdida (outro servidor assumiu), o jogador é expulso em vez de perder ganhos em silêncio; falha TEMPORÁRIA do DataStore não expulsa (tenta no próximo autosave). 3 testes novos.
- **M5:** ao dono sair, as ordens dele que não estavam em andamento são removidas (sem ordem fantasma na reentrada).
- **B1:** prompts do "E" (carro e cliente) passam por limite de 0,5 s por jogador.
- **Expiração testada no Play** (gancho `AgeJobs` do QA, só Studio): ordem aceita e esquecida → cliente leva o carro, -1 de reputação, vaga e cliente do bay removidos; cliente sem atendimento → vai embora com aviso; nenhum objeto órfão.
- **Testes:** 639 verificações. Reauditoria no formato da seção 22 em `docs/AUDITORIA_P0.md` (seção 8).

## 2026-11-06 — Reset do perfil de produção do dono (autorizado pelo Product Owner)
- **Alvo:** chave `u_11072958195` no DataStore `Oficina24H_PlayerData_v1` (universo 10774930385). Conferido antes: 817 moedas, 15 avaliações, histórico de 11 serviços, sem trava de sessão ativa — os mesmos dados de teste da auditoria.
- **Cópia de segurança:** `C:\Users\Administrador\.oficina24h\backups\profile_u_11072958195_20261106_145206.json` (fora do repositório, junto da chave de API).
- **Ação:** DELETE via Open Cloud (204); GET depois retorna 404 (entrada não encontrada). O DataStore mantém versões antigas por um tempo, mas o jogo vê o perfil como inexistente: no próximo login nasce um perfil novo (250 moedas, guia do 1º atendimento ativo).
- **Não tocado:** o DataStore de teste do Studio (`_STUDIO`) e qualquer outro usuário.

## 2026-11-07 — Renovação visual, etapa 1: veículos sem marca (missão "RENOVAÇÃO VISUAL E INTEGRAÇÃO DE ASSETS 3D")
Classificação: arte do P0 (substitui os 3 carros genéricos). Fases 1 a 5 cumpridas **para os veículos**; fases 6 a 8 (bairro, 3 oficinas, equipamentos) **ainda não**.
- **Inventário da pasta `carros`:** 532 modelos (hatch 46, sedã 61, SUV 77, picape 23, cupê 234...), 528 CC BY e 4 CC BY-SA, mediana de 68 mil triângulos, 486 comprimidos com meshopt (o importador do Roblox não lê), 428 com textura.
- **Incidente de moderação:** o primeiro lote enviado trazia um modelo cuja textura tinha bandeira e texto; o Roblox moderou a conta ("User is moderated", 403). O Product Owner reativou a conta e pediu **nenhum QR code e nenhuma marca de carro**. Daí em diante: inspeção visual de todas as texturas antes de enviar; sem OCR/QR automático.
- **Pipeline novo (`pipeline/`):** `blender_process_car.py` (escala real, frente em +Y, remoção de peças de emblema/placa, remoção por raio no ponto marcado, mini-texturas para cores lisas, JPEG, redução de polígonos), `brand_patches.json` (pontos marcados nas vistas), `sanitize_glb_textures.py` (placa genérica fictícia, apaga assinaturas), `extract_glb_textures.py`, vistas ortográficas, `upload_models.py` (Open Cloud), `fetch_kits.py`.
- **Resultado:** 14 veículos sem marca (4 hatch, 4 sedã, **2 SUV**, 4 picape) com 0,7 a 12 mil triângulos (antes ~17 mil), 0,25 a 3 MB cada, nomes genéricos no jogo (`Catalog.VehicleModels`, 14 nomes). Os mesmos 3 carros antigos ficaram em `ServerStorage/Assets/Veiculos_Antigos`.
- **Bugs achados no teste:** (1) o importador do Roblox ignora a cor de material sem textura (SUV saiu todo cinza) → mini-texturas; (2) cor linear gravada como sRGB (sedã vinho saiu preto); (3) imagem gerada em memória não era lida pelo exportador (texturas pretas) → salvar PNG em arquivo e recarregar; (4) PNG pesado (GLB de 14 MB) → JPEG + compactação do binário.
- **Testado no Play:** os 14 modelos importam (escala, texturas), miniaturas do HUD (14 previews), chegada na rua (carros vindos do leste, frente para o oeste), aceitar → carro na vaga com cliente ao lado, sem objetos órfãos. Testes automáticos: **650** verificações (Catalog 435 com os 11 novos).
- **Pendente da missão:** compor o bairro com o kit Shuriken (já baixado, 32 modelos), 3 tipos de oficina, equipamentos do pacote 3DAssets.dev (55 modelos CC0 já baixados), capturas antes/depois, medição de desempenho com 6 oficinas. Kenney não foi baixado (botão sem link direto). Origem e licença registradas em `docs/ORIGEM_ASSETS.md`; a licença do Shuriken **proíbe redistribuir os GLB** (ficam fora do GitHub).
- **Créditos:** os 14 carros são CC BY (crédito obrigatório). O jogo ainda não tem tela de créditos: **bloqueador de publicação**.

## 2026-11-07 — Renovação visual, etapa 2: bairro, 3 tipos de oficina e equipamentos reais
Decisão do Product Owner: como os logos foram removidos dos carros, a pendência de créditos de autor deixa de bloquear a publicação (continua registrada em `docs/ORIGEM_ASSETS.md`).
- **Bairro (`tools/BuildNeighborhood.luau`, `Workspace.Bairro`):** 17 casas/prédios (oeste, segunda fileira e rua lateral), 8 comércios (café, mercadinho, galeria, lava-rápido, posto, estacionamento, banca, outdoor), 43 itens de rua (22 postes, 4 pontos de ônibus, semáforo, telefone, jardineiras, caçambas, praças, placa de boas-vindas) e 18 carros estacionados (modelos do próprio jogo). Colisores simples invisíveis nas casas (20). As 18 árvores que ficavam dentro dos novos prédios e os postes procedurais antigos foram removidos. Fotos antes/depois feitas no Studio.
- **3 tipos de oficina (`WorkshopSkin`, derivado do nível empresarial que JÁ existia, sem sistema paralelo):** 1 Oficina de bairro (níveis 1–3: pilha de pneus, placa, lixeira, barril), 2 Centro automotivo (níveis 4–6: fachada de alumínio azul, marquise, totem, elevador, jardineiras), 3 Oficina premium (níveis 7+: grafite com LED dourado, letreiro de teto, vitrine com carro de exibição, refletores). A fachada muda sozinha, o jogador recebe o aviso "Sua oficina evoluiu: agora é ...", e o lote liberado volta ao tipo 1. Capacidade, vagas, preços e progressão não foram tocados. `Catalog.WorkshopTier` tem 4 testes novos.
- **Equipamentos reais:** os 11 equipamentos agora usam modelos do pacote de oficina (CC0, 1–5 mil triângulos) quando existem em `ServerStorage/Assets/Equipamentos`; o construtor procedural antigo continua como reserva.
- **Pipeline:** `blender_process_prop.py`, 57 props tratados e enviados sem moderação (cor lisa vira mini-textura; 0,3 a 5 mil triângulos, 30–600 KB). Os modelos do kit Shuriken (casas, lojas, ruas, cidade; 146 GLB) e do 3DAssets.dev (64 GLB) são low-poly sem marca nem placa legível.
- **Desempenho (Studio no PC, NÃO celular):** pior caso com as 6 oficinas premium, todos os equipamentos e 12 carros: 60 FPS; 6.636 instâncias no Workspace, 2.874 partes, 1.722 MeshParts, 42 luzes (sem sombra), 208 texturas únicas. Streaming desligado. A memória total do Studio (2,9 GB) inclui o próprio editor; não serve como medida do jogo.
- **Testes:** 654 verificações (Catalog 439). Verificador sem achados novos.
- **Não testado / pendente:** celular real (desempenho e toque), 2 jogadores reais, kit Kenney (não baixado: botão sem link), guia de estilo único para texturas (os props têm cores lisas, os carros têm textura: mistura aceitável mas visível), colisão do bairro com jogadores reais, as 3 oficinas em 6 lotes ao mesmo tempo com jogadores diferentes (testado só pela simulação), kit de casas interiores.

## 2026-11-07 — Revisão geral: carros com logo, NPCs comuns, cliente dirige até a vaga, praça
Pedido do PO: carros semi-realistas com logo (só sem placa), NPCs comuns da Roblox, nome combinando com o gênero, NPC não enroscar em placas, carro com colisão, **o cliente dirige o carro até dentro da garagem**, resto do jogo leve para celular, e deixar o jogo mais divertido.
- **Carros:** 20 modelos semi-realistas da Creator Store + o Esportivo vermelho (origem e autores em `docs/ORIGEM_ASSETS.md`), com logos e texturas originais, placas removidas, sem scripts. Convenção nova: `Raiz` (PrimaryPart no chão, frente = LookVector), `Casco` com colisão (o jogador esbarra no carro), banco do motorista. Os 18 carros estacionados do bairro foram trocados pelos novos (`tools/BuildNeighborhood.luau`).
- **Cliente dirige (novo `LotPath`):** o carro vem pela faixa (mão direita), encosta no meio-fio antes das entradas, o cliente desce, contorna o carro e espera na **calçada** com o balão da reclamação e o prompt **Atender** (aceita a ordem). Ao aceitar, ele volta ao volante e entra de frente na vaga; desce e espera atrás do carro, perto do portão (prompt Conversar = diagnóstico). Ao terminar/abandonar, volta ao carro, dá ré até a rua e vai embora. Dispensado ou sem paciência: sai do meio-fio direto para a rua. Prompts do carro só ligam depois de estacionado. A vaga fica marcada até o carro sair dela.
- **NPC não enrosca mais:** o cliente nunca anda até a placa do lote; a placa e a entrada foram para x = -14 (fora do corredor dos carros, `Layout.Driveway`); colunas da marquise e jardineiras das fachadas 2 e 3 saíram do caminho. Se travar, o NPC é reposicionado no ponto seguinte.
- **Gênero:** `Catalog.CustomerNamesMale/Female` + `Catalog.PickCustomer`; o modelo vem do mesmo gênero (`NpcKit.Pick`). Etiqueta com o nome sobre a cabeça.
- **Diversão:** cliente **VIP** (8%): chega num esportivo, paga o dobro, etiqueta dourada "★ VIP" e aviso especial. Praça central nova (`tools/BuildPlaza.luau`): piso, chafariz com jato, 4 árvores, bancos, postes e o painel ao vivo **"Melhores oficinas do servidor"** (top 5 por reputação, atualizado a cada 15 s).
- **Vagas:** profundidade 18 → 22 (picapes de 20,5).
- **Testes:** 807 verificações passam (Catalog 592 com gênero, VIP e veículos). Play testado no Studio: chegada, espera na calçada, aceitar, entrada na vaga, cliente desce, abandonar → ré e saída, dispensar no meio-fio → saída.
- **Não feito / não testado:** a garagem `ONLY+GRAGE.fbx` (94 MB) dos Downloads não foi importada (Blender fechado e pesada demais para celular; o prédio atual com equipamentos CC0 continua). Movimento do carro é feito pelo servidor (pode parecer menos suave com rede ruim). Não testado em celular nem com 2 jogadores reais. Os logos de marcas são risco de moderação (decisão do PO).

## 2026-11-07 — Ideias do PO (lote 2): oficina física, carros "de verdade", funcionários, expansão e rivais
**Testado no Studio (Play) e integrado ao main.** Conferido em jogo: aceitar longe da TV é recusado e na TV funciona;
conversar a 30 studs do cliente é recusado e de perto abre o diagnóstico; comprar longe da loja é recusado e na loja
funciona; carro sobe no elevador ao começar o reparo e desce ao cancelar; contratar mecânico pelo quadro e ele concluiu
um serviço sozinho (+90 moedas, 4 estrelas); expandir pela placa constrói o anexo e o carro entra no Box 3 pelo caminho
interno; 3 rivais ocupam lotes com placa e fachada; rodas detectadas em todos os carros; placa "LOTE LIVRE" nos lotes vazios.
Correções achadas no teste: campos da placa 3D (impedia os rivais), postes da placa cobriam o texto, prompts das estações
perto demais (o HUD mostra um por vez: quadro foi para o fundo e alcance caiu para 8), rivais ganhavam todos os clientes
(agora disputam ~30% do mercado, Config.RivalMarketShare). 827 verificações automáticas passam.
- **NPC:** um nome só sobre a cabeça (nome nativo do Humanoid; VIP com ★ e selo "VIP"); balão de fala pequeno, em studs
  (encolhe com a distância) e visível só a até 26 studs.
- **Carros (client/VehicleFx):** rodas giram conforme a distância percorrida (detectadas pela geometria), som de motor
  com tom pela velocidade; defeito visível no carro estacionado (motor = fumaça no capô e escapamento + chiado; elétrica =
  faíscas azuis, luz piscando e zumbido; pneu = pneu murcho com fumaça; suspensão = roda torta); no reparo o pneu sai do
  carro, o capô abre (quando o modelo tem capô separado), parafusadeira/catraca e faíscas de trabalho.
- **Elevador:** cada box tem plataforma elevatória; o carro sobe durante o reparo (som hidráulico) e desce antes de sair.
- **Oficina física (StationService):** TV de ordens (aceitar SÓ na TV), prateleira do estoque, quadro de funcionários;
  conversar/diagnosticar SÓ perto do cliente (10 studs ≈ 3 m); comprar SÓ na Loja de Autopeças do bairro. Longe da
  estação, os botões Estoque/Loja e o "Aceitar" mostram uma luz-guia até ela. O guia do 1º atendimento aponta a TV e a loja.
- **Mochila:** até 12 peças carregadas (para reparos fora da oficina no futuro); passar peças na prateleira.
- **Placa 3D da oficina (totem):** atualiza sozinha a cada 6 s: tipo da oficina, nome, nível, nota, clientes atendidos,
  reputação, posição no servidor ("A MELHOR OFICINA DO SERVIDOR" para o 1º). A TV mostra os clientes esperando.
- **Expansão:** placa "Área de expansão" no pátio esquerdo (1.500 moedas) → anexo coberto com o Box 3 (elevador incluso);
  o carro chega pelo corredor principal e um caminho interno. Equipamentos do pátio esquerdo foram para outros cantos.
- **Funcionários:** contratar (300) no quadro; salário de 60 a cada 5 min; até 2. Atendem sozinhos carros estacionados
  (diagnóstico + elevador + reparo em 40 s, qualidade 72%, sem XP para o dono); sem peças/equipamento avisam e tentam
  de novo em 1 min; sem dinheiro para o salário, um pede demissão. Validação de mercado: Retail Tycoon 2 e Restaurant
  Tycoon 2 usam contratação + expansão (nenhum módulo pronto para oficina; feito do zero).
- **Oficinas rivais (RivalService):** até 3 rivais NPC com nomes de jogador ocupam lotes livres (sempre sobram 2), com
  totem, fachada pelo tipo, mecânico, clientes chegando de carro, elevador e estatísticas que crescem; disputam clientes
  no mercado e aparecem no ranking e no painel da praça. Quando falta lote para quem entra, um rival "vende" e sai.
- **Testes:** CatalogTest ganhou checagens de estações, placa, anexo e configurações (rodar no Studio).
- **Pendente:** ouvir os sons no jogo (ids públicos; não dá para conferir áudio pelo Studio via MCP), testar no celular,
  2 jogadores reais disputando lotes com rivais.

## 2026-11-07 — Lote 3: 4 níveis de oficina, Construtora, equipamentos interativos, som ambiente e música
Ideias do Alan, avaliadas e ajustadas (validação e balanceamento pelo dono do projeto):
- **4 níveis de prédio** (`shared/WorkshopLevels.lua`), cada um maior que o anterior, montados pelo servidor com
  materiais de verdade (tijolo, concreto, metal ondulado, vidro), portas de enrolar, letreiro com LED na cor do nível,
  luminárias, sala lateral (prateleira), **sala dos fundos com os equipamentos** e pátio de asfalto com portões
  **ENTRADA** (x = 40) e **SAÍDA** (x = 31). Os carros entram pelo portão, circulam no pátio e entram de frente em
  qualquer box; saem de ré para a fileira de saída e vão pelo portão de saída (testado com o box mais distante).

| Nível | Prédio | Boxes | Moedas | Nível da oficina | Reputação | XP (soma das habilidades) | Equip. instalados | Cabem equip. | Funcionários |
|---|---|---|---|---|---|---|---|---|---|
| 0 | Garagem de bairro | 1 | — | — | — | — | — | 3 | 0 |
| 1 | Oficina | 2 | 1.500 | 4 | 20 | 8 | 3 | 5 | 0 |
| 2 | Centro automotivo | 4 | 6.000 | 8 | 70 | 14 | 5 | 8 | 1 |
| 3 | Oficina premium | 6 | 18.000 | 13 | 160 | 22 | 8 | 12 | 2 |

  Estimativa: nível 1 em ~8 serviços, nível 2 em ~25, nível 3 em ~60 (serviço médio ~200 moedas, 1–6 de reputação e
  22–90 XP). O próprio prédio limita quantos equipamentos cabem: crescer o prédio é o que libera os serviços maiores.
  Ordens abertas = boxes + 1. Perfis antigos (que já atendiam) começam no nível 1; quem comprou o anexo antigo recebeu
  as 1.500 moedas de volta (o anexo deixou de existir).
- **Construtora** (o bloco liso "Distribuidora" do bairro virou prédio com vitrine, toldo e letreiro): prompt
  "Ampliar oficina" abre a tela com o prédio atual, a próxima obra e os requisitos em verde/vermelho; a obra só
  acontece com os boxes vazios. A Loja de Autopeças também ganhou fachada de verdade.
- **Funcionários** só a partir do nível 2 (quadro de funcionários aparece no prédio): 1 no nível 2, 2 no nível 3.
  Equilíbrio: o mecânico NPC só pega um carro quando há **2 ou mais** esperando (sempre sobra trabalho para o jogador)
  e leva 60 s. Contratar jogadores continua pelo convite de colaboração por ordem (já existia).
- **Equipamentos interativos:** cada máquina comprada aparece na sala dos fundos com o prompt **"Usar"**; reparo que
  precisa de máquina começa nela (o jogador vai até a desmontadora, o scanner, a bancada...). Ferramenta de mão (kit
  básico) continua no próprio carro. Comprar equipamento além do que cabe pede ampliação.
- **Som ambiente e música** (`client/AmbientAudio`): cidade de dia na rua, galpão industrial dentro da oficina (troca
  sozinho ao entrar/sair), playlist de 6 faixas licenciadas (APM Music: funk, hip-hop, chill) com botão ♪.
- **Correção:** rodas giravam para trás.
- **Rivais:** prédio pelo mesmo critério dos jogadores (nível 0–3 pelo faturamento).
- **Testes:** 787 verificações (CatalogTest com os níveis: boxes, tamanhos, alcance do pátio, requisitos, espaço de
  equipamentos). Play no Studio: prédio nível 2 com 4 boxes, carro entrando pelo portão no box mais distante e saindo
  pelo portão de saída, tela da Construtora, compra de equipamento na loja e "Usar" na máquina.
- **Pendente:** ouvir as músicas/ambiente no jogo (ids licenciados; o MCP não reproduz áudio), celular, revisar a
  aparência dos 4 níveis em foto lado a lado, prédio do nível 3 com 2 funcionários em ação.

## 2026-11-07 (madrugada) — Revisão total: auditorias por skill + retenção
Detalhes em `docs/AUDITORIA_GERAL.md`. Resumo:
- **Auditorias** (segurança/dados, desempenho/celular, retenção/design) com as skills fwjelaa. Sem falhas críticas;
  7 achados de segurança e 4 de desempenho corrigidos; plano para os demais.
- **Retenção nova**: recompensa diária (7 dias), 3 missões diárias, 14 conquistas, códigos promocionais, Hora do Rush
  (servidor inteiro), combo do turno; tela "Metas" (botão 🎯 com aviso) e faixa do Rush.
- **Primeiro minuto**: 1º cliente imediato, 2 primeiros defeitos resolvíveis com o estoque inicial, guia levando à TV
  com luz-guia, funil do guia no Analytics.
- **Testes**: 815 verificações (nova suíte ProgressTest). Play no Studio: tela Metas abriu sozinha, diária, código,
  missão, Hora do Rush com aviso, faixa e clientes em dobro conferidos.
