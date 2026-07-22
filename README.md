# 囲碁 (Igo)

> **Targets Zymbol v0.0.8**

The game of Go for the terminal, written entirely in Zymbol, with an AI opponent,
full rule enforcement, and automatic scoring.

囲碁 is the third real TUI game written in Zymbol, after
[Serpiente](https://github.com/zymbol-lang/zySerpiente) and
[Hov veS](https://github.com/zymbol-lang/zyKlingonGalaxy). It was built to
validate a different class of language capability: a large persistent data
structure (up to 361 points) threaded across cooperating modules, recursive
graph traversal (group and liberty detection by flood fill), a heuristic
decision engine, and a double-width glyph grid where every cell is exactly two
terminal columns.

> **Validation project for Zymbol v0.0.8** — stress-tests recursive flood fill
> at depth, multi-module state threading through isolated function scopes,
> double-width glyph layout under `>>~`, terminal-size gating with `>>?`, and
> two levels of internationalization across five languages (runtime UI strings
> and identifier-level API translation).

> **Español:** [README_ES.md](README_ES.md) · **Technical spec:** [DESIGN.md](DESIGN.md)
> · **Complexity test:** [棋戦.md](棋戦.md)

---

## Why Japanese?

The game was invented in China (围棋, *wéiqí*) and is played across Korea
(바둑, *baduk*) and Vietnam (cờ vây). It reached the West through Japan, which
is why the international name is *go* and why the vocabulary used worldwide —
*komi*, *atari*, *ko*, *hoshi*, *dame*, *jigo* — is Japanese.

So the code is written in Japanese. Every identifier, module name, and file
name uses kanji and kana; the rule vocabulary in the source is the same
vocabulary a player already knows. This also fills a gap in the Zymbol project:
Korean (Z-Tic-Tac-Toe), Klingon (Hov veS), Spanish and Greek (i18n test suite)
were already covered — Japanese was not.

The interface, though, is available in **five languages**: Japanese (日本語),
Korean (한국어), Mandarin (中文), English, and Spanish — the three languages the
game is actually played in across Asia, plus the two the project is documented
in. Adding a sixth (Vietnamese *cờ vây* is the obvious gap) is three edits: a
locale file, an import, one arm in each dispatch.

---

## How to play

Requires the [Zymbol interpreter](https://github.com/zymbol-lang/interpreter)
v0.0.8 or later:

```bash
git clone https://github.com/zymbol-lang/zy-GO
cd zy-GO
zymbol run 囲碁.zy
```

> Run with the tree-walker (the default). The register VM (`--vm`) has only
> partial module support; see [Limitations](#limitations).

### Terminal size

The game reads the real terminal size with `>>?` at startup and offers only the
board sizes that fit. Every board cell is exactly **two columns** wide, so the
board block measures `2N + 7` columns by `N + 2` rows.

| Board | Japanese | Minimum terminal | With side panel |
|-------|----------|------------------|-----------------|
| 9 × 9 | 九路盤 | 27 × 15 | 51 × 13 |
| 13 × 13 | 十三路盤 | 35 × 19 | 59 × 17 |
| 19 × 19 | 十九路盤 | 47 × 25 | 71 × 23 |

The side-by-side layout needs more columns but fewer rows, so a 19 × 19 board
fits a classic 80 × 24 terminal with the panel beside it.

Below the side-panel width the status panel is drawn under the board instead of
beside it. Below the minimum, that board size is greyed out in the setup screen
with the exact dimensions it needs. If the terminal is too small for even 9 × 9,
the game exits with a message rather than drawing a broken board.

---

## Controls

| Key | Action | Japanese |
|-----|--------|----------|
| `↑` `↓` `←` `→` | Move the cursor | カーソル移動 |
| `↵` | Place a stone at the cursor | 着手 |
| `p` | Pass | パス |
| `u` | Undo the last exchange (your move + the AI's reply) | 待った |
| `e` | Score estimate | 目算 |
| `t` | Cycle stone theme | 主題切替 |
| `?` | Help overlay | ヘルプ |
| `q` | Resign / quit | 投了 |

> **On the arrow keys.** `<<|` returns the arrow glyphs themselves — `'↑'`,
> `'↓'`, `'←'`, `'→'` — not the letters `'U'`, `'D'`, `'L'`, `'R'` that
> GUIDE.md §3b documents. The guide is wrong; Serpiente has been matching on
> the glyphs since v0.0.5. See [HALLAZGOS_ES.md](HALLAZGOS_ES.md) HLZ-006.

---

## Screens

### Setup — 対局設定

A single screen holds every choice. `↑` `↓` select the row, `←` `→` change the
value, `↵` starts the game.

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

Board sizes that do not fit the current terminal are shown dimmed with their
required size. Choosing an integer komi (6 or 7) makes 持碁 — a draw — possible;
the default 6.5 makes it impossible.

### Board — 対局

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

Columns are lettered `A`–`T` skipping `I`, the international convention; rows
count upward from the bottom. `╋` marks the 星 (hoshi) star points. `＋` is the
cursor over an empty intersection; over an occupied one the stone is drawn with
an inverted background. The status line under the board reports rejected moves,
captures, and pass announcements.

### End of game — 終局

Two consecutive passes end the game and scoring runs automatically:

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

Resignation reports 中押し勝ち (a win by resignation, no point count). An exact
tie reports 持碁 (jigo).

### The same game in another language

`围棋.zy` on a classic 80 × 24 terminal — 19 × 19 fits side by side with the
panel, and every label comes from the Mandarin locale:

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

`바둑.zy` on a narrow terminal, with the 月 theme. Below the side-panel width
the panel collapses to one dense line rather than a framed box, because a tall
narrow terminal cannot afford ten rows of frame:

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

## Themes — 主題

Three stone sets, switchable mid-game with `t`. Every cell stays exactly two
columns wide in all three, so the layout never shifts:

| Theme | Black | White | Width | Notes |
|-------|-------|-------|-------|-------|
| 石 (stone) | ⚫ | ⚪ | 2 columns | Default. Best terminal support among the emoji sets. |
| 月 (moon) | 🌑 | 🌕 | 2 columns | Same geometry, different mood. |
| 字 (ASCII) | `X` | `O` | 1 column + connector | Portable fallback for terminals that mis-measure emoji. |

The ASCII theme deliberately avoids `●` and `○`. Those characters are *East
Asian Ambiguous* width: one column in a Western terminal, two in a CJK-configured
one, which is exactly the class of glyph that breaks column arithmetic.

---

## Rules implemented

| Rule | Japanese | Behaviour |
|------|----------|-----------|
| Stones and chains | 石 · 連 | Orthogonally adjacent same-colour stones form one chain |
| Liberties | ダメ | Empty points adjacent to a chain |
| Capture | 取り · アゲハマ | A chain with zero liberties is removed and counted as prisoners |
| Capture precedence | — | Opponent chains are captured before the played stone's own liberties are checked |
| Suicide | 自殺手 | Illegal unless the move captures first |
| Ko | コウ | A move that recreates the immediately previous position is illegal |
| Pass | パス | Always legal |
| End of game | 終局 | Two consecutive passes — never decided by the program |
| Resignation | 投了 | `q` during play |
| Komi | コミ | Configurable; compensation added to White |
| Draw | 持碁 | Possible only with an integer komi |
| Star points | 星 | Drawn per board size; used by the opening book |

Positional superko (prohibiting *any* repeated whole-board position, not just
the previous one) is available as an option — it costs a position history, so
it is off by default.

### Knowing when to stop

Go has no automatic end. The game finishes when **both players pass**, because
only the players can judge that nothing worth playing is left — and a beginner
cannot yet make that judgement. So the program does not decide it, but it does
say when the side to move has no move that is neither illegal nor a self-filled
eye:

```
 nothing useful left — press p to pass
```

That is `核/思考.zy` reading the position: `眼()` decides whether an empty point
is an eye of a colour, `有用手()` lists the legal moves that are not one. The
same two functions are what the AI will be built on — an engine that fills its
own eyes is not an opponent, it is a suicide machine.

---

## Scoring — 計算

囲碁 scores by **area** (the Chinese method) and presents it with Japanese
vocabulary. Each player's score is their stones on the board plus the empty
points their stones fully surround; White then adds komi.

Area scoring was chosen for one decisive reason: it is fully computable by the
program. Japanese territory scoring requires both players to first *agree* on
which groups are dead — a negotiation phase that a beginner-strength AI cannot
resolve honestly, and getting it wrong means reporting the wrong winner. Area
scoring also handles 「セキ」 (seki) correctly with no special case, since shared
liberties simply count for nobody.

The two methods almost always agree within one point on the same final position,
so the result you see is the result a Japanese-rules count would give.

---

## The AI — 思考

The opponent is a layered heuristic move generator, not a search engine. For
each legal candidate it accumulates a score across the layers below, then plays
the best one — with an amount of randomness that depends on the level:

| Layer | Japanese | What it rewards |
|-------|----------|-----------------|
| 1 | 合法手 | Legality: no suicide, no ko, never fill your own eye |
| 2 | 取り | Capturing — weighted by how many stones come off |
| 3 | アタリ逃げ | Escaping atari, but only when the escape actually gains liberties |
| 4 | アタリ | Putting an opponent chain in atari |
| 5 | 形 | 3 × 3 shape patterns around the opponent's last move (hane, extension, connection, cut) |
| 6 | 勢力 | An influence map, favouring the boundary between the two spheres |
| 7 | 布石 | An opening book for the first moves: star and 3-4 points, never the first or second line |

| Level | Japanese | Behaviour |
|-------|----------|-----------|
| Beginner | 初級 | Layers 1–4 only, heavy randomness among the top candidates |
| Intermediate | 中級 | All layers, moderate randomness |
| Advanced | 上級 | All layers, wider candidate scan, near-deterministic |

**Honest strength estimate:** a weak beginner, somewhere around 25 kyu. It will
capture what you leave hanging, save its own stones from atari, refuse to fill
its own eyes, open in a corner and avoid the first two lines while the board is
open. It will not read a ladder to its conclusion or judge a life-and-death
problem. That is the point — the AI exists to prove the language can express a
non-trivial decision engine, not to beat you.

One term is not in the table above and earns its place: **self-atari**. Without
a penalty for leaving your own chain on one liberty while capturing nothing, the
engine walks into capture cheerfully and every other layer is wasted.

The level is a single number — how far below the best a move may score and still
be picked (60 / 25 / 5 points). A beginner is not a program that plays badly on
purpose; it is one that cannot tell a good move from a nearly-good one.

---

## Architecture

```
zy-GO/
├── 囲碁.zy              entry point, Japanese          ┐
├── 바둑.zy              entry point, Korean            │ same game,
├── 围棋.zy              entry point, Mandarin          │ preselected
├── go.zy                entry point, language menu     ┘ language
├── 対局.zy              match controller — turn loop, history, undo
├── 棋戦.zy              AI vs AI, instrumented — see 棋戦.md
├── 集計.zy              sums every run into one set of matrices
│                       records go to zy-GO-kifu (ZYGO_KIFU to redirect)
├── 核/                  engine
│   ├── 盤.zy            board state, chains, liberties, placement, capture
│   ├── 規則.zy          legality, ko, end-of-game detection
│   ├── 計算.zy          area scoring, komi, result
│   └── 思考.zy          AI move generation and evaluation
├── 表示/                presentation
│   ├── 文字.zy          display-width metrics, padding, truncation
│   ├── 描画.zy          board, cursor, panel, screens
│   └── 主題.zy          stone themes and layout arithmetic
├── 言語/                runtime UI strings
│   ├── module.zy        dispatcher, locale state, key catalogue
│   ├── 日本語.zy        ja
│   ├── 한국어.zy        ko
│   ├── 中文.zy          zh
│   ├── English.zy       en
│   └── Español.zy       es
├── 試験/                test suites
│   ├── 全試験.sh        runs everything
│   ├── 文字試験.zy      column arithmetic
│   ├── 言語検証.zy      i18n completeness gate
│   ├── 盤試験.zy        rule engine
│   ├── 計算試験.zy      scoring
│   ├── 性能試験.zy      recursion depth and 19×19 cost
│   └── 図.zy            text-diagram parser for readable test positions
└── api/                 identifier-level API translations
    ├── english.zy
    └── espanol.zy
```

Four entry points, one game. `囲碁.zy`, `바둑.zy` and `围棋.zy` differ only in the
locale they preselect; `go.zy` opens on the language menu and is there for the
terminal where typing CJK is inconvenient.

The board is a **flat array of `N × N` points**, 1-indexed, values `0` empty,
`1` black, `2` white. Point `(row, col)` lives at index `(row - 1) × N + col`.
A flat array beats a matrix here: it makes the neighbour arithmetic trivial and
avoids nested indexing in the innermost loop of the flood fill, which is the
hottest code in the program.

Because Zymbol functions called directly by name have **isolated scope** — only
their parameters are visible — the board is never global state. It is passed
explicitly to every function, and mutated through `<~` output parameters where
mutation is intended. See [DESIGN.md](DESIGN.md) for the full module contract.

---

## Internationalization

囲碁 uses **both** of Zymbol's i18n mechanisms, which solve different problems:

**Runtime UI strings** (`言語/`) — the text a player reads, in five languages.
`言語::設定(コード)` selects a locale by ISO 639-1 code and `言語::語(鍵)` returns
the string; the choice persists for the whole session as module state, so no
render function has to carry a language parameter.

Every locale implements the same four-function contract. `語(鍵)` is a static
lookup, and the other three compose sentences — because a static table cannot
express "White wins by 1.5 points" in five grammars:

| Function | Purpose |
|----------|---------|
| `語(鍵)` | static string for a key |
| `路盤名(路)` | board name — 九路盤 · 9줄 바둑판 · 九路棋盘 · 9×9 |
| `結果文(勝色, 差, 中押)` | the result sentence — 白の1目半勝ち · 백 1집반승 · 白胜1目半 · White wins by 1.5 points · las blancas ganan por 1,5 puntos |
| `取石文(数)` | capture announcement, with plural agreement where the language needs it |

Keys are neutral ASCII identifiers (`panel.captures`, `msg.ko`), never Japanese
words. That is what makes the system verifiable: a locale missing a key returns
the key itself, so `試験/言語検証.zy` walks the master catalogue against every
locale and fails on any string that comes back unchanged. Adding a language is
three edits and the gate tells you immediately what you forgot.

**Identifier-level API translation** (`api/`) — pure re-export layers that expose
the engine's public API under English and Spanish names, with zero logic and
zero runtime cost. A developer who does not read Japanese can write their own
front-end against `board::place(...)` or `tablero::colocar(...)` and never open
a Japanese source file. This is the three-layer pattern from
[I18N.md](../interpreter/I18N.md), applied to a real engine rather than a test
fixture.

---

## Limitations

1. **Dead stones count as alive.** Area scoring assumes dead stones have actually
   been captured. If the game ends with dead stones still on the board, they
   count for their owner. Standard practice applies: keep playing until the dead
   groups are off the board. Heuristic dead-group detection is on the roadmap.
2. **Beginner-strength AI.** See above. No ladder reading, no life-and-death
   solving, no endgame counting.
3. **Simple ko only by default.** Positional superko is opt-in.
4. **Emoji width depends on your terminal and font.** If stones straddle their
   cells, switch to the 字 theme with `t`.
5. **Both engines now.** The project shipped tree-walker only because `--vm`
   silently dropped output parameters of module functions (HLZ-008) and could
   not slice a String inside one (HLZ-009). Both are fixed in the interpreter,
   and all six suites — plus the game itself — now run identically under
   `zymbol run` and `zymbol run --vm`.

---

## Status

| Phase | Content | State |
|-------|---------|-------|
| 1 | i18n foundation: five locales, dispatcher, key catalogue, completeness gate | **done** |
| 2 | 表示/文字: display-width metrics for CJK, emoji and fullwidth glyphs | **done** |
| 3 | 核/盤 + 核/規則: chains, liberties, capture, suicide, ko, legality | **done** |
| 4 | 核/計算: area scoring, komi, 持碁, ownership map | **done** |
| 5 | 表示/描画 + 表示/主題: board, themes, cursor, panel, `>>?` gating | **done** |
| 6 | 対局 + entry points: turn loop, history, 待った, the four launchers | **done** — hot-seat |
| 7 | 核/思考: eye detection (眼) and useful-move enumeration (有用手) | **done** |
| 8 | 核/思考: the AI and its three levels | **done** |
| 9 | 棋戦: AI vs AI harness — timing, memory, level and personality statistics, replayable game records | **done** |
|   | *400 games: Beginner loses 90% to both other levels, but Intermediate against Advanced is a coin flip. Memory moved 96 KB over 200 games.* | |
|   | *and the register VM turns out to be 8–14× faster than the tree-walker on this workload, not the ~4× the docs claim* | |
| 10 | api/: identifier-level API translation layers | pending |
| 11 | 棋譜 (SGF export), 置き碁 (handicap), positional superko, TW vs VM benchmark | pending |

Everything marked done is covered by `試験/全試験.sh`:

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

There is an opponent now. Measured on the machine that built it: **0.18 s per
move on 9 × 9**, 0.62 s on 19 × 19 — a full self-play game of 93 moves ran in
16 seconds and proposed **zero illegal moves**.

Rule cases are written as text diagrams so they can be checked by eye:

```zymbol
局面 = 図::読図([
    ".OX..",
    "O.OX.",      // black plays 7 and captures the white stone at 8;
    ".OX..",      // white may not recapture at 8 — that is the ko
    ".....",
    "....."
])
```

---

## Zymbol primitives used

| Primitive | Use in 囲碁 |
|-----------|-------------|
| `>>\| { }` | TUI block — alternate screen, raw mode |
| `>>~ (r, c, BKS, fg, bg) > items` | Positioned output; the entire board, panel, and cursor |
| `>>!` | Clear screen (screen transitions) |
| `>>?` | Real terminal size — board availability and layout selection |
| `<<\| var` | Blocking key read (the game is turn-based, not real-time) |
| `fn(x<~)` | Output parameters — board mutation across module boundaries |
| `<# ./path => alias` | Module imports across three subdirectories |
| `#> { alias::fn => name }` | Re-export — the API translation layers |
| Module state | Language selection, prisoner counts, position history |
| `??` match | String tables, result phrasing, pattern classification |

---

## Language findings

Bugs, gaps, and ideas found while building 囲碁 are documented in
[HALLAZGOS_ES.md](HALLAZGOS_ES.md) (Spanish), following the convention of
Serpiente and Hov veS.

| ID | Type | Description | State |
|----|------|-------------|-------|
| HLZ-001 | Gap | `CONST := -1` inside a module is E013 — a signed literal parses as an expression | API redesigned around it |
| HLZ-002 | Bug | An array index computed from function parameters fails analysis with "must be Int, got Float" | Workaround: `##!` cast in one place |
| HLZ-003 | Bug | `##.0 == 0` is `#0` while `##.0 >= 0` and `##.0 <= 0` are both `#1` | Open |
| HLZ-004 | Bug (LSP) | The documented dot convention for subfolder modules is flagged E001 by the language server, though the interpreter runs it | Open |
| HLZ-005 | Gap | `<# ./../x` does not parse; `<# ../x` is required, and the error does not say so | Documented |
| IDEA-001 | Idea | No primitive measures display width; `0d\|c\|` string-parsing is the only Char→Int route | Proposed |

**Seven of the nine are now fixed in the interpreter**, each with a regression
test, and the parity suite runs them in both engines so they cannot diverge
again unnoticed. See the interpreter CHANGELOG for v0.0.8.

HLZ-003 is the sharp one: both values print identically, so a failing assertion
reads `expected 0, got 0`. Go scores are half-integers because of komi, which
puts every score on the Float side of that divide.

The double-width problem that bit Serpiente as
[BUG-004](https://github.com/zymbol-lang/zySerpiente) — a two-column emoji stored
at a single coordinate — is answered here structurally rather than by special
case: **every board cell is two columns wide in every theme**, so a stone fills
its cell exactly and the grid arithmetic has no seams. `試験/文字試験.zy` asserts
it directly, checking that a board row measures the same in all three themes.

### What did not fail

These were the declared risks in [DESIGN.md](DESIGN.md), and the engine cleared
all four:

| Risk | Measured |
|------|----------|
| Flood-fill recursion depth | A 360-stone chain on 19 × 19 traverses fine in the tree-walker |
| Full legality scan cost | 287 points evaluated in 0.38 s total, board copy included per point |
| Output parameters across module boundaries | `局面<~` mutates correctly through modules, recursion and nested calls |
| Module state for the active locale | Persists per file path; no module needs a language parameter |
