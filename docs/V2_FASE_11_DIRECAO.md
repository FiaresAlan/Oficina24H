# Oficina24H — V2-11 | Fundamentos de veículo de OS dirigível

**Branch:** `work/v2-00-02-fundacao-pilotos-gestao-2026-11-13` · **PR:** #27 · **Data:** 13/11/2026.  
**Estado:** código e testes automatizados preparados; **CI estático e build Rojo**; **não realizado** playtest real no Roblox Studio, nem certificação dos assets importados, rede ruim, touchscreen ou gamepad. A `main` permanece reservada à reconciliação/QA V1.

## Resultado de engenharia

O **Hatch amarelo** (`Veiculo_Hatch_MG3`) de uma ordem de serviço aceita pode ser **dirigido por seu proprietário** por até 150 segundos. Os carros Sedã/Picape e as ordens de outros jogadores **não** são dirigíveis nesta fase. O motorista pode conduzir com W/S/A/D ou setas, gamepad e botões próprios de toque; `Backspace`, botão B ou `BOX` encerram a sessão. Câmera local acompanha o `VehicleSeat` e HUD exibe velocidade em studs/s, tempo indicativo e até 4 checkpoints consultivos.

**O carro da OS nunca é trocado por um veículo do cliente:** a `Raiz` ancorada da V1, box reservado e identificador da OS permanecem intactos. Antes do início, `VehicleService.SuspendForDrive` salva *para cada BasePart* transparência, colisão, toque e consulta, oculta o carro original e marca `Estacionado=false` (bloqueando reparos). Um **clone físico descartável** é construído com `VehicleSeat` e rodas procedurais: 4 `HingeConstraint` motor + 2 servos de esterço, chassi com colisão, elementos visuais sanitizados e rodas isoladas do chassi com `NoCollisionConstraint`. Após retornar, `VehicleService.ResumeFromDrive` restaura o original, preservando pivôs, posição, NPC/OS, prompts, peças, cliente, slot e status. Não há conversão de NPCs em motoristas nem interferência na animação V1 de chegada/saída dos clientes.

## Contrato de assets

O rig físico usa clone sem scripts do `ServerStorage.Assets.Veiculos.Veiculo_Hatch_MG3` quando possível (95 BaseParts no máximo; limite de dimensões X<50, Y<25, Z<60), removendo assentos e constraints herdados do asset, e soldando malhas **sem colisão/massa** ao chassi. Sem o modelo importado ou em asset incompatível, usa carroceria e cabine procedurais, sem falhar ao iniciar a sessão. Os pneus e eixos dinâmicos são criados pelo próprio jogo. Esse sistema é aditivo e não modifica o asset original de V1.

**Atenção:** o `VehicleSeat` e o chassi são operacionais em código, mas a confiabilidade do motor/servo depende da malha, terreno e física real em Studio. Ajustar torque, atrito, câmera e posição inicial após teste obrigatório. Não confundir build Rojo com validação de dirigibilidade.

## Segurança e limite da OS

- `WorkshopService.DriveCar` aceita somente `JobId` e `Mode = Start/Return`. Servidor confere OS ativa e dono, modelo piloto, carro estacionado, protagonista próximo e vivo, equipamentos/componentes fechados, elevador abaixado, ausência de mecânico NPC, colaborador ou minijogo aberto e exclusividade por jogador e veículo.
- `VehicleSeat.Occupant` é conferido no servidor; intrusos são desalojados. O servidor mantém `NetworkOwner=nil` em todas as assemblies do rig. O canal remoto independente `DriveInput` carrega **somente throttle/steer** entre -1 e 1, limitado a ~14 Hz. Remotos de outras contas, valores NaN/Infinity, fora de faixa ou sem ocupante correto são ignorados. Sem input novo há mais de 0,35 s, motor é zerado.
- `V2DriveRules.AssessMotion` usa apenas `Position` e `AssemblyLinearVelocity` OBSERVADOS no servidor. Limites: 54 studs/s, 260 studs de raio, ±desnível seguro e delta por tempo. Servidor reavalia a ~10 Hz; teleporte, queda, capotamento, obstáculo frontal em velocidade, tempo acima de 150 s, desconexão, respawn/morte ou abandono do assento encerram sessão e restauram o carro.
- Checkpoints ordenados, calculados a partir de `LotPath`/referencial da oficina, usam distância observada no servidor (raio 15 studs, intervalo mínimo 1,5 s). `Touched`/claims enviados pelo cliente não contam. A V2-11 **não paga moedas, XP, avaliações, progressão, bônus nem confirma diagnóstico**. A futura V2-12 exigirá gate próprio e validação econômica.
- `HireNpc`, `InviteWorker`, `RespondInvite`, `StartRepair` e `UpgradeWorkshop` não podem concluir ou trocar a OS/box durante o test-drive. `VehicleService.Despawn` cancela antes de liberar a vaga; `Main.PlayerRemoving` cancela antes de remover as OS.

