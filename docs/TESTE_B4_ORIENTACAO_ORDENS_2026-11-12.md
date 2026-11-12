# B4 — Próximo passo real da OS, orientação física e integração ao onboarding
**Data:** 12/11/2026
**Branch:** `work/oficina24h-b4-orientacao-ordens-2026-11-12`
**Base:** `work/oficina24h-b3a-hud-estabilidade-2026-11-12`
**Estado:** desenvolvimento por GitHub e revisão estática. **Sem executar Roblox Studio, ferramentas Rojo, multiplayer ou celular físico.**

## Objetivo de UX
O jogador não deve precisar adivinhar onde ocorre a ação da OS e nem concluir um reparo através de um painel abstrato. A B3a resolveu o dock mobile; a B4 usa o snapshot público para orientar o jogador até o **local e equipamento** reais, sem autorização remota de serviços.

## Fluxo implementado
| Situação | Cartão na HUD | Destino |
|---|---|---|
| Oficina não registrada | Abrir sua oficina | Ordens |
| Cliente disponível | Cliente aguardando | TV de ordens |
| Cliente consumiu 75%+ da paciência | Cliente impaciente | TV de ordens |
| OS ativa sem diagnóstico | Diagnosticar | Veículo |
| Falta peça para OS diagnosticada | Faltam peças | Loja de Autopeças |
| Pneu/bateria/arrefecimento sem preparo | Preparar veículo | Pontos do carro |
| Reparação exige equipamento especial | Usar equipamento | Máquina da oficina |
| Reparação com ferramenta manual | Executar reparo | Veículo |
| OS delegada a contratado | Serviço delegado | Painel de Ordens |
| Contrato aceito em oficina parceira | Trabalho contratado | Veículo (se replicado; senão Ordens) |
| Sem clientes | Oficina disponível | Ordens |

## Código criado/alterado
- `src/shared/ServiceFocusRules.lua`: regras puras, prioridade determinística para múltiplas ordens, limiar de paciência, ausência de peças, preparação e equipamento. Não revela DefectId ao cliente.
- `src/client/UI/CompactHUD.lua`: cartão e cor de destaque consomem as mesmas regras.
- `src/client/UI/HUD.lua`: ao ativar o objetivo, desenha orientação visual para loja, carro ou equipamento conhecido. Quando o alvo não está carregado, abre Ordens.
- `src/client/UI/Stations.lua`: métodos locais para localizar o modelo de veículo por JobId e equipamento instalado na oficina; `GuideTo` reaproveita a linha visual já presente no projeto.
- `src/client/UI/Panels/Orders.lua`: o botão de tentar `CompleteJob`/diagnosticar pelo painel foi substituído por **ir ao veículo/loja/máquina**, evitando a mensagem de erro causada pela distância. A mesma regra gera estado e destino da OS. A delegação é informativa e não permite conclusão instantânea.
- `src/client/UI/Onboarding.lua`: inclui preparação física como etapa explícita do tutorial.
- `tools/ServiceFocusTest.luau`: **30 checks escritos** para prioridade, urgência, autorização visual, estoque, preparo e equipamentos; conectado a `RunAllTests`.

## Regras de segurança e integridade
- Nenhuma ação de reparo, diagnóstico, pagamento ou compra passa a ser realizada pelo clique de orientação. O botão só indica onde o jogador deve ir, e o **servidor permanece responsável** por validar OS, distância, ferramentas, peças e dinheiro.
- Não foi modificado DataStore, preços, XP, reputação ou inventário.
- Alvos na interface só são buscados localmente a partir de modelos já replicados; com StreamingEnabled podem estar indisponíveis, caso em que se abre Ordens.
- Defeito e partes exigidas continuam ocultos até que o diagnóstico seja confirmado pelo servidor.

## Testes obrigatórios de aceitação (ainda não executados)
- [ ] Executar todas as suítes em `ServerStorage.Tools.RunAllTests` e confirmar zero FAIL/ERRO/AUSENTE.
- [ ] Jogador novo: cadastrar oficina, aguardar cliente, aceitar na TV, conversar e diagnosticar no carro.
- [ ] Pneu diagnosticado: objetivo muda para preparo; guia aponta carro; concluir porcas + apoio, abrir reparo físico e receber pagamento somente no fim.
- [ ] Bateria e arrefecimento: testar pontos físicos e equipamento dedicado quando aplicável.
- [ ] Estoque insuficiente: objetivo leva à loja física, sem permitir comprar à distância.
- [ ] Fila com dois clientes: selecionar maior proporção de tempo de espera/paciência (desempate por ID).
- [ ] Cliente impaciente: mensagem visual correta sem reduzir o tempo de paciência.
- [ ] Jogador A delega serviço a B: HUD de A não manda realizar reparo, B continua com acesso autorizado pelo servidor.
- [ ] Painel de Ordens: nenhuma ação técnica feita de longe; botão guia ao veículo/estação e fecha o painel sem deixar escurecimento.
- [ ] StreamingEnabled: carro/máquina não replicados, nenhuma exceção no cliente, fallback para Ordens.
- [ ] Testar 320×568, 390×844, 844×390, 1366×768 e 1920×1080 com touch, mouse e gamepad; observar sobreposições e controles nativos.
- [ ] Multijogador, reconexão, abandono/expiração da OS e alterações de snapshot durante a animação da orientação.

## Portões
**PR draft:** não mesclar com `main` antes de validar os PRs empilhados e homologar no Studio. Os 30 testes são **fontes escritas**, não execução confirmada.
