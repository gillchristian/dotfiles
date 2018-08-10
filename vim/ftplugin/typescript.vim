if exists('g:loaded_tsuquyomi')
    nnoremap <buffer> <f5> :TsuReloadProject<cr>:w<cr>:echom 'Reloaded!'<cr>

    nnoremap <buffer> <localleader>t :echo tsuquyomi#hint()<cr>
    nnoremap <buffer> <localleader>i :TsuImport<cr>
    nnoremap <buffer> <localleader>f :TsuReferences<cr>
else
    :echom 'Tsuquyomi is not installed, maps won''t work'<cr>
endif

let b:ale_linters = {'typescript': ['tslint']}
