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


## 7. COOPERAÇÃO SOCIAL: PRÓXIMO DIFERENCIAL, SEM PREJUDICAR SOLO

### 7.1. Produto mínimo vs produto avançado

**P0 oficial da v2:** 2 jogadores no mesmo servidor, oficinas/dados isolados, carros/OS corretamente associados; coexistência e segurança validadas. Convites avançados não são bloqueadores. **[PROP]** Se os testes de núcleo indicarem que um protótipo cooperativo simples aumenta diversão sem grande risco, o Product Owner poderá aprovar uma **exceção P0 limitada**; não tratar como automática.

**P1:** assistência por tarefa ou transferência especializada com minijogo real e pagamentos justos.

**P2:** duas pessoas operando em paralelo a mesma OS, bancada compartilhada e guincho de motor interno.

### 7.2. Como a cooperação deve funcionar

Exemplo de OS “revisão de arrefecimento”:
1. Proprietário conversa e diagnostica.
2. A prepara carro e remove proteção; B consulta estoque e reserva radiador.
3. A retira radiador; B prepara ferramenta/estação.
4. B instala componente ou opera máquina autorizada; A verifica encaixe.
5. A faz teste final, o sistema registra contribuições de ambos.
6. Cliente recebe o carro, a oficina recebe avaliação, dinheiro é repartido conforme combinado.

**Contribuição real** = tarefa validada do servidor, não apenas presença ou clique simultâneo.

### 7.3. Permissões e contratos

Dono mantém propriedade do lote, estoque, equipamento, precificação e OS. Convidado recebe autorização **temporária, limitada à OS e às tarefas selecionadas**. Servidor guarda conjunto de UserIds autorizados; não usar atributo textual AllowedCrew como única fonte de autoridade.

Consentimento antes da execução: papel, pagamento, condição de desistência e quem fornece peças. Permitir reatribuição de tarefa quando colaborador sair. **Não pagar duas vezes.** Não dar ao colaborador poder de mover itens da oficina para seu inventário pessoal sem transação expressamente permitida.

**Crítica ao Gemini:** reduzir WalkSpeed à metade para transportar motor e liberar +15% financeiro fixo na cooperação podem criar burocracia e inflação. Melhor usar equipamento (guincho) e paralelismo para ganho de tempo e capacidade; se houver bônus financeiro, que seja justificado por qualidade/contrato, limitado e submetido a simulação econômica.

### 7.4. Operação do guincho de motor (P2)

**Peça grande:** motor. **Papéis:** operador regula altura/alinhamento; mecânico libera suportes e fixações; opcionalmente assistente NPC prepara equipamento.

**Estados controlados pelo servidor:** Mounted -> ConnectionsReleased -> HoistAttached -> Suspended -> Bench -> Reinstalled -> Verified.

**Visual:** motor pesado pode usar tween/constraints com sockets, Attachments e geometria/GLB real quando existir. Não depender de network ownership para validar dinheiro, condição ou posição econômica de componente. Fallback solo: tarefas sequenciais com operação assistida.

### 7.5. Outros encontros sociais de alto valor

- Quadro na praça: “Oficina Alfa precisa de mecânico de elétrica” e vaga temporária.
- Visita a oficinas sem direito de alterá-las.
- Clientes observando movimentação, elevadores e funcionários em outras oficinas.
- Mural de avaliações e especialidades na fachada.
- Evento de frota com membros contribuindo em diferentes etapas.
- Categoria de ranking de qualidade separada de faturamento, para não esmagar jogador solo.

---

## 8. GESTÃO, MERCADO, CLIENTES E RETENÇÃO

### 8.1. Entender por que o cliente escolheu uma oficina

Hoje há fórmula agregada por preço, reputação, especialidade, distância, fila e nota. Para evolução, adicionar **arquétipos de NPC**, mantendo o mesmo motor econômico:

| Cliente | Dá mais peso a | Oportunidade |
|---|---|---|
| Econômico | Orçamento | Oficina barata, mas não necessariamente mais lucrativa |
| Urgente | Prazo e capacidade | Oficina eficiente, estoque pronto, atendimento rápido |
| Exigente | Nota, especialidade e garantia | Mecânico bem treinado, peça confiável |
| Fiel | Histórico e confiança | Retorno para quem prestou bom serviço |
| Frota | Regularidade, capacidade e custo total | Contrato, equipe e logística |

