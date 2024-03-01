local auto_drive = require'genius'

vim.api.nvim_create_user_command('GeniusChat', function ()
    auto_drive.open_chat_window()
end, {})

vim.api.nvim_create_user_command('GeniusToggle', function ()
    auto_drive.toggle_completion()
end, {})

vim.api.nvim_create_user_command('GeniusComplete', function ()
    auto_drive.code_completion()
end, {})

vim.api.nvim_create_user_command('GeniusHold', function ()
    auto_drive.code_completion(true)
end, {})

vim.api.nvim_create_user_command('GeniusAccept', function (opts)
    if auto_drive.completion_accept(opts.bang and 'word' or 'all') then
        auto_drive.code_completion()
    end
end, {bang = true})

vim.api.nvim_create_user_command('GeniusDismiss', function (opts)
    auto_drive.completion_dismiss(opts.bang and 'word' or 'all')
end, {bang = true})

vim.api.nvim_create_user_command('GeniusAcceptLine', function (opts)
    if auto_drive.completion_accept(opts.bang and 'char' or 'line') then
        auto_drive.code_completion()
    end
end, {bang = true})

vim.api.nvim_create_user_command('GeniusDismissLine', function (opts)
    auto_drive.completion_dismiss(opts.bang and 'char' or 'line')
end, {bang = true})

vim.cmd [[
function! s:SetStyle() abort
    if &t_Co == 256
        hi def GeniusSuggestion guifg=#808080 ctermfg=244
        hi def GeniusInformation guifg=#505050 ctermfg=244
    else
        hi def GeniusSuggestion guifg=#808080 ctermfg=8
        hi def GeniusInformation guifg=#505050 ctermfg=8
    endif
    hi def link GeniusAnnotation Normal
endfunction

function! s:TabExpr() abort
    if mode() !~# '^[iR]' || !luaeval("require'genius'.completion_visible()") || pumvisible()
        return "\t"
    endif
    return "\<Cmd>GeniusAccept\<CR>"
endfunction

function! s:LeftExpr() abort
    if mode() !~# '^[iR]' || !luaeval("require'genius'.completion_visible()")
        return "\<Left>"
    endif
    return "\<Cmd>GeniusDismiss!\<CR>"
endfunction

function! s:RightExpr() abort
    if mode() !~# '^[iR]'
        return "\<Right>"
    endif
    if !luaeval("require'genius'.completion_visible()")
        if getcurpos()[2] != len(getline('.')) + 1
            return "\<Right>"
        else
            return "\<Cmd>GeniusComplete\<CR>"
        endif
    endif
    return "\<Cmd>GeniusAccept!\<CR>"
endfunction

function! s:HomeExpr() abort
    if mode() !~# '^[iR]' || !luaeval("require'genius'.completion_visible()")
        return "\<Home>"
    endif
    return "\<Cmd>GeniusDismissLine\<CR>"
endfunction

function! s:EndExpr() abort
    if mode() !~# '^[iR]'
        return "\<End>"
    endif
    if !luaeval("require'genius'.completion_visible()")
        if getcurpos()[2] != len(getline('.')) + 1
            return "\<End>"
        else
            return "\<Cmd>GeniusComplete\<CR>"
        endif
    endif
    return "\<Cmd>GeniusAcceptLine\<CR>"
endfunction

function! s:DelExpr() abort
    if mode() !~# '^[iR]' || !luaeval("require'genius'.completion_visible()")
        return "\<Del>"
    endif
    return "\<Cmd>GeniusComplete\<CR>"
endfunction

function! s:MapKeys() abort
    if luaeval("require'genius'.get_options().keymaps.tab")
        imap <script><silent><nowait><expr> <Tab> <SID>TabExpr()
    endif
    if luaeval("require'genius'.get_options().keymaps.leftright")
        imap <script><silent><nowait><expr> <Left> <SID>LeftExpr()
        imap <script><silent><nowait><expr> <Right> <SID>RightExpr()
    endif
    if luaeval("require'genius'.get_options().keymaps.homeend")
        imap <script><silent><nowait><expr> <Home> <SID>HomeExpr()
        imap <script><silent><nowait><expr> <End> <SID>EndExpr()
    endif
    if luaeval("require'genius'.get_options().keymaps.delete")
        imap <script><silent><nowait><expr> <Del> <SID>DelExpr()
    endif
endfunction

function! s:ServerLeave() abort
endfunction

if v:true
    augroup Genius
        autocmd!
        autocmd InsertEnter,CursorMovedI,CompleteChanged * GeniusHold
        autocmd BufEnter * if mode() =~# '^[iR]'|call execute('GeniusHold')|endif
        autocmd BufLeave * if mode() =~# '^[iR]'|call execute('GeniusDismiss')|endif
        autocmd InsertLeave * GeniusDismiss
        autocmd ColorScheme,VimEnter * call s:SetStyle()
        autocmd VimEnter             * call s:MapKeys()
        autocmd VimLeave             * call s:ServerLeave()
        " autocmd CursorHold,CursorMoved,CursorMovedI * lua require'genius'.show_server_status()
    augroup end
else
    inoremap <C-Space> <Cmd>GeniusComplete<CR>
    imap <script><silent><nowait><expr> <Tab> <SID>TabExpr()
    nnoremap <C-Space> <Cmd>.GeniusComplete<CR>
    vnoremap <C-Space> <Cmd>GeniusComplete<CR>
end
]]
