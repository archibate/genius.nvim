local M = {}

function M.is_bufname_ok(bufname)
    return bufname ~= '' -- and vim.fn.filereadable(bufname) == 1
end

function M.fetch_current_buffer(cwd, opts, cursor)
    local curname = vim.api.nvim_buf_get_name(0)
    if not M.is_bufname_ok(curname) then return nil, nil, nil, nil end

    local lastline = vim.api.nvim_buf_line_count(0)
    if not cursor then
        cursor = vim.api.nvim_win_get_cursor(0)
    end
    local line, col = cursor[1], cursor[2]

    if vim.startswith(curname, cwd) then
        curname = curname:sub(1 + #cwd)
    end

    local prefix = ''
    local suffix = ''
    for _, text in ipairs(vim.api.nvim_buf_get_lines(0, 0, line - 1, true)) do
        prefix = prefix .. text .. '\n'
    end
    for _, text in ipairs(vim.api.nvim_buf_get_lines(0, line, lastline, true)) do
        suffix = suffix .. '\n' .. text
    end

    local text = vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]
    prefix = prefix .. text:sub(1, col)
    suffix = text:sub(col + 1) .. suffix

    local curft = vim.bo.filetype
    if curft and opts.filetype_hints[curft] then
        prefix = opts.filetype_hints[curft] .. prefix
    end

    return prefix, suffix, {line, col}, curname
end

function M.fetch_code(cwd, opts)
    local curbuf = vim.api.nvim_get_current_buf()
    local curprefix, cursuffix, cursor, curname = M.fetch_current_buffer(cwd, opts)
    if curprefix == nil then
        return nil, nil, nil
    end
    -- curprefix = escape_content(curprefix, opts)
    -- cursuffix = escape_content(cursuffix, opts)

    if opts.completion_buffers > 1 then
        local fullprefix = ''
        local buflist
        if opts.buffers_sort_mru then
            buflist = vim.split(vim.fn.execute(':ls t'), '\n', {plain = true})
        else
            buflist = vim.api.nvim_list_bufs()
        end
        local nbufs = 1
        for _, buf in ipairs(buflist) do
            if opts.buffers_sort_mru then
                buf = tonumber(buf:match('%s*(%d+)'))
            end
            if buf ~= nil and curbuf ~= buf and vim.api.nvim_buf_is_loaded(buf) then
                nbufs = nbufs + 1
                local exceeded = false
                if nbufs > opts.completion_buffers then
                    if not opts.exceeded_buffer_has_mark then
                        break
                    end
                    exceeded = true
                end
                local bufname = vim.api.nvim_buf_get_name(buf)
                if M.is_bufname_ok(bufname) then
                    -- bufname = escape_content(bufname, opts)
                    if exceeded then
                        local code = opts.marks.file_name .. bufname .. opts.marks.file_content .. opts.marks.file_eos
                        fullprefix = fullprefix .. code
                    else
                        local is_inside_cwd = vim.startswith(bufname, cwd)
                        if is_inside_cwd then
                            bufname = bufname:sub(1 + #cwd)
                        end
                        if is_inside_cwd or not opts.buffers_in_cwd_only then
                            local code = ''
                            local lastline = vim.api.nvim_buf_line_count(buf)
                            for _, text in ipairs(vim.api.nvim_buf_get_lines(buf, 0, lastline, true)) do
                                code = code .. text .. '\n'
                            end
                            -- code = escape_content(code, opts)
                            code = opts.marks.file_name .. bufname .. opts.marks.file_content .. code .. opts.marks.file_eos
                            fullprefix = fullprefix .. code
                        end
                    end
                end
            end
        end
        if nbufs > 1 or opts.single_buffer_has_mark then
            -- curname = escape_content(curname, opts)
            curprefix = opts.marks.file_name .. curname .. opts.marks.file_content .. curprefix
        end
        if #fullprefix ~= 0 then
            curprefix = fullprefix .. opts.marks.begin_above_mark .. curprefix
        end

    elseif opts.single_buffer_has_mark then
        -- curname = escape_content(curname, opts)
        curprefix = opts.marks.file_name .. curname .. opts.marks.file_content .. curprefix
    end

    if opts.list_cwd_files then
        local scanner = vim.loop.fs_scandir(cwd)
        if scanner then
            local fileinfo = opts.marks.cwd_files
            local had = false
            while true do
                local file = vim.loop.fs_scandir_next(scanner)
                if not file then break end
                if vim.fn.isdirectory(file) == 1 then
                    file = file .. '/'
                end
                -- file = escape_content(file, opts)
                fileinfo = fileinfo .. file .. '\n'
                had = true
            end
            fileinfo = fileinfo .. opts.marks.cwd_eos
            if had then
                curprefix = fileinfo .. curprefix
            end
        end
    end

    return curprefix, cursuffix, cursor
end

function M.get_buffer_text(bufnr)
    local linecount = vim.api.nvim_buf_line_count(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, linecount, true)
    local text = ''
    for _, line in ipairs(lines) do
        text = text .. line .. '\n'
    end
    return text:sub(1, -2)
end

return M
