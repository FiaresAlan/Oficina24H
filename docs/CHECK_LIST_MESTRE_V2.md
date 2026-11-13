# CHECK_LIST_MESTRE_V2 — OFICINA 24H

**Versão:** 2.0, 13/11/2026. **Situação:** planejamento, aguardando autorização para executar gameplay V2.  
**Direção aprovada pelo proprietário:** híbrida — estilização legível do mundo + reparos visualmente mecânicos + gestão de negócio.  
**Código base:** main df3f1a66 (C1–C17). **Preservar:** Issue #15 V1 como histórico.  
**Documentos de referência:** DIRECAO_JOGO_V2_2026-11-13.md, PESQUISA_MERCADO_V2_2026-11-13.md, AUDITORIA_V2_BASE_CODIGO_2026-11-13.md.

## Regra de preenchimento
- [C] = código e teste de regressão escritos e integrados.
- [A] = verificações automáticas e Rojo executados com sucesso no commit final.
- [S] = jogo **realmente** testado no Roblox Studio / dispositivo.
- Nada é marcado [x] por ter sido planejado. **Todas as fases V2 abaixo começam pendentes.**
- O proprietário pretende executar a homologação Studio ao final. Isso não dispensa testes de código em cada etapa e mantém riscos de integração abertos.
- Implementar **uma fase inteira por rodada**. Duas fases apenas quando independentes e com CI verde.

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

## V2-00 — Integridade pré-V2
**Meta:** não expandir um código com contas ou serviços inconsistentes.
- [ ] [C] Reauditar DataService/WorkshopService, 15 reparos, NPC, loja e plataformas, incluindo todas as alterações C1–C17.
- [ ] [C] Resolver/mitigar fluxo legacy timing sem recibo durável, conta de NPC, provas finitas de repasses e claims órfãs.
- [ ] [C] Provar idempotência do débito/compra/upgrade, cancelamento, fraude de remotes, desconexão, reconexão e rollback.
- [ ] [C] Inventariar assets, licenças e integração no place real; listar substituições necessárias e fallbacks.
- [ ] [C] Escrever testes adversos e revisão das migrações schema v1–v8.
- [ ] [A] CI Rojo, contratos e verificações disponíveis aprovados, logs registrados.
- [ ] [S] RunAllTests, StudioPlaceAudit, duas contas e 15 serviços no place (a ser feito pelo usuário).

**Aceite de código:** não há P0 desconhecido sem plano; erros conhecidos ficam registrados; sem alegação de atomicidade multi-chave.

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

**PORTÃO DE AUTORIZAÇÃO:** aguardando a ordem explícita do proprietário para iniciar **V2-00**. Publicar esta documentação não significa autorização de gameplay.
