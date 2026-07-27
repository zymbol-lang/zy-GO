# Auditoría de i18n — 囲碁 (zy-GO)

Revisión del sistema de internacionalización del proyecto, hecha el **2026-07-26**
contra Zymbol **v0.0.8**.

A diferencia de [HALLAZGOS_ES.md](HALLAZGOS_ES.md), que registra carencias **del
lenguaje**, este documento registra carencias **del proyecto**: sitios donde 囲碁
no sigue su propia doctrina de i18n.

囲碁 es la implementación de referencia del proyecto Zymbol en esta materia — la
doctrina extraída de aquí está escrita en
[interpreter/USERAPPI18N.md](../interpreter/USERAPPI18N.md). Los tres hallazgos de
abajo son los sitios donde la referencia no se cumple a sí misma.

| ID | Tipo | Descripción | Estado |
|----|------|-------------|--------|
| [GO-I18N-001](#go-i18n-001--la-capa-api-está-documentada-pero-no-existe) | Doc vs. código | `DESIGN.md` §9 y `README.md` describen `api/english.zy` y `api/espanol.zy`; el directorio no existe | **Corregido** |
| [GO-I18N-002](#go-i18n-002--集計zy-hila-el-idioma-como-parámetro-booleano) | Inconsistencia | `集計.zy` no importa `言語/取次` y pasa el idioma como `#0/#1` por 15 sitios de llamada | **Corregido** |
| [GO-I18N-003](#go-i18n-003--designmd-8-se-contradice-a-sí-mismo) | Doc | El ejemplo usa claves sin prefijo de dominio; el texto explica dos párrafos después que el prefijo es obligatorio | **Corregido** |
| [GO-I18N-004](#go-i18n-004--los-instrumentos-no-hablan-japonés) | Cobertura | `言語/道具.zy` responde en `en` y `es`; el idioma base del programa no está | Abierto |

---

## GO-I18N-001 · La capa `api/` está documentada pero no existe

- **Archivos:** `DESIGN.md` §9, `README.md` (encabezado de validación)
- **Descripción:** `DESIGN.md` §9 se titula *«api/ — identifier-level API
  translation»* y muestra el contenido de `api/english.zy`:

  ```zymbol
  # .api_english {
      <# ../核/盤 => b
      #> { b::新規 => new_board, b::着手 => play, … }
  }
  ```

  `README.md` lo anuncia como uno de los dos niveles de i18n del proyecto:
  *«two levels of internationalization across five languages (runtime UI strings
  **and identifier-level API translation**)»*.

  No hay directorio `api/` en el árbol. Los cuatro puntos de entrada
  (`囲碁.zy`, `围棋.zy`, `바둑.zy`, `go.zy`) son idénticos salvo por el código de
  locale que preseleccionan:

  ```zymbol
  <# ./対局 => 対局
  対局::開始("en")
  ```

  Preseleccionan idioma de **interfaz**. No traducen ni un identificador. Un
  desarrollador que quiera escribir un front-end en inglés contra el motor sigue
  teniendo que abrir archivos en japonés.

- **Por qué importa:** es el único de los dos ejes de i18n que 囲碁 dice cubrir y
  no cubre. Además es el eje que `interpreter/I18N.md` Parte 1 documenta como
  mecanismo central del lenguaje (capas de re-export), así que 囲碁 debería ser su
  demostración de referencia.
- **Opciones:** implementar `api/english.zy` y `api/espanol.zy` tal como los
  describe el diseño — son re-exports puros, sin lógica ni coste en ejecución — o
  retirar la afirmación de `README.md` y la sección §9 de `DESIGN.md`.
- **Solución aplicada (2026-07-26):** implementados. `api/english.zy` y
  `api/espanol.zy` cubren la superficie pública completa de `核/` — 21 nombres de
  `盤`, 6 de `規則`, 4 de `計算`. Las constantes se reexportan con `.` y las
  funciones con `::`, y así se leen (`en.BLACK`, `en::play(…)`).
  `試験/api試験.zy` juega la misma jugada bajo los dos nombres y compara tablero,
  capturas y punto de ko —incluidos los parámetros de salida de `着手`, que es
  donde un reexport roto se notaría primero— en los dos motores. Está en
  `試験/全試験.sh`.

---

## GO-I18N-002 · `集計.zy` hila el idioma como parámetro booleano

- **Archivos:** `集計.zy` (L38–L79, L130, L144, L217–L281), `棋戦.zy` (L190–L230)
- **Descripción:** `集計.zy` resuelve su texto con una función local

  ```zymbol
  訳(鍵, 西) {
      ? 西 { <~ ?? 鍵 { "title" => "集計 — todas las tandas juntas"  … } }
      <~ ?? 鍵 { "title" => "集計 — every run together"  … }
  }
  ```

  El idioma es el booleano `西`, obtenido del argumento de línea de órdenes
  (L130, L144) y pasado a mano a los **quince** sitios de llamada. `集計.zy` no
  importa `言語/取次` ni una sola vez.

  Es exactamente el patrón que 囲碁 rechaza en el comentario de cabecera de
  `言語/取次.zy` — *«sin hilar el argumento de idioma por la cadena de llamadas»* —
  y el mismo que `DESIGN.md` §8 señala como el contraste deliberado con Hov veS.

  `棋戦.zy` mantiene un catálogo local **también**, pero eso está justificado y
  documentado en el propio archivo (L167–L188): los rótulos de un instrumento de
  medición no pertenecen al catálogo que existe para lo que lee un jugador. La
  diferencia decisiva es que `棋戦.zy` **sí** lee el locale del sitio correcto:

  ```zymbol
  訳(鍵) { ? 言::現在() == "es" { … } }
  ```

  y delega el vocabulario del juego a `言::語("棋力.N")`. `集計.zy` no hace ninguna
  de las dos cosas.

- **Coste añadido:** las claves están duplicadas entre los dos archivos
  (`"title"`, `"games"`, `"beg"`, `"int"`, `"adv"`, `"bal"`, `"off"`, `"def"`,
  `"warn"`) con valores que ya divergen. Ninguno de los dos catálogos pasa por
  `試験/言語検証.zy`, así que una traducción ausente en cualquiera de ellos no la
  detecta nada.
- **Opciones:** extraer el catálogo de rótulos de herramientas a un módulo propio
  —`言語/道具.zy`, mismo contrato de cuatro funciones, claves con prefijo
  (`集計.表題`, `棋戦.表題`)— consumido por los dos archivos, con `集計.zy` leyendo
  el locale de `言::現在()` y el parámetro `西` eliminado. El gate
  `試験/言語検証.zy` recorrería entonces también ese catálogo.
- **Solución aplicada (2026-07-26):** creado `言語/道具.zy` con 50 claves con
  prefijo de dominio (`共通.*`, `性格.*`, `棋戦.*`, `集計.*`) y su propio
  `言語一覧()`. Los dos archivos lo consumen a través de un `訳(鍵)` de una línea.
  `集計.zy` llama ahora a `言::設定()` con el argumento de línea de órdenes y el
  parámetro `西` desapareció de los quince sitios; sus nombres de nivel vienen de
  `言::語("棋力.N")`, que ya existían en el catálogo del jugador. El gate recorre
  el catálogo de herramientas (`50/50 OK` en `en` y `es`) y devuelve el locale a
  `ja` al terminar, porque el estado del despachador se comparte por ruta de
  archivo y una selección abandonada seguiría viva en la suite siguiente.
- **Extra:** la columna de rótulos de `集計.zy` era la constante `26`, que la
  traducción más larga del español (`sin terminar (sin summary)`) alcanzaba
  exactamente, pegando el rótulo al número. Ahora se mide con `文::幅` sobre los
  cuatro rótulos del idioma activo — punto 8 de la lista de comprobación de
  [USERAPPI18N.md](../interpreter/USERAPPI18N.md).

---

## GO-I18N-003 · `DESIGN.md` §8 se contradice a sí mismo

- **Archivo:** `DESIGN.md` §8
- **Descripción:** el ejemplo de código de la sección muestra claves **sin**
  prefijo de dominio:

  ```zymbol
  _日(キー) {
      <~ ?? キー {
          "手番"     => "手番"
          "終局"     => "終局"
          …
      }
  }
  ```

  Dos párrafos más abajo, el mismo documento explica por qué eso no puede ser:

  > *«Because every key carries a domain prefix and so can never equal its own
  > translation (`終局.石`, never plain `石`), that fallback is also what makes
  > completeness decidable»*

  Con la clave `"終局"` traducida como `"終局"`, el gate de `試験/言語検証.zy` la
  marcaría como ausente en japonés, que es precisamente el fallo que el prefijo
  existe para evitar. El código real (`言語/取次.zy` L131–L152) sí usa prefijos; el
  ejemplo del diseño no.

- **Por qué importa:** `DESIGN.md` §8 es la fuente que
  `interpreter/USERAPPI18N.md` cita como patrón de referencia. Un ejemplo que
  desmiente su propia regla es la manera más eficaz de propagar el error al
  siguiente proyecto.
- **Opción:** corregir el ejemplo a `"区画.手番" => "手番"`, `"終局.表題" => "終局"`.
- **Solución aplicada (2026-07-26):** ejemplo corregido, con una nota explícita de
  que el prefijo no es decoración. De paso se corrigieron dos afirmaciones más de
  §8: el número de sitios de llamada al despachador (64, ninguno con locale) y la
  descripción de Hov veS, que hilaba el idioma por **dos** módulos, no por cinco
  (ver [HOV-I18N-005](../klingon_galaxy/auditoria_i18n_es.md)). §9 se reescribió
  contra la implementación real y §8b documenta el catálogo de herramientas.

---

## GO-I18N-004 · Los instrumentos no hablan japonés

- **Archivo:** `言語/道具.zy`
- **Descripción:** el catálogo de herramientas responde en `en` y `es`. El juego
  responde en cinco idiomas, y el programa está escrito en japonés — pero quien lo
  escribió no puede leer el informe de `棋戦` ni el de `集計` en su propio idioma.
  Es el estado que ya tenían los dos catálogos locales antes de unificarlos; la
  unificación no lo empeoró, pero tampoco lo arregla.
- **Argumento a favor de dejarlo así:** `棋戦.zy` documenta que el instrumento no
  es el juego y que sus registros son forma de máquina. Un informe de banco de
  pruebas lo lee quien desarrolla el motor, no quien viene a jugar.
- **Argumento en contra:** «no hay inglés en este programa» fue el criterio del
  último commit del proyecto, y aquí el inglés es el idioma por defecto.
- **Opción:** añadir `ja` a `道::言語一覧()` y traducir las 50 claves. El gate lo
  verificaría solo. Queda a la espera de decisión: implementar / desestimar.

---

## Lo que **sí** está bien — y por qué es la referencia

Vale la pena dejarlo por escrito, porque es de donde sale la doctrina:

- **Locale como estado de módulo.** `言語/取次.zy` L58–L72. El estado de módulo se
  comparte por ruta de archivo, así que los 22 usos de `言::` en `表示/描画.zy`, los
  31 de `対局.zy` y los 11 de `棋戦.zy` ven la misma selección sin que nadie pase
  un argumento.
- **Claves en el idioma base, con prefijo de dominio.** 51 claves en `鍵一覧()`,
  todas con dominio (`終局.石`, `報せ.コウ`, `操作.投了`).
- **Fallback de identidad.** `_ => 鍵`: una traducción ausente se ve en pantalla.
- **Mensajes compuestos como funciones del locale.** `路盤名`, `結果文`, `取石文` y
  el privado `_点数` de cada idioma. Ninguna tabla estática podría producir
  `1目半` / `1집반승` / `1.5 points` / `1,5 puntos` a partir del mismo número.
- **Ninguna anchura tecleada a mano.** Todo pasa por `表示/文字::幅`, que envuelve
  `std/term::width` vía `標準/端末.zy`. Nunca `$#`.
- **Cambio de idioma en caliente** desde la pantalla de configuración de `対局.zy`.
- **Gate ejecutable.** `試験/言語検証.zy`: 51 claves × 5 locales, más los tres
  mensajes compuestos en los cinco idiomas. Está en `試験/全試験.sh`.

---

## Historial

- **2026-07-26** — Auditoría inicial. Tres hallazgos abiertos.
- **2026-07-26** — GO-I18N-001, 002 y 003 corregidos. Nuevo GO-I18N-004 abierto,
  a la espera de decisión. `bash 試験/全試験.sh` → `全試験 PASS` con la suite nueva
  `試験/api試験.zy` incluida.