**Não mudar pesos sem simulação.** Medir receita, margem, taxa de recusa, serviço impossível e concentração de clientes por estratégia. Estatísticas do quadro devem ser honestas com a natureza probabilística das escolhas.

### 8.2. Economia que permita escolhas

Receita não é igual a lucro. O painel de cada serviço deve indicar:
- Pagamento previsto (antes da aceitação).
- Custo de peças/insumos.
- Custo da contratação, quando aplicável.
- Qualidade e prazo, após execução.
- Margem informativa, sem contabilidade pesada P0.

**P0 não requer aluguel, energia, impostos, dívidas ou perda passiva offline**, conforme v2. Custos novos só com evidência de inflação real.

**Escolha estratégica:** peça nova mais cara vs reparo adequado mais barato; serviço premium vs volume; atender agora vs negociar prazo. Sem decisões falsas: alternativa barata não deve ser sempre a melhor, nem qualidade premium garantir lucro sem limite.

### 8.3. Reputação e clientes memoráveis

O sistema já guarda fregueses. Evolução:
- Veículo retorna com identificação coerente e histórico limitado.
- Cliente lembra do último serviço, comenta melhora ou problema.
- Qualidade e preço afetam indicação/fidelidade.
- Em caso de falha coerente, oferecer revisão com regras claras e chance de recuperar confiança.
- Reputação por especialidade **P1/P2**, preservando reputação geral e ratings legados.

**Novo recurso de baixa complexidade e alto impacto:** bilhete de entrega com frase simples do cliente + diagnóstico feito + peça instalada + resultado do teste. Isso transforma resultado financeiro abstrato em história de atendimento.

### 8.4. NPC rivais são negócios do bairro, não “pontuação falsa”

Rivais devem:
- Receber cliente somente quando têm capacidade/baia.
- Reservar vaga, mostrar atendimento e registrar conclusão/falha real.
- Ter preço, reputação e habilidade comparáveis sob regras explícitas.
- Liberar lotes para jogadores e não comprometer capacidade real do servidor.
- Nunca ganhar rating ou moeda antes do sucesso de serviço.
- Ser sinalizados como oficinas NPC, não jogadores humanos fictícios.

**Nova melhoria:** o bairro pode comunicar “a oficina vizinha ganhou demanda de suspensão” como tendência agregada, sem fingir interações que não aconteceram.

### 8.5. Progressão: evitar empilhamento de recompensas

A base já traz: clientes fiéis, Rush, bônus de amigo, combo, missão diária, liga e conquistas. Isso pode ficar como suporte, não como núcleo da diversão.

**Recomendação de balanceamento:**
- Bônus por trabalho bem feito e qualidade acima de presença.
- Nenhuma penalização arbitrária por desconectar ou perder sequência diária.
- Reduzir efeitos cumulativos que façam serviço normal parecer inútil.
- Progressão desbloqueia **decisões e trabalhos**, não só multiplicadores.
- Dinheiro pode ser usado em capacidade, equipamento, peças e estética; não criar custos recorrentes antes de medir necessidade.

---

## 9. HUD / UI / UX COMO SISTEMA DE ESTADOS

Referência detalhada [GEM] descreve:
- A pé: notificações alto direito; dinheiro baixo esquerdo; hotbar inferior; checklist lateral.
- Dirigindo: painel automotivo baixo direito; minimapa GPS baixo esquerdo.
- Terminais: cartões de trabalho; catálogo com categorias/carrinho; ECU com curvas e sliders.

**Essas posições não foram verificadas diretamente por esta auditoria em frames do YouTube.** Servem como referência de design, não contrato de pixel.

### 9.1. Layout por contexto

| Contexto | Mostrar | Ocultar |
|---|---|---|
| Exploração/Oficina | saldo, cliente ativo, ferramentas, notificações discretas | painel de carro dirigível |
| Atendimento | retrato, queixa, paciência, opções de conversa | diagnóstico confirmado |
| Diagnóstico | exame, evidência, hipóteses, feedback | minigames não relacionados |
| Reparo | peça alvo, bloqueio, ferramenta, estado/qualidade | lojas sobrepostas |
| Máquina | controle da estação, slots, progresso | menu geral cobrindo máquina |
| Co-op | funções, tarefas paralelas, equipe, acordo | controles de outras OS |
| Gestão | fila, estoque, funcionários, preço e reputação | instrumentação de direção |
| Condução futura | velocidade, estado do veículo, rota | checklist mecânico extenso |

