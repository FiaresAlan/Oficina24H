# Oficina 24H — Qualidade de produto final e portões de lançamento

**Branch:** `work/oficina24h-c3-gates-qualidade-2026-11-12`  
**Base:** `work/oficina24h-c2-procedimentos-15-servicos-2026-11-12`  
**Estado:** somente código e documentação GitHub; sem execução no Studio nesta rodada.

## O que já existe no código
- 15 defeitos de 5 especializações; diagnóstico com 9 exames e validação de evidência relevante.
- 15 procedimentos de reparo (3 pilotos e 12 receitas com quatro famílias).
- NPCs, concorrentes, oficina física, estoque, economia, contratos com profissionais, progressão e reputação herdados do projeto anterior.
- HUD v2 com etapas de trabalho, navegação responsiva, orientação ao carro e painel de ordens contextual.
- Regras de pagamento/qualidade no servidor; placeholders de componentes e sockets por modelo.

**Isto não é homologação de produto final.** Os scripts e o place podem divergir e há assets fora do repositório, sem CI/teste de Roblox Studio nesta sessão.

## Portões de qualidade executáveis

`tools/RunAllTests.luau` foi fortalecido:
- Cada suite ausente, erro de execução, exceção de `require` e suíte sem verificações conta como **falha** (antes algumas exceções acabavam como 0 falhas).
- Resumo global com aprovações, falhas e avisos; bloqueios destacados no início.
- Mantém isolamento de cache de `Shared` e execução do runner no modo Edit do Studio.

`tools/StudioPlaceAudit.luau` adiciona verificações:
- `ReplicatedStorage.Shared`, scripts do servidor e suíte de testes existentes.
- `Workspace.Plots`, loja de autopeças e construtora reais.
- `ServerStorage.Assets.Veiculos` e `ServerStorage.Assets.Clientes` presentes.
- Cada nome de veículo do catálogo resolve para um `Model` com `PrimaryPart`.
- Ao menos um NPC com Humanoid e PrimaryPart.
- Sem scripts embutidos nos assets importados.
- 15 defeitos com evidências e operação.
- Avisos de licenças, multiplayer, celular real e performance que exigem trabalho humano/Studio.

## Como rodar (após sincronizar)
1. Salvar backup do place de homologação; não substituir o local publicado de produção.
2. `git fetch origin` e `git checkout work/oficina24h-c3-gates-qualidade-2026-11-12`.
3. `rokit install`, `rojo serve default.project.json`, conectar Rojo ao Roblox Studio.
4. Certificar-se de que os assets do place continuam em `ServerStorage.Assets`; arquivos 3D não estão versionados no GitHub.
5. Rodar `ServerStorage.Tools.RunAllTests` no modo Edit, copiar resultado completo.
6. Corrigir qualquer `REPROVADO`, `FAIL`, `ERRO` ou `AUSENTE`.
7. Tratar cada `WARN` — licenças e performance não são cobertas por testes puros.
8. Fazer um atendimento completo de cada tipo (15) em PC e celular; testar um contratado em 2 clientes e DataStore publicado em servidor privado.

## Portões adicionais de PRODUTO FINAL (não substituíveis por testes unitários)
- [ ] **Diversão comprovada**: 20–30 pessoas testam 30 minutos de oficina; observar repetição, retenção voluntária e fricções, sem métricas abusivas.
- [ ] **Arte final**: modelos de carro e ferramentas PBR, materiais, ajustes reais dos sockets por veículo e animação de ferramenta/mão em 3ª pessoa.
- [ ] **Som**: áudio de chegada, diagnóstico, ferramenta, compressor, motor, fricção e avaliações, com licenças.
- [ ] **Mundo vivo**: NPCs com reações, variação de carros/defeitos, lojas e rua com ambientação crível.
- [ ] **Confiabilidade**: DataStore publicado, idempotência de pagamentos, reconexão, contratos, latência e escalabilidade.
- [ ] **Plataformas**: PC, touch real e gamepad sem sobreposição, tela cortada ou inputs ambíguos.
- [ ] **Performance**: FPS, memória, número de veículos, texturas, NPCs e streaming medidos com orçamento do dispositivo alvo.
- [ ] **Políticas e licenças**: créditos CC BY de carros e autoria de sprites/ícones confirmada antes de publicação.
- [ ] **Publicação**: checklist de privacidade, classificação indicativa, economia/monetização, políticas Roblox e QA final.

## Prioridade depois desta fase
1. Homologar os 15 fluxos em um Studio conectado (bloqueio instrumental aqui).
2. Importar/adaptar um veículo vertical (capô, roda, bateria, radiador) com 9 sockets inspecionáveis + cinco sockets de ferramenta; documentar cada modelo.
3. Substituir props provisórios por ferramenta/peça 3D real e adicionar áudio licenciado.
4. Realizar sessões com humanos e ajustar qualidade das quatro famílias, controle de tempo e recompensas.
5. Só então consolidar o enorme stack de PRs na `main` e seguir para expansões/tuning/mundos adicionais.

**Não se deve marcar o lançamento como pronto apenas porque foram escritos 15 planos ou 200+ testes.** O objetivo é uma experiência consistente, completa e divertida nos dispositivos reais.
