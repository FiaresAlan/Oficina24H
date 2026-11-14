# CHECK_LIST_MESTRE_V2 — OFICINA 24H

**Versão:** 2.9, 13/11/2026. **Situação:** engenharia V2-00–16 + auditoria de pré-entrega incorporada à PR #27, **NÃO RELEASE**. Soluções de reparo agora só no servidor; bônus de frota pós-Save; compatibilidade com correções de Studio da V1 portada estaticamente. V2-12/13 desligadas; V2-08 FIFO, conflitos com main, licenças, Studio e beta continuam bloqueando publicação. **Nenhuma homologação Studio da V2 presumida.**  
**Direção aprovada pelo proprietário:** híbrida — estilização legível do mundo + reparos visualmente mecânicos + gestão de negócio.  
**Código base de referência:** main em C31 (`2690f082` antes dos commits exclusivamente documentais da V2). **Atenção:** o Claude Code está homologando/corrigindo a V1 em paralelo; sempre ler novo HEAD e reconciliar diffs antes de programar V2. Preservar Issue #15 V1 como histórico.  
**Documentos de referência:** DIRECAO_JOGO_V2_2026-11-13.md, PESQUISA_MERCADO_V2_2026-11-13.md, AUDITORIA_V2_BASE_CODIGO_2026-11-13.md (auditoria histórica até C17), [GUIA_UNICO_ASSETS_V2.md](GUIA_UNICO_ASSETS_V2.md) e GUIA_UNICO_ASSETS_V1.md.

## Regra de preenchimento
- [C] = código e teste de regressão escritos e integrados.
- [A] = verificações automáticas e Rojo executados com sucesso no commit final.
- [S] = jogo **realmente** testado no Roblox Studio / dispositivo.
- Nada é marcado [x] por ter sido planejado. **Código implementado está em branch V2, ainda não na main**; checkboxes [C] históricos de integração seguem pendentes do merge/reconciliação. Ver quadro de execução abaixo.
- O proprietário pretende executar a homologação Studio ao final. Isso não dispensa testes de código em cada etapa e mantém riscos de integração abertos.
- Implementar **o máximo de fases completas e seguras possível por rodada**. Agrupar somente quando dependências, revisão, testes e CI permitirem; sem limite arbitrário de quantidade nem redução de qualidade.

## Sequência e bloqueios

| ID | Entrega | Natureza | Depende de |
|---|---|---|---|
| V2-00 | Auditoria e compatibilidade com a fundação C1–C31 | P0 | main atual |
| V2-01 | Bible visual híbrida + 3 carros piloto | P0 | V2-00 |
| V2-02 | Recepção e gestão visível da fila/negócio | P0 | V2-00 |
| V2-03 | Carros interativos, capô/portas/rodas | P0 | V2-01 |
| V2-04 | Reparos mecânicos ricos nos 15 serviços | P0 | V2-03 |
| V2-05 | Funcionários supervisionáveis e caminhos | P0 | V2-02/04 |
| V2-06 | Upgrades físicos claros e seguros | P0 | V2-02/03 |
| V2-07 | Bairro vivo com orçamento de NPCs | P0 | V2-01/05 |
| V2-08 | Gestão de custos, estoque e margem | P0 | V2-02/05 |
| V2-09 | Compra, reparo e revenda: protótipo | P1 opcional | V2-03/08 |
| V2-10 | Personalização, coleção, showroom | P1 opcional | V2-09 |
| V2-11 | Veículo da OS dirigível pelo jogador | P1 opcional | V2-03/07 |
| V2-12 | Diagnóstico por test-drive contextual | P1 opcional | V2-11/04 |
| V2-13 | Test-drive pós-reparo e retrabalho | P1 opcional | V2-12 |
| V2-14 | Contratos/frota, social, reputação | P1 | V2-05/08 |
| V2-15 | Segurança, performance, acessibilidade | P0 transversal | todas aprovadas |
| V2-16 | Testes Studio, beta e decisão de release | Gate final | escopo de código aprovado |

P0 = prioridade para o núcleo de lançamento. P1 = opcional condicionado a viabilidade/qualidade; P2/P3 não bloqueia publicação. Test-drive é FUTURO, não antecipar no começo.

---

## V2 — Engenharia desenvolvida na PR #27, sem interferir na V1

**Autorização do proprietário recebida.** O código das primeiras fases está na branch `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13`, documentado no [relatório de engenharia V2](V2_RODADA_01_ENGENHARIA.md).

