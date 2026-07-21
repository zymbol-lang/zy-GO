# 囲碁 — Technical Design

Implementation specification for [zy-GO](README.md). Written against Zymbol
v0.0.8, tree-walker execution path.

This document exists because most of the interesting decisions in this project
are forced by the language, not by Go. Zymbol has no global mutable state
reachable from functions, no hash maps with dynamic keys, and no executable
statements at module top level. Each of those shapes the design below.

---

## 1. Language constraints that drive the design

| Constraint | Source | Consequence here |
|------------|--------|------------------|
| Functions called by name see **only their parameters** | GUIDE §9 "Function Scope" | The board can never be a global. It is a parameter on every engine function. |
| Top-level `:=` constants **do** pierce function scope | GUIDE §4 "Constant Scope" | Board size, colour codes, and weights are constants, not parameters. |
| Mutation across a call requires `<~` output params | GUIDE §9 "Output Parameters" | `着手` takes the board as `盤<~` and the prisoner counters as `<~`. |
| Module bodies allow only literal initializers — no calls, no control flow | GUIDE §17 | String tables cannot be built at module load. They are `??` matches inside functions. |
| Module private state persists across calls and is shared per file path | GUIDE §17 | Language selection and position history live as module state, reached through setters. |
| Named tuples have no dynamic string-key access | v0.0.7 finding | Every keyed lookup is a `??` match, never `tbl[key]`. |
| Arrow keys arrive from `<<\|` as the glyphs `'↑' '↓' '←' '→'` | measured — GUIDE §3b says `'U' 'D' 'L' 'R'` and is wrong (HLZ-006) | The controller matches on the glyphs. Commands are lowercase by convention, not by necessity. |
| String interpolation takes `{identifier}` only | HLZ-007 | Field access and indexing are bound to a local before they can be printed. |
| `>>\|` errors when stdout is not a TTY | GUIDE §3b | The game refuses to run under redirection; tests drive the engine modules directly. |
| A module constant must be a bare literal — `:= -1` is an expression | HLZ-001 | Status codes are positive, and `着手` returns status while the ko point leaves through an output parameter. |
| An array index computed from parameters is inferred Float and rejected | HLZ-002 | Every computed index goes through `位置()`, whose return is `##!`-cast. |
| `==` is type-strict across Int/Float while `<` and `>` coerce | HLZ-003 | Scores are forced to Float on both sides, and 勝色/差分 compare only with `>`. |
| No primitive measures display width | IDEA-001 | `表示/文字.zy` derives code points via `0d\|c\|` and carries its own East Asian Wide table. |

---

## 2. Board representation

```
盤   : flat array, length 路 × 路, 1-indexed
路   : board size (9, 13, 19)
value: 0 = 空 (empty), 1 = 黒 (black), 2 = 白 (white)
```

Index arithmetic, with rows counted from the top of the array (row 1 = display
row `路`, so the display layer flips, not the engine):

```zymbol
位置(路, 行, 列) { <~ (行 - 1) * 路 + 列 }
```

Neighbours are `位置 ± 1` horizontally and `位置 ± 路` vertically, with edge
guards on `列 == 1`, `列 == 路`, `行 == 1`, `行 == 路`. A flat array is used
rather than a matrix because the flood fill walks neighbours millions of times
over a game and nested indexing is the more expensive path.

**Colour constants** (top-level `:=`, visible inside every function):

```zymbol
空 := 0
黒 := 1
白 := 2
```

### Match state

The match state is a named tuple threaded through `対局.zy`:

| Field | Meaning |
|-------|---------|
| `盤` | the flat board array |
| `路` | board size |
| `手番` | side to move (`黒` / `白`) |
| `手数` | move number |
| `黒アゲハマ` / `白アゲハマ` | prisoners captured by each side |
| `コウ点` | forbidden ko point, or `0` |
| `連続パス` | consecutive pass count |
| `最終手` | last move index, or `0` |
| `コミ` | komi |
| `棋譜` | move history array, for 待った and SGF export |

