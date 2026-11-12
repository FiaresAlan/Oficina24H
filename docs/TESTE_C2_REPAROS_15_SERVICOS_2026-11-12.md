# C2 — Todo o catálogo com operações de reparo diferenciadas

**Branch:** `work/oficina24h-c2-procedimentos-15-servicos-2026-11-12`  
**Base:** `work/oficina24h-c1-diagnosticos-completos-2026-11-12`  
**QA:** scripts versionados, testes automatizados *escritos*, ainda sem execução confirmada no Roblox Studio.

## Mudança principal

Antes, o minijogo de timing se repetia em 12 dos 15 defeitos, criando uma sensação de profissão genérica. Nesta fase, o catálogo tem 15 planos de operação **diferentes em conteúdo** e 7 tipos de interação (3 pilotos anteriores e 4 famílias). O antigo minijogo permanece apenas como fallback de segurança para IDs desconhecidos.

| Interação | Serviços (12 novos) | Regra |
|---|---|---|
| Montagem em ordem | Pneu desgastado, suspensão solta, freio gasto, braço quebrado, retífica | Executar 4–5 etapas únicas em sequência; ordem incorreta penaliza qualidade |
| Calibração | Rodas desbalanceadas, direção desalinhada | Ajustar duas grandezas com unidade, limites, incremento e tolerância |
| Diagnóstico de circuito | Falha de ignição, falha elétrica | Selecionar ramo/fonte e intervenção correta |
| Recuperação de superfície | Amassado, colisão, pintura | Ajustar nível de tratamento em 3 áreas de severidades diferentes |
| Pilotos mantidos | Pneu furado, bateria fraca, superaquecimento | Local do furo/pressão; terminais; fluido/sangria/ventoinha |

## Alterações integradas

- `WorkshopProcedures.lua` define contratos das 12 receitas, sorteio determinístico da ordem visual dos botões, validação de tipo, limites numéricos, sequência, tempo e cálculo de qualidade por desempenho.
- `RepairOperations.lua` delega os 12 novos planos ao módulo, preservando os 3 modos-piloto e o contrato já usado por `WorkshopService.StartRepair` e `FinishRepair`.
- `OperationRepairGame.lua` tem botões específicos para sequência, calibragem, circuito e acabamento, além dos três painéis originais.
- `WorkshopProcedures.PublicPlan` não envia ao cliente a sequência correta, o alvo de circuito ou a intensidade desejada. Calibração publica tolerâncias e metas para o mecânico trabalhar com especificações.
- `RepairOperationsTest` atualizado para reconhecer que `Dent` agora possui procedimento de superfície; `WorkshopProceduresTest` cobre os 15 serviços e tentativas de inputs adulterados; integrado a `RunAllTests`.
- Nenhuma mudança de DataStore, preços ou estoque. O pagamento continua somente no servidor após `FinishRepair` válido.

## Limites técnicos

- Modos e decisões são validados no servidor, mas a UI ainda apresenta as operações em painéis: **não existe desmontagem física autoritativa para cada peça de cada carro**.
- A duração mínima por receita não prova, sozinha, que todos os gestos foram executados por um humano; isso exigiria protocolo incremental autoritativo por etapa (futura revisão de segurança).
- O visual é um estágio funcional, ainda dependente de Studio, assets reais e testes com jogadores.
- Não há retífica 3D complexa nem simulação de tinta profissional; cada serviço apresenta o respectivo raciocínio mecânico em escala de jogo.

## Portões de homologação pendentes

- [ ] Rodar `RunAllTests` sem erros; conferir os testes `WorkshopProceduresTest` e `RepairOperationsTest`.
- [ ] Executar os 15 serviços no Studio, de diagnóstico a pagamento, em níveis e equipamentos corretos.
- [ ] Testar sequência de 5 etapas (retífica), precisão de alinhamento, procedimento elétrico, pintura e estoque.
- [ ] Verificar que duplicação de `FinishRepair` não paga duas vezes; inputs falsos são negados.
- [ ] Validar interface de operações no celular vertical, celular horizontal, desktop e gamepad.
- [ ] Garantir que um serviço interrompido pode ser cancelado e a sessão limpa.
- [ ] Reconciliar branches empilhadas antes de `main`.
