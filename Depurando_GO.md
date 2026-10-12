# Depurando 囲碁 — bugs de la aplicación y divergencias de motor

Registro de trabajo de la rama **v0.0.10**. Empezó el 2026-09-27 con una
revisión externa de `web/examples/games/classic/go.zyp`, hecha con pruebas
sobre `zymbol.js` (zyjs), y sigue con lo que salió al comprobarla en los tres
motores: tree-walker (tw), VM de registros (vm) y zyjs.

[HALLAZGOS_ES.md](HALLAZGOS_ES.md) es el registro de lo que **el lenguaje** hizo
mal o no tenía. Este documento guarda las dos cosas que no caben ahí: los
bugs de **la aplicación**, que se corrigen en GO, y las **divergencias entre
motores** que la depuración va destapando, con la prueba de cada una.

| ID | Dónde | Descripción | Estado |
|----|-------|-------------|--------|
| [DG-01](#dg-01--blanco-juega-siempre-con-la-versión-de-negro) | GO | `_版選び` devuelve siempre `設定[6]`: blanco piensa con el motor de negro | **Corregido** |
| [DG-02](#dg-02--la-versión-v2-es-inalcanzable) | GO | `_版着手選択` manda v2 y v3 al mismo motor; `思2` se importa y no se llama | **Corregido** |
| [DG-03](#dg-03--el-comentario-de-_版選び-describe-un-diseño-anterior) | GO | El comentario describe un selector único con «0 = v1 contra v2» | **Corregido** |
| [DG-04](#dg-04--設定-es-un-arreglo-mezclado-escrito-con-) | GO | `設定` mezcla Int, String y Float dentro de `[…]` | **Corregido** |
| [DG-05](#dg-05--zyjs-deja-de-comprobar-un-arreglo-en-cuanto-un-elemento-no-tiene-tipo-conocido) | zyjs | `[9, "x", p]` es error en Rust y se ejecuta en zyjs | **Corregido** |
| [DG-06](#dg-06--zyjs-descarta-todos-los-avisos-dentro-de-un-módulo) | zyjs | `check` de un fichero de módulo: Rust da los avisos, zyjs ninguno | **Descartado por ahora** |
| [DG-07](#dg-07--rust-avisa-de-mezcla-innecesaria-sobre-tipos-que-no-conoce) | tw, vm | `#[id(1), "x"]` avisa «every element is Any»: afirma una homogeneidad que no puede ver | **Corregido** |
| [DG-08](#dg-08--zymbol-run-callaba-los-avisos-de-la-fase-de-tipos-al-rechazar) | tw, vm | Con un error estático, `run` no imprimía los avisos de la fase de tipos; `check` y zyjs sí | **Corregido** |

Los dos gaps de herramientas que señaló la misma revisión (import sin usar,
código inalcanzable) son del lenguaje y están en `HALLAZGOS_ES.md` como
**HLZ-015** y **HLZ-016**, abiertos y sin decisión.

---

## Método

**La partida no se puede conducir por una tubería**: el menú y el tablero leen
teclas con `<<|`, que exige una terminal. Para confirmar DG-01 y DG-02 se hizo
una copia de GO fuera del repositorio con dos funciones de prueba exportadas
desde `対局.zy`, que llaman a las privadas con un tablero real:

```zymbol
探版(設定, 色) { <~ _版選び(設定, 色) }
探着手(版, 局面, 色) { <~ _版着手選択(版, 局面, 9, 色, 2, 0, 0, 0) }
```

y una línea `[DBG]` en cada rama de `_版着手選択` que dice a qué módulo despacha.
El repositorio no se tocó para medir.

**Las divergencias se reducen hasta la forma mínima** y se ejecutan en los tres
motores, con `</dev/null`: sin stdin, `web/tests/run_one.mjs` se queda
esperando la entrada real.

---

## DG-01 · Blanco juega siempre con la versión de negro

- **Dónde:** `対局.zy`, `_版選び` (línea 342), llamada desde `_思考一手` (680).
- **Qué hace:**

  ```zymbol
  _版選び(設定, 色) {
      版 = 設定[6]
      ? 版 == 0 {
          ? 色 == 1 { <~ 1 }
          <~ 2
      }
      <~ 版
  }
  ```

  `色` solo se lee dentro de `? 版 == 0`, y el menú (`版一覧 = [3, 2, 1]` en
  `_設定画面`) nunca produce un 0. Siempre devuelve `設定[6]`, la versión de
  negro.
- **Medido** (igual en tw, vm y zyjs):

  ```
  黒=v1 白=v3   色=1 → 1 → 思1   |   色=2 → 1 → 思1
  黒=v3 白=v1   色=1 → 3 → 思    |   色=2 → 3 → 思
  ```

- **Efecto:** en 観戦 no se puede enfrentar una versión a otra, que es para lo
  que existe elegir una versión por color. Además el rótulo sí distingue
  (`表示/描画.zy:340-341` lee `設定[7]` cuando juega blanco): la pantalla dice
  «v3» mientras blanco piensa con v1.
- **Origen:** no es un refactor que dejara atrás a la función. `_版選び` nació
  en f893081 (2026-09-01, *Choose the engine per colour*), **el mismo commit**
  que creó `設定[7]` y el selector de blanco, y ya entonces leía solo
  `設定[6]`. La rama `版 == 0` es el resto del diseño anterior, un selector
  único con «v1 contra v2», que el commit reemplazó en el menú y no en la
  función.
- **Corrección:** `? 色 == 2 { <~ 設定[7] }` y `<~ 設定[6]`; la rama muerta se
  elimina.
- **Medido después**, con la misma sonda, idéntico byte a byte en tw, vm y
  zyjs:

  ```
  黒=v1 白=v3   色=1 → 1 → 思1   |   色=2 → 3 → 思
  黒=v3 白=v1   色=1 → 3 → 思    |   色=2 → 1 → 思1
  黒=v1 白=v2   色=1 → 1 → 思1   |   色=2 → 2 → 思2
  黒=v2 白=v3   色=1 → 2 → 思2   |   色=2 → 3 → 思
  黒=v2 白=v1   色=1 → 2 → 思2   |   色=2 → 1 → 思1
  ```

- **Sin prueba automática:** `_版選び` es privada y la partida solo se conduce
  con teclas. La sonda vive fuera del repositorio; fijarla exigiría sacar la
  elección de versión a un módulo que una suite de `試験/` pueda importar.
- **Estado:** **corregido.**

## DG-02 · La versión v2 es inalcanzable

- **Dónde:** `対局.zy`, `_版着手選択` (línea 351); import de `思2` (línea 55).
- **Qué hace:** distingue solo `版 == 1`; 2 y 3 van a `思` (`核/思考`, el motor
  actual). `思2` no se nombra fuera del import.
- **Medido:** `黒=v2` → `版=2 -> 思 (核/思考)` en los tres motores.
- **Por qué no lo vio ninguna herramienta:** HLZ-015. Desde el 2026-09-27
  los tres motores avisan `import '思2' is never used`; con la línea del
  despacho puesta, ya no hay nada que avisar.
- **Origen:** 4972446 (2026-09-02, *v3: defend a chain at two liberties*). Al
  llegar v3 se congeló v2 en `版/思考v2.zy`, se añadieron su import y el `2`
  del menú (`版一覧 = [3, 2, 1]`), y faltó la línea del despacho, que es
  justo lo que el comentario de `_設定画面` pide: *«Adding a version is one
  entry here and one line in _版着手選択»*.
- **Corrección:** `? 版 == 2 { <~ 思2::着手選択(…) }`, y un comentario sobre
  la función que dice que cada versión congelada es una línea.
- **Estado:** **corregido** (medido en la tabla de DG-01).

## DG-03 · El comentario de `_版選び` describe un diseño anterior

- **Dónde:** `対局.zy`, líneas 326-340 (japonés e inglés).
- **Qué dice:** *«設定[6] is 1 for the frozen first engine, 2 for the current
  one, 0 for "v1 against v2"»*: un solo selector compartido. Desde que
  `_設定画面` devuelve `設定[6]` y `設定[7]` por separado, eso ya no es verdad;
  y «2 = el actual» tampoco, porque desde v3 el actual es 3.
- **Por qué importa:** es lo que hizo creíble DG-01. Quien lee el comentario ve
  una función coherente con él.
- **Corrección:** reescrito en japonés e inglés: dice de dónde sale cada
  versión y por qué la función cambió.
- **Estado:** **corregido.**

## DG-04 · `設定` es un arreglo mezclado escrito con `[…]`

- **Dónde:** `対局.zy:279`, el retorno de `_設定画面`:

  ```zymbol
  <~ [路一覧[路位], 主題一覧[主題位], 級, コミ一覧[コミ位], 手番一覧[手番位], 版一覧[黒位], 版一覧[白位]]
  ```

  Int, String (el tema), Int, Float (la komi), Int, Int, Int.
- **Por qué pasa:** la homogeneidad de `[…]` es una comprobación del analizador
  sobre el literal (REFERENCE L11, decisión 15), no del valor. Aquí ningún
  elemento tiene un tipo que el analizador pueda deducir, así que ningún motor
  lo rechaza, ni al comprobar ni al ejecutar (`[id(1), id("x"), 6.5]` corre en
  los tres).
- **Lo que dice el lenguaje:** una mezcla deliberada se declara con `#[…]`.
- **Corrección:** `<~ #[…]`, con un comentario que dice por qué. Medirlo
  destapó DG-07: con el Rust de entonces, `#[…]` sobre estos elementos avisaba
  *«every element is Any»*. Con DG-07 corregido, `zymbol check 対局.zy` da el
  mismo único aviso de antes (el de rango, 137:14).
- **Estado:** **corregido.**

---

## DG-05 · zyjs deja de comprobar un arreglo en cuanto un elemento no tiene tipo conocido

- **Antecedente:** es un residuo de **DM-04** (`Divergente_ES/INDICE.md`),
  cerrada el 2026-08-18 con «`[…]` se comprueba en los tres».
- **Forma mínima:**

  ```zymbol
  f(p) { <~ [9, "x", p] }
  >> f(1) ¶
  ```

  | motor | resultado |
  |---|---|
  | tw, vm | `error: array element 2 has type String, but expected Int (same as first element)` |
  | zyjs | `[9, x, 1]` |

  Igual con `k = [1]` y `[9, "x", k[1]]`, y con `[k[1], "x"]`.
- **Causa**, en dos partes:
  1. `type_check.rs` compara **cada** elemento con el primero, y un tipo
     desconocido es compatible con todo. `Checker` de zyjs
     (`case 'Array'`) solo compara si conoce **todos** los tipos
     (`kinds.every(k => k !== null)`): un solo elemento desconocido apaga la
     comprobación del arreglo entero.
  2. `staticKind` no deduce el tipo de una lectura indexada (`k[1]` con `k`
     un `[Int]`), y Rust sí. Esto solo importa para `[k[1], "x"]`, donde el
     desconocido es el primero.
- **Por qué importa:** un programa que corre en el playground no compila en la
  línea de órdenes, el orden de descubrimiento más caro, y el que DM-04 quiso
  cerrar. Salió porque una sonda de DG-01 usaba `[9, "x", …]` por descuido y
  zyjs la ejecutó.
- **Corrección** (`web/src/zymbol/zymbol.js`, `Checker`, `case 'Array'`):
  1. Cada elemento se compara con el primero y un tipo desconocido es
     compatible con todo, como en `type_check.rs`. Un error por elemento, como
     allí: `[1, "a", #1]` da dos en los tres motores.
  2. El tipo de un elemento es `staticKind(el) ?? inferType(el)`. `inferType` es
     la réplica de `infer_expr` que zyjs ya usaba para `W_TYPE_CHANGE`
     (GLB-043): sabe tipar `k[1]`, la llamada a una función del mismo fichero y
     `a$#`. `Any` cuenta como desconocido.
- **Pruebas:** dos formas nuevas en `zyquality/reject/collections/`:
  `16_literal_mixes_with_untyped.zy` (causa 1) y
  `17_literal_mixes_with_indexed_read.zy` (causa 2). `zyq reject`: 45 de 45
  rechazadas en los tres motores. Sondas de la tabla de DG-07 y `[1, ##_]`,
  `[1, g()]` con `g` que devuelve String, `[a$#, "x"]`: mismo diagnóstico en
  los tres.
- **Estado:** **corregido.**

## DG-06 · zyjs descarta todos los avisos dentro de un módulo

- **Forma mínima**, `zymbol check` sobre el fichero del módulo:

  ```zymbol
  # md_x {
      #> { f }
      f(a) {
          sobra = 3
          c = [1, "x"]
          n = a$#
          @ i:1..n { >> a[i] ¶ }
          ? 5 { >> c ¶ }
          <~ 1
      }
  }
  ```

  | motor | diagnósticos |
  |---|---|
  | tw, vm | `unused variable 'sobra'`, el error del arreglo, `range direction is decided at runtime`, `if condition should be Bool, got Int` |
  | zyjs | solo el error del arreglo |

  En GO: `zymbol check 対局.zy` da el aviso de rango en 137:14 y `checkSource`
  nada. Es el «0 diagnósticos» de la revisión.
- **Causa:** deliberada. `case 'ModuleBlock'` en `zymbol.js` guarda los
  errores y tira los avisos:

  > *Warnings raised inside are dropped: … this engine's `unused variable`
  > analysis reports a false positive for a name reassigned inside a branch
  > and then returned (`nueva = dir / ? … { nueva = 1 } / <~ nueva`) — a
  > pre-existing defect that has nothing to do with modules.*

- **La razón citada ya no se sostiene, pero hay otra:** el falso positivo del
  comentario no se reproduce (su forma exacta, en una función suelta, no da
  avisos en ningún motor). Pero al quitar el descarte en una copia y comparar
  con `zymbol check` los **195 ficheros de módulo** del corpus y de las
  aplicaciones (GO, Chaturanga, serpiente, klingon_galaxy, Zofia, ZyAudit,
  ZyBank, GoL, `web/examples`):

  | | avisos |
  |---|---|
  | Rust | 99 |
  | zyjs sin descarte | 894 |
  | coinciden | 94 |
  | solo zyjs | 800, **todos** `unused variable` (736) o `unused constant` (64) |

  El aviso de rango y el resto de las categorías coinciden. Lo que sobra son
  falsos positivos del análisis de nombres sin usar dentro de un módulo, de al
  menos tres clases:
  - el **nombre de una función del módulo** se trata como una variable sin
    leer (`GO/表示/描画.zy:179`, `設定描画(上, 左, …) {`), y lo mismo un
    re-export (`Chaturanga/दर्शनम्/अक्षरम्.zy:38`);
  - una **constante** del módulo, exportada o leída por sus funciones;
  - una variable leída **solo dentro de una interpolación** que va de
    argumento: `級 = 設定[3]` y luego `言::語("棋力.{級}")`
    (`GO/表示/描画.zy:374`).

  Los cinco avisos que solo da Rust son de `klingon_galaxy` (`bach.zy:106`,
  `HuD.zy:219`, `HuD.zy:350`): `variable '' is assigned but never read`, con el
  **nombre vacío**. Un defecto de Rust aparte, sin estudiar todavía.
- **Alcance:** solo `check` de un fichero de módulo (la pestaña abierta en el
  playground, el panel de diagnóstico). Al **ejecutar**, ningún motor muestra
  los avisos de un módulo importado, así que la salida de los programas no
  cambia.
- **Estado:** **descartado por ahora** (decisión del autor, 2026-09-27). El
  descarte de avisos sigue en `zymbol.js`. La medición queda aquí para cuando
  se retome: antes de quitar el descarte hay que corregir las tres clases de
  falso positivo y volver a comparar los 195 ficheros de módulo. El aviso de
  nombre vacío de Rust en klingon_galaxy también queda sin estudiar.

## DG-07 · Rust avisa de «mezcla innecesaria» sobre tipos que no conoce

- **Encontrado** al preparar DG-04: antes de proponer `#[…]` para `設定` había
  que saber si la decisión 18 («un `#[…]` que resulta homogéneo avisa») se
  dispara cuando el analizador no ve los tipos.
- **Forma mínima**, con `id(p) { <~ p }`:

  | forma | tw, vm (antes) | zyjs |
  |---|---|---|
  | `#[id(1), id("x")]` | `every element is Any` | nada |
  | `#[id(1), "x"]` | `every element is Any` | nada |
  | `#[1, id(2)]` | `every element is Int` | nada |
  | `#[1, 2]` | `every element is Int` | `every element is Int` |

  La segunda fila es una mezcla **real** en ejecución (`[1, x]`), y Rust
  recomienda escribirla con `[…]`.
- **Causa:** `type_check.rs` calcula `mixed` con `types_compatible`, donde
  `Any`/`Unknown` son compatibles con todo. Eso está bien para **rechazar**
  (nunca da un error falso) y mal para **afirmar**: «no mezclado» pasaba a ser
  «no pude probar la mezcla», y el aviso afirma lo contrario.
- **Quién tenía razón:** zyjs, que solo avisa cuando conoce todos los tipos.
  GUIDE.md dice *«warns when a `#[…]` turns out homogeneous»*, y con un tipo
  desconocido no ha resultado nada.
- **Corrección:** `ZymbolType::is_determined()` (ningún `Any`/`Unknown` a
  ninguna profundidad), y el aviso exige que todos los elementos lo sean.
  Pruebas: `declared_mix_of_known_equal_types_warns` y
  `declared_mix_with_an_untyped_element_does_not_warn` en `type_check.rs`.
  Ningún golden dependía del aviso falso.
- **Estado:** **corregido.** Desbloquea DG-04.


## DG-08 · `zymbol run` callaba los avisos de la fase de tipos al rechazar

- **Encontrado** al construir HLZ-016: siete celdas de ZyDDT usaban `? #0 { … }`
  a propósito, y tres de ellas, que además eran un error estático, pasaron a
  `DIVERGE`. zyjs imprimía `this branch never runs` antes del error; tw y vm
  no.
- **No era del aviso nuevo.** Ya pasaba con cualquier aviso de esa fase:

  ```zymbol
  x = 5
  ? x { >> 1 ¶ }
  sobra = 2
  >> nada ¶
  ```

  | | avisos antes del error |
  |---|---|
  | `zymbol check` | `unused variable 'sobra'`, `if condition should be Bool, got Int` |
  | zyjs | los mismos dos |
  | `zymbol run` (tw, vm), antes | solo `unused variable 'sobra'` |

  `run` imprimía los avisos del análisis de variables, que va antes, y los de
  la fase de tipos solo si el programa pasaba: al rechazarlo por un error de
  tipos o de `std/`, salía antes de llegar a ellos. Ninguna celda lo
  provocaba.
- **Corrección:** `run_program` junta los avisos de la fase (los del type
  checker, HLZ-015 y HLZ-016) en cuanto termina el análisis y los imprime
  **antes** de salir por cualquiera de los dos rechazos. Es el principio que
  el propio código ya enunciaba: *«`run` says what `check` says»*. En un
  programa que pasa, el orden y el contenido de la salida no cambian.
- **Las celdas `WRONG`.** Las cuatro celdas que esperaban `ok` (dos en
  `lifetime`, una en `runtime-functions-hof`, una en `syntax-expressions`)
  pasaron a avisar, igual en los tres motores. Cambiarles `expect` a `warn`
  habría debilitado la pregunta: `ok` también afirma que no sale *ningún*
  aviso, y eso es lo que vigila `prefix-hot-read-in-an-else-if` (ZYJS-035).
  Se cambió la condición: `? #0` pasó a `? x == 0` con `x = 1`, que sigue sin
  correr y el analizador no pliega. Cada celda lleva un comentario con el
  porqué.
- **Estado:** **corregido.**

---

## Verificación del lote (2026-09-27)

- **GO:** `zyquality/project/run.sh --only go`: 10 de 10 goldens, 10 ficheros de
  acuerdo y 0 divergencias entre motores. `試験/api試験.zy` pasa en tw y vm.
- **Paquete:** `web/examples/games/classic/go.zyp` reconstruido con
  `zymbol package GO` (23 ficheros; el `W008` de `試験/`, `api/`, etc. es el de
  siempre). Su `対局.zy` es idéntico al de `GO/`. `test_catalog --check` y
  `test_zyp` pasan.
- **Rechazos:** 45 de 45 refusados en los tres motores. Con el `zymbol.js`
  anterior, las dos formas nuevas (16 y 17) salen **aceptadas**: prueban lo
  que dicen.
- **`zyq suite`:** selftest, audit, reject, expect (634 de 638 goldens + 26 de
  26 vía `check`, 4 sin comprobar por exclusión) y consensus (660 de 666, 0
  divergencias) pasan. Las siete aplicaciones mantienen sus goldens. ZyDDT: todos los
  ejes de acuerdo, 0 `wrong`, los 12 pins de acuerdo. **El gate sale rojo**
  por `surfaces` de ZyDDT: `highlight.js` deja 14 tokens `' #'` sin marcar y
  la gramática de VS Code 43, sobre celdas generadas de formato numérico. Este
  lote no toca ningún resaltador. `reach` también falla (6 diagnósticos de
  sintaxis nuevos que nada provoca), marcado *not a gate*, y tampoco es de
  aquí.
- **Rust:** `cargo test -p zymbol-semantic` en verde, con las dos pruebas nuevas.
- **web:** `test_check` (sin regresiones de paridad), `test_i18n_playground`,
  `test_runner --dir examples` (216 de acuerdo, 0 divergencias).
- **Editor:** tras recompilar, VS Code seguía mostrando el aviso falso de DG-07
  en `対局.zy`: los `zymbol-lsp` en marcha eran del 2026-09-14. Recargar la
  ventana.
