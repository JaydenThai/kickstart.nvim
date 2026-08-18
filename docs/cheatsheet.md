# Cheatsheet

A deliberately short list. This config has 46 leader mappings and 37 plugins —
this file is the subset worth building muscle memory for. Everything else is
discoverable (see [Finding the rest](#finding-the-rest)), so there is no reason
to memorise it.

Leader is `<Space>`.

## The core eight

Learn these until they are automatic. Nothing else on this page matters until
they are.

| Key                 | Does                                    |
| ------------------- | --------------------------------------- |
| `<leader>sf`        | Search files by name                    |
| `<leader>sg`        | Grep the whole project                  |
| `<leader><leader>`  | Switch between open buffers             |
| `grd`               | Go to definition                        |
| `grr`               | Go to references                        |
| `K`                 | Hover docs for the symbol under cursor  |
| `<leader>q`         | Diagnostics (errors) for this file      |
| `<leader>lg`        | LazyGit                                 |

`<C-o>` jumps back where you came from, `<C-i>` forward again. That pair is what
makes `grd` usable — jump in, read, jump out.

## Vim grammar

This is the part that transfers to every editor, every `vi` on every server, and
never goes out of date. It is worth more than any plugin.

**Operator + motion.** Pick a verb, then say how far:

| | |
| --- | --- |
| `d` delete · `c` change · `y` yank · `>` indent | `w` word · `}` paragraph · `$` end of line · `5j` five lines down |

So `d}` deletes to the end of the paragraph, `c$` changes to end of line,
`y5j` yanks six lines. Any verb combines with any motion — that is the whole
idea, and it is why vim is worth the trouble.

**Operator + text object.** `i` = inside, `a` = around:

```
ci"     change inside quotes
da(     delete around parens, brackets included
vi{     visually select inside braces
dap     delete a paragraph
```

**Text objects from `mini.ai`** (already installed) extend that with code-aware
targets — `f` for function, and `n`/`l` for next/last:

```
daf     delete a function, whole thing
cif     change a function body
ci)     change inside the parens you are sitting in
cin"    change inside the NEXT set of quotes
```

**Surround, from `mini.surround`** (already installed) — `s` for surround:

```
saiw)   add parens around the word under the cursor
sd'     delete the surrounding single quotes
sr)'    replace surrounding parens with quotes
```

**Counted motions.** Relative line numbers are on, so the gutter tells you the
count directly. See `7` next to a line? `d7j` deletes down to it, `7k` jumps to
it, `y7j` yanks to it.

## Finding the rest

Three tools, so you never have to memorise the other 38 mappings:

- **Press `<Space>` and stop.** which-key is set to `delay = 0`, so the menu of
  every leader mapping appears instantly. Works for sub-groups too — `<Space>s`
  shows all search mappings, `<Space>T` all test mappings.
- **`<leader>sk`** — fuzzy-search every keymap by name or description.
- **`<leader>sh`** — fuzzy-search Neovim's help. `:help` is genuinely good;
  `:help text-objects` and `:help motion.txt` are worth an evening each.

Groups defined in this config: `<leader>s` search · `<leader>t` toggle ·
`<leader>T` test · `<leader>h` git hunk.

## Deliberately not on this page

DAP, neotest, the TypeScript and Ruff code-action mappings, telescope's more
exotic pickers. They are all configured and all working — reach for them via
which-key when you actually need them, rather than trying to hold them in your
head now.

## Practice

- `:Tutor` — built in, about 25 minutes. Worth doing twice, a week apart.
- Add nothing to this config for a while. The plugins are ahead of the fluency;
  closing that gap is the fastest available win.