**Regra inegociável do proprietário:** loja, inventário e painéis não podem escurecer o gameplay nem impedir visão contínua da oficina. Painéis contextuais preferencialmente laterais, responsivos e fecháveis. Não criar botão decorativo sem operação.

### 9.2. Cuidado com o acionamento de direção

**Crítica ao Gemini:** Humanoid.Seated sozinho não prova que o jogador dirige. Pode estar sentado em qualquer Seat. Detectar VehicleSeat/ocupante/veículo autorizado e estado de direção, com transições de assento, morte, desconexão e respawn. Não render velocímetro fora dessa condição.

**Raio-X:** iniciar só com ferramenta/estado corretos; guardar restauração de visibilidade e impedir oclusão de partes interativas. Highlight de bloqueio deve durar pouco e ter feedback textual; vermelho sozinho não é acessível a todos.

**Minimapa/GPS:** só se houver dirigibilidade/rotas úteis. Beam não “projeta automaticamente” um trilho no asfalto; precisa de pontos/Attachments e tratamento de elevação/curvas. Para P0, sinalização de loja e marcador do objetivo são suficientes.

### 9.3. Glossário PT-BR para UI

- Ordem de Serviço (OS), Sintoma, Diagnóstico, Inspeção, Orçamento, Peça, Ferramenta, Equipamento, Bancada, Elevador automotivo, Guincho de motor, Balanceadora, Desmontadora, Scanner automotivo, Suspensão, Cambagem, Freios, Motor, Radiador, Polimento, Revisão, Garantia, Reputação.
- “Guincho de motor” ≠ “guincho/reboque”.
- “Ultrassom/limpeza ultrassônica” não equivale a reconstruir metal danificado.
- Usar termos profissionais compreensíveis, com tooltip opcional. Evitar literalismos traduzidos e mensagens genéricas.

---

## 10. O BAIRRO, OS ESTABELECIMENTOS E A ARTE

### 10.1. Conflito de escala no relatório Gemini

O relatório descreve ao mesmo tempo “cidade costeira modular compacta” e um mapa grande/vazio com poucos encontros. Isso pode significar baixa densidade de atividades ou exagero da dimensão, mas **não autoriza concluir tamanho real do mapa sem observar vídeos e medir**.

A conclusão útil é outra: **área só merece existir se gera ação, encontro ou motivo de retorno**.

### 10.2. Zoneamento por necessidade

**P0 — bairro atual:** seis lotes, via principal, oficinas, loja de autopeças, Construtora, praça/quadro e circulação de NPCs. Melhorar legibilidade, travessia, visibilidade de outras oficinas e caminhos curtos antes de criar orla.

**P1 — primeiro distrito útil:** serviço externo simples ou fornecedor de componentes usados, se dados de retenção demandarem. Não criar estacionamento infinito.

**P2 — oficinas especializadas:** loja de rodas, pintura, bancada de motores, preparação e ferro-velho quando houver sistemas correspondentes e capacidade de arte.

**P3 — orla, pista, concessionária premium e grande malha rodoviária:** só se restauração, condução e tuning criarem jogo real nessas áreas.

### 10.3. Como os POIs devem se conectar

| Local | Ação exclusiva | Relação com oficina |
|---|---|---|
| Loja de autopeças | comprar peça compatível e comparar qualidade | estoque, custo, OS |
| Construtora | expandir área, vagas, capacidade | lucro, reputação, equipe |
| Praça/TV de ofertas | ver oportunidades e mercado | competição, co-op |
| Ferro-velho futuro | inspecionar usado/sucata | restauração, estoque |
| Loja de rodas futura | comparar roda/configuração | especialização, teste |
| Cabine de pintura futura | acabamento visual verificado | funilaria, restauração |
| Dinamômetro futuro | medir resultado real/simulado | tuning, laudo |
| Pista futura | testar carro | preparação e direção |

**Crítica à proposta de NPC Street Racers:** corridas espontâneas como atividade principal desviam o jogo da profissão, multiplicam trabalho de direção/IA/segurança e podem quebrar foco. Se tuning existir, começar com pista técnica e provas controladas, não rachas generalizados.

