# Hallazgos del lenguaje — 囲碁 (zy-GO)

Bugs, carencias e ideas encontrados al construir 囲碁 sobre Zymbol **v0.0.8**
y, desde HLZ-012, **v0.0.9**.
Sigue la convención de [Serpiente](../serpiente/HALLAZGOS_ES.md) y
[Hov veS](../klingon_galaxy/hallazgos_es.md).

> **Estado (2026-09-02): los catorce hallazgos están corregidos.** HLZ-012 (el
> tree-walker copiaba la colección para leer un elemento), HLZ-013 (zyjs devolvía
> Unit en vez de una cadena multilínea) y HLZ-014 (copiaba la colección al pasarla
> a una función) se cerraron en la rama `v0.0.9`, cada uno con su prueba de
> regresión: un banco de pendiente en `zyquality/bench/bench_index_read.zy` y un
> fichero de corpus en `zyquality/corpus/strings/literal_multilinea.zy`.
> HLZ-014 salió del banco escrito para HLZ-012, y su arreglo fue **portar el
> modelo de valores de la VM** al tree-walker: los dos motores que no fallaban ya
> pagaban al escribir en vez de al pasar. Entre los dos, la partida de 19×19 pasó
> de 36,3 s a 15,5 s y la búsqueda alfa-beta de Chaturanga de 43,5 s a 12,8 s,
> con las partidas del oráculo idénticas byte a byte.

> **Estado (2026-07-24): los once hallazgos están corregidos en el intérprete**,
> en la rama `v0.0.8`, cada uno con su prueba de regresión. Puertas tras los
> arreglos: 860 pruebas unitarias (antes 847), 528/528 de paridad
> tree-walker/VM (antes 519), 90/90 de verificación del GUIDE, formateador sin
> regresiones. Con HLZ-008 y HLZ-009 cerrados, **las seis suites de 囲碁 pasan
> también bajo `--vm`**, y el juego entero se ejecuta idéntico en ambos motores.
> **IDEA-001 también está implementada** (módulo `std/term` + `##!` sobre `Char`):
> `表示/文字.zy` cayó de 143 a 52 líneas con salida idéntica byte a byte.

