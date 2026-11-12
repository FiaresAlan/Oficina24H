# OFICINA 24H — PRODUCT MASTER DOCUMENT v3.0 (PROPOSTA)
**Data:** 12/11/2026  
**Repositório:** https://github.com/FiaresAlan/Oficina24H  
**Natureza:** documento mestre de produto, auditoria crítica, GDD integrado e roadmap de implantação.  
**Status de aprovação:** **PROPOSTA** — o Product Master Document v2.0 (06/11/2026), preservado na biblioteca do proprietário, continua a autoridade formal até aprovação expressa da v3.  
**Implementação:** Claude/Fable 5.2 com acesso ao GitHub, inicialmente SEM Computer Use, SEM Roblox Studio/Blender/terminal local.  
**Escopo desta entrega:** análise e planejamento; nenhuma mudança de gameplay, DataStore ou scripts de produção.

> Tese central: o Oficina 24H não precisa de mais uma coleção de mecânicas independentes. Precisa fazer o jogador **gostar de ser mecânico**, perceber a consequência de suas decisões e encontrar motivos legítimos para conviver e competir com outros profissionais no bairro.

---

## 0. CONTROLE DE FONTES, CONFIANÇA E DECISÕES

Fontes comparadas:
1. **[V2]** Oficina24H_Product_Master_Document_v2.0.docx, de 06/11/2026: direção oficial, 24 seções, 13 páginas, maior autoridade de escopo.
2. **[COD]** branch main do GitHub inspecionada em 12/11/2026; árvore do repositório SHA 3988cb2a34776c3513cb6106cede81cce107cbb5. Inclui src/server, src/shared, src/client, docs, pipeline e tools. A árvore não é prova de teste funcional.
3. **[GEM]** relatório técnico do Gemini fornecido pelo proprietário nesta conversa: duas descrições do Mechanic Legends e propostas de adaptação. **Não houve inspeção direta das imagens dos seis vídeos do YouTube** por esta análise; detalhes visuais específicos não foram independentemente confirmados.
4. **[ANT]** decisões anteriores explícitas do proprietário: bairro com oficinas próximas; clientes NPC físicos; problema oculto até investigação; estoque e loja físicos; avaliações imediatas; especialidades, funcionários e contratação humana; expansão nível 0->1; visual maduro, realista/semi-realista e assets gratuitos licenciados; rejeição de sabotagem e roubo de entregas; experiência social sem depender de amigos online.
5. **[PROP]** críticas, hipóteses e propostas originais deste documento. Estimativas de duração, economia e impacto são metas a testar, não resultados observados.

**Regra de governança:** decisões já aprovadas na v2 permanecem obrigatórias. Quando a v3 propuser antecipar co-op, receitas físicas ou outras expansões, isso é **proposta de exceção**, não mudança automática do escopo P0. Não reclassificar uma ideia só porque o código já existe.

**Contradição detectada:** o prompt operacional de 14 fases criado posteriormente contém muitas expansões (receitas complexas, guincho, frota compartilhada, tuning) que podem ser interpretadas como pré-requisitos. Este documento estabelece **duas trilhas**: fechamento do MVP presencial e evolução de produto pós-validação. O prompt de execução deve ser alinhado a esta hierarquia antes de orientar trabalho de grande porte.

---

## 1. VISÃO DE PRODUTO — QUAL É O JOGO?

**Definição oficial refinada:** Oficina 24H é um simulador social de profissão e empreendedorismo automotivo. Cada pessoa começa como mecânico de bairro, atende clientes e transforma competência técnica em confiança, renda, especialização e crescimento empresarial. As oficinas coexistem em um bairro compacto, competem pela preferência dos clientes e podem compartilhar trabalhadores autorizados.

**Fantasia principal:** “Eu entendi o problema, escolhi a solução correta, trabalhei no carro e conquistei um cliente satisfeito.”

**Fantasia secundária:** “Eu construí uma oficina respeitada e minha escolha de serviços, preços, equipamentos e equipe faz diferença.”

**Fantasia social:** “Posso ajudar outro mecânico em trabalho real, ser contratado por minha especialidade, visitar oficinas e competir sem destruição ou roubo.”

