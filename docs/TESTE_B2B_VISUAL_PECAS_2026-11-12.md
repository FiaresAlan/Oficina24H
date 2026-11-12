# B2b — Encaixes por modelo e feedback físico das peças

**Branch:** `work/oficina24h-b2b-pecas-ferramentas-2026-11-12`  
**Base:** `work/oficina24h-b2-preparo-fisico-2026-11-12`  
**Status:** código no GitHub; sem execução no Studio/PC/celular.

## Entrega

A preparação criada na B2a passa a modificar a apresentação do veículo **no espaço 3D**, sem criar um segundo inventário ou sistema paralelo de pagamentos:

- **Roda:** cinco cabeças de porca visíveis na etapa de fixadores; após apoio hidráulico, a roda detectada por `VehicleFx.client.lua` se desloca visualmente do cubo.
- **Apoio:** base, pistão e prato de apoio local aparecem sob o veículo; a peça muda de posição após concluir a etapa.
- **Capô:** trava/maçaneta visual na frente, além da abertura do capô real quando a malha possui peça separada.
- **Bateria:** presilha metálica local libera e se desloca ao concluir o passo.
- **Arrefecimento:** bandeja de contenção local é posicionada sob a dianteira do veículo.
- **Ferramenta:** ao manter pressionado o prompt, aparece uma chave metálica animada para o mecânico executor; some ao soltar/concluir.

Todos esses elementos são **efeitos locais leves**, sem colisão ou física autoritativa. Não são modelos finais do Blender, e o servidor continua validando estado/ordem/distância em `WorkshopService`.

## Sockets específicos para cada carro

Para ajustar o posicionamento de um carro sem mudar código, criar os seguintes `Attachment` em `BasePart` existentes do modelo de veículo:

| Nome exato do Attachment | Local sugerido |
|---|---|
| `OficinaSocket_WheelBolts` | Face do cubo da roda dianteira esquerda |
| `OficinaSocket_JackSupport` | Ponto de apoio inferior, no chassi |
| `OficinaSocket_HoodRelease` | Trava frontal do capô |
| `OficinaSocket_BatteryBracket` | Presilha da bateria sob o capô |
| `OficinaSocket_DrainPan` | Região inferior do radiador/tampão de drenagem |

Os sockets podem ser filhos de qualquer `BasePart` do modelo. `RepairSocketRules.Resolve` usa `Attachment.WorldCFrame` quando encontrado; caso contrário, mantém o offset de dimensões do modelo. `VehicleService` grava `SocketSource = "ModelAttachment"` ou `"DimensionFallback"` no ponto gerado, para auditoria no Studio.

**Importante:** os sockets referenciam a pose inicial da malha do servidor. O posicionamento final da ferramenta e dos efeitos após animações locais precisa ser conferido com cada veículo. A presença de um socket não significa que o componente seja desmontável por física real.

## Arquivos

- `src/shared/RepairSocketRules.lua` — contratos de nomes e resolução/fallback.
- `src/server/VehicleService.lua` — sockets na criação dos pontos da preparação.
- `src/shared/RepairPartVisualRules.lua` — estados active/completed e LOD.
- `src/client/RepairPartVisuals.client.lua` — props metálicos, animação de ferramenta, limpeza automática.
- `src/client/VehicleFx.client.lua` — roda deslocada após conclusão do apoio.
- `tools/RepairSocketTest.luau`, `tools/RepairPartVisualTest.luau` — 23 verificações, incluídas em `RunAllTests.luau`.

## Testar antes de merge

- [ ] No Studio, confirmar que os dois novos scripts são carregados pelo Rojo.
- [ ] Executar `RunAllTests`; não confundir testes escritos com testes executados.
- [ ] Abrir cliente de pneu: porcas presentes; soltar porcas; apoio aparece e se eleva; a roda sai somente depois de concluir apoio; minijogo continua.
- [ ] Abrir bateria: observar trava do capô e presilha; capô físico abre se o veículo tiver malha separada.
- [ ] Abrir arrefecimento: confirmar posição da bandeja, sem flutuar ou atravessar chão.
- [ ] Criar `OficinaSocket_BatteryBracket` num veículo de teste, deslocar o Attachment e confirmar `SocketSource = ModelAttachment`.
- [ ] Remover o Attachment e confirmar fallback sem erro.
- [ ] Repetir duas vezes a mesma OS, cancelar durante reparo, sair do servidor e verificar limpeza de props/ferramenta.
- [ ] Observar como outro jogador vê o reparo; tentar executar prompt de OS alheia, que deve ser negado pelo servidor.
- [ ] Celular touch e gamepad: hold de ferramenta, marcadores e HUD responsivos.
- [ ] 6 carros próximos e distantes: não deixar modelos locais antigos ou aumentar FPS/memória de forma relevante.
- [ ] Verificar que nenhum efeito local altera `DataStore`, inventário, XP, moedas ou físicas compartilhadas.

## Limites e próximos passos

Esta fase integra física visual e sockets genéricos, mas não instala malhas PBR, animações de personagem, juntas físicas reais ou desmontagem persistente de componentes. Essas exigem Studio/Blender/MCP e modelos já compatíveis. Próxima fatia recomendada: criar um **piloto com um carro real** (wheel hub, capô, bateria e radiador com sockets aferidos) e homologá-lo com 2 jogadores antes de multiplicar receitas e modelos.
