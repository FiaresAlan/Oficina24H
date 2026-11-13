# Oficina 24H V2-05 — Mecânicos NPC e supervisão

**Implementação:** PR #27, branch V2 isolada, 13/11/2026. **Estado:** código no repositório; testes Roblox Studio ainda não realizados. A main permanece com a homologação da V1 conduzida pelo Claude Code.

## Experiência de jogo implementada

A V2-05 mantém as contratações físicas e o pagamento do jogo V1. Até **2 mecânicos** podem executar ordens enquanto o dono administra a oficina, condicionado ao nível do prédio. Cada um agora tem controles no novo separador **Equipe** do painel de ordens (acessível perto da TV física do proprietário):

- **Escala:** Automático (recebe serviço após prioridade do dono), Manual (somente serviço atribuído explicitamente), Pausado (não recebe nova tarefa, mas termina a atual).
- **Especialização:** Todas, Pneus, Motor, Elétrica, Suspensão ou Funilaria. Cada worker respeita seu foco.
- **Atribuição e cancelamento de fila:** o proprietário escolhe qual OS em andamento vai para qual mecânico. Não pode retirar uma OS que já está em execução; é necessário aguardar a conclusão. Se o contratado real assumiu, o NPC fica excluído.
- **Produtividade:** status, progresso, última OS, histórico de até 12 serviços, quantidade concluída, receita bruta, qualidade média e tempo médio; salário por mecânico, total pago e próximo vencimento.

O painel não calcula lucro líquido nesta fase; isso ficará na V2-08, que integra peças, folha, upgrades e custos de oportunidade.

## Como o NPC executa o trabalho

1. Seleção **servidor**, ordenada por atribuição manual, prioridade da OS, idade e ID. A primeira OS continua com 25 segundos de prioridade para o jogador quando só há um carro; com várias OS, o mecânico ajuda.
2. Reserva atômica por JobId antes do primeiro yield; duas tarefas concorrentes nunca podem consumir a mesma OS.
3. Caminhada com navmesh limitada e até dois recálculos: **cliente → estoque/ferramentas → box → descanso**. Se o cliente não estiver disponível, pula somente a parada social. Não teletransporta através de paredes quando a rota falha.
4. Animação visual com ferramenta, feedback progressivo e execução temporal reduzida pelos upgrades de equipamento já existentes. O NPC utiliza os materiais do estoque real; se faltam, suspende e reagenda a OS.
5. Liquidação usando **DataService.SettleNpcRepairOnce**, a mesma autoridade e proteções contra duplicidade da V1. Só após crédito confirmado em memória o serviço conta no histórico de produtividade. A confirmação definitiva ao jogador aguarda salvamento de DataStore por confirmNpcSave.

## Persistência, folha e segurança

- Migração aditiva do perfil **schema v12 → v13** com StaffSlots[1..2] e StaffPayroll; preserva saldo, ledger, reivindicações e provas financeiras da V1.
- Modos, foco, histórico e estatísticas são saneados e limitados no servidor. Um mecânico recontratado começa com estatísticas próprias, sem herdar as do demitido.
- Folha a cada 300 segundos: debita 60 moedas por funcionário, conforme Config atual. **NextPayAt e moedas são modificados sem yield no mesmo perfil**. O mesmo vencimento rejeita replay; reconexão preserva histórico e prazo. A falha de saldo não inventa pagamento, adia o ciclo e desliga um funcionário com cancelamento seguro do trabalho em andamento.
- A demissão manual bloqueia enquanto o último NPC estiver trabalhando. Se o dono desconecta ou um funcionário desaparece, a reserva é liberada, o carro volta a estado reparável e não há crédito sem validação.
- Todas as ações de escala e atribuição passam pela lista de remotes autorizados, validadas no servidor, perto da **TV de ordens da própria oficina**; a interface não pode criar salários/receitas/peças.
- O snapshot expõe apenas métricas de equipe e status úteis; listas internas com JobIds e planilha salarial não são replicadas dentro de Profile.

## Arte e assets: o que importar

**Não há novo download obrigatório para V2-05.** Reutilizar os NPCs R15 oficiais livres da V1 já organizados em `ServerStorage.Assets.Clientes`, com `Humanoid`, `PrimaryPart` e, quando aplicável, atributo `Genero`. O pipeline de NpcKit remove scripts importados, desabilita colisões e controla ownership no servidor.

**Fonte e instruções:** [GUIA ÚNICO DE ASSETS V1](GUIA_UNICO_ASSETS_V1.md) e [GUIA ÚNICO DE ASSETS V2](GUIA_UNICO_ASSETS_V2.md). Para melhores visuais, uniformes e kits de ferramentas podem ser adicionados depois, somente com origem/licença verificadas. Não substituir modelos do Claude nem remodelar a rua.

## Testes escritos / homologação pendente

- `tools/V2StaffRulesTest.luau`: escopo, especialização, escala, sanear dados, replay e histórico limitado.
- `tools/V2StaffDispatchTest.luau`: 0/1/2 empregados, 1/2/3 OS, reserva concorrente, prioridade, pausa e modo manual.
- `tools/PersistenceTest.luau`: migração v12→v13, salvar/reabrir em outro servidor, salário único, histórico e perfil antigo corrompido sem perder provas financeiras.
- `tools/V2StaffPlaceAudit.luau`: inspeção não destrutiva de assets, rigs e integração Rojo; ausência de modelo é WARN, não PASS.
- `tools/RunAllTests.luau` e `tools/ci/verify_contracts.py`: registram suites e validam contratos. GitHub Actions executa checks estáticos e build Rojo, **não** testes Luau.

**Teste obrigatório pelo Claude/proprietário no Studio:** contratar e demitir 0/1/2 mecânicos, esperar salário, faltar dinheiro, atuar com 1/2/3 OS, foco divergente, pausas, atribuições, duplo clique, dois jogadores, logout no meio da caminhada, queda de rede na liquidação, estoque insuficiente, bloqueio de caminho e recuperação, 15 serviços, gamepad/mobile e FPS. Registrar capturas e números antes de declarar a fase homologada.

**Limite de release:** finalização de código não equivale a testes visuais/funcionais. Esta PR não deve ser mesclada automaticamente na main enquanto o Claude altera V1. A próxima fase do checklist é V2-06 — upgrades físicos.


### Revisão adicional de navegação e integridade de dados

O cálculo de chegada dos NPCs utiliza **distância horizontal**, pois os pontos da oficina são medidos no piso e a HumanoidRootPart fica acima dele. Isso evita rejeitar rotas alcançadas por diferença apenas de altura. O despacho respeita prioridades `-1/0/+1`, e a telemetria recusa `NaN`/`Infinity` em qualidade, receita e duração para não contaminar os totais. A suíte `V2StaffNavigatorTest` e novos casos de `V2StaffRulesTest` registram essas regressões. A confirmação dessas suites no Roblox Studio ainda é necessária; o CI disponível não executa os testes Luau.
