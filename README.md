# RFindUnit - Fork do RFindUnit Original

> **Fork do projeto [RFindUnit](https://github.com/rfrezino/RFindUnit) de Rodrigo Farias Rezino**, com correções de bugs, novas funcionalidades e reestruturação do código.

O RFindUnit é um plugin para o IDE Delphi que substitui a funcionalidade nativa "Find Unit" (Ctrl+Shift+A), que é conhecida por ser lenta e instável.

**Repositório original:** https://github.com/rfrezino/RFindUnit

**Fork ativo:** https://github.com/Rtrevisan20/RFindUnit

---

## Funcionalidades

| Atalho           | Função        | Descrição                                    |
| ---------------- | ------------- | -------------------------------------------- |
| **Ctrl+Shift+A** | Find Unit     | Busca inteligente de units para importação   |
| **Ctrl+Shift+U** | Organize Uses | Ordena e organiza a cláusula uses            |
| **Ctrl+Shift+L** | Unused Uses   | Detecta units não utilizadas no código       |
| **Ctrl+Space**   | Auto Import   | Importa units automaticamente (configurável) |

### Find Unit (Ctrl+Shift+A)

Busca inteligente de units com suporte a namespaces fully qualified e ResourceString. Encontra as Units instaladas com o gerenciador de dependências o [Boss](https://github.com/HashLoad/boss).

![Find Unit](https://github.com/Rtrevisan20/RFindUnit/blob/master/Resources/RFindUnitImage.png)

### Organize Uses (Ctrl+Shift+U)

Ordena e organiza a cláusula uses com várias opções:

- Ordenação alfabética (padrão)
- Ordenação por nível (RTL → VCL → FMX → Third-party → Project)
- Agrupamento por namespace
- Quebra de linha configurável
- Preserva comentários no bloco uses

![Organize Uses](https://github.com/Rtrevisan20/RFindUnit/blob/master/Resources/organizeAfter.png)

### Unused Uses (Ctrl+Shift+L)

Detecta e destaca units que estão no bloco uses mas não são utilizadas no código.

A detecção usa um índice de element names em memória (lookup O(1)) e o resultado é pintado no editor com código de cores:

| Cor | Significado |
|---|---|
| Laranja | Unit indexada e não utilizada no código |
| Cinza | Unit não indexada mas com `.dcu`/`.pas` no disco (ex: `ToolsAPI`, RTL/VCL fora do índice) |
| Azul claro | Unit distribuída apenas via `.dcp` da IDE (ex: `DockForm`, `DeskUtil`) |

O check no gutter (unit sem uses não utilizadas) é renderizado com **SVG** (componente [SVG-Ekot](https://github.com/EKot/SVG)), com cor que acompanha o tema da IDE (claro/escuro) automaticamente.

![Unused Uses](https://github.com/Rtrevisan20/RFindUnit/blob/master/Resources/CheckedAndNotOk.png)

### Auto Import (Ctrl+Space)

Importa units automaticamente quando o código referencia classes/procedimentos de units não importadas. Pode ser habilitado/desabilitado nas configurações.

### Internacionalização (i18n)

Suporte a múltiplos idiomas (PT-BR / EN) com tradução dinâmica de todas as mensagens da interface.

---

## Bugs Corrigidos (neste fork)

| Bug                                 | Severidade  | Descrição                                                                         |
| ----------------------------------- | ----------- | --------------------------------------------------------------------------------- |
| #76                                 | **Crítica** | Organize Uses destruía a cláusula uses (race condition + posições desatualizadas) |
| #73                                 | **Alta**    | Consumo excessivo de CPU (re-parse frequente + threads desnecessárias)            |
| #80                                 | Média       | Não encontrava ResourceString/Constants no parser                                 |
| #72                                 | Média       | Namespaces não eram fully qualified na busca                                      |
| Ctrl+Shift+L sem resultado          | **Alta**    | LoadProjectPath nunca era chamado na inicialização                                |
| Ctrl+Shift+L só analisava interface | Média       | Bloco implementation era ignorado no Unused Uses                                  |
| Ctrl+Shift+U corrompia classes      | **Alta**    | Posições stale inseria tokens dentro de declarações de classe                     |
| Ctrl+Shift+U linhas em branco       | Média       | Removia/adicionava linhas em branco incorretamente                                |
| Import com comments                 | Média       | Units comentadas no uses não eram importadas/descomentadas                        |
| Acentuação PT-BR                    | Baixa       | Strings com caracteres corrompidos (encoding sem BOM)                             |

---

## Desempenho

O **Unused Uses (Ctrl+Shift+L)** foi otimizado com um índice de elementos em memória, reduzindo drasticamente o tempo de análise:

| Fase | Tempo por unit |
|---|---|
| Antes das otimizações | ~14.000 ms (pior caso) |
| Após as otimizações | **1–58 ms** (média ~13 ms) |

**Melhoria de ~1.000x** no pior caso.

### Otimizações aplicadas

- **Índice de element names em memória** — lookup O(1), substituindo a varredura de todas as units indexadas por palavra buscada
- **Cache de parsing** — arquivos não modificados não são re-parseados (threshold de 1s)
- **Fallback pattern-based** — tipos, variáveis e valores de enum que o parser não extrai são detectados por varredura do código real (comentários/strings ignorados)
- **Detecção de dependências implícitas** — drivers FireDAC (ex: `FireDAC.Phys.PG` via `*Def`), infraestrutura de forms (FMX/FireDAC/Data.Bind por namespace), helpers
- **Guard de escopo de projeto** — arquivos fora do projeto/biblioteca indexados não geram falsos "unused"
- **Pintura em 3 cores** — units não indexadas são distinguidas (cinza/azul) das realmente não utilizadas (laranja)
- **Ícones SVG no gutter** — check e ampulheta renderizados via SVG-Ekot, com cor adaptada ao tema da IDE

### Métricas atuais (97 units analisadas)

| Métrica | Valor |
|---|---|
| Média por unit | 12,9 ms |
| Mediana | 9 ms |
| Min / Max | 1 ms / 58 ms |

---

## Estrutura do Projeto

O projeto segue arquitetura **MVC** com prefixo **HD** nas units:

```
src/
  Model/          - Lógica de negócio (20 units)
  View/           - Interface do usuário (4 units + 3 dfm)
  Controller/     - Controle e orquestração (5 units)
  Utils/          - Funções auxiliares (1 unit)
```

---

## Instalação

**Requisito:** Delphi Berlin ou superior (Tokyo testado)

1. Baixe o [repositório](https://github.com/Rtrevisan20/RFindUnit/archive/main.zip) ou clone:
   ```
   git clone https://github.com/Rtrevisan20/RFindUnit.git
   ```
2. Abra `Packages/DelphiTokyo/RFindUnit.dproj` no Delphi
3. Clique com o botão direito no projeto → **Install**

---

## Projetos Referenciados

- [DelphiAST](https://github.com/RomanYankovsky/DelphiAST) — Parser de código Delphi
- [Log4Pascal](https://github.com/martinusso/log4pascal) — Sistema de logging
- [DCU32INT](https://github.com/rfrezino/DCU32INT) — Descompilador DCU
- [SVG-Ekot](https://github.com/EKot/SVG) — Renderização de ícones SVG (units renomeadas com prefixo `RFU` para evitar conflito de packages)

---

## Contato

**Fork mantido por:** Rtrevisan20
**Autor original:** Rodrigo Farias Rezino — rodrigofrezino@gmail.com

---

## Licença

MIT License — Veja o arquivo [LICENSE](LICENSE) para detalhes.
