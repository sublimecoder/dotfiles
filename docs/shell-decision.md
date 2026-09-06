# Shell: bash on Omarchy, zsh on the Mac

**Decided 2026-09-05. Reversed the same day, before anything was installed —
both versions are kept below, because the reasoning is the useful part.**

## The decision, as it stands

- **Omarchy/Arch: bash everywhere.** Login shell and terminal, Omarchy's default.
  zsh is not installed and is deliberately absent from `linux/packages.txt`.
- **Mac: unchanged.** zsh, as it has always been.
- Nothing is `chsh`-ed on either machine.

## What the first version said, and why it changed

The first pass set the terminal to launch zsh on both machines so the interactive
shell would be identical. The stated justification was that
`zsh/functions/g` — 1100 invocations, the most-used file in this repo — and
everything in `zsh/configs/` are zsh.

**Half of that was wrong, and it is the half that mattered.** `g` is not
zsh-specific at all:

```sh
g() {
  if [[ $# -gt 0 ]]; then git "$@"; else git status; fi
}
```

`[[ ]]` is a bash builtin too. That function runs unmodified under bash, so the
single strongest argument for installing zsh here did not survive being read.

## What bash actually costs on this machine

Small, and worth knowing precisely rather than guessing:

| | Portable to bash? |
|---|---|
| `zsh/functions/g` | **Yes**, unmodified |
| 59 of 63 aliases | **Yes** |
| `alias -g G/L/M` (3) | No — zsh global aliases have no bash equivalent |
| `alias -- -="cd -"` | No — bash cannot alias `-` |
| `zsh/configs/*` | No — prompt, completion, keybindings, history options |
| `zsh/completion/*` | No |

So the genuine loss is the zsh *environment* (prompt, completions, keybindings),
not the tooling. Omarchy ships its own prompt and completions, which is the point
of running the distribution's default in the first place.

## Why not force them to match

Two machines with identical interactive shells sounds tidy and buys little here.
Omarchy is a curated environment with an opinion about bash; overriding it means
maintaining a zsh setup against a distribution that tests the other one. The Mac
has ten years of zsh muscle memory and no reason to move.

The dotfiles already express this correctly: `shared/` holds what is genuinely
shared, and the shell environment is not. `shared/zsh/` simply goes unused on
Linux — it is linked, harmless, and there for the Mac.

## If this reverses again

Everything needed is already here. `omarchy pkg add zsh`, then:

```ini
# ~/.config/foot/foot.ini, under [main]
shell=/usr/bin/zsh
```

Ghostty is `shell = /usr/bin/zsh` in `~/.config/ghostty/config`; Alacritty is
`[terminal] shell = "/usr/bin/zsh"`. Apply with `omarchy restart terminal`.
`~/.config/foot/foot.ini` is user config and safe to edit — never
`/usr/share/omarchy/`, which `omarchy update` overwrites.

**Install the configs before pointing a terminal at zsh.** A terminal set to an
unconfigured zsh is strictly worse than bash: no `g`, no completions, no prompt.

## Open, if bash stays

`g` and ~59 aliases are portable but reach nothing on this box today — bash reads
`~/.bashrc`, and this repo ships no bash entry point. Wiring one is a small,
separate job: source the portable aliases, define `g`, skip the four zsh-only
lines.
