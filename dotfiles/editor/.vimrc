" .vimrc — managed by dotfiles-bootstrap.
set nocompatible
syntax on
filetype plugin indent on

set number
set expandtab
set shiftwidth=2
set tabstop=2
set autoindent
set incsearch
set hlsearch
set ignorecase
set smartcase
set ruler
set laststatus=2
set backspace=indent,eol,start
set wildmenu

" Keep swap/backup noise out of the working tree.
set directory=~/.vim/swap//
set backupdir=~/.vim/backup//
silent! call mkdir($HOME . '/.vim/swap', 'p')
silent! call mkdir($HOME . '/.vim/backup', 'p')

" Clear search highlight with Enter.
nnoremap <CR> :nohlsearch<CR><CR>