---

## 3. 盤.zy — board mechanics

### Public API

```zymbol
新規(路)                          → a board of 路 × 路 zeros
複製(局面)                        → an independent copy
位置(路, 行, 列)                  → flat index (the only place indices are computed)
取得(局面, 路, 行, 列)            → the value at a point
連(局面, 路, 起点)                → array of indices in the chain containing 起点
ダメ点(局面, 路, 群)              → array of distinct liberty indices of a chain
群ダメ数(局面, 路, 群)            → liberty count of an already-computed chain
ダメ数(局面, 路, 起点)            → liberty count of the chain at 起点
着手(局面<~, 路, 起点, 色, 取数<~, コウ点<~)
                                  → plays a stone; returns 可 / 禁_占有 / 禁_自殺
除去(局面<~, 群)                  → clears a chain from the board
```

### Chain detection — flood fill

Recursive, with a visited array of board length. Depth is bounded by chain size,
so worst case is 361 frames on 19 × 19 — a real recursion-depth test for the
tree-walker.

```
連(局面, 路, 起点):
    色 ← 局面[起点]
    訪問 ← array of 路×路 zeros
    _探索(局面, 路, 起点, 色, 訪問<~, 結果<~)
    return 結果

_探索(局面, 路, p, 色, 訪問<~, 結果<~):
    if 訪問[p] ≠ 0 or 局面[p] ≠ 色: return
    訪問[p] ← 1
    結果 $+ p
    for each neighbour q of p: _探索(局面, 路, q, 色, 訪問, 結果)
```

An iterative worklist variant was held in reserve in case recursion depth or
interpreter overhead became a problem. It was not needed: `試験/性能試験.zy`
walks a single 360-stone chain on a 19 × 19 board without trouble.

### Placing a stone — order matters

The order below is the whole of Go's capture rule and the reason suicide is
usually — but not always — illegal:

```
着手(局面, 路, p, 色):
    1. 局面[p] ← 色                      place first
    2. 取数 ← 0
       for each neighbour q of p with 局面[q] == 敵色:
           if ダメ数(局面, 路, q) == 0:
               取数 += size of that chain
               除去(that chain)
    3. if 取数 == 0 and ダメ数(局面, 路, p) == 0:
           undo step 1 and reject — 自殺手
    4. コウ点 ← p_captured  if 取数 == 1 and the played chain is a single
                            stone with exactly one liberty; else 0
    return 可
```

Step 4 is the precise condition for simple ko: exactly one stone captured, by a
single stone that itself now has exactly one liberty. Anything looser forbids
legal moves; anything tighter permits infinite recapture.

---

## 4. 規則.zy — legality and end of game

```zymbol
判定(局面, 路, 起点, 色, コウ点)   → 可 / 禁_占有 / 禁_自殺 / 禁_コウ
合法(局面, 路, 起点, 色, コウ点)   → #1 / #0
着手可能(局面, 路, 色, コウ点)     → array of all legal points for 色
終局(連続パス)                     → #1 when 連続パス >= 2
理由鍵(コード)                     → the i18n key for a rejection
```

`判定` works on a **copy** of the board, so it never disturbs the caller. It is
the most-called function in the AI loop, and it was the primary benchmark
target — measured at 287 points scanned on a 19 × 19 position in 0.38 s of
total process time, board copy included. A full unpruned legality scan is
affordable.

`理由鍵` exists so no caller ever hard-codes a message: a rejection travels as a
code, becomes an i18n key here, and becomes text in whichever of the five
languages is active.

**Positional superko** (optional): `対局` keeps an array of position hashes; a
move whose resulting position hash already appears in the history is rejected.
The hash is a simple polynomial fold over the flat board — collisions are
tolerable here because a false rejection costs one alternative move, not
correctness of the score.

---

## 5. 計算.zy — area scoring

