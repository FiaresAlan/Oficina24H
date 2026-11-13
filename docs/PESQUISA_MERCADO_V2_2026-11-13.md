# OFICINA 24H — PESQUISA COMPETITIVA V2

**Data da consulta:** 13/11/2026.  
**Escopo:** referências, mecanismos de gameplay e sinais de fricção, sem declarar que popularidade prova qualidade. A análise **não** significa que houve acesso ao gameplay interno de todos os jogos. Separar fatos documentados, relatos isolados e riscos deduzidos.

## 1. Junk Mechanics — Oil Leak
Jogo: https://www.roblox.com/games/70435795041539/Junk-Mechanics  
Fonte oficial: comprar veículos danificados, reparar, pintar e revender para lucro, expandindo coleção; declara suporte a computador, celular e console. Tracker não oficial Rolimon’s (consulta de 13/11/2026): ~1.834 jogadores no instante, ~72,5 milhões de visitas, ~15 minutos de sessão média exibida e pico histórico maior; números instantâneos oscilam e **não** autorizam concluir que low poly causou sucesso. https://www.rolimons.com/game/70435795041539

**Transferível:** loop objetivo de compra → avaliação → reparo → ganho, estado visual do carro, coleção de veículos e negociação. **Na Oficina 24H:** colocar compra/revenda como filial/serviço secundário, preservando a oficina que atende clientes.

**Críticas verificadas:** não foi encontrada amostra confiável suficiente de avaliações textuais dos jogadores para apontar reclamação predominante desse título; métricas de aprovação não explicam o motivo de avaliações negativas.  
**Riscos para nossa adaptação (inferências, não queixas comprovadas do jogo):** repetição de carro→venda sem gestão; arbitragem de dinheiro fácil; carros comprados eclipsarem o atendimento de NPCs; coleção infinita e storage caro.

## 2. My Car Workshop! — Frisbee Entertainment
Jogo: https://www.roblox.com/games/99701434175669/My-Car-Workshop  
Fonte oficial: carros por raridade, trabalhadores, estações de reparo, expansão de terrenos, coleção/exposição e declaração de progresso dos trabalhadores e construções offline. Esta descrição é **alegação do próprio jogo**, não prova técnica de renda offline contínua.

**Transferível:** fantasia de “dono de oficina”, equipe visível, desbloqueio da capacidade e progressão espacial. **Na Oficina 24H:** distinguir supervisor/gestor de mecânico manual; eventos e previsões no quadro, expansão vinculada a lucro, clientes e especializações.

**Críticas verificadas:** sem conjunto público confiável de reviews textuais específicas localizado nesta pesquisa.  
**Riscos para nossa adaptação (hipóteses):** funcionários tornam dono espectador; rentabilidade offline desbalanceia o trabalho ativo; espaço cresce antes de existir demanda; progressão baseada só em espera.

## 3. Fix It Up! — .workspace
Jogo: https://www.roblox.com/games/72712036210947/Fix-It-Up  
Fonte oficial: comprar sucata, reparar partes, ferramentas/bancadas, pintar, vender e ganhar lucro; aprofundamento de reparo automotivo. Histórico comunitário de versões contém correções específicas de interface mobile, controles de gamepad, bugs da loja de peças e de reparo de bateria, entre outras (o histórico é mantido por fãs e pode não ser exaustivo):  
https://fix-it-up.fandom.com/wiki/Events_/_Updates  
https://fix-it-up.fandom.com/wiki/Update/2.3.0

**Relatos pontuais de jogadores encontrados:** comentário no r/roblox de março de 2026 elogia o jogo mas relata banimento falso de anticheat após reset; um comentário no r/CarDealershipTycoon de junho de 2026 relata lentidão no celular ao jogar Fix It Up. **São relatos isolados**, não demonstração de falha generalizada nem julgamento do desenvolvedor:  
https://www.reddit.com/r/roblox/comments/1rpbqyw/suggest_me_a_game/  
https://www.reddit.com/r/CarDealershipTycoon/comments/1uha7tr/i_got_it/

**Transferível:** estados físicos de peças, ferramentas específicas, antes/depois, carro danificado e satisfação em recuperar veículos. **Na Oficina 24H:** usar componentes selecionados e feedback de serviço, sem exigir desmontagem total para toda tarefa.

**Riscos pertinentes:** complexidade do menu de peças, UX difícil no touch, FPS ruim com excesso de malhas e anticheat mal calibrado. Esses riscos podem ser reforçados pelos relatos/patches acima, mas exigem QA próprio.

