# Oficina 24H — Roteiro de homologação da integração A1/A2
**Data:** 12/11/2026  
**Branch consolidada:** `work/oficina24h-integracao-a1-a2-2026-11-12`  
**Base:** main `3988cb2a34776c3513cb6106cede81cce107cbb5`  
**Status:** código enviado ao GitHub; **nenhuma validação em Studio ou celular executada nesta rodada**.

## 1. Sincronizar a branch consolidada

1. Salvar o place de testes e fazer backup do `.rbxl` antes de sincronizar.
2. No repositório local do Oficina24H: `git fetch origin` e `git checkout work/oficina24h-integracao-a1-a2-2026-11-12`.
3. Execute `rokit install` se faltar Rojo e `rojo serve default.project.json`.
4. Conecte o Rojo ao Roblox Studio e confira que os scripts novos aparecem em `ReplicatedStorage.Shared`, `ServerScriptService.Server`, `StarterPlayerScripts.Client` e `ServerStorage.Tools`.
5. Os carros/NPCs armazenados em `ServerStorage/Assets` permanecem no place local, não no GitHub. **Não publique antes de verificar licenças de sprites/ícones.**

## 2. Testes unitários/regressão (Studio Edit)

Rodar `ServerStorage.Tools.RunAllTests` com o fluxo já usado no projeto. Suítes novas:

- `LocationTest`: 11 testes.
- `RivalRulesTest`: 10 testes.
- `DiagnosisEvidenceTest`: 15 testes.
- `RepairOperationsTest`: 17 testes.
- `RepairSessionTest`: 10 testes.

**Total: 63 novos checks escritos, ainda não executados.** As suítes anteriores devem continuar passando. A contagem antiga do README não representa a quantidade atual.

## 3. Teste de jogabilidade solo (Play)

- Iniciar personagem novo com oficina nível 0, cliente NPC e estoque inicial.
- Conversar e abrir diagnóstico; testar painel sem examinar e tentativa de selecionar defeito de pneu/bateria.
- Aproxime-se do carro; execute **Pressão do pneu** e observe laudo.
- Concluir diagnóstico; abrir reparo de pneu: selecionar localização do furo, ajustar pressão, concluir. Conferir saldo, estoque de `TirePatch`, XP, avaliação e estado de veículo.
- Repetir para bateria: exame de tensão, escolher ordem dos terminais, concluir; conferir consumo de uma `Battery`.
- Progredir para motor `Overheating`, fazer exame de temperatura, ajuste de fluido, ciclos de sangria e ventoinha; conferir `Coolant`.
- Testar serviço de funilaria/suspensão para confirmar que o minijogo legado continua funcionando.
- Abrir loja/estoque e diagnóstico juntos: não deve escurecer jogo; botões e HUD responsivos.

## 4. Segurança e fluxo inválido (local multiplayer)

- Um jogador tenta examinar ou diagnosticar OS de outra oficina: o servidor deve negar.
- Testar comando `ExamineJob` sem conversa, longe do veículo e com `ExamId` desconhecido.
- Repetir `FinishRepair` depois da conclusão: não pode dar moeda, XP ou consumo extra.
- Iniciar outro reparo enquanto sessão anterior está ativa: negar e manter primeiro reparo intacto.
- Expirar uma sessão, abandonar ordem ou cancelar: carro e elevador devem retornar ao estado correto.
- Remover o edifício `LojaAutopecas` e tentar comprar, e remover `DistribuidoraEquipamentos` para tentar upgrade. **O teste da ausência do prédio precisa ser realizado num place publicado de homologação, pois no Studio existe exceção QA autorizada.**
- Verificar rival NPC sem baia livre, falha de spawn e evicção durante serviço: sem incremento de dinheiro, avaliação ou reputação.
- Testar 2 clientes locais, latência simulada, saída e reconexão; depois 2 jogadores reais e DataStore em homologação publicada.

## 5. Interface e performance

- Testar PC, smartphone real em retrato e paisagem, além de gamepad se possível.
- Confirmar que o painel de exames e o de operações não cortam botões nem ocultam permanentemente a cena.
- Verificar estado de prompts e câmera perto da oficina e de equipamentos.
- Observar desempenho com rivais e múltiplos veículos simultâneos.

## 6. Portões de aprovação

- [ ] Testes Luau executados e sem falhas.
- [ ] Ciclos de pneu, bateria e arrefecimento demonstrados sem erros em Play.
- [ ] Cinco áreas jogáveis preservadas.
- [ ] Nenhum exploit de duplicação/ownership observado nos cenários do roteiro.
- [ ] 2 jogadores reais e DataStore publicado testados.
- [ ] Celular real testado.
- [ ] Desempenho medido.
- [ ] Licenças de assets verificadas.

**Não mesclar a branch consolidada na main antes de passar os testes de integração relevantes.**

## 7. Dependências de PR

- #3: correção de rivais e locais físicos.
- #4: diagnóstico com evidência.
- #5: reparos-piloto — base #4.
- #6: estado de sessões — base #5.
- PR consolidado: reúne os arquivos dos quatro PRs de código para permitir sincronização e avaliação de **uma branch**. É a referência de homologação; não mesclar individualmente os outros PRs junto com o consolidado sem reconciliar/fechar duplicatas.
