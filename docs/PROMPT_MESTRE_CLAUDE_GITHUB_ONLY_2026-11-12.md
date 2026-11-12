# OFICINA 24H — PROMPT MESTRE PARA CLAUDE / FABLE 5.2
**Repositório:** https://github.com/FiaresAlan/Oficina24H  
**Modalidade:** desenvolvimento EXCLUSIVAMENTE via GitHub, sem controle do computador.  
**Versão:** 12/11/2026  
**Objetivo:** evolução incremental do jogo existente para um simulador social de mecânica, gestão de empresa, competição econômica e cooperação real.

> LEIA ESTE DOCUMENTO INTEIRO ANTES DE ALTERAR QUALQUER CÓDIGO. Você será o arquiteto técnico e programador principal do Oficina 24H. Sua responsabilidade é preservar a base já desenvolvida e transformá-la em uma experiência jogável, profunda, diferenciada e coerente. Não é um pedido para reescrever o jogo, criar um novo template ou produzir somente documentos.

---

## 0. RESTRIÇÃO INEGOCIÁVEL: GITHUB-ONLY

Você **NÃO TEM Computer Use** no cenário inicial. Não tem acesso a Roblox Studio, Blender, Windows do proprietário, pastas locais, terminal/CLI local, execução de Rojo, arquivos GLB externos, screenshots do place ou modelos que existam apenas dentro do ServerStorage. Sua ferramenta efetiva é o GitHub, dentro das permissões disponíveis.

Regras:

1. Trabalhe com código Luau, testes versionados, documentos, schemas, contratos de integração, mocks e geradores que possam ser executados posteriormente.
2. **Não afirme** que abriu o Studio, rodou testes, verificou uma animação, confirmou FPS, usou Blender, importou GLB ou inspecionou a cena, se não fez isso com ferramenta real.
3. Distinga sempre: CODE_COMPLETE (código entregue), STATIC_REVIEWED (inspecionado), NEEDS_STUDIO (precisa testar no jogo), NEEDS_ASSET (precisa de modelo/arte), BLOCKED, VALIDATED_IN_STUDIO (somente se houver evidência de execução real).
4. Não invente IDs de asset, links, licenças ou nomes de partes não inspecionadas.
5. Não dependa de confirmação humana para decisões pequenas. Faça escolhas conservadoras e documente. Se uma limitação bloquear uma integração visual, faça o código e fallback e continue no que for independente.
6. Não modifique main diretamente sem aprovação. Prefira branches e PRs pequenos; não alegue commit/PR que a ferramenta não confirmou.
7. Não construa 15 fases num único commit. Faça fatias verticais completas (regras + servidor + cliente + testes + integração + docs).
8. Se a sessão acabar, o próximo agente deve conseguir continuar por ROADMAP, IMPLEMENTATION_LOG e PRs.
9. Evite reescrever módulos que já funcionam; novas funcionalidades precisam conversar com a economia, os clientes, os carros, o estoque, a progressão e as ferramentas existentes.
10. Testes não executáveis neste ambiente continuam **pendentes**, mesmo que o código de testes tenha sido escrito.

---

## 1. PROPÓSITO DO JOGO

**Promessa:** o jogador começa com uma garagem de uma vaga, atende clientes NPC que descrevem problemas, investiga sintomas, usa peças e ferramentas, faz reparos físicos, recebe nota e pagamento, desenvolve especialidades, expande sua oficina, disputa mercado e consegue executar serviços maiores com outras pessoas.

O jogador deve sentir que:
- Aprendeu mecânica e reconhece problemas novos.
- Melhorou a oficina em funcionalidades, não somente em aparência.
- As decisões de preço, peças, atendimento e investimentos importam.
- Outros jogadores podem ser colegas de trabalho, especialistas contratados e concorrentes legítimos.
- O bairro está vivo: carros chegam, clientes reagem, serviços acontecem e oportunidades surgem.
- Existe motivação genuína para retornar e experimentar serviços diferentes.

**Princípios:**
- Realista visualmente, mas acessível e divertido. Nunca confundir dificuldade com repetição mecânica excessiva.
- Solo sempre viável. Co-op oferece especialização, paralelismo e coordenação, sem bloquear jogo solo.
- Economia competitiva sem sabotagem, roubo de materiais/entregas, destruição ou griefing.
- HUD contextual sem overlay escuro cobrindo gameplay e sem esconder carro/peças.
- Onboarding curto com primeiro reparo e avanço inicial tangível.
- Serviços mecânicos diferentes exigem operações diferentes, não apenas 15 rótulos sobre um mesmo minijogo.
- Nomes genéricos de veículos, sem logotipos/marcas reais nos modelos; observar licenças de arte.

### O que aproveitar da referência Mechanic Legends

Inspirar-se em: visualização/encaixe de peças; modo raio-X; elevador; guincho; limpador ultrassônico; polidor; compra e entrega de peças; checklists; condição de componentes; pintura; ferro-velho; restauração; avaliação de revenda; loja física de peças e motores; suspensão/cambagem; ECU e dinamômetro. **Não copiar identidade, layout integral ou assets protegidos.**

Lições críticas das gravações: começo cheio de descobertas; risco de repetição de transportar/limpar/polir peça a peça; isolamento em garagens; mundo aberto pouco útil quando não há encontro/atividade; tuning que precisa servir a um objetivo concreto; interface que não deve obstruir o carro. Não tratar hipóteses sobre retenção/contagem de jogadores como fatos estatísticos.

---

## 2. AUDITORIA INICIAL OBRIGATÓRIA

Antes de codificar, leia o **estado ATUAL da branch base**, sem confiar cegamente em documentos históricos. Em 12/11/2026 o repositório continha, entre outros:

- README.md e default.project.json.
- docs/01_VISAO_DO_JOGO.md; docs/02_ARQUITETURA_TECNICA.md; docs/PLANO_DESENVOLVIMENTO.md; docs/PROGRESSO.md; docs/AUDITORIA_GERAL.md; docs/AUDITORIA_P0.md; docs/ORIGEM_ASSETS.md.
- src/server/Main.server.lua, WorkshopService.lua, DataService.lua, VehicleService.lua, CustomerArrivalService.lua, CustomerNpcService.lua, EquipmentService.lua, EquipmentModels.lua, StationService.lua, PlotService.lua, RivalService.lua, ContractService.lua, ProgressService.lua.
- src/shared/Catalog.lua, Config.lua, RepairRules.lua, DiagnosisRules.lua, JobRules.lua, CustomerRules.lua, WorkshopLevels.lua, PartModels.lua, ContractRules.lua, ProgressRules.lua, Locale.lua.
- src/client/UI/HUD.lua, UI/RepairGame.lua, UI/DiagnosisGame.lua, UI/Store.lua, UI/Panels/Orders.lua, UI/Panels/Shop.lua, UI/Panels/Stock.lua, VehicleFx.client.lua.
- tools/RunAllTests.luau e demais testes/geradores; pipeline de GLBs/IDs.

### O que provavelmente já funciona (CONFIRMAR NO CÓDIGO)

