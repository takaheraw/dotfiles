set nocompatible
filetype off

set rtp+=~/.vim/vundle.git/
call vundle#rc()

Bundle 'YankRing.vim'
Bundle 'Shougo/neocomplcache'
Bundle 'altercation/vim-colors-solarized'
Bundle 'Lokaltog/vim-easymotion'
Bundle 'thinca/vim-fontzoom'
Bundle 'thinca/vim-ft-markdown_fold'
Bundle 'thinca/vim-guicolorscheme'
Bundle 'nathanaelkane/vim-indent-guides'
Bundle 'fuenor/vim-make-syntax'
Bundle 'thinca/vim-quickrun'
Bundle 'thinca/vim-ref'
Bundle 'vim-ruby/vim-ruby'
Bundle 'tpope/vim-surround'
Bundle 'mattn/zencoding-vim'
Bundle 'mattn/webapi-vim'
Bundle 'mattn/gist-vim'
Bundle 'Shougo/vimfiler'
Bundle 'Shougo/unite.vim'
Bundle 'Shougo/vimproc'
Bundle 'Shougo/vimshell'

filetype plugin indent on 

" vim-ruby
set tabstop=2
set shiftwidth=2
set expandtab
set autoindent
set nocompatible
syntax on

" seach hilight
set hlsearch
set number

" sutatus bar
set laststatus=2

" statusline color
au InsertEnter * hi StatusLine guifg=DarkBlue guibg=DarkYellow gui=none ctermfg=Blue ctermbg=Yellow cterm=none
au InsertLeave * hi StatusLine guifg=DarkBlue guibg=DarkGray gui=none ctermfg=Blue ctermbg=DarkGray cterm=none

" colorscheme
colorscheme darkblue
syntax enable

" fileendodings
set termencoding=utf-8
set encoding=utf-8
set fileencodings=utf-8,euc-jp,iso-2022-jp

" clipboard
set clipboard+=autoselect

" indent hilight
let g:indent_guides_enable_on_vim_startup=1
let g:indent_guides_color_change_percent=30
let g:indent_guides_guide_size=1

" esc hilight
nnoremap <ESC><ESC> :nohlsearch<CR>

" vim-ref
let g:ref_refe_cmd = "/Users/takaheraw/Work/rubyrefm/refe-1_9_2"

" neocomplcache
let g:neocomplcache_enable_at_startup = 1
" " Disable AutoComplPop.
let g:acp_enableAtStartup = 0

" vimfiler IDE
nnoremap <silent> <Leader>fi :<C-u>VimFilerBufferDir -split -simple -winwidth=35 -no-quit<CR>
