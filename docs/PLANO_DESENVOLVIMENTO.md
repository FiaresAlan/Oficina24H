> **Plano histórico.** As fases futuras passam a ser planejadas em [CHECK_LIST_MESTRE_V2.md](CHECK_LIST_MESTRE_V2.md), com acompanhamento em [Issue #26](https://github.com/FiaresAlan/Oficina24H/issues/26). C1–C17 permanecem rastreadas pela Issue #15. Nenhuma fase de gameplay V2 foi iniciada.

# Plano de desenvolvimento — Oficina 24H

Atualizado em 2026-11-05 (sessão autônoma, sem o usuário presente). Estado detalhado e histórico: `PROGRESSO.md`.

## 1. Onde estamos

Jogável como protótipo de 1 jogador no Studio: o jogador entra, ganha um lote com oficina, recebe clientes, aceita ordens
(o carro aparece numa vaga), diagnostica e repara chegando perto do carro (prompt de proximidade), recebe moedas/XP/reputação,
compra equipamentos que aparecem fisicamente no pátio, e tudo é servidor-autoritativo. Há HUD e quatro painéis, persistência
robusta (testada com DataStore simulado) e 231 verificações automáticas.

Validação automática (rodar `tools/RunAllTests.luau` no Edit via MCP): CatalogTest 267, PlotTest 27, PersistenceTest 35 (329 verificações) — todas passam.
Achados de balanceamento encontrados pelos testes e já corrigidos: Funilaria sem serviços; Bancada de Motor e Elevador sem
serviço que os exigisse; ordens impossíveis prendiam a vaga; 86% dos clientes eram impossíveis para novato; botão de cliente
sem cooldown (farm de moedas). **Ainda aberto:** não há custo recorrente (aluguel/energia) — o dinheiro só tem sumidouro em
equipamentos e peças; ver Fase A.
Validação manual em Play (1 jogador, remotes reais): fluxo completo, distância, recusa/abandono de ordem, compra com modelo
físico, 18 payloads maliciosos sem efeito e sem erros no console, rate limit (1 resposta em 40 disparos).

## 2. O que NÃO está validado (riscos reais)

| Risco | Por que importa | Como fechar |
|---|---|---|
| DataStore real nunca foi exercitado | Place não publicado; toda a persistência foi testada só com mock | Publicar o place de teste, habilitar API Services, jogar, sair, voltar |
| Multiplayer real (2+ jogadores) | Convite/colaboração/divisão de pagamento/visita só testados por leitura de código | Studio: Teste > Servidor e clientes com 2 clientes (ver §5) |
| Mobile | UIScale/tamanhos de toque foram projetados, não vistos | Emulador de dispositivo do Studio ou celular real |
| Desempenho | 300 partes + 6 garagens de 3 MeshParts; sem StreamingEnabled; não medido | MicroProfiler/Stats em Play com 6 clientes |
| Aparência da UI | Só medida por geometria, nunca vista em captura | Captura no Play depois de resolver o foco de janela |
| Assets importados | Só 4 GLB (garagem + 3 carros); upload pelo Studio foi manual e exigiu a janela certa | Aprovar pasta de upload no Assistant (ver §5) |

## 3. Roadmap

Cada fase termina com testes automáticos novos onde possível e checkpoint (`.rbxlx` salvo + `PROGRESSO.md`).

### Fase A — Fechar o loop de 1 jogador (quase pronta)
- [x] Terrenos, oficina, vagas, veículos físicos, diagnóstico/reparo por proximidade, pagamento, XP, reputação.
- [x] Recusar/abandonar ordem, cliente que desiste (300 s), reclamação nem sempre = defeito real (35%).
- [x] 15 defeitos/serviços cobrindo as 5 especializações; 11 equipamentos com modelo físico.
- [ ] Sons e feedback de reparo (faísca/barra de progresso); animação do personagem. Critério: toda ação tem feedback visual e sonoro.
- [x] Peças como consumível: 14 peças, estoque persistido, loja de peças (UI), reparo consome peças (tudo-ou-nada), estoque inicial.
- [x] Clientes ponderados pela capacidade da oficina (`shared/JobRules`): 68% atendíveis para novo jogador; antes 1 em 14.
- [x] Anti-farm: cooldown de 20 s no botão "Receber cliente"; clientes também chegam sozinhos a cada 45 s.
- [ ] Manutenção/custos operacionais periódicos (aluguel, energia) para evitar inflação. Critério: saldo de jogador ocioso decai até o piso.

### Fase B — Persistência completa
- [x] Perfil v2 (moedas, rep, XP, equipamentos, histórico), trava de sessão, retentativas, migração, BindToClose.
- [ ] Persistir lote preferido, expansão da oficina, funcionários NPC, ordens em andamento.
- [ ] Teste com DataStore real e 2 servidores (depende de publicar).

### Fase C — Multiplayer e economia competitiva
- [x] Convite com divisão, colaborador mantém XP, NPC sem XP ao dono, colaborador pode sair, 1 colaborador por ordem.
- [ ] Contraproposta de porcentagem (hoje o dono define; o profissional só aceita/recusa).
- [ ] Acesso do colaborador restrito à ordem autorizada (hoje ele só consegue agir na ordem; falta liberar a entrada física no lote).
- [x] Clientes NPC escolhem oficina por preço, reputação, especialização, distância e fila (`shared/CustomerRules`, `DispatchCustomers`).
- [x] Preço editável pelo dono (70% a 150%, passo 5%, persistido, fixado na ordem), panfletos pagos (15 moedas), ranking das oficinas online.
- [x] Avaliações dos clientes (1 a 5 estrelas por preço, espera, qualidade e executor), ligadas à reputação e à atratividade.
- [ ] Publicidade de longo prazo, ranking persistente entre servidores (OrderedDataStore), avisar o dono quando um colaborador recebe a nota.
- [ ] Visitação de outras oficinas (permissões de leitura; sem alterar dados alheios).
- [ ] Funcionários NPC persistentes com salário e especialização.

### Fase D — Mundo e arte
- [x] Bairro-base: ruas, calçadas, 6 lotes, muros, postes, árvores, cones (modelo Roblox oficial), letreiros.
- [x] Interior acessível da oficina (procedural em Parts: recepção, estantes, bancada, luzes, quadro de preços). - [x] Veículos no prédio: 2 vagas sob o portão ampliado; equipamentos pequenos dentro, grandes (Elevador, Alinhador, Máquina de pneus, Kit de funilaria) no pátio; layout único em `shared/Layout` com teste de colisão. Pendente: medir desempenho (1055 partes, 42 luzes).
- [ ] Loja de autopeças e distribuidora com modelos próprios; NPCs ambientais; veículos circulando.
- [ ] Importar kits de rua (Shuriken) e industriais (Kenney) para substituir blocos.
- [ ] Peças removíveis nos carros (capô, rodas) animadas durante o reparo.
- [ ] Ciclo dia/noite com postes acendendo.

### Fase E — UI e acessibilidade
- [x] HUD, Ordens, Habilidades, Loja de equipamentos, Perfil, convite; textos em Locale.
- [x] Cinco painéis novos (Perfil, Estoque, Loja de Peças com carrinho e compra no servidor, Habilidades, Ordens). HUD novo (barra superior, menu lateral minimizável, clientes aguardando, painel de ordem, perfil, avaliação, sino, estoque, ranking). Pendentes: contratação, expansão do terreno, configurações, sair.
- [ ] Revisão em celular/tablet; gamepad; localização en-US.

### Fase F — Qualidade e publicação
- [ ] Teste de 6 jogadores simultâneos; medição de desempenho; StreamingEnabled se necessário.
- [ ] Revisão de licenças (Polyfork exige conferência; Kenney/Grab3D CC0; Cone é da Roblox).
- [ ] Revisão de segurança final com o agente `roblox-reviewer`; checklist de publicação.

## 4. Melhorias propostas (priorizadas por impacto/esforço)
1. **Peças + loja de peças** (alto impacto no loop; reaproveita DataService/Catalog).
2. **Escolha de oficina pelo cliente** (liga competição, reputação e preço — pilar do jogo).
3. **Interior da oficina** (identidade visual; hoje o jogador trabalha no pátio).
4. **Feedback de reparo** (som, partículas, barra de progresso): maior ganho de "game feel".
5. **Contraproposta** e visita de oficinas (pilar social).
6. Configurações (volume, idioma) e acessibilidade.

## 5. Dependências do usuário (não resolvidas por mim)
- **Publicar** o place de teste e habilitar *API Services* para validar DataStore (não publico sem ordem expressa).
- **Aprovar a pasta** `Desktop\OFICINA24h` em *Assistant Settings → MCP Permissions* para o upload de GLB por Open Cloud
  (hoje bloqueado; não contorno). Alternativa manual: botão Importar do Studio, com a janela do place em foco.
- **Teste com 2 jogadores**: no menu Teste, usar "Clientes e servidores" com 2 jogadores; tentei por "Servidor e clientes"
  e só abriu o servidor sem clientes.
- Studio exibe "Reiniciar para atualizar"; não reiniciei para não perder o estado aberto.
- Cuidado operacional: há outro place seu aberto ("Local de FalconRev: 11062026_1"). Esta sessão **não** o alterou, mas o
  plugin Rojo dele recebeu a oferta de conectar ao nosso servidor (recusada). Se for retomar com Rojo, conectar só no place certo.

## 6. Como retomar
1. `rojo serve default.project.json` na pasta do projeto (Rokit fixa a versão 7.7.1).
2. Abrir `Downloads\Oficina24H_Teste.rbxlx` no Studio e conectar o Rojo.
3. Rodar `tools/RunAllTests.luau` (clone + require no Edit) e conferir que tudo passa.
4. Regenerar mundo se necessário: `BuildWorld` e depois `BuildScenery` (mesmo método de clone + require).
5. Salvar: janela do place em foco + Ctrl+S; confirmar pelo LastWriteTime do arquivo.
