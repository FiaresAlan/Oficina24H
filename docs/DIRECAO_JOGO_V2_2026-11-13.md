# OFICINA 24H — DIREÇÃO DE PRODUTO E ARTE V2

**Versão:** 2.0 — decisão de direção aprovada em 13/11/2026  
**Status:** documento de decisão; implementação de novas mecânicas ainda depende de autorização explícita.  
**Base técnica auditada:** branch main, commit df3f1a66f12aa85afa8b2a09ba50af41106fee9b (A1–C17).  
**Documentos associados:** CHECK_LIST_MESTRE_V2.md; PESQUISA_MERCADO_V2_2026-11-13.md; AUDITORIA_V2_BASE_CODIGO_2026-11-13.md.  
**Preservar:** Issue #15 (checklist V1, histórico, bugs e portões ainda abertos). Não interpretar V2 como prova de implementação.

## 1. Visão e promessa

**Gênero principal:** gestão de negócios / tycoon de oficina com mecânica prática. **Não** é um simulador de engenharia automotiva e **não** é um idle vazio.

**Promessa para o jogador:** “Comece numa garagem de uma vaga, descubra defeitos, conquiste clientes, invista em ferramentas, contrate uma equipe que você vê trabalhando e transforme sua oficina no negócio mais reconhecido do bairro.”

**Frase-guia:** “Fácil de administrar, gostoso de consertar, recompensador de expandir.”

### Pilares inegociáveis, em ordem
1. **Progresso visível do negócio:** novas vagas, funcionários, balcão, estoque, equipamentos e fachada; sempre mostrar mudança física.
2. **Demanda e mundo vivo:** clientes de verdade chegam, explicam problemas, acompanham a espera e saem em veículos. O bairro tem circulação orgânica, sem impacto excessivo de NPCs no FPS.
3. **Mecânica tangível, acessível:** abrir capô, inspecionar, usar ferramentas e trocar peça de modo satisfatório; conhecimento ajuda, mas não é obrigatório para começar.
4. **Decisão econômica real:** preço, tempo, margem, estoque, reputação, contratação e escolha das ordens competem pelo orçamento.
5. **Autonomia progressiva:** contratar e treinar equipe permite ao jogador gerir vários serviços, sem deixar o jogador sem decisão interessante.
6. **Profundidade opcional:** trabalhos de motor, elétrica e test-drive ficam mais técnicos; o loop básico continua simples.

## 2. Direção visual APROVADA: híbrida estilizada

**NÃO** migrar toda a produção para low poly puro. **NÃO** substituir imediatamente os carros e ruas atuais. Usar uma linguagem “stylized grounded”:
- **Bairro externo:** formas legíveis, cores equilibradas, iluminação clara, tráfego/NPCs otimizados, estradas atuais preservadas como referência. Simplificar excesso de detalhes de objetos distantes.
- **Oficinas:** edifícios organizados, peças e máquinas com materiais convincentes, volumes claros, iluminação mais industrial e conforto de leitura; não usar decoração infantil.
- **Veículos:** silhuetas fortes e consistentes, material simples onde não houver interação, detalhes ricos nas regiões de reparo. Carros comuns, utilitários e modelos premium devem ser diferenciáveis de longe.
- **Momento técnico:** capô e portas que se abrem quando relevante, motor com áreas interativas, pneus/partes removíveis, ferramentas, som de torque, vibração e resultado antes/depois. Evitar uma “mágica” que conclui sem feedback visual.
- **HUD:** ênfase em valor, progresso, próximo upgrade e ocupação da oficina; sem poluição visual constante. Compra por plataforma só quando não bloquear passagem ou provocar compras involuntárias.
- **Fidelidade escalável:** LOD por distância e importância, StreamingEnabled, assets pesados apenas na cena ativa, texturas e efeitos de acordo com perfil do dispositivo. Não confundir “stylized” com baixa qualidade.