**Diferenciação desejada:** o jogo mistura procedimento mecânico curto, NPC com consequência, evolução empresarial e mercado social. Não vira jogo de corrida, tycoon ocioso nem simulador de desmontar cem parafusos.

### 1.1. Pilares de qualidade e como comprová-los

| Pilar | Evidência jogável | Falha que o contradiz |
|---|---|---|
| Operação mecânica | Diagnóstico e operações distintas resultam em reparo verificado | Todos os serviços são a mesma barra de timing |
| Clientes e confiança | NPC tem queixa, paciência, avaliação, retorno e efeito na demanda | Cliente é só gerador de moedas |
| Gestão empresarial | Compras, preço, estoque, qualidade e capacidade mudam possibilidades | Equipamentos servem só como bloqueio artificial |
| Bairro social | Jogadores têm motivo para visitar, prestar serviço e observar vizinhos | Cada oficina é um menu isolado |
| Progressão profissional | Especialidade desbloqueia novos tipos de desafio e contrato | XP só eleva número e velocidade de ganho |
| Clareza e acessibilidade | PC/celular mostram objetivos e explicam erro sem ocultar veículo | HUD confusa, modal invasivo, texto microscópico |

### 1.2. Público e produção

Hipótese inicial v2: interesse especial em jogadores de 16–24 anos, sem limitar outros públicos e sem prometer faixa etária Roblox. Estilo **semi-realista/realista maduro**, PBR moderado, silhuetas reconhecíveis e leitura clara. Para primeira publicação: PC e celular obrigatórios. O detalhe das peças e iluminação deve ser compatível com desempenho em dispositivos modestos.

### 1.3. Não objetivos mantidos

**NÃO:** sabotagem, roubo de entregas, griefing, perda de patrimônio por ficar offline, sorteios pagos, pay-to-win de especialidades, mundo aberto gigante, física profissional minuciosa, corrida como atividade principal, player trade sem anti-dupe, veículos pesados no MVP. **Assistência externa, carro dirigível, guincho de reboque, tuning e grandes galpões** não bloqueiam lançamento P0.

Observação: **guincho de motor** (máquina interna da oficina) é diferente de **guincho de reboque** (transporte externo). Tratar como sistemas separados.

---

## 2. DIAGNÓSTICO CRÍTICO DO CÓDIGO ATUAL

Esta seção não é uma promessa de defeito reproduzido no Studio; é uma auditoria estática de comportamento e arquitetura, com locais verificáveis.

### C01 — O jogador exerce pouca mecânica [ALTA / produto]
**Evidência:** src/shared/RepairRules.lua implementa plano de 3–5 toques em marcador móvel; src/client/UI/RepairGame.lua apresenta esse mecanismo. src/server/WorkshopService.lua inicia BuildPlan e conclui pela validação desses toques.

**Crítica:** 15 tipos de defeito sobre o mesmo gesto podem parecer 15 nomes para um único trabalho. Equipamento comprado frequentemente funciona como chave de acesso, não como instrumento de decisão. Este é **o maior risco de diversão**.

**Correção mínima antes de aprofundar:** duas ou três **famílias de operação** curtas e verdadeiramente diferentes, ligadas a testes/peças. Não é necessário simular 15 carros modulares ou cada parafuso para o P0. Incorporar inspeção, ação contextual e verificação de resultado.

### C02 — Diagnóstico funciona mais como palpite que investigação [ALTA / produto]
**Evidência:** src/shared/DiagnosisRules.lua gera três opções com defeito real; src/client/UI/DiagnosisGame.lua apresenta as escolhas; erros reduzem qualidade final.

**Crítica:** o jogador pode escolher por tentativa e erro, sem evidência física. Penalizar palpite sem fornecer ferramenta informativa suficiente não é profundidade técnica.

**Correção:** adicionar pelo menos **um exame informativo** para cada família piloto: inspeção de pressão/vazamento, medição elétrica e temperatura/fluido. Depois escolha orientada por evidência, não por sorte.

### C03 — Cooperação atual é substituição do executor [ALTA / diferencial social]
**Evidência:** src/server/WorkshopService.lua, CompleteCollaborativeJob, permite que o convidado finalize sem mesmo minijogo; preço usa qualidade padrão 85%, XP do convidado é metade do serviço.