Clientes chegam/saem e aguardam; conversa, sintomas, diagnóstico por 3 opções, minijogo de precisão, notas, reputação, XP, estoque e loja; 5 especializações e vários serviços; 11 equipamentos; oficinas de 1/2/4/6 boxes; funcionários NPC; rivais NPC; mercado por preço, reputação, habilidade, avaliação, distância e fila; clientes fiéis; contratos de frota, Hora do Rush, ligas, missões, convites para colaborador, persistência e HUD.

### Lacunas verificadas no briefing

1. **Reparo:** diversas áreas usam o mesmo minijogo de timing. Falta variedade física por especialidade.
2. **Diagnóstico:** majoritariamente 3 hipóteses, sem uma cadeia de evidências.
3. **Máquinas:** muitas são requisitos físicos para iniciar minijogo, não operações com estado próprio.
4. **Cooperação:** CompleteCollaborativeJob atribui a conclusão a um convidado e usa qualidade padrão 85%; não há duas pessoas fazendo ações simultâneas na mesma OS.
5. **Carro modular:** capô/rodas e faíscas têm efeitos locais, mas ainda falta ciclo de peças com estado autoritativo e dependências.
6. **Assets:** modelos 3D importados para ServerStorage do place NÃO estão todos no GitHub; documentação e IDs não substituem verificação visual.
7. **Testes reais:** multiplayer, mobile, performance e importação ainda exigem Roblox Studio. Nunca declarar pronto para lançamento só pelo GitHub.

### Entregáveis imediatos de Fase 0

Criar ou atualizar:
- docs/ROADMAP_MASTER_2026.md — fases, dependências, status e critérios de aceite.
- docs/IMPLEMENTATION_LOG.md — decisões, PR, mudanças, riscos, próximos passos.
- docs/QA_MANUAL.md — roteiro de validação real em Studio/PC/celular/multiplayer.
- docs/ASSET_INTEGRATION_MANIFEST.md — modelos, sockets, IDs, licenças e bloqueios.
- docs/adr/ (somente decisões que precisam ficar registradas).

Produzir matriz com “código existente -> lacuna -> menor intervenção -> risco -> teste”. Registrar SHA da base. **Concluir auditoria e começar o código da Fase 1**, sem usar auditoria como desculpa para somente escrever documentação.

---

## 3. A REGRA MAIS IMPORTANTE: AS MECÂNICAS PRECISAM CONVERSAR

Cada feature nova precisa ligar pelo menos **dois sistemas existentes** e gerar uma ação visível + uma consequência verificável.

~~~text
PERFIL DO CLIENTE / EVENTO / FROTA
  -> NPC COM SINTOMA E CARRO FÍSICO
  -> ORDEM DE SERVIÇO + PRAZO + ORÇAMENTO
  -> EXAMES / EVIDÊNCIAS / DIAGNÓSTICO
  -> PLANO DE REPARO COM TAREFAS E PEÇAS
  -> ESTOQUE + EQUIPAMENTO + HABILIDADE + EQUIPE
  -> DESMONTAR / TRATAR / SUBSTITUIR / INSTALAR / TESTAR
  -> QUALIDADE E TEMPO MEDIDOS NO SERVIDOR
  -> PAGAMENTO + REPUTAÇÃO + XP + HISTÓRICO + FIDELIDADE
  -> ATRAÇÃO DE NOVOS CLIENTES E DISPUTA DE MERCADO
  -> COMPRA DE EQUIPAMENTO + EXPANSÃO + ESPECIALIZAÇÃO
  -> CONTRATOS MAIORES + RESTAURAÇÃO + EVENTOS
~~~

Quatro loops conectados:

1. **Atendimento:** cliente -> investigação -> reparo -> teste -> nota -> novo cliente.
2. **Empresarial:** margem -> investimento -> nova capacidade -> novos serviços -> custos -> gestão.
3. **Social:** especialização -> chamada de colega -> tarefas em paralelo -> pagamento compartilhado -> reputação.
4. **Automotivo avançado (posterior):** sucata -> restauração -> teste -> avaliação -> revenda/coleção/tuning.

A restauração não deve tornar atendimento inútil. O trabalho solo não pode ser inferior em todas as categorias. Mais carros e maior mapa são consequências de haver loops interessantes, não substitutos deles.

---

## 4. REGRAS DE ARQUITETURA

**Shared:** regras puras, catálogos, receitas, schemas, cálculos, regras de dependência, qualidade e mercado.

**Server:** autoridade exclusiva de OS, peças, máquinas, estoque, dinheiro, XP, propriedade, reembolso, autorização, permissões, posições e DataStore.

**Client:** UI, câmera, input, highlights, áudio, partículas, animações e respostas visuais — sem cálculos econômicos autoritativos.

**Tools:** testes Luau puros, QA, scripts de construção que possam ser executados depois.

### Compatibilidade

- Preservar Main.server.lua, WorkshopService, DataService, remotes e contratos públicos, salvo refatoração justificada e protegida por testes.
- Adicionar recursos novos com **feature flag por receita**. Serviços legados continuam no minijogo atual até migrarem.
- O estado atual Available/InProgress/Completed não pode ser substituído cegamente. Se necessário, manter WorkflowStage interno detalhado, adaptando UI e persistência.
- Não criar DataStore paralelo nem quebrar o schema antigo. Novos campos opcionais com defaults, validação e migração. Não sobrescrever schema futuro desconhecido.
- Transações de pagamento/peças/XP precisam ser **idempotentes**; não premiar duas vezes, não aceitar replay de remote.
- Evitar espera dentro de seções críticas de consumo/concessão; reservar recursos e usar commit/rollback de maneira segura.
- Não assumir a existência de modelo de arte; acesso a ServerStorage/Assets deve ser seguro e ter fallback.
- Usar nomes/IDs estáveis e tipos Luau claros; evitar novos megamódulos de milhares de linhas.

### Modelo sugerido de OS

Manter compatibilidade de status público; etapas internas podem mapear:

~~~text
Available -> Reserved -> Accepted -> Diagnosing -> Planned
 -> InRepair -> QualityCheck -> ReadyForDelivery -> Completed
 -> Cancelled / Expired / Abandoned / Recoverable
~~~

Tarefas:

~~~text
Locked -> Available -> Claimed -> InProgress -> Completed
                               -> Failed -> RetryAvailable
~~~

Cada claim deve ter actor, revisão, expiração e validação. Etapas independentes podem ocorrer em paralelo. Etapas incompatíveis sobre a mesma peça precisam de lock.

### Modelo de receita (ADAPTAR; não duplicar estrutura similar)

~~~lua
--!strict
type RecipeStep = {
    Id: string,
    Kind: string, -- Inspect/Remove/Carry/Clean/Replace/Install/Test
    TargetPartId: string?,
    RequiredToolId: string?,
    RequiredStationId: string?,
    DependsOn: {string},
    Role: string?,
}
type RepairRecipe = {
    Id: string,
    Version: number,
    DefectId: string,
    Steps: {RecipeStep},
    SoloSupported: boolean,
}
type StepProgress = {
    Status: string,
    ActorUserId: number?,
    Revision: number,
    StartedAt: number?,
    FinishedAt: number?,
}
~~~

