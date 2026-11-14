# Oficina 24H — V2-15 | Hardening, acessibilidade, streaming e auditoria de release

**Implementação de engenharia:** 13/11/2026, branch `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13`, PR #27 em **draft**. Nenhum merge na main, nenhum teste de física/UX no Roblox Studio declarado, nenhuma publicação. A V2-15 não destrava os portões V2-11 a V2-13 e não elimina a pendência de lotes/fornecedores FIFO V2-08.

**Ordem de prioridades:** preservar OS V1 e pagamentos idempotentes → segurança dos remotos → não executar assets de terceiros → limites de CPU/partículas/physics → feedback do negócio → acessibilidade sem alterar os resultados → licenças e QA física.

## 1. Problemas reais encontrados e correções de código

### 1.1 RemoteEvent / RemoteFunction — rate limit transversal

**Antes:** o dispatcher da V1 tinha cooldown por **ação**, proteção de `RepairAction` por sessão e `DriveInput` separado (14 Hz), mas um cliente modificado poderia distribuir o spam por dezenas de ações conhecidas e mandar tabelas profundamente aninhadas. A função de snapshot possuía cache de 0,4s, mas nenhuma limitação global de consultas.

**Depois:**

- `src/shared/V2RemoteSecurityRules.lua` implementa contador de tokens por jogador e um validador **antes** do dispatcher: máximo de 44 solicitações em rajada e recuperação de 26 tokens/s para a soma de todas as ações; snapshot até 12 em rajada e 8/s. O veículo permanece em seu canal distinto de comando analógico com limite existente.
- `PayloadValid` para na entrada 121 de uma estrutura remota; profundidade máxima de 5 tabelas, texto até 512 bytes, chaves com até 64 bytes; rejeita `NaN`, infinito, índices negativos/excessivos, tipos Roblox Instance e referências circulares. Esse código não interpreta JobIds, saldos, preços nem provas de resultado.
- O `Main.server.lua` aplica orçamento e validação antes de `CheckRepairResult`, `RepairAction`, loja, reparo e economia. Limpa os orçamentos ao desconectar. Uma negativa de limite não é moeda/reputação negativa: solicitações não são executadas.
- `GetSnapshot` responde `Ready=false,Throttled=true` sob abuso; `Store.Refresh` ignora o payload temporário e mantém o último snapshot válido, sem sobrescrever dados com erro.
- Não declarar **DDoS protection geral**; isso limita apenas remotes do jogo e não substitui proteções da plataforma nem prova que um atacante não encontre outro vetor.

**Risco para Studio:** confirmar `RepairAction` a 10 Hz, tentativa de reenvio e `Checkout` grande não sofram bloqueio indevido com ping alto. Testar 2 jogadores e 40 tipos de ações simultâneas contra o mesmo servidor.

### 1.2 Modelos, PBR, física e NPC — controle antes de Clone()

**Antes:** `V2DriveService.visualShell` verificava o tamanho depois do `Clone`, possibilitando spikes de memória na presença de asset de marketplace com muitos componentes. `V2NeighborhoodAmbient` também clonava os modelos da biblioteca local sem preflight completo.

**Depois:**

- `V2VisualBudgetRules.PreflightTemplate` exige um `Model` com pelo menos uma peça, no máximo **95 peças e 350 descendentes** para o casco dirigido e **90 peças/280 descendentes** para o ambiente; máximo **24 SurfaceAppearances**; limita caixa a 50×25×60 studs antes de clonar. Os limites são de engenharia, não medição de performance.
- `V2DriveService` usa esse preflight **antes** do `Clone()`. Se não passar, volta ao Hatch físico procedural de V2-11, sem bloquear o tutorial e sem executar scripts de terceiros. Depois do clone, `AssetSafetyRules.StripScripts` continua retirando Script/LocalScript/ModuleScript antes de Parent no Workspace.
- Máximo de **cinco rigs dirigíveis simultâneos por servidor**, com mensagem de indisponibilidade em vez de tentar simular ilimitados; continuam com `SetNetworkOwner(nil)`, `VehicleSeat`, controle exclusivo do dono, queda/colisão/teleporte retornando ao box.
- `V2NeighborhoodAssets.Publish` e `V2NeighborhoodAmbient.create` preflightam avatares/carrocerias antes de publicar/clonar; figurantes permanecem **somente locais**, sem física/collide/touched/credit, com pool, culling e orçamento adaptativo por FPS e touch da V2-07.
- **`Workspace.StreamingEnabled` é propriedade do place no Roblox Studio.** O script não a altera nem finge que foi ativada; `V2ReleasePlaceAudit` gera `WARN` quando estiver desabilitada.

**Risco para Studio:** limites de Part não capturam tamanho real de texturas GPU ou triângulos do `MeshPart`. Um asset pode passar preflight e ainda ser caro. Confirmar Memory, FPS, GPU, velocidade e física reais em celular fraco, PC médio e multiplayer.

### 1.3 Recompensa de frota V2-14 — falha de Save e confirmação correta

