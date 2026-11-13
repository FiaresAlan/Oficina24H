# C6 — Resiliência a latência e retransmissões de reparo

**Data:** 12/11/2026
**Branch:** `work/oficina24h-c6-rede-resiliencia-2026-11-12` (baseada na `main`, commit `db6557f5`)
**Status:** código e testes escritos, aguardando CI e homologação real no Roblox Studio.

## Problemas reproduzidos por revisão de código

1. Em C5, `RepairAction` era executado uma única vez; após quatro segundos sem `RepairActionAck`, a interface cancelava a sessão. O servidor podia já ter aceitado o gesto: um ACK perdido causava perda de progresso.
2. Sem uma chave de correlação por revisão, uma confirmação **atrasada de comando anterior** podia consumir a resposta de um comando novo.
3. `CancelRepair` não exigia `JobId` nem token. Um cancelamento antigo de UI podia, em condições de rede, derrubar uma sessão que o jogador tinha acabado de reiniciar.
4. Uma falta de resposta do `FinishRepair` fechava a interface sem enviar cancelamento, deixando a sessão até expirar (quando não havia pagamento já concluído).

## Mudanças implementadas

- **Idempotência de ações:** `RepairActionRules` memoriza apenas o **último comando aceito** (`Kind`, `Id`, `Value`, `Revision`) e oferece `IsReplay`. Um reenvio exato da última revisão recebe ACK positivo **sem aplicar o gesto novamente**. Valores diferentes e revisões antigas continuam rejeitados.
- **Autorização preservada:** `WorkshopService.RepairAction` revalida propriedade/autorização, distância, equipamento e peças mesmo em retransmissões; só depois reconhece o último comando.
- **Correlação forte de ACK:** `Main.server` inclui `RequestRevision` na resposta. A UI só aplica um ACK se corresponder à revisão do seu comando atualmente pendente, com `JobId` e token correspondentes. ACK antigo é ignorado.
- **Retry delimitado:** a UI transmite uma vez, tenta novamente após 2,5 s e uma terceira vez após mais 3 s. O mesmo pacote/revisão é reutilizado. Se após mais 3 s não houver resposta, informa o bloqueio e cancela a sessão com seu token.
- **Cancelamento de sessão:** `RepairSessionRules.CanCancel` exige `JobId` e token para os procedimentos; a ferramenta legada de timing continua compatível. A UI envia os dois valores; um cancelamento de sessão anterior não afeta o reparo atual.
- **Entrega sem ACK:** o timeout final da UI foi estendido de 5 para 10 segundos, com aviso explícito e cancelamento identificado. O pagamento continua decidido pelo servidor.
- **Regressão:** `RepairActionRulesTest` foi ampliado para retransmissões, replay anterior à execução, números de revisão e payload forjado; `RepairSessionTest` cobre cancelamento com token antigo, JobId trocado e compatibilidade com timing.
- **CI:** contratos de transporte adicionados a `tools/ci/verify_contracts.py`, mantendo o build Rojo de código.

## Limites

- A implementação recupera **quedas de ACK enquanto a sessão do servidor continua ativa**. Não promete continuidade entre servidores ou após desconexão completa do jogador; nesses casos, a sessão é encerrada e a OS segue as regras já existentes.
- Não impede clientes automatizados de mandar comandos válidos; impede duplicações, desordem e cancelamentos de sessões que não correspondem.
- Retransmissões só reconhecem o último comando aceito; comandos muito antigos são rejeitados.
- A operação de `FinishRepair` continua sendo single-use: o servidor não repete moedas nem XP quando um cliente retransmite a entrega.
- CI/compilação **não substituem testes com latência simulada**, dispositivos e dois jogadores.

## Aceite pendente — Roblox Studio

- [ ] Executar `RunAllTests` com `RepairActionRulesTest` e `RepairSessionTest`.
- [ ] Testar 0, 200, 500 e 1.000 ms de latência em cliente/servidor com todo o ciclo de pneu, bateria e retífica.
- [ ] Simular ACK perdido e reenviado: confirmação dupla não pode duplicar etapa, consumo de peças nem moedas.
- [ ] Repetir resposta de revisão anterior durante nova ação: ignorar, sem alterar a HUD.
- [ ] Cancelar e reiniciar reparo; enviar cancelamento com token antigo: o reparo novo deve continuar.
- [ ] Testar expiração aos 90 segundos; recuperar da latência de comando sem contornar duração.
- [ ] Validar toque rápido, botões mobile e gamepad: estados visuais não devem mudar antes do ACK.
- [ ] Testar colaboração com dois jogadores, dono desconectando, latência assimétrica e ausência de pagamento duplo.
- [ ] Validar comportamento quando a resposta de `FinishRepair` se perde: saldo e OS precisam refletir o resultado real, sem refazer pagamento.

**Integração de código permitida:** por autorização explícita do dono do projeto, após CI aprovado, separadamente da homologação do produto publicada no Studio.
