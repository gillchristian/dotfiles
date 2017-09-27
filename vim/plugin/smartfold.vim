if exists("g:loaded_SmartFold") || &cp
  finish
endif
let g:loaded_SmartFold = 100
let s:keepcpo = &cpo
set cpo&vim

function! s:SmartFoldFn()
  let l:filetype = &filetype

  if l:filetype ==# 'javascript'
    execute "normal! zfaB"
  elseif l:filetype ==# 'html'
    execute "normal! zfat"
  endif
endfunction

noremap <silent> <unique> <script> <Plug>SmartFold :call <SID>SmartFoldFn()<CR>
\:call repeat#set("\<Plug>SmartFold", v:count)<CR>

nmap zff <Plug>SmartFold

let &cpo= s:keepcpo
unlet s:keepcpo