- [x] **V2-00 código na branch:** migração aditiva schema v11→v12, lista de compra e marcos anônimos, preservação de claims/ledger/recibos, testes de migração e reconexão escritos.
- [x] **V2-01 código na branch:** três pilotos V1, pivôs autoráveis por script Studio, perfis de materiais, LOD seletivo, prevenção de modelos e sockets inválidos, suítes de regressão escritas.
- [x] **V2-02 código na branch:** recepção física, controles server-authoritative de prioridade, agenda, descontos, estoque/loja, wishlist de múltiplas OS, orçamento e dashboard, com testes de contratos escritos.
- [x] **Automação de engenharia na branch:** verificações estáticas e build Rojo aprovados [no último build anterior a esta revisão documental](https://github.com/FiaresAlan/Oficina24H/actions/runs/43496196905).
- [ ] **Merge na main:** depende de comparar, revisar e conciliar as correções V1 do Claude e refazer CI.
- [ ] **Arte real:** revisar/importar os três modelos piloto, ajustar malhas móveis, pivôs, licença, áudio e LOD reais.
- [ ] **Studio:** executar RunAllTests, V2PilotPlaceAudit, 15 serviços, multiplayer, mobile/PC/gamepad e verificar efeitos reais.
- [ ] **Homologação real V2-16 e lotes V2-08:** implementar somente após dependências, sem declarar V2 completa por CI verde.

**Portão:** código escrito e integrado em branch não equivale a jogo homologado. Não há publicação automática.

## V2-00 — Integração segura com a V1 em homologação
**Meta:** reconciliar o HEAD atualizado pelo Claude com a V1 C31, sem refazer correções C18–C31 nem interferir na homologação.
- [ ] [C] Comparar HEAD atual com C31; mapear módulos e riscos alterados pelo QA V1, classificados na Issue #15.
- [ ] [C] Reauditar DataService, WorkshopService e schema atual (v11 em C31), 15 serviços, NPC, compras, upgrades, recibos, claims e reconciliação entre perfis.
- [ ] [C] Revisar limites residuais de atomicidade financeira entre contas e ledger/arquivo de provas, sem afirmar segurança já comprovada em Studio.
- [ ] [C] Definir política de trabalho isolado em branch V2, integração revisada e testes para não sobrescrever a main da V1.
- [ ] [C] Definir novos contratos e migração reversível compatível com dados existentes; inventário real de assets/licenças e fallbacks.
- [ ] [C] Escrever testes adversos de idempotência/replay, duas compras, duas OS, desconexão/rollback e compatibilidade do código tocado.
- [ ] [A] Rodar contratos, validações e build Rojo; registrar links de CI efetivamente aprovados.
- [ ] [S] Suites Luau, 15 serviços e dois jogadores no Studio continuam com Claude/proprietário; não usar CI como substituto.

**Aceite de engenharia:** nenhuma regressão conhecida sem plano, baseline registrado, integração sem force-push ou sobrescrever correções da V1.
## V2-01 — Pipeline visual híbrido e 3 carros de referência
- [ ] [C] Definir paleta, iluminação, materiais e densidade de cena: bairro leve + oficina industrial + reparo técnico.
- [ ] [C] Preservar a rua atual; fazer protótipo visual em um quarteirão, não remodelagem geral.
- [ ] [C] Preparar compacto/sedã/picape, cada um com estados externos e rig de interação, escala/sockets consistentes.
- [ ] [C] Arquitetar LOD, modelos fallback, streaming e licenças/atribuições.
- [ ] [C] Definir pipeline Blender→Roblox reproduzível e limites de polígonos/efeitos por carro.
- [ ] [A] Testar mapeamento de assets, posições e fallback de modelos ausentes.
- [ ] [S] Revisar prints/quality/performance dos três modelos no Studio.

**Aceite:** arte legível sem abandonar o caráter de oficina real.

## V2-02 — Gestão intuitiva, recepção e quadro de ordens
- [ ] [C] Status de OS: chegada, aceitação, diagnóstico, aguardando peça, trabalhando, testando, liberado, entregue.
- [ ] [C] Quadro exibe cliente, carro, reclamação, urgência, preço, custo previsto e margem sem revelar defeito antes do diagnóstico.
- [ ] [C] Ações delegar, reagendar, recusar, priorizar, solicitar peças, sugerir preço.
- [ ] [C] Dashboard do proprietário: boxes, receita, custo, lucro, estoque, demanda e funcionários.
- [ ] [C] Onboarding 30–60 s guiando primeiro reparo e primeiro upgrade; sem overlay obstrutivo.
- [ ] [C] Medições de tutorial, primeira OS, primeiro funcionário, primeiro upgrade sem dados pessoais desnecessários.
- [ ] [A] Testar máquinas de estado de OS/snapshot e não quebrar HUD de C1–C17.
- [ ] [S] Validar mobile/PC/gamepad e primeira sessão de 10–25 min.

**Aceite:** o jogador percebe a próxima decisão de negócio rapidamente.

## V2-03 — Capô, portas, rodas, engine bay e elevadores

**Código V2-03 entregue na PR #27, sem homologação Studio:** [guia exato e QA V2-03](V2_FASE_03_COMPONENTES.md).
- [x] [C] Oito pontos físicos, estados server-authoritative, permissão do responsável, distância e bloqueio ao movimentar ou durante reparo.
- [x] [C] Portas, tampa, capô, quatro rodas independentes e cofre do motor, com partes nativas marcadas ou proxies client-side.
- [x] [C] Pré-requisitos dos procedimentos FlatTire/WeakBattery/Overheating, reset seguro antes da saída e próximo passo no HUD pós-diagnóstico.
- [x] [C] Suítes Luau registradas, auditoria não destrutiva de pivôs/meshes e checks CI.
- [ ] [S] Homologar separação física das malhas reais, posicionamento de pivôs, 15 serviços, mobile/gamepad e multiplayer no Studio.


- [ ] [C] Rigs/Attachments/pivôs de capô, portas, porta-malas e rodas para os três carros.
- [ ] [C] Usar sockets de componentes reais; não só posições genéricas do carro.
- [ ] [C] Regras de porta/capô: abrir, inspecionar, reparar, fechar, impedir abertura em movimento.
- [ ] [C] Som e feedback visual de cada ação, com alternativa visual para pistas sonoras.
- [ ] [C] Colisões seguras, limites de partes físicas e fallback de carros ausentes.
- [ ] [A] Casos de duplicação de interação, propriedade, posição, cancelamento e reconexão.
- [ ] [S] Abrir/consertar/fechar nos modelos reais no Studio.

**Aceite:** contato mecânico convincente sem simulação física integral de motor.

## V2-04 — Reparos ricos e variados (15 serviços)

**Engenharia em branch V2, sem homologação no Studio:** [matriz dos 15 procedimentos e roteiro de QA](V2_FASE_04_15_SERVICOS.md).

- [x] [C] Três etapas mecânicas distintas para cada um dos 15 defeitos, com interação física nos pivôs do carro e validação de proprietário/ator, sequência, proximidade e componentes.
- [x] [C] Integração com os 15 minijogos V1 e regras V2-03, equipamento e estoque; bloqueio do reparo antes das etapas físicas.
- [x] [C] HUD pós-diagnóstico, antes/depois visual, recap de qualidade, reinício de sequência confirmado e opção de tentar novamente sem cobrança antes da entrega.
- [x] [A] Verificações estáticas e build Rojo executados, suites físicas e cruzamento com os sete modos V1 registradas.
- [ ] [S] Studio: malhas e pivôs reais, 15 serviços, multiusuário, mobile/gamepad, performance, remotes e DataStore.


- [ ] [C] Auditar cada um dos 15 serviços existentes quanto à integração com rig, peça e equipamento.
- [ ] [C] Procedimentos diferenciados por família; interação real em pneu, elétrica, motor, suspensão, direção e lataria.
- [ ] [C] Qualidade visível: defeito, peça danificada, ferramenta, ação e “antes/depois”.
- [ ] [C] Erros com retrabalho proporcional; sem perder pagamento devido a bug visual.
- [ ] [C] Integrar custo da peça, estoque, reputação, lucro, XP e recap da OS.
- [ ] [A] Testes por serviço, aborto, timeout, spam de remotes e replay.
- [ ] [S] Homologar 15 serviços no Studio e mobile/gamepad.

**Aceite:** consertar um motor tem sensação distinta de trocar um pneu.

## V2-05 — Mecânicos NPC realmente úteis

**Engenharia V2-05 implementada na PR #27, sem homologação Studio:** [fluxo de funcionários, escala, dinheiro e matriz de QA](V2_FASE_05_FUNCIONARIOS.md).

- [x] [C] Caminhada controlada com recálculo limitado e falha segura sem teleporte pelo cliente, estoque, box e descanso.
- [x] [C] Gerência física com modo automático/manual/pausado, especialização, atribuição/cancelamento de fila e ordem determinística por prioridade.
- [x] [C] Supervisão de produtividade, qualidade média, duração, histórico individual, folha e vencimentos, com dados saneados.
- [x] [C] NPC só usa estoque e gera pagamento por SettlementNpcRepairOnce, registra resultado após liquidação e preserva provas financeiras da V1.
- [x] [C] Migração aditiva v12→v13, folha salarial sem replay do mesmo vencimento, demissão segura e recuperação de rotas/abandono.
- [x] [A] Suítes de escala, múltiplas OS e persistência escritas, mais auditoria não destrutiva dos personagens; CI e Rojo verificam os contratos.
- [ ] [S] Studio: animações/caminhadas, 0/1/2 empregados, 1/2/3 OS, fluxo financeiro e performance real.


**Aceite:** a equipe trabalha de maneira crível e não substitui o dono de imediato.

## V2-06 — Upgrade físico de negócio sem compras acidentais

**Engenharia implementada na PR #27, não homologada em Studio:** [matriz de expansão, compras seguras e QA](V2_FASE_06_EXPANSOES.md).

- [x] [C] Pads não compram ao pisar; interação com ProximityPrompt e confirmação do nível/preço calculado pelo servidor em até 14 segundos.
- [x] [C] Ampliação do prédio também exige prévia e confirmação: nível, custo, XP, reputação, equipamentos, distância e boxes livres revalidados no servidor.
- [x] [C] Capacidade real de 1/2/4/6 boxes e vagas de máquinas/funcionários mostrada na Construtora com benefícios mensuráveis, sem inventar ROI.
- [x] [C] Sinalização física de boxes, recepção, estoque e equipe sem colisão, recriada idempotentemente na troca de nível.
- [x] [C] Pagamento do upgrade e nível alterados no mesmo perfil sem yield, protegidos contra replay de cotação ou salto para o próximo nível.
- [x] [A] Testes Luau escritos para quote, preço/nível/saldo, persistência/reconexão, 4 visuais e comportamento não colidível. CI e Rojo verificam contratos.
- [ ] [S] Studio: testes reais de pisar/ficar/sair, 1/2 cliques, vizinho, saldo, morte/logout, multiplayer, mobile, boxes livres e performance.

**Aceite de código:** investir por decisão explícita e visualizar a nova capacidade, sem compra acidental. **Aceite de produto:** requer QA Studio.

## V2-07 — Bairro vivo e escalável

**Engenharia implementada na PR #27, não homologada no Studio:** [guia de tráfego, ativos, limites e QA](V2_FASE_07_BAIRRO_VIVO.md).

- [x] [C] 9 trajetos de pedestres e 6 de carros no bairro, usando modelos licenciados já importados, animação apenas no cliente e sem colisão.
- [x] [C] Pool global de 12 modelos e máximo de 9 entidades ativas, com culling por distância, FPS, dispositivo e jogadores.
- [x] [C] Entregador visual com prioridade após compra de peças validada, sem mudar o inventário ou repetir pagamento.
- [x] [C] Templates de até 3 avatares sanitizados e modelos reais de veículos reutilizados da V1; rivais e clientes permanecem V1.
- [x] [C] Recolhimento ao pool, cooldown, prioridade de veículos reais, desligamento de VFX e cleanup do jogador.
- [x] [A] Regras e auditoria Studio escritas, incluídas no runner; CI estático e build Rojo.
- [ ] [S] Conferir assets, streaming, FPS, visual/animador de NPC e conflito de tráfego no Studio.

**Aceite:** engenharia separada e limitada; performance real depende de QA Studio.

## V2-08 — Negócio e margem financeira

**Engenharia financeira na PR #27, ainda não homologada em Studio:** [guia v14, caixa, categorias e QA](V2_FASE_08_FINANCAS.md).

- [x] [C] Entradas e despesas reais por categoria: OS, peças, salários, publicidade, máquinas, prédio, contratação e bônus.
- [x] [C] Schema v14 aditivo, saldos e categorias persistentes, migração com histórico parcial explícito, conciliação e privacidade de recibos.
- [x] [C] Checkout misto separa equipamentos/peças sem custo duplicado; créditos de OS e NPC seguem comprovantes V1.
- [x] [C] Reposição de peças por OS diagnosticada e histórico, reserva de salários, alerta de insuficiência de caixa e 15 estimativas de contribuição-base.
- [x] [C] Aba Caixa na janela Ordens; fluxo de caixa real distinguido de lucro contábil não comprovado.
- [x] [A] Suites Luau e simulação de migração/replay/salvamento escritas; contratos estáticos e build Rojo.
- [ ] [C] Fornecedores com graus de qualidade de peça e custo/consumo próprios — requer controle de lote e rollback, não simulado.
- [ ] [S] QA Studio: 15 serviços, salários, estoque, colaboração, mobile e playtest gerencial de 20–30 min.

**Aceite do livro de caixa:** lançamentos reais sem duplicação. **Aceite completo da fase:** resta aquisição por qualidade e homologação Studio.

## V2-09 — Mercado de carros velhos / compra e revenda (P1, protótipo)

**Engenharia de protótipo codificada na PR #27, QA Studio pendente:** [escopo, estimativas, UX, segurança e roteiro de testes](V2_FASE_09_USADOS.md).

- [x] [C] Mercado limitado a quem concluiu 3 OS de clientes e ampliou a oficina; valores e sorteio de risco somente no servidor. As estimativas de contribuição não são lucro contábil.
- [x] [C] Três variantes (Hatch/Sedã/Picape), um único carro próprio e cooldown persistente de 10 minutos entre ciclos. Carros próprios não ocupam boxes das OS.
- [x] [C] Fluxo compra → inspecionar → desmontar → restaurar consumindo peças e pagamento → pintura opcional → venda ou venda como sucata; previews 3D dos modelos existentes no painel.
- [x] [C] Idempotência de revenda, limite de capacidade e anti-replay; custos do mercado segregados em categoria financeira própria, sem crédito/XP/reputação de OS.
- [x] [C] Schema v15 aditivo, teste de reconexão e persistência de veículo/caixa, regressões Luau e contratos de CI escritos.
- [x] [A] [Contratos estáticos e build Rojo verificados](https://github.com/FiaresAlan/Oficina24H/actions/runs/43527260118) no código V2-09, commit `6fec467`. Alterações documentais posteriores mantêm o mesmo código.
- [ ] [S] Validar localização física e interfaces reais, três modelos, multiplayer, mobile/gamepad, relog, cooldown e economia no Studio.
- [x] [C] Carro em vitrine física não colidível do lote, modelo 3D sanitizado/fallback, prompts de inspeção/restauração/venda, mudança visual e cleanup da sessão.
- [ ] [C] Desmontagem de rodas/peças e showroom imersivo com ferramentas reais (**não implementados**; avaliar aprofundamento na V2-10).
- [ ] DECISÃO: expandir, simplificar ou retirar após playtest que compare o tempo e o ganho por OS.

**Pendência herdada da V2-08:** graus Econômico/Padrão/Premium por lotes FIFO ainda precisam de controle de custos, consumo, migração e rollback. Não apresentar como implementados.

## V2-10 — Personalização comercial e showroom (P1)

**Engenharia integrada na PR #27, sem QA Studio:** [guia de preço, UI, comportamento, segurança e playtest](V2_FASE_10_SHOWROOM.md).

- [x] [C] Catálogo fechado para pintura (Azul/Vermelho/Grafite), acabamento (fosco/brilhante) e rodas (clássicas/esportivas); custo servidor > bônus máximo de revenda.
- [x] [C] Prévia 3D ANTES/DEPOIS local usando os mesmos visuais do pátio; confirmação separada; cancelar prévia nunca cobra. Só uma aplicação válida por categoria e veículo.
- [x] [C] Showroom persistente com 2 carros restaurados expostos e 1 ativo independente das OS, sem colisão, toque, física ou script de asset; prompts de retirada e venda autenticados.
- [x] [C] Transferir/retirar/vender com o mesmo UID; venda de exposto idempotente, cooldown e livro financeiro em `Market`, sem bônus de OS/XP/rating.
- [x] [C] +1 reputação apenas na primeira exposição histórica de Hatch/Sedã/Picape (limite 3), com marcador no mesmo perfil sem yield e sem replay após venda/reentrada.
- [x] [C] `UsedMarket` v15 aditivo com Showroom/ShowroomSeen/Finish/Wheels; compatível com carros V2-09 Azul/Vermelho e históricos sem campos novos.
- [x] [C] Subnavegação CAIXA/USADOS na aba existente: mercado e showroom acessíveis sem rolagem por todo o extrato no celular; nenhum botão novo na HUD.
- [x] [A] Suites Luau escritas e registradas, contratos estáticos/build Rojo [aprovados](https://github.com/FiaresAlan/Oficina24H/actions/runs/43531088184) para a implementação e proteção contra assets vazios. Revalidar CI no HEAD após a última revisão de testes Grafite.
- [ ] [S] Homologar três veículos reais, malhas PBR, roteiro de 2 jogadores, tablet/celular/gamepad, relog, 15 OS e desempenho por lote no Roblox Studio.
- [ ] [S] Confirmar que benefício de reputação pontual e catálogo cosmético não desviam o jogador das OS. Decidir manter/simplificar após beta.

**Não confundir:** showroom físico decorativo e prévia 3D existem em código, mas a condução física piloto V2-11 permanece sem homologação real de direção nem testes Studio concluídos. Materiais PBR podem precisar de `V2CosmeticRole` nos meshes importados.

## V2-11 — Fundamentos do carro dirigido pelo jogador (P1)

**Engenharia na PR #27:** [documentação, contratos físicos, segurança e roteiro de QA](V2_FASE_11_DIRECAO.md). V2-11 não libera moeda/XP, diagnósticos nem recompensas de test-drive (reservados à V2-12/13).

- [x] [C] Hatch piloto com **VehicleSeat real, chassi físico**, 4 rodas motorizadas (HingeConstraint), 2 servos de esterço, teclado/setas, gamepad, botões próprios de toque, câmera e HUD de checkpoints.
- [x] [C] Carro da OS permanece no box, sem tocar no NPC/rota V1: original ancorado fica temporariamente invisível e sem colisão; clone seguro dirigível usa assets sanitizados ou fallback. Tudo é restaurado no CFrame do box, conservando flags originais, prompts e UID da OS.
- [x] [C] Só o dono da OS ativa e Hatch piloto com componentes fechados, carro no chão, sem colaborador/NPC/minijogo ativo pode dirigir; uma sessão por jogador/OS, autorização de ocupante do assento no servidor.
- [x] [C] Remote de input carrega só throttle/steer limitados e no máximo ~14 Hz, sem posição/velocidade enviadas pelo cliente; servidor é network owner de todas as peças, motor neutraliza input vencido.
- [x] [C] Timeout 150 s, desconexão, morte/respawn, abandono do assento, capotamento, colisão frontal, queda e teleporte acionam rollback e cleanup. Despawn de OS cancela antes de remover carro/box.
- [x] [C] Servidor valida velocidade/posição/distância/desnível e checkpoints em ordem a ~10 Hz, sem `Touched`/crédito/XP por movimento. Venda e recebimento de serviços só pelas rotas V1 existentes.
- [x] [C] NPC avulso, convites/aceite de colaboração, StartRepair e upgrade de prédio bloqueados enquanto a OS estiver em condução, evitando liquidação com carro fora.
- [x] [A] Suites de regressão escritas (`V2DriveRulesTest`, `V2DriveRigTest`, `V2DriveSuspensionTest`) e registradas no runner; CI de contratos e Rojo verde na branch após integrar núcleo V2-11. **Não executa scripts Luau no Studio.**
- [ ] [S] Playtest Studio de dirigir/retornar com 1–2 jogadores; ajustar e homologar torque, física, câmera, toque, gamepad, latência, modelos importados e vias do mapa.
- [ ] [S] Executar suites Luau em Edit e validar casos de usuário indevido, avatar morto, retorno, falhas de rede, espelhamento dos lotes, NPCs, 15 OS e desempenho.

**Gate obrigatório antes de V2-12:** homologação física e segurança Studio. CI verde sozinho não autoriza integrar diagnósticos/receitas da V2-12.

## V2-12 — Test-drive contextual para diagnóstico (P1, engenharia concluída sob gate)

**[Especificação, tabela de sintomas e roteiro Studio](V2_FASE_12_DIAGNOSTICO_DRIVE.md)** · `V2DriveScenarioRules.LiveEnabled=false` até homologar a condução V2-11 no Studio.

- [x] [C] Tabela fechada para pneus, volante/direção, suspensão, freios e motor com pista contextual que não revela DefectId.
- [x] [C] Gatilho aleatório apenas entre Hatch piloto/defeitos elegíveis e fora do onboarding (38%), com seed único registrado no servidor ao gerar a OS e caso intermitente raro (terceiro checkpoint).
- [x] [C] Rota física V2-11 com 4 checkpoints, >=32 s mínimos, alvo de 45–90 s, telemetria e retorno seguro sem `Touched`; máximo 2 inícios para permitir retry de aborto e apenas 1 conclusão por OS.
- [x] [C] Sinal por velocidade, curva, frenagem, aceleração e aquecimento observado no servidor; cliente vê painel âmbar/vermelho e texto, reproduz som autorizado e vibração opcional.
- [x] [C] Evidência contextual aparece somente após teste válido, sem preço/XP/moeda, e mantém `DiagnosisRules.Judge` + exames mecânicos da V1 como fonte do diagnóstico final.
- [x] [C] Remote `DriveCar` valida fase, dono, OS/ocupante; callback privado `OnDriveOutcome` atribui evidência sem cliente enviar checkpoint/defeito/seed.
- [x] [A] `V2DriveScenarioTest.luau` escrito, registrado no runner; testes de gate/seed/chances/gatilhos/replay/aborto/snapshot e contratos CI/Rojo automatizados. **Execução de Luau no Studio pendente.**
- [ ] [S] Homologar gate V2-11 primeiro. Então medir 45–90 s, prazer de condução e se não é obrigatório, sinais com/sem som, toque/gamepad, baixa latência, 2 jogadores, queda e sem dinheiro pelo teste.

## V2-13 — Qualidade pós-reparo e retrabalho (P1, engenharia concluída sob gate)

**[Máquina de estados, integridade financeira e roteiro Studio](V2_FASE_13_QUALIDADE_RETRABALHO.md)** · mesmo gate `LiveEnabled=false`. Sem liberar esta fase para jogadores antes do QA V2-11/V2-12.

- [x] [C] Em 24% das OS Hatch/defeito elegíveis, após minijogo validado, oferecer rodagem de qualidade OPCIONAL; NPC/colaborador e primeiro onboarding continuam com pagamento V1.
- [x] [C] Estados server-side `Offer` → `Driving` → `Approved`, `Rework` ou `Incomplete`, atribuídos por retorno verificado e qualidade original (<70 = correção recomendada; não por sorteio ou colisão).
- [x] [C] Botões de entregar sem teste (mesma nota), verificar na rua, aprovar/entregar ou refazer uma única vez com novo minijogo no mesmo JobId, sem cobrança extra de peças no primeiro ciclo.
- [x] [C] Pista e decisão de pós-reparo não concedem XP/moeda/nota extra. Entrega com qualidade insuficiente preserva nota original e a avaliação V1; oferece retrabalho como decisão não coercitiva.
- [x] [C] Aborto/rede ruim não puni; retorna à oferta. Relógio de 300s tenta concluir qualidade original sem penalidade, e OS não expira enquanto está reservada.
- [x] [C] Minijogos fecham por `RepairQualityPending` sem anúncio falso de quitação. Token, quality, resultado e OS ficam selados no servidor, sem novos remotes de pagamento.
- [x] [C] Pagamento/XP/peças/histórico percorrem **um único** `settleEvaluatedRepair` (a mesma cadeia V1 idempotente), nunca por evento `Touched` nem controle do veículo. Staff, NPC, colaboração e expansão bloqueados durante pré-commit e yield.
- [x] [A] `V2QualityDriveTest.luau` escrito e registrado, contratos CI/Rojo de gate, fluxo, rework, abortos, recibos e não dupla cobrança. **Não é execução de Luau/Playtest Studio.**
- [ ] [S] Homologar aprovado/reprovado/incompleto, custo zero da repetição, recibo único, DataStore com falhas, multiplayer, boa UX mobile/gamepad e ritmo do loop sem test-drive em 100% das OS.
- [ ] [S] Registrar limitação de sessão sem pagamento em desconexão: a OS V1 é transitória e não há recuperação interservidor do resultado ainda não liquidado. Decidir mitigação de produto antes de publicação.

**Gate antes de V2-14/release:** testes da V2-11 física, da V2-12 sensorial e da V2-13 financeira no Roblox Studio precisam passar; a branch continua sem merge na main.

## V2-14 — Frotas, contratos e relações comerciais (P1, engenharia concluída)

**[Guia completo da V2-14, contratos, riscos, persistência e roteiro de QA](V2_FASE_14_FROTAS_CONTRATOS.md)** · Engenharia na PR #27; **testes Luau e Studio ainda não executados**.

- [x] [C] Propostas das cinco empresas abertas somente após onboarding, não mais contratos forçados: recusar/expirar sem multa, prazo da decisão 130 s, 1 proposta/contrato por oficina, cooldown e aceitação única do modo Normal/Prioritário.
- [x] [C] `V2FleetBusinessRules.Quote`: prazos e bônus calculados no servidor, prêmio da urgência ~20% maior e prazo ~22% menor; estimativas de serviço/peças/estoque/capacidade/boxes/ocupação/equipe com base nos defeitos e materiais de verdade, sem números garantidos de lucro.
- [x] [C] Geração de carros da frota limitada a defeitos que a oficina *de fato* consegue executar com seu equipamento e nível, mantendo o atendimento V1 de outras OS sem contrato.
- [x] [C] Alternativas econômicas apresentadas na aba Equipe: margem de referência com proprietário, colaborador (parcela estimada) ou NPC avulso; atribuição real de funcionário e convite de colaboração continuam nos fluxos validados de V1/V2-05.
- [x] [C] Relacionamento persistente por empresa: cada contrato cumprido gera 2% de bonificação no próximo convite do parceiro (teto +10%), somente sobre prêmio do contrato; conclusão/expiração e histórico dos 20 eventos recentes sanitizados e chaves financeiras não replicadas.
- [x] [C] `FleetDone` somente após pagamento de OS por jogador/colaborador/NPC/staff; valida token vigente, JobId único, executor e meta, rejeita replay e token de outra frota.
- [x] [C] Prova de bônus no **mesmo perfil** (`DataService.RecordFleetOutcomeOnce`) antes de crédito de moedas/reputação; mudanças sem yield e idempotência após Save/Load, sem substituir a liquidação colaborativa existente.
- [x] [C] Timeout do contrato registra vencimento sem debitar saldo/rep; desconexão não cria direito a prêmio não conquistado. **Limite documentado:** contrato parcial continua por sessão (como V1), não recuperável entre servidores.
- [x] [A] Duas suites escritas (`V2FleetBusinessRulesTest`, `V2FleetContractTest`) e regressões extras em `PersistenceTest` com DataStore simulado A/B/C, token falso, contrato duplicado, timeout, sanitização, team modes e idempotência; suites registradas no runner.
- [x] [A] CI Rojo e contratos estáticos para cotação, gating, privacidade, JobId único, mesma conta e replay de bônus; **CI não executa os testes Luau**.
- [ ] [S] Homologar em Studio 2 jogadores, cinco empresas, normal/prioritário, fonte de margem, estoque, comissão colaborativa, equipe, saída de jogadores, Save falho e contrato vencendo entre OS.
- [ ] [S] Decidir produto: contrato parcial expira/reinicia ao desconectar (herdado da V1) ou deve ser retomado no beta; avaliar clareza da cotação e se o prazo é razoável.

## V2-15 — Polimento transversal, segurança e auditoria (P0, código integrado, QA aberto)

**Documentação:** [V2-15 — análise de riscos, correções e QA adversarial](V2_FASE_15_HARDENING_RELEASE.md) · [Changelog técnico V2](CHANGELOG_V2_2026-11-13.md). A PR #27 permanece **draft** e sem merge.

- [x] [C] Auditar o fluxo crítico dos remotos (Main), snapshot/cache, física V2-11, cenários V2-12/13, contrato V2-14, salário/economia DataService, assets de terceiros e componentes UI, preservando as salvaguardas C1–C31 e a `main`.
- [x] [C] `V2RemoteSecurityRules` e Main: limite **transversal** por jogador de 44 ações em rajada/26 por segundo, snapshots 12/8, validação recursiva finita de tamanho, profundidade, índices, Instances, ciclos e números NaN/infinito antes de qualquer handler.
- [x] [C] `V2VisualBudgetRules.PreflightTemplate`: rejeitar asset excessivo **antes do Clone** no Hatch físico (95 peças/350 instâncias/24 PBR), figurantes locais/servidor (90 peças/280 instâncias), fallback procedural e teto de 5 rigs de física por servidor.
- [x] [C] Verificação de StreamingEnabled só por auditoria Studio, sem script que altere property em runtime. Áudio licenciado catalogado em `SoundIds`, scripts externos sanitizados e NPC ambiente somente cosmético com limites adaptativos.
- [x] [C] `ContractService.endContract` revalida conclusão e aguarda Save antes de anunciar sucesso; retry com mesma chave e sem duplicar saldo, reputação, liga ou JobId. Snapshot exibe `PendingSettlement` enquanto pendente.
- [x] [C] `V2AccessibilityRules` e DataService: três opções de haptics/SFX/LowDetail persistentes no perfil, com botão de configuração na aba Equipe, pistas textuais preservadas no Hatch e bairro menos pesado para mobile; nenhum efeito na economia/diagnóstico.
- [x] [C] Auditoria de licenças com novo `V2Credits` e tela **Perfil → Créditos**, fontes/atribuições rastreáveis e avisos sobre HUD/ícones, modelos sem licença, marcas, CC BY e Shuriken; **documentar pendências NÃO significa licenças resolvidas**.
- [x] [C] Verificar localização atual: `Locale.lua` só contém `pt-BR`; jogo não anuncia suporte integral `en-US`. Textos novos da V2 continuam prioritariamente em português e a tradução para lançamento internacional está pendente de decisão.
- [x] [C] Proteger migrações aditivas v15 de `Accessibility`/`FleetAccounts` e rotina de Save do bônus, explicitando que mudanças intra-perfil sem yield não são transação entre contas nem substituem recibos V1.
- [x] [A] Testes adicionais escritos e registrados: `V2RemoteSecurityTest`, `V2RuntimeAssetBudgetTest`, `V2AccessibilityTest`, `V2CreditsTest`, `V2ReleasePlaceAudit`; cenários de Save falho em `V2FleetContractTest` e Save/Load em `PersistenceTest`. A execução real de Luau está aberta para o Studio.
- [x] [A] Changelog, auditoria e matriz adversarial P0/P1 com gate V2-16 criados, contratos estáticos expandidos em `tools/ci/verify_contracts.py`; pipeline do GitHub verifica também build Rojo. **Não confundir CI estático com teste Play Solo.**
- [ ] [S] Testes reais de FPS/memória GPU/latência, StreamingEnabled, torque/câmera/touch/gamepad, cenas com 2 jogadores, 15 serviços e perfis em aparelhos fracos.
- [ ] [S] Confirmar os direitos comerciais e a licença **de cada asset usado**; os sprites HUD e pacote de ícones seguem pendentes de autorização, além de modelo esportivo e marcas. Créditos em UI não resolvem esse gate.
- [ ] [S] Homologar a latência de `FinishRepair` e de `ContractService.RetryPending` quando DataStore ceder execução ou falhar, sem prejudicar OS, NPC ou colaboração de terceiros.
- [ ] [S] Se lançamento internacional for objetivo, criar tradução integral `en-US` com paridade e conferir acessibilidade real de texto/controles; `pt-BR` é o único idioma implementado hoje.
- [ ] [S] Revisar com a `main` atual do Claude/QA V1, conferir regressões dos 15 serviços, obter confirmação do proprietário e anexar evidências de playtest ao gate V2-16.

## V2-16 — Homologação Studio e beta (engenharia de QA concluída; RELEASE BLOQUEADA)

**Documentação:** [V2-16 — comandos Studio, 16 gates e plano Go/No-Go](V2_FASE_16_HOMOLOGACAO_BETA.md) · [Manifest de evidências, todos sem aprovação](release/V2_RELEASE_EVIDENCE.json) · [Matriz de 15 OS pendentes](release/V2_TEST_MATRIX_15_SERVICOS.csv). A PR #27 permanece **draft** e sem merge na `main`.

- [x] [C] Matriz `V2ReleaseGateRules` com 16 portões de lançamento e fontes distintas CI/GitHub/Studio/Legal/Beta/Owner. Nenhuma aprovação sem URL de prova, nota, data ISO e SHA completo idêntico ao build.
- [x] [C] `tools/ci/release_gate.py` com `--mode report` e `--mode enforce`; autoverificação de fontes, licenças, owner, SHA divergente e pendências. O enforcement é manual, não faz deploy; o CI apenas informa NO-GO sem confundir código verde com playtest.
- [x] [C] `V2BetaSmokeAudit.luau` do place em Studio/Edit/Play e `V2ReleaseGateRulesTest.luau` adicionados ao `RunAllTests.luau`; não mexem em saldos nem ativam diagnóstico/test-drive opcional.
- [x] [C] Matriz CSV com os 15 defeitos do catálogo, status `PENDENTE` e campos para modelo, dispositivo, jogador, diagnóstico, reparo, peça, recibo único, reputação e prova do build. Validação CI de paridade exata com Catalog.
- [x] [C] Auditoria da divergência GitHub: PR #27 aparece **não mesclável** com a `main` atual neste checkpoint; reconciliação V1 é tarefa antes do merge, sem sobrescrever trabalho do Claude.
- [x] [A] Pipeline Rojo/contratos e teste do bloqueio de release incorporados ao Code Health; os controles de `--mode enforce` deverão retornar código 1 enquanto os gates estiverem abertos. **Não foi executado Studio nesta rodada.**
- [ ] [S] Rodar `RunAllTests`, `StudioPlaceAudit`, `V2ReleasePlaceAudit` e `V2BetaSmokeAudit` no place com assets reais, arquivar saídas e SHA.
- [ ] [S] Executar todos os 15 serviços, registrar as 15 linhas da matriz CSV com resultados e provas reais em diferentes modelos e dispositivos.
- [ ] [S] Testar loop do novato → 1ª OS → upgrade nível 1 → contratação e faturamento, sem comandos QA.
- [ ] [S] Testar 2+ jogadores, remotos falsificados, desconexão, DataStore Studio e servidor privado publicado de testes.
- [ ] [S] Homologar V2-11 física, torque, câmera, checkpoints, retorno ao box e acessibilidade touch/gamepad; manter V2-12/13 `LiveEnabled=false` até gate próprio.
- [ ] [S] Implementar e homologar lotes FIFO dos fornecedores da V2-08 e suas migrações; **P0 aberto, não marcar V2-08 como pronta**.
- [ ] [S] Confirmar licenças/autorização de todos os sprites, ícones, modelos externos e marcas; checar StreamingEnabled, FPS/memória reais, áudio e animações.
- [ ] [S] Corrigir divergência PR #27 com o `main` atual, revisar conflitos V1 sem force-push na `main`, congelar SHA da build final.
- [ ] [S] Executar beta fechado, medir diversão/abandono/lucratividade, corrigir P0/P1 e recolher documentação do build.
- [ ] [S] Registrar 16/16 evidências de fonte correta, SHA da build e aprovação explícita do proprietário; **NENHUMA autorização implícita de publicação**.

## Auditoria final antes da entrega ao Claude — código revisado, NO-GO

**Relatório de transferência:** [V2 — Auditoria pré-entrega e guia para Claude](V2_AUDITORIA_HANDOFF_CLAUDE_2026-11-13.md). **Main V1 lida:** `a3a1279fc409f1997255f6fb5d97c2788b121388` (atualizar na hora de integrar). **PR #27:** `mergeable=false` (dirty), **draft**; a `main` não foi alterada por este assistente.

- [x] [C] **P0 segurança:** remover `RepairOperations` e `WorkshopProcedures` de `ReplicatedStorage.Shared`; mover gabaritos da V1 homologada para `src/server`, corrigir `WorkshopService`, oito paths de testes e auditorias e falhar no CI se voltarem a ser replicados.
- [x] [C] **P0 pagamento/reentrada:** tirar `FleetDone` de `rateService`; apenas após recibos e Save confirmado de reparo manual, colaborativo, NPC ou funcionário agendar registro idempotente de progresso de frota sem bloquear a resposta do reparo.
- [x] [C] **Correções V1 preservadas:** ID negativo de usuário Studio em quitação, posse da OS enquanto dono trabalha, fail-closed TV/prateleira, tolerância float32 da loja, fallback de API Studio, cash/snapshot anti-spam, respostas ACK saneadas, QA para os 15 defeitos, UX touch/onboarding, billboard de upgrades e cache de amigos.
- [x] [C] **Suítes V1 ajustadas:** `CompactHudTest` usa JobId real; `PersistenceTest` usa `Suspension` em claims/XP, não especialização inexistente `Freios`; `RequestBudgetRulesTest` registrado no runner de 81 suítes.
- [x] [A] Scanner `tools/ci/audit_repo_integrity.py` acoplado ao CI, cobrindo 222 fontes Lua/Luau, 81 suítes, 395 verificações de integridade e bloqueio à replicação de gabaritos; verificação estática e Rojo executadas sem erros no workflow; **não é compilação/teste Luau em Studio**.
- [ ] [S] **QA Claude V2:** executar as 81 suítes no Studio, cobrir falha/retry de contrato após Save, expiração/desconexão, física, 15 OS, collab, novos NPCs e dispositivos; não herdar automaticamente o PASS da V1.
- [ ] [S] **Integração V1:** resolver conflitos em branch temporária, revisando por módulo (não `--ours`/ `--theirs` em massa). Preservar correções da V1, gabaritos server-only e DataStore. Só então mesclar após homologação.
- [ ] [S] **Produto:** implementar e testar lotes FIFO/fornecedores V2-08 e licenças/atribuições, teste beta e autorização final 16/16; PR permanece draft.

## Checklist obrigatório de cada rodada futura
- [ ] Fixar SHA base, dependências e critério de aceite.
- [ ] Auditar código legado e não duplicar mecânicas existentes.
- [ ] Planejar migração, autoridade do servidor, feedback de UI e testes.
- [ ] Entregar fase completa com revisões e casos negativos.
- [ ] Rodar verificações automáticas reais e registrar resultados.
- [ ] Integrar branch de forma segura e atualizar docs/checklist com SHA e portões.
- [ ] Não fingir testes Studio feitos; deixar [S] pendente até evidência.
- [ ] Avançar só na próxima fase aprovada.

**PORTÃO DE AUTORIZAÇÃO:** aguardando a ordem explícita do proprietário para iniciar **V2-00**. Publicar esta documentação não significa autorização de gameplay; nenhuma fase recebe [C]/[A]/[S] por ser apenas planejada.


---

## Anexo 2.1 — Matriz operacional de entrega e revisão

**Separação de responsabilidade:** o assistente entrega arquitetura, serviços Luau, UI, interações, regras de economia, testes, segurança, pipelines, CI e documentação. O proprietário/Claude faz a importação dos assets no place original, testes Studio, multiplayer real, performance em dispositivos e decisão de publicação. Correções da V1 originadas pelo QA pertencem à Issue #15, sem inflar a conclusão da V2.

**Planejamento das fases:** 00–08 e 15 formam o núcleo P0; 09–14 são hipóteses P1 e só entram na implementação quando há justificativa de produto e viabilidade; 16 é homologação. As fases não são contadas como concluídas antes de evidências de código, automação ou Studio.

### Aceite e dependências por fase

| Fase | Entrega mensurável de engenharia | Asset/arte necessário | Prova mínima antes de dar [C]/[A] |
|---|---|---|---|
| 00 | Compatibilidade V1→V2, idempotência/finanças e proteção contra sobrescrita | Inventário V1 + manifesto V2 | Contratos e CI após reconciliação com QA V1 |
| 01 | 3 carros (hatch/sedã/picape) com LOD, sockets, materiais e pipeline | V1 21 carros + PBR opcional | Contrato/fallback dos três rigs e teste de carga estático |
| 02 | Fila/recepção, OS com estados, dashboard e onboarding | Recepção/quadros do pack V1 | Não vazar defeito; snapshots coerentes; UI navegável |
| 03 | Capô/portas/rodas, pivôs, interação e bloqueio de movimento | Componentes A03, carros V1 normalizados | Validação servidor, cancelamentos, replay e estados |
| 04 | Representação física de 15 serviços, feedback antes/depois | Ferramentas/partes A02/A03, efeitos/áudio | Matriz 15/15 e não duplicar pagamento |
| 05 | Mecânicos com delegação, rota, performance e salário | R15 V1, máquinas A02 | Fila sem corrida, remuneração só após conclusão |
| 06 | Expansões e upgrades com ROI/feedback e compra segura | Oficina/equipamentos V1 | Saldo/compra dupla/entrada acidental cobertos |
| 07 | Pedestres/trânsito leve por distância e pool | Cenário V1, LOD de carros existentes | Despawn/logout/streaming e orçamento de NPC |
| 08 | Gestão de caixa, margem, preço, reposição e estoque | Ícones/recepção V1 | Testes econômicos, migração, extrato coerente |
| 09 | Compra/restauração/revenda em um slice | Variação danificada dos 3 pilotos | Compra/venda idempotente, não substituir OS |
| 10 | Pintura/rodas/showroom limitado | Variantes A13 | Persistência, cancelamento, performance do showroom |
| 11 | Carro da OS dirigível com servidor validando estado | Carro piloto; sem kit novo obrigatório | Recuperação após respawn/logout e anti-fraude |
| 12 | Test-drive contextual com sintoma/seed | Som/indicadores reutilizados | Elegibilidade, timeout e replay seguros |
| 13 | Verificação pós-reparo e retrabalho justo | Mesmo carro A14 | Não cobrar/pagar duas vezes; falha de rede justa |
| 14 | Frota, contratos e reputação | V1 carros + HUD | Contratos e repartição sem crédito duplicado |
| 15 | Revisão transversal e congelamento candidato | Manifesto completo de licença | CI final, segurança, documentação, migrações |
| 16 | QA Studio/beta/aprovação do proprietário | Place com assets reais importados | Evidências [S] e autorização de release |

### Sequência sugerida de rodadas — maximizar entregas sem perder qualidade
- Rodada 1: V2-00; avançar a V2-01 apenas se o diagnóstico da base estiver estabilizado.
- Rodada 2: V2-01 + V2-02 quando independentes e com verificações próprias.
- Rodada 3: V2-03 (três carros piloto), seguido da V2-04 se os protocolos de rig e estado já estiverem comprovados em código.
- Rodada 4: V2-05 + V2-06; depois V2-07 + V2-08 se o servidor, HUD e economia estiverem isolados.
- Rodadas opcionais: V2-09→V2-14 após análise do custo de diversão e da viabilidade, sem ampliar todo o escopo sem vertical slice.
- Encerramento: V2-15 engenharia e V2-16 homologação. **A quantidade não é compromisso fixo; só contam fases completas e verificadas.**

### Regra de engenharia de cada rodada
- [ ] Registrar SHA base e mudanças simultâneas do Claude Code; evitar editar o mesmo módulo às cegas.
- [ ] Revisar regras e assets existentes antes de escrever novos serviços; evitar duplicação de sistemas.
- [ ] Entregar interface, estados, servidor, rollback, feedback, mocks/fallback e testes em cada fase.
- [ ] Confirmar autoridade do servidor para dinheiro/OS/reparo/estoque e compatibilidade do DataStore.
- [ ] Executar verificador real e build Rojo, registrar link do CI; não afirmar teste Studio sem evidência.
- [ ] Registrar cada commit, pendência e risco nas docs e na Issue #26, deixando [S] separadamente pendente.
- [ ] Não usar force-push para substituir a V1; reconciliar conflitos e preservar o cenário original.
- [ ] Conferir licença, localização e necessidade real de qualquer novo asset no [Guia V2](GUIA_UNICO_ASSETS_V2.md).

### Prioridade de assets para começar
1. Verificar se o Claude já importou os cinco pacotes V1 e onde estão 21 carros, 11 equipamentos e rigs R15; **não baixar duplicados**.
2. V2-01 começa com um hatch, um sedã e uma picape **do catálogo V1**, sem trocar a rua.
3. Na V2-03, se faltar malha de freio, motor ou bateria, usar apenas as peças necessárias do pack CC0 **Survivor Vehicle Maintenance** (A03).
4. Materiais Poly Haven, efeitos Kenney e ícones Lucide são opcionais e entram só quando melhorarem legibilidade/qualidade; conferir licença.
5. Nenhum arquivo externo GLB será solicitado pelo código em runtime Roblox: importar ao Studio/Creator Hub e usar as referências autorizadas.

**Estado vigente:** implementação em branch V2 explicitamente autorizada e submetida à PR #27; proibido substituir a `main` do Claude sem conciliação. Importação ao place, homologação Studio, licenças, beta e publicação aguardam execução/aprovação real do proprietário. Consulte a auditoria pré-entrega acima e o gate V2-16.
