# Oficina 24H — C26 | Fechamento de ordens e pipeline de 15 serviços

**Fase:** V1 C26 · **Data:** 13/11/2026  
**Status:** implementação e testes Luau preparados, CI de contratos estáticos + Rojo. **Não realizado:** execução Roblox Studio/Edit, testes em dois jogadores, DataStore real, UI mobile, modelos 3D.

## Problema real corrigido

`WorkshopService.PlayerLeft` já removia veículos físicos via `VehicleService.DespawnOwner`, mas convertia ordens `InProgress` do dono desconectado em `Available`, mantendo seus `JobId` no servidor. Isso podia gerar uma **ordem fantasma** após a reentrada: cliente/veículo inexistente, OS no HUD e capacidade da oficina calculada sobre dados antigos. A recuperação não deve recriar um carro de uma sessão encerrada.

## Correções realizadas

1. Novo `JobExitRules.Action(job, leavingUserId)` diferencia `RemoveOwner`, `ReturnToOwner` e `None`.
2. Ao sair o **dono**, ordens `Available`, `InProgress` e `Completed` são retiradas da tabela `Jobs`. A rotina já existente `CustomerArrivalService.Clear` e `VehicleService.DespawnOwner` remove NPCs/carros; os atendimentos futuros serão **novas ordens**.
3. Se um colaborador tiver sessão de reparo no carro do dono que saiu, cancelar a sessão **mesmo que os atributos do avatar já tenham sido limpos**, informar encerramento e não conceder pagamento.
4. Se apenas o **colaborador** sair, manter a OS no proprietário, retirar o vínculo/percentual/timestamp da colaboração e devolver `AssignedWorkerUserId` ao dono. Não cancelar o carro do proprietário.
5. Acrescentar `JobExitRulesTest.luau`, com testes dos três status de OS, dono com colaborador, colaborador saindo, terceiro usuário e parâmetros inválidos.
6. Acrescentar `AllServiceActionFlowTest.luau` ao `RunAllTests`: cada defeito do catálogo é percorrido com uma sessão gerada no servidor. O teste envia gestos aceitos por `RepairActionRules.Apply` com revisão/ACK, reconstrói a execução em `FinalInput`, valida qualidade via `RepairOperations.Evaluate`, bloqueia comandos de revisão antiga e verifica que o plano público não revela o gabarito. **Não existe formulário final inventado** para substituir ações aceitas.
7. Contratos do CI em `tools/ci/verify_contracts.py` exigem que ambas as suítes existam e que `PlayerLeft` não reabra uma ordem sem carro. O CI só verifica estrutura e compilação do place Rojo, **não executa `RunAllTests`**.

## Matriz dos 15 serviços para QA de regras (não substitui gameplay real)

| Defeito | Procedimento de minijogo | Equipamento necessário |
|---|---|---|
| FlatTire | Tire: identificar furo + calibrar pressão | BasicToolset |
| WornTire | Sequence: elevar, retirar, montar, balancear | TireMachine |
| WeakBattery | Battery: terminais em ordem segura | BasicToolset |
| LooseSuspension | Sequence: apoio, inspeção, torque, carga | Jack |
| EngineMisfire | Circuit: cilindro e ação correta | Scanner |
| ElectricalFault | Circuit: alimentação e componente | ElectricalBench |
| Dent | Surface: corrigir intensidade por região | BasicToolset |
| BodyDamage | Surface: realinhar regiões da carroceria | BodyworkKit |
| PaintJob | Surface: intensidade de camada por região | Compressor |
| WheelImbalance | Calibration: massa e ângulo do contrapeso | Balancer |
| Misalignment | Calibration: convergência e cambagem | AlignmentRig |
| BrakeWear | Sequence: suporte, pinça, pastilhas e freio | Jack |
| BrokenArm | Sequence: apoio, substituição e geometria | SuspensionLift |
| EngineOverhaul | Sequence: drenagem, remontagem e compressão | EngineBench |
| Overheating | Cooling: fluido, sangria e ventoinha | BasicToolset |

## Roteiro de homologação no Roblox Studio (a executar após assets importados)

- [ ] **Preparação do place:** importar por categoria e configurar os cinco pacotes 3D já baixados de acordo com `GUIA_UNICO_ASSETS_V1.md`. Verificar licenças e `PrimaryPart`; fazer backup do bairro antes de substituir qualquer objeto.
- [ ] Rodar `tools/RunAllTests.luau` no Studio Edit e registrar **PASSOU**, falhas e avisos, incluindo as suítes `AllServiceActionFlowTest` e `JobExitRulesTest`. Não aceitar teste com zero verificações.
- [ ] Rodar `StudioPlaceAudit.luau` com carros, NPCs, equipamentos e lojas fisicamente presentes.
- [ ] Para cada um dos **15 serviços**, criar uma OS legítima com jogador e requisitos de nível/equipamento/estoque: chegada → aceitar → conversar → examinar se exigido → diagnosticar → preparar (quando exigido) → gestos → finalizar → cliente sair → avaliação/saldo/estoque/histórico atualizados uma única vez.
- [ ] Para **Tire/Battery/Cooling**, verificar prompts de preparação no ponto correto do carro (pneu, bateria, motor); para os outros 12, conferir interface do procedimento especializado correspondente.
- [ ] Cancelar sessão e reabrir o mesmo serviço: nenhum crédito ou consumo de peças pelo cancelamento.
- [ ] Com dono e colaborador, começar reparo e fazer **dono desconectar**: colaborar não pode finalizar/pagar uma OS cujo carro foi removido; após reentrada, não existem ordens fantasmas.
- [ ] Com dono e colaborador, fazer **apenas colaborador sair**: dono mantém carro/ordem, volta a ser o responsável e consegue concluir uma vez.
- [ ] Repetir com funcionário NPC caminhando, em reparo e após reparo concluído, sem criar pagamento extra.
- [ ] Homologar PC (1920×1080), celular (390×844, 320×568, 844×390), gamepad, FPS, StreamingEnabled, dois servidores, reconexão e DataStore.
- [ ] Revisar regressões e anotar falhas na Issue #15. Somente testes de Studio homologados podem fechar os portões P0 de gameplay.

## Pendências e limites

- **Nenhum teste real no Studio foi feito nesta fase.** A automação de CI só valida arquivos/contratos e faz build Rojo.
- Assets estão baixados/organizados no computador do proprietário, **ainda não importados** no Studio.
- Esta fase não altera os 15 minijogos em produção além de prevenir ordens fantasmas; o teste completo baseado em regras não substitui avaliação de UI, ergonomia, NPCs, modelos ou colisões.
- Pendências anteriores de pagamentos distribuídos/claims históricos continuam abertas. Não houve alteração financeira nesta fase.
- **V2 permanece documental**, sem alteração das mecânicas aprovadas para depois.

**Próxima fase sugerida da V1:** fechamento dos bloqueios de integração do Studio, com roteiro de diagnóstico de falhas reais (assets, HUD, duas contas, 15 serviços), antes de inaugurar novos sistemas de gameplay.
