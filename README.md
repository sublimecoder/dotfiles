# dotfiles

Personal shell and git config for two machines — a Mac and an Omarchy/Arch box —
from one repo and one branch.

`shared/` is linked everywhere; `macos/` or `linux/` is linked according to
`uname`. The split is done by *which files get linked*, not by a runtime OS test
inside the configs — so a per-OS setting is a new file in an OS directory, never
an edit to `zshrc`.

## Install

```bash
git clone git@github.com:sublimecoder/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` symlinks each file into `$HOME` (e.g. `shared/zshrc` ->
`~/.zshrc`, `shared/bin/*` -> `~/.bin/*`). Re-run it any time after adding a new
file — it's safe to run repeatedly, and it won't overwrite a real (non-symlink)
file that's already at the destination.

On macOS it also runs `brew bundle` against `macos/Brewfile`. On Linux it
**reports** anything missing from `linux/packages.txt` and installs nothing.

## Rebuilding an Omarchy machine

Everything a machine carries beyond a stock Omarchy install lives in
`linux/omarchy/common.manifest` plus `linux/omarchy/hosts/<hostname>.manifest`:
packages, AUR packages, Omarchy installers, shell plugins, bar order, web apps,
services and a few in-place settings. The format is documented at the top of
`common.manifest`. `install.sh` only reports the count; applying takes sudo:

```bash
omarchy-provision --check     # what is missing, changes nothing
omarchy-provision             # install it (idempotent; re-run after a failure)
sudo ~/dotfiles/linux/bin/restic-setup   # nightly restic -> B2; asks for credentials
```

Then restore data from restic **selectively** (`restic restore latest --target
... --include ~/code` and the like), never all of `~/.config` over a fresh
install: that overwrites the newer Omarchy defaults the install just wrote.

Order on a dead laptop: install Omarchy, clone this repo, `install.sh`,
`omarchy-provision`, `restic-setup`, restore data. Restic credentials are not in
this repo; keep them somewhere off the machine. When you add something by hand,
add its line to the host manifest, and `omarchy-provision --check` on the live
machine should say "nothing missing".

It also restores Claude Code: `claude/setup.sh` merges `claude/settings.base.json`
into `~/.claude/settings.json` (merged, not linked — Claude Code writes that file),
installs the listed plugins, and clones third-party skills. A private second
installer is run afterwards when present; on a fresh machine pass its remote once:

```bash
AIOS_VAULT_REMOTE=<git url> ~/dotfiles/install.sh
```

On a fresh machine, also point git at the commit template:

```bash
git config --global init.templatedir ~/.git_template
```

## Layout

- `shared/zshrc`, `shared/aliases`, `shared/zshenv` — shell
- `shared/zsh/` — functions, completions, and config fragments loaded by `zshrc`
- `shared/vimrc`, `shared/vim/` — vim (being retired; see the port plan)
- `shared/gitconfig`, `shared/gitmessage`, `shared/git_template/` — git
- `shared/bin/` — small personal scripts, on `$PATH` via `install.sh`
- `macos/` — Brewfile, zprofile, and the Homebrew / gcloud / Android / iCloud
  bits that exist only there
- `linux/` — `packages.txt`, the Wayland clipboard aliases, and the printer
  setup (`linux/bin/setup-printers.sh`, `linux/cups/lprint-backend`)

`macos/zsh/configs/` and `linux/zsh/configs/` link into the *same*
`~/.zsh/configs/` as the shared ones, so both halves load through one loader.

## Printers

`install.sh` does **not** configure printers — every step needs root. It only
reports the command when no CUPS queue exists:

```bash
sudo ~/dotfiles/linux/bin/setup-printers.sh
```

That wires two things on a fresh Omarchy box:

- **Canon PIXMA TS4320 (network)** — driverless. No Canon package and no PPD:
  the printer advertises IPP Everywhere over mDNS and stock CUPS drives it. The
  script discovers *any* AirPrint printer on the LAN rather than hardcoding one,
  so a replacement printer needs no edit.
- **Yxwl/Labeer Y812BT 4x6 thermal label printer (USB)** — via `lprint` from
  Arch `extra/`. Its USB device ID reports an empty `CMD:`, so nothing
  auto-detects it; the command language is TSPL, confirmed by probe.

Two things that setup learned the hard way, both written into the script:

- `lprint` claims the USB device through libusb, which **deletes
  `/dev/usb/lp0`**. Writing to that path afterwards silently creates a regular
  file and the job disappears with no error. Drive it through `lprint`.
- Chromium/Brave sends `print-color-mode=color` on every job even when CUPS
  advertises monochrome-only, and `lprint` rejects it — jobs land as
  `canceled-at-device` with nothing printed and nothing stuck. Not fixable from
  the browser or the queue defaults, so CUPS reaches `lprint` through
  `linux/cups/lprint-backend`, a nine-line shim that pins monochrome.

The label printer's resolution is **per-unit** — 203 dpi was confirmed with a
ruler, but the same Yxwl engine ships at 300 dpi under other badges. Verify
before trusting it; re-run with `LABEL_DPI=300` if labels print off-scale.

## Shell

**Mac: zsh. Omarchy/Arch: bash**, the distribution's default — zsh is not
installed there and is deliberately absent from `linux/packages.txt`. Nothing is
`chsh`-ed on either machine. `shared/zsh/` is linked on Linux but simply unused.
Reasoning, what bash actually costs, and how to reverse it:
[`docs/shell-decision.md`](docs/shell-decision.md).

If you want to copy any of this, go ahead.
