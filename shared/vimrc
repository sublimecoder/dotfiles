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