IDs recomendados: JobId, VehicleInstanceId, PartInstanceId, RecipeId, StepId, StationId, WorkshopOwnerUserId, ActorUserId, Revision. Não usar apenas nome de Instance para estado econômico.

### Antiexploit e concorrência

Validar servidor: whitelist de actions, tipo/tamanho/range, NaN/inf, distância, propriedade, especialização, máquina, estoque, status, permissão e rate limit. Prevenir: concluir duas vezes, comprar duas vezes, duas pessoas consumindo mesma peça, convidado acessando OS alheia, máquina presa após desconexão, recompensa sem execução.

Para testar sem Studio, extrair regras puras e criar fakes de relógio, jogador, OS e inventário. **Escrever testes não equivale a executá-los.**

---


## 5. DESIGN PROFUNDO: CADA SERVIÇO DEVE SER DIFERENTE

### 5.1. Diagnóstico por evidências

O atual diagnóstico por três opções deve evoluir para **sintoma -> exame -> evidência -> hipótese -> decisão**, com fallback para o sistema antigo nos serviços ainda não migrados.

- Motor: temperatura, vazamento, inspeção de mangueira, radiador, scanner.
- Elétrica: voltagem da bateria, fusível, alternador, partida.
- Pneus: pressão, desgaste irregular, furo, balanceamento.
- Suspensão/freios: folga, amortecedor, pastilha, disco, alinhamento.
- Funilaria: localização, profundidade do dano, preparação, acabamento.

**Nova melhoria:** sintomas iniciais podem induzir a hipótese errada, mas toda evidência precisa permanecer coerente com a causa real. Não criar adivinhação arbitrária.

**Nova melhoria:** três níveis de ajuda. Iniciante recebe dicas visuais; intermediário recebe testes sugeridos; avançado pode reduzir dicas, mas recursos de acessibilidade devem permanecer disponíveis.

**Integrações:** NPC/diálogo, catálogo de defeitos, especializações, scanner e máquinas, qualidade, satisfação, UI e estatísticas.

**Teste de valor:** o jogador identifica uma causa com base em evidência, não por tentativa de opções bloqueadas.

### 5.2. Reparos por receitas (Recipe System)

Reparo é um conjunto de pequenas operações contextualizadas, não um menu único. Criar ações reutilizáveis, mas com sequências diferentes.

**Pneu furado, alvo 60–90 s:** localizar furo -> levantar -> soltar roda -> remendo/troca -> calibrar -> verificar.

**Bateria com falha, alvo 60–100 s:** testar -> confirmar falha -> desconectar -> substituir/recarregar -> medir -> testar partida.

**Arrefecimento, alvo 3–5 min:** analisar temperatura -> abrir capô -> inspecionar -> remover proteção/radiador -> buscar novo -> encaixar -> completar líquido -> testar funcionamento.

**Suspensão, alvo 3–5 min:** inspecionar -> elevar -> retirar roda -> acesso à suspensão -> substituir -> torque -> teste.

**Funilaria:** identificar -> preparar -> tratar amassado/superfície -> pintura/polimento -> inspeção.

São **metas de prototipagem**, não tempos medidos ou rígidos.

A qualidade final deve combinar:
- Evidência e diagnóstico.
- Ferramenta correta.
- Condição/confiabilidade da peça.
- Execução das ações da receita.
- Verificação final.
- Habilidade e equipamento.
- Prazo e atendimento devem afetar **nota**, não magicamente integridade da peça.

Não simplesmente somar mais minijogos repetidos. O minijogo de tempo já existente pode servir para **torque/fixação** onde fizer sentido. Outros procedimentos devem diferenciar controle e decisão: escolha de teste, alinhamento de componente, calibragem, sequência, interpretação de resultado.

### 5.3. Componentes realmente interativos

Criar um **carro piloto modular** antes de tentar adaptar dezenas. Atributos/sockets previstos: capô, roda, bateria, radiador, correia, coletor, motor, pontos de elevação e fixação. A lista exata depende dos modelos disponíveis: usar adapter e fallback se a peça física não existir.

Estados propostos da peça: Mounted, Accessible, Loosened, Removed, InCart, AtStation, Cleaned, Refurbished, Replaced, Installed, Verified, Damaged.

Dependências: para remover radiador, talvez seja necessário tirar uma proteção; para acessar componente profundo, abrir capô e liberar outros. Grafo declarativo pequeno, sem simular todos os parafusos de carros reais.

**Dica contextual obrigatória:** ao tentar operação bloqueada, iluminar a peça bloqueadora e informar a precondição; nunca apenas “ação inválida”.

**Integrar:** recipe, VehicleService, Catalog, estoque, RepairGame, VehicleFx e novas ações de UI. Um objeto visual solto não representa por si só uma peça reservada economicamente.

### 5.4. Máquinas grandes como gameplay

**Prioridade de identidade:** guincho de motor (engine hoist) cooperativo, com operador de posição/altura e mecânico de fixações; uma terceira função de preparo de motor/peças pode chegar posteriormente.

- Sozinho: guincho assistido, etapas sequenciais, operação viável.
- Dupla: um opera, outro executa fixações; atividades simultâneas com coordenação.
- O motor avança por estados controlados no servidor; visual pode usar alinhamento/tween/constraints, sem tornar física instável a autoridade do pagamento.
- Se um participante sair, a máquina retorna para condição segura; ninguém perde o motor, a OS nem o dinheiro por crash.
- Locks por máquina/peça e exceções de recuperação.

**Outras máquinas:** elevador com controle e segurança; scanner com exames; desmontadora/balanceadora; polidor; limpador ultrassônico multi-slot; bancada elétrica; alinhamento avançado. Máquina comprada precisa desbloquear operação real, não apenas autorizar a mesma barra de timing.

**Nova melhoria — processamento em lote:** carrinho para 3–6 peças, limpador/polidor com 2–4 slots, progresso independente. A progressão reduz caminhadas tediosas e espera artificial.

### 5.5. Loja e estoque com logística

Peças circulam de forma clara:

~~~text
Oferta/Compra -> Encomendada -> Entregue -> Armazenada
 -> Reservada para OS -> Utilizada/Devolvida -> Consumida ou Reaproveitada
~~~

Não criar caixa visível com “entrega” se o servidor também deu a peça diretamente de maneira incompatível. Se fase não tem caminhonete, usar depósito ou ponto de recebimento com feedback honesto. Preservar operação do estoque antigo enquanto migra.

**Nova melhoria — reserva de estoque:** uma OS reserva quantidades; outra OS não consome a mesma peça simultaneamente. Cancelamento devolve, finalização consome uma única vez.

**Nova melhoria — escolha de peça:** nova, remanufaturada e usada, com custo, prazo, garantia, durabilidade e risco transparentes. Não permitir arbitragem sem limite.

**Nova melhoria — vitrine física de motores:** lojas podem exibir motores em guinchos e filtrar catálogo por motorização ao interagir; uma qualidade de UX observada na referência.

**Nova melhoria — carrinho de oficina:** transporte de várias peças, sem exigir 8 viagens idênticas.

---

## 6. COOPERAÇÃO, CARREIRA E MERCADO

### 6.1. Cooperação operacional, não “delegar e clicar”

