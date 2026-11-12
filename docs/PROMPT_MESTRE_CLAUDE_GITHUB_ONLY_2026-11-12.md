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

