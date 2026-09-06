# Shell: bash logs you in, zsh is what you type into

**Decided 2026-09-05, during the Omarchy port. Recorded so the next machine does
not re-derive it — and so the reasoning survives disagreeing with it later.**

## The decision

- **Login shell stays `bash`.** `chsh` is not run.
- **The terminal launches `zsh`** for interactive use.
- Both machines end up in the same interactive shell, which is the point.

## Why not just make zsh the login shell

Omarchy ships bash as the login shell and its own tooling is written against
that assumption — `/usr/share/omarchy/bin/*` and the shell integration expect
bash to be what starts. Changing the login shell is the kind of edit that works
fine for a week and then breaks one `omarchy-*` command in a way that reads as
an Omarchy bug rather than as a local change. Leaving it alone keeps the
distribution on the path it tests.

## Why not just use bash

`zsh/functions/g` is the single most-used file in this repo — **1100 invocations**
in 5397 lines of Mac shell history (`g ci` 616, `g co` 221). Everything in
`zsh/configs/` is zsh, not portable sh. Rewriting that for bash to avoid setting
one config line is the worse trade by a wide margin.

## How it is actually set

**On this machine the terminal is `foot`, not Ghostty.** The port plan said
"set zsh as the Ghostty shell"; Ghostty is not installed here and `foot` is the
only terminal binary present, so the same decision lands in a different file:

```ini
# ~/.config/foot/foot.ini, under [main]
shell=/usr/bin/zsh
```

Ghostty, if it is ever installed, is `shell = /usr/bin/zsh` in
`~/.config/ghostty/config`. Alacritty is `[terminal] shell = "/usr/bin/zsh"`.
Apply with `omarchy restart terminal` (foot picks it up in new windows).

`~/.config/foot/foot.ini` is user config and safe to edit. Do **not** edit
`/usr/share/omarchy/` — it is overwritten by `omarchy update`.

## Order of operations, which bit us once

**Install the zsh configs BEFORE pointing the terminal at zsh.** A terminal set
to an unconfigured zsh is strictly worse than bash: no `g`, no completions, no
prompt. On 2026-09-05 the terminal flip was deliberately held back until
`install.sh` had linked `zsh/` on this machine, because at that moment nothing
from this repo was installed here at all.

Prerequisite, since Omarchy does not ship zsh:

```bash
omarchy pkg add zsh
```
