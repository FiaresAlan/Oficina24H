# Oficina 24H — V2-03 · Componentes 3D interativos

**Implementado na branch da PR #27 (13/11/2026). Ainda não homologado no Roblox Studio.**

## Arquitetura

Hatch MG3, Sedã Civic e Picape S10 usam os oito pivôs V2-01. O servidor monta oito ProximityPrompts ligados por WeldConstraint à Raiz: Hood, DoorLeft, DoorRight, Trunk, WheelFL, WheelFR, WheelRL e WheelRR. Os estados V2State_ são replicados por veículo: Open/Closed para painéis, Detached/Mounted para rodas. O mesmo canal físico de interação da V1 passa por Main.server.lua, WorkshopService.Interact e VehicleService.ToggleComponent.

O servidor verifica: OS em andamento; jogador designado/autorizado; distância máxima de 8 studs até o pivô real; veículo estacionado; nenhuma operação de reparo ou funcionário trabalhando. Rodas exigem diagnóstico prévio; para FlatTire exigem WheelBolts e JackSupport concluídos. A roda-alvo padronizada no procedimento V1 é a dianteira esquerda: WheelFL deve estar removida antes de iniciar o minijogo. WeakBattery e Overheating exigem capô aberto; o prompt V1 HoodRelease sincroniza V2State_Hood. Outras OS preservam a mecânica existente. Nenhuma ação de componente altera moeda, peças, XP ou comprovantes.

A saída do cliente recoloca os componentes antes de dirigir. O snapshot e a tela de OS mostram o próximo passo mecânico SOMENTE após o diagnóstico, sem revelar o defeito secreto. Teclado E, gamepad X e toque usam o HUD de prompts existente.

## Renderização e compatibilidade com GLB

- **VehicleFx.client.lua:** anima capô e rodas por estado do servidor, com sons curtos, mantendo animações anteriores da V1. Rodas são detectadas por geometria ou por tag explícita; se uma roda não for separável, gera pneu/cubo visual apenas no cliente.
- **V2ArticulationFx.client.lua:** anima portas esquerda/direita e porta-malas por dobradiças do pivô; uma MeshPart separada e marcada é preferida a um painel procedural.
- **V2EngineBayFx.client.lua:** exibe motor, bateria, reservatório de arrefecimento, admissão e alternador enquanto o capô está aberto. Somente os papéis ausentes são gerados como proxies sem colisão.
- As partes virtuais não alteram a colisão do Casco V1, scripts importados são removidos pelo AssetSafetyRules e nenhum novo RemoteEvent financeiro é criado. A renderização respeita distância, visibilidade e preferência por movimento reduzido nas portas.

### Importação dos modelos reais

Na cópia do place, preservar ServerStorage.Assets.Veiculos, Raiz, Casco e atributos V1 de dimensões/Motorista. O script **tools/V2AuthorPilotRigs.luau** pode criar os 8 Attachments sobre os templates; depois posicionar os pivôs na dobradiça das portas/capô/tampa e nos centros das rodas.

Para usar a geometria real em vez de fallback, separar as partes no Blender ou Studio e marcar cada BasePart/MeshPart com um atributo String:

| Atributo | Valores aceitos |
| --- | --- |
| V2MovingComponent | Hood, DoorLeft, DoorRight, Trunk, WheelFL, WheelFR, WheelRL, WheelRR |
| V2EngineBayRole | EngineBlock, Battery, Coolant, Intake, Alternator |

Atributos V2MovingComponent são individuais por peça móvel; rodagem nativa também pode ser identificada pela geometria. V2EngineBayRole só é necessário quando substituir os componentes do cofre procedural.

**Limite real:** o código articula partes separadas quando existirem. Um GLB monobloco usa visuais procedurais e NÃO passa a ser magicamente dividido em peças. A autoria de malhas, orientação visual dos eixos e ajuste de pivôs requer o place real no Studio; não marcar essa validação como concluída por CI.

## Regressão e aceite

- **tools/V2ComponentRulesTest.luau:** whitelist dos oito componentes; distância; autorização; carro parado; pré-requisitos das rodas e capô; impedimento de mecânico concorrente; saída segura.
- **tools/V2ComponentPlaceAudit.luau:** audita os 3 pilotos sobre clones do modelo, sem editar templates; missing GLB ou malha separada aparece como WARN, não como PASS.
- **tools/RunAllTests.luau:** registra as novas suites com as suites V1 e V2 anteriores.
- **tools/ci/verify_contracts.py:** verificações estáticas de autorização, prompts, visual, fluxo de reparo, pré-diagnóstico e inventário de assets.

**Antes de publicação:** rodar testes Luau no Studio Edit, realizar 15 reparos com 3 pilotos, testar abrir/fechar/montar/desmontar, elevar, cancelar, sair, convidado, funcionário NPC, servidor com 2 players, streaming e touch/gamepad. Medir FPS em dispositivos reais. Essas atividades NÃO foram executadas nesta rodada.

Próxima fase: V2-04 (reparos mecânicos diferenciados para os 15 defeitos) após revisão de dependências.