| ID | Tipo | Descripción | Estado |
|----|------|-------------|--------|
| [HLZ-001](#hlz-001--las-constantes-de-módulo-no-admiten-valores-negativos) | Gap | `CONST := -1` en un módulo es E013 | **Corregido** |
| [HLZ-002](#hlz-002--el-analizador-infiere-float-en-aritmética-sobre-parámetros) | Bug | Índice de array calculado a partir de parámetros → «must be Int, got Float» | **Corregido** |
| [HLZ-003](#hlz-003--la-igualdad-es-estricta-con-tipos-pero-el-orden-no) | Bug | `##.0 == 0` es `#0` mientras `>= 0` y `<= 0` son ambos `#1` | **Corregido** |
| [HLZ-004](#hlz-004--check-y-el-lsp-rechazan-la-convención-de-punto-de-subcarpetas) | Bug | `# .核_盤` en `核/盤.zy` se ejecuta bien pero `zymbol check` y el LSP lo marcan E001 | **Corregido** |
| [HLZ-005](#hlz-005--ruta-de-import-relativa-al-padre) | Gap menor | `<# ./../x` no parsea; hay que escribir `<# ../x` | **Corregido** (el diagnóstico) |
| [HLZ-006](#hlz-006--guidemd-documenta-mal-el-mapeo-de-las-flechas) | Bug (doc) | GUIDE.md §3b dice que las flechas son `'U' 'D' 'L' 'R'`; en realidad son `'↑' '↓' '←' '→'` | **Corregido** |
| [HLZ-007](#hlz-007--la-yuxtaposición-se-detenía-en-el-primer-delimitador) | Gap | La yuxtaposición no entraba en los argumentos de una llamada | **Corregido** |
| [HLZ-008](#hlz-008--la-vm-ignora-los-parámetros-de-salida-de-un-módulo) | **Bug grave** | En `--vm`, un `<~` de función de módulo no se escribe de vuelta: resultados silenciosamente incorrectos | **Corregido** |
| [HLZ-009](#hlz-009--la-vm-no-puede-cortar-un-string-dentro-de-un-módulo) | Bug | En `--vm`, `s$[3..]` dentro de una función de módulo da «expected Array, Tuple, or NamedTuple» | **Corregido** |
| [HLZ-010](#hlz-010--la-vm-convertía-una-constante-interpolada-en-texto-literal) | **Bug grave** | En `--vm`, `"{CONST}"` dentro de una función producía las llaves literales | **Corregido** |
| [HLZ-011](#hlz-011--una-variable-usada-solo-como-cota-de-rango-se-marcaba-como-no-usada) | Bug (aviso) | `総 = 名一覧$#` usado solo en `@ i:1..総` se marcaba «unused variable» | **Corregido** |
| [HLZ-012](#hlz-012--en-el-tree-walker-leer-ai-copia-la-colección-entera) | **Bug de rendimiento** | En el tree-walker, `a[i]` clona el array completo en cada lectura: O(n) por lectura, y el tablero son 361 celdas | **Corregido** |
| [HLZ-013](#hlz-013--en-el-motor-del-navegador-devolver-una-cadena-multilínea-da-unit) | **Bug grave** | En zyjs, `<~ "línea1⏎línea2"` devuelve Unit en vez de la cadena; los dos motores Rust la devuelven | **Corregido** |
| [HLZ-014](#hlz-014--pasar-una-colección-a-una-función-la-clona-entera) | **Bug de rendimiento** | En el tree-walker, pasar un array a una función lo clona entero, aunque la función no lo mire: 20 000 llamadas con 4 000 elementos son 10 s frente a 6 ms en la VM | **Corregido** |
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

## HLZ-007 · La yuxtaposición se detenía en el primer delimitador

- **Cómo se registró primero (y por qué estaba mal):** el hallazgo se abrió
  contra la interpolación, porque cualquier expresión dentro de las llaves es un
  error de lexer:

  ```zymbol
  >> "total: {結果.黒合計}" ¶   // ✗ invalid character in string interpolation
  >> "komi: {一覧[i]}" ¶        // ✗ ídem
  ```

  Al ir a arreglarlo se contaron las variables intermedias de `表示/描画.zy` una
  por una, y el diagnóstico no se sostuvo: **casi ninguna es un acceso a campo o
  a índice, son llamadas** (`文::右詰(…)`, `言::語(…)`, `主::石字(…)`). Admitir
  `{t.campo}` y `{arr[i]}` habría cerrado el hallazgo tal como estaba escrito
  sin eliminar una sola de las seis variables del panel lateral.

- **Lo que sí costaba:** había dos muros juntos y solo uno cargaba peso. La
  yuxtaposición —la concatenación natural de Zymbol— existía **solo en el nivel
  superior**:

  ```zymbol
  c = a " " b        // ✓ asignación
  >> a " " b ¶       // ✓ salida
  c = (a " " b)      // ✗ expected ')' to close grouped expression
  d = [a " " b]      // ✗ expected ']' to close array literal
  f(a " " b)         // ✗ expected ')' after function arguments
  ```

  Como todo el panel de 囲碁 son llamadas (`側面行(…)`, `枠行(…)`), la
  interpolación quedaba como único recurso; y la interpolación tampoco admite
  llamadas. Entre las dos vallas, la única salida era la variable intermedia.

- **Corregido:** la yuxtaposición funciona ahora dentro de argumentos de
  llamada, elementos de array, elementos de tupla y expresiones agrupadas. La
  coma sigue separando argumentos, y un `(` a continuación **no** continúa la
  cadena en esas posiciones, porque ahí es ambiguo con una lambda, una tupla y
  una agrupación.

  ```zymbol
  // antes
  名_取 = 文::右詰(言::語("panel.captures"), 10)
  >>~ (行, 左, 0, 色_文) > 側面行(" {名_取}{黒}{黒取}  {白}{白取}")

  // ahora
  >>~ (行, 左, 0, 色_文) > 側面行(" " 文::右詰(言::語("panel.captures"), 10) 黒 黒取 "  " 白 白取)
  ```

- **Coste del cambio:** `f(a b)` con una coma olvidada ahora concatena en vez de
  dar error de parseo. Es el precio de la regla, y es el mismo que ya se pagaba
  en el nivel superior.
- **Alcance:** solo el parser. El nodo `BinaryOp::Concat` ya existía, así que ni
  el tree-walker, ni el compilador, ni la VM, ni el formateador cambiaron.
- **Estado:** **corregido**. Regresión en
  `interpreter/tests/strings/30_juxtaposition_delimited.zy` (TW == VM).
- **Lo que queda de la interpolación:** `"{t.campo}"` sigue siendo un error. Se
  deja así a propósito: el mensaje es claro, el `help:` dice qué se admite, y
  ahora existe una forma natural de componer sin ella.

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

## HLZ-009 · La VM no puede cortar un String dentro de un módulo

- **Descripción:** Un slice abierto sobre un String dentro de una función de
  módulo revienta en `--vm`:

  ```zymbol
  # .w_m {
      #> { cola }
      cola(s) { <~ s$[3..] }
  }
  ```

  ```
  zymbol run t.zy        → 0065
  zymbol run --vm t.zy   → Runtime error: type error:
                           expected Array, Tuple, or NamedTuple, got String
  ```

- **Causa:** la instrucción `ArraySlice` de la VM cubría Array, Tuple y
  NamedTuple pero no String. Solo se llegaba a ella cuando el sujeto era un
  valor en ejecución en vez de un literal que el compilador pudiera plegar —
  por eso el hueco aparecía dentro de funciones de módulo y en ningún otro
  sitio.
- **Dónde salió:** `表示/文字.zy`, en `符号点()`, que corta el prefijo `"0d"`
  del literal de base invertido. Es la función de la que depende todo el cálculo
  de anchos, así que se llevó por delante tres de las seis suites.
- **Estado:** **corregido**. Regresión en
  `interpreter/tests/modules_scope/out_param_module.zy`, ejecutada por la suite
  de paridad en ambos motores.

---

## HLZ-010 · La VM convertía una constante interpolada en texto literal

- **Descripción:** bajo `--vm`, `"{記録場所}/9路_0001.kifu"` **dentro del cuerpo
  de una función** compilaba a los caracteres literales `{記録場所}` seguidos de
  `/9路_0001.kifu`. Sin error, sin aviso.

  ```zymbol
  記録場所 := "棋譜"

  書き出す(番号) {
      道 = "{記録場所}/9路_{番号}.kifu"   // --vm → "{記録場所}/9路_0001.kifu"
      io::write(道, 内容)                 // falla en blando, no dice nada
  }
  ```

- **Causa:** `compile_interpolated_string` resolvía cada `{nombre}` buscando un
  registro local y, al no encontrarlo, caía directo en su rama de texto literal.
  Nunca consultaba `global_consts`, donde viven todas las constantes de nivel
  superior, ni `global_var_map`.
- **Por qué se escondió tanto:** la misma cadena en el nivel superior funcionaba,
  y un `>> K` directo dentro de la misma función también. Solo fallaba la
  interpolación, solo dentro de una función, solo bajo la VM.
- **Dónde salió:** el banco `棋戦.zy` jugó **64 partidas y escribió cero
  registros**. La ruta de salida se construía así, `io::write` recibía una ruta
  con una llave literal dentro, fallaba en blando y no avisaba: 64 partidas de
  datos perdidas sin un solo error en pantalla.
- **Estado:** **corregido**. Regresión en
  `interpreter/tests/modules_scope/interp_global_const.zy`, que cubre los cinco
  tipos de constante, el estado mutable de módulo y el nombre genuinamente
  desconocido que **debe** quedarse literal en ambos motores.

---

## HLZ-011 · Una variable usada solo como cota de rango se marcaba como no usada

- **Descripción:** una variable leída **únicamente** en la cota de un rango de
  bucle disparaba el aviso «unused variable», aunque el bucle la usa:

  ```zymbol
  総 = 名一覧$#
  @ i:1..総 {          // 総 se lee aquí, pero el analizador no lo registraba
      >> 名一覧[i] ¶
  }
  ```

  ```
  warning: variable '総' is assigned but never read
  ```

- **Impacto:** solo ruido — el programa se ejecuta bien —, pero un aviso falso
  entrena a ignorar los avisos, que es justo lo que no se quiere de un análisis
  estático. Salió en `表示/描画.zy`, en `設定描画`.
- **Lo desconcertante:** disparaba de forma **no determinista**. El mismo patrón
  en `助言描画`, estructuralmente idéntico, **no** avisaba; dependía de cuántas
  otras variables compartían el ámbito. Eso lo hizo difícil de creer al principio
  («¿por qué solo esta línea?») hasta reproducirlo en aislamiento.
- **Causa:** el analizador de variables no usadas trataba `Expr::Range` como un
  no-op, con un comentario que afirmaba que las cotas eran «literales o
  identificadores solamente». En realidad `start`, `end` y `step` son
  expresiones completas, así que una variable usada solo como cota nunca contaba
  como leída.
- **Estado:** **corregido**. El analizador ahora visita las tres partes del
  rango; una variable genuinamente sin usar sigue avisando. Regresión en
  `interpreter/crates/zymbol-semantic/tests/underscore_semantics.rs` (tres
  casos: cota superior, `inicio..fin:paso`, y el que debe seguir avisando).

---

## HLZ-012 · En el tree-walker, leer `a[i]` copia la colección entera

- **Archivo:** cualquiera. Se encontró perfilando `核/盤.zy`, donde `局面[点]`
  está en el camino de todo.
- **Descripción:** `eval_index` evalúa la expresión de la colección con
  `eval_expr`, y para un identificador eso es `get_variable(...).clone()`. La
  lectura de **un** elemento clona el array entero antes de indexarlo. El coste
  de `a[7]` crece con el tamaño de `a`, no con nada más.

  Sonda (200.000 lecturas de `a[7]`, restando el coste de construir `a`):

  | tamaño de `a` | zytw | zyvm | zyjs |
  |---|---|---|---|
  | 100 | 261 ms | 21 ms | ~226 ms* |
  | 1.000 | 2.147 ms | 21 ms | ~234 ms* |
  | 4.000 | 8.590 ms | 21 ms | ~260 ms* |

  \* zyjs con 20.000 lecturas, no 200.000 — es un motor mucho más lento por
  operación, y lo que importa aquí es la **pendiente**: plana en la VM y en el
  navegador, lineal en el tree-walker.

- **Por qué importa:** un programa que lleva su estado en un array — un tablero,
  una rejilla, un buffer — paga el tamaño de ese estado en cada lectura. En 囲碁
  el tablero de 19×19 son 361 celdas, así que cada `局面[点]` copia 361 valores
  para leer uno. Es la razón principal de que el tree-walker fuera 21× más lento
  que la VM en una partida de 19×19 (777 s frente a 36 s), y no es una diferencia
  de diseño entre motores: es una copia que nadie pidió.
- **Alcance:** solo el tree-walker. La VM y el motor del navegador leen en
  tiempo constante.
- **Arreglo propuesto:** en `eval_index`, cuando la expresión de la colección es
  un identificador, tomarla prestada del entorno y clonar **el elemento**, no la
  colección. Es un caso rápido dentro de una función, sin cambio de semántica:
  la lectura ya devolvía una copia del elemento. Lo mismo vale para
  `eval_member_access` sobre un diccionario.
- **Estado:** **corregido** (v0.0.9, `crates/zymbol-interpreter/src/expr_eval.rs`).
  Se reportó desde aquí porque es un hallazgo del lenguaje, no de la aplicación;
  囲碁 no lo podía arreglar, solo esquivarlo — y esquivarlo es exactamente lo que
  hicieron las optimizaciones de v0.0.9: menos lecturas del tablero, no lecturas
  más baratas.

### Cómo quedó

`eval_index` toma un camino corto cuando la colección es un **nombre**, sola o en
la raíz de una cadena como `m[i][j]`: evalúa los índices, toma el valor prestado
del entorno y clona **el elemento**. `eval_member_access` hace lo mismo con el
diccionario, porque `d.clave` tenía exactamente la misma copia — sobre 300 claves
eran 0,46 s frente a los 0,045 s del `d["clave"]` ya arreglado, las dos formas de
leer lo mismo con un factor 10 entre ellas.

La semántica no cambia —una lectura ya devolvía una copia del elemento— y los
diagnósticos tampoco: los diecinueve errores de indexación y de acceso por punto
(índice 0, fuera de rango en array, tupla, tupla con nombre y cadena, clave
ausente, diccionario por posición, índice no entero, indexar o puntear algo que
no es colección, tupla posicional por nombre, y los mismos a través de una
cadena) dan **texto idéntico** antes y después, comprobado contra los binarios
anteriores.

Un detalle que no es cosmético: el mensaje de fuera de rango **nombra la
colección**, y cada una de esas cuatro redacciones es un mensaje propio. Al
factorizarlas en una sola plantilla la suite `messages` se puso roja —
compara los motores por los mensajes que sus fuentes construyen, y tres de zyjs
se quedaron sin pareja. Están escritas otra vez una por una.

La misma sonda, restando el coste de construir `a`:

| tamaño de `a` | zytw antes | zytw ahora | zyvm |
|---|---|---|---|
| 100 | 261 ms | 19 ms | 21 ms |
| 1.000 | 2.147 ms | 16 ms | 21 ms |
| 4.000 | 8.590 ms | 28 ms | 21 ms |

La pendiente es plana: lo que queda es ruido de máquina, no tamaño.

### Lo que gana el juego

`試験/自戦試験.zy` es el oráculo — una partida entera desde semilla fija — así que
la comparación es la misma partida, movimiento a movimiento. Misma máquina, mismo
árbol, binario anterior y binario con el arreglo; las tres partidas salieron
**byte a byte idénticas**:

| tablero | zytw antes | zytw ahora | |
|---|---|---|---|
| 9×9 | 1,34 s | 1,11 s | 1,2× |
| 13×13 | 6,37 s | 4,82 s | 1,3× |
| 19×19 | 36,26 s | 21,20 s | **1,7×** |

La ganancia crece con el tablero, que es lo que tiene que hacer el arreglo de un
coste que crecía con el tamaño del estado. No es el 21× que separaba al
tree-walker de la VM: **la otra mitad es [HLZ-014](#hlz-014--pasar-una-colección-a-una-función-la-clona-entera)**,
la copia que se paga al *entregar* el tablero a una función, y esa sigue abierta.

### La prueba de regresión

`zyquality/bench/bench_index_read.zy`, registrado en `bench_gate.sh`. No mide un
tiempo: mide una **pendiente** — las mismas 60 000 lecturas contra un array de
100 elementos y contra uno de 4 000, y las mismas 40 000 contra un diccionario de
9 claves y otro de 301, en sus dos grafías (`d["k"]` y `d.k`, que van por caminos
distintos y tenían la misma copia). Cada par tiene que dar lo mismo en cualquier
máquina y en cualquier motor.

Nada en `bench/` leía un elemento por índice: los bancos de colecciones van por
`$>`, `$|`, `$<`, `$?` y cortes, que consumen la colección entera de todos modos
y por eso no distinguen una copia de una lectura. Ese era el hueco por el que se
coló el hallazgo.

---

## HLZ-013 · En el motor del navegador, devolver una cadena multilínea da Unit

- **Archivo:** cualquiera. Se encontró en `対局.zy`, en la cabecera del 棋譜.
- **Descripción:** una función cuyo `<~` lleva **directamente** un literal de
  cadena que ocupa varias líneas devuelve `Unit` en zyjs. Los dos motores Rust
  devuelven la cadena. No hay error ni aviso: el valor sale vacío.

  ```zymbol
  # mod2 {
      #> { a1, a2 }
      a1() { <~ "sin salto" }
      a2() {
          <~ "con
  salto"
      }
  }
  ```

  ```
  tw / vm:   a1=[sin salto]   a2=[con\nsalto]
  zyjs:      a1=[sin salto]   a2=[]
  ```

  Alcance medido con sondas:

  | forma | tw | vm | zyjs |
  |---|---|---|---|
  | `<~ "una línea"` | ok | ok | ok |
  | `<~ "dos⏎líneas"` | ok | ok | **Unit** |
  | `<~ "con {x}⏎interpolación"` | ok | ok | **Unit** |
  | `<~ "con\nsalto escapado"` | ok | ok | ok |
  | `t = "dos⏎líneas"` y luego `<~ t` | ok | ok | ok |

  Pasa igual en una función de módulo y en una de guion suelto, así que no es
  el problema de alcance de los nombres con guion bajo (§4 del brief).

- **Por qué importa:** el valor no falla, sale vacío, y el programa sigue. En
  囲碁 la cabecera del 棋譜 —`# zy-GO kifu v1 / board 9 / …`— se construye así,
  y el registro salía completo en la terminal y **sin cabecera** en el
  navegador. Un registro sin cabecera no dice ni de qué tablero es.
- **Alcance:** solo el motor del navegador. Lo esquivamos atando el literal a un
  nombre local antes de devolverlo (`頭 = "…"` y `<~ 頭`), que funciona en los
  tres.
- **Por qué el gate no lo veía:** el corpus no tiene ningún caso de
  `<~` con literal multilínea. Es un hueco de cobertura, no un fallo del
  comparador: `zyq consensus` compara lo que se le da.
- **Estado:** **corregido** (v0.0.9, `web/src/zymbol/zymbol.js`).

### La causa

`readString` empuja el token con `this.line` **después** de haber consumido el
literal, saltos incluidos, así que un literal multilínea quedaba fechado en la
línea de su comilla de **cierre**. Un token pertenece a la línea en la que
**empieza** — los dos motores Rust pasan la posición de inicio a `lex_string`
precisamente por esto — y en zyjs todas las reglas sensibles a la línea leían ese
campo. `<~` concluía que su valor empezaba en otra línea, decidía que el retorno
no llevaba valor y devolvía Unit sin decir nada.

### Cómo quedó

El token guarda las dos: `line` es donde empieza y `endLine` donde termina. Las
reglas que preguntan *«¿esto continúa la expresión anterior?»* —yuxtaposición,
`[`, `(`, y las de `>>` y `<~`— preguntan por `endLine` a través de
`prevEndLine()`, que es como lo deletrean los motores Rust
(`peek().span.start.line != expr.span().end.line`).

Esa segunda mitad no era opcional: fechar el token en su inicio y dejar las
reglas como estaban habría cambiado un fallo por otro. La sonda destapó dos
divergencias más de la misma raíz, ambas ya corregidas y ambas comprobadas contra
los dos motores Rust:

| forma | tw / vm | zyjs antes | zyjs ahora |
|---|---|---|---|
| `<~ "a⏎b"` | `a\nb` | **Unit** | `a\nb` |
| `<~ "a⏎b" "c"` | `a\nbc` | `a\nb` | `a\nbc` |
| `>> "[" f("d⏎e") "]" "f" ¶` | `[d\ne]f` | `[d\ne` | `[d\ne]f` |

### La prueba de regresión

`zyquality/corpus/strings/literal_multilinea.zy` (con su módulo `_m`), que es
donde debería haber saltado: el corpus no tenía **ningún** caso de literal
multilínea tras `<~`. Recorre las once formas que leen el número de línea de una
cadena — devuelta desde función de módulo y desde función suelta, con y sin cola
yuxtapuesta, atada a un nombre, impresa directamente, como argumento, como
operando de `$#` y dentro de un array. Los tres motores coinciden.

---

## HLZ-014 · Pasar una colección a una función la clona entera

- **Archivo:** cualquiera. Salió del banco de pruebas escrito para
  [HLZ-012](#hlz-012--en-el-tree-walker-leer-ai-copia-la-colección-entera), en la
  línea que mide una lectura hecha *dentro* de una función.
- **Descripción:** en el tree-walker, entregar un array a una función lo copia
  entero, aunque la función no lo mire. La sonda es una función que ignora su
  parámetro:

  ```zymbol
  toma(t) { <~ 1 }
  @ _k:1..20000 { s = s + toma(a) }
  ```

  | tamaño de `a` | zytw | zyvm | zyjs\* |
  |---|---|---|---|
  | 100 | 61 ms | 5 ms | 11 ms |
  | 1.000 | 1.486 ms | 10 ms | — |
  | 4.000 | 8.846 ms | 6 ms | 2 ms |

  \* zyjs con 2.000 llamadas y tiempo de pared menos su propia línea base; lo
  que importa es la pendiente, plana en los dos motores que no copian.

  El coste es del **paso**, no de la llamada: la misma función sin argumento son
  34 ms, y leer `a[7]` fuera de la función son 8 ms.

- **Causa:** `eval_traditional_function_call` evalúa cada argumento con
  `eval_expr`, y para un nombre eso es `get_variable(..).clone()`. Una copia por
  llamada. En el caso de 4.000 elementos son ~192 KB por llamada, por encima del
  umbral de `mmap` de glibc, así que cada llamada es además un `mmap`/`munmap`:
  de los 10 s medidos, 6,9 s eran tiempo de **sistema**.
- **Por qué importa:** es la otra mitad de la distancia entre los dos motores
  Rust en 囲碁. Con HLZ-012 cerrado, la partida de 19×19 desde semilla fija son
  21,2 s en el tree-walker y 3,8 s en la VM — 5,5× — y el juego pasa `局面` a casi
  todas sus funciones. Un programa que lleva su estado en una colección paga el
  tamaño de ese estado en cada llamada que se lo entrega.
- **Alcance:** solo el tree-walker. La VM y el motor del navegador entregan la
  colección en tiempo constante.
- **Lo que NO es el arreglo:** pasar por referencia. Un parámetro sin marca es
  una copia y el lenguaje lo dice: el cuerpo puede reasignarlo y puede editarlo
  con `$~`, y ni una cosa ni la otra llegan a quien llamó — para eso está `<~`
  en la firma. La semántica se queda como está.
- **Estado:** **corregido** (v0.0.9, `crates/zymbol-interpreter/src/lib.rs` y 14
  ficheros más del crate).

### Los otros dos motores ya lo hacían

La pregunta que decidió el arreglo no fue «¿qué inventamos?» sino «¿cómo lo hacen
los que no fallan?», y la respuesta estaba en el repositorio:

| motor | al ligar | al escribir |
|---|---|---|
| **zyvm** | `Array(Rc<Vec<Value>>)` — comparte | `Rc::make_mut`, se separa el primero que escribe |
| **zyjs** | comparte el array de JavaScript | `deepUpdateValue` construye uno nuevo: `[...col.v]` |
| **zytw** | **clonaba entero** | escribía en sitio |

Dos caminos distintos hacia el mismo principio —se paga al **escribir**, no al
**pasar**— y el tree-walker era el único que pagaba en la otra puerta. Así que
esto no fue diseñar copia al escribir: fue **portar el modelo de valores de la
VM**, con sus decisiones ya tomadas y probadas.

### Cómo quedó

```rust
Array(Rc<Vec<Value>>),
Tuple(Rc<Vec<Value>>),
NamedTuple(Rc<Vec<(String, Value)>>),
```

y `Rc::make_mut` en los **32** sitios que escriben. `own_elements`/`own_fields`
son el gemelo del lado de la lectura para el código que consume la colección
(`$>`, `json::encode`): entrega los valores sin copia cuando nadie más los tiene.
`String` se queda como está a propósito: la VM tiene `ZyStr` para eso —7 bytes en
línea, `Rc<String>` por encima— que es código `unsafe` que se gana el sueldo en un
bucle de bytecode y no aquí, y una cadena es una asignación, no una por elemento.

El compilador señaló los 76 sitios y no hubo que buscar ninguno a mano.

### La semántica no se movió

Es la parte que había que demostrar, porque compartir solo es aceptable si es
invisible. Catorce puertas, los tres motores, misma respuesta en las tres
columnas: reasignar el parámetro, `$~` dentro del llamado, `b = a` y escribir
luego, un array dentro de otro array, `$+` sobre la copia, las marcas `~` y `<~`,
el diccionario por clave y por punto, la tupla, la matriz anidada, recorrer con
`@`, `$>` y `$+`. Y los 19 diagnósticos de indexación y acceso por punto siguen
dando texto idéntico.

Una comprobación más, la que importaba: escribir en un bucle no se volvió caro.
40 000 escrituras sobre un array de 2 000 cuestan lo mismo compartido que sin
compartir (14 ms y 15 ms) — la copia ocurre **una vez**, en la primera escritura,
y a partir de ahí el contador vuelve a uno.

### Lo que gana

Misma sonda de antes, la función que ignora su parámetro:

| tamaño de `a` | antes | ahora | zyvm |
|---|---|---|---|
| 100 | 61 ms | 17 ms | 7 ms |
| 1.000 | 1.486 ms | 20 ms | 5 ms |
| 4.000 | **8.846 ms** | **14 ms** | 6 ms |

Y en las dos aplicaciones que más lo pagaban, con las partidas del oráculo otra
vez **byte a byte idénticas**:

| carga | v0.0.9 original | tras HLZ-012 | tras HLZ-014 | zyvm | total |
|---|---|---|---|---|---|
| zy-GO 9×9 | 1,34 s | 1,11 s | **0,97 s** | 0,15 s | 1,4× |
| zy-GO 13×13 | 6,37 s | 4,82 s | **3,87 s** | 0,66 s | 1,6× |
| zy-GO 19×19 | 36,26 s | 21,20 s | **15,49 s** | 3,78 s | **2,3×** |
| Chaturanga `गतिपरीक्षा` | 6,11 s | 2,16 s | **1,94 s** | 0,17 s | 3,2× |
| Chaturanga `मतिपरीक्षा` | 43,5 s | 16,08 s | **12,78 s** | 0,99 s | **3,4×** |

La distancia con la VM en la partida de 19×19 baja de 21× a **4,1×**, y en la
búsqueda alfa-beta de 42–46× a **13×**. La VM no se tocó: lo que cambió es que el
tree-walker dejó de copiar dos veces lo que nadie le pidió que copiara.

### La prueba de regresión

La línea `read_in_fn` de `zyquality/bench/bench_index_read.zy`, que se escribió
para esto y por eso está ahí: 2,165 s antes, 0,009 s ahora. El banco entero pasó
de 2,32 s a 0,14 s.

---

## IDEA-001 · Ancho de visualización como primitiva — **implementada (std/term)**

> **Estado (2026-07-24): implementada** como el módulo **`std/term`** del
> intérprete (no como símbolo — es capacidad de biblioteca, y además son cinco
> funciones, no una). `表示/文字.zy` pasó de **143 a 52 líneas**: ahora es un
> envoltorio localizado delgado sobre `std/term`, y las seis suites de 囲碁 más
> el panel dan salida **idéntica byte a byte** antes y después, en TW y VM. La
> regla que fijó la frontera: `std/term` mide la **pantalla** (`width`,
> `pad_left`, `pad_right`, `center`, `truncate`); todo lo que opera sobre el
> **contenido** del string (split `$/`, slice `$[..]`, replace `$~~`, y los
> futuros join/trim) es símbolo del lenguaje y nunca entra ahí — por eso se
> llama `term` y no `text`. El rodeo `符号点` desaparece: **`##!` ahora acepta un
> `Char`** y da su code point directamente. Un test diferencial confirmó 0
> divergencias entre la tabla manual y `unicode-width` sobre cada glifo que el
> juego dibuja.

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
- **Lo que se construyó primero:** `表示/文字.zy` implementaba `幅()`, `右詰()`,
  `左詰()`, `中央()` y `切詰()` sobre unas 40 comprobaciones de rango East Asian
  Wide — una tabla Unicode mantenida a mano dentro de un juego.
- **Lo que reemplazó a esa tabla:** el módulo nativo **`std/term`**
  (`width`/`pad_left`/`pad_right`/`center`/`truncate`), que mide columnas con
  las tablas de `unicode-width` sobre grapheme clusters. `文字.zy` es ahora un
  envoltorio localizado de 52 líneas que delega en `端::…`, y `符号点` es un
  simple `##!c`. Se descartó la alternativa del símbolo `$#~`: medir la pantalla
  es una capacidad de biblioteca, y son cinco funciones, no una — la regla
  **contenido vs pantalla** mantiene split/join/trim como símbolos del lenguaje.

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
| `--vm` como escape | falla (HLZ-008) | no disponible **entonces** |

Dos conclusiones:

1. **MCTS necesita unas 6.000 veces más presupuesto del que hay.** Con 2 s por
   jugada caben ~8 playouts, y ocho partidas aleatorias no informan de nada.
2. **La brecha entre tensores anidados y arrays planos es de 6-7×**, lo que
   confirma desde fuera el diagnóstico del propio `ROADMAP_IA.md` de Zofía: los
   tensores como listas de listas son el cuello de botella, y un tipo tensor
   nativo es el cambio que desbloquea todo lo demás. Aun con esa mejora, una
   pasada adelante seguiría costando ~0,6 s — suficiente para evaluar una
   posición, insuficiente para buscar sobre ella.

**Corregido después (2026-07-22):** la fila de `--vm` de la tabla está fechada.
Con HLZ-008 y HLZ-009 cerrados la VM sí es una vía, y medida contra el
tree-walker en esta carga da **8-14× más rápida** (una partida de 19×19 pasó de
6m40s a 49,8s) — no el ~4,4× que declara `ARCHITECTURE.md`, cifra que sale de
bancos aritméticos y no de una carga dominada por asignación y copia de arrays.
Aun así, un factor 10 no mueve la conclusión sobre MCTS: hacen falta tres
órdenes de magnitud, no uno.

Por eso 核/思考.zy es **determinista y metódico**, no estadístico. La única
simulación que se paga sola es la dirigida y corta: leer una escalera
(シチョウ) son decenas de pasos deterministas, no miles de partidas.