No sistema atual, um colaborador recebe atribuição e pode finalizar por caminho diferente do reparo normal. Migrar com cuidado:

- **WorkOrderTaskService/CoopService** ou extensão equivalente à arquitetura atual.
- Party temporária por oficina/OS; primeira versão de 2 jogadores. Até 4 depois de validação.
- Permissões por tarefa, peça, estação e veículo; nenhum convidado pode mudar preço, estoque, fachada ou dados do dono sem autorização explícita.
- Convite informa papel, divisão de pagamento e condições.
- Cada participante realiza trabalho verificável. XP pessoal por contribuição real.
- Pagamento definido antes; dono não altera participação unilateralmente depois do aceite.
- Se convidado sai, libera tasks, reatribui e preserva progresso legítimo.
- Um NPC pode ser assistente de tarefa para solo, com custo e eficiência próprios; nunca “jogar sozinho é impossível”.
- Alterações do legado via feature flag; jobs antigos continuam disponíveis.

**Exemplo de um serviço de radiador:** A realiza diagnóstico e desmontagem; B separa peça e usa máquina; A instala enquanto B prepara teste; A e B acompanham finalização. Não criar loops que obrigam dois jogadores a apertar o mesmo botão repetidamente.

**Nova melhoria — trabalho avulso no bairro:** jogador habilitado encontra no quadro pedidos de ajuda de outros proprietários e é contratado para uma etapa específica. Ao concluir, recebe remuneração e XP, sem se tornar sócio permanente.

**Nova melhoria — aprendiz NPC:** apoio limitado carregando peças, segurando componente, operando mecanismo auxiliar e reduzindo gargalos; não substitui a cooperação humana inteira.

### 6.2. O mercado já existe; torná-lo justo e legível

Auditar CustomerRules e RivalService atuais. O fator 1/preço² pode gerar incentivos fortes para reduzir preço. Criar perfis de cliente:

- Econômico: custo e deslocamento.
- Urgente: fila e prazo.
- Exigente: especialização, nota, qualidade.
- Fiel: histórico e confiança.
- Comercial/frota: volume e previsibilidade.

**Não inventar justificativa individual após sorteio probabilístico.** Mostrar tendências verdadeiras de mercado: percentuais agregados, origem, expectativa e fatores da escolha. O jogador deve entender por que investir em ferramenta, especialização ou atendimento pode mudar clientela.

**Nova melhoria — reputação por especialidade:** uma oficina pode ser conhecida por motores, outra por pneus. Manter nota global e compatibilidade com o ranking antigo.

**Nova melhoria — orçamento honesto:** após diagnóstico, cliente aprova plano com custo, peça e prazo; alterações fora do escopo precisam de novo consentimento simulado. A experiência valoriza confiança.

**Auditoria técnica específica:** conferir se rivais NPC aumentam renda/reputação antes de completar atendimento; se sim, desacoplar progresso de evento não realizado. Rever participação dos rivais e disponibilidade de vagas. Não prometer competição “realista” com dados fictícios.

**Ranking justo:** qualidade, produtividade e resultado econômico separados; não coroar apenas a maior oficina com mais funcionários. Jogador solo precisa ter categorias competitivas.

### 6.3. Clientes com memória e garantia

Reusar clientes fiéis. Criar histórico compacto (cliente + veículo + últimos serviços + reclamação + satisfação), sem inflar DataStore.

- Cliente pode retornar com o mesmo carro, mencionar serviço anterior e pedir revisão.
- Garantia limitada e transparente: falhas coerentes com baixa qualidade podem gerar revisão; nada de punições aleatórias desproporcionais.
- Reparo muito bom aumenta confiança, indicação e retorno.
- Diagnóstico errado não deve causar fraude invisível; o jogo apresenta consequência e chance de recuperar a satisfação.

**Nova melhoria — ética mecânica como gameplay:** evitar troca desnecessária, oferecer orçamento razoável e explicar o problema aumenta confiança. Não criar sistema moralizante; oferecer dados e consequências claras.

### 6.4. Contratos e eventos conversam com a oficina

**Não duplicar ContractService.** Evoluir contratos de frota e Hora do Rush.

**Mutirão de frota:** uma empresa envia vários carros com especialidades diferentes; até duas oficinas se associam ou disputam atendimento; premiação considera prazo e qualidade, sem ignorar participação. Solo/NPC fallback.

**Chamado externo:** veículo quebra próximo do bairro; jogador faz triagem e leva serviço à oficina; reboque/dirigibilidade somente quando existir infraestrutura real. Não construir estrada gigante agora.

**Nova melhoria — demanda contextual de bairro:** frio/calor/chuva podem alterar tipos de ocorrência *com comunicação clara*, sem prometer física climática avançada. Eventos precisam usar receitas, peças, máquinas, reputação e equipe existentes.

**Nova melhoria — presença social real:** NPCs visíveis, carros ocupando boxes, elevadores operando, jogadores ajudando na rua e quadro de trabalho público. Densidade visual/social é mais valiosa inicialmente que ampliar a cidade.

---

## 7. PROGRESSÃO, RESTAURAÇÃO E ENDGAME

### 7.1. Oficina com evolução funcional

Manter níveis existentes 0/1/2/3 e vagas 1/2/4/6 (conferir código atual). Cada nível deve destravar **formas novas de trabalho**: estação, espaço, processo, capacidade, contrato, equipe e especialidade. Não limitar evolução a aumento de salário passivo.

**Nova melhoria — especialização de identidade:** oficina pode virar referência em elétrica, pneus, motor, funilaria ou preparação. Vitrine, placa, tipos de cliente e possibilidade de contratar profissionais precisam refletir essa decisão.

**Nova melhoria — planejamento de fila:** proprietário escolhe atendimentos de margem/prazo/complexidade diferentes; não apenas aceita todos os carros sem consequência.

### 7.2. Segunda carreira: restauração de carros próprios

**Somente após mecânica modular e economia estarem validadas.** Não criar engine de reparo paralela.

~~~text
Comprar usado/sucata -> Inspecionar -> Orçar -> Restaurar por receitas
 -> Testar -> Avaliar -> Expor, usar ou vender
~~~

A condição do carro e as peças precisam persistir (ID compacto). Preço de venda baseado em condição, histórico, custos, demanda e qualidade; **não prometer multiplicador fixo de lucro**. Leilão/trade entre jogadores só com segurança transacional e antidupe testados.

**Nova melhoria — coleção de projetos:** mostrar carro antes/depois, ficha de reparos, placa fictícia e histórico de proprietário. Gera prestígio, não dinheiro passivo infinito.

### 7.3. Preparação, ECU e dinamômetro

Deixar para depois da validação de condução ou simulador de teste real.

- Suspensão/cambagem/altura/coilovers têm impacto mensurável em teste.
- ECU mostra curva simplificada de torque/potência; ajustes têm trade-off em temperatura/consumo/confiabilidade.
- Dinamômetro gera laudo antes/depois.
- Testes de pista solo com NPC fallback apenas quando direção realmente existir.
- UI lateral e câmera orbitável sem cobrir carro.
- Reputação de preparador vinculada a resultados registrados.

**Não transformar o Oficina 24H num jogo principalmente de corrida.** O tuning serve à mecânica e à carreira.

