# B2 — Pré-reparo físico/contextual, do veículo ao procedimento
**Data:** 12/11/2026  
**Branch:** `work/oficina24h-b2-preparo-fisico-2026-11-12`  
**Base:** `work/oficina24h-b1-colaboracao-com-reparo-2026-11-12`  
**Status:** implementação de código com revisão estática; **sem execução de Roblox Studio, testes Luau ou playtest real nesta rodada**.

## Entrega funcional

Os três defeitos piloto já tinham diagnóstico por evidência e uma interface de reparo distinta. Agora exigem **duas ações físicas no carro**, em pontos diferentes da malha local, antes de executar o procedimento contextual. O servidor mantém o estado e não aceita que `StartRepair` ou `FinishRepair` contornem o preparo.

| Defeito | 1º gesto no mundo | 2º gesto no mundo | Procedimento posterior |
|---|---|---|---|
| FlatTire | Soltar porcas na roda dianteira | Posicionar apoio do elevador sob o carro | Escolher local do vazamento e calibrar pressão |
| WeakBattery | Abrir o capô dianteiro | Liberar presilha da bateria | Executar sequência dos terminais |
| Overheating | Abrir o capô dianteiro | Preparar bandeja sob o arrefecimento | Ajustar fluido, sangria e ventoinha |

**As ações usam ProximityPrompt com hold, validate de distância e ordem pelo servidor.** São interações espaciais contextualizadas e feedback visual, mas **não** desmontagem real de malhas, parafusos com física ou peças 3D arrastáveis. O capô abre visualmente onde o modelo permite, reutilizando `VehicleFx.client.lua`.

## Compatibilidade e segurança

- `RepairPrepRules`: define receitas, ordem, sucesso, prompts e offsets, sem mexer no DataStore.
- `VehicleService`: cria cinco sockets genéricos soldados a cada carro; habilita apenas o passo autorizado, esconde o botão Reparar até conclusão, replica progresso e executor.
- `WorkshopService`: registra passo por OS; valida jogador responsável (dono ou contratado), diagnóstico, veículo estacionado, estado, ID e proximidade; checa preparo novamente no início e fim da sessão.
- `RepairPrepMarkers.client.lua`: jogador executante vê marcador amarelo para etapa pendente e verde para concluída, sem overlay escuro.
- `HUD.lua`: checklist adiciona etapa “Preparar o veículo” somente aos três pilotos, sem revelar o defeito antes do diagnóstico.
- `VehicleFx.client.lua`: ignora sockets de interface ao detectar peças, e reflete abertura do capô.
- `employeeWork`: NPC funcionário mantém a OS retomável quando falha por falta de peças; não captura automaticamente serviço cujo preparo manual já avançou.
- Defeitos legados fora dos três pilotos continuam funcionando sem etapa adicional.
- `FinishRepair` continua consumindo peças/pagando apenas uma vez após sucesso, usando lógica existente; preparo não entrega economia nem XP.
- Mecânico contratado usa os mesmos passos do dono enquanto designado; a UI do antigo dono não mostra prompts de execução durante a delegação.
- Posicionamento dos sockets é aproximado pela largura, comprimento e altura declarados no veículo; ajustes por modelo dependem de inspecionar o place.

## Testes de regressão escritos

`tools/RepairPrepTest.luau` contém **35 checks**: receita obrigatória vs legado, ordem de ações, rejeição de bypass, índices inválidos, prompts falsos, estados concluídos, offsets e limites de distância. Incluído em `tools/RunAllTests.luau`.

As verificações estáticas de integração do GitHub confirmaram ligação entre 17 responsabilidades de regra, servidor, carro, HUD e FX. **Não são equivalentes à execução de testes Luau.**

## Homologação obrigatória (Studio + 2 jogadores)

- [ ] Rodar todas as suítes por `RunAllTests`.
- [ ] Cliente de pneu: diagnosticar, tentar abrir reparo direto (deve negar), soltar porcas, apoiar elevador, abrir minijogo, finalizar e validar saldo/peça/avaliação.
- [ ] Tentar fazer segundo passo antes do primeiro (deve negar, sem consumos).
- [ ] Tentar ativar pontos de outro carro, de OS alheia ou distante (> 7.5 studs) (deve negar).
- [ ] Bateria: verificar que só o primeiro passo abre o capô nos modelos que possuem capô separado, completar segundo passo e sequência dos terminais.
- [ ] Arrefecimento: verificar posição da bandeja, completar preparação e executar procedimento.
- [ ] Serviço de funilaria/freios: minijogo legado inalterado.
- [ ] Contratar jogador B: apenas B deve ver prompts de preparo/reparo; B executa, peças saem do dono, pagamento é dividido sem duplicação.
- [ ] B desconectar durante preparo: A retoma etapa já validada; nenhuma sessão fantasma.
- [ ] Funcionário NPC falhar por falta de peças: ao adquirir peças o dono pode continuar manualmente sem bloqueio.
- [ ] Testar cancelamento, expiração e tentativa de `FinishRepair` forjada.
- [ ] Testar 2 jogadores, smartphone touch, gamepad, StreamingEnabled e veículos de tamanhos distintos.
- [ ] Confirmar ângulos, acessibilidade, capô móvel, ausência de overlays, CPU/FPS e licenças dos assets reais.

**Portões de publicação não satisfeitos:** não mesclar na main antes da homologação. Os PRs #7, #8 e #9 são dependências empilhadas; esta branch herda o código de todas.

## Limites de escopo

Este PR não cria objetos 3D de roda/bateria para manipulação livre, pintura PBR, loja nova, guincho nem co-op simultânea. O próximo incremento deve tratar sockets reais por modelo, animações de ferramentas e testes/feedback de resultado, depois cooperação simultânea. Não ampliar mapa nem mecânicas econômicas sem validação do núcleo.