**Antes:** `ContractService.endContract` mudava a chave, moedas/reputação e marcava o contrato como cumprido **antes** da confirmação de `DataService.Save`, chamando um Save diferido. Um servidor que caiu nessa janela poderia anunciar recompensa não persistida.

**Depois:**

- A prova idempotente `RecordFleetOutcomeOnce` continua mudando `FleetAccounts`, saldo e reputação no **mesmo** perfil e sem yield (não usa o ledger do colaborador).
- `endContract` mantém `c.Settling=true` durante Save, chama `pcall(data.Save,player)` e somente **após sucesso** remove o contrato, abre cooldown, anuncia sucesso e avisa demais jogadores. Liga semanal é marcada uma vez **antes do Save**.
- Se Save falhar, `c.Settling=false`; o contrato fica pendente, exibe `PendingSettlement` e o watchdog chama `RetryPending`. Registro duplicado da mesma chave retorna `Duplicado.` e não credita moedas, pontos da liga nem reputação novamente. UI da aba Equipe mostra **“SALVAMENTO PENDENTE”**; nunca sucesso antecipado.
- **Limitação:** uma falha de disco/servidor antes de qualquer Save válido ainda pode perder as mudanças não persistidas; não há transação cross-server ou crédito mágico. O usuário deve saber disso. Nem a V2-15 altera o comportamento de contrato *parcial* descartado ao logout, herdado da V1.

**Risco para Studio:** o Save agora pode ceder execução no caminho que finaliza o contrato de frota, portanto testar a conclusão da OS V1 e o recibo com DataStore lento/falhando; evitar deadlock do autosave e medição de latência de `rateService`. Fake DataStore não prova performance real.

## 2. Acessibilidade / interface / idioma

**Mudanças de código:**

- `src/shared/V2AccessibilityRules.lua`: preferências **persistentes e limitadas a três booleanos** — `DriveHaptics`, `DriveSfx`, `LowDetail`. `false` não é perdido na sanitização. Rejeita chaves desconhecidas como `Coins`, e nenhuma opção altera diagnóstico, velocidade, dinheiro, XP ou reputação.
- `DataService.SetAccessibility`, `WorkshopService.SetAccessibility` e `Main.server.lua` aceitam a alteração validada e gravam no perfil v15 de modo aditivo, sem nova migração destrutiva.
- Em **Ordens → Equipe** há três toggles legíveis para controle com vibração, som de alertas e menos figurantes 3D. Nenhum modal que escurece gameplay e nenhuma nova ação na HUD.
- `V2DriveControls.client.lua` respeita os dois primeiros controles e reduz FOV no modo visual leve. **Texto de sintoma e contexto de checkpoint permanecem disponíveis** quando som/vibração estão desligados.
- `V2NeighborhoodRules.Budget` e o cliente ambiente limitam a dois pedestres e um carro, no máximo, no `LowDetail`. O modo padrão permanece igual ao V2-07.
- `src/client/UI/Panels/Profile.lua` ganhou a aba **Créditos**, reutilizando o layout compacto com scroll para expor os autores e fontes registrados. `V2Credits` guarda fontes e pendências de direitos como dados do projeto.

**Estado real da localização:** `src/shared/Locale.lua` só possui `pt-BR`. A infraestrutura tem `Locale.SetLanguage`, mas não existe tradução `en-US` integral. A V2-15 **não** promete uma versão internacional. Incluir locale inglês e revisar strings recentes dos módulos V2 caso o produto vise lançamento fora do Brasil. Confirmar teclado/gamepad/touch e leitores de tela disponíveis em Studio/device: testes automatizados não substituem acessibilidade humana.

## 3. Auditoria de licenças: bloqueadores de publicação

**Fonte de verdade do inventário:** `docs/ORIGEM_ASSETS.md` e `docs/GUIA_UNICO_ASSETS_V2.md`. A presença de “grátis” no catálogo não prova licença comercial, autoria ou direito de redistribuição.

**Pendências já documentadas no projeto e que continuam abertas:**

1. Sprites do HUD/painéis derivados de imagens de referência: **autoria/licença a confirmar**. Revisar ou substituir com imagens próprias e registrar a fonte.
2. Pacote de ícones entregue por terceiro: autorização apenas verbal; obter liberação **por escrito** ou substituir por licença explícita.
3. Veículo esportivo vermelho originalmente disponibilizado pelo proprietário: licença de uso comercial e origem ausentes.
4. Marca, logos e carrocerias reconhecíveis de veículos do catálogo: revisar regras atuais de Roblox e propriedade intelectual para publicação.
5. Arquivos Sketchfab **CC BY 4.0** da frota histórica: se forem reativados, atribuir cada autor/URL originais — a troca por assets atuais não prova que não permaneceu um carro antigo no place.
6. Assets Shuriken são permitidos em jogo conforme o registro, mas **redistribuição dos GLB avulsos é proibida**. Não inserir arquivos de terceiros no GitHub público ou Creator Store.
7. Sons de ProSoundEffects/APM/terceiros possuem IDs Roblox em `SoundIds.lua`; testar se realmente carregam no place e se seus direitos se aplicam ao uso final. Tela de créditos não substitui autorização.

