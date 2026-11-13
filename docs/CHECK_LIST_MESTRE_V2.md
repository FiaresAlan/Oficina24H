# CHECK_LIST_MESTRE_V2 — OFICINA 24H

**Versão:** 2.1, 13/11/2026. **Situação:** planejamento e guia de assets finalizados; **nenhuma mecânica V2 implementada**, aguardando OK explícito para código.  
**Direção aprovada pelo proprietário:** híbrida — estilização legível do mundo + reparos visualmente mecânicos + gestão de negócio.  
**Código base de referência:** main em C31 (`2690f082` antes dos commits exclusivamente documentais da V2). **Atenção:** o Claude Code está homologando/corrigindo a V1 em paralelo; sempre ler novo HEAD e reconciliar diffs antes de programar V2. Preservar Issue #15 V1 como histórico.  
**Documentos de referência:** DIRECAO_JOGO_V2_2026-11-13.md, PESQUISA_MERCADO_V2_2026-11-13.md, AUDITORIA_V2_BASE_CODIGO_2026-11-13.md (auditoria histórica até C17), [GUIA_UNICO_ASSETS_V2.md](GUIA_UNICO_ASSETS_V2.md) e GUIA_UNICO_ASSETS_V1.md.

## Regra de preenchimento
- [C] = código e teste de regressão escritos e integrados.
- [A] = verificações automáticas e Rojo executados com sucesso no commit final.
- [S] = jogo **realmente** testado no Roblox Studio / dispositivo.
- Nada é marcado [x] por ter sido planejado. **Todas as fases V2 abaixo começam pendentes.**
- O proprietário pretende executar a homologação Studio ao final. Isso não dispensa testes de código em cada etapa e mantém riscos de integração abertos.
- Implementar **o máximo de fases completas e seguras possível por rodada**. Agrupar somente quando dependências, revisão, testes e CI permitirem; sem limite arbitrário de quantidade nem redução de qualidade.

## Sequência e bloqueios

| ID | Entrega | Natureza | Depende de |
|---|---|---|---|
| V2-00 | Auditoria e reforço da fundação C1–C17 | P0 | main atual |
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
- [ ] [C] Rigs/Attachments/pivôs de capô, portas, porta-malas e rodas para os três carros.
- [ ] [C] Usar sockets de componentes reais; não só posições genéricas do carro.
- [ ] [C] Regras de porta/capô: abrir, inspecionar, reparar, fechar, impedir abertura em movimento.
- [ ] [C] Som e feedback visual de cada ação, com alternativa visual para pistas sonoras.
- [ ] [C] Colisões seguras, limites de partes físicas e fallback de carros ausentes.
- [ ] [A] Casos de duplicação de interação, propriedade, posição, cancelamento e reconexão.
- [ ] [S] Abrir/consertar/fechar nos modelos reais no Studio.

**Aceite:** contato mecânico convincente sem simulação física integral de motor.

## V2-04 — Reparos ricos e variados (15 serviços)
- [ ] [C] Auditar cada um dos 15 serviços existentes quanto à integração com rig, peça e equipamento.
- [ ] [C] Procedimentos diferenciados por família; interação real em pneu, elétrica, motor, suspensão, direção e lataria.
- [ ] [C] Qualidade visível: defeito, peça danificada, ferramenta, ação e “antes/depois”.
- [ ] [C] Erros com retrabalho proporcional; sem perder pagamento devido a bug visual.
- [ ] [C] Integrar custo da peça, estoque, reputação, lucro, XP e recap da OS.
- [ ] [A] Testes por serviço, aborto, timeout, spam de remotes e replay.
- [ ] [S] Homologar 15 serviços no Studio e mobile/gamepad.

**Aceite:** consertar um motor tem sensação distinta de trocar um pneu.

## V2-05 — Mecânicos NPC realmente úteis
- [ ] [C] Melhorar pathfinding e recomputação; NPC caminha entre estoque, box, cliente e descanso.
- [ ] [C] Gerente escolhe OS, prioridade e especialização do funcionário; fila evita disputa pelo mesmo carro.
- [ ] [C] Mostrar produtividade, qualidade, salário, tempo e histórico de trabalho.
- [ ] [C] NPC usa peça/salário/equipamento e gera receita apenas após serviço concluído.
- [ ] [C] Proteger demissão/cancelamento/desconexão e despesa duplicada.
- [ ] [A] Testes simultâneos com 0/1/2 funcionários e 1/2/3 OS.
- [ ] [S] Observar caminhada/animações e carga de servidor em Studio.

