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
