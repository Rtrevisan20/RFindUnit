# Painter — camada de abstração de pintura (tarefas 1.1–1.4)

> Documentação em pt-BR (regra do `AGENTS.md`). Código-fonte comentado em inglês.

## 1. Propósito

O port DelphiSVG → Delphi + Lazarus usa uma camada de pintura independente de
plataforma (`TPainter`) com dois backends:

```
                    TSVG (SVG.pas) — árvore + parsing (portável)
                                  |
                               TPainter (base, portável)
                    /                        \
      TPainterGdiPlus                   TPainterLCL
  (Delphi 12.2 + FPC/Lazarus)      (FPC/Lazarus, TCanvas)
```

- **Delphi** usa `TPainterGdiPlus` (fidelidade ao comportamento atual do GDI+).
- **Lazarus/FPC** usa `TPainterGdiPlus` no Windows (idem) ou `TPainterLCL` nas
  demais plataformas (e também é verificável no Windows).

## 2. Contrato `TPainter` (Painter.pas)

- 100% portátil: `{$IFDEF FPC}{$MODE Delphi}{$ENDIF}` + `uses` IFDEF
  (`System.Classes`/`System.SysUtils` no Delphi, `Classes`/`SysUtils` no FPC).
- **Cor**: `TPainterColor = Cardinal` em **0xAARRGGBB** (mesmo layout do núcleo).
- **Estado**: `SetSmoothingMode`, `SetTransform`/`ResetTransform`/`GetTransform`,
  `SetClip`/`ResetClip`, `Clear`.
- **Recursos** (`TPainterObject` com "last status"): `TPainterPen`,
  `TPainterBrush` (`Solid`, `LinearGradient`, `RadialGradient`),
  `TPainterFontFamily`, `TPainterFont`, `TPainterImage` (load de stream),
  `TPainterPath` (apenas geometria: move/line/bezier/arc/rect/ellipse/polygon/
  string + Transform/Clone/Flatten/GetPointCount — **tesselação nos backends**),
  `TPainterTextFormat`.
- **Operações**: `DrawPath`, `DrawLine`, `DrawImage`, `DrawString`,
  `MeasureString`/`MeasureText`, `AddTextToPath`.
- Helpers portáveis: `TPainterMatrix`, `MatrixMultiply`, `MatrixTransformPoint`,
  `MakeIdentityMatrix`, `MakePoint`/`MakeRect`, `PainterColor(A,R,G,B)` etc.

### Convenções de implementação

- `TPainter` base **não tem** construtor via HDC; cada backend cria suas
  subclasses concretas (factories). Posse do `TGPGraphics`/`TCanvas` fica com
  quem cria.
- Construtores de recursos usam `reintroduce;` **sem** `virtual` (regra dos
  gotchas do Delphi 12.2 — ver `AGENTS.md` §3.5).
- Path: segmentos com **start implícito** (o ponto atual do path é o início):
  `pskMove` guarda 1 ponto; `pskLine` guarda 1 ponto (o fim); `pskBezier` guarda
  3 pontos de controle (o fim = último controle); `pskClose` não guarda dados.

## 3. `TPainterGdiPlus` (PainterGdiPlus.pas)

- Backend GDI+ de baixo nível (Delphi 12.2 compila limpo; branch FPC do `uses`
  já preparado — compilar no FPC depende da tarefa 3.5, port FPC de
  `GDIPAPI`/`GDIPOBJ`).
- Gotchas resolvidos do Delphi 12.2 documentados em `AGENTS.md` §3.5
  (`reintroduce`, `PSingle` via `Winapi.Windows`, qualificar `Painter.MakePoint`)
- Texto espelha o núcleo: `KerningText` (`AddToGraphics`/`MeasureText`/
  `AddToPath`), `TGPStringFormat(GenericTypographic)`,
  `StringFormatFlagsMeasureTrailingSpaces`.
- **Limitação conhecida (GDI+)**: gradiente radial com resultado idêntico ao
  núcleo atual do DelphiSVG (todo o gradiente radial atual depende do GDI+).

## 4. `TPainterLCL` (PainterLCL.pas) — FPC/LCL

- Implementa o contrato sobre `TCanvas` (Lazarus 4.8 / FPC 3.2.2).
- **100% cross-platform no LCL**: sem unit `Windows`; regiões vêm do `LCLIntf`
  (`CreatePolygonRgn`, `CreateRectRgn`, `CombineRgn`, `FillRgn`,
  `DeleteObject`, `GetRGNBox`, `SelectClipRgn`) e constantes do `LCLType`
  (`RGN_*`, `ALTERNATE`/`WINDING`, `NULLREGION`).