---

## 8. HUD CONTEXTUAL E EXPERIÊNCIA

Implementar modos:
- A pé: saldo, reputação, cliente, ferramenta, convite.
- Recepção: NPC, reclamação, espera, conversa.
- Diagnóstico: exames, evidências, hipótese, próximo teste.
- Reparo: peça, estado, ferramenta, bloqueio, progresso.
- Máquina: ocupação, slots, controles e peça em processo.
- Co-op: tarefa de cada participante, progresso geral e contribuição.
- Gerência: fila, estoque, equipe, reputação, contratos e preço.
- Dirigindo: velocidade, marcha, rota (SOMENTE quando condução livre existir).
- Evento: objetivo de equipe e progresso sem obscurecer a cena.

**Proibição de UX:** loja ou inventário escurecerem o restante da tela, interface central cobrindo o carro, velocímetro quando a pé, menus com tradução automotiva incorreta, botões exclusivos de mouse/teclado.

**Nova melhoria — inspeção de peça:** tooltip perto do componente, highlight do que bloqueia operação, indicação específica de ferramenta e ação; possibilidade de orbitar câmera.

**Nova melhoria — comunicação da equipe:** mostrar quem opera máquina, quem é responsável pela peça e o que pode ser feito em paralelo. Sem permitir que painel de outro player monopolize a tela.

**Nova melhoria — fila legível:** cartões de clientes mostram modelo/preview, queixa, paciência, pagamento estimado e especialidade, **mas não o defeito verdadeiro**. Cliente continua fisicamente presente e expressa impaciência até sair.

**Acessibilidade:** suporte a toque e gamepad quando aplicável, botão de reduzir movimento, textos legíveis, controles com feedback, assistências ajustáveis e contraste. Sem Studio, entregar código e checklist, não afirmar aprovação visual.

---

## 9. ASSETS E DIREÇÃO VISUAL, SEM COMPUTER USE

O repositório documenta modelos e IDs em docs/ORIGEM_ASSETS.md, pipeline/asset_ids.json, pipeline/cars_selection.json, pipeline/prop_selection.json, src/shared/HudAssets.lua e src/shared/PartModels.lua. Verificar cada um.

- Modelos de carros importados podem existir somente no place dentro de ServerStorage/Assets; GitHub não garante acesso a esses bytes.
- **Nada de inventar modelo gratuito, link, licença ou ID.**
- Criar AssetRegistry e AssetAdapter quando necessário, com nomes estáveis e fallback procedural para testar lógica.
- Criar manifest com: categoria, função, expected path, sockets/Attachments, nome do modelo, escala aproximada a validar, estado, licença, fonte, passo manual de importação e teste Studio.
- Não usar marcas/placas/QR codes de veículos reais; código e dados de atribuição devem preservar obrigações CC BY. Não publicar arte com autorização pendente.
- Direção final realista/industrial/PBR; placeholders em Parts são apenas substitutos funcionais.
- Minimizar overdraw, efeitos por frame e modelos pesados sem LOD; não alegar FPS sem medir.
- Máquinas novas devem funcionar com geometria simples e ser substituíveis por um Mesh/GLB validado mais tarde.
- Registrar dependências humanas **específicas**: “importar modelo X em ServerStorage.Assets...”, “criar Attachment Y”, “ligar Pivot”, “testar escala”. Nunca escrever “falta ajustar tudo manualmente”.

---

## 10. ROADMAP DE CÓDIGO POR FASES E FATIAS VERTICAIS

**Este roadmap é ordem de dependência, não ordem para gerar tudo no mesmo PR.** Uma fase pode ter vários PRs. A cada PR, a implementação deve atravessar shared/server/client/teste/doc quando aplicável. Só avance em integrações dependentes quando houver revisão suficiente; se faltar Studio, documente e trabalhe em blocos independentes sem fingir validação.

### FASE 0 — Auditabilidade e baseline

**Objetivo:** confirmar versão exata e definir contratos.

**Arquivos:** documentação citada na Seção 2; novos ROADMAP_MASTER_2026.md, IMPLEMENTATION_LOG.md, QA_MANUAL.md e ASSET_INTEGRATION_MANIFEST.md.

**Fazer:** inventário de módulos e remotes, mapa da UI, entidades, responsabilidades, estado de persistência, testes e assets; identificar acoplamentos arriscados e produzir prioridades. Feature flags se já houver ponto seguro para inclusão.

**Não fazer:** refatorar toda a aplicação, reescrever docs antigos ou marcar testes como executados.

**Aceite:** cada lacuna importante mapeada ao código real; plano de PRs e testes; linha de base com SHA do repositório.

### FASE 1 — Engine de receitas de reparo, sem quebrar legado

**Objetivo:** um serviço deixa de ser uma única ação genérica.

**Implementar:**
- Definição de RepairRecipe e Steps em shared, com dependências e validação de DAG.
- Estado por OS, locks de etapas e transições em servidor.
- API/snapshot mínima de progresso e “próxima ação”.
- Integração incremental com WorkshopService e Catalog, mantendo reparo antigo para receitas não migradas.
- Primeira receita piloto, sem depender de asset novo.

**Testes:** grafo cíclico, etapa bloqueada, passo fora de ordem, replay, cancelamento, versão de receita, fallback de serviço antigo, validação de sessão, regressão de pagamento.

**Aceite:** há receita data-driven conectada ao job sem duplo pagamento; velho minijogo continua disponível.

### FASE 2 — Diagnóstico por exames e evidências

**Objetivo:** substituir palpite puro por investigação.

**Implementar:**
- Sintomas, testes, evidências e hipóteses coerentes.
- Módulo de regra pura com resultado determinístico quando a semente/caso é conhecido.
- Servidor controla exames liberados/consumidos.
- UI de diagnóstico contextual e revisão de onboarding.
- Pilotos: pneu furado, bateria com defeito, arrefecimento.

**Testes:** evidência obrigatória, resposta não revelada antes, diagnóstico inválido, servidor não aceita exame impossível, reentrada, erro e correção, acessibilidade.

**Aceite:** o usuário tem motivos para investigar e recebe explicação do defeito.

### FASE 3 — Carro modular e estado de peças

**Objetivo:** peças com função e ciclo visível.

**Implementar:**
- PartState/VehicleAssemblyRules, sockets e grafo pequeno de acesso.
- AssetAdapter para modelos existentes e fallback procedural.
- Ações de remover, posicionar, instalar, inspecionar.
- UI de highlight, bloqueio e ferramenta contextual.
- Estado no servidor; efeitos no cliente.

**Testes:** peça incompatível, remove sem precondição, falta de ferramenta, dois comandos simultâneos, perda/ausência de asset, ownership.

**Aceite:** pelo menos um veículo piloto com 6–10 pontos de interação de código, com manipulação de peça autoritativa. Validação visual segue NEEDS_STUDIO.

### FASE 4 — Máquinas operáveis

**Objetivo:** equipamento muda o que o jogador faz.

**Implementar:**
- Elevador controlável com estados e guarda de segurança.
- Scanner ligado a testes/evidências.
- Banco elétrico, desmontadora/balanceadora, limpador/polidor com processos próprios.
- Reservas de estação, requisitos e ocupação.
- Integração de preço/qualidade/XP com execução real.

