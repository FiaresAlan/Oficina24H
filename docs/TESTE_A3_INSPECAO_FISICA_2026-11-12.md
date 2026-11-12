# A3 — Inspeção física de veículos: roteiro de integração
**Data:** 12/11/2026  
**Branch:** `work/oficina24h-a3-inspecao-fisica-2026-11-12`  
**Base:** `work/oficina24h-integracao-a1-a2-2026-11-12`  
**Status:** código no GitHub, análise de caminhos estática; **não foi rodado no Roblox Studio nem em celular**.

## Qual problema foi solucionado no código

Na versão anterior da A2, o diagnóstico tinha apenas botões de exame e uma checagem de distância até a caixa geral do carro. Era possível clicar em um teste de pneu estando perto do motor, e um teste de bateria não relacionado contava como prova suficiente para confirmar um pneu furado.

Nesta fase:
1. **Todo veículo** recebe três pontos lógicos de inspeção, soldados na PrimaryPart: pneu lateral, bateria esquerda e arrefecimento direito, ambos sob o cofre dianteiro.
2. Os pontos são criados usando dimensões `Largura`, `Comprimento` e `Altura` com limites e fallback; **não dependem de nomes dos MeshParts** dos modelos atuais.
3. Os pontos não ativam até o jogador conversar com o cliente e abrir o diagnóstico; ao concluir o diagnóstico ou retirar o carro, deixam de estar disponíveis.
4. O cliente local desenha marcadores discretos junto aos pontos **somente para seu próprio veículo**; um teste realizado ganha marcador verde. Nada é pintado no modelo compartilhado para outros jogadores.
5. Um clique no painel ou um `ProximityPrompt` físico aciona o **mesmo** `ExamineJob`; o servidor valida proprietário, OS, conversa, estado, ExamId e distância **do ponto correspondente**, não da caixa geral do veículo.
6. Para pneu, bateria e arrefecimento, um exame de outro sistema **não basta** para confirmar a hipótese. O servidor exige evidência relevante sem revelar o defeito nas mensagens.
7. O servidor também aplica tempo mínimo de 2/3,5/3 segundos para as operações; a UI avisa sobre tempo restante em vez de punir jogador que clicou rápido.
8. Defeitos não piloto continuam com minijogo legado, sem migrar DataStore.

## Arquivos afetados

- `src/shared/InspectionPointRules.lua` — offsets, identificação e distância.
- `src/server/VehicleService.lua` — pontos, welds, prompts, estágio e marcação de exames.
- `src/server/WorkshopService.lua` — permissões, roteamento, relevância e proximidade.
- `src/client/InspectionMarkers.client.lua` — BillboardGui locais e progresso.
- `src/client/UI/DiagnosisGame.lua` — instrução contextual.
- `src/shared/DiagnosisEvidence.lua` — confirmação exige exame relevante.
- `src/shared/RepairOperations.lua`, `src/client/UI/OperationRepairGame.lua` — tempo mínimo e explicação ao jogador.
- `tools/InspectionPointTest.luau`, `tools/DiagnosisEvidenceTest.luau`, `tools/RepairOperationsTest.luau`, `tools/RunAllTests.luau` — regressões.

## Testes de aceitação em Roblox Studio (pendentes)

- [ ] Rodar `RunAllTests.luau`; confirmar que todas as suítes (antigas + novas) passam.
- [ ] Entrar como novato: antes de conversar, não ver os marcadores; depois, enxergar os três pontos.
- [ ] Aproximar-se do **pneu** e disparar o exame por E/touch, confirmar leitura e marcador verde.
- [ ] Ficar longe do pneu e tentar `ExamineJob` via UI/remoto: negar, sem marcar.
- [ ] Executar só exame de **bateria** em um pneu furado: não liberar diagnóstico correto; fazer teste do pneu e concluir.
- [ ] Executar bateria e arrefecimento equivalentes; medir se os marcadores estão em posições corretas em cada modelo de carro.
- [ ] Conferir se outro jogador não vê os marcadores do meu carro, não pode examinar minha OS e não recebe pistas do defeito.
- [ ] Testar carros com modelos pequenos/grandes; nenhum marcador dentro do solo, teto ou rodas inacessíveis.
- [ ] Cancelar/abandonar/expirar OS; nenhuma peça/prompt residual.
- [ ] Validar os tempos mínimos: clique rápido mostra tempo restante, sem tentativa enviada; após o tempo, serviço pode ser concluído.
- [ ] Smartphone real, PC e gamepad; em celular, o HUD não deve obstruir o ponto de interação.
- [ ] Verificar performance com 6 vagas e NPC rivais, StreamingEnabled e carros desaparecendo perto da câmera.

## Limitações explícitas

- Os três pontos são **sockets aproximados no espaço local do veículo**, não correspondem ainda às malhas reais de bateria, radiador ou pneu; o alinhamento de cada carro requer Studio/MCP.
- Os marcadores são BillboardGui, não modelos de ferramentas/manômetros nem inspeção de raio-X real.
- Não foram criadas texturas, sons, animações ou alterações no `.rbxl`.
- Esse trabalho **não substitui** playtest de diversão ou homologação de P0.
- Não foi alterado schema de dados, economia de preços ou permissões de outras OS.

## Próxima fatia

A4: melhorar as operações mecânicas visuais, checkpoints de etapa e feedback no veículo; depois P1 cooperação com execução real e divisão de trabalho. Não antecipar tuning/mundo novo sem validar o núcleo.