### 10.4. Arte e assets

O Product Master v2 orienta preferir assistente 3D do Studio via MCP, com inspeção e integração reais. **O Claude GitHub-only não tem essa capacidade inicialmente**. Na fase de código, ele deve:
- Enumerar assets no GitHub e seus IDs documentados, sem fingir inspeção de modelos locais.
- Criar interfaces para sockets, pivôs, attachments e fallbacks.
- Fazer manifest de importação e validação Studio.
- Reservar criação visual de carros, oficina, máquinas e rua à fase com Studio/MCP ou importação manual.
- Checar licenças de cada item; texturas, sprites de referência e ícones sem autorização escrita continuam bloqueados para publicação.
- Evitar marcas de carros, logotipos reais, QR codes e texturas problemáticas.
- Priorizar silhueta/escala/coerência visual acima de polígonos em um objeto isolado.
- Medir performance em celular. Modelos do Workspace podem ser influenciados por StreamingEnabled; modelos mantidos em ReplicatedStorage não ganham streaming espacial equivalente.

**Risco especial:** muitos ViewportFrames, luzes e modelos em ReplicatedStorage podem consumir memória mesmo fora do campo de visão. Preferir miniaturas prontas quando comprovadamente mais eficientes.

---

## 11. CORREÇÕES E AJUSTES NAS RECOMENDAÇÕES DO GEMINI

| Proposta GEM | Veredito | Razão e adaptação |
|---|---|---|
| Modo raio-X por LocalTransparencyModifier | **Aprovar com condicionantes** | É apresentação local; complementar raycast, câmera, sockets e feedback; não resolveria tudo sozinho |
| Árvore de dependências e Highlight | **Aprovar** | Começar com poucas peças e feedback de bloqueio; servidor valida |
| Limpeza + polimento levam tudo a 100% | **Rejeitar no formato descrito** | Sujeira/ferrugem ≠ dano/desgaste; permitir recuperação limitada |
| Colaboração simultânea | **Aprovar como direção** | É diferenciação, mas não bloqueia P0 sem exceção; começar pequeno |
| Motor pesado reduz WalkSpeed 50% | **Rejeitar como regra geral** | Punição de deslocamento; usar guincho/auxílio e tarefas relevantes |
| Co-op paga +15% fixo | **Não aprovar automaticamente** | Inflação e exploração; qualidade/eficiência/contrato podem justificar benefício controlado |
| Carrinho 4–6 slots | **Aprovar depois de precisar** | Só quando carga de peças existir; não adicionar logística física P0 |
| Assistência externa e guincho | **Backlog P1/P2 conforme v2** | Exige condução, controles, mapa e NPC; não bloqueia lançamento |
| Scanner revela todas peças num clique | **Reprojetar** | Scanner fornece evidências, não resposta universal |
| Direção ativada por Humanoid.Seated | **Corrigir** | Checar carro dirigível/autorização, não assento genérico |
| GPS com Beam no asfalto | **Protótipo posterior** | Não há projeção automática; path e attachments exigem integração |
| NPCs desafiando para rachas | **Adiar/P3** | Desvia da fantasia mecânica e depende de direção útil |
| Cidade costeira com muitos POIs | **Adiar** | Cada prédio precisa de atividade real e fluxo de visitas |
| “Milhares online = servidor falso” | **Não comprovado** | Jogadores globais e por instância são métricas diferentes |
| Tuning ECU/cambagem | **Aprovar como expansão** | Só com laudo, trade-offs e teste que muda de fato |
| Cabine de pintura e concessionária | **Backlog P2** | Reusar restauração e avaliação; não expandir mundo sem loop |
| Contratos com quatro cards, catálogo com carrinho | **Adotar padrões funcionais** | Se melhorar leitura/compra, sem copiar identidade visual |

---

## 12. CRITÉRIO DE LANÇAMENTO P0 — O QUE É E O QUE NÃO É

### 12.1. P0 obrigatório (conforme v2 + correções de qualidade mínima)

