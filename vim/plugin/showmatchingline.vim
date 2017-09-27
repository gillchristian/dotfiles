function! s:showmatchingline()
  normal zfaB
	" " Save cursor position and window view
	" let l:winview = winsaveview()

	" " Get matching line content and strip leading whitespace
	" normal %
	" let l:raw_line_content = getline('.')
	" let l:line_content = substitute(l:raw_line_content, '\v^\s+', '', '')

	" " Restore cursor position and window view
	" call winrestview(l:winview)

	" echom l:line_content
endfunction

nnoremap <leader>m <Plug>ShowMatchingLine
nnoremap <Plug>ShowMatchingLine :<c-u>call <SID>showmatchingline()<cr>
