local M = {}

local utf8 = require 'genius.utf8'
local state = require 'genius.state'

M.namespace = vim.api.nvim_create_namespace('Genius')

function M.dissmiss_hint_at_cursor(buf)
    vim.api.nvim_buf_del_extmark(buf, M.namespace, 1)
end

function M.show_hint_at_cursor(code, cursor, buf, info)
    -- if code == '' then
    --     dissmiss_hint_at_cursor(buf)
    --     return
    -- end
    local line, col = cursor[1], cursor[2]
    local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1]
    code = vim.split(code, '\n', {plain = true})
    assert(#code ~= 0)
    local lines = {}
    local firstline = code[1]
    if #code >= 2 then
        lines = vim.list_slice(code, 2, #code - 1)
        vim.list_extend(lines, {code[#code] .. text:sub(col + 1)})
    else
        firstline = code[1] .. text:sub(col + 1)
    end
    local virt_lines = {}
    for i, v in ipairs(lines) do
        virt_lines[i] = {{v, 'GeniusSuggestion'}}
    end
    local data = {
        id = 1,
        hl_mode = 'combine',
        virt_text_win_col = utf8.utf8_text_width(text:sub(1, col)),
        virt_lines = virt_lines,
        virt_text = {{firstline, 'GeniusSuggestion'}, {info, 'GeniusInformation'}},
    }
    vim.api.nvim_buf_set_extmark(buf, M.namespace, line - 1, col, data)
end

function M.insert_at_cursor(code, cursor, buf, notrigger)
    if code == '' then return cursor end
    local line, col = cursor[1], cursor[2]
    local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1]
    code = vim.split(code, '\n', {plain = true})
    assert(#code ~= 0)
    local newline, newcol, lines
    if #code >= 2 then
        lines = {text:sub(1, col) .. code[1]}
        vim.list_extend(lines, vim.list_slice(code, 2, #code - 1))
        vim.list_extend(lines, {code[#code] .. text:sub(col + 1)})
        newline = line + #code - 1
        newcol = #code[#code]
    else
        lines = {text:sub(1, col) .. code[1] .. text:sub(col + 1)}
        newline = line
        newcol = col + #code[1]
    end
    vim.api.nvim_buf_set_lines(buf, line - 1, line, true, lines)
    if vim.api.nvim_get_current_buf() == buf then
        local nowcur = vim.api.nvim_win_get_cursor(0)
        if nowcur[1] == line and nowcur[2] == col then
            if notrigger then
                state.completion_notrigger = true
            end
            vim.api.nvim_win_set_cursor(0, {newline, newcol})
        end
    end
    return {newline, newcol}
end

function M.delete_at_cursor(nchars, cursor, buf, notrigger)
    if nchars == 0 then return cursor end
    local line, col = cursor[1], cursor[2]
    local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1]
    local newcol = col - nchars
    local newline = line
    local had = false
    local prevtext = text
    while newcol < 0 do
        local curlen = col
        if had then
            prevtext = vim.api.nvim_buf_get_lines(buf, newline - 1, newline, true)[1]
            curlen = #prevtext + 1
        end
        newcol = newcol + curlen
        if newcol < 0 then
            newline = newline - 1
            had = true
        end
    end
    text = prevtext:sub(1, newcol) .. text:sub(1 + col)
    if vim.api.nvim_get_current_buf() == buf then
        local nowcur = vim.api.nvim_win_get_cursor(0)
        if nowcur[1] == line and nowcur[2] == col then
            if notrigger then
                state.completion_notrigger = true
            end
            vim.api.nvim_win_set_cursor(0, {newline, newcol})
        end
    end
    vim.api.nvim_buf_set_lines(buf, newline - 1, line, true, {text})
    return {newline, newcol}
end

function M.append_to_end(code, buf)
    local line = vim.api.nvim_buf_line_count(buf)
    local lastline = vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1]
    code = vim.split(code, '\n', {plain = true})
    assert(#code > 0)
    code[1] = lastline .. code[1]
    vim.api.nvim_buf_set_lines(buf, line - 1, line, true, code)
    return {line, #code[#code]}
end

function M.suggestion_backward(suggestion, buf, step)
    local cursor = suggestion[3]
    local suggest = suggestion[2]
    local accepted = suggestion[4]
    if step > #accepted then
        step = #accepted
    end
    if step == 0 then return true end
    local delta = accepted:sub(-step)
    accepted = accepted:sub(1, -1 - step)
    suggest = delta .. suggest
    M.delete_at_cursor(step, cursor, buf, true)
    local curlist = suggestion[5]
    cursor = assert(curlist[#curlist + 1 - step])
    suggestion[5] = vim.list_slice(curlist, 1, #curlist - step)
    suggestion[2] = suggest
    suggestion[3] = cursor
    suggestion[4] = accepted
    local info = string.format(' %d/%d', #accepted, #suggest + #accepted)
    M.show_hint_at_cursor(suggest, cursor, buf, info)
    return false
end

function M.suggestion_advance(suggestion, buf, step)
    local cursor = suggestion[3]
    local line = cursor[1]
    local col = cursor[2]
    local suggest = suggestion[2]
    local accepted = suggestion[4]
    if step > #suggest then
        step = #suggest
    end
    if step == 0 then return true end
    local delta = suggest:sub(1, step)
    suggest = suggest:sub(1 + step)
    accepted = accepted .. delta
    local curlist = suggestion[5]
    for i = 1, #delta do
        curlist[#curlist + 1] = {line, col}
        if delta:byte(i) == 10 then
            line = line + 1
            col = 0
        else
            col = col + 1
        end
    end
    M.insert_at_cursor(delta, cursor, buf, true)
    cursor = {line, col}
    suggestion[2] = suggest
    suggestion[3] = cursor
    suggestion[4] = accepted
    suggestion[5] = curlist
    local info = string.format(' %d/%d', #accepted, #suggest + #accepted)
    M.show_hint_at_cursor(suggest, cursor, buf, info)
    return #suggest == 0
end

function M.find_boundary_word(s, rev)
    if rev then s = s:reverse() end
    return (s:find('%f[%W]') or #s + 1) - 1
end

function M.find_boundary_bigword(s, rev)
    if rev then s = s:reverse() end
    return (s:find('%f[%s]') or #s + 1) - 1
end

function M.find_boundary_line(s, rev)
    if rev then s = s:reverse() end
    return (s:find('\n', 2) or #s + 1) - 1
end

return M