## Arquivos alterados

- `src/shared/V2DriveRules.lua` — elegibilidade, limites, watchdog, checkpoint e input da física.
- `src/server/V2DriveService.lua` — físico do carro, controle do servidor, sessões, cancelamento e cleanup, confirmação de checkpoints.
- `src/server/VehicleService.lua` — suspensão/retorno de rig visual original da OS, callbacks de despawn.
- `src/server/WorkshopService.lua` — autorização integrada ao estado de OS, bloqueio NPC/colaboração, status público.
- `src/server/Main.server.lua` — comandos `DriveCar` e canal `DriveInput`.
- `src/client/V2DriveControls.client.lua` — câmera, controle analógico/teclado/gamepad/toque, HUD e ação de voltar.
- `src/client/UI/Panels/Orders.lua` — ação de conduzir/retornar na seção de OS em andamento.

## Testes de regressão escritos

- `V2DriveRulesTest`: proprietário, OS, distância, mecânico ocupado, roda/porta/capô, motorista indevido, spam, controle clamped, NaN, velocidade fictícia, teleporte, altitude, raio, checkpoint ordenado/replay, espera de assento, abandono, respawn, timeout e rede ruim.
- `V2DriveRigTest`: criação da instância real `VehicleSeat`, 4 motores, 2 servos, chassi e rodas não ancorados, saneamento dos assets e não mutação do original.
- `V2DriveSuspensionTest`: fixture de OS/box em ambiente Edit, bloqueio de proprietário falso, isolamento da vaga, ocultar e restaurar a aparência/collision exatas, duplo início, duplo rollback, bloqueio de elevador e roda aberta.
- `tools/RunAllTests.luau`: inclui as três suites. `tools/ci/verify_contracts.py`: contratos estáticos de autoridade, rollback, motor, segurança e bloqueios de pagamento.

**Os testes Luau devem ser executados no Roblox Studio.** CI garante apenas contratos estáticos e `rojo build`, não o comportamento físico real.

## Checklist de homologação Studio antes de V2-12

1. **Baseline:** entrar, aguardar Hatch de cliente, aceitar a OS e esperar o NPC estacionar; verificar posição do carro, cliente e prompts originais antes e depois do teste. Conferir 15 reparos normais sem test-drive.
2. **Modelo/controles:** Hatch real e fallback, rodar W/S/A/D, setas, gamepad XInput e tela de toque; câmera acompanha sem travar avatar, esterço para direita/esquerda, freio e ré coerentes. Rodas não atravessam o chassi; medir estabilidade em rampas, paredes e piso do bairro.
3. **Autorização/concorrência:** dois jogadores, dono do Hatch e visitante acionam os botões; simular remotamente Start duplicado, carro Sedã/Picape, roubo do assento e `DriveInput` fora da faixa. Negar segunda OS/driving simultâneo do mesmo usuário. Garantir sem novos créditos nem consumo de peças.
4. **Rollback/vida:** Return via painel, Backspace, botão B, touchscreen, morte, reset, sair do assento e reconectar durante condução; colisão frontal, capotamento, queda e timeout >150s. Em todos os casos o Hatch volta ao **mesmo box**, prompts e estados mecânicos conservados, sem carro fantasma.
5. **Rota/riscos:** mapa com lotes de ambos os lados da rua, direções do trânsito, checkpoints do servidor na ordem, tentativa de teleporte ou entrada fora de ordem, cliente com ping alto/perda de pacotes. Confirmar que nenhum resultado libera dinheiro/XP ou conclui OS.
6. **Interferência:** tentar contratar mecânico NPC, convidar colaborador, iniciar reparo e ampliar a oficina enquanto está dirigindo; todas bloqueadas sem cobrança. Depois de Return, OS volta a funcionar e NPC segue caminho V1 intacto.
7. **Performance:** 1–2 jogadores testando carros, 6 lotes com veículos estáticos/clientes, FPS/memória/network physics e latência do servidor. O ownership forçado no servidor favorece segurança, mas pode exigir refinamento de responsividade após medições.

**Gate antes de V2-12:** assento, direção/freio, retorno, multiplayer, remotos, crash e rollback aprovados por Playtest real. Só então integrar defeitos e recompensas contextuais. A V2-08 (fornecedores/lotes FIFO) e reconciliação com `main` continuam independentes e abertas.