**Crítica:** a feature vende “trabalho em equipe”, mas dois jogadores não realizam tarefas complementares no mesmo veículo. O colaborador troca proprietário por executor, não cria cooperação operacional.

**Correção:** primeiro permitir colaboração **limitada** numa OS simples (um investiga/prepara, outro instala/testa) com contribuição real; guincho pesado fica para posterior, com fallback solo. Proteger pagamentos e permissões.

### C04 — Rivais podem prosperar sem conseguir serviço [ALTA / integridade do mercado]
**Evidência:** src/server/RivalService.lua, início de RivalService.Serve: incrementa TotalEarned, Reputation, RatingCount e RatingSum **antes** de buscar vaga e antes de BuildCar confirmar carro. Se não há vaga/carro, retorna depois de já creditar resultados.

**Crítica:** não é mercado de mérito; rivais podem subir no ranking sem atendimento visível. É também risco de quebrar confiança do jogador na concorrência.

**Correção:** gerar transação de serviço ao reservar baia e **creditar faturamento, nota e reputação apenas depois de resultado/tempo de serviço definido**, de forma idempotente. Testar ausência de baia, falha de spawn e saída de rival.

### C05 — Loja física pode falhar em modo permissivo [MÉDIA/ALTA, condicional]
**Evidência:** src/server/WorkshopService.lua, função nearShop retorna true quando o prédio LojaAutopecas não existe ou não é BasePart. src/server/StationService.lua usa lógica semelhante para Construtora ausente. Comentário justifica testes no Edit.

**Crítica:** numa experiência publicada com cena incompleta, as regras de presença física podem ser contornadas. **Não afirmar exploit reproduzido**, mas tratar como risco de integridade/contrato de mapa.

**Correção:** distinguir modo de teste autorizado via RunService:IsStudio() de jogo publicado. Em produção, ausência de edifício deve falhar de forma segura e logar erro; QA tem caminhos especiais explícitos.

### C06 — Fórmula de atratividade pode favorecer excessivamente preço baixo [MÉDIA / economia]
**Evidência:** src/shared/CustomerRules.lua usa PriceFactor = (1 / Price)^2, com reputação, nível, distância, fila e rating. A escolha é **probabilística**, incluindo WalkAwayScore.

**Crítica:** não é correto dizer que preço determina sozinho cada cliente, porém a elasticidade é forte; pode transformar estratégia ótima em baixar tarifa e atender em massa. A combinação de boosts de Rush, freguês, amigo e combo merece simulação.

**Correção:** perfis de cliente com pesos distintos por urgência/qualidade/preço e medição de receitas/margem. Simular distribuição antes de trocar fórmula. Não inventar “o cliente te rejeitou por preço” se a seleção foi estocástica sem explicação causal determinística.

### C07 — Máquina física, interação ainda genérica [ALTA / produto]
**Evidência:** src/server/EquipmentService.lua cria equipamentos com prompt “Usar”; WorkshopService.checkRepairable exige equipamento, nível e proximidade; StartRepair abre o mesmo BuildPlan.

**Crítica:** elevador e scanner têm apelo visual, mas possuir a máquina quase não altera **qual ação o jogador executa**.

**Correção:** scanner produz evidência; desmontadora permite operar pneu; elevador dá acesso a pontos inferiores; bancada dá capacidade de tratar peça. Os mesmos tipos de operação podem ser reutilizados entre serviços.

### C08 — Mercado e contratos não equivalem a comunidade [MÉDIA / produto]
**Evidência:** ContractService guarda contrato indexado por UserId e FleetDone credita o próprio proprietário; não há contrato consorciado entre oficinas. RivalService simula negócios NPC.

**Crítica:** “tem contrato” não significa “tem conteúdo social”. Comunidade exige observar trabalho de outros, compartilhar serviço autorizado, resultados e oportunidades.

**Correção:** para P0, oficinas vizinhas e quadro público claros; para P1/P2, uma OS compartilhada e mutirão com papéis. Não duplicar ContractService.

### C09 — Loop de reparo interrompe continuidade física [MÉDIA / UX]
**Evidência:** VehicleService/VehicleFx exibem rodas, capô, fumaça e efeitos cosméticos, mas não há inventário server-side de componente removido por carro equivalente a uma receita de desmontagem.

**Crítica:** jogador vê uma peça sair enquanto executa barra de timing, mas não decide onde colocá-la, limpá-la ou substituí-la.