**Resultado:** a nova tela exibe atribuições e avisos, mas **V2-16 publicação permanece bloqueada enquanto pendências legais forem verdadeiras**.

## 4. CI, inventário de testes e cenários adversos

| Área | Cenário de regressão escrito | Critério de falha |
|---|---|---|
| Remotos | `V2RemoteSecurityTest.luau`: NaN, infinidade, Instance, 121 entradas, profundidade, ciclo, spam de 100 ações, refil e snapshot flood | Qualquer payload inválido aceito ou limite inoperante |
| Física | `V2RuntimeAssetBudgetTest.luau`: clone sem peças, asset gigante, 96 peças, excesso de Attachments/PBR, mais de cinco rigs | Asset excessivo clonado ou rig ilimitado |
| Persistência | `V2FleetContractTest.luau`: última OS, Save falha após crédito em memória, retry, comprovante único, liga sem replay | Mensagem de sucesso anterior a Save, bônus repetido ou contrato perdido no retry |
| Acessibilidade | `V2AccessibilityTest.luau`: false preservado, valores forjados, defaults, limites de bairro, configuração independente de economia | Preferência ignora escolha, altera XP ou quebra orçamento de mobile |
| Perfil | `PersistenceTest.luau` com fake DataStore A/B: desligar Haptics/Sfx, LowDetail, Save/Load, sem alterar saldo/rep | Falsa persistência ou corrupção de perfil legado |
| Direitos | `V2CreditsTest.luau`: atribuição e fonte exigidas, blockers conhecidos | Crédito ausente, duplicado ou texto que sugere licença já resolvida |
| Place | `V2ReleasePlaceAudit.luau`: StreamingEnabled, modelos importados, scripts externos, sons, rigs e orçamento | P0 de scripts no preview ou rigs excessivos; WARN para assets/licenças/testes não verificáveis |
| Compatibilidade | `RunAllTests.luau`: as suites antigas de OS/ledger/reparos e novas V2-00–15 | Falha/erro de require/compilação dos scripts na sessão Studio Edit |
| CI | `tools/ci/verify_contracts.py` e Rojo no GitHub Actions | O commit não compila ou há rota de contrato, rede ou crédito removida |

**CI do GitHub** executa contratos de texto/propriedades e build Rojo code-only. **Não executa Roblox Lua**, não baixa os assets importados do Windows e não confirma FPS, licenças, qualidade visual, streaming, som, física nem DataStore publicado. As suítes Luau são escritas, mas ainda aguardam execução por Claude/proprietário no Studio.

### Matriz adversarial para Play Solo / Start Server (V2-16)

1. Jogo sem `ServerStorage.Assets` e com três carros reais; verificar fallback e que nenhum asset excedente é clonado/executado. Câmera, física, torque, colisões e retorno de segurança com 1 e 2 jogadores.
2. Abrir 6 carros simultâneos em múltiplas oficinas (se houver 6 players), verificar que o sexto é recusado, que os cinco rigs vivos não excedem a memória-alvo e que o sexto pode tentar após um retorno.
3. `RemoteEvent.Action` com arrays gigantes, string 1000 bytes, infinito, `Checkout` inválido, comandos `RepairAction` fora de ordem e spam de ações distintas; nenhuma peça, moeda, XP ou reputation muda. Cliente honesto com ping alto consegue terminar todos os 15 tipos de reparo.
4. Simular Save falho uma vez (DataStore mock) e com API Services em Studio. Ver `PendingSettlement`, não receber mensagem falsa, retry único e histórico depois de rejoin. Confirmar que `rateService` não retém outros jogadores.
5. Revalidar 15 serviços V1, NPC, colaboração, staff, contrato, UsedMarket, Showroom, 2 lojas e progressão; não reabrir comprovante consumido.
6. Alternar toggle visual durante tráfego pesado; 1–2 NPCs visuais e um carro no modo leve; nunca remover clientes reais/caminhões da OS.
7. Dirigir com som desativado, controles de vibração desativados, toque e gamepad. Confirmar leitura da pista por texto e retorno ao box; alto contraste e tela compacta.
8. Verificar menu Perfil → Créditos em celular e desktop, copiar autores para inspeção individual no Creator Hub, remover/substituir todos os assets com licença pendente e testar ID de áudio que não carrega.
9. Estimar `StreamingTargetRadius`, `StreamOutBehavior`, FPS mínimo/médio e memória GPU com perfis desktop/celular; ativar/ajustar StreamingEnabled pelo **Studio**, não por script de jogo.
10. Testar Play Solo, Start Server 2, rejoin e beta fechado. Marcar [S] só com evidência real (logs, screenshots e notas de versão) e aprovação do proprietário.

**Não avançar a release por ter CI verde.** `V2DriveScenarioRules.LiveEnabled=false` é mantido até a física V2-11 passar no Studio; V2-08 fornecedores/FIFO segue incompleta. A fase V2-16 exige decisão explícita de publicação.
