nnoremap <buffer> <localleader>d :TernDev<cr>
nnoremap <buffer> <localleader>r :TernRename<cr>
" Usages
nnoremap <buffer> <localleader>u :TernRefs<cr>

nnoremap <buffer> <localleader>p :call JsBeautify()<cr>
vnoremap <buffer> <localleader>p :call RangeJsBeautify()<cr>
