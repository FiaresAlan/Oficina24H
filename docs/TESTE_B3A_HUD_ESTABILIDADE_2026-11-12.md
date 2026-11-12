# B3a — Estabilidade da navegação touch e desktop
**Branch:** `work/oficina24h-b3a-hud-estabilidade-2026-11-12`  
**Base:** `work/oficina24h-b3-hud-ux-v2-2026-11-12`  
**Status:** código versionado, sem execução Roblox Studio.

## Diagnóstico
Na B3, `HudLayoutRules.Plan` comprimía seis botões do dock em telas de 320 px, dando alvos físicos próximos de 44 px. Além disso, a HUD usava contêiner `Frame` com tamanho automático; quando os botões não cabiam, podiam invadir os controles ou ser cortados.

## Alterações
- `HudLayoutRules.Plan` agora calcula `DockWidth`, `DockContentWidth` e `DockScrollable`. O tamanho mínimo dos itens lógicos foi ajustado para 62, aproximadamente 48 px físicos no piso de escala touch de 0,78.
- `HUD.lua` cria um `DockScroll` horizontal transparente dentro do cartão inferior, mantendo o conjunto de seis ações. O contêiner externo é limitado à largura da viewport e o conteúdo excedente pode ser rolado.
- A tela de 320 px permite percorrer as seis ações com scroll, em vez de forçar cada item a encolher. A tela de 390 px não requer scroll.
- `HudLayoutTest.luau` contém testes adicionais para alvos de toque, rolagem e limites de viewport; a suíte global existente mantém a mesma entrada.

## Testes de aceitação pendentes
- [ ] 320×568 e 390×844 em emulador e celular real: todos os seis botões acionáveis e legíveis, com swipe no dock quando necessário.
- [ ] 844×390 landscape e tablet: animações, painéis e aviso de avaliação sem sobreposição.
- [ ] Conectar gamepad e usar foco sem rolar acidentalmente a página.
- [ ] Repetir fluxo completo de cliente → OS → diagnóstico → preparação → reparo.
- [ ] Rodar `ServerStorage.Tools.RunAllTests` com o projeto Rojo sincronizado.
- [ ] Verificar que a largura do dock não excede safe area nem interfere nos botões padrão do Roblox.

**Não foram executados testes Luau, Studio ou dispositivo físico nesta rodada.** Não há mudança em DataStore, remotes, inventário, clientes ou economia.
