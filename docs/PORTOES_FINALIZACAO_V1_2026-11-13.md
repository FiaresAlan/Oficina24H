# Oficina 24H — Portões finais de homologação da V1

**Data-base:** 13/11/2026 · **Fonte detalhada:** [Checklist Mestre V1 — Issue #15](https://github.com/FiaresAlan/Oficina24H/issues/15). Este é um resumo dos critérios de conclusão, **não substitui** o histórico técnico C1–C31 ou os testes existentes.

## Quanto ainda falta?
A implementação de código dos sistemas principais (15 serviços, cliente/ordem, estoque, funcionário NPC, upgrade, contratos, progressão e persistência) está avançada. **Não há percentual de conclusão defensável** sem executar os jogos no place real: CI verde confirma build de código, não experiência visual, multiplayer ou dados reais.

A Issue #15 contém muitos checkboxes redundantes de testes e ideias opcionais. Não interpretar sua quantidade como número de fases obrigatórias ou como porcentagem do produto. Para autorizar o próximo marco, precisamos de **cinco portões de homologação**, todos ainda abertos.

| Portão | O que precisa estar comprovado | Responsável principal |
|---|---|---|
| G1 — Assets reais | Cinco pacotes já baixados: importar no Roblox Studio, configurar veículos/NPCs/equipamentos, verificar `PrimaryPart`, sockets, scripts embutidos, licenças e áudio | Proprietário no Studio; assistente corrige configuração/código documentáveis |
| G2 — Atendimento completo | Executar os **15 serviços** com carro físico: chegada, conversa, diagnóstico, equipamento, gesto, peças, nota, pagamento, saída e NPC real; executar `RunAllTests` e `StudioPlaceAudit` | Proprietário no Studio; assistente corrige bugs relatados |
| G3 — Multiplayer e persistência | Duas contas e dois servidores, divisão de remuneração, saída durante reparo, falhas de `GetAsync/UpdateAsync`, reconexão, idempotência; revisar riscos residuais de compensação, provas antigas e arquivos finitos | Homologação Studio/contas; engenharia analisa e corrige |
| G4 — UX e desempenho | Conferir HUD e minijogos em PC, 390×844, 320×568, 844×390 e gamepad; StreamingEnabled, FPS, memória, queda de rede, prompts e acessibilidade | Homologação em dispositivos; assistente corrige UI/código |
| G5 — Publicação segura | Revisão de direitos/licenças, segurança dos remotes, privacidade, feedbacks, economia, ausência de bloqueios P0; versão do place publicada em ambiente de teste e release decidido com evidências | Proprietário autoriza publicação após QA |

**Critério de término da V1:** os cinco portões estão confirmados por evidência de Studio e problemas bloqueadores corrigidos, ou limitações explicitamente aceitas com mitigação documentada. O checklist histórico **não** deve ter cada ideia opcional transformada em requisito de release.

### Ficam fora do bloqueio de MVP
Guincho, desmontagem modular de motor, cooperação simultânea para a mesma tarefa, restauração avançada, tuning/ECU, test-drive e expansão de mapa — validar como novas fases depois, não impedir o teste do núcleo da V1 por novas ideias. A direção V2 continua apenas documentada até autorização do proprietário.

### Preparação adicional de G1 (C30–C31)
A C30 sanitiza cópias de assets antes de inseri-las no mundo, e a C31 audita estruturas de modelos e NPCs. As verificações de CI passaram, mas não validam os modelos reais nem substituem a execução do Studio. Guias: [C30](TESTE_C30_SEGURANCA_ASSETS_V1_2026-11-13.md) e [C31](TESTE_C31_AUDITORIA_MODELOS_V1_2026-11-13.md). **G1 permanece aberto** até importação e conferência manual.

## Próximas ações práticas
1. Proprietário importa os pacotes já organizados no Studio e preserva backup da rua aprovada, conforme [guia único de assets](GUIA_UNICO_ASSETS_V1.md).
2. Executa as suítes Studio, começando por `RunAllTests`, `StudioPlaceAudit` e atendimento real de pneu/bateria; registra erro exato e prints/logs.
3. O desenvolvimento corrige as falhas encontradas, valida CI novamente e repete o ciclo para 15 serviços, multiplayer e aparelhos.
4. Só declarar concluída a V1 após a checagem formal de G1–G5. **Não há autorização de publicação presumida.**

### Rodada 1 de homologação no Studio (13/11/2026) — [relatório completo](HOMOLOGACAO_V1_2026-11-13.md)
Executado num **place de QA só com código** (paridade 144/144 com o repositório, carros/NPCs placeholders): `RunAllTests` **PASSOU (2014 OK, 0 falhas)**, os **15 serviços jogados ao vivo** pelos remotes do HUD (qualidade 100, sem pagamento duplo, sem carro órfão) e HUD medido em iPhone 14, Galaxy A06, 568×320 e Xbox. Corrigidos: gabaritos dos minijogos expostos ao cliente (P1), limites por segundo em `RepairAction`/snapshot, distância de estações sem a pasta `Estacoes`, letreiros dos pads sobrepostos, METAS cobrindo o guia, alvos de toque < 44 px e guia vazando em 568×320/1920×1080. **Nenhum portão está homologado no place original**, que não foi aberto nesta rodada. G2 e G4 estão aprovados no nível de código/simulador; G1, G3 e G5 dependem do place real, de duas contas e da autorização do proprietário (seção 8 do relatório).

**Rodada 2 (place original, 13/11):** `RunAllTests` 2029/0, auditoria 17/0 com os assets reais, 3 serviços reais OK e 59,9 fps no mapa real. Dois P1 corrigidos (`PrimaryPart` das 11 máquinas e funcionário NPC tomando a OS do dono). **G1 (estrutura) e G2 homologados no place original**; G3 (2 contas), G4 (aparelho físico), licenças e publicação seguem abertos. Ver o [relatório](HOMOLOGACAO_V1_2026-11-13.md).

**Estado anterior (C31):** G1–G5 ainda não homologados. Os assets estão baixados no computador, mas **não importados**; as novas suítes de Luau foram preparadas, **não executadas** no Studio. O checklist pode ter mais de 100 caixas abertas sem que sejam 100 fases sequenciais.