### Regras de arte para um carro
**Camada A (rua):** corpo externo simplificado, 4 rodas legíveis, luzes, cor, estado de conservação, pequenas marcas de dano.  
**Camada B (oficina):** capô/portas/porta-malas com pivôs, interior visível, elevador, rodas e zonas de ferramentas.  
**Camada C (operação):** 3–8 pontos de interação por serviço específico, componentes selecionados em malhas próprias/attachments, som, animação, evidência do defeito e peça substituída.  
**Não** fabricar um motor inteiro com centenas de componentes físicos ativos para cada carro do bairro.

**Pilotar primeiro com 3 arquétipos:** compacto, sedã e picape; incluir uma variação desgastada e outra premium. Após provar o pipeline, expandir catálogo. Não perder licenças/créditos e não trocar os modelos sem compatibilidade com sockets atuais.

### Regras para interação física
- Abrir capô = pivot/weld/constraint autorado e testado; bloqueio quando carro estiver se movendo.
- Porta/porta-malas só abrem em serviços pertinentes, não por animação aleatória.
- Peças “desmontáveis” podem ser visuais controladas por estado; física livre somente se gameplay exigir, sempre com limites de peças.
- Checklists do procedimento, não cliques repetitivos sem significado.
- Serviço que falha deve gerar evidência: ruído, luz de painel, feedback de scanner, sensação em volante ou inspeção objetiva.

## 3. Loop principal e ritmo

**30–60 s iniciais:** cliente chega, reclama do defeito, execução guiada com uma ferramenta real, pagamento e primeiro upgrade visível. O usuário domina a regra de uma OS antes de ver menus complexos.  
**Ciclo curto (2–4 min, alvo a validar):** chegada → ouvir/diagnosticar → reservar peça/box/funcionário → reparar/validar → cobrar → avaliação → decisão de reinvestimento.  
**Sessão (10–25 min):** lidar com 3–6 decisões úteis, melhorar ferramenta, contratar/treinar, reorganizar fila, desbloquear box ou aceitar contrato.  
**Longo prazo:** especializar negócio, ampliar 1→2→4→6 boxes, atrair frotas, vender serviços premium, ter mecânicos confiáveis e uma operação lucrativa.

Toda recompensa financeira precisa de uma fonte visível (OS/cliente/venda/contrato), custo e feedback do lucro **líquido**; evitar renda passiva arbitrária que desvalorize decisões.

## 4. Negócio: transformar sistemas existentes em gestão de verdade

### Frente de loja
- Recepção com fila física + painel claro: nome, veículo, reclamação, urgência, tempo estimado, preço previsto, margem estimada e status. O defeito real segue oculto até diagnóstico.
- Decisões: aceitar, agendar, recusar, terceirizar, priorizar, dar desconto ou solicitar mais detalhes do cliente.
- **Preço:** a oficina tem faixa configurável e informa impacto esperado em procura e satisfação; não dar números aleatórios de mercado sem modelo.
- Clientes recorrentes/empresariais respondem a reputação, pontualidade, qualidade, preço e tratamento.

### Operação
- Cada box tem um estado visível: livre, aguardando peça, diagnóstico, reparo, teste, liberado.
- Funcionário NPC tem função/ocupação, especialização, velocidade, qualidade, salário e histórico de produção. O proprietário pode atribuir/priorizar OS; NPC não “desaparece para calcular dinheiro”.
- Upgrade de equipamento altera tempo, qualidade, capacidade ou serviço desbloqueado **de maneira explicada**. No máximo poucas camadas de melhoria até que cada uma seja visualmente perceptível.
- Loja física e estoque continuam. Pads são atalho para expansão de infraestrutura, não substituto das compras com catálogo/quantidade.
- Caixa, estoque, custo das peças e salários devem aparecer em resumo do dia: receitas, gastos, margem e pedidos concluídos.