- **Tesselação**: bezier cúbico via `SubdivideBezier` (de Casteljau, `Level=4`);
  arcos virão em segmentos de linha aprox. 15° (`AddArc`); elipse = 4 beziers;
  retângulo/polígono = figuras fechadas.
- **Gradiente linear**: faixas paralelas ao eixo do gradiente, recortadas contra
  a região do path via `FillRgn` (GDI). Nº de faixas = `EnsureRange(Round(len),8,256)`.
- **Gradiente radial**: N=32 anéis concêntricos escalados (regiões), cor por
  anel via `ColorAt`; recorte final contra a região do path (`FillRgn`).
  *Não* suporta transformada radial arbitrária — aproximação por anéis.
- **Clip**: `SetClip` combina as figuras fechadas do path numa única região
  inteira (GDI). Sem suavização de clip (região é inteira).
- **Texto**: `TextOut`/`TextExtent` (fonte, estilo, cor via `Font.Color`).
  `AddString`/`AddTextBox` geram **boxes placeholder** (sem contornos de texto
  em path). `smoothing antialiasing` mapeia para `TCanvas.AntialiasingMode`
  (afeta texto ClearType; paths continuam inteiros → **sem AA de figuras**).
- **Imagem**: `StretchDraw`. Opções de opacidade do contrato **ignoradas**
  (limitação).

### Limitações resumidas do backend LCL (tarefa 1.3/1.4)

| Item | Situação |
|---|---|
| Preenchimento sólido/figuras fechadas | OK |
| Elipse / rect / polígono / polyline | OK |
| Bezier cúbico (fill+stroke) | OK (de Casteljau nível 4) |
| Gradiente linear | OK (faixas) |
| Gradiente radial | Aproximado (32 anéis; sem transform arbitrária) |
| Clip | Região inteira (sem suavização) |
| Antialiasing de figuras | Não (só texto, via `AntialiasingMode`) |
| Texto (draw/measure) | OK |
| Texto em path (AddString/AddTextBox) | Placeholder (boxes) |
| Imagem + opacidade | Draw SEM opacidade (StretchDraw) |
| `SetClip` encadeado com transformações | Região após `MatrixTransformPoint` |

## 5. Compilação e smoke test

FPC/Lazarus (painter):
```
fpc -Mdelphi -Fu"C:\lazarus\lcl\units\x86_64-win64" ^
     -Fu"C:\lazarus\lcl\units\x86_64-win64\win32" ^
     -Fu"C:\lazarus\components\lazutils\lib\x86_64-win64" PainterLCL.pas
```
Delphi (painter):
```
dcc32 -B -CC -U"..\painter;..\gdip" ..\painter\Painter.pas
dcc32 -B -CC -U"..\painter;..\gdip" ..\painter\PainterGdiPlus.pas
```
Smoke tests (fora do repo, em `%TEMP%\opencode\painter_smoke\`):
- `PainterSmoke.dpr` → `smoke.png` (baseline GDI+ Delphi).
- `lcl_smoke.pas` → `lcl_smoke.bmp` (FPG/LCL; inclui unit `interfaces`).
  Verificação por amostragem/pixel: rect sólido, gradientes linear+radial,
  elipse preenchida, ribbon bezier (stroke) e texto.

## 6. Limpeza de erros encontradas (tarefa 1.3)

1. **Convenção de path ambígua**: `FlattenPath` lia "start+end" mas retângulo/
   elipse gravavam só "end/controles" → polígonos degenerados cobrindo a tela
   inteira. Padronizado para **start implícito** (ver §2) em `AddLine`,
   `AddBezier`, `FlattenPath`.
2. **Gradientes corrompiam o canvas**: `SelectClipRgn` bruto + `SaveDC`/
   `RestoreDC` dessincronizavam o `TCanvas` LCL (desenhos posteriores
   "sumiam"). Substituído por **`LCLIntf.FillRgn`** com a região recortada
   (sem manipular clip do DC).
3. **`TBrush.Handle` deprecated** no LCL: usar `FCanvas.Brush.Reference.Handle`
   (cast p/ `HBRUSH`).
4. regra FPC: retornos inline de `array of X` → aliases tipados
   (`TPainterPointArray`, `TColorArray`, `TPositionArray`); `var A: array of X`
   não é redimensionável (usar tipo dinâmico nomeado).

*Nota: em 22/09/2026 a versão do Lazarus instalada é 4.8 (Lazarus 4.8/FPC 3.2.2);
quando o FPC pular para versões futuras, validar novamente os avisos de
depreciação (`Reference.Handle`).