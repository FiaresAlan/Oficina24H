# V1 C31 / G1 — Auditoria de estrutura dos modelos no Roblox Studio

Data: 13/11/2026. Fonte: Checklist Mestre V1 Issue #15. **Validacao automatizada escrita; testes Luau e assets reais ainda nao executados**.

## Mudancas
A `StudioPlaceAudit` chama `AssetIntegrityRules` para verificar todos os 21 modelos de carro do catalogo: existencia de `Model`, `PrimaryPart = Raiz` ancorada, `Casco` com colisao, atributos `Largura`, `Comprimento`, `Altura` e `Motorista`, partes extras que nao acompanham a raiz, juntas rigidas e sockets `OficinaSocket_*`. Ausencia de sockets nativos e apenas WARN: o jogo tem offsets de fallback.

Clientes passam a exigir `Humanoid`, rig R15, `HumanoidRootPart` como `PrimaryPart`, `Genero M/F` e cobertura dos dois generos. Os 11 equipamentos `Eq_*` sao auditados quando importados; os ausentes mantem o fallback procedural documentado. A auditoria de scripts embutidos da C3 e preservada.

## Roteiro de homologacao
- [ ] Abrir backup do place original, sem executar construtores destrutivos do bairro.
- [ ] Importar os cinco pacotes organizados em `ServerStorage.Assets` conforme `GUIA_UNICO_ASSETS_V1.md`.
- [ ] Executar `RunAllTests` no Studio Edit; conferir `AssetSafetyRulesTest`, `AssetIntegrityRulesTest` e `StudioPlaceAudit`.
- [ ] Corrigir cada FAIL de nome, estrutura, pivô, colisao, dimensoes, rig, genero e script embutido. Registrar resultados e screenshots.
- [ ] Conferir visualmente frente/altura de cada carro, posicao dos sockets no modelo real, traçado das rodas e cliente sentado, shaders, audio e autoria/licencas.
- [ ] Executar pelo menos uma chegada e saida com carro real. Somente apos G1 comprovado iniciar homologacao G2.

## Limites
`StudioPlaceAudit` nao pode comprovar licencas, direitos autorais, fidelidade visual, posicao real dos attachments, comportamento em multiplayer ou FPS. A auditoria e de leitura: nao reescreve modelos nem substitui o mapa. A V1 continua com G1–G5 abertos; V2 somente documentada.
