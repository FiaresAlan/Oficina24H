# Oficina 24H — V1 C29 | Limpeza de carros e NPCs em cenas assíncronas

**Data-base:** 13/11/2026. **Status:** código e testes de regras preparados; CI estático + build Rojo. **Roblox Studio real não foi executado nesta rodada.**

## Falhas encontradas na revisão

1. `CustomerArrivalService.Arrive` reserva a cena, mas cria o carro dentro de uma `task.spawn`. Se a OS for removida pelo logout do dono ou por um cancelamento antes de a coroutine executar, `Clear` pode remover o estado sem encontrar nenhum modelo para destruir. A coroutine antiga ainda criaria o carro e seguiria dirigindo, sem uma ordem ativa.
2. `Depart` remove o registro principal de espera antes de o carro dirigir para fora. A reserva temporária da vaga no meio-fio (`lingering`) pode desaparecer assim que o carro começa a andar, antes de terminar a rota. Se o dono sair nesse intervalo, o carro e o NPC não são necessariamente recolhidos.
3. `VehicleService.Despawn` remove o veículo de `byJob` ao iniciar a animação de saída da oficina. `DespawnOwner` varria apenas `byJob`; portanto, carros já saindo não eram alcançados pelo logout. A liberação de vaga e a remoção visual poderiam continuar durante a nova sessão.

## Correções C29

- Criado `src/shared/VehicleSceneRules.lua`, com comparação de identidade da cena vigente e do proprietário. Não basta reutilizar o mesmo identificador de OS: uma rotina antiga nunca deve assumir um novo estado.
- `CustomerArrivalService.Arrive` verifica se a cena continua ativa **antes** de criar o carro e **depois** de construir o clone; se a cena não for mais atual, destrói carro e NPC sem iniciar movimento. Essa checagem também preserva o estado de outra chegada caso uma construção falhe.
- `CustomerArrivalService.Clear` remove cenas ativas e os registros temporários de meio-fio ligados ao proprietário. Carros transferidos para `VehicleService` não são destruídos pela rotina da rua, evitando conflito de propriedade.
- `CustomerArrivalService.Depart` mantém um registro próprio `curbDeparting` enquanto a despedida está em curso, independentemente da vaga ter sido liberada ou reutilizada. Ao finalizar, limpa os registros; quando o dono sai, destrói apenas os carros/NPCs pertencentes àquele dono.
- `VehicleService.Despawn` mantém `departing` separado de `byJob` durante a saída da oficina. `DespawnOwner` recolhe esses carros e NPCs, liberando a marca da vaga se ela ainda corresponde à animação antiga. Não altera vagas de outro jogador.
- `VehicleSceneRulesTest.luau` cobre cancelamento antes da execução, reuso de JobId, isolamento entre proprietários, identificadores inválidos e limpeza vinculada. O runner `RunAllTests` e contratos estáticos do CI foram atualizados.

## Checklist de testes no Roblox Studio

- [ ] Executar `RunAllTests`, incluindo `VehicleSceneRulesTest`, e `StudioPlaceAudit` com os modelos reais.
- [ ] Dono A recebe carro com a animação de chegada em andamento; desconectar A imediatamente. **Nenhum carro, NPC ou JobId de A** pode permanecer na rua.
- [ ] Repetir logout durante a caminhada do cliente do carro até a calçada.
- [ ] A dispensa uma OS: enquanto o cliente volta ao carro, A sai. Confirmar ausência de carros e NPCs órfãos.
- [ ] Permitir que o carro dispensado avance o suficiente para liberar a vaga do meio-fio; A sai antes do carro concluir a rota. Confirmar limpeza do carro já fora de `lingering`.
- [ ] A conclui um reparo e o carro começa a sair da vaga da oficina; A sai antes de terminar a rota. Confirmar limpeza, marca `JobId` da vaga liberada e nenhum objeto preso.
- [ ] Repetir em duas contas A e B: sair de A não pode interromper chegada, saída ou serviço de B.
- [ ] Reentrar com A, gerar novos clientes e confirmar que ninguém reutiliza estado/carro da sessão antiga.
- [ ] Testar `StreamingEnabled`, latência alta e mobile; investigar scripts de NPC que ainda referenciem modelos destruídos.

## Limites e próximos passos

A C29 melhora o ciclo de vida das cenas sem alterar economia, catálogo dos 15 serviços ou comportamento visual aprovado da rua. Testes de regras escritos **não comprovam** a execução do fluxo completo no Roblox Studio. A animação e os modelos reais precisam ser homologados após a importação dos cinco pacotes de assets já baixados pelo proprietário.

**Portões V1:** G1–G5 continuam abertos; [plano de finalização](PORTOES_FINALIZACAO_V1_2026-11-13.md). **V2:** não iniciada.