**Testes:** uso sem comprar, distância, máquina ocupada, peça errada, fim do timer, repetição, interrupção e saída do jogador.

**Aceite:** três máquinas distintas têm comandos/resultados próprios, não só “abrir minijogo”.

### FASE 5 — Cooperação real e guincho de motor

**Objetivo:** dois jogadores podem agir simultaneamente sobre a mesma OS.

**Implementar:**
- Permissões temporárias por jogador/OS/peça/estação.
- Claims com timeout e recuperação.
- Funções de mecânico, operador e apoio (não classes permanentes).
- Divisão consensual de dinheiro e XP pela contribuição.
- Guincho com estado no servidor e animação substituível por asset final.
- Solo com operação assistida.
- Adapter para colaboração legada.

**Testes:** dois jogadores completam etapas diferentes, conflito na mesma peça, colaborador sai, dono sai, convite expirado, fraude de porcentagem, XP sem contribuição, pagamento duplo.

**Aceite:** trabalho cooperativo possui ações distintas de dois jogadores na mesma ordem; validar em Studio com 2 players depois.

### FASE 6 — Logística física de peças e estoque reservado

**Objetivo:** integrar compra, recebimento, armazenamento, transporte e OS.

**Implementar:**
- Pedido/entrega com estado.
- Reserva de peças por OS, devolução, confirmação de consumo.
- Carrinho multi-slot; processamento em lote das máquinas.
- UI de estoque e lista de compras compatíveis com o veículo.
- Mercado de peças usadas somente quando regras de valor estiverem auditadas.

**Testes:** compra concorrente, dois jobs reservando mesmo item, cancelamento, estoque sem saldo, reembolso, limite de mochila/carrinho.

**Aceite:** peças não duplicam; o fluxo físico reduz caminhadas repetitivas.

### FASE 7 — Profissões, contratação e progressão funcional

**Objetivo:** crescimento muda a operação da oficina.

**Implementar:**
- Novos benefícios concretos de equipamentos e melhorias.
- Trabalho avulso humano por especialidade, contraproposta e permissões.
- Assistente NPC limitado; tarefas de rotina.
- Progressão com especialização sem bloquear solo.
- Reuso dos níveis da oficina e sistema de funcionários atuais.

**Testes:** capacidade por nível, custos, funcionário não rouba XP, limites de contratação, duas negociações simultâneas.

**Aceite:** desbloquear uma melhoria altera opções de trabalho e não apenas multiplicador de renda.

### FASE 8 — Economia competitiva, cliente fiel e garantia

**Objetivo:** estratégia da oficina modifica mercado.

**Implementar:**
- Perfis de demanda e preferências de clientes.
- Diagnóstico/orçamento transparente.
- Reputação por especialidade conservando nota geral.
- Histórico compacto de cliente/veículo e garantia limitada.
- Auditoria e correção justificada dos rivais NPC, CustomerRules e rankings.

**Testes:** extremos de preço e fila, satisfação, qualidade, bônus de fidelidade, margem econômica, cliente desiste, rival cresce somente conforme regra.

**Aceite:** duas oficinas com estratégias diferentes conseguem ser competitivas; mercado consegue explicar tendências sem fabricar justificativas.

### FASE 9 — Eventos com consequência para o bairro

**Objetivo:** contratos existentes originam atividades sociais.

**Implementar:**
- Mutirão de frota e contrato de equipe/consórcio.
- Prazos, divisão de atividades e prêmio idempotente.
- Integração com demandas de clientes e rivais.
- NPC fallback para servidor vazio.
- HUD não intrusiva de evento.

**Testes:** evento expira, participante sai, solo, multijogador, uma OS pertence a contrato correto, prêmios não duplicam.

**Aceite:** evento usa a mesma engine de reparo, peças, qualidade e reputação.

### FASE 10 — Projetos próprios e restauração

**Objetivo:** segundo loop de longo prazo ligado à mecânica.

**Implementar:**
- Projeto de carro usado/sucata com estado persistente.
- Restauro via receitas existentes.
- Avaliação transparente por condição, qualidade, custos e demanda.
- Exibição/venda a NPC, sem arbitragem infinita.
- Coleção pequena com limite de capacidade.

**Testes:** projeto reabre após reconexão, orçamento, perda de peça, venda duplicada, preços extremos, perfil antigo.

**Aceite:** decisão de restaurar ou vender tem consequências e não substitui todo atendimento.

### FASE 11 — Preparação e teste automotivo

**Objetivo:** tuning tem propósito e consequência.

**Pré-requisitos:** peças e restauro estáveis; condução/teste funcional ou simulador de resultado honesto. Não criar mundo de corrida sem infra.

**Implementar:** setup de suspensão simplificado, ECU com gráfico calculado, trade-offs, relatório de dinamômetro e desempenho antes/depois.

**Testes:** entradas inválidas, limites, sem ganho fabricado client-side, custos e persistência, trade-offs.

**Aceite:** mudar configuração muda teste verificável, não apenas gráfico decorativo.

### FASE 12 — HUD contextual, localização e acessibilidade

**Objetivo:** todos os sistemas parecerem um único jogo.

**Implementar:** máquina/peça, jogador/colaborador, cliente, gestão e eventos com estados visuais. Não esconder gameplay com overlays, não cobrir peça com painel, melhorar câmera, fontes e formatos mobile.

**Testes:** estados vazios, transições, erros de tradução/termos, lógica responsiva; screenshots somente na etapa humana.

**Aceite:** sempre fica claro “qual é o próximo passo” e “qual consequência”.

### FASE 13 — Segurança, performance e QA

**Objetivo:** reduzir regressão antes de abrir beta.

**Implementar:** auditoria de remotes, limite de snapshots, limpeza de conexões/Instances, cache, scripts de QA no Studio protegidos, telemetria de abandono e conclusão, testes de persistência e regressões.

**Testes:** rejoin, sessão duplicada, transação dupla, spam, 2/6 jogadores em harness, lote cheio, assets ausentes, cliente sem rede, DataStore migrado.

**Aceite:** checklists e instrumentos para executar testes reais, sem alegar desempenho medido antes de medi-lo.

### FASE 14 — Handoff de assets e build de integração

**Objetivo:** entregar uma versão de código que possa ser montada e validada no Studio.

**Implementar:** manifest final de modelos e licenças, scripts de montagem de placeholders, contratos de sockets, inventário de IDs, roteiro de importação, checklist de publicação e lista de bloqueios.

**Aceite:** toda dependência externa tem ação concreta e proprietário sabe exatamente o que precisa importar/testar. Não declarar lançamento pronto sem Roblox Studio, celular, multiplayer e revisão de licença.

---

## 11. FATIAMENTO DOS PRIMEIROS PRs

O trabalho começa pela fundação e **uma fatia jogável**, não por uma pilha de 25 módulos não conectados.