```zymbol
目算(局面, 路, コミ)  → named tuple (黒石, 白石, 黒地, 白地, 黒合計, 白合計)
勝色(結果)            → 1 black ahead · 2 white ahead · 0 持碁
差分(結果)            → absolute margin, for 言語::結果文
領域図(局面, 路)      → per-point ownership: 0 neutral · 1 black · 2 white
```

Algorithm:

1. Count stones of each colour — one linear pass.
2. Flood fill each connected region of empty points, recording which colours
   border it.
3. A region bordered by exactly one colour is that colour's 地 (territory). A
   region bordering both, or neither, is ダメ — neutral, counted for nobody.
4. `黒合計 = 黒石 + 黒地`, `白合計 = 白石 + 白地 + コミ`. **Both are forced to
   Float.** Otherwise the type of a score would depend on the type of the komi
   the caller passed, and Int/Float equality is strict (HLZ-003) — a Float zero
   is not `== 0`, though it is both `>= 0` and `<= 0`.
5. `勝色` compares the totals with `>` only, never `==`, and answers 0 for 持碁.

Result phrasing, via `??` on the difference:

| Condition | Japanese | English |
|-----------|----------|---------|
| `差 == 0` | 持碁 | Draw |
| resignation | 中押し勝ち | Win by resignation |
| `差` has a `.5` | `N目半勝ち` | Win by N.5 points |
| otherwise | `N目勝ち` | Win by N points |

The same function powers the live 目算 estimate shown in the panel; during play
it is called on the current position with unsettled regions simply counted as
neutral, which is why the estimate moves as the boundaries close.

---

## 6. 思考.zy — the AI

### Why it is deterministic and not statistical

The obvious modern answer to "write a Go AI" is Monte Carlo tree search, or a
policy network trained by self-play. Both were measured before being ruled out,
on 9 × 9, tree-walker, same machine:

| Operation | Measured |
|-----------|----------|
| One heuristic move — enumerate candidates and evaluate | **~0.04 s** |
| One light random playout to the end of the game | **0.24 s** |
| MCTS at 1,000 playouts per move | **~4 min per move** |
| MCTS at 10,000 playouts per move | **~40 min per move** |
| One forward pass of an 81→64→81 net, nested tensors | **~4 s** |
| The same 5,184 multiply-accumulates on a flat array | **~0.3 s** |
| `--vm` as an escape hatch | fails — HLZ-008 |

MCTS needs roughly **6,000×** the budget available. Within a two-second move
that buys about eight playouts, and eight random games are noise, not
knowledge. A trained network is further still: self-play needs millions of
positions, and one forward pass costs more than a whole heuristic move.

The flat-array measurement is worth keeping for a different reason — it is a
6-7× gap against nested tensors, which independently confirms the diagnosis in
Zofía's own `ROADMAP_IA.md`: representation, not the language, is what blocks
numeric work. Even with a native tensor type, a forward pass at ~0.6 s would be
enough to *evaluate* a position and nowhere near enough to *search* over it.

So the engine reads the board with rules, the way a human beginner is taught to.
The only simulation that pays for itself is short and directed: reading a ladder
(シチョウ) is tens of deterministic steps, not thousands of random games.

### Shipped

```zymbol
眼(局面, 路, 点, 色)             → is this empty point an eye of 色?
有用手(局面, 路, 色, コウ点)     → legal moves that are not a self-filled eye
手詰まり(局面, 路, 色, コウ点)   → #1 when nothing useful is left
```

### Planned

```zymbol
着手選択(局面, 路, 色, 級, コウ点, 最終手, 手数)  → chosen point, or 0 to pass
評価(局面, 路, 起点, 色, 級, 最終手, 手数)        → an integer score
候補(局面, 路, 色, コウ点)                        → pruned candidate array
```

### Candidate pruning

Full legality scanning of 361 points per turn is the worst case. `候補` prunes
first:

- If the board is empty or nearly so, candidates are the star points and 3-4
  points only (opening book).
- Otherwise, candidates are empty points within Manhattan distance 2 of any
  existing stone, plus star points. This is standard bot practice and cuts the
  scan by roughly an order of magnitude in the opening and midgame.
