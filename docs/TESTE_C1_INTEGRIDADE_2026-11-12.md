# C1 — Integridade para operação contínua

**Branch:** `work/oficina24h-c1-integridade-producao-2026-11-12`  
**Data:** 12/11/2026  
**Base:** `work/oficina24h-b4-orientacao-ordens-2026-11-12`

## Falhas corrigidas

1. **Ordem órfã ao sair:** `WorkshopService.PlayerLeft` removia carros e cliente, mas mantinha `Jobs[jobId]` em andamento convertido para "Available". Ao reconectar, o dono podia reencontrar uma ordem sem cliente. Agora o proprietário encerra/cancela as próprias ordens no servidor e os registros são eliminados. Se existir contratado, seus atributos de trabalho/sessão são limpos e ele recebe aviso.
2. **Carro sem modelo:** uma OS podia ser criada com `VehicleName` que não existia em `ServerStorage.Assets.Veiculos`. Agora `JobLifecycleRules.SelectVehicle` restringe à lista realmente carregável, preservando freguês cujo modelo existe e escolhendo fallback disponível.
3. **Panfletos sem cliente:** a publicidade cobrava antes de confirmar a criação da OS. Agora somente cobra quando um carro válido pôde ser selecionado. Se nenhum modelo estiver disponível, exibe erro útil.
4. **VIP de indicação:** flag de indicação pendente não é consumida antes de criar a ordem.
5. **Mercado:** falha ao gerar OS por falta de asset conta como atendimento perdido, não sucesso fictício.

## Automação de integridade
- `tools/check_repo_contracts.py`: analisador estático sem bibliotecas externas que confere caminhos de módulos Luau, nomes de `RunAllTests` e árvore do `default.project.json`.
- `.github/workflows/contracts.yml`: dispara verificação estrutural a cada PR/push de branch, quando GitHub Actions estiver habilitado.
- `tools/JobLifecycleTest.luau`: 11 casos de regra (modelos ausentes, seleção e saída de proprietário).
- Suíte registrada em `tools/RunAllTests.luau`.

## Homologação necessária
- [ ] GitHub Actions deve ficar verde após abertura do PR. **Verificação estática ≠ compilação nem jogo rodando.**
- [ ] Executar `RunAllTests` com Rojo/Studio; confirmar zero `FAIL`/`ERRO`.
- [ ] Remover temporariamente um modelo de carro no Studio e pedir cliente. Não cobrar panfletos quando não há nenhum veículo válido.
- [ ] Freguês com veículo retirado do servidor deve usar fallback de carro disponível.
- [ ] Sair durante OS com carro no box, reconectar imediatamente e verificar ausência de ordem fantasma e vaga corretamente liberada.
- [ ] Sair durante serviço delegado; colaborador deve receber cancelamento e não receber moedas/XP pela OS.
- [ ] Testar chamados do mercado com veículos indisponíveis; nenhuma ordem fantasma.
- [ ] Testar preço, saldos, salvamento, desconexão e gameplay completo.

**Limitação:** a validação de modelos depende dos assets reais do place. Estes assets não estão versionados no GitHub. Não foi executada sessão no Studio nesta rodada.