### Novos negócios opcionais (futuro, não obrigatório no lançamento)
- **Compra, restauração e revenda:** *piloto secundário*, não substituir conserto de carros de clientes. Comprar carro avariado, estimar custo, restaurar, precificar, vender. Risco real de compra ruim; possível lucro.
- **Personalização comercial:** pintura simples, rodas, acabamento, vitrine e “antes/depois”. Desbloquear em ritmo posterior, evitando liberar uma concessionária inteira.
- **Frota/contratos recorrentes:** propostas com quantidade, prazo, margem e risco de atraso; equipe e estoque tornam-se estrategicamente úteis.
- **Clientes especiais e reputação:** avaliação/reclamação concreta, possível retrabalho proporcional à qualidade, benefícios na demanda; não impor punição artificial por desconectar.

## 5. IDEIA NOVA — Test-drive para diagnosticar e aprovar reparos (FUTURO)

**Decisão:** aprovar como **hipótese de mecânica forte**, não implementar nesta rodada; colocar depois de veículo dirigível interoperável e capô/peças integrados. **Nunca exigir test-drive em 100% das OS.**

### Quando acontece
1. **Diagnóstico em condução:** parte das reclamações de suspensão, direção, freio, câmbio, alinhamento, ruído ou falha de ignição requer/beneficia teste. Pergunta inicial do cliente dá pistas.
2. **Verificação pós-reparo:** em parte das OS qualificadas, cliente pede conferência antes da entrega ou o próprio mecânico decide testar para aumentar a confiança/qualidade. Pode descobrir correção incompleta e solicitar retrabalho.
3. **Evento raro de problema intermitente:** defeito não se manifesta na primeira inspeção, mas surge na rua quando o motor aquece ou em determinada condição de aceleração/curva/frenagem. A aleatoriedade altera **a ocorrência**, não a correção do diagnóstico.