**Correção:** em piloto visual de carro, criar slots/estados de peça e ação contextual; **não** transformar todos os carros em simuladores 1:1.

### C10 — Promessa visual e estado de assets divergem [ALTA / lançamento]
**Evidência:** README.md informa place e vários modelos em ServerStorage/Assets fora do GitHub. docs/ORIGEM_ASSETS.md registra sprites de HUD, pacote de ícones e licenças pendentes. O código procedural não comprova PBR final.

**Crítica:** nenhum plano de código em GitHub-only consegue validar visual final ou importar arte no place. Incluir esse trabalho nas “fases concluídas” gera falsa sensação de progresso.

**Correção:** manifesto de assets com fonte, licença, modelo, sockets, escala, pivô e importação pendente. Verificar créditos antes de publicar; reservar sessão futura de Studio/MCP para integração, PC e celular.

### C11 — Indicadores de progressão podem dominar a experiência [MÉDIA / design]
**Evidência:** Config.lua possui bônus por amizade (+10%), cliente fiel (+25%), Rush (multiplicador 1,5), prêmios periódicos e eventos; ProgressRules tem missões/conquistas/ligas.

**Crítica:** há muitos gatilhos de moeda/recompensa para pouca variedade de trabalho manual. Isso pode esconder o tédio por um tempo, sem resolvê-lo. E empilhar multiplicadores ameaça inflação.

**Correção:** medir qualidade e repetição de serviços antes de acrescentar qualquer multiplicador; priorizar recompensas intrínsecas, veículos transformados e depoimento do cliente. Simular economia.

### C12 — Dois riscos de atraso [ALTA / execução]
**Evidência:** Product Master v2 prioriza MVP presencial/validação mobile; prompt operacional recente propõe 14 fases incluindo restauro e tuning; docs antigos relatam dezenas de assets e testes automatizados, mas o README afirma que ainda faltam testes com jogadores reais, mobile, desempenho e licenças.

**Crítica:** a execução pode se tornar interminável se cada ideia nova entrar como requisito. Um GDD gigante não conserta sensação de jogo se não houver protótipo experimentado.

**Correção:** separar explicitamente:
- **Trilha A — P0:** ciclo presencial completo, variedade mínima representativa, compatibilidade, testes e publicação fechada.
- **Trilha B — P1/P2:** receitas profundas, co-op avançada, máquinas especiais, restauração, comércio e tuning.
- **Gatilho de mudança:** aprovação do Product Owner, risco calculado e dados de teste.

---

## 3. O QUE DEVE SER PRESERVADO

Preservar, não reimplementar:
- Clientes NPC e carros físicos ligados a ordem, paciência, humor, saída e lotes.
- Reparo server-authoritative, antispam e validação de tipo/estado; testar eficácia real.
- Cinco especializações e catálogo central; aproveitar os defeitos já modelados.
- Oficina nível 0 (1 vaga) até nível 3 (6 vagas), sem exigir expansão P3.
- Loja física, estoque visual, mochila e peças, com modo de compra compatível.
- Perfil, reputação, preço configurável, avaliações, XP e fidelização.
- Contratos de frota, NPC rivais e eventos já escritos, sem adicionar variantes até validar.
- HUD com Ordens, Loja, Estoque, Perfil, Habilidades, Ranking e notificações.
- Pipeline procedural como fallback, com direção final semi-realista/realista.
- Compatibilidade de DataStore (schema atual a verificar), migrando somente com teste.
- Roteiro de onboarding: primeiro reparo guiado, depois 2–3 clientes e primeira expansão quando economia permitir.

**Regra específica de atendimento [ANT]:** a ordem mostra foto/preview do carro, identidade do cliente, sintoma relatado e tempo. **Não mostra defeito confirmado**. O NPC aguarda fisicamente, expressa ansiedade e pode sair de carro para procurar outra oficina. Avaliação aparece imediatamente ao entregar, inclusive no Perfil. Recusa de trabalho ainda disponível não reduz reputação; abandono depois de aceitar pode ter consequência proporcionada.

---

## 4. MAPA DE MECÂNICAS QUE SE CONVERSAM

