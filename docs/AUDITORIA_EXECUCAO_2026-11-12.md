# Oficina 24H — A0: auditoria de execução (2026-11-12)
**Base examinada:** `main` em `3988cb2a34776c3513cb6106cede81cce107cbb5`.  
**Método:** leitura do GitHub, sem Roblox Studio, execução de scripts Luau, câmera, assets do place, DataStore ou clientes reais.  
**Referência:** Product Master v2 (autoridade de produto até aprovação) e v3 (proposta de melhorias).

## Estado verificado na base

| Subsistema | Evidência estática | Status |
|---|---|---|
| Gestão da oficina | `WorkshopService.lua`, `WorkshopLevels.lua`, `DataService.lua` | Código presente; execução não testada |
| Clientes físicos e fluxo de OS | `CustomerArrivalService.lua`, `CustomerNpcService.lua`, `VehicleService.lua` | Código presente; execução não testada |
| Diagnóstico | `DiagnosisRules.lua`, `DiagnosisGame.lua` | Três alternativas; evidência física ainda não é parte do fluxo |
| Reparo | `RepairRules.lua`, `RepairGame.lua` | Minijogo comum de timing com 3–5 passos |
| Co-op | `WorkshopService.CompleteCollaborativeJob` | Transferência de execução com qualidade fixa 85%; não co-op simultânea |
| Mercado NPC | `RivalService.Serve` | **Defeito confirmado por leitura:** atualiza faturamento/nota antes de checar baia/carro |
| Compra presencial | `WorkshopService.nearShop`, `StationService.NearConstrutora` | **Risco confirmado:** retorno permissivo se prédio indisponível |
| Competição/preço | `CustomerRules.Score`, `WorkshopService.DispatchCustomers` | Fórmula estocástica com preço, reputação, nível, fila e distância |
| Persistência | `DataService.lua` `SCHEMA_VERSION = 4` | Código de lock/reconcile/retentativas; DataStore real não testado |
| Testes | `tools/RunAllTests.luau` | Testes disponíveis para executar no Studio; **não executados nesta auditoria** |
| Assets | `docs/ORIGEM_ASSETS.md`, `ServerStorage/Assets` documentado | Alguns recursos sem licença confirmada; modelos do place não inspecionáveis pelo GitHub |

## Ações aprovadas como implementação técnica de integridade

1. Em `RivalService.Serve`, só liquidar receita/reputação/nota quando o serviço foi concluído e o rival/baia/carro continuam válidos; tratar cancelamento/evicção sem prêmio.
2. Em `WorkshopService.nearShop` e `StationService.NearConstrutora`, **fail closed** em ambiente publicado sem objeto físico; manter exceção de QA somente no Studio, rastreável.
3. Criar helper puro de validação espacial e regressões Luau; integrar ao `RunAllTests`.
4. Antes de mexer no DataStore/OS, caracterizar atomicidade/rollback e testabilidade. Não reescrever persistência sem prova.

## Fila seguinte

- **A1:** correções de integridade dos rivais e estabelecimentos + testes unitários de proximidade.
- **A1b:** examinar casos de dupla cobrança/pagamento e cancelamentos, sem alterar prematuramente regras estáveis.
- **A2:** protótipo vertical de diagnóstico com evidências para pneu/bateria/arrefecimento; depois reparos distintos.
- **Portões reais:** Studio, dois jogadores, DataStore homologado, PC/celular e licenças. Nenhum portão foi satisfeito por este documento.

## Registro de limites

O código pode conter arquivos executáveis e testes relatados anteriormente. **A existência de arquivo, comentário ou contagem antiga de testes não prova execução nesta rodada.** O GitHub não contém a totalidade do conteúdo `ServerStorage/Assets`. Nenhum gameplay foi publicado/mesclado.