**Aceite:** a equipe trabalha de maneira crível e não substitui o dono de imediato.

## V2-06 — Upgrade físico de negócio sem compras acidentais
- [ ] [C] Revisar plataformas C16: posição, preço, nível, benefício, saldo, bloqueio de compra involuntária.
- [ ] [C] Estender upgrades a boxes, recepção, estoque e contratações apropriadas, sem remover a loja de peças.
- [ ] [C] Feedback visual da melhoria que aconteceu de verdade; tempo, qualidade ou capacidade mensurável.
- [ ] [C] Compra segura em perfil, reentrada/queda durante save e confirmação para custos grandes.
- [ ] [A] Testes de pisar/ficar/sair, exploit, jogador vizinho e saldo insuficiente.
- [ ] [S] Confirmar que pads não bloqueiam passagem e não compram sem intenção.

**Aceite:** entender o investimento e ver o retorno sem abrir menus enormes.

## V2-07 — Bairro vivo e escalável
- [ ] [C] Pedestres ambientais com pools e rotas, evitando bloqueio de clientes e tráfego.
- [ ] [C] Trânsito de carros NPC, entregador de peças, rotina de clientes e rivais de oficina.
- [ ] [C] Limitar densidade e atualizações pelo dispositivo, distância e número de jogadores.
- [ ] [C] Remover NPCs/veículos órfãos no logout e evitar modelos pesados fora de vista.
- [ ] [A] Testes de spawn/despawn, cleanup e custo por tick.
- [ ] [S] Medir FPS/memória em mundo cheio com streaming e touch.

**Aceite:** sensação de bairro movimentado com desempenho previsível.

## V2-08 — Negócio e margem financeira
- [ ] [C] Extrato de receitas e despesas: serviço, peças, funcionário, publicidade, upgrade e contratos.
- [ ] [C] Decisões de estoque/reposição, qualidade de peças, preços e condições dos clientes.
- [ ] [C] Previsão de margem e aviso de lucro negativo ou caixa insuficiente.
- [ ] [C] Equilibrar renda manual, NPC e eventual automação offline limitada.
- [ ] [A] Testes de simulação de economia, anti-exploit e compatibilidade da persistência.
- [ ] [S] Playtest de 20–30 min com foco em decisões do proprietário.

**Aceite:** gerir a oficina é interessante mesmo quando NPCs estão reparando.

## V2-09 — Mercado de carros velhos / compra e revenda (P1, protótipo)
- [ ] [C] Mercado controlado, carro avariado, avaliação de custo e previsão aproximada de lucro.
- [ ] [C] Três variantes no primeiro slice e limite de estoque/vagas de carros próprios.
- [ ] [C] Reparar, modificar aparência e vender com risco e margem visíveis.
- [ ] [C] Não roubar espaço de OS de clientes; limitar dinheiro vindo de revenda.
- [ ] [A] Testes de compra/venda duplicadas, rollback e persistência do carro.
- [ ] [S] Provar que complementa a gestão, não transforma tudo em compra-venda.
- [ ] DECISÃO: expandir, simplificar ou retirar após playtest.

## V2-10 — Personalização comercial e showroom (P1)
- [ ] [C] Pintura/acabamento/rodas com visual antes/depois e preço transparente.
- [ ] [C] Showroom com número limitado de carros e física inativa fora da condução.
- [ ] [C] Benefício em satisfação/reputação sem obrigar corrida/tuning detalhado.
- [ ] [A] Testes de aplicação, cancelamento e persistência.
- [ ] [S] Performance e UX mobile/gamepad.