- [ ] Jogador novo entra numa oficina nível 0 e completa atendimento sem explicação verbal.
- [ ] NPC e veículo chegam corretamente, aguardam, reagem, partem sem duplicação.
- [ ] Sintoma, conversa e diagnóstico separados; defeito não aparece prematuramente.
- [ ] Serviços representativos das cinco especialidades são atendíveis.
- [ ] Mínimo de diferenciação mecânica demonstrável, sem exigir árvore profunda de peças.
- [ ] Reparo responde a ferramenta/equipamento/peça/execução; qualidade validada no servidor.
- [ ] Loja, estoque e peças persistem, compatibilidade e consumo único corretos.
- [ ] Compra, avaliação, reputação, saldo, XP e desbloqueio claros.
- [ ] Recusa, abandono, expiração e saída de NPC liberam baia e estado corretamente.
- [ ] Oficina e dados isolados por jogador; dois jogadores simultâneos sem interferência.
- [ ] DataStore real testado em place publicado de homologação.
- [ ] Controle touch em celular real; PC também validado.
- [ ] Remotes, pagamentos, inventário e propriedade revisados contra abuso.
- [ ] Desempenho medido em cenário representativo.
- [ ] Assets/ícones/sons possuem origem e licença aplicável verificada.
- [ ] Bugs bloqueadores corrigidos; documentação e release candidate congelados.

O checklist é de aceitação **real**, não de arquivos existentes. Como esta revisão não operou o Studio, **nenhum item de runtime foi marcado validado**.

### 12.2. P0 “polimento de prazer”, limitado por escopo

Uma microfatia por serviço pode agregar alta diversão sem bloquear cronograma: diagnóstico com 1 exame, operação diferente e feedback do carro. **Proposta:** construir 3 pilotos, avaliar com 5–10 usuários, então decidir se expandem as cinco áreas antes do lançamento. A v2 exige cinco áreas representadas, não cinco simuladores separados.

### 12.3. O que já existe mas não deve expandir agora

Contratos de frota, ligas, bônus de amigo, Rush, ranking, staff NPC e visuais avançados já têm código. A prioridade é **validar/corrigir** seu impacto, não criar seis novas versões. Funcionalidades opcionais podem ser simplificadas ou escondidas por feature flag no beta sem apagar dados.

---

## 13. ROADMAP DE EXECUÇÃO — DUAS TRILHAS COM PORTÕES

### TRILHA A — FECHAR E TESTAR P0

**A0 — Auditoria/reprodutibilidade (CODE-ONLY):** confirmar branch/commit, remotes, dados, assets, testes, responsabilidades e divergências de documentação. Atualizar README e docs/PROGRESSO com apenas fatos.

**A1 — Reparar correções de integridade (CODE-ONLY):**
- RivalService só credita serviço após conclusão com baia/carro; testes de falha.
- Fallback da loja/construtora em produção deve negar operações se faltar prédio.
- Revisão de dupla conclusão, compras, abandono, expiração e reconexão.
- Garantir compatibilidade do SchemaVersion atual.

**A2 — Variedade mecânica mínima (CODE-ONLY + NEEDS_STUDIO):**
- 3 interações piloto: pneu, bateria, arrefecimento.
- Diagnóstico com exame útil e explicação.
- Preservar interface do minijogo antigo para demais serviços por feature flag.
- Fallback sem modelos externos.
- Checagem de acessibilidade e controles touch.

**A3 — Onboarding e HUD (CODE-ONLY + NEEDS_STUDIO):**
- Guia de primeiro cliente, avanço inicial, feedback de peça/qualidade.
- Corrigir sobreposições; manter loja e inventário sem overlay escuro.
- Melhorar feedback de não atender por falta de ferramenta/peça/nível.
- Reduzir ruído de notificações.

**A4 — Qualidade e estabilidade técnica (CODE-ONLY + NEEDS_STUDIO):**
- Testes de dados, remotes, clientes, mercado, OS, moedas, estoque, incompatibilidade.
- Medição de custos de snapshots, ViewportFrames e FX.
- Preparar homologação.

**A5 — HOMOLOGAÇÃO OBRIGATÓRIA (NÃO DISPONÍVEL VIA GITHUB-ONLY):**
- Abrir Roblox Studio, integrar place e assets, executar testes 2 players.
- Testar DataStore em experiência publicada de homologação.
- Testar celular real, PC e desempenho, corrigir bugs e revisar licenças.

**A6 — BETA FECHADO:** recomendação v2: ~15–20 participantes. Observar primeiro serviço, repetição, erro, economia, UI, multiplayer e decisão espontânea de fazer outro atendimento.