- Legality is tested only on the pruned set.

### Evaluation layers

`評価` sums weighted terms. Weights are top-level constants so they can be tuned
without touching the logic:

| Term | Weight constant | Value |
|------|-----------------|-------|
| Stones captured by this move | `重_取り` | `100 × captured` |
| Own chain escaping atari, resulting liberties ≥ 2 | `重_逃げ` | `80 × chain size` |
| Puts an opponent chain in atari | `重_アタリ` | `40` |
| 3 × 3 shape pattern match near the opponent's last move | `重_形` | `10 … 30` per pattern |
| Influence map value at the point | `重_勢力` | `0 … 20` |
| Opening book point, first 8 moves | `重_布石` | `50` |
| First or second line before move 30 | `重_辺` | `-30` |
| Fills own eye | — | rejected outright, never scored |

**Eye detection** (the rule that keeps the AI from killing itself): a point is
an eye for 色 when all four orthogonal neighbours are 色 or off-board, and at
least three of the on-board diagonals are 色 or off-board (two, if the point is
on an edge). This is the standard approximation — it can misjudge a false eye,
and doing so is an acceptable failure for a beginner-level engine.

**Influence map**: each stone radiates `4 - distance` for distances 0–3 into its
neighbourhood, black positive and white negative. Points with a near-zero sum
are the contested boundary, which is where the AI wants to play. The map is
computed once per turn, not per candidate.

**Levels** modulate two things only — which layers are active and how much noise
is added before the argmax:

| Level | Layers | Noise |
|-------|--------|-------|
| 初級 | 1–4 | ±40% of the best score, choose among the top 8 |
| 中級 | 1–7 | ±15%, choose among the top 4 |
| 上級 | 1–7 + wider prune radius | ±3%, best move |

**Passing**: the AI passes when no candidate scores above a floor and the
opponent has just passed, or when every legal move would fill one of its own
eyes. Under area scoring, passing early is a real loss, so the floor is
deliberately low.

---

## 7. 表示/ — rendering geometry

### The two-column invariant

Every board cell occupies **exactly two terminal columns** in every theme. This
is the single most important rendering decision in the project, and it is what
lets emoji stones coexist with box-drawing grid lines:

| Cell content | Rendering | Columns |
|--------------|-----------|---------|
| Empty point | grid glyph + `─` connector | 1 + 1 |
| Empty star point | `╋` + `─` | 1 + 1 |
| Stone, emoji theme | `⚫` or `⚪` (the glyph is itself double-width) | 2 |
| Stone, ASCII theme | `X` or `O` + `─` connector | 1 + 1 |
| Rightmost column | glyph + **space** | 1 + 1 |

The rightmost column is the one that nearly got away. An earlier draft dropped
the trailing connector there, making the grid `2 × 路 - 1` columns wide — right
for an empty board, and one column short the moment a stone was played in the
last column, which would have jittered the row label. The connector becomes a
space instead, so the grid is `2 × 路` columns wide whatever is on it, and
`試験/描画試験.zy` asserts exactly that with stones in the first and last
columns of every theme.

Grid glyphs are chosen per position: `┌ ┬ ┐` on the top row, `├ ┼ ┤` in the
middle, `└ ┴ ┘` on the bottom, `╋` at star points.

### Layout arithmetic

```
gutter          = 5 columns   ("  19 " — 2 spaces, right-aligned label, space)
board width     = 2 × 路      (路 cells of exactly 2 columns)
right label     = 2 columns   (space + label)
block width     = 2 × 路 + 7
block height    = 路 + 2      (column labels above and below)
```

Layout selection, from `[高, 幅] = >>?`:

| Condition | Layout |
|-----------|--------|
| `幅 >= 2 × 路 + 33` and `高 >= 路 + 4` | Boxed panel to the right |
| `幅 >= 2 × 路 + 9` and `高 >= 路 + 6` | One-line panel below |
| otherwise | That board size is unavailable |