| PR proposto | Conteúdo |
|---|---|
| 00 | Auditoria, ADR mínima, roadmap e pontos seguros de feature flag |
| 01 | RecipeRules e validação de grafo + testes puros |
| 02 | RecipeService conectado a WorkshopService + um serviço piloto + compatibilidade legada |
| 03 | Evidências e diagnóstico de três defeitos + UI correspondente |
| 04 | Peças com estado e slots + carro piloto + AssetAdapter |
| 05 | Máquinas com workflow + testes |
| 06 | Coop roles, permissões, claims, pagamentos |
| 07 | Guincho de motor cooperativo + solo assistido |
| 08 | Reservas/estoque/carrinho/entrega |
| 09 | Perfis de cliente e equilíbrio de concorrência |
| 10 | Contrato de frota compartilhado |
| 11+ | Restauração, tuning, direção e polimento quando os pré-requisitos forem verdadeiros |

PRs podem ser divididos ainda mais. Evite dezenas de arquivos substancialmente alterados em um único PR. Cada PR precisa informar claramente o que pode ser revertido e quais contratos foram alterados.

**Regra de progressão:** se um PR depende de resultado do Studio indisponível, conclua-o como NEEDS_STUDIO, documente teste exato e avance apenas nas tarefas que podem ser corretamente implementadas sem assumir que a anterior funcionou.

---

## 12. MELHORIAS ORIGINAIS ADICIONAIS — BACKLOG CRÍTICO E COESO

Estas são ideias candidatas. **Não construa todas automaticamente**; selecione apenas quando fortalecerem o ciclo principal e houver pré-requisitos.

**A. Quadro de despacho de OS:** agenda visual mostra vagas, urgência, especialidade, custo estimado, peças faltantes e responsável. Reúne equipe, cliente, estoque e rentabilidade.

**B. Laudo técnico compartilhado:** evidências do diagnóstico ficam registradas na OS; cliente fiel pode voltar e mencionar serviço anterior. Vincula diagnóstico, NPC, confiança e garantia.

**C. Garantia e retrabalho coerente:** reparo de qualidade ruim pode retornar, mas de modo limitado, previsível e com chance de correção; evita “avaliação é só número”.

**D. Orçamento antes de comprar peça:** cliente escolhe aceitar reparo novo/recuperado mais barato ou de melhor durabilidade; melhora negociação e cria tensão econômica legítima.

**E. Mutirão de bairro:** evento de vários carros que pode ser dividido entre oficinas; o resultado aparece no quadro e reputação da região.

**F. Mercado de profissionais:** um mecânico especialista procura trabalhos em oficinas alheias; adquire XP e pode começar negócio próprio. Gera coop sem forçar sociedade permanente.

**G. Histórias de clientes recorrentes:** mesmo NPC e veículo retornam com quilometragem, reparo e preferência; faz NPC parecer personagem e não moeda com pernas.

**H. Ferramentas que mudam procedimento:** pneumática acelera fixação; carrinho move lotes; scanner reduz testes; alinhador dá precisão. Equipamento precisa ter trade-off de custo/capacidade.

**I. Biblioteca de diagnósticos dentro do jogo:** a cada defeito resolvido, o jogador registra conhecimento e recebe dicas mais específicas para casos similares; progressão horizontal sem aumentar números artificialmente.

**J. Especialização da loja de peças:** motor exposto fisicamente pode filtrar catálogo pelo tipo; evitar nomes técnicos difíceis e compras incompatíveis.

**K. Peças usadas e economia circular:** recuperar e revender componentes; controle de condição impede geração ilimitada de dinheiro.

**L. Eventos de clima com efeito no mercado, não só no visual:** dias quentes elevam chamados de arrefecimento; chuva altera demandas; informar a tendência.

**M. Inspeção pré-entrega:** ligar motor, verificar temperatura, tensão, pressão e alinhamento conforme receita. Gera payoff concreto.

**N. Prestígio visual verificável:** placa, uniformes, fachada e mural de boas avaliações mostram conquistas reais. Sem pay-to-win.

**O. Contador de produtividade e qualidade:** rankings separados e justos, para que equipe grande e solo possam competir em categorias diferentes.

**P. Aprendiz NPC e assistente de guincho:** o jogador solo consegue executar serviço complexo pagando tempo/custo em vez de ficar travado por falta de parceiro.

**Q. Feedback de sucesso contextual:** cliente volta a ligar carro após reparo, comenta melhoria, entra e vai embora; mecanismo alimenta reputação em vez de pop-up puramente abstrato.

**R. Serviços de frota recorrentes:** contratos da mesma empresa têm memória e requisitos próprios; a qualidade anterior afeta chance de novo contrato.

**S. Obras e trânsito que geram chamados:** em fase posterior, eventos roteirizados e guincho podem nascer naturalmente na cidade; NÃO construir simulação de tráfego complexa prematuramente.

**T. Carros de projeto com antes/depois:** showroom e ficha técnica demonstram trabalho real; gera metas sociais e colecionismo sem renda passiva dominante.

**U. Dificuldade adaptada por domínio:** um iniciante pode executar serviço básico com ajuda; veterano encontra causas combinadas e diagnósticos mais sofisticados. Dificuldade tem que ser compreensível, não aumentar velocidade da barrinha.

**V. Relatório do turno:** mostrar clientes perdidos, ganho, margem, satisfação, serviços por especialidade e investimento seguinte; conecta competição ao aprendizado do jogador.

**W. Densidade social sem mapa maior:** baias e fachadas abertas, janela para oficina vizinha, quadro de oportunidades e personagens caminhando. Preferível a quilômetros de estrada vazia.

**X. Laudo de dinamômetro com histórico:** compara configuração anterior e atual; oficina pode ganhar reputação por desempenho comprovado. Só quando condução/teste permitir.

**Y. Máquina de bancada com processamento batch:** reduz grind dos vídeos de referência sem retirar o prazer de ver peça restaurada.

**Z. Opção de recusar ou terceirizar serviço:** contratos podem ser inviáveis por falta de especialização; dono decide contratar ajuda, pedir peça ou não aceitar, com efeitos claros de reputação/prazo.

Para cada ideia, classificar: impacto no loop, interação física nova, integração com sistemas existentes, custo de código, necessidade de asset, risco de exploit/economia, dependência e teste de valor. Rejeite ideias isoladas ou de baixa relação custo/benefício.

---

## 13. REGRAS DE ECONOMIA E RETENÇÃO

1. Margem = receita − peças − custo proporcional de funcionários/equipamento/logística. Faturamento alto não é necessariamente lucro alto.
2. Não criar inflação com restauração de lucro fixo, venda duplicável ou bônus sem custo.
3. Clientela precisa ter preferências variadas; preço mínimo não deve dominar todas as estratégias.
4. XP por atividade legítima; colaborador não ganha XP completo sem ação.
5. Não retirar patrimônio por sair da sessão ou não entrar todo dia.
6. Recompensas diárias e Hora do Rush já existem; não empilhar multiplicadores a ponto de invalidar economia.
7. Contratos e eventos geram metas compreensíveis, com fallback solo e tempo de descanso.
8. Monetização preferencialmente estética, transparente e não necessária para desempenho; não vender máquinas essenciais por Robux.
9. Usar métricas de retenção para verificar hipóteses: funil do primeiro serviço, tempo até segundo reparo, coop ativado, tarefas abandonadas, motivo de perda de OS, frequência de retorno.
10. Não chamar recompensas de “vício” nem projetar punições para pressionar abandono. Preferir motivação de domínio, comunidade e metas alcançáveis.

