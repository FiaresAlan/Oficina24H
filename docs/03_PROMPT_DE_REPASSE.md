# Prompt de repasse — Oficina 24H

Você está assumindo o desenvolvimento de um jogo Roblox chamado **Oficina 24H**. Leia integralmente `README.md`, `docs/01_VISAO_DO_JOGO.md` e `docs/02_ARQUITETURA_TECNICA.md` antes de alterar qualquer arquivo.

## Objetivo do produto

Criar um simulador social de oficinas mecânicas em um bairro compartilhado. Cada jogador desenvolve habilidades como mecânico e administra uma oficina. Clientes NPC chegam com reclamações; o jogador diagnostica o defeito, verifica se possui habilidade e equipamento, executa o serviço e recebe pagamento, reputação e XP.

O jogo precisa funcionar com poucos jogadores online, usando clientes NPC, mas deve ficar melhor com pessoas reais por meio de cooperação, contratação, visitas e competição comercial.

## Pilares inegociáveis

1. Mecânica: diagnóstico e reparo são o ciclo principal.
2. Progressão: habilidades pessoais e equipamentos da oficina liberam serviços.
3. Social: jogadores podem trabalhar juntos, contratar profissionais e competir comercialmente.
4. Crescimento funcional: expandir a oficina aumenta capacidade e serviços, não apenas aparência.
5. Segurança: o servidor controla dinheiro, XP, defeitos, requisitos e pagamentos.

## Regras de design

- Habilidades pertencem ao personagem e acompanham o jogador.
- Equipamentos pertencem à oficina.
- Serviço exige habilidade + equipamento; peças entram em uma etapa posterior.
- O profissional real recebe XP pelo trabalho executado mesmo em oficina alheia.
- O proprietário recebe a parcela acordada do serviço.
- NPC contratado é alternativa mais cara, previsível e não concede XP ao proprietário.
- O jogador pode recusar um cliente.
- O jogador pode executar etapas parciais legítimas e receber XP proporcional, quando isso for implementado.
- Funcionário pode sair sem perder suas habilidades.
- Ao abrir a própria oficina, leva a habilidade, não o patrimônio do antigo empregador.
- Competição deve ocorrer por preço, qualidade, rapidez, reputação, especialização, publicidade e contratação.

## Exclusões explícitas

Não implementar:
- roubo de entregas ou materiais;
- sabotagem de veículos;
- sabotagem de equipamentos;
- roubo de inventário ou patrimônio de outros jogadores;
- mecânicas de griefing que bloqueiem ou destruam o progresso de concorrentes.

Não reintroduzir essas mecânicas sem uma decisão explícita do proprietário do projeto.

## Escopo do primeiro vertical slice

- bairro compacto com quatro terrenos lógicos;
- uma oficina funcional;
- três veículos NPC;
- três defeitos ativos (o catálogo pode ter seis);
- três a cinco serviços;
- habilidades e requisitos;
- equipamentos necessários;
- ordens de serviço;
- diagnóstico;
- reparo e pagamento;
- XP e reputação;
- convite de um jogador para colaborar;
- NPC como alternativa operacional;
- teste com um e dois jogadores.

Não criar mapa gigante, dezenas de carros, estoque complexo, mercado global ou sistema completo de funcionários antes de validar o loop principal.

## Regras de execução

1. Inspecione o projeto e os arquivos antes de editar.
2. Preserve código funcional existente; não substitua sistemas inteiros sem justificar.
3. Trabalhe em incrementos pequenos e testáveis.
4. Use Luau com `--!strict` sempre que viável.
5. Mantenha validação e lógica econômica no servidor.
6. Nunca confie em valores enviados pelo cliente.
7. Não crie modelos, mapas ou UI provisórios que sejam tratados como arte final.
8. Se uma decisão de produto estiver ambígua, apresente a dúvida antes de implementar.
9. Não adicione escopo por iniciativa própria.
10. Ao concluir cada etapa, informe arquivos alterados, comportamento implementado, testes executados, limitações e próximo passo.

## Tarefa inicial

Faça uma auditoria do código-base deste pacote. Identifique:
- erros de sintaxe/API;
- problemas de segurança;
- lacunas no fluxo de ordem de serviço;
- problemas de persistência;
- dependências ausentes.

Não comece construindo o bairro. Primeiro deixe o vertical slice de dados e gameplay consistente. Em seguida, proponha uma sequência de implementação com entregas pequenas.