### Estrutura recomendada
- Percurso curto no bairro (alvo inicial 45–90 s, ajustar em playtest) com checkpoints simples; permitir encerrar sem abandonar a OS. Áreas seguras, rota de retorno e proteção contra estacionar em lotes de outros jogadores.
- O player dirige **o carro da OS em sessão temporária**, sem ganhá-lo; controle devolvido à oficina após conclusão/cancelamento/desconexão.
- Sintomas testáveis: volante puxando, vibração quando acelera, batida na suspensão, atraso de resposta, motor falhando, aviso elétrico, ruído de roda/freio.
- Sinais são audiovisual/háptico e só alguns por OS; a física não precisa simular dano real de motor para ser convincente.
- **Servidor guarda** defeito, seed de sintomas, condições de disparo e resultado; cliente só reproduz som/tremor/efeito. Não pagar por evento físico \`Touched\` ou tempo reportado pelo cliente.
- Ao retornar, escolher hipótese com base em evidências; após reparo, registrar “aprovado”, “reteste recomendado” ou “falha detectada”.
- A falha deve ser justa e explicável, não aleatoriamente roubar o pagamento do jogador sem possibilidade de correção.

### Regras de proteção
- Um test-drive ativo por ordem/veículo e uma única rota por sessão, sem clonagens de pagamento ou múltiplos carros fantasmas.
- Network ownership do motorista para responsividade, com validação servidor de posição/velocidade/rota, limites e fallback em perda de rede.
- Timeout, abandono, respawn, reconexão, colisões e troca de motorista sem perda permanente da OS.
- Controles mobile/gamepad; câmera legível; botão claro “retornar à oficina”; opção de pular quando o teste não é necessário.
- Alternativa assistida se veículo/mecânica do carro não suportar condução. **Não comprometer o loop de negócio por uma peça de física frágil.**

### Exemplo de experiência
Cliente: “Quando eu acelero depois de uma curva, o carro treme.”  
Jogador aceita, roda 50 segundos, observa vibração sob aceleração, encontra erro na roda ou suspensão, retorna, compra/usa peças e repara. Em alguns casos, faz teste rápido de confirmação e recebe avaliação melhor. Em outros, diagnóstico de bancada basta.

## 6. Variação, acessibilidade e dificuldade

- **Serviços:** classes simples, intermediária, especializada; sempre dizer por que o procedimento muda.
- **Dificuldade:** variável por diagnóstico, peças e equipe, não só por minijogo de timing.
- **Automação:** gestor atribui prioridades e estoque; pode operar manualmente para ganhar margem/XP/qualidade. O NPC nunca substitui a necessidade de decisões.
- **Acessibilidade:** todo prompt em PC, toque e controle; ícones + texto; contraste; som não pode ser a única evidência de defeito; modo de movimento de câmera confortável.
- **Falha produtiva:** o jogador pode errar e retrabalhar com custo controlado; não perder um turno inteiro por falta de informação que o jogo escondeu.
- **Aleatoriedade controlada:** defeitos, veículos e ordens vêm de tabelas de peso e nível; cenários testáveis por seed. Sorte não é desculpa para receita ou dificuldade injustas.

## 7. Economia e monetização
- Receita vem de OS, opcionais e contratos; despesas de peças, salários, infraestrutura e retrabalho; informar saldo e lucro líquido.
- Evitar um meta de “ganhar offline sem fazer nada” que ultrapasse jogar. **Offline** pode trazer relatórios/pedidos limitados e justos somente após comprovar economia e anti-exploit; nunca prometer primeiro.
- Monetização cosmética/conveniência moderada, não peça obrigatória para diagnosticar nem “carro funcionando só para pagantes”.
- A/B de preços e duração deve medir retenção e frustração, não dependência artificial.
- Métricas recomendadas: tutorial completo, 1ª OS, 1º upgrade, primeiro funcionário, pedidos/hora, tempo improdutivo, margem líquida e abandono por erro; estimativas e metas são hipóteses até dados reais.

## 8. O que preservamos e o que NÃO faremos
**Preservar:** rua e estrutura do bairro atual, clientes/ordens com NPC, loja física, estoque físico, ranking, cooperação entre mecânicos, 15 serviços existentes, protocolos de reparo e persistência já escritos.  
**Evoluir:** exterior leve, carros modulares, som e qualidade do trabalho, interface de gestão, comportamento de equipe, circulação da cidade, compra/venda opcional e test-drive contextual.  
**Evitar:** substituir tudo por low poly de uma vez, apostar que muitos jogadores = arte correta, dirigir após toda OS, corrida PvP como núcleo do jogo, física completa de motor em cada carro, muitos NPCs sem orçamento de streaming, regressão do protocolo financeiro, pedir confirmação para toda ação trivial ou comprar acidentalmente no piso.

## 9. Entregas, revisão e autorização
1. **Agora:** esta documentação e CHECK_LIST_MESTRE_V2, sem mudar sistemas de gameplay.
2. **Após aprovação explícita do usuário:** implementar uma fase V2 inteira por rodada; até duas quando forem compatíveis e não afetarem qualidade. Revisar código antigo integrado, testes automatizados, documentação, CI verde e commit seguro.
3. **Portões de código:** revisão dos módulos tocados, teste unitário/contrato de regressão, migrações, segurança, build, auditoria de performance estática e relatório de limitações.
4. **Portões Studio:** ficam abertos para homologação pelo proprietário ao fim do pacote de código, sem marcar falso “aprovado”.
5. **Beta e publicação:** não depender só de checklist cheio de código; exigir experiência do jogador e resultados reais.

## 10. Critérios de decisão
Qualquer mecânica nova precisa mostrar: (a) qual decisão relevante cria, (b) como comunica progresso, (c) onde entra no loop de negócio, (d) como é testada, (e) qual custo de performance/desenvolvimento, (f) por que não desvaloriza as mecânicas existentes.

**Documento de direção aprovado; execução das fases V2 ainda não iniciada.**
