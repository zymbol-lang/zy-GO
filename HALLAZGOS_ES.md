# Hallazgos del lenguaje — 囲碁 (zy-GO)

Bugs, carencias e ideas encontrados al construir 囲碁 sobre Zymbol **v0.0.8**.
Sigue la convención de [Serpiente](../serpiente/HALLAZGOS_ES.md) y
[Hov veS](../klingon_galaxy/hallazgos_es.md).

| ID | Tipo | Descripción | Estado |
|----|------|-------------|--------|
| [HLZ-001](#hlz-001--las-constantes-de-módulo-no-admiten-valores-negativos) | Gap | `CONST := -1` en un módulo es E013 | Rediseño de API |
| [HLZ-002](#hlz-002--el-analizador-infiere-float-en-aritmética-sobre-parámetros) | Bug | Índice de array calculado a partir de parámetros → «must be Int, got Float» | Workaround `##!` |
| [HLZ-003](#hlz-003--la-igualdad-es-estricta-con-tipos-pero-el-orden-no) | Bug | `##.0 == 0` es `#0` mientras `>= 0` y `<= 0` son ambos `#1` | Abierto |
| [HLZ-004](#hlz-004--check-y-el-lsp-rechazan-la-convención-de-punto-de-subcarpetas) | Bug | `# .核_盤` en `核/盤.zy` se ejecuta bien pero `zymbol check` y el LSP lo marcan E001 | Abierto |
| [HLZ-005](#hlz-005--ruta-de-import-relativa-al-padre) | Gap menor | `<# ./../x` no parsea; hay que escribir `<# ../x` | Documentar |
| [HLZ-006](#hlz-006--guidemd-documenta-mal-el-mapeo-de-las-flechas) | Bug (doc) | GUIDE.md §3b dice que las flechas son `'U' 'D' 'L' 'R'`; en realidad son `'↑' '↓' '←' '→'` | Abierto |
| [HLZ-007](#hlz-007--la-interpolación-solo-admite-identificadores) | Gap | `"{t.campo}"` y `"{arr[i]}"` no interpolan | Documentado |
| [HLZ-008](#hlz-008--la-vm-ignora-los-parámetros-de-salida-de-un-módulo) | **Bug grave** | En `--vm`, un `<~` de función de módulo no se escribe de vuelta: resultados silenciosamente incorrectos | Abierto |
| [IDEA-001](#idea-001--ancho-de-visualización-como-primitiva) | Idea | No hay forma directa de medir columnas de terminal de un string | Propuesta |
| [IDEA-002](#idea-002--el-coste-numérico-decide-la-arquitectura-de-la-ia) | Medición | Números que descartan MCTS y redes neuronales en Zymbol actual | Aplicada |

---

## HLZ-001 · Las constantes de módulo no admiten valores negativos

- **Archivo:** `核/盤.zy`
- **Descripción:** El cuerpo de un módulo solo acepta inicializadores literales.
  Un valor negativo se parsea como menos unario aplicado a un literal, es decir
  una **expresión**, y el analizador lo rechaza:

  ```zymbol
  # .核_盤 {
      禁_占有 := -1      // E013: constant initializer in module must be a literal
  }
  ```

  ```
  E013: constant initializer in module must be a literal
    help: module-level constants must use literal values, not expressions or function calls
  ```

- **Por qué importa:** los códigos de error negativos son el idioma habitual
  para «valor válido o código de fallo» en un mismo retorno. Sin negativos hay
  que buscar otro esquema.
- **Solución aplicada:** en vez de parchear con una función `_menos_uno()`, se
  rediseñó la API para no necesitar negativos. `盤::着手()` ahora devuelve un
  **estado** (`可`=0, `禁_占有`=1, `禁_自殺`=2) y entrega el punto de ko por
  **parámetro de salida**, en lugar de multiplexar ambas cosas en el retorno:

  ```zymbol
  着手(局面<~, 路, 起点, 色, 取数<~, コウ点<~)
  ```

  El resultado es mejor API que la original: un punto de ko es un índice del
  tablero, así que devolverlo colisionaba con los códigos de estado en todos
  los puntos del tablero.
- **Propuesta para el lenguaje:** aceptar un literal numérico con signo en el
  cuerpo de módulo. `-1` no es una expresión computada, es una constante.

---

## HLZ-002 · El analizador infiere Float en aritmética sobre parámetros

- **Archivo:** `核/盤.zy`, `試験/図.zy`
- **Descripción:** Indexar un array con una expresión aritmética construida a
  partir de parámetros de función falla en análisis semántico, aunque todos los
  operandos sean enteros en ejecución:

  ```zymbol
  # m1 {
      #> { a }
      a(arr, n, r, c) { <~ arr[(r - 1) * n + c] }
  }
  ```

  ```
  error: array index must be Int, got Float
  ```

  Sacar el cálculo a una variable intermedia **no** ayuda: la variable hereda la
  inferencia Float. Es un falso positivo: los parámetros no tienen tipo
  declarado y la aritmética mixta se infiere como Float por defecto.
- **Condición exacta de fallo:** expresión aritmética con al menos un parámetro
  de función sin tipo conocido, usada como índice de array.
- **Workaround:** el cast de truncado `##!` actúa como aserción de tipo. Envolver
  la expresión, o —mejor— envolver el retorno de la función que calcula índices:

  ```zymbol
  位置(路, 行, 列) { <~ ##!((行 - 1) * 路 + 列) }
  取得(局面, 路, 行, 列) { <~ 局面[位置(路, 行, 列)] }   // ✓ pasa el checker
  ```

  En 囲碁 **todo índice calculado pasa por `位置()`**, así el workaround queda
  confinado a una línea en lugar de repartirse por el motor.

---

## HLZ-003 · La igualdad es estricta con tipos pero el orden no

- **Descripción:** Un Float y un Int con el mismo valor no son iguales, pero sí
  son mutuamente `>=` y `<=`:

  ```zymbol
  a = ##.0
  >> (a == 0)    ¶   // → #0   ← falso
  >> (a == 0.0)  ¶   // → #1
  >> (a >= 0)    ¶   // → #1
  >> (a <= 0)    ¶   // → #1
  ```

  `a >= 0 && a <= 0` implica `a == 0` en cualquier lectura razonable del orden
  total; aquí no. Además ambos valores se **imprimen idénticos** (`0`), así que
  el fallo es invisible en pantalla: una aserción de test informa
  `expected 0, got 0`.
- **Por qué importa:** las puntuaciones de go son semienteras por el komi, así
  que son Float por naturaleza, mientras que los conteos de piedras y territorio
  son Int. Cualquier `puntuación == 0` (detección de 持碁, empate) responde
  silenciosamente que no.
- **Solución aplicada:** `核/計算.zy` fuerza **ambos** totales a Float
  (`##.(白石 + 白地) + ##.コミ`) para que el tipo de una puntuación no dependa
  del tipo del komi que pasó quien llama; y `勝色()`/`差分()` se escriben solo
  con `>`, nunca con `==`.
- **Propuesta:** o bien `==` coacciona numéricamente como hacen `<` y `>`, o
  bien `<`/`>` se vuelven estrictos también. La mezcla actual es la única
  combinación que no se puede razonar.

---

## HLZ-004 · `check` y el LSP rechazan la convención de punto de subcarpetas

- **Descripción:** `DOT_CONVENTION.md` establece que un módulo en subcarpeta se
  declara `# .carpeta_archivo`. El intérprete lo ejecuta correctamente, pero el
  servidor de lenguaje marca error en cada archivo del proyecto:

  ```
  E001: Module name '.核_盤' does not match file name '盤'
  help: The module name must match the filename (without .zy extension)
  ```

- **Condición exacta de fallo:** cualquier módulo en subcarpeta con la
  convención documentada. En 囲碁 son 11 de los 13 módulos.
- **Impacto:** ruido permanente en el editor; enmascara errores reales. Y algo
  peor: `zymbol check <archivo>` es inutilizable sobre esos módulos, porque el
  E001 sale como **error**, no como aviso.
- **Divergencia real:** `zymbol run` importa y ejecuta esos módulos sin
  problema; `zymbol check` y el LSP los rechazan. Los tres deberían coincidir.

  ```bash
  zymbol check 核/盤.zy      # error: E001 …
  zymbol run 試験/盤試験.zy  # PASS — importa 核/盤.zy y funciona
  ```

---

## HLZ-005 · Ruta de import relativa al padre

- **Descripción:** `<# ./../表示/文字 => 文` no parsea; hay que escribir
  `<# ../表示/文字 => 文`. El error tampoco lo explica:

  ```
  error: expected module path
  error: unexpected token: Slash
  ```

- **Impacto:** menor, pero `./..` es una forma habitual y el mensaje no orienta.
- **Relacionado:** importar la carpeta `言語/` requiere la ruta explícita
  `<# ./言語/module => 言`; `<# ./言語` da «module not found: 言語.zy». Es
  coherente con la convención documentada, pero merecería un `help:` que lo diga.

---

## HLZ-006 · GUIDE.md documenta mal el mapeo de las flechas

- **Descripción:** La tabla «Special keys are mapped to single-character
  symbols» de GUIDE.md §3b afirma que `<<|` devuelve `'U'`, `'D'`, `'L'`, `'R'`
  para las cuatro flechas. No es cierto: devuelve **los propios glifos de
  flecha**.

  ```zymbol
  >>| {
      @ i:1..4 {
          <<| k
          >>~ (i, 1) > "[" k "]  cp=" 0d|k|
      }
  }
  ```

  ```
  [↑]  cp=0d8593      // U+2191, no 'U'
  [↓]  cp=0d8595      // U+2193
  [←]  cp=0d8592      // U+2190
  [→]  cp=0d8594      // U+2192
  ```

- **Confirmación cruzada:** `serpiente/logica.zy:59-62` compara contra
  `'↑' '↓' '←' '→'` desde la v0.0.5. El código que funciona lleva razón; la
  documentación no.
- **Coste real:** el primer controlador de 囲碁 comparaba contra `'U'/'D'/'L'/'R'`
  siguiendo la guía. Compilaba, arrancaba y dibujaba bien — pero el cursor no se
  movía, y como la tecla caía en el caso `_` no había ningún error que leer. Solo
  apareció al ejecutar el juego bajo una pseudo-terminal e imprimir los códigos.
- **Efecto secundario en el diseño:** se documentó en el README que todos los
  comandos eran minúsculas «porque las mayúsculas U/D/L/R colisionarían con las
  flechas». Esa justificación era falsa y ya está corregida — no hay colisión
  posible, las flechas no son letras.
- **Propuesta:** corregir la tabla de GUIDE.md §3b. Es un bug de una sola tabla,
  pero manda a cualquiera que la lea a escribir un TUI que no responde.

---

## HLZ-007 · La interpolación solo admite identificadores

- **Descripción:** `"{x}"` interpola una variable, pero cualquier expresión
  dentro de las llaves es un error de lexer, no de tipos:

  ```zymbol
  >> "total: {結果.黒合計}" ¶   // ✗ invalid character in string interpolation
  >> "komi: {一覧[i]}" ¶        // ✗ ídem
  ```

  ```
  help: interpolation must be {identifier} — use \{ for a literal brace
  ```

- **Impacto:** cualquier valor compuesto hay que ligarlo a una variable local
  antes de poder convertirlo en texto. En `表示/描画.zy` eso son seis variables
  que solo existen para eso.
- **Nota:** el mensaje de error es claro y el `help:` dice exactamente qué se
  admite, así que el coste es verbosidad, no depuración. Se combina con el
  caveat ya conocido de que la yuxtaposición tampoco concatena dentro de los
  argumentos de una llamada — entre ambos, construir una cadena a partir de un
  campo obliga siempre a un paso intermedio.

---

## HLZ-008 · La VM ignora los parámetros de salida de un módulo

- **Descripción:** Una función de módulo con parámetro de salida `<~` no escribe
  de vuelta en la variable de quien llama cuando se ejecuta con `--vm`. No hay
  error: la ejecución continúa con los valores originales.

  ```zymbol
  // m.zy
  # m {
      #> { lleno, poner }
      lleno(n) {
          a = []
          @ i:1..n { a = a $+ 0 }
          <~ a
      }
      poner(a<~, i, v, cuenta<~) {
          cuenta = 0
          a[i] = v
          cuenta = 1
          <~ 0
      }
  }
  ```

  ```zymbol
  // t.zy
  <# ./m => m
  a = m::lleno(5)
  c = 0
  m::poner(a, 2, 7, c)
  >> "a[2]=" (a[2]) "  c=" c ¶
  ```

  ```
  zymbol run t.zy        → a[2]=7  c=1     ✓
  zymbol run --vm t.zy   → a[2]=0  c=0     ✗ sin error
  ```

- **Por qué es grave:** falla **en silencio**. Un programa que use este patrón da
  resultados distintos según el motor y no hay nada que lo delate. En 囲碁 el
  síntoma aguas abajo fue `array index out of bounds` en un punto muy alejado de
  la causa, porque el tablero nunca se modificaba y la lógica seguía adelante
  con una posición vacía.
- **Alcance en el proyecto:** el motor entero descansa en este patrón —
  `盤::着手(局面<~, …, 取数<~, コウ点<~)` es la operación central. Con `--vm`
  ninguna suite pasa. Es la razón por la que 囲碁 es tree-walker only.
- **Relación con MM-10/MM-11:** el v0.0.8 cerró dos bugs de paridad de la VM en
  esta misma zona (mutaciones que cruzan fronteras de módulo). Este parece el
  mismo territorio, aún abierto para `<~`.

---

## IDEA-001 · Ancho de visualización como primitiva

- **Descripción:** Un TUI multilingüe necesita **columnas de terminal**, no
  graphemes. `"手番"$#` da 2 y ocupa 4 columnas; lo mismo con hangul, hanzi,
  emoji y formas de ancho completo. Sin medir columnas, cualquier panel
  enmarcado se desalinea al cambiar de idioma — y este proyecto tiene cinco.
- **Situación actual:** la única ruta de `Char` a entero es el literal de base
  invertido, y hay que quitarle el prefijo a mano:

  ```zymbol
  符号点(c) {
      s = 0d|c|        // "0d12354"
      t = s$[3..]
      <~ #|t|
  }
  ```

  Los `Char` no son comparables (`'あ' > 'z'` es error de ejecución) ni
  convertibles con `##!`/`###`, así que sin este rodeo no hay forma de
  clasificar un carácter por rango Unicode.
- **Lo construido:** `表示/文字.zy` implementa `幅()`, `右詰()`, `左詰()`,
  `中央()` y `切詰()` sobre unas 40 comprobaciones de rango East Asian Wide.
  Funciona (verificado en los cinco idiomas), pero es una tabla Unicode
  mantenida a mano dentro de un juego.
- **Propuesta:** el intérprete ya conoce los grapheme clusters (el lexer los
  maneja). Exponer `$#~` (ancho en columnas) o una función `std/text::width`
  convertiría 150 líneas de tabla en una llamada, y beneficiaría a cualquier
  TUI que no sea puramente ASCII.

---

## Lo que **no** falló

Vale la pena registrarlo, porque eran los riesgos declarados en
[DESIGN.md](DESIGN.md):

| Riesgo previsto | Resultado real |
|-----------------|----------------|
| Profundidad de recursión del flood fill | Una cadena de **360 piedras** en 19×19 se recorre sin problema en el tree-walker |
| Coste de un barrido completo de legalidad | 287 puntos evaluados en **0,38 s** totales, copia de tablero incluida en cada uno |
| Parámetros de salida a través de módulos | `局面<~` se muta correctamente cruzando fronteras de módulo, en recursión y en llamadas anidadas |
| Estado de módulo para el idioma activo | Persiste por ruta de archivo; ningún módulo necesita recibir el idioma como parámetro |
| `>>\|` dentro de una función de módulo | Funciona: `対局::開始()` entra en pantalla alterna y modo raw desde dentro del módulo |
| Arrays anidados como pila de deshacer | `履歴 $+ 盤::複製(局面)` guarda y recupera posiciones completas sin problema |

---

## IDEA-002 · El coste numérico decide la arquitectura de la IA

No es un bug: es la medición que eligió el diseño del motor de juego. Todo en
tree-walker, tablero 9×9, misma máquina.

| Operación | Medido | Consecuencia |
|-----------|--------|--------------|
| Una jugada heurística (enumerar candidatos + evaluar) | **~0,04 s** | instantánea |
| Una simulación aleatoria completa (playout ligero) | **0,24 s** | — |
| MCTS a 1.000 playouts por jugada | **~4 min/jugada** | inviable |
| MCTS a 10.000 playouts por jugada | **~40 min/jugada** | inviable |
| Pasada adelante de una red 81→64→81 (tensores de Zofía) | **~4 s** | inviable |
| Las mismas 5.184 multiplicaciones con array plano | **~0,3 s** | 6-7× más rápido |
| `--vm` como escape | falla (HLZ-008) | no disponible |

Dos conclusiones:

1. **MCTS necesita unas 6.000 veces más presupuesto del que hay.** Con 2 s por
   jugada caben ~8 playouts, y ocho partidas aleatorias no informan de nada.
2. **La brecha entre tensores anidados y arrays planos es de 6-7×**, lo que
   confirma desde fuera el diagnóstico del propio `ROADMAP_IA.md` de Zofía: los
   tensores como listas de listas son el cuello de botella, y un tipo tensor
   nativo es el cambio que desbloquea todo lo demás. Aun con esa mejora, una
   pasada adelante seguiría costando ~0,6 s — suficiente para evaluar una
   posición, insuficiente para buscar sobre ella.

Por eso 核/思考.zy es **determinista y metódico**, no estadístico. La única
simulación que se paga sola es la dirigida y corta: leer una escalera
(シチョウ) son decenas de pasos deterministas, no miles de partidas.