## V2-11 — Fundamentos do carro dirigido pelo jogador (P1)
- [ ] [C] Um veículo piloto com assento real, direção/freio/câmera/controles; preservar caminhos NPC.
- [ ] [C] Associar carro a uma OS, liberar apenas motorista autorizado e uma sessão por veículo.
- [ ] [C] Devolver carro ao box após timeout, desconexão, colisão ou cancelamento.
- [ ] [C] Servidor valida posição/velocidade/checkpoints e não confia no evento Touched do cliente para pagar.
- [ ] [A] Testes de spam, fuga de rota, respawn, rede ruim, propriedade de física e duplicidade.
- [ ] [S] Dirigir no bairro e voltar com 1–2 jogadores no Studio.

**Gate obrigatório antes de V2-12.**

## V2-12 — Test-drive para diagnóstico contextual (P1, FUTURO)
- [ ] [C] Tabela de elegibilidade por sintoma/defeito (direção, freio, suspensão, motor, rodas).
- [ ] [C] Disparar aleatoriamente SOMENTE entre condições elegíveis, com seed registrado no servidor.
- [ ] [C] Percurso curto alvo de 45–90 s, checkpoints, retorno e opção de encerrar com segurança.
- [ ] [C] Sons/vibrações/luzes e evidência diagnóstica não apenas sonora; pista útil para o reparo.
- [ ] [C] Um test-drive por sessão de OS; resultado, XP e dinheiro sempre verificados no servidor.
- [ ] [A] Testes de seed, gatilhos, falha, spoof, repetição, abortos e reconnect.
- [ ] [S] Validar que é divertido e não vira obrigação em todas as OS.

## V2-13 — Test-drive pós-reparo e retrabalho (P1, FUTURO)
- [ ] [C] Em parte dos reparos, oferecer teste de qualidade após reparo.
- [ ] [C] Estados: aprovado, teste incompleto, reparo inadequado, retrabalho; causa ligada ao estado real.
- [ ] [C] Retrabalho proporcional, comunicação com cliente, regras de satisfação e custos coerentes.
- [ ] [C] Não punir jogador por instabilidade de servidor/rota.
- [ ] [A] Testes de pagamento único e estado consistente após falha.
- [ ] [S] Playtest do ritmo de atendimento com e sem test-drive.

## V2-14 — Frotas, contratos e relações comerciais (P1)
- [ ] [C] Expandir contratos existentes com precificação, prazo, serviço, equipe e estoque.
- [ ] [C] Reputação/retorno de clientes e decisões econômicas de terceirizar.
- [ ] [C] Compatibilizar pagamento colaborativo, idempotência e saída de outros jogadores.
- [ ] [A] Testes de vários contratos simultâneos, prazo, fraude e liquidação.
- [ ] [S] Homologar diversão/social e clareza de lucro.

## V2-15 — Polimento transversal e segurança (P0)
- [ ] [C] Revisar código de todas as fases aprovadas, dívida técnica, regressões, licenças e remotes.
- [ ] [C] Consolidar custo de modelos, LOD, StreamingEnabled, áudio, NPC e física.
- [ ] [C] Verificar acessibilidade, traduções, prompts, touch/gamepad e feedback do negócio.
- [ ] [C] Verificar economia, dados, migrações e limites sem prometer atomicidade entre contas.
- [ ] [A] CI Rojo, testes/contratos, changelog e inventário de cenários adversos.
- [ ] [S] Avaliar FPS/memória/latência com usuários e dispositivos reais.

## V2-16 — Studio, beta e publicação (GATE DO PROPRIETÁRIO)
- [ ] [S] Rodar RunAllTests e StudioPlaceAudit no place com assets reais.
- [ ] [S] Executar todos os 15 serviços em diferentes modelos e dispositivos.
- [ ] [S] Testar loop do novato → 1ª OS → upgrade → contratação e faturamento.
- [ ] [S] Testar 2+ jogadores, remotes, desconexão, DataStore Studio e servidor publicado de testes.
- [ ] [S] Validar UI touch/gamepad, FPS, performance/streaming, áudios, animações e licenças.
- [ ] [S] Beta fechado e métricas reais de diversão, abandono, lucratividade e retenção.
- [ ] [S] Corrigir bugs P0/P1 e obter autorização final de lançamento.

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

**Não autorizado nesta etapa:** código V2, download automático, importação no place, publicação ou marcação de fases concluídas. Aguardando OK explícito.