---

## 14. QA, SEGURANÇA E CRITÉRIOS DE ACEITE POR FASE

### Testes de regras a adicionar (mesmo sem executar)

- Receita válida não tem ciclo e respeita dependências.
- Tarefa bloqueada não pode ser concluída via remote.
- Dois pedidos simultâneos não instalam/consomem a mesma peça.
- Cancelamento de OS devolve recursos reservados.
- Concluir reparo duas vezes não paga duas vezes.
- NPC funcionário não concede XP indevido ao dono.
- Colaborador não acessa outra oficina ou outra ordem.
- Convite e percentual não podem ser adulterados depois do aceite.
- Desconexão libera tarefa/maquinário sem perda de recurso.
- Falta de asset produz fallback seguro, não erro e pagamento grátis.
- Um perfil antigo carrega novos campos sem ser zerado.
- Versão futura de dados não é sobrescrita.
- Mercado reage coerentemente a preço/nota/fila/especialização.
- Rivais não recebem renda indevida.
- Variações de receita são suficientemente diferentes no fluxo.
- Loja não vende item incompatível sem feedback.
- Eventos não pagam duas vezes por mesma OS.
- Restauração não permite revenda com arbitragem infinita.

### Testes de Studio a DOCUMENTAR para execução futura

1. Jogador novo completa onboarding.
2. Serviço simples reparado pelo dono.
3. Diagnóstico errado/certo e evidências.
4. Peça removida e reinstalada visualmente.
5. Elevação do carro segura e câmera adequada.
6. Estação ocupada / utilização simultânea.
7. Dupla executa ações diferentes na mesma OS.
8. Jogador desconecta na metade da cooperação.
9. Duas oficinas competem por clientes no mesmo servidor.
10. Modo solo sem parceiro continua funcional.
11. Mobile: textos, botões, câmera, prompts e render.
12. Sem asset específico: placeholder não trava.
13. DataStore em ambiente de teste, reentrada e migração.
14. Validação de FPS/memória/rede com concorrência real.
15. Licenças, assets, sons, créditos, conteúdo sem marcas.

**Nunca diga “testes passaram” se só escreveu testes.** Anotar “escrito, aguardando execução”.

---

## 15. PADRÃO DE ENTREGA E COMUNICAÇÃO ENTRE RODADAS

Antes de cada PR/fatia, registre:

- Objetivo de gameplay: o que o jogador faz e por que isso é divertido.
- Conexão entre sistemas existentes.
- Arquivos a alterar e contratos públicos impactados.
- Hipóteses, riscos e rollback.
- Testes previstos e dependência de assets/Studio.

Depois da implementação, entregue:

~~~text
FATIA / PR:
BRANCH / COMMIT / LINK (somente se realmente criado):
STATUS: CODE_COMPLETE | PARTIAL
REVISÃO: STATIC_REVIEWED | NOT_REVIEWED
TESTES ESCRITOS: ...
TESTES EXECUTADOS: nenhum (salvo ferramenta real)
STUDIO: NEEDS_STUDIO
ASSETS: READY | NEEDS_ASSET
ARQUIVOS ALTERADOS:
- ...
CONTRATOS/REMOTES AFETADOS:
- ...
COMPATIBILIDADE:
- ...
RISCO RESTANTE:
- ...
PASSOS EXATOS DE TESTE HUMANO:
- ...
PRÓXIMA FATIA:
- ...
~~~

Atualizar docs/IMPLEMENTATION_LOG.md e ROADMAP_MASTER_2026.md. Cada PR deve permitir inspeção e reversão simples. Evitar mais de 8–12 arquivos substancialmente modificados por PR sem justificativa.

Em revisões, procurar: API inexistente, módulo não importado, action não registrada, evento sem subscriber, botão inerte, fallback perigoso, dados não migrados, tarefa sem cleanup, recompensa sem idempotência, comando que supõe Studio aberto.

---

## 16. NÃO FAÇA

- Não reescreva o projeto inteiro.
- Não destrua o MVP atual.
- Não implemente todas as sugestões num único passo.
- Não confunda escrever código com testar gameplay.
- Não dê ao cliente autoridade sobre dinheiro, peças ou XP.
- Não invente resultados visuais do place e modelos inexistentes.
- Não amplie o mapa sem criar atividades.
- Não transforme o simulador em um jogo principalmente de corridas.
- Não reproduza o layout exato ou os assets de Mechanic Legends.
- Não esconda o carro com HUD opaca ou fundo escuro.
- Não torne coop obrigatória para serviços essenciais.
- Não permita que convite de co-op faça o reparo físico desaparecer.
- Não force microtarefas inúteis e espera repetitiva.
- Não introduza sabotagem, roubo, exploração de jogadores ou perda arbitrária por inatividade.
- Não publique asset sem direitos verificados.
- Não declare versão pronta para lançamento antes dos testes reais.

---

## 17. ORDEM EXECUTIVA PARA COMEÇAR AGORA

**A partir deste momento, execute sem pedir nova confirmação para decisões técnicas pequenas:**

1. Acesse o repositório e confirme a árvore/README/último commit.
2. Faça FASE 0 objetiva e gere arquivos de status e QA.
3. Escolha branch e faça **PR-01: RecipeRules + testes puros + primeira receita**, preservando fluxo antigo.
4. Faça revisão estática e atualize log/status.
5. Avance para integração de servidor e primeiro serviço piloto, em PR separado.
6. Continue por fatias pequenas de acordo com dependência, sem fingir Studio/asset.
7. Sempre que faltar teste humano, registre instruções exatas e continue apenas em código independente seguro.

**Metas de produto, nesta ordem:**

- **M1:** três serviços (pneu, bateria, arrefecimento) com diagnósticos e procedimentos *diferentes*, não apenas minijogo de timing.
- **M2:** um carro com componentes realmente manipuláveis e uma máquina operável.
- **M3:** dois jogadores realizando tarefas distintas e simultâneas na mesma OS, com solo assistido e pagamentos confiáveis.
- **M4:** resultado de serviços altera nota, demanda, especialização e concorrência de modo verificável.
- **M5:** contratos/eventos conectam oficina, NPCs, mercado e co-op.
- **M6:** restauração/tuning cria objetivos duradouros só depois de o núcleo estar validado.

**Critério principal de qualidade:** ao terminar uma OS, o jogador precisa lembrar **qual problema o veículo tinha, como o diagnosticou, quais peças manipulou, quem ajudou e como isso afetou sua oficina**. Se tudo se resume a clicar, receber moeda e repetir, mesmo com código limpo, o objetivo do projeto não foi atingido.

**INICIE AGORA PELA AUDITORIA E PRIMEIRA FATIA DE CÓDIGO DA FASE 1. PRESERVE O JOGO EXISTENTE. SEJA AUTÔNOMO E CRÍTICO. TRABALHE NO GITHUB COM PRs INCREMENTAIS. NÃO ALEGUE TESTES OU AÇÕES FORA DAS SUAS CAPACIDADES.**
