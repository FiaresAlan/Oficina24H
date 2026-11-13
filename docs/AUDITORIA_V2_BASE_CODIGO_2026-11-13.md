# OFICINA 24H — AUDITORIA DA BASE C1–C17 E GAPS PARA V2

**Data:** 13/11/2026. **Commit auditado:** df3f1a66f12aa85afa8b2a09ba50af41106fee9b.  
**Método:** leitura do código, árvore, docs e Issue #15; sem Roblox Studio ou place real.  
**Conclusão:** NÃO é correto declarar que só faltam testes do Studio. Além de QA, faltam tarefas de integração visual e arquitetura, e algumas funcionalidades V2 ainda não existem.

## 1. Recursos já codificados que devem ser reaproveitados

| Área | Código-fonte | Estado |
|---|---|---|
| 15 serviços e diagnóstico | Catalog, WorkshopProcedures, DiagnosisRules, WorkshopService | Regras escritas; QA da experiência física pendente |
| Cliente, NPC e veículo entrando/saindo | CustomerArrivalService, CustomerNpcService, VehicleService, LotPath | Deslocamento automatizado; NÃO equivale a dirigir livremente como jogador |
| Mecânico NPC | NpcKit, WorkshopService, StaffAssignmentRules | Contratação/salário/serviço/caminhada programados; movimento real não homologado |
| Máquinas, ferramenta, estoque, loja | EquipmentService, EquipmentModels, WorkshopLevels, Panels/Shop, Panels/Stock | Código integrado; conferir modelos/attachments físicos no place |
| Plataforma de melhoria | EquipmentUpgradePads, EquipmentUpgradeRules, DataService schema v8 | Níveis I–III já escritos; risco de pisar acidentalmente e validação pendentes |
| Expansão 1–2–4–6 boxes | WorkshopLevels, StationService e UI da Construtora | Regra/estrutura codificadas |
| Receitas/colaboração/frotas | DataService, WorkshopService, ContractService, SettlementLedgerRules | Código presente; sem transação atômica multi-perfil |
| Painéis e onboarding | client/UI/Onboarding, Orders, Profile, Shop, Stock | Código presente; QA touch/gamepad e clareza pendentes |
| Bairro com rivais | RivalService e ferramentas de cidade | Há rivais e carros NPC; não existe prova de pedestres independentes de cidade |
| CI | .github/workflows/code-health.yml; tools/ci/verify_contracts.py | Checagens estáticas e build Rojo, NÃO roda todos testes Luau no Studio |

## 2. Pendências reais de código ou integração de assets

### P0 — Contabilidade e segurança
- Fluxo legado de reparo timing não possui todo o encadeamento token/claim do caminho moderno. Migrar ou encerrar com segurança, cobertura de idempotência e regressão.
- Recuperação de colaboração é eventual e limitada por arquivo de 1024 provas do dono; não garante atomicidade entre chaves. Política de prova durável, claims órfãs e limitação do custo de DataStore ainda precisam ser trabalhadas.
- Auditar concorrência de duas OS, duas compras em plataforma, saída/respawn, recuperação após falha de Save e entrega de recompensa do funcionário.
- Auditar autoridade do servidor e replay dos remotes de compra, upgrade, reparo, contrato, cancelamento, venda futura e conclusão.
- Não escalar economia de NPC/passiva até ter livro-caixa claro de despesas e receita.

### P0 — Carros reais e experiência de reparo
- Socket logical/fallback já existe em RepairSocketRules, mas capô com pivô, porta, roda, componentes e ferramentas precisam de pipeline integrado/validado em modelos de verdade.
- Os 15 serviços têm regras. A apresentação física, sonora e o feedback “antes/depois” de todas as famílias ainda não estão comprovados no place.
- docs/ORIGEM_ASSETS.md possui itens baixados e NÃO integrados; não assumir que arte/áudio final está pronta sem inspecionar o place.
- O staff usa pathfinding/fallback no código, mas navegação com obstáculos e animação do NPC requer refinamento/homologação.
- UI e painéis precisam mostrar status de negócio, tempo, lucro líquido e quadro de equipe com leitura clara, não só botões de mecânica.

### P1 — Não implementado e dependente de V2
- Veículo de OS dirigível pelo jogador, com assento, câmera, rede, controle, saída/retorno e cleanup. Rotas de carros NPC não cobrem isso.
- Test-drive contextual para diagnóstico e checagem pós-serviço.
- Compra e revenda de carros de sucata/restauração sem substituir reparos de clientes.
- Camada adicional de pedestres/trânsito, entregas e ciclo ambiental com LOD/pool.
- Painel gerencial consolidado, customização comercial e showroom.

## 3. Pendências que dependem do usuário no Studio
- Rodar RunAllTests e StudioPlaceAudit com place real; observar 15 serviços, dois jogadores, assets e erros de compilação/runtime.
- Testar datas/locks do DataStore, reconnect, perdas de rede, exploit attempts, latência e snapshot.
- Inspecionar física e animação de veículos, câmera, colisões, modelos R6/R15, mobile/gamepad e áudio.
- Medir memória, FPS, NPCs simultâneos e StreamingEnabled com mundo cheio.
- Fazer beta fechado e medir se as decisões são divertidas, não apenas se o código compila.

## 4. Inconsistências históricas e política de rastreamento
- Issue #15 tem checkboxes antigos “integrar após QA”, mesmo com código C1–C17 já na main. Tratar como histórico desatualizado, não como motivo para dar merge em código duplicado.
- Contagem da Issue #15 lida hoje: 131 itens marcados e 96 abertos. Quantidade não é porcentagem de produto pronto.
- Estados novos: C = código entregue, A = verificação automática executada, S = Studio/Playtest comprovado. Nenhum S é “verdadeiro” sem evidência.
- CHECK_LIST_MESTRE_V2 não apaga V1 e nenhuma feature planejada recebe [x] por existir no documento.

## 5. Regras de engenharia
1. Nenhuma mudança de gameplay V2 antes da autorização explícita.
2. Priorizar correções P0; mudanças pequenas, revisões de todos os fluxos tocados e testes de regressão.
3. Fase completa com contrato, UI/arte, erros, teste e relatório; até duas por rodada somente sem perder qualidade.
4. Integrar depois do CI; marcar código/automação separadamente de Studio.
5. Fazer vertical slice com 1 carro/1 defeito/1 rota antes de criar uma frota inteira.
6. Não declarar projeto “pronto para publicar” até QA real e critérios de publicação.

**Diagnóstico:** aproveitar o investimento em C1–C17, corrigir integridade, reforçar a fantasia de negócio e integrar interação física. O maior risco é expansão de escopo antes de provar o loop.