~~~text
TIPO DE CLIENTE + HISTÓRICO + DEMANDA DO BAIRRO
   -> CHEGADA REAL DO NPC E VEÍCULO
   -> CONVERSA (QUEIXA, URGÊNCIA, EXPECTATIVA)
   -> TESTE/EXAME (EVIDÊNCIA, NÃO PALPITE)
   -> DIAGNÓSTICO E ORÇAMENTO
   -> OS COM RECEITA DE AÇÕES, PEÇAS, TEMPO E FERRAMENTAS
   -> ESTOQUE / LOJA / ELEVADOR / BANCADA / MECÂNICO
   -> EXECUÇÃO VISUAL + INTERAÇÃO FÍSICA CONTEXTUAL
   -> TESTE DE RESULTADO / QUALIDADE DO SERVIÇO
   -> ENTREGA / NOTA / DINHEIRO / XP / REPUTAÇÃO / FIDELIDADE
   -> MERCADO LOCAL E PRÓXIMA DEMANDA
   -> EXPANSÃO DA OFICINA E ESPECIALIDADE
~~~

**Contratos e cooperação** conectam-se à OS, não criam um segundo sistema de reparo. **Restauração** reutiliza peças, receitas, avaliação e teste. **Tuning** só surge com carro próprio e teste de desempenho significativo.

Uma feature nova só entra se:
1. Resolve uma frustração ou abre decisão interessante.
2. Conecta pelo menos **duas** partes do circuito.
3. É inteligível para jogador casual.
4. Pode ser implementada e testada com risco aceitável.
5. Não degrada performance mobile/controle touch.
6. Tem alternativa menor para P0.

---

## 5. LOOP DO JOGADOR — COMO DEVE SER JOGAR

### Primeiros 30 segundos (hipótese de experiência, não cronômetro validado)
- Ver a própria garagem pequena com **uma vaga**, fachada e bancada reconhecíveis.
- Primeiro cliente estaciona com veículo físico e se aproxima/aguarda.
- Cliente pede ajuda; fala em termos simples (“Está perdendo pressão”).
- Guia destaca onde olhar; diagnóstico com evidência simples.
- Jogador usa ferramenta no carro, faz um procedimento curto, vê alteração visual.
- Cliente confere e agradece, paga; aparece progresso para próximo atendimento.
- Nenhum painel grande cobre a ação principal; nenhum menu de comércio força saída imediata.

### Primeiro ciclo completo
**Chegada → Conversa → Exame → Diagnóstico → Preparação → Operação → Verificação → Entrega → Avaliação → Investimento.**

A versão P0 não precisa de desmontagem de cada peça, mas precisa de pelo menos **um instante visível de trabalho mecânico com significado**, não apenas uma barra no centro da tela.

### Primeiros 5 minutos
- Realizar 2–3 serviços curtos e diferentes, com uma consequência perceptível de erro/qualidade.
- Ver o primeiro desbloqueio, especialidade ou equipamento desejado.
- Encontrar cliente/atividade de outra oficina ou NPC rival sem transformar bairro em labirinto.
- Perceber que as mesmas peças/equipamentos aparecem em loja, estoque e execução.

### Sessão de 15–20 minutos
- Escolher atendimento por recompensa, especialidade, custo e fila.
- Fazer uma compra de peça útil; notar se qualidade da peça importa.
- Melhorar uma habilidade ou uma máquina; experimentar serviço novo.
- Decidir entre trabalho pessoal, contratar NPC ou ajudar jogador quando a funcionalidade existir.
- Encerrar sessão voluntariamente com progresso salvo. **Sem penalidade offline.**

### Longo prazo
**Especialização pessoal + reputação do negócio + variedade de clientes/contratos + mudança visual real da oficina.** Depois: carreira de funcionário, restauração, projetos de coleção, tuning com laudo e assistência externa.

---

## 6. DESIGN DE REPAROS: PROFUNDIDADE SELETIVA

### 6.1. Famílias de interação

Em vez de 15 minigames exclusivos ou 1 único universal, criar uma biblioteca de operações:

