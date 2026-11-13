# V1 C30 / G1 — Sanitizacao de scripts em modelos importados

Data: 13/11/2026. Fonte: Checklist Mestre V1, Issue #15. Implementacao de defesa preventiva; **nao homologa a importacao**.

## Objetivo
Assets de terceiros guardados em `ServerStorage.Assets` podem conter `Script`, `LocalScript` e `ModuleScript`. Quando clonados e inseridos no `Workspace`, alguns scripts passam a executar com permissoes do jogo. A C30 remove esses descendentes **somente das copias** antes da publicacao no mundo ou em `ReplicatedStorage`, sem alterar os templates originais.

Pontos protegidos:
- `CustomerArrivalService.BuildCar`: carros.
- `NpcKit.Clone`: clientes.
- `EquipmentModels.Build`: equipamentos 3D importados.
- `VehicleService.PublishPreviews`: miniaturas de carros.

A regra compartilhada `AssetSafetyRules.StripScripts` elimina os tres tipos inclusive quando aninhados, preservando geometria. O teste `AssetSafetyRulesTest` usa modelos artificiais em memoria, sem tocar no mapa nem no DataStore.

## Evidencias e testes obrigatorios
- [ ] Executar `RunAllTests` no Roblox Studio Edit e registrar a saida da suite `AssetSafetyRulesTest`.
- [ ] Executar `StudioPlaceAudit` apos importar os assets; os scripts ainda presentes nos templates devem gerar falha e ser **removidos na origem**, nao apenas nos clones.
- [ ] Conferir no Explorer que carros, NPCs e equipamentos aparecem no jogo sem scripts extras e sem quebrar animacoes legitimas.
- [ ] Inspecionar manualmente `ServerStorage.Assets.Cenario` e os scripts de montagem antes de copiar modelos para o Workspace. A protecao C30 nao cobre modelos inseridos manualmente no mapa nem arquivos externos executados durante importacao.
- [ ] Validar as permissoes de audio e licencas de cada pacote. Nenhum gate G1–G5 esta homologado por este commit.

## Limites
A sanitizacao no tempo de clone e uma **segunda barreira**; nao substitui revisao dos assets no Studio ou a remocao de codigo suspeito dos arquivos originais. Build Rojo/contratos estaticos nao substituem execucao de testes Luau e gameplay.