**A7 — PUBLICAÇÃO:** apenas se critérios P0 forem demonstrados; congelar escopo e gerar notas de versão.

### TRILHA B — EXPANSÕES APÓS VALIDAÇÃO OU EXCEÇÃO DO PRODUCT OWNER

**B1 — Cooperação mínima útil e despacho por especialidade:** convidar profissional, dividir tarefas legítimas de OS e remuneração idempotente.

**B2 — Carro piloto modular e máquinas realmente operáveis:** peças, estado, scanner, elevador, roda, bancada, integração de câmeras e sockets.

**B3 — Guincho de motor interno e coop simultânea:** roles, locks, helper solo, economia e testes 2–4 players.

**B4 — Mercado por perfil, garantia, histórico de veículo e oportunidades públicas:** evolução de CustomerRules, RivalService e ContractService.

**B5 — Recondicionamento, carrinho e logística:** apenas se repetição de transporte e falta de decisão forem observadas.

**B6 — Assistência externa presencial com NPC e despacho:** primeiro pontos próximos, depois veículo dirigível/caminhonete/reboque.

**B7 — Restauração, ferro-velho, venda e showroom:** reutilizar engine de peças/qualidade; não garantir lucro fixo.

**B8 — ECU, dinamômetro, cambagem e pista de teste:** somente com desempenho verificável do carro e controle adequado.

**B9 — Novas regiões/veículos pesados:** P3, caso a base sustente e haja dados positivos.

**Crítica de execução:** o prompt anterior de 14 fases é bom como **backlog técnico**, mas inadequado como um único cronograma de pré-lançamento. Ajustar o agente para priorizar A0–A7 e só antecipar Bx com exceção explícita.

---

## 14. INTEGRAÇÃO EM ARQUIVOS E ARQUITETURA

### 14.1. Reaproveitar primeiro

| Sistema | Arquivo principal | Ação planejada |
|---|---|---|
| OS, clientes, pagamentos e colaboração | src/server/WorkshopService.lua | Isolar estados e conectar novas regras sem reescrever |
| Reparo e qualidade | src/shared/RepairRules.lua; UI/RepairGame.lua | Manter legado e criar receitas data-driven adicionais |
| Diagnóstico | src/shared/DiagnosisRules.lua; UI/DiagnosisGame.lua | Introduzir exames/evidências antes das hipóteses |
| Carros e efeitos | src/server/VehicleService.lua; src/client/VehicleFx.client.lua | Adicionar slots/adapter e feedback contextual |
| Equipamentos | src/server/EquipmentService.lua; StationService.lua | Atividade própria e fail-safe |
| Clientes e concorrência | src/shared/CustomerRules.lua; src/server/RivalService.lua | Corrigir integridade e simular mercados |
| Contratos | src/server/ContractService.lua | Validar legado, depois coop multi-oficina |
| DataStore | src/server/DataService.lua | Migração compatível; nenhuma reescrita arriscada |
| UI e snapshots | src/client/UI/HUD.lua; UI/Store.lua | Estado contextual sem obscurecer jogo |
| Catálogos | src/shared/Catalog.lua; Config.lua | Uma fonte de verdade para os serviços |

### 14.2. Novos contratos, somente quando necessários

**Diagnóstico:** ExamId, TargetComponentId, EvidenceId, DefectHypothesisId, JobId e resultado server-side.

**Receita:** RecipeId, StepId, Kind, DependsOn, RequiredTool, RequiredStation, TargetPartId, Status, Revision, ActorUserId.

**Peça:** VehicleInstanceId, PartInstanceId, SlotId, Condition, Contamination, Wear, StructuralDamage, Compatibility, Ownership.

**Coop:** JobId, OwnerUserId, Participants, Permissions, TaskClaims, PaymentAgreement, Revision.

**Estação:** StationId, BusyByJobId, OperatorId, ItemSlots, State, EndsAt, Revision.

Não persistir Instances brutas; guardar IDs e dados compactos, com limites e migração. Evitar combinar cliente e servidor na mesma fonte de autoridade. Fazer idempotência com tokens/estado e validar distância/posse/ação no servidor.

### 14.3. Testes de regra sem Studio

