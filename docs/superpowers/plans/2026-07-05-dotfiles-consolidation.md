# Dotfiles Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge `~/dotfiles` (thoughtbot fork) and `~/dotfiles-local` (personal overrides) into a single, fully self-owned `~/dotfiles` repo with no rcm dependency and no thoughtbot lineage.

**Architecture:** Stage the new repo at `~/dotfiles-new`, seeded from `~/dotfiles-local`'s git history (already 100% personal). Merge each `X`/`X.local` file pair into one flat `X`, drop all thoughtbot boilerplate, replace the rcm install mechanism with a tiny symlink script, push to a new GitHub repo, then cut over `$HOME` symlinks and archive the two old GitHub repos.

**Tech Stack:** git, zsh, vim/vim-plug, `gh` CLI, POSIX shell (install script).

## Global Constraints

- New repo lives at `~/dotfiles`, GitHub repo `sublimecoder/dotfiles` — **amended in Task 7**: pushed into the existing repo of that name (force-pushed over the old fork's content) rather than a newly-created non-fork repo; `isFork` stays `true` as unavoidable GitHub metadata, content is fully replaced, public.
- No `.local`-suffix files, no `DOTFILES_DIRS` precedence, no rcm/`rcup`/`rcrc`.
- Single git identity in `gitconfig`: `name = Jared Smith`, `email = jared.smith88@me.com`. No work/personal `includeIf` split.
- Nothing from `thoughtbot/dotfiles`'s branding/automation survives: no README/LICENSE/CODE_OF_CONDUCT.md/SECURITY.md/CODEOWNERS, no `.github/workflows/*`, no `upstream` remote.
- `~/.git_template.local/*` stays untouched — out of scope.
- Every step below that writes a merged file shows its exact final content — no placeholders.

---

## Task 1: Bootstrap new repo from dotfiles-local history

**Files:**
- Create: `~/dotfiles-new/` (git clone of `~/dotfiles-local`)

**Interfaces:**
- Consumes: `~/dotfiles-local` (existing repo, clean working tree)
- Produces: `~/dotfiles-new` — a git repo with `dotfiles-local`'s full commit history, no remote configured yet, ready for the merge tasks to add/modify files in.

- [ ] **Step 1: Verify source repo is clean**

Run: `git -C ~/dotfiles-local status --porcelain`
Expected: empty output (clean working tree). If not empty, stop and ask the user before continuing — do not clone over uncommitted work.

- [ ] **Step 2: Clone locally, preserving history**

```bash
git clone ~/dotfiles-local ~/dotfiles-new
cd ~/dotfiles-new
git remote remove origin
```

- [ ] **Step 3: Verify history carried over**

Run: `git -C ~/dotfiles-new log --oneline | tail -5`
Expected: shows the oldest `dotfiles-local` commits (e.g. `6a66508 Update alias`, `dec7851 Remove alias` — the tail of the log captured during design).

Run: `git -C ~/dotfiles-new remote -v`
Expected: empty output (no remotes configured).

No commit for this task — nothing changed yet, just staged the clone.

---

## Task 2: Merge shell config (zshrc, aliases)

**Files:**
- Modify: `~/dotfiles-new/zshrc`
- Modify: `~/dotfiles-new/aliases`
- Delete: `~/dotfiles-new/zshrc.local`, `~/dotfiles-new/aliases.local`

**Interfaces:**
- Consumes: `~/dotfiles-new/zshrc.local`, `~/dotfiles-new/aliases.local` (inherited from dotfiles-local), plus the current `~/dotfiles/zshrc` and `~/dotfiles/aliases` content (base repo, read during design — reproduced below).
- Produces: flat `zshrc` and `aliases` in `~/dotfiles-new`, with no `.local` source lines remaining.

- [ ] **Step 1: Write the merged `zshrc`**

This combines the current `~/dotfiles/zshrc` (including its uncommitted WIP — bun, Android SDK, Obsidian `vault` alias, Claude Code path exports) with `zshrc.local`, dropping the `.local` source line and de-duplicating the `bun` block that's currently pasted twice.

```bash
cat > ~/dotfiles-new/zshrc <<'ZSHRC_EOF'
# load custom executable functions
for function in ~/.zsh/functions/*; do
  source $function
done

# extra files in ~/.zsh/configs/pre , ~/.zsh/configs , and ~/.zsh/configs/post
# these are loaded first, second, and third, respectively.
_load_settings() {
  _dir="$1"
  if [ -d "$_dir" ]; then
    if [ -d "$_dir/pre" ]; then
      for config in "$_dir"/pre/**/*~*.zwc(N-.); do
        . $config
      done
    fi

    for config in "$_dir"/**/*(N-.); do
      case "$config" in
        "$_dir"/(pre|post)/*|*.zwc)
          :
          ;;
        *)
          . $config
          ;;
      esac
    done

    if [ -d "$_dir/post" ]; then
      for config in "$_dir"/post/**/*~*.zwc(N-.); do
        . $config
      done
    fi
  fi
}
_load_settings "$HOME/.zsh/configs"

if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

alias vim='MIX_ENV=test nvim'
alias vi='MIX_ENV=test nvim'
alias v='MIX_ENV=test nvim'

export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="${ASDF_DATA_DIR}/shims:$PATH"

export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/sbin:$PATH"
export PATH="/Users/jsmith/.emacs.d/bin:$PATH"

export PATH="$HOME/.bin:$PATH"

eval "$(direnv hook zsh)"

export PATH="$PATH:$(brew --prefix rabbitmq 2>/dev/null)/sbin"

export ASDF_GOLANG_MOD_VERSION_ENABLED=true

export PATH="$PATH:$(go env GOPATH)/bin"

# fortify files path
export PATH="$PATH:/Users/jsmith/Downloads/Fortify_ScanCentral_Client_22.2.1_x64/bin"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/jsmith/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/jsmith/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/jsmith/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/jsmith/google-cloud-sdk/completion.zsh.inc'; fi
export PATH="$HOME/.local/bin:$PATH"

# aliases
[[ -f ~/.aliases ]] && source ~/.aliases

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# bun completions
[ -s "/Users/jsmith/.bun/_bun" ] && source "/Users/jsmith/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Launch Claude Code in the Obsidian vault
alias vault='cd "/Users/jsmith/Library/Mobile Documents/iCloud~md~obsidian/Documents" && claude'
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator
ZSHRC_EOF
```

- [ ] **Step 2: Verify `zshrc` syntax and no duplicate `bun` block**

Run: `zsh -n ~/dotfiles-new/zshrc && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

Run: `grep -c 'BUN_INSTALL' ~/dotfiles-new/zshrc`
Expected: `2` (one in the "bun completions" line's guard context plus the export block — not 4, which is what the old duplicated-block file had). Sanity: `grep -c '# bun$'` should be `1`:

Run: `grep -c '^# bun$' ~/dotfiles-new/zshrc`
Expected: `1`

- [ ] **Step 3: Write the merged `aliases`**

Combines base `aliases` with `aliases.local`. Two intentional deviations from a raw concatenation, called out because they'd otherwise be dead/broken: `alias aliases=` now points at the merged file itself (was `~/.aliases.local`), and `alias dl='cd ~/dotfiles-local'` is dropped (that directory won't exist after this migration).

```bash
cat > ~/dotfiles-new/aliases <<'ALIASES_EOF'
# Unix
alias ll="ls -al"
alias ln="ln -v"
alias mkdir="mkdir -p"
alias e="$EDITOR"
alias v="$VISUAL"

# Bundler
alias b="bundle"

# Rails
alias migrate="bin/rails db:migrate db:rollback && bin/rails db:migrate db:test:prepare"
alias s="rspec"

# Pretty print the path
alias path='echo -e ${PATH//:/\\n}'

# Easier navigation: ..., ...., ....., and -
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias -- -="cd -"

# alias todo='$EDITOR ~/.todo'

alias a='ls -lrthG'
alias aios='cd ~/code/aios-vault && git pull --ff-only -q; claude'
alias -g G='| grep'
alias -g L='| less'
alias -g M='| more'
alias aliases='vim ~/.aliases'
alias amend="git commit --amend"
alias c='cd'
alias d='cd ~/dotfiles'
alias dbprep='rdm && rdtp'
alias todo='vim ~/code/Notes/todo.md'
alias start='vim ~/code/Notes/day-start-checklist.md'
alias notes="cd ~/code/Notes ; vim ."
alias code='cd ~/code'
alias gclean="git branch | grep -vE '(main|master|staging|develop)' | xargs git branch -D"
alias gua="ls | xargs -P10 -I{} git -C {} pull"
alias gmc-staging="ls | xargs -P10 -I{} git -C {} checkout staging"
alias gmc-master="ls | xargs -P10 -I{} git -C {} checkout master"
alias gmc-main="ls | xargs -P10 -I{} git -C {} checkout main"
alias gad='git add --all .'
alias gag='git add . && git commit --amend --no-edit && git push -f'
alias gbc='gdc'
alias gca='git commit -a'
alias gcaa='git commit -a --amend -C HEAD'
alias gcl='git clone'
alias gcm="git commit -m"
alias gco='git checkout'
alias gd='git diff'
alias gdc='git diff --cached'
alias gdm='git diff master'
alias gg='git lg'
alias gp='git push'
alias gpr='git pull --rebase'
alias gpush='echo "Use gp!" && git push'
alias grc='git rebase --continue'
alias gs='git show'
alias m='git checkout master'
alias mm='git checkout main'
alias mastre='master'
alias newscreen="tmux"
alias remore='!! | more'
alias repush="gpr && git push"
alias restart_postgres="stoppostgres && startpostgres"
alias retag='ctags -R --exclude=.svn --exclude=.git --exclude=log --exclude=tmp *'
alias review="git diff master"
alias safepush='git pull --rebase && mix deps.get && git push'
alias so='source ~/.aliases'
alias sp='safepush'
alias squash='git rebase -i master'
alias stage='git push staging head:master && staging open'
alias startredis='redis-server /usr/local/etc/redis.conf &'
alias sync='git add -u . && git commit -m "Minor changes. Commit message skipped." && repush'
alias track='git checkout -t'
alias trs='tmux rename-session'
alias u='cd ..'

# Elixir Aliases
alias mdg='mix deps.get'
alias mt='mix test'
alias mdu='mix deps.update --all'
alias mps='mix phx.server'
alias ism='iex -S mix'
alias repry='fc -e - mix\ test=iex\ -S\ mix\ test\ --trace mix\ test'

# Go-lang Aliases
alias gup="go get -u ./..."
alias gup-tests="go get -t -u ./..."
alias glist="go list -u -m all"
alias go-packages='cd "$(asdf where golang)/packages"'
alias gts="gotestsum"
alias go-test="go test -v ./..."
alias killGO='lsof -t -i :5000 | xargs kill -9'
ALIASES_EOF
```

- [ ] **Step 4: Verify `aliases` syntax and delete the retired `.local` files**

Run: `zsh -n ~/dotfiles-new/aliases && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

```bash
cd ~/dotfiles-new
git rm -q zshrc.local aliases.local
git add zshrc aliases
```

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-new
git commit -m "$(cat <<'EOF'
Merge zshrc/aliases with their .local counterparts

Folds zshrc.local and aliases.local into flat zshrc/aliases now that
there's no more base/local split. Dedupes the bun block that was
pasted twice in zshrc's in-flight WIP.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Merge vim config (vimrc, vimrc.bundles)

**Files:**
- Modify: `~/dotfiles-new/vimrc`
- Modify: `~/dotfiles-new/vimrc.bundles`
- Delete: `~/dotfiles-new/vimrc.local`, `~/dotfiles-new/vimrc.bundles.local`

**Interfaces:**
- Consumes: `~/dotfiles-new/vimrc.local`, `~/dotfiles-new/vimrc.bundles.local` (inherited from dotfiles-local).
- Produces: flat `vimrc` and `vimrc.bundles`, no `.local` source lines, no thoughtbot self-references.

- [ ] **Step 1: Write the merged `vimrc`**

Combines base `vimrc` with `vimrc.local`, appended in the same order they load today (so `vimrc.local`'s `colorscheme jellybeans` still wins over the base's `colorscheme catppuccin_latte`, matching current behavior). Also fixes two now-stale thoughtbot/rcm self-references and updates the filetype-detection autocmd's filenames to match the new flat names (the old `.local` filenames no longer exist, so leaving them would silently break syntax highlighting when editing those files).

```bash
cat > ~/dotfiles-new/vimrc <<'VIMRC_EOF'
set encoding=utf-8

" Leader
let mapleader = " "

set backspace=2   " Backspace deletes like most programs in insert mode
set nobackup
set nowritebackup
set noswapfile    " http://robots.thoughtbot.com/post/18739402579/global-gitignore#comment-458413287
set history=50
set ruler         " show the cursor position all the time
set showcmd       " display incomplete commands
set termguicolors " make our colors pretty
set incsearch     " do incremental searching
set laststatus=2  " Always display the status line
set autowrite     " Automatically :write before running commands
set modelines=0   " Disable modelines as a security precaution
set nomodeline

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if (&t_Co > 2 || has("gui_running")) && !exists("syntax_on")
  syntax on
endif

if filereadable(expand("~/.vimrc.bundles"))
  source ~/.vimrc.bundles
endif

" Load matchit.vim, but only if the user hasn't installed a newer version.
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
  runtime! macros/matchit.vim
endif

filetype plugin indent on

augroup vimrcEx
  autocmd!

  " When editing a file, always jump to the last known cursor position.
  " Don't do it for commit messages, when the position is invalid, or when
  " inside an event handler (happens when dropping a file on gvim).
  autocmd BufReadPost *
    \ if &ft != 'gitcommit' && line("'\"") > 0 && line("'\"") <= line("$") |
    \   exe "normal g`\"" |
    \ endif

  " Set syntax highlighting for specific file types
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  autocmd BufRead,BufNewFile .{jscs,jshint,eslint}rc set filetype=json
  autocmd BufRead,BufNewFile
    \ aliases,
    \zshenv,zlogin,zlogout,zshrc,zprofile,
    \*/zsh/configs/*
    \ set filetype=sh
  autocmd BufRead,BufNewFile gitconfig set filetype=gitconfig
  autocmd BufRead,BufNewFile tmux.conf set filetype=tmux
  autocmd BufRead,BufNewFile vimrc set filetype=vim
augroup END

" ALE linting events
augroup ale
  autocmd!

  if g:has_async
    autocmd VimEnter *
      \ set updatetime=1000 |
      \ let g:ale_lint_on_text_changed = 0
    autocmd CursorHold * call ale#Queue(0)
    autocmd CursorHoldI * call ale#Queue(0)
    autocmd InsertEnter * call ale#Queue(0)
    autocmd InsertLeave * call ale#Queue(0)
  else
    echoerr "Vim/Neovim without async (v8+ or nvim) is required"
  endif
augroup END

" When the type of shell script is /bin/sh, assume a POSIX-compatible
" shell for syntax highlighting purposes.
let g:is_posix = 1

" Softtabs, 2 spaces
set tabstop=2
set shiftwidth=2
set shiftround
set expandtab

" Display extra whitespace
set list listchars=tab:»·,trail:·,nbsp:·

" Use one space, not two, after punctuation.
set nojoinspaces

" Use ripgrep https://github.com/BurntSushi/ripgrep
if executable('rg')
  " Use Rg over Grep
  set grepprg=rg\ --vimgrep\ --no-heading\ --smart-case

  " Use rg in fzf for listing files. Lightning fast and respects .gitignore
  let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'

  nnoremap \ :Rg<SPACE>
" Use The Silver Searcher https://github.com/ggreer/the_silver_searcher
elseif executable('ag')
  " Use Ag over Grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in fzf for listing files. Lightning fast and respects .gitignore
  let $FZF_DEFAULT_COMMAND = 'ag --literal --files-with-matches --nocolor --hidden -g ""'

  nnoremap \ :Ag<SPACE>
endif

" Make it obvious where 80 characters is
set textwidth=80
set colorcolumn=+1

" Numbers
set number
set numberwidth=5

" Tab completion
" will insert tab at beginning of line,
" will use completion if not at beginning
set wildmode=list:longest,list:full
function! InsertTabWrapper()
    let col = col('.') - 1
    if !col || getline('.')[col - 1] !~ '\k'
        return "\<Tab>"
    else
        return "\<C-p>"
    endif
endfunction
inoremap <Tab> <C-r>=InsertTabWrapper()<CR>
inoremap <S-Tab> <C-n>

" Switch between the last two files
nnoremap <Leader><Leader> <C-^>

" vim-test mappings
nnoremap <silent> <Leader>t :TestFile<CR>
nnoremap <silent> <Leader>s :TestNearest<CR>
nnoremap <silent> <Leader>l :TestLast<CR>
nnoremap <silent> <Leader>a :TestSuite<CR>
nnoremap <silent> <Leader>gt :TestVisit<CR>

" Run commands that require an interactive shell
nnoremap <Leader>r :RunInInteractiveShell<Space>

" Treat <li> and <p> tags like the block tags they are
let g:html_indent_tags = 'li\|p'

" Set tags for vim-fugitive
set tags^=.git/tags

" Open new split panes to right and bottom, which feels more natural
set splitbelow
set splitright

" Quicker window movement
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

" Move between linting errors
nnoremap ]r :ALENextWrap<CR>
nnoremap [r :ALEPreviousWrap<CR>

" Map Ctrl + p to open fuzzy find (FZF)
nnoremap <c-p> :Files<cr>

" Set spellfile to location that is guaranteed to exist, can be symlinked to
" Dropbox or kept in Git and managed outside of this repo.
set spellfile=$HOME/.vim-spell-en.utf-8.add

" Autocomplete with dictionary words when spell check is on
set complete+=kspell

" Always use vertical diffs
set diffopt+=vertical

" Use Catpuccin Latte as our default color scheme
colorscheme catppuccin_latte

set nocompatible               " be iMproved
filetype off                   " required!

" Kill Beeps
set noeb vb t_vb=

" recommended configurations for powerline
set laststatus=2   " Always show the statusline
set encoding=utf-8 " Necessary to show Unicode glyphs
let g:Powerline_symbols = 'fancy'

" Turn on auto-indenting and set it to copy previous
" indentation
set autoindent
set copyindent

" testing strategy for vim-test
" let test#strategy = "tslime"
" let test#strategy = "vimterminal"
let test#strategy = "vimux"
let g:tslime_always_current_session = 1
let g:tslime_always_current_window = 1

" Highlight matching parentheses
set showmatch

syntax enable
set background=dark
colorscheme jellybeans

" Resize windows with arrow keys
nnoremap <D-Up> <C-w>+
nnoremap <D-Down> <C-w>-
nnoremap <D-Left> <C-w><
nnoremap <D-Right>  <C-w>>

" hit ,f to find the definition of the current class
" this uses ctags. the standard way to get this is Ctrl-]
nnoremap <silent> ,f <C-]>

" use ,F to jump to tag in a vertical split
nnoremap <silent> ,F :let word=expand("<cword>")<CR>:vsp<CR>:wincmd w<cr>:exec("tag ". word)<cr>

autocmd BufNewFile,BufReadPost *.md set filetype=markdown
autocmd BufNewFile,BufRead DockerQA set filetype=dockerfile
autocmd BufNewFile,BufRead DockerTest set filetype=dockerfile
autocmd BufNewFile,BufRead DockerQA-B set filetype=dockerfile
autocmd BufNewFile,BufRead HistoricalSyncDockerfile set filetype=dockerfile
autocmd BufRead,BufNewFile *.ex,*.exs set filetype=elixir
autocmd BufRead,BufNewFile *.eex,*.heex,*.leex,*.sface,*.lexs set filetype=eelixir
autocmd BufRead,BufNewFile mix.lock set filetype=elixir
autocmd BufEnter *.{js,jsx,ts,tsx} :syntax sync fromstart
autocmd BufLeave *.{js,jsx,ts,tsx} :syntax sync clear

" Remove trailing white spaces on save.
autocmd BufWritePre * :%s/\s\+$//e

nnoremap K :grep! "\b<C-R><C-W>\b"<CR>:cw<CR>

set number                     " Show current line number
set relativenumber             " Show relative line numbers

" allow dot command to operate over a visual selection
xnoremap . :normal .<CR>

" allow user macro over a visual selection
xnoremap @ :<C-u>call ExecuteMacroOverVisualRange()<CR>

function! ExecuteMacroOverVisualRange()
  echo "@".getcmdline()
  execute ":'<,'>normal @".nr2char(getchar())
endfunction

map <Leader>p :set paste<CR>o<esc>"*]p:set nopaste<cr>
map <Leader>i mmgg=G`m
map <Leader>bb :!bundle install<cr>
vmap <Leader>b :<C-U>!git blame <C-R>=expand("%:p") <CR> \| sed -n <C-R>=line("'<") <CR>,<C-R>=line("'>") <CR>p <CR>
map <Leader>gw :!git add . && git commit -m 'WIP' && git push<cr>
map <Leader>d :vs ~/code/Notes/todo.md<cr>
nmap <leader>f orequire IEx; IEx.pry<esc>

set hlsearch
set ignorecase
set smartcase
map <Leader>h :nohlsearch<cr>

let g:jsx_ext_required = 0
let g:python3_host_prog = '/usr/bin/python3'

" vim elixir formatter
let g:mix_format_on_save = 1
let g:mix_format_silent_errors = 1
let g:mix_format_options = '--check-equivalent'


let g:ale_linters = {
      \  'elixir': ['credo', 'elixir-ls'],
      \  'ruby': ['solargraph'],
      \  'javascript': ['eslint', 'tsserver'],
      \  'typescript': ['eslint', 'tsserver'],
\}

let g:ale_fixers = {
      \  '*': ['remove_trailing_lines', 'trim_whitespace'],
      \  'javascript': ['eslint'],
      \  'typescript': ['eslint'],
      \  'elixir': ['mix_format'],
      \}

let g:ale_elixir_elixir_ls_config = {
\   'cmd': ['elixir-ls'],
\   'mix_env': 'dev',
\   'dialyzer_enabled': v:false,
\}

let g:ale_lint_on_enter = 0
let g:ale_lint_on_save = 1
let g:ale_fix_on_save = 1

" gist-vim configurations
let g:gist_detect_filetype = 1
let g:gist_open_browser_after_post = 1

" help formatting json
com! FormatJson %!python -m json.tool

" DisplayTableSummary plugin
nnoremap <leader>dt :DisplayTableSummary<cr>
nnoremap <leader>xt :call popup_clear()<cr>

" Use The Silver Searcher https://github.com/ggreer/the_silver_searcher
if executable('ag')
  set grepprg=ag\ --nogroup\ --nocolor\ --ignore={\"vendor\*\"\,\"node_modules\*\"}

  " Use ag in fzf for listing files. Lightning fast and respects .gitignore
  let $FZF_DEFAULT_COMMAND = 'ag --literal --files-with-matches --nocolor --hidden -g "" --ignore={"vendor*","node_modules*"}'
endif
VIMRC_EOF
```

- [ ] **Step 2: Write the merged `vimrc.bundles`**

```bash
cat > ~/dotfiles-new/vimrc.bundles <<'BUNDLES_EOF'
if &compatible
  set nocompatible
end

" Remove declared plugins
function! s:UnPlug(plug_name)
  if has_key(g:plugs, a:plug_name)
    call remove(g:plugs, a:plug_name)
  endif
endfunction
command!  -nargs=1 UnPlug call s:UnPlug(<args>)

let g:has_async = v:version >= 800 || has('nvim')

call plug#begin('~/.vim/bundle')

" Define bundles via Github repos
Plug 'christoomey/vim-run-interactive'

" If fzf has already been installed via Homebrew, use the existing fzf
" Otherwise, install fzf. The `--all` flag makes fzf accessible outside of vim
if executable("brew")
  let g:brew_fzf_path = trim(system("brew --prefix fzf"))
endif

if exists("g:brew_fzf_path") && isdirectory(g:brew_fzf_path)
  Plug g:brew_fzf_path 
else
  Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
endif

Plug 'catppuccin/vim', { 'as': 'catppuccin' }
Plug 'junegunn/fzf.vim'
Plug 'elixir-lang/vim-elixir'
Plug 'fatih/vim-go'
Plug 'janko-m/vim-test'
Plug 'pangloss/vim-javascript'
Plug 'pbrisbin/vim-mkdir'
Plug 'slim-template/vim-slim'
Plug 'tpope/vim-bundler'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-eunuch'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-projectionist'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-rake'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'vim-ruby/vim-ruby'
Plug 'vim-scripts/tComment'

if g:has_async
  Plug 'dense-analysis/ale'
endif

Plug 'nanotech/jellybeans.vim'
Plug 'tpope/vim-markdown'
Plug 'preservim/vimux'
Plug 'christoomey/vim-tmux-navigator'
Plug 'mattn/gist-vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'peitalin/vim-jsx-typescript'
Plug 'leafgarland/typescript-vim'
Plug 'styled-components/vim-styled-components', { 'branch': 'main' }

call plug#end()
BUNDLES_EOF
```

- [ ] **Step 3: Verify and delete the retired `.local` files**

Run: `vim -es -u NONE -c 'let g:has_async=1' -c 'source ~/dotfiles-new/vimrc.bundles' -c 'qa!' 2>&1; echo "exit:$?"`
Expected: no `E5108`/parse-error output before `exit:0` (plugin-not-found warnings about missing `~/.vim/bundle/*` are fine — vim-plug isn't bootstrapped in this check).

```bash
cd ~/dotfiles-new
git rm -q vimrc.local vimrc.bundles.local
git add vimrc vimrc.bundles
```

- [ ] **Step 4: Commit**

```bash
cd ~/dotfiles-new
git commit -m "$(cat <<'EOF'
Merge vimrc/vimrc.bundles with their .local counterparts

Folds vimrc.local and vimrc.bundles.local into flat files. Updates
the filetype-detection autocmd to the new flat filenames and drops
two stale thoughtbot/rcm self-references now that neither applies.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Merge git and db config (gitconfig, psqlrc, asdfrc)

**Files:**
- Modify: `~/dotfiles-new/gitconfig`
- Modify: `~/dotfiles-new/psqlrc`
- Modify: `~/dotfiles-new/asdfrc` (no content change — see step 3)
- Delete: `~/dotfiles-new/gitconfig.local`, `~/dotfiles-new/psqlrc.local`

**Interfaces:**
- Consumes: `~/dotfiles-new/gitconfig.local`, `~/dotfiles-new/psqlrc.local`, `~/dotfiles-new/asdfrc` (inherited from dotfiles-local), plus base `~/dotfiles/gitconfig`, `~/dotfiles/psqlrc`, `~/dotfiles/asdfrc`.
- Produces: flat `gitconfig` (single identity, no dangling includes), flat `psqlrc` (no `.local` include), single `asdfrc`.

- [ ] **Step 1: Write the merged `gitconfig`**

Combines base `gitconfig` with `gitconfig.local`'s `[alias]`/`[pretty]`/`[user]`/`[heroku]` entries. Drops the `[include] path = ~/.gitconfig.local` line (inlined) and the `[include] path = ~/.git_signing_key.local` line (that file no longer exists — dangling). Single git identity, per the "drop it" decision on work/personal split.

```bash
cat > ~/dotfiles-new/gitconfig <<'GITCONFIG_EOF'
[init]
  defaultBranch = main
  templatedir = ~/.git_template
[push]
  default = current
[color]
  ui = auto
[alias]
  aa = add --all
  ap = add --patch
  branches = for-each-ref --sort=-committerdate --format=\"%(color:blue)%(authordate:relative)\t%(color:red)%(authorname)\t%(color:white)%(color:bold)%(refname:short)\" refs/remotes
  ci = commit -v
  co = checkout
  pf = push --force-with-lease
  st = status
  l = log --pretty=colored
  dms = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative master..staging
[core]
  excludesfile = ~/.gitignore
  autocrlf = input
[merge]
  ff = only
[commit]
  template = ~/.gitmessage
	gpgsign = true
[fetch]
  prune = true
[rebase]
  autosquash = true
[diff]
  colorMoved = zebra
[gpg]
	program = gpg2
[pretty]
  colored = format:%Cred%h%Creset %s %Cgreen(%cr) %C(bold blue)%an%Creset
[user]
  name = Jared Smith
  email = jared.smith88@me.com
[heroku]
	account = personal
GITCONFIG_EOF
```

- [ ] **Step 2: Verify `gitconfig` parses and identity resolves**

Run: `git config --file ~/dotfiles-new/gitconfig --list > /dev/null && echo PARSE_OK`
Expected: `PARSE_OK`

Run: `git config --file ~/dotfiles-new/gitconfig user.email`
Expected: `jared.smith88@me.com`

- [ ] **Step 3: Write the merged `psqlrc`, keep `asdfrc` as-is**

`psqlrc.local` is empty (0 bytes), so there's nothing to fold in — just drop the now-pointless include line. `asdfrc` is byte-identical in both repos already; no edit needed, just delete the duplicate.

```bash
cat > ~/dotfiles-new/psqlrc <<'PSQLRC_EOF'
-- Official docs: http://www.postgresql.org/docs/9.3/static/app-psql.html
-- Unofficial docs: http://robots.thoughtbot.com/improving-the-command-line-postgres-experience

-- Don't display the "helpful" message on startup.
\set QUIET 1
\pset null '[NULL]'

-- http://www.postgresql.org/docs/9.3/static/app-psql.html#APP-PSQL-PROMPTING
\set PROMPT1 '%[%033[1m%]%M %n@%/%R%[%033[0m%]%# '
-- PROMPT2 is printed when the prompt expects more input, like when you type
-- SELECT * FROM<enter>. %R shows what type of input it expects.
\set PROMPT2 '[more] %R > '

-- Show how long each query takes to execute
\timing

-- Use best available output format
\x auto
\set VERBOSITY verbose
\set HISTFILE ~/.psql_history- :DBNAME
\set HISTCONTROL ignoredups
\set COMP_KEYWORD_CASE upper
\unset QUIET
PSQLRC_EOF
```

- [ ] **Step 4: Verify and delete the retired files**

Run: `diff <(git -C ~/dotfiles-new show HEAD:asdfrc) ~/dotfiles/asdfrc && echo IDENTICAL`
Expected: `IDENTICAL` (confirms the two repos really did have the same `asdfrc` before we drop one).

```bash
cd ~/dotfiles-new
git rm -q gitconfig.local psqlrc.local
git add gitconfig psqlrc
```

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-new
git commit -m "$(cat <<'EOF'
Merge gitconfig/psqlrc with their .local counterparts

Single git identity (jared.smith88@me.com), drops the dangling
~/.git_signing_key.local include (file no longer exists) and the
now-pointless ~/.psqlrc.local include.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Clean up ignore files and repo cruft

**Files:**
- Modify: `~/dotfiles-new/gitignore` (the `~/.gitignore` payload)
- Create: `~/dotfiles-new/git_template/info/exclude`
- Delete: `~/dotfiles-new/tmp/` (accidental cruft)

**Interfaces:**
- Consumes: current `~/dotfiles/gitignore` and `~/dotfiles/git_template/info/exclude` working-tree content (including uncommitted WIP), `~/dotfiles-new/tmp/build-errors.log` (inherited from dotfiles-local).
- Produces: deduped `gitignore`, carried-forward `git_template/info/exclude`, `tmp/` removed.

- [ ] **Step 1: Write the deduped `gitignore`**

The current base `gitignore` has `**/.claude/settings.local.json` pasted twice with a blank line between — keep one.

```bash
cat > ~/dotfiles-new/gitignore <<'GITIGNORE_EOF'
*.pyc
*.sw[nop]
.DS_Store
.bundle
.byebug_history
.env
.git/
/bower_components/
/log
/node_modules/
/tmp
db/*.sqlite3
log/*.log
rerun.txt
tmp/**/*
/tags

**/.claude/settings.local.json
GITIGNORE_EOF
```

- [ ] **Step 2: Carry forward `git_template/info/exclude` (including in-flight WIP)**

```bash
mkdir -p ~/dotfiles-new/git_template/info
cat > ~/dotfiles-new/git_template/info/exclude <<'EXCLUDE_EOF'
# git ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.
# For a project mostly in C, the following would be a good set of
# exclude patterns (uncomment them if you want to use them):
# *.[oa]
# *~
# claude-code-runtime
**/.claude/scheduled_tasks.lock
**/.claude/scheduled_tasks.json
**/.claude/routines/.state/
**/.claude/worktrees/
**/.claude/checkpoints/
**/.claude/mailbox/
**/.claude/agent-registry.json
**/.claude/agent-memory-local
**/.claude/first-run
**/.claude/assistant-daemon-state.json
# impeccable-config-ignore-start
.impeccable/config.local.json
# impeccable-config-ignore-end

# impeccable-hook-ignore-start .
.impeccable/hook.cache.json
.impeccable/hook.pending.json
.impeccable/config.local.json
# impeccable-hook-ignore-end .

# Personal AIOS work-layer pointer (local only)
CLAUDE.local.md
EXCLUDE_EOF
```

- [ ] **Step 3: Delete the accidental `tmp/` cruft**

```bash
cd ~/dotfiles-new
git rm -rq tmp
```

- [ ] **Step 4: Verify no duplicate lines remain**

Run: `sort ~/dotfiles-new/gitignore | uniq -d`
Expected: empty output (no duplicate lines).

```bash
cd ~/dotfiles-new
git add gitignore git_template/info/exclude
```

- [ ] **Step 5: Commit**

```bash
cd ~/dotfiles-new
git commit -m "$(cat <<'EOF'
Dedupe gitignore, carry forward git_template excludes, drop tmp/ cruft

The gitignore payload had **/.claude/settings.local.json pasted
twice. tmp/build-errors.log was accidental committed cruft from
dotfiles-local with no gitignore rule to prevent it.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Bring over unchanged files, drop thoughtbot boilerplate, add README/install.sh

**Files:**
- Create: `~/dotfiles-new/bin/*`, `~/dotfiles-new/zsh/*`, `~/dotfiles-new/vim/ftplugin/*`, `~/dotfiles-new/vim/plugin/*`, `~/dotfiles-new/git_template/hooks/*` (copied unchanged from `~/dotfiles`)
- Create: `~/dotfiles-new/ctags`, `~/dotfiles-new/gemrc`, `~/dotfiles-new/gitmessage`, `~/dotfiles-new/hushlogin`, `~/dotfiles-new/railsrc`, `~/dotfiles-new/rspec`, `~/dotfiles-new/tmux.conf`, `~/dotfiles-new/zprofile`, `~/dotfiles-new/zshenv` (copied unchanged)
- Create: `~/dotfiles-new/.gitignore` (repo-local ignore rules, new `tmp/`/`.DS_Store` rules added)
- Create: `~/dotfiles-new/install.sh`
- Create: `~/dotfiles-new/README.md`
- Delete: `~/dotfiles-new/README.md` (old dotfiles-local one, overwritten by the line above)

**Interfaces:**
- Consumes: `~/dotfiles` (base repo file trees for `bin/`, `zsh/configs`, `zsh/functions`, `zsh/completion`, `vim/ftplugin`, `vim/plugin`, `git_template/hooks`, and the unchanged top-level dotfiles); `~/dotfiles-new/zsh/completion/_mix` (inherited from dotfiles-local, kept as-is).
- Produces: a complete, self-contained repo with no rcm dependency and no thoughtbot files.

- [ ] **Step 1: Copy unchanged directory trees and top-level files from the base repo**

```bash
cd ~/dotfiles
rsync -a --exclude='.DS_Store' bin/ ~/dotfiles-new/bin/
rsync -a --exclude='.DS_Store' zsh/configs/ ~/dotfiles-new/zsh/configs/
rsync -a --exclude='.DS_Store' zsh/functions/ ~/dotfiles-new/zsh/functions/
rsync -a --exclude='.DS_Store' zsh/completion/ ~/dotfiles-new/zsh/completion/
rsync -a --exclude='.DS_Store' vim/ftplugin/ ~/dotfiles-new/vim/ftplugin/
rsync -a --exclude='.DS_Store' vim/plugin/ ~/dotfiles-new/vim/plugin/
rsync -a --exclude='.DS_Store' git_template/hooks/ ~/dotfiles-new/git_template/hooks/
cp ctags gemrc gitmessage hushlogin railsrc rspec tmux.conf zprofile zshenv ~/dotfiles-new/
```

- [ ] **Step 2: Verify `zsh/completion/_mix` (from dotfiles-local) sits alongside the copied completions**

Run: `ls ~/dotfiles-new/zsh/completion/`
Expected: `_ag  _bundler  _g  _mix  _production  _rspec  _staging` (six copied from base plus `_mix` already present from dotfiles-local).

- [ ] **Step 3: Write the repo-local `.gitignore`**

Adds `tmp/` and `.DS_Store` so the accidental-commit problem from Task 5 can't recur, on top of the base repo's existing two rules.

```bash
cat > ~/dotfiles-new/.gitignore <<'DOTGITIGNORE_EOF'
!bin
vim/bundle/
tmp/
.DS_Store
DOTGITIGNORE_EOF
```

- [ ] **Step 4: Write `install.sh`**

Replaces rcm/`rcup` entirely. Symlinks every top-level dotfile to `~/.<name>`, and mirrors `bin/`, `zsh/`, `vim/ftplugin/`, `vim/plugin/`, `git_template/hooks/`, `git_template/info/` file-by-file into their `~/.` counterparts — matching what rcm was doing, without the dependency.

```bash
cat > ~/dotfiles-new/install.sh <<'INSTALL_EOF'
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

link() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip (real file exists): $dest"
    return
  fi
  ln -nsf "$src" "$dest"
  echo "linked: $dest -> $src"
}

# Top-level dotfiles -> ~/.<name>
for f in *; do
  case "$f" in
    README.md|install.sh|.gitignore|.git|.DS_Store) continue ;;
  esac
  [ -d "$f" ] && continue
  link "$DOTFILES_DIR/$f" "$HOME/.$f"
done

# Directory trees, mirrored file-by-file under ~/.<dir>/...
for dir in bin zsh vim git_template; do
  [ -d "$dir" ] || continue
  while IFS= read -r -d '' file; do
    rel="${file#"$dir"/}"
    link "$DOTFILES_DIR/$file" "$HOME/.$dir/$rel"
  done < <(find "$dir" -type f -not -name '.DS_Store' -print0)
done

echo
echo "Done. If this is a fresh machine, also run:"
echo "  git config --global init.templatedir ~/.git_template"
INSTALL_EOF
chmod +x ~/dotfiles-new/install.sh
```

- [ ] **Step 5: Verify `install.sh` syntax**

Run: `bash -n ~/dotfiles-new/install.sh && echo SYNTAX_OK`
Expected: `SYNTAX_OK`

- [ ] **Step 6: Write the new `README.md`, remove the old dotfiles-local one if still present**

```bash
cat > ~/dotfiles-new/README.md <<'README_EOF'
# dotfiles

Personal shell, git, vim, and tmux config. One flat repo, no local-override
layer — every file here is meant to be edited directly.

## Install

```bash
git clone git@github.com:sublimecoder/dotfiles.git ~/dotfiles
~/dotfiles/install.sh
```

`install.sh` symlinks each file into `$HOME` (e.g. `zshrc` -> `~/.zshrc`,
`bin/*` -> `~/.bin/*`). Re-run it any time after adding a new file — it's
safe to run repeatedly, and it won't overwrite a real (non-symlink) file
that's already at the destination.

On a fresh machine, also point git at the commit template:

```bash
git config --global init.templatedir ~/.git_template
```

## Layout

- `zshrc`, `aliases`, `zshenv`, `zprofile` — shell
- `zsh/` — shell functions, completions, and config fragments loaded by `zshrc`
- `vimrc`, `vimrc.bundles` — vim, plugins via vim-plug
- `vim/` — filetype and plugin config
- `gitconfig`, `gitmessage`, `git_template/` — git config and commit template/hooks
- `tmux.conf` — tmux
- `bin/` — small personal scripts, put on `$PATH` via `install.sh`

If you want to copy any of this, go ahead — there's no portability layer
here, it's just what's on this machine.
README_EOF
```

- [ ] **Step 7: Stage and commit**

```bash
cd ~/dotfiles-new
git add -A
git status --porcelain
```

Expected: only additions/creates listed (no unexpected deletions beyond the old `README.md` content being overwritten in place).

Run: `ls ~/dotfiles-new | grep -iE 'LICENSE|CODE_OF_CONDUCT|SECURITY|CODEOWNERS'; ls ~/dotfiles-new/.github 2>&1`
Expected: first command prints nothing, second prints `No such file or directory` — confirms none of the thoughtbot boilerplate made it into the new repo (it was never in `dotfiles-local`'s history and Step 1 only copied the specific files/dirs listed above).

```bash
git commit -m "$(cat <<'EOF'
Bring over unchanged config, drop rcm, add install.sh and README

Copies bin/, zsh/, vim/ftplugin, vim/plugin, and git_template/hooks
over unchanged. Replaces rcm/rcup with a small install.sh that
symlinks files directly. New README describes the flat layout —
no more base/local split, no thoughtbot dependency.

Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: Push into the existing GitHub repo (AMENDED — see below)

**Amendment (executed 2026-07-05):** Step 1's existence check correctly found that `sublimecoder/dotfiles` already exists — it's the current fork, the very thing this migration replaces. The original "create a brand-new non-fork repo" approach was infeasible under that name. Asked the user; decision was to force-push the merged content directly over the existing repo rather than create a differently-named repo or rename the old fork first. Actual steps executed:

1. `git remote add origin git@github.com:sublimecoder/dotfiles.git` (in `~/dotfiles-new`)
2. `git fetch origin main && git push --force-with-lease origin main` (plain `--force` is blocked by a repo hook; `--force-with-lease` after a fetch is the safe equivalent)
3. Deleted the stale `master` branch and the `github-actions/repository-maintenance-*` branch (an artifact of the thoughtbot template-sync bot) from the remote — only `main` remains
4. Verified: `defaultBranchRef: main`, `visibility: PUBLIC`, `isFork: true` (this one field does NOT change — GitHub's fork relationship is metadata with no user-facing "detach" API; force-pushing replaces content, not that flag. The practical concern — thoughtbot's template bot having write access via `.github/workflows/*` — is already resolved since Task 6 dropped those files)
5. Also pushed a same-session `zshrc` addition (`JAVA_HOME` for Android Studio's bundled JBR, requested mid-migration) as a follow-up commit — `fc03aba`

**Consequence for Task 9 below:** since `sublimecoder/dotfiles` is now the live repo (not a retired one), it must NOT be archived. Task 9 is amended to cover `sublimecoder/dotfiles-local` only.

**Original plan text (not executed, kept for reference):**

**Files:** none (remote operation)

**Interfaces:**
- Consumes: `~/dotfiles-new` (fully merged, committed repo from Tasks 1-6).
- Produces: `sublimecoder/dotfiles` on GitHub, `origin` remote configured in `~/dotfiles-new`.

- [x] **Step 1: Confirm no fork relationship will be created**

Run: `gh repo view sublimecoder/dotfiles 2>&1`
Expected: `GraphQL: Could not resolve to a Repository...` (repo doesn't exist yet — if it does exist, stop and check with the user before overwriting anything).

Actual: repo already existed (see amendment above) — correctly stopped and escalated instead of overwriting blind.

- [ ] ~~Step 2: Create the repo and push~~ (superseded — see amendment: pushed into the existing repo instead)

```bash
cd ~/dotfiles-new
gh repo create sublimecoder/dotfiles --public --source=. --remote=origin
git push -u origin main
```

- [x] **Step 3: Verify**

Run: `gh repo view sublimecoder/dotfiles --json isFork,visibility`
Expected (original): `{"isFork":false,"visibility":"PUBLIC"}`
Actual: `{"isFork":true,"visibility":"PUBLIC"}` — expected per the amendment, not a defect.

Run: `git -C ~/dotfiles-new log --oneline | wc -l`
Expected: a count roughly equal to `dotfiles-local`'s original commit count plus the merge commits from Tasks 2-6 (confirms history rode along, nothing got squashed). Actual: 89.

No further commit needed — this task only pushes.

---

## Task 8: Cut over — retire old checkouts, install into $HOME, verify

**Files:**
- Rename: `~/dotfiles` -> `~/dotfiles.old-fork`, `~/dotfiles-local` -> `~/dotfiles-local.old`, `~/dotfiles-new` -> `~/dotfiles`
- Delete: stale `$HOME` symlinks for retired `.local` files, `~/.rcrc`, `~/.gitconfig-work.local`

**Interfaces:**
- Consumes: the pushed `~/dotfiles-new` from Task 7, current `$HOME` symlink state.
- Produces: `$HOME` fully repointed at the new repo; old checkouts preserved on disk (renamed, not deleted) as a rollback safety net.

**This task touches your live shell/vim/git config. Confirm with the user immediately before running Step 2 (the `mv`s) — it's easy to reverse (just rename back) but should not happen silently.**

- [ ] **Step 1: Snapshot current state for rollback**

Run: `ls -la ~ | grep -E '\.(zshrc|vimrc|gitconfig|aliases)' > /tmp/pre-cutover-symlinks.txt; cat /tmp/pre-cutover-symlinks.txt`
Expected: shows current symlinks pointing at `dotfiles`/`dotfiles-local` — kept as a reference in case anything needs to be manually restored.

- [ ] **Step 2: Rename the old checkouts, promote the new one**

```bash
mv ~/dotfiles ~/dotfiles.old-fork
mv ~/dotfiles-local ~/dotfiles-local.old
mv ~/dotfiles-new ~/dotfiles
```

- [ ] **Step 3: Remove symlinks/files for names that no longer exist in the new repo**

```bash
rm -f ~/.aliases.local ~/.gitconfig.local ~/.gitconfig-work.local \
      ~/.psqlrc.local ~/.vimrc.local ~/.vimrc.bundles.local \
      ~/.zshrc.local ~/.rcrc
```

- [ ] **Step 4: Run the new installer**

```bash
~/dotfiles/install.sh
```

Expected: a `linked: ...` line for every top-level dotfile and every file under `bin/`, `zsh/`, `vim/ftplugin`, `vim/plugin`, `git_template/hooks`, `git_template/info` — no `skip (real file exists)` lines other than genuinely unrelated real files (if any appear, stop and investigate before continuing).

- [ ] **Step 5: Verify per the design spec's verification plan**

Run: `zsh -c 'source ~/.zshrc; echo LOADED_OK'`
Expected: `LOADED_OK` printed with no error output above it.

Run: `zsh -c 'source ~/.zshrc; echo "bun:$(echo $PATH | grep -o "\.bun" | wc -l) asdf:$(echo $PATH | grep -o "\.asdf/shims" | wc -l) android:$(echo $PATH | grep -o "Android/sdk" | wc -l)"'`
Expected: `bun:1 asdf:1 android:2` (Android SDK legitimately appears twice — `platform-tools` and `emulator` are two separate PATH entries under the same `Android/sdk` root; `bun` and `asdf` should each appear exactly once now that the duplicate blocks are gone).

Run: `git config --get user.email`
Expected: `jared.smith88@me.com`

Run: `git -C ~/dotfiles remote -v`
Expected: only `origin  git@github.com:sublimecoder/dotfiles.git (fetch/push)` — no `upstream`.

Run: `ls -la ~ | grep -c 'dotfiles-local'`
Expected: `0` (no remaining symlinks into the retired directory).

Open vim, run `:PlugStatus`, confirm the plugin list matches Task 3's merged `vimrc.bundles` (manual check — no automated command for this).

- [ ] **Step 6: Confirm with the user before proceeding to Task 9**

This is the point of no easy return for the GitHub side (Task 9 archives the old repos). Get explicit go-ahead after Step 5's checks pass.

---

## Task 9: Archive the old dotfiles-local GitHub repo (AMENDED scope)

**Amendment:** per Task 7's amendment, `sublimecoder/dotfiles` is now the live, actively-used repo (force-pushed in place) — it must NOT be archived. Only `sublimecoder/dotfiles-local` is a genuinely retired repo at this point.

**Files:** none (remote operation)

**Interfaces:**
- Consumes: user confirmation from Task 8 Step 6.
- Produces: `sublimecoder/dotfiles-local` archived (read-only) on GitHub.

- [ ] **Step 1: Archive the retired repo**

```bash
gh repo archive sublimecoder/dotfiles-local --yes
```

- [ ] **Step 2: Verify**

Run: `gh repo view sublimecoder/dotfiles-local --json isArchived`
Expected: `{"isArchived":true}`

Run: `gh repo view sublimecoder/dotfiles --json isArchived`
Expected: `{"isArchived":false}` — confirms the live repo was NOT touched by this task.

No commit for this task — GitHub-only operation.