| Operação | Comportamento | Usa quais sistemas |
|---|---|---|
| Inspecionar | Mirar/selecionar alvo e receber evidência | NPC, diagnóstico, scanner |
| Medir | Ajustar/interpretar intervalo simples | Habilidade, ferramenta, defeito |
| Soltar/fixar | Sequência ou timing curto contextual | Peça, ferramenta, qualidade |
| Desmontar/instalar | Selecionar peça desbloqueada e encaixar | Slots, estado, compatibilidade |
| Preparar/tratar | Limpeza/polimento com limites por peça | Estação, condição, tempo, custo |
| Calibrar | Escolha de parâmetro e resultado | Máquina, teste, especialidade |
| Testar | Confirmar que problema foi corrigido | Qualidade, avaliação, garantia |

**Direção de UX:** a peça é o foco; o painel informa o que fazer. Evitar minigame grande que esconda carro. No início, usar 2–3 operações para uma OS; não exigir treinamento mecânico profissional.

### 6.2. Cinco especializações e serviços representativos

**Pneus e rodas — P0:** pneu furado. Exame de vazamento/pressão, elevar/soltar roda, remendar ou substituir, calibrar e testar. Diferenciação: pressão/posição do furo, não torque de motor.

**Elétrica — P0:** bateria falhando. Verificar tensão, reconhecer sintoma, substituir/recuperar conforme regra, testar partida. Diferenciação: medição e polaridade/ordem simplificada, sem riscos reais reproduzidos.

**Motor — P0:** superaquecimento simples. Ler temperatura ou inspecionar fluido, escolher hipótese, consertar mangueira/radiador em versão curta, testar. Motor inteiro removível é **P2**, não requisito P0.

**Suspensão e freios — P0:** pastilha gasta ou ruído. Inspecionar roda, usar elevador, acesso ao componente, fixação e checagem. Não implementar sistema físico de cambagem completo no MVP.

**Funilaria e pintura — P0:** amassado pequeno. Identificar área danificada, preparação, aplicar correção visual simples, verificar acabamento. Cabine PBR e pintura detalhada ficam para P1/P2.

**Atenção à prioridade:** três receitas piloto podem receber maior profundidade (pneu, bateria, arrefecimento). As outras duas especialidades precisam de pelo menos rota curta funcional e compreensível, conforme v2.

### 6.3. Modelo de diagnóstico aprimorado

Cada caso tem:
- **Defeito verdadeiro** secreto do servidor.
- **Sintomas possíveis** e perfil do NPC.
- **Exames disponíveis** pelo nível/ferramenta.
- **Evidências** que confirmam/refutam hipóteses.
- **Hipóteses plausíveis**, nunca três opções meramente aleatórias.
- **Plano de solução** com custo, peça, tempo e requisito.

Um exame importante tem resultado útil; não criar “inspecionar tudo” obrigatório. Jogador com maior habilidade pode receber hints melhores, mas não um atalho que elimina toda diversão. Não mostrar diagnóstico antes da conversa, nem penalizar por recusar uma OS não aceita.

### 6.4. Reparo de peça não é igual a limpeza

**Crítica ao Gemini:** recuperar qualquer peça de 0 a 100% apenas limpando e polindo é mecanicamente incoerente e destrói economia de substituição.

Modelo proposto (após P0):
- **Sujeira:** pode ser removida por limpeza.
- **Ferrugem superficial:** tratável em estações compatíveis.
- **Desgaste:** só pode melhorar por reparo/remanufatura permitida, com custo e limite.
- **Dano estrutural/condenação:** exige substituição.
- **Condição final:** resultado de trabalho, peça, material e verificação; não multiplicador gratuito.

Não simular química real; projetar decisões legíveis. Peça recuperada pode ser mais barata e ter garantia/risco diferente, mas não deve ser automaticamente melhor que peça nova.

### 6.5. Raio-X e câmera

**[GEM]** Modo raio-X com lataria transparente é referência. **[PROP]** aplicar transparência somente às partes visuais do veículo correto, com atributos/tags estáveis e exclusão de peças interativas/colisores. LocalTransparencyModifier é recurso de apresentação, não resolve sozinho hit-test, clipping, câmera, oclusão, mobile ou posicionamento.

**Estado proposto:** usuário equipa ferramenta de inspeção -> modo de acesso contextual -> câmera com limite de órbita e seleção por raycast -> lataria localmente translucida -> blocos/peças relevantes destacados -> ao sair, restaurar estado. Proteger desempenho e legibilidade. Não presumir que os modelos atuais possuem capô separado.

---