O agente GitHub-only pode escrever testes Luau de:
- DAG de receita e dependências.
- Qualidade e evidências.
- Escolhas de clientes e distribuição de mercado.
- Reservas/consumo de peças.
- Idempotência de compra, pagamento e OS.
- Tentativa de alteração por visitante.
- Desconexão e estado expirado.
- Rivais sem baia/spawn.
- Dados antigos com schema novo.
- Reclamação não revelar defeito.

**Não pode afirmar que executou**, salvo ferramenta explícita disponível. Testes Roblox remotos/multiplayer/mobile e percepção visual continuam NEEDS_STUDIO.

---

## 15. MÉTRICAS, EXPERIMENTOS E CRITÉRIOS DE DIVERTIMENTO

### 15.1. Instrumentação

Rastrear:
1. Entrou no jogo.
2. Identificou o primeiro cliente.
3. Falou com NPC.
4. Realizou primeiro exame.
5. Concluiu diagnóstico.
6. Iniciou reparo.
7. Concluiu e recebeu avaliação.
8. Iniciou segundo atendimento.
9. Comprou primeira melhoria.
10. Voltou em outro dia (com amostra suficiente).

Complementares: duração por tipo de OS, abandono/cancelamento, razão de ferramenta insuficiente, nota, margem, tipo de dispositivo, quedas/erros, interferência com outro jogador, co-op real, qualidade do teste final.

Eventos de funil do Roblox permitem medir onde jogadores abandonam as etapas. Os valores de referência devem ser definidos após beta, não inventados.

### 15.2. Cinco perguntas de teste com pessoas

- “Você entendeu por que aquele carro estava com problema?”
- “Qual foi a ação mais divertida do reparo?”
- “O que você faria diferente na próxima OS?”
- “Você gostaria de trabalhar ou visitar a oficina de outra pessoa? Por quê?”
- “Você faria outro serviço sem prêmio diário extra?”

Uma pessoa aceitar um teste não comprova retenção. Observar ações espontâneas, abandonos, fluxo de toque e reclamações.

### 15.3. Não usar pontuação fictícia como evidência

As durações sugeridas para onboarding/serviços, o ganho de velocidade em coop e a distribuição de demanda são hipóteses. **Não publicar “retenção aumentou”, “FPS 60” ou “usuários gostam” sem medições.**

---

## 16. REGISTRO DE RISCOS E CORREÇÕES PRIORITÁRIAS

| Risco | Gravidade | Ação |
|---|---|---|
| Reparo uniforme fica repetitivo | Alta, produto | 3 receitas piloto + teste com pessoas |
| Diagnóstico por adivinhação | Alta, produto | Exame informativo e evidência |
| Rivais ganham estatística sem serviço | Alta, integridade | Corrigir ordem de crédito |
| Local físico ausente libera compra | Média/Alta, condicional | Falhar seguro fora de Studio |
| Falha de DataStore real | Crítica, lançamento | Homologação publicada |
| 2 players afetam mesma OS/dados | Crítica, lançamento | Testar coexistência, ownership e rejoin |
| Arte sem licença documentada | Alta, publicação | Confirmar origem e substituir |
| Mobile não testado | Crítica, lançamento | Teste em aparelho real |
| Equipamentos são só gating | Alta, produto | Interações de máquina em protótipo |
| Co-op sem trabalho compartilhado | Média/Alta, diferencial | P1 e feature flag |
| Empilhamento de bônus / inflação | Média | Simular e medir |
| Crescimento ilimitado do mapa | Alta, prazo | POIs só com loops |
| Game design maior que capacidade de execução | Alta, gestão | Freeze P0 e branches por PR |
| Teste escrito ≠ teste executado | Alta, governança | Status explícito |

---

## 17. COMO CLAUDE / FABLE 5.2 DEVE USAR ESTE DOCUMENTO

**Sem Computer Use**:
1. Ler a v2.0 oficial (precisa ser fornecida ou anexada no ambiente do agente; ela está na biblioteca do proprietário, não necessariamente no GitHub).
2. Ler este documento e o código atual; respeitar governança v2.
3. Classificar cada gap por P0/P1/P2/P3 e CODE_COMPLETE/NEEDS_STUDIO/NEEDS_ASSET.
4. Abrir branch/PR pequena, com um defeito ou vertical slice por vez.
5. Começar por integridade e experiência mecânica mínima (A1/A2).
6. Preservar DataStore, remotes, serviços e catálogos. Nada de criação paralela.
7. Adicionar testes e relatórios de execução honesta. Nunca dizer que testou Studio/Blender sem realmente operar.
8. Atualizar docs/PROGRESSO.md e histórico de implementações somente com evidências verificáveis.
9. Não pedir ao proprietário para escolher cada detalhe trivial.
10. Não transformar as expansões B1–B9 em requisitos obrigatórios sem exceção aprovada.

