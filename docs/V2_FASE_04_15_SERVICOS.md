# Oficina 24H — V2-04: 15 procedimentos mecânicos

**Implementação de código:** branch V2, PR #27, 13/11/2026. O Roblox Studio e os assets reais ainda não foram homologados.

## Fluxo técnico

Cada um dos 15 defeitos já tinha um minijogo de regras no servidor V1, em sete modos: Tire, Battery, Cooling, Sequence, Calibration, Circuit e Surface. A V2-04 acrescenta **três ações mecânicas específicas no carro** antes desse minijogo. O servidor controla sequência, disponibilidade da peça, ferramenta, estado do veículo, permissões e distância física de até 7,5 studs.

A aplicação está limitada, por enquanto, aos três carros piloto com rig V2-03 (MG3, Civic e S10); nos outros carros o fluxo V1 é preservado até a importação e configuração de seus rigs. Após diagnosticar, aparecem os pontos mecânicos e a próxima etapa no painel; antes do diagnóstico nenhum passo/defeito é revelado.

## As 15 receitas

| Defeito | Ações físicas antes do minijogo | Área |
| --- | --- | --- |
| FlatTire | localizar furo → preparar remendo → conferir válvula | Roda FL retirada |
| WornTire | apoiar cavalete → inspecionar pneu → preparar novo pneu | Roda FL |
| WeakBattery | medir tensão → isolar terminais → preparar bateria | Capô aberto |
| LooseSuspension | apoiar suspensão → inspecionar bucha → aplicar torque | Roda FL |
| EngineMisfire | conectar scanner → examinar ignição → preparar correção | Capô aberto |
| ElectricalFault | rastrear chicote → isolar circuito → preparar fusível | Capô aberto |
| Dent | marcar amassado → posicionar ventosa → conferir reflexo | Porta esquerda |
| BodyDamage | medir folga → preparar tração → conferir estrutura | Porta esquerda |
| PaintJob | lixar → mascarar frisos → conferir primer | Porta direita |
| WheelImbalance | examinar pesos → marcar contrapeso → preparar massa | Roda FL |
| Misalignment | medir convergência → regular terminal → conferir cambagem | Roda FL |
| BrakeWear | apoiar dianteira → examinar pinça → preparar pastilhas | Roda FL retirada |
| BrokenArm | apoiar conjunto → verificar fixações → preparar braço | Roda FL retirada |
| EngineOverhaul | medir compressão → inspecionar bloco → preparar kit | Capô aberto |
| Overheating | testar pressão → examinar radiador → preparar aditivo | Capô aberto |

**FL = dianteira esquerda.** A escolha foi mantida consistente com o reparo piloto da V1; a diversificação de rodas-alvo exigirá mudar os marcadores e roteiros conjuntamente.

## Segurança, avaliação e retrabalho

Os ProximityPrompts são criados pelo servidor só depois do diagnóstico. Cada comando verifica ator autorizado, OS, peça, equipamento e sequência; repetição, salto de etapa, veículo em movimento e falta de estoque são recusados. Os gestos físicos não criam XP, saldo nem peças. O consumo de materiais e o pagamento continuam exclusivamente na liquidação comprovada da V1, com controles contra replay. Nos serviços de roda/suspensão, o passo de apoio eleva fisicamente o carro pelo elevador do box; a roda só pode ser manipulada após a estabilização confirmada no servidor. Um box sem elevador válido não libera a desmontagem. O suporte permanece até a saída/cancelamento seguro da OS.

O usuário pode cancelar a tentativa antes de confirmar o reparo sem consumos, e repetir. O botão de reinício de sequências agora usa o Reset confirmado pelo servidor. O recap indica decisões imprecisas que reduzem qualidade e recompensa. Retrabalho após pagamento ou teste pós-reparo pertence à V2-13 opcional e não é simulado aqui.

## Feedback, assets e testes

O V2ProcedureFx.client.lua posiciona indicador localizado no componente ativo com texto e cor, só após diagnóstico e apenas para o participante da OS. Durante o minijogo o indicador some; no fim, o carro exibe o estado concluído. Continua utilizando os meshes/proxies da V2-03, não os reanima.

Arquivos fundamentais:
- src/shared/V2ServiceProcedureRules.lua: 15 receitas e validação adversarial.
- src/server/VehicleService.lua / WorkshopService.lua: prompts físicos, permissão, progresso, ponto validado, estoque e início do reparo.
- src/client/UI/Panels/Orders.lua, src/client/V2ProcedureFx.client.lua e OperationRepairGame.lua: instrução/feedback e recomeço seguro.
- tools/V2ServiceProcedureRulesTest.luau, tools/V2ProcedureIntegrationTest.luau, tools/AllServiceActionFlowTest.luau: regressão das 15 receitas físicas e dos 15 minijogos, incluindo replay. Integrados ao RunAllTests e aos contratos estáticos de CI.

**Ainda exigido no Studio pelo Claude/proprietário:** importar os três veículos e ajustar pivôs, rodar as suites Luau, executar os 15 serviços, verificar bloqueios por jogador/estoque/equipamento, colaboração, NPCs, timeout, múltiplas OS, mobile/gamepad, streaming e performance. Nenhum desses resultados foi presumido a partir de CI/Rojo.

A branch continua separada da main enquanto o Claude homologa a V1. Conciliar correções V1 antes de qualquer merge.
