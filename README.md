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

Busca inteligente de units com suporte a namespaces fully qualified e ResourceString.

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

---

## Contato

**Fork mantido por:** Rtrevisan20
**Autor original:** Rodrigo Farias Rezino — rodrigofrezino@gmail.com

---

## Licença

MIT License — Veja o arquivo [LICENSE](LICENSE) para detalhes.