**Formato de entrega por PR:**

~~~text
Problema de jogador:
Prioridade P0/P1/P2/P3:
Arquivos modificados:
Mudança real no gameplay:
Integração com sistemas existentes:
Testes escritos e executados separadamente:
Riscos de segurança, performance e persistência:
Compatibilidade e rollback:
O que depende de Studio/arte:
Link do PR e commit real:
Próxima fatia:
~~~

**Sinal de mau desenvolvimento:** mais 10 módulos criados, nenhum cliente/veículo/OS alterado de ponta a ponta.

**Sinal de bom desenvolvimento:** um defeito foi diagnosticado com evidência, tratado com operação distinta, pago com integridade, visto no carro e refletido na satisfação do NPC, sem quebrar legados.

---

## 18. DECISÕES QUE PRECISAM SER APROVADAS PELO PRODUCT OWNER

A versão anterior continua autoridade; as seguintes decisões são **propostas**:

1. **Aprovar a v3 como nova referência de visão, preservando P0 da v2?** Recomendação: sim, desde que cada expansão continue fora do gate de lançamento.
2. **Antecipar um piloto de três receitas (pneu, bateria, radiador) para P0?** Recomendação: sim como polimento mínimo; interromper expansão se colocar estabilidade em risco.
3. **Co-op simultânea avançada é bloqueadora de lançamento?** Recomendação: **não**; fazer P1/P2, podendo demonstrar prova pequena separada antes.
4. **Manter primeira publicação no bairro presencial?** Recomendação: sim; assistência externa pós-lançamento.
5. **Corrigir rivais e permissões de lojas antes da beta?** Recomendação: sim, integridade supera expansão.
6. **Manter direção realista mas performance mobile?** Recomendação: sim, modelos 3D industriais coerentes com otimização e licença verificada.
7. **Monetização de progressão/competição?** Recomendação: não; cosméticos e valor opcional transparente, sem pay-to-win.
8. **Documentos operacionais anteriores de 14 fases devem ser reorganizados por prioridade?** Recomendação: sim; o backlog não é compromisso de implementação pré-lançamento.

O Product Owner pode aprovar exceções específicas depois de avaliar trade-offs; nenhum agente deve assumir que “mais ideias” equivale a “lance só depois de tudo”.

---

## 19. FONTES E TRAÇABILIDADE

**Fonte oficial [V2]:** Oficina24H_Product_Master_Document_v2.0.docx (06/11/2026), 13 páginas, 24 seções, encontrado na biblioteca do proprietário. Continua autoridade até decisão explícita.

**Código [COD]:**
- https://github.com/FiaresAlan/Oficina24H/blob/main/README.md
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/shared/RepairRules.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/shared/DiagnosisRules.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/shared/CustomerRules.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/server/WorkshopService.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/server/RivalService.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/server/ContractService.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/server/VehicleService.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/src/server/DataService.lua
- https://github.com/FiaresAlan/Oficina24H/blob/main/docs/ORIGEM_ASSETS.md

**Relatório [GEM]:** análise do Mechanic Legends compartilhada pelo proprietário nesta conversa; suas afirmações sobre cenas e HUD não foram confirmadas quadro a quadro por esta revisão.

**Diretrizes técnicas Roblox:** Creator Hub, best practices DataStore (UpdateAsync, retries, jitter, chave por jogador), Instance Streaming (Workspace vs ReplicatedStorage, modos Atomic/Persistent) e Analytics Funnel Events. Essas fontes apoiam as diretrizes de arquitetura e métricas; não comprovam estado de execução do jogo.

**Nota final:** documento mestre não substitui playtest. O Oficina 24H só terá vantagem real sobre a referência se o jogador vivenciar **diagnóstico com sentido, reparo com consequência, clientes memoráveis e interação social legítima**. Complexidade em código, por si só, não é diversão.

**FIM — V3.0 PROPOSTA PARA REVISÃO DO PRODUCT OWNER.**
