local M = {}

local Popup = require("nui.popup")
local Layout = require("nui.layout")
local state = require 'genius.state'
local opts = require 'genius.config'
local mark = require 'genius.mark'
local buffer = require 'genius.buffer'
local utf8 = require 'genius.utf8'
local bots = require 'genius.bots'
local chatml = require 'genius.chatml'

function M.get_options()
    return opts
end

function M.setup(options)
    for k, v in pairs(options) do
        if type(v) == 'table' then
            for kk, vv in pairs(v) do
                opts[k][kk] = vv
            end
        else
            opts[k] = v
        end
    end
end

function M.is_completion_enabled()
    return state.plugin_enabled
end

function M.toggle_completion()
    state.plugin_enabled = not state.plugin_enabled
    if state.plugin_enabled then
        vim.notify('Genius enabled', vim.log.levels.INFO, {title = 'Genius'})
    else
        for buf, suggestion in pairs(state.current_suggestion) do
            if suggestion[1] == 'WAITING' or suggestion[1] == 'REQUESTING' then
                suggestion[2]()
            end
            mark.dissmiss_hint_at_cursor(buf)
        end
        vim.notify('Genius disabled', vim.log.levels.INFO, {title = 'Genius'})
    end
end

function M.open_chat_window()
    local popup_one, popup_two = Popup({
        enter = true,
        border = "single",
    }), Popup({
        border = "double",
    })

    local layout = Layout(
        {
            position = "50%",
            size = {
                width = "80%",
                height = "80%",
            },
        },
        Layout.Box({
            Layout.Box(popup_two, { size = "70%" }),
            Layout.Box(popup_one, { size = "30%" }),
        }, { dir = "col" })
    )

    popup_one:map("n", "<Esc>", function()
        layout:unmount()
    end, {})

    local function cr()
        if popup_one.bufnr ~= vim.api.nvim_get_current_buf() then return end
        local linecount = vim.api.nvim_buf_line_count(0)
        local lines = vim.api.nvim_buf_get_lines(0, 0, linecount, true)
        assert(#lines > 0)
        vim.api.nvim_buf_set_lines(0, 0, linecount, true, {})
        if #lines == 1 and #lines[1] == 0 then
            layout:unmount()
            return
        end
        M.chat_completion(lines, popup_two.bufnr)
    end
    local function shift_cr()
        vim.api.nvim_feedkeys("\n", "n", false)
    end
    popup_one:map("i", "<CR>", cr, {})
    popup_one:map("n", "<CR>", cr, {})
    popup_one:map("i", "<S-CR>", shift_cr, {})
    popup_one:map("n", "<S-CR>", shift_cr, {})
    vim.bo[popup_one.bufnr].filetype = 'markdown'
    vim.bo[popup_two.bufnr].filetype = 'markdown'
    vim.api.nvim_buf_set_lines(popup_two.bufnr, 0, 1, true, {''})

    layout:mount()
end

local function format_time(time)
    if time > 5 then
        return string.format(" %.2fs", time)
    else
        return string.format(" %.0fms", time * 1000)
    end
end

function M.code_completion(delay)
    if delay and state.completion_notrigger then
        state.completion_notrigger = false
        return
    end

    local bufname = vim.api.nvim_buf_get_name(0)
    if not buffer.is_bufname_ok(bufname) then return end

    local curbuf = vim.api.nvim_get_current_buf()
    mark.dissmiss_hint_at_cursor(curbuf)

    local function begin_request()
        if not vim.api.nvim_buf_is_valid(curbuf) then return function () end end

        local cwd = vim.loop.cwd() .. '/'
        local prefix, suffix, cursor = buffer.fetch_code(cwd, opts)
        if prefix == nil then
            return function () end
        end
        prefix, suffix = utf8.trim_prefix_and_suffix(prefix, suffix, opts)

        local ridspace, ridnewline
        prefix, ridspace, ridnewline = utf8.count_space_nls(prefix, opts.rid_prefix_space, opts.rid_prefix_newline)

        local function on_complete(result, time)
            if not vim.api.nvim_buf_is_valid(curbuf) then return end
            result = utf8.rid_space_nls(result, ridspace, ridnewline)
            local sugguestion = state.current_suggestion[curbuf]
            if sugguestion ~= nil and sugguestion[1] == 'REQUESTING' then
                state.current_suggestion[curbuf] = {'FINISHED', result, cursor, '', {}}
                mark.show_hint_at_cursor(result, cursor, curbuf, format_time(time))
            end
        end
        local bot = bots.get_bot()
        local canceler = bot.on_complete(prefix, suffix, on_complete, opts, ridspace, ridnewline)
        -- if opts.api_type == 'openai' then
        --     -- canceler = request_chat({role = 'user', content = prompt}, -1, opts, opts.infill_options, on_complete, false)
        --     local prompt = opts.infill_marks.completion .. prefix
        --     utils.dump(prompt .. '<INSERT>' .. suffix)
        --     canceler = api.request_legacy_completion(prompt, suffix, -1, opts, opts.infill_options, on_complete, false, ridspace, ridnewline)
        -- else
        --     local prompt = template.apply_infill_template(prefix, suffix, opts)
        --     utils.dump(prompt)
        --     canceler = api.request_completion(prompt, -1, opts, opts.infill_options, on_complete, false, ridspace, ridnewline)
        -- end
        state.current_suggestion[curbuf] = {'REQUESTING', canceler}
        return canceler
    end

    if not delay then
        local suggestion = state.current_suggestion[curbuf]
        if suggestion ~= nil then
            if suggestion[1] == 'WAITING' then
                suggestion[2]()
            end
            if suggestion[1] == 'REQUESTING' then
                return
            end
        end
        return begin_request()

    else
        local suggestion = state.current_suggestion[curbuf]
        if suggestion ~= nil then
            if suggestion[1] == 'WAITING' or suggestion[1] == 'REQUESTING' then
                suggestion[2]()
            end
        end

        if opts.complete_only_on_eol then
            local cursor = vim.api.nvim_win_get_cursor(0)
            local maxcol = #vim.api.nvim_buf_get_lines(0, cursor[1] - 1, cursor[1], true)[1]
            if cursor[2] ~= maxcol then
                return function () end
            end
        end

        if opts.completion_delay_ms == -1 then
            state.current_suggestion[curbuf] = {'WAITING', function () end}
            return
        end

        local canceler
        if opts.completion_delay_ms == 0 then
            canceler = begin_request()
            state.current_suggestion[curbuf] = {'WAITING', canceler}
        else
            local timer = vim.loop.new_timer()
            local req_canceler = nil
            canceler = function ()
                if req_canceler then
                    return req_canceler()
                end
                timer:stop()
                if not timer:is_closing() then
                    timer:close()
                end
            end
            state.current_suggestion[curbuf] = {'WAITING', canceler}
            timer:start(opts.completion_delay_ms, 0, vim.schedule_wrap(function ()
                timer:stop()
                if not timer:is_closing() then
                    timer:close()
                end
                req_canceler = begin_request()
            end))
        end
        return canceler
    end
end

function M.chat_completion(lines, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if lines then
        assert(type(lines) == 'table' and #lines > 0)
        local linecount = vim.api.nvim_buf_line_count(bufnr)
        lines = vim.list_extend({opts.chat_sep_user}, lines)
        lines = vim.list_extend(lines, {opts.chat_sep_assistant, ''})
        vim.api.nvim_buf_set_lines(bufnr, linecount, linecount, true, lines)
    end

    local function on_stream(res, time, stop)
        _ = stop
        local cursor = mark.append_to_end(res, bufnr)
        mark.show_hint_at_cursor("", cursor, bufnr, format_time(time))
    end

    local text = buffer.get_buffer_text(bufnr)
    local messages = chatml.parse_chat_template(text, opts)
    local bot = bots.get_bot()
    return bot.on_chat(messages, on_stream, opts)
    -- if opts.api_type == 'openai' then
    --     return api.request_chat(messages, -1, opts, opts.chat_options, on_stream, opts.chat_stream)
    -- else
    --     text = template.apply_chat_template(text, opts)
    --     return api.request_completion(text, -1, opts, opts.chat_options, on_stream, opts.chat_stream, 1, 0)
    -- end
end

function M.completion_dismiss(step)
    local buf = vim.api.nvim_get_current_buf()
    local suggestion = state.current_suggestion[buf]
    if suggestion ~= nil then
        if suggestion[1] == 'WAITING' or suggestion[1] == 'REQUESTING' then
            suggestion[2]()
        elseif suggestion[1] == 'FINISHED' then
            local die
            if step == 'char' then
                die = mark.suggestion_backward(suggestion, buf, 1)
            elseif step == 'word' then
                die = mark.suggestion_backward(suggestion, buf, mark.find_boundary_word(suggestion[4], true))
            elseif step == 'bigword' then
                die = mark.suggestion_backward(suggestion, buf, mark.find_boundary_bigword(suggestion[4], true))
            elseif step == 'line' then
                die = mark.suggestion_backward(suggestion, buf, mark.find_boundary_line(suggestion[4], true))
            else
                assert(step == 'all')
                die = true
            end
            if die then
                state.current_suggestion[buf] = nil
                mark.dissmiss_hint_at_cursor(buf)
            end
        end
    end
end

function M.completion_accept(step)
    local buf = vim.api.nvim_get_current_buf()
    local suggestion = state.current_suggestion[buf]
    if suggestion ~= nil and suggestion[1] == 'FINISHED' then
        local die
        if step == 'char' then
            die = mark.suggestion_advance(suggestion, buf, 1)
        elseif step == 'word' then
            die = mark.suggestion_advance(suggestion, buf, mark.find_boundary_word(suggestion[2]))
        elseif step == 'bigword' then
            die = mark.suggestion_advance(suggestion, buf, mark.find_boundary_bigword(suggestion[2]))
        elseif step == 'line' then
            die = mark.suggestion_advance(suggestion, buf, mark.find_boundary_line(suggestion[2]))
        else
            assert(step == 'all')
            mark.insert_at_cursor(suggestion[2], suggestion[3], buf)
            state.current_suggestion[buf] = nil
            mark.dissmiss_hint_at_cursor(buf)
            die = false
        end
        return die
    end
end

function M.completion_visible()
    local buf = vim.api.nvim_get_current_buf()
    local suggestion = state.current_suggestion[buf]
    return suggestion ~= nil and suggestion[1] == 'FINISHED'
end

return M