## 4. Mechanic Legends — Mechanic Devs
Página usada nesta pesquisa: https://www.roblox.com/games/9265443535/Car-Mechanic-Simulator  
Descrição disponível: mais de 50 carros, desmontagem e melhoria do motor, pintura/tuning, corridas de arrancada e trabalhos alternativos de entrega/táxi. **Atenção:** existem páginas e experiências com nome “Mechanic Legends” semelhante; não misturar métricas e críticas entre IDs diferentes. Não usar números de CCU de outro título sem identificar ID/universe.

**Transferível:** capô abrindo, partes de motor claramente visíveis, ferramentas na mão, roda, iluminação industrial e a satisfação de tocar no componente certo. **Na Oficina 24H:** técnico apenas nos reparos relevantes, com profundidade opt-in e linguagem de gestão acessível.

**Críticas verificadas:** não apareceu amostra independente e suficiente de reviews específicas neste levantamento.  
**Riscos para nossa adaptação (inferências):** escopo técnico enorme, sensação de lentidão por desmontagem repetida, performance em dispositivos modestos, corrida/tuning sequestrarem o loop principal de negócios.

## 5. Feedback geral de comunidade Roblox (NÃO atribuível aos quatro jogos)
Discussão no r/roblox em 04/10/2026 critica jogos percebidos como monetizados demais, cópias de fórmulas de sucesso e progressão vazia. É opinião de participantes e não uma análise estatística:  
https://www.reddit.com/r/roblox/comments/1wxq5ra/what_happened_to_roblox_games/

**Implicação:** copiar sensações positivas e evitar progresso vazio, não replicar o simulador de fazenda só pelo número de jogadores simultâneos.

## 6. Matriz de decisão
| Mecânica | Referência | Decisão V2 | Prioridade | Motivo |
|---|---|---|---|---|
| Crescimento físico de oficina | My Car Workshop | APROVAR / evoluir | P0 | Fantasia central de gestão |
| Funcionário ativo e visível | My Car Workshop | APROVAR / aprofundar | P0 | Fazer contratação ter consequência |
| Equipamento e upgrade instantâneo | Referência do usuário (jogo de fazenda) | APROVAR com proteção de compra | P0 | Clareza de investimento |
| Capô e componente interativo | Mechanic Legends / Fix It Up | APROVAR por serviço | P0 | Contraste entre mundo leve e reparo rico |
| Compra/reparo/revenda | Junk Mechanics / Fix It Up | PILOTO secundário | P1 | Boa decisão de margem, mas pode desviar o núcleo |
| Pintura/coleção de veículos | Junk Mechanics / Fix It Up | P1 | P1 | Status e variedade |
| Test-drive diagnóstico e pós-reparo | Ideia do proprietário + mecânica real | FUTURO, fase independente | P1 | Diversidade sem obrigatoriedade |
| Corridas de arrancada | Mechanic Legends | ADIAR / não nuclear | P3 | Desvia da gestão |
| Mecânico offline ilimitado | My Car Workshop (descrição) | NÃO COPIAR literalmente | P3 | Desvaloriza o trabalho ativo |
| Desmontagem integral de todo motor | Mechanic Legends | NÃO COPIAR como requisito universal | P3 | Alto escopo e baixo retorno inicial |

## 7. Fontes técnicas para testar segurança/viabilidade
- Roblox network ownership: https://create.roblox.com/docs/physics/network-ownership — veículos controlados pelo cliente são responsivos, porém dados de física podem ser manipulados; validação server-authoritative para pagamento.
- Roblox pathfinding/StreamingEnabled: https://create.roblox.com/docs/characters/pathfinding — caminhos podem ficar bloqueados por conteúdo em streaming, exigindo recomputação.
- Roblox security/network ownership: https://create.roblox.com/docs/scripting/security/network-ownership — não confiar em colisão ou física do cliente como fato financeiro.

## 8. Perguntas a validar, não fatos provados
- Um test-drive opcional de 60 s melhora satisfação ou interrompe o loop?
- Ver um NPC trabalhar aumenta percepção de valor da contratação?
- Exibir lucro líquido, além de moedas brutas, aumenta decisões de gestão?
- Um carro externo simplificado com motor mais detalhado é mais memorável do que o visual atual?
- Comprar/revender ajuda o início ou disputa a atenção com serviços de clientes?

Teste esses pontos em uma fatia vertical controlada e registre observações; não declare sucesso só por CCU de outras experiências.
