function! s:LogLine()
  let l:filetype = &filetype

  if l:filetype ==# 'javascript'
    execute "normal! oconsole.log('Line: " . (line('.') + 1) . "');"
  else
    echom 'Filetype not supported'
  endif
endfunction

nnoremap <silent> <plug>LogLine :call <sid>LogLine()<cr>
\:call repeat#set("\<Plug>LogLine", v:count)<CR>
nmap <unique> <silent> <localleader>ll <plug>LogLine
