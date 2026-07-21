# 囲碁 (Igo)

> **Dirigido a Zymbol v0.0.8**

El juego del go para terminal, escrito íntegramente en Zymbol, con oponente de
IA, validación completa de reglas y puntuación automática.

囲碁 es el tercer juego TUI real escrito en Zymbol, después de
[Serpiente](https://github.com/zymbol-lang/zySerpiente) y
[Hov veS](https://github.com/zymbol-lang/zyKlingonGalaxy). Se construyó para
validar otra clase de capacidad del lenguaje: una estructura de datos grande y
persistente (hasta 361 puntos) atravesando módulos que cooperan, recorrido
recursivo de grafos (detección de cadenas y libertades por flood fill), un motor
de decisión heurístico, y una rejilla de glifos de doble ancho donde cada celda
ocupa exactamente dos columnas de terminal.

> **Proyecto de validación para Zymbol v0.0.8** — pone a prueba el flood fill
> recursivo en profundidad, el hilado de estado entre módulos con ámbitos de
> función aislados, la maquetación de glifos de doble ancho bajo `>>~`, el
> control de tamaño de terminal con `>>?`, y dos niveles de internacionalización
> en cinco idiomas (textos de interfaz en tiempo de ejecución y traducción de la
> API a nivel de identificadores).

> **English:** [README.md](README.md) · **Especificación técnica:** [DESIGN.md](DESIGN.md)

---

## ¿Por qué en japonés?

El juego se inventó en China (围棋, *wéiqí*) y se juega en Corea (바둑, *baduk*)
y Vietnam (cờ vây). Llegó a Occidente a través de Japón, y por eso el nombre
internacional es *go* y por eso el vocabulario que se usa en todo el mundo —
*komi*, *atari*, *ko*, *hoshi*, *dame*, *jigo* — es japonés.

Así que el código está escrito en japonés. Cada identificador, nombre de módulo
y nombre de archivo usa kanji y kana; el vocabulario de las reglas en el código
fuente es el mismo que un jugador ya conoce. Además cubre un hueco del proyecto
Zymbol: coreano (Z-Tic-Tac-Toe), klingon (Hov veS), español y griego (suite de
i18n) ya estaban cubiertos — el japonés no.

La interfaz, en cambio, está disponible en **cinco idiomas**: japonés (日本語),
coreano (한국어), mandarín (中文), inglés y español — los tres idiomas en los que
realmente se juega en Asia, más los dos en los que está documentado el proyecto.
Añadir un sexto (el vietnamita *cờ vây* es el hueco evidente) son tres ediciones:
un archivo de idioma, un import y un caso en cada despacho.

---

## Cómo jugar

Requiere el [intérprete de Zymbol](https://github.com/zymbol-lang/interpreter)
v0.0.8 o superior:

```bash
git clone https://github.com/zymbol-lang/zy-GO
cd zy-GO
zymbol run 囲碁.zy
```

> Ejecutar con el tree-walker (el predeterminado). La VM de registros (`--vm`)
> solo tiene soporte parcial de módulos; ver [Limitaciones](#limitaciones).

### Tamaño de terminal

El juego lee el tamaño real de la terminal con `>>?` al arrancar y ofrece solo
los tableros que caben. Cada celda del tablero mide exactamente **dos columnas**,
así que el bloque del tablero ocupa `2N + 7` columnas por `N + 2` filas.

| Tablero | Japonés | Terminal mínima | Con panel lateral |
|---------|---------|-----------------|-------------------|
| 9 × 9 | 九路盤 | 27 × 15 | 51 × 13 |
| 13 × 13 | 十三路盤 | 35 × 19 | 59 × 17 |
| 19 × 19 | 十九路盤 | 47 × 25 | 71 × 23 |

La maquetación lateral necesita más columnas pero menos filas, así que un
tablero de 19 × 19 cabe en una terminal clásica de 80 × 24 con el panel al lado.

Por debajo del ancho con panel lateral, el panel de estado se dibuja debajo del
tablero en vez de al lado. Por debajo del mínimo, ese tamaño aparece atenuado en
la pantalla de configuración indicando las dimensiones exactas que necesita. Si
la terminal no da ni para 9 × 9, el juego sale con un mensaje en lugar de dibujar
un tablero roto.

---

## Controles

| Tecla | Acción | Japonés |
|-------|--------|---------|
| `↑` `↓` `←` `→` | Mover el cursor | カーソル移動 |
| `↵` | Colocar piedra en el cursor | 着手 |
| `p` | Pasar | パス |
| `u` | Deshacer el último intercambio (tu jugada + la respuesta de la IA) | 待った |
| `e` | Estimación de puntuación | 目算 |
| `t` | Cambiar el tema de fichas | 主題切替 |
| `?` | Ayuda | ヘルプ |
| `q` | Abandonar / salir | 投了 |

> **Sobre las flechas.** `<<|` devuelve los propios glifos de flecha — `'↑'`,
> `'↓'`, `'←'`, `'→'` — y no las letras `'U'`, `'D'`, `'L'`, `'R'` que documenta
> GUIDE.md §3b. La guía está equivocada; Serpiente compara contra los glifos
> desde la v0.0.5. Ver [HALLAZGOS_ES.md](HALLAZGOS_ES.md) HLZ-006.

---

## Pantallas

### Configuración — 対局設定

Una sola pantalla contiene todas las opciones. `↑` `↓` eligen la fila, `←` `→`
cambian el valor, `↵` empieza la partida.

```
     ╭──────────────────────────────────────╮
     │                 囲碁                 │
     │            Zymbol v0.0.8             │
     ├──────────────────────────────────────┤
     │ ► 路盤        ‹    九路盤    ›       │
     │   コミ        ‹     6.5      ›       │
     │   主題        ‹      石      ›       │
     │   言語        ‹    日本語    ›       │
     ├──────────────────────────────────────┤
     │      ↑↓ 選択   ←→ 変更   ↵ 開始      │
     ╰──────────────────────────────────────╯
```

Los tamaños que no caben en la terminal actual se muestran atenuados con el
tamaño que requieren. Elegir un komi entero (6 o 7) hace posible el 持碁 — el
empate técnico —; el 6.5 por defecto lo hace imposible.

### Tablero — 対局

```
      A B C D E F G H J     ╭──────────────────────╮
    9 ┌─┬─┬─┬─┬─┬─┬─┬─┐  9  │ 九路盤               │
    8 ├─┼─┼─┼─┼─┼─┼─┼─┤  8  ├──────────────────────┤
    7 ├─┼─╋─┼─┼─┼─╋─┼─┤  7  │ 手番      ⚫ 黒      │
    6 ├─┼─┼─⚫┼─⚪┼─┼─┤  6  │ 手数      6          │
    5 ├─┼─┼─┼─⚫⚫┼─┼─┤  5  │ アゲハマ  ⚫0  ⚪0   │
    4 ├─┼─┼─⚪┼─┼─┼─┼─┤  4  │ コミ      6.5        │
    3 ├─┼─╋─┼─⚪┼─╋─┼─┤  3  │ 最終手    E3         │
    2 ├─┼─┼─┼─┼─┼─┼─┼─┤  2  │ 目算      ⚪ +6.5    │
    1 └─┴─┴─┴─┴─┴─┴─┴─┘  1  ╰──────────────────────╯
      A B C D E F G H J

 1子を取った
```

Las columnas se etiquetan `A`–`T` saltando la `I`, la convención internacional;
las filas se cuentan desde abajo. `╋` marca los puntos 星 (hoshi). `＋` es el
cursor sobre una intersección vacía; sobre una ocupada, la piedra se dibuja con
el fondo invertido. La línea de estado bajo el tablero informa de jugadas
rechazadas, capturas y pases.

### Fin de partida — 終局

Dos pases consecutivos terminan la partida y el recuento se ejecuta solo:

```
     ╭──────────────────────╮
     │         終局         │
     ├──────────────────────┤
     │           ⚫    ⚪   │
     │ 石        2     0    │
     │ 地        79    0    │
     │ コミ      —     6.5  │
     ├──────────────────────┤
     │ 合計      81    6.5  │
     ├──────────────────────┤
     │    黒の74目半勝ち    │
     ╰──────────────────────╯
```

El abandono reporta 中押し勝ち (victoria por abandono, sin recuento de puntos).
Un empate exacto reporta 持碁 (jigo).

### La misma partida en otro idioma

`围棋.zy` en una terminal clásica de 80 × 24 — el 19 × 19 cabe con el panel al
lado, y todas las etiquetas salen del idioma mandarín:

```
      A B C D E F G H J K L M N O P Q R S T     ╭──────────────────────╮
   19 ┌─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┬─┐ 19  │ 十九路棋盘           │
   18 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤ 18  ├──────────────────────┤
   17 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤ 17  │ 轮到      ⚫ 黑      │
   16 ├─┼─┼─╋─┼─┼─┼─┼─┼─╋─┼─┼─┼─┼─┼─╋─┼─┼─┤ 16  │ 手数      2          │
   15 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤ 15  │ 提子      ⚫0  ⚪0   │
   14 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤ 14  │ 贴目      6.5        │
   13 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤ 13  │ 最后一手  L11        │
   12 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┼─┤ 12  │ 形势判断  ⚪ +6.5    │
   11 ├─┼─┼─┼─┼─┼─┼─┼─┼─┼─⚪┼─┼─┼─┼─┼─┼─┼─┤ 11  ╰──────────────────────╯
   10 ├─┼─┼─╋─┼─┼─┼─┼─┼─⚫┼─┼─┼─┼─┼─╋─┼─┼─┤ 10
      ⋮                                    ⋮
    1 └─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┴─┘  1
      A B C D E F G H J K L M N O P Q R S T
```

`바둑.zy` en una terminal estrecha, con el tema 月. Por debajo del ancho con
panel lateral, el panel se reduce a una sola línea densa en vez de una caja: una
terminal alta y estrecha no puede permitirse diez filas de marco:

```
      A B C D E F G H J
    9 ┌─┬─┬─┬─┬─┬─┬─┬─┐  9
    8 ├─┼─┼─┼─┼─┼─┼─┼─┤  8
    7 ├─┼─╋─┼─┼─┼─╋─┼─┤  7
    6 ├─┼─┼─┼─┼─┼─┼─┼─┤  6
    5 ├─┼─┼─┼─🌑🌕┼─┼─┤  5
    4 ├─┼─┼─┼─┼─┼─┼─┼─┤  4
    3 ├─┼─╋─┼─┼─┼─╋─┼─┤  3
    2 ├─┼─┼─┼─┼─┼─┼─┼─┤  2
    1 └─┴─┴─┴─┴─┴─┴─┴─┘  1
      A B C D E F G H J
 🌑 흑   2   🌑0 🌕0   F5
```

---

## Temas — 主題

Tres juegos de fichas, conmutables en partida con `t`. Cada celda sigue midiendo
exactamente dos columnas en los tres, así que la maquetación nunca se desplaza:

| Tema | Negras | Blancas | Ancho | Notas |
|------|--------|---------|-------|-------|
| 石 (piedra) | ⚫ | ⚪ | 2 columnas | Por defecto. El mejor soporte de terminal entre los emojis. |
| 月 (luna) | 🌑 | 🌕 | 2 columnas | Misma geometría, otra atmósfera. |
| 字 (ASCII) | `X` | `O` | 1 columna + conector | Alternativa portable para terminales que miden mal los emojis. |

El tema ASCII evita deliberadamente `●` y `○`. Esos caracteres son de ancho
*East Asian Ambiguous*: una columna en una terminal occidental, dos en una
configurada para CJK — exactamente la clase de glifo que rompe la aritmética de
columnas.

---

## Reglas implementadas

| Regla | Japonés | Comportamiento |
|-------|---------|----------------|
| Piedras y cadenas | 石 · 連 | Piedras del mismo color ortogonalmente adyacentes forman una cadena |
| Libertades | ダメ | Puntos vacíos adyacentes a una cadena |
| Captura | 取り · アゲハマ | Una cadena sin libertades se retira y cuenta como prisioneros |
| Orden de captura | — | Las cadenas rivales se capturan antes de comprobar las libertades de la piedra jugada |
| Suicidio | 自殺手 | Ilegal, salvo que la jugada capture primero |
| Ko | コウ | Es ilegal recrear la posición inmediatamente anterior |
| Pase | パス | Siempre legal |
| Fin de partida | 終局 | Dos pases consecutivos — nunca lo decide el programa |
| Abandono | 投了 | `q` durante la partida |
| Komi | コミ | Configurable; compensación sumada a blancas |
| Empate | 持碁 | Solo posible con komi entero |
| Puntos estrella | 星 | Dibujados según el tamaño; los usa el libro de aperturas |

El superko posicional (prohibir *cualquier* posición repetida del tablero
completo, no solo la anterior) está disponible como opción — cuesta mantener un
historial de posiciones, así que viene desactivado.

### Saber cuándo parar

El go no tiene final automático. La partida termina cuando **ambos jugadores
pasan**, porque solo los jugadores pueden juzgar que no queda nada que valga la
pena jugar — y un principiante todavía no sabe hacer ese juicio. Así que el
programa no lo decide, pero sí avisa cuando quien tiene el turno no dispone de
ninguna jugada que no sea ilegal o rellenar un ojo propio:

```
 no queda nada útil — pulsa p para pasar
```

Eso es `核/思考.zy` leyendo la posición: `眼()` decide si un punto vacío es un
ojo de un color y `有用手()` lista las jugadas legales que no lo son. Esas dos
funciones son la base sobre la que se construirá la IA — un motor que rellena
sus propios ojos no es un rival, es una máquina de suicidarse.

---

## Puntuación — 計算

囲碁 puntúa por **área** (el método chino) y lo presenta con vocabulario
japonés. La puntuación de cada jugador son sus piedras en el tablero más los
puntos vacíos que sus piedras rodean por completo; blancas suman después el komi.

Se eligió la puntuación por área por una razón decisiva: es totalmente
computable por el programa. La puntuación japonesa por territorio exige que
ambos jugadores *acuerden* primero qué grupos están muertos — una fase de
negociación que una IA de nivel principiante no puede resolver con honestidad,
y equivocarse ahí significa anunciar al ganador equivocado. La puntuación por
área además resuelve el 「セキ」 (seki) correctamente sin ningún caso especial,
porque las libertades compartidas simplemente no cuentan para nadie.

Los dos métodos casi siempre coinciden dentro de un punto sobre la misma
posición final, así que el resultado que ves es el que daría un recuento con
reglas japonesas.

---

## La IA — 思考

El oponente es un generador de jugadas heurístico por capas, no un motor de
búsqueda. Para cada candidata legal acumula una puntuación a lo largo de las
capas siguientes y juega la mejor — con una cantidad de aleatoriedad que depende
del nivel:

| Capa | Japonés | Qué premia |
|------|---------|------------|
| 1 | 合法手 | Legalidad: sin suicidio, sin ko, nunca rellenar un ojo propio |
| 2 | 取り | Capturar — ponderado por cuántas piedras se llevan |
| 3 | アタリ逃げ | Escapar del atari, pero solo cuando la fuga gana libertades de verdad |
| 4 | アタリ | Poner en atari una cadena rival |
| 5 | 形 | Patrones de forma 3 × 3 alrededor de la última jugada rival (hane, extensión, conexión, corte) |
| 6 | 勢力 | Un mapa de influencia, favoreciendo la frontera entre ambas esferas |
| 7 | 布石 | Libro de aperturas para las primeras jugadas: puntos estrella y 3-4, nunca primera ni segunda línea |

| Nivel | Japonés | Comportamiento |
|-------|---------|----------------|
| Principiante | 初級 | Solo capas 1–4, mucha aleatoriedad entre las mejores candidatas |
| Intermedio | 中級 | Todas las capas, aleatoriedad moderada |
| Avanzado | 上級 | Todas las capas, barrido de candidatas más amplio, casi determinista |

**Estimación honesta de fuerza:** un principiante flojo, en torno a 25 kyu.
Capturará lo que dejes colgando, salvará sus piedras del atari y no rellenará
sus propios ojos. No leerá una escalera hasta el final ni resolverá un problema
de vida y muerte. Y ese es el objetivo — la IA existe para demostrar que el
lenguaje puede expresar un motor de decisión no trivial, no para ganarte.

---

## Arquitectura

```
zy-GO/
├── 囲碁.zy              punto de entrada, japonés      ┐
├── 바둑.zy              punto de entrada, coreano      │ el mismo juego,
├── 围棋.zy              punto de entrada, mandarín     │ con el idioma
├── go.zy                punto de entrada, menú         ┘ preseleccionado
├── 対局.zy              controlador de partida — turnos, historial, deshacer
├── 核/                  motor
│   ├── 盤.zy            estado del tablero, cadenas, libertades, colocación, captura
│   ├── 規則.zy          legalidad, ko, detección de fin de partida
│   ├── 計算.zy          puntuación por área, komi, resultado
│   └── 思考.zy          generación y evaluación de jugadas de la IA
├── 表示/                presentación
│   ├── 文字.zy          métricas de ancho, relleno, truncado
│   ├── 描画.zy          tablero, cursor, panel, pantallas
│   └── 主題.zy          temas de fichas y aritmética de maquetación
├── 言語/                textos de interfaz en tiempo de ejecución
│   ├── module.zy        despachador, estado del idioma, catálogo de claves
│   ├── 日本語.zy        ja
│   ├── 한국어.zy        ko
│   ├── 中文.zy          zh
│   ├── English.zy       en
│   └── Español.zy       es
├── 試験/                suites de prueba
│   ├── 全試験.sh        ejecuta todo
│   ├── 文字試験.zy      aritmética de columnas
│   ├── 言語検証.zy      puerta de completitud i18n
│   ├── 盤試験.zy        motor de reglas
│   ├── 計算試験.zy      puntuación
│   ├── 性能試験.zy      profundidad de recursión y coste en 19×19
│   └── 図.zy            lector de diagramas de texto para posiciones de prueba
└── api/                 traducciones de la API a nivel de identificadores
    ├── english.zy
    └── espanol.zy
```

Cuatro puntos de entrada, un solo juego. `囲碁.zy`, `바둑.zy` y `围棋.zy` solo se
diferencian en el idioma que preseleccionan; `go.zy` abre en el menú de idiomas y
existe para la terminal donde escribir CJK es incómodo.

El tablero es un **array plano de `N × N` puntos**, indexado desde 1, con
valores `0` vacío, `1` negras, `2` blancas. El punto `(fila, columna)` vive en
el índice `(fila - 1) × N + columna`. Un array plano gana a una matriz aquí:
hace trivial la aritmética de vecinos y evita la indexación anidada en el bucle
más interno del flood fill, que es el código más caliente del programa.

Como las funciones de Zymbol llamadas directamente por nombre tienen **ámbito
aislado** — solo ven sus parámetros —, el tablero nunca es estado global. Se
pasa explícitamente a cada función y se muta mediante parámetros de salida `<~`
allí donde la mutación es intencionada. Ver [DESIGN.md](DESIGN.md) para el
contrato completo de módulos.

---

## Internacionalización

囲碁 usa **los dos** mecanismos de i18n de Zymbol, que resuelven problemas
distintos:

**Textos de interfaz en tiempo de ejecución** (`言語/`) — lo que lee el jugador,
en cinco idiomas. `言語::設定(コード)` selecciona el idioma por código ISO 639-1 y
`言語::語(鍵)` devuelve la cadena; la elección persiste toda la sesión como estado
de módulo, así que ninguna función de dibujo tiene que arrastrar un parámetro de
idioma.

Cada idioma implementa el mismo contrato de cuatro funciones. `語(鍵)` es una
búsqueda estática; las otras tres **componen** frases, porque una tabla estática
no puede expresar «blancas ganan por 1,5 puntos» en cinco gramáticas:

| Función | Propósito |
|---------|-----------|
| `語(鍵)` | cadena estática para una clave |
| `路盤名(路)` | nombre del tablero — 九路盤 · 9줄 바둑판 · 九路棋盘 · 9×9 |
| `結果文(勝色, 差, 中押)` | la frase de resultado — 白の1目半勝ち · 백 1집반승 · 白胜1目半 · White wins by 1.5 points · las blancas ganan por 1,5 puntos |
| `取石文(数)` | anuncio de captura, con concordancia de plural donde el idioma la necesita |

Las claves son identificadores ASCII neutros (`panel.captures`, `msg.ko`), nunca
palabras japonesas. Eso es lo que hace el sistema verificable: un idioma al que
le falte una clave devuelve la clave misma, así que `試験/言語検証.zy` recorre el
catálogo maestro contra cada idioma y falla ante cualquier cadena que vuelva sin
cambiar. Añadir un idioma son tres ediciones, y la puerta te dice al instante qué
olvidaste.

**Traducción de la API a nivel de identificadores** (`api/`) — capas de
reexportación puras que exponen la API pública del motor con nombres en inglés y
español, sin lógica y sin coste en ejecución. Alguien que no lea japonés puede
escribir su propio front-end contra `board::place(...)` o
`tablero::colocar(...)` sin abrir nunca un archivo fuente en japonés. Es el
patrón de tres capas de [I18N.md](../interpreter/I18N.md), aplicado a un motor
real y no a un fixture de pruebas.

---

## Limitaciones

1. **Las piedras muertas cuentan como vivas.** La puntuación por área asume que
   las piedras muertas se han capturado de verdad. Si la partida termina con
   piedras muertas en el tablero, cuentan para su dueño. Aplica la práctica
   habitual: seguir jugando hasta retirar los grupos muertos. La detección
   heurística de grupos muertos está en la hoja de ruta.
2. **IA de nivel principiante.** Ver arriba. Sin lectura de escaleras, sin vida
   y muerte, sin cálculo de final.
3. **Solo ko simple por defecto.** El superko posicional es opcional.
4. **El ancho de los emojis depende de tu terminal y tu fuente.** Si las piedras
   se salen de su celda, cambia al tema 字 con `t`.
5. **Solo tree-walker por ahora.** El soporte de módulos en `--vm` es parcial; la
   paridad con la VM es un punto de la hoja de ruta, y el tiempo de turno de la
   IA en ambos motores es uno de los benchmarks que este proyecto debe producir.

---

## Estado

| Fase | Contenido | Estado |
|------|-----------|--------|
| 1 | Base i18n: cinco idiomas, despachador, catálogo de claves, puerta de completitud | **hecho** |
| 2 | 表示/文字: métricas de ancho para CJK, emoji y formas de ancho completo | **hecho** |
| 3 | 核/盤 + 核/規則: cadenas, libertades, captura, suicidio, ko, legalidad | **hecho** |
| 4 | 核/計算: puntuación por área, komi, 持碁, mapa de propiedad | **hecho** |
| 5 | 表示/描画 + 表示/主題: tablero, temas, cursor, panel, control con `>>?` | **hecho** |
| 6 | 対局 + puntos de entrada: bucle de turnos, historial, 待った, los cuatro lanzadores | **hecho** — por turnos |
| 7 | 核/思考: detección de ojos (眼) y jugadas útiles (有用手) | **hecho** |
| 8 | 核/思考: la IA propiamente dicha y sus tres niveles | pendiente |
| 9 | api/: capas de traducción de la API a nivel de identificadores | pendiente |
| 10 | 棋譜 (exportación SGF), 置き碁 (handicap), superko posicional, benchmark TW contra VM | pendiente |

Todo lo marcado como hecho está cubierto por `試験/全試験.sh`:

```bash
bash 試験/全試験.sh
```

```
─── 試験/文字試験.zy    PASS — column arithmetic holds
─── 試験/言語検証.zy    PASS — every key resolves in every locale
─── 試験/盤試験.zy      PASS — every rule case behaved
─── 試験/計算試験.zy    PASS — scoring behaved
─── 試験/描画試験.zy    PASS — the grid holds together
全試験 PASS
```

El juego ya es jugable, dos personas en un mismo teclado. La fase 7 sustituye a
una de ellas por 核/思考.zy.

Los casos de reglas se escriben como diagramas de texto, para poder comprobarlos
a ojo:

```zymbol
局面 = 図::読図([
    ".OX..",
    "O.OX.",      // negras juegan 7 y capturan la piedra blanca de 8;
    ".OX..",      // blancas no pueden recapturar en 8 — eso es el ko
    ".....",
    "....."
])
```

---

## Primitivas de Zymbol usadas

| Primitiva | Uso en 囲碁 |
|-----------|-------------|
| `>>\| { }` | Bloque TUI — pantalla alterna, raw mode |
| `>>~ (f, c, BKS, fg, bg) > items` | Salida posicionada; todo el tablero, el panel y el cursor |
| `>>!` | Limpiar pantalla (transiciones) |
| `>>?` | Tamaño real de la terminal — disponibilidad de tableros y elección de maquetación |
| `<<\| var` | Lectura de tecla bloqueante (el juego es por turnos, no en tiempo real) |
| `fn(x<~)` | Parámetros de salida — mutación del tablero a través de fronteras de módulo |
| `<# ./ruta => alias` | Importaciones de módulos en tres subdirectorios |
| `#> { alias::fn => nombre }` | Reexportación — las capas de traducción de la API |
| Estado de módulo | Idioma seleccionado, contadores de prisioneros, historial de posiciones |
| Match `??` | Tablas de cadenas, redacción del resultado, clasificación de patrones |

---

## Hallazgos del lenguaje

Los bugs, carencias e ideas de mejora encontrados al construir 囲碁 se
documentarán en `HALLAZGOS_ES.md`, siguiendo la convención de Serpiente y
Hov veS.

Uno ya se conoce de antemano. Serpiente lo encontró como
[BUG-004](https://github.com/zymbol-lang/zySerpiente): el emoji de la fruta
ocupaba dos columnas de terminal pero se almacenaba en una sola coordenada, así
que la serpiente podía entrar por la columna derecha sin registrar la colisión,
y borrar el emoji exigía limpiar dos columnas. 囲碁 responde a esto de forma
estructural y no con un caso especial — **cada celda del tablero mide dos
columnas en todos los temas**, así que una piedra llena su celda exactamente y
la aritmética de la rejilla no tiene costuras. Si eso se sostiene en las
terminales reales es una de las cosas que este proyecto está aquí para
averiguar.