| Board | Stacked | Side by side |
|-------|---------|--------------|
| 9 × 9 | 27 × 15 | 51 × 13 |
| 13 × 13 | 35 × 19 | 59 × 17 |
| 19 × 19 | 47 × 25 | 71 × 23 |

Side by side costs columns and saves rows, which is why the widest board is the
one that fits a classic 80 × 24 terminal — the stacked layout would need 25
rows for it. The panel earns its two forms here: a ten-row framed box beside
the board, or a single dense line under it.

### Redraw strategy

The game is turn-based, so there is no frame budget and no delta rendering — the
board is redrawn whole after each move. Two exceptions, both because they happen
at typing speed rather than move speed:

- **Cursor movement** redraws only the two affected cells (old position restored,
  new position highlighted).
- **The panel** redraws only the fields that changed.

Cursor highlighting uses `>>~ (行, 列, 0, fg, bg)` with inverted colours over an
occupied point, and the `＋` glyph over an empty one so the cursor stays visible
in terminals with weak background-colour support.

### The double-width lesson from Serpiente

Serpiente's BUG-004: a fruit emoji spanned two columns but was stored at one
coordinate, so collisions through the right-hand column went undetected and
erasing left half a glyph behind. The structural fix here is the two-column
invariant — a stone exactly fills its cell, coordinates are cell coordinates
rather than column coordinates, and `列 → column` conversion happens once, in
the render layer:

```zymbol
画面列(列) { <~ 余白 + 5 + (列 - 1) * 2 }
```

No other module ever computes a terminal column.

---

## 7b. 表示/文字.zy — text metrics

Grapheme count is not column count: `"手番"$#` is 2 and occupies 4 columns.
Every width calculation in the program goes through `幅()`, never through `$#`.

Zymbol has no display-width primitive and `Char` is neither comparable nor
castable to Int, so the code point is recovered through the inverted base
literal:

```zymbol
符号点(c) {
    s = 0d|c|        // "0d12354"
    t = s$[3..]
    <~ #|t|
}
```

On top of that sit `幅()` (East Asian Wide and Fullwidth ranges plus the emoji
blocks, ~40 range tests), `右詰()`, `左詰()`, `中央()` and `切詰()` — the last
never splitting a wide glyph in half. This is the module the panel and every
framed screen depend on, and `試験/文字試験.zy` asserts it in five scripts.

---

## 8. 言語/ — runtime UI strings

The module body cannot execute anything, so no lookup table can be built at
load time, and named tuples have no dynamic string-key access. The lookup is
therefore a `??` match inside a function:

```zymbol
# .言語_module {
    #> { 設定, 語, 現在 }

    現在言語 = "ja"

    設定(コード) { 現在言語 = コード }
    現在() { <~ 現在言語 }

    語(キー) {
        ?? 現在言語 {
            "en" => <~ _英(キー)
            "es" => <~ _西(キー)
            _    => <~ _日(キー)
        }
    }

    _日(キー) {
        <~ ?? キー {
            "手番"     => "手番"
            "アゲハマ" => "アゲハマ"
            "終局"     => "終局"
            "持碁"     => "持碁"
            _          => キー
        }
    }
}
```

The `_ => 鍵` fallback means a missing translation renders as its key rather
than as an empty string — a missing entry is visible instead of silent. Because
keys are neutral ASCII and translations never are, that fallback is also what
makes completeness **decidable**, and `試験/言語検証.zy` walks the master
catalogue from `鍵一覧()` against all five locales:

```
  [ja] 日本語        51/51  OK
  [ko] 한국어        51/51  OK
  [zh] 中文          51/51  OK
  [en] English       51/51  OK
  [es] Español       51/51  OK
PASS — every key resolves in every locale
```

Static lookup is not enough on its own. Grammar and number formatting differ per
language, so each locale also composes three sentences:

| Function | ja | ko | zh | en | es |
|----------|----|----|----|----|----|
| `路盤名(9)` | 九路盤 | 9줄 바둑판 | 九路棋盘 | 9×9 | 9×9 |
| `結果文(2, 1.5, #0)` | 白の1目半勝ち | 백 1집반승 | 白胜1目半 | White wins by 1.5 points | las blancas ganan por 1,5 puntos |
| `取石文(3)` | 3子を取った | 3점을 따냈습니다 | 提3子 | captured 3 stones | captura 3 piedras |

Note what a static table could not have done: Japanese and Chinese write the
half point as 半 rather than a decimal, Korean counts in 집, English inflects the
plural, and Spanish uses the decimal comma.

Language choice is module state, so it survives every call for the session
without being threaded through the render functions as a parameter. This is the
deliberate contrast with Hov veS, which threaded language as a parameter through
five modules; the two approaches sit side by side in the project record.

---

## 9. api/ — identifier-level API translation

Pure re-export layers, no logic, no runtime cost — the three-layer pattern from
[I18N.md](../interpreter/I18N.md) applied to a working engine:

```zymbol
# .api_english {
    <# ../核/盤 => b
    <# ../核/規則 => r
    <# ../核/計算 => s

    #> {
        b::新規   => new_board
        b::着手   => play
        b::連     => chain
        b::ダメ数 => liberties
        r::合法   => is_legal
        r::終局   => is_over
        s::目算   => score
    }
}
```

A developer writing a front-end in English imports `api/english` and never opens
a Japanese file. `api/espanol.zy` does the same in Spanish. Subdirectory modules
use the dot convention: `核/盤.zy` declares `# .核_盤`.

---

## 10. Test strategy

`>>|` refuses to run without a TTY, so the TUI cannot be tested by piping. The
split:

- **Engine modules** (`核/`) are tested by ordinary `.zy` scripts with `.expected`
  files, in the style of `interpreter/tests/`. Positions are set up by a helper
  that parses a text diagram into a flat array, so test cases are readable.
- **Rule cases** to cover: capture of 1 / many / multiple chains at once,
  suicide rejected, suicide legal because it captures, ko forbidden then
  permitted after an intervening move, snapback, capture in the corner and on
  the edge, seki scored as neutral, board full, both pass immediately.
- **Scoring cases**: an empty board (0 vs komi), a board split cleanly down the
  middle, a region bordered by both colours counted as neutral, integer komi
  producing 持碁.
- **The AI** is tested for properties, not outputs: it never returns an illegal
  move, never fills its own eye, always captures a free single stone in atari,
  and always escapes its own single-stone atari when escape gains liberties.
- **Rendering** is verified by eye against the mockups, and by a width assertion
  helper that checks every rendered row is the expected column count.

---

## 11. Open questions — and the answers so far

Measured by `試験/性能試験.zy` on the real engine:

1. **Recursion depth — answered.** A single chain of 360 stones on a 19 × 19
   board is traversed by `連()` without trouble in the tree-walker. The
   iterative worklist variant is not needed.
2. **Full legality scan cost — answered.** `着手可能()` evaluated 287 legal
   points on a 19 × 19 midgame position, copying the board once per point, in
   0.38 s of total process time. The AI can afford an unpruned legality scan;
   pruning in §6 is now about the *evaluation* cost, not legality.
3. **Array copy cost — folded into 2.** The 361-element copy per legality test
   is included in the number above, so play-then-undo on a single board is not
   worth its mutation-correctness risk yet.
4. **Emoji width in practice — answered for one terminal.** The game was run
   under a pseudo-terminal and the output stream replayed through a width-aware
   reconstruction: the grid, the panel and the frames line up in all three
   themes, on 9 × 9 and 19 × 19, in Japanese, Korean and Mandarin. That is one
   terminal emulator, not all of them, so the risk is reduced rather than
   closed — but it is no longer theoretical.
5. **CJK panel alignment — answered.** `表示/文字.zy` measures display width, so
   padding is computed rather than guessed. The panel measures 24 columns in
   all five locales, verified by assertion and confirmed on screen.
