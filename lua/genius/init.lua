local M = {}

local curl = require 'plenary.curl'
local Popup = require("nui.popup")
local Layout = require("nui.layout")

local default_opts = {
    api_type = 'openai',
    config_openai = {
        api_key = os.getenv("OPENAI_API_KEY"),
        base_url = "https://api.openai.com",
        chat_marks = {
            inst_prefix_bos = "### User:\n",
            inst_prefix_eos = "\n### User:\n",
            inst_suffix = "\n### Assistant:\n",
            input_price = 0.0005,
            output_price = 0.0015,
        },
        chat_options = {
            max_tokens = 512,
            model = "gpt-3.5-turbo",
            temperature = 0.8,
        },
        infill_marks = {
            completion = "",
            cwd_eos = "\n",
            cwd_files = "### List of current directory:\n",
            file_content = "\n",
            file_eos = "\n",
            file_name = "### File: ",
            begin_above_mark = "\n### Based on the existing files listed above, do code completion for the following file:\n",
            insertion = { "", "<INSERT_HERE>", "" },
            input_price = 0.0015,
            output_price = 0.0020,
        },
        infill_options = {
            max_tokens = 100,
            model = "gpt-3.5-turbo-instruct",
            temperature = 0.8,
        },
    },
    config_deepseek = {
        base_url = "http://127.0.0.1:8080",
        chat_marks = {
            inst_prefix_bos = "Expert Q&A\nQuestion: ",
            inst_prefix_eos = "<|EOT|>\nQuestion: ",
            inst_suffix = "\nAnswer:",
        },
        chat_options = {
            n_predict = -1,
            stop = { "\nQuestion:" },
            temperature = 0.8,
        },
        escape_list = { { "<｜([%l▁]+)｜>", "<|%1|>" }, { "<|(%u+)|>", "<｜%1｜>" } },
        infill_marks = {
            completion = "",
            cwd_eos = "<|EOT|>",
            cwd_files = "### List of current directory:\n",
            file_content = "\n",
            file_eos = "<|EOT|>",
            file_name = "### File: ",
            begin_above_mark = "",
            insertion = { "<｜fim▁begin｜>", "<｜fim▁hole｜>", "<｜fim▁end｜>" },
        },
        infill_options = {
            n_predict = 100,
            temperature = 0.8,
        },
    },
    config_mistral = {
        base_url = "http://127.0.0.1:8080",
        chat_marks = {
            inst_prefix_bos = "<s>[INST] ",
            inst_prefix_eos = "</s>[INST] ",
            inst_suffix = " [/INST]",
        },
        chat_options = {
            n_predict = -1,
            temperature = 0.8,
        },
        escape_list = { { "</?[su]n?k?>", string.upper }, { "<0x[0-9A-F][0-9A-F]>", string.upper } },
        infill_marks = {
            completion = "Do code completion based on the following code. No repeat. Indentation must be correct. Be short and relevant.\n\n",
            cwd_eos = "</s>",
            cwd_files = "### List of current directory:\n",
            file_content = "\n",
            file_eos = "</s>",
            file_name = "### File: ",
            begin_above_mark = "",
        },
        infill_options = {
            n_predict = 100,
            stop = { "### File:" },
            temperature = 0.8,
        },
    },
    completion_buffers = 1,
    single_buffer_has_mark = false,
    buffers_sort_mru = true,
    exceeded_buffer_has_mark = true,
    completion_delay_ms = 2000,
    complete_only_on_eol = false,
    trimming_window = 7200,
    trimming_suffix_portion = 0.28,
    buffers_in_cwd_only = true,
    list_cwd_files = false,
    escape_special_tokens = true,
    rid_prefix_space = true,
    rid_prefix_newline = true,
    keymaps = {
        tab = true,
        delete = true,
        leftright = true,
        homeend = true,
        freeend = true,
    },
    filetype_hints = {
        gitcommit = 'Please write a unique and memorizable commit message based on files changed, no comments or quotes:\n\n\n',
    },
    chat_stream = true,
    chat_sep_assistant = '🤖',
    chat_sep_user = '😊',
    report_error = true,
}

setmetatable(default_opts, {
    __index = function (t, k)
        local v = rawget(t, k)
        if v ~= nil then return v end
        local a = rawget(t, 'api_type')
        if type(a) ~= 'string' then return nil end
        local cfg = rawget(t, 'config_' .. a)
        if cfg == nil then return nil end
        return cfg[k]
    end,
})

local function report(msg)
    if default_opts.report_error then
        vim.notify(msg, vim.log.levels.ERROR, {title = 'Genius'})
    end
end

local function dump(x)
    if type(x) ~= 'string' then
        x = vim.inspect(x)
    end
    local file = io.open("/tmp/neovim.log", "a")
    if file then
        file:write('\n=======\n')
        file:write(x)
        file:close()
    end
end

function M.get_options()
    return default_opts
end

function M.setup(opts)
    for k, v in pairs(opts) do
        if type(v) == 'table' then
            for kk, vv in pairs(v) do
                default_opts[k][kk] = vv
            end
        else
            default_opts[k] = v
        end
    end
end

local plugin_ready = nil
local completion_notrigger = false
local plugin_enabled = true

local function request_http(base_url, uri, data, callback, stream, authorization)
    if not plugin_enabled then
        return function () end
    end
    local headers = {
        ['Content-type'] = 'application/json',
    }
    if authorization then
        headers['Authorization'] = authorization
    end
    local function begin_request()
        local canceled = false
        local t0 = vim.fn.reltime()
        local opts = {
            body = vim.fn.json_encode(data),
            headers = headers,
            on_error = vim.schedule_wrap(function (res)
                if canceled then return end
                local msg = string.format("--- CURL ERROR %d ---\n%s", res.exit, res.message)
                return report(msg)
            end),
        }
        if stream then
                -- vim.notify(opts.body)
            opts.stream = vim.schedule_wrap(function (err, res)
                if canceled then return end
                if err then
                    local msg = string.format("--- CURL STREAM ERROR ---\n%s", err)
                    return report(msg)
                end
                if vim.startswith(res, 'data: ') then
                    local body = res:sub(7)
                    if body == "[DONE]" then return end
                    local success, result = pcall(vim.fn.json_decode, body)
                    if not success then
                        local msg = string.format("--- JSON LINE DECODE FAILURE ---\n%s", body)
                        return report(msg)
                    end
                    local dt = vim.fn.reltimefloat(vim.fn.reltime(t0))
                    return callback(result, dt)
                end
            end)
        else
                -- vim.notify(opts.body)
            opts.callback = vim.schedule_wrap(function (res)
                -- vim.notify(vim.inspect(res))
                if canceled then return end
                if res.status ~= 200 then
                    local msg = string.format("--- HTTP ERROR %d ---\n%s", res.status, res.body)
                    return report(msg)
                end
                local success, result = pcall(vim.fn.json_decode, res.body)
                if not success then
                    local msg = string.format("--- JSON DECODE FAILURE ---\n%s", res.body)
                    return report(msg)
                end
                local dt = vim.fn.reltimefloat(vim.fn.reltime(t0))
                return callback(result, dt)
            end)
        end
        local success, job = pcall(curl.post, base_url .. uri, opts)
        -- vim.notify(vim.inspect(job))
        if not success then
            report('curl.post invocation failed')
            return function () end
        end
        return function ()
            if not canceled then
                pcall(function ()
                    job:shutdown(0, 2)
                end)
                canceled = true
            end
        end
    end
    if plugin_ready == true then
        return begin_request()
    elseif plugin_ready == nil then
        local canceler = nil
        local canceled = false
        if string.match(uri, '^/v1/') then
            curl.get(base_url .. '/v1/models', {
                on_error = vim.schedule_wrap(function ()
                    plugin_ready = false
                    report('completion server not ready (failed to connect)')
                end),
                callback = vim.schedule_wrap(function (res)
                    if res.status ~= 200 then
                        plugin_ready = false
                        if res.status == 401 then
                            report('completion server not ready (status 401, invalid API key)')
                        else
                            report('completion server not ready (status ' .. res.status .. ')')
                        end
                    else
                        plugin_ready = true
                        if canceled then return end
                        canceler = begin_request()
                    end
                end),
            })
        else
            curl.get(base_url .. '/', {
                on_error = vim.schedule_wrap(function ()
                    plugin_ready = false
                    report('completion server not ready (failed to connect)')
                end),
                callback = vim.schedule_wrap(function (res)
                    plugin_ready = true
                    if canceled then return end
                    canceler = begin_request()
                    -- end
                end),
            })
        end
        return function ()
            canceled = true
            if canceler then
                canceler()
            end
        end
    else
        return function () end
    end
end

local function request_embedding(content, callback, opts)
    return request_http(opts.base_url, '/embedding', {
        content = content,
    }, function (res, time)
        assert(res.embedding ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.embedding) == 'table')
        return callback(res.embedding, time)
    end)
end

local function request_tokenize(content, callback, opts)
    return request_http(opts.base_url, '/tokenize', {
        content = content,
    }, function (res, time)
        assert(res.tokens ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.tokens) == 'table')
        return callback(res.tokens, time)
    end)
end

local function request_detokenize(tokens, callback, opts)
    return request_http(opts.base_url, '/detokenize', {
        tokens = tokens,
    }, function (res, time)
        assert(res.content ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.content) == 'table')
        return callback(res.content, time)
    end)
end

local function request_completion(prompt, seed, opts, options, callback, stream, ridspace, ridnewline)
    ridnewline = ridnewline or 0
    ridspace = ridspace or 0
    return request_http(opts.base_url, '/completion', vim.tbl_extend('force', {
        prompt = prompt,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, options), function (res, time)
        local content = res.content
        assert(content ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(content) == 'string')
        while ridnewline > 0 and #content ~= 0 do
            if content:byte() == 10 then
                content = content:sub(2)
                ridnewline = ridnewline - 1
            else
                ridnewline = 0
            end
        end
        while ridspace > 0 and #content ~= 0 do
            if content:byte() == 32 then
                content = content:sub(2)
                ridspace = ridspace - 1
            else
                ridspace = 0
            end
        end
        return callback(content, time, res.stop)
    end, stream)
end

local function request_legacy_completion(prompt, suffix, seed, opts, options, callback, stream, ridspace, ridnewline)
    local api_key = opts.api_key
    -- vim.notify(vim.inspect(api_key))
    -- vim.notify(vim.inspect(messages))
    return request_http(opts.base_url, '/v1/completions', vim.tbl_extend('force', {
        prompt = prompt,
        suffix = suffix,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, options), function (res, time)
        -- vim.notify(vim.inspect(res))
        assert(res ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res) == 'table')
        if res.error ~= nil and res.error.message ~= nil then
            report('server error: ' .. res.error.message)
            return
        end
        assert(type(res.choices) == 'table', 'invalid server response: ' .. vim.inspect(res))
        local content = res.choices[1].text or ''
        -- if not stream and res.usage then
        --     local price = (res.usage.prompt_tokens * opts.infill_marks.input_price + res.usage.completion_tokens * opts.infill_marks.output_price) * 0.001
        -- end
        assert(type(content) == 'string')
        while ridnewline > 0 and #content ~= 0 do
            if content:byte() == 10 then
                content = content:sub(2)
                ridnewline = ridnewline - 1
            else
                ridnewline = 0
            end
        end
        while ridspace > 0 and #content ~= 0 do
            if content:byte() == 32 then
                content = content:sub(2)
                ridspace = ridspace - 1
            else
                ridspace = 0
            end
        end
        return callback(content, time)
    end, stream, api_key and 'Bearer ' .. api_key)
end

local function request_chat(messages, seed, opts, options, callback, stream)
    local api_key = opts.api_key
    -- vim.notify(vim.inspect(api_key))
    -- vim.notify(vim.inspect(messages))
    return request_http(opts.base_url, '/v1/chat/completions', vim.tbl_extend('force', {
        messages = messages,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, options), function (res, time)
        -- vim.notify(vim.inspect(res))
        assert(res ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res) == 'table')
        local content
        if stream then
            content = res.choices[1].delta.content or ''
        else
            content = res.choices[1].content or ''
        end
        -- if not stream and res.usage then
        --     local price = (res.usage.prompt_tokens * opts.chat_marks.input_price + res.usage.completion_tokens * opts.chat_marks.output_price) * 0.001
        -- end
        assert(type(content) == 'string')
        return callback(content, time)
    end, stream, api_key and 'Bearer ' .. api_key)
end

local function apply_infill_template(prefix, suffix, opts)
    if #suffix ~= 0 and opts.infill_marks.insertion then
        return opts.infill_marks.insertion[1] .. prefix .. opts.infill_marks.insertion[2] .. suffix .. opts.infill_marks.insertion[3]
    else
        return opts.infill_marks.completion .. prefix
    end
end

local function escape_content(text, opts)
    if opts.escape_special_tokens then
        local escape_list = opts.escape_list
        if escape_list then
            for _, pair in ipairs(escape_list) do
                text = text:gsub(pair[1], pair[2])
            end
        end
    end
    return text
end

local function apply_chat_template(text, opts)
    local prompt = ''
    local system = true
    local user = true
    local eos = false
    for _, line in ipairs(vim.split(text:gsub('\n' .. opts.chat_sep_assistant .. '\n',
        '\n' .. opts.chat_sep_user .. '\n'), '\n' .. opts.chat_sep_user .. '\n', {plain = true})) do
        line = escape_content(line, opts)
        if system then
            system = false
        else
            if user then
                local inst_prefix = opts.chat_marks.inst_prefix_bos
                if eos then
                    inst_prefix = opts.chat_marks.inst_prefix_eos
                end
                eos = true
                line = inst_prefix .. line .. opts.chat_marks.inst_suffix
            end
            prompt = prompt .. line
            user = not user
        end
    end
    return prompt
end

local function parse_chat_template(text, opts)
    local messages = {}
    local system = true
    local user = true
    for _, line in ipairs(vim.split(text:gsub('\n' .. opts.chat_sep_assistant .. '\n',
        '\n' .. opts.chat_sep_user .. '\n'), '\n' .. opts.chat_sep_user .. '\n', {plain = true})) do
        if system then
            system = false
        else
            local role
            if user then
                role = 'user'
            else
                role = 'assistant'
            end
            if line ~= '' then
                messages[#messages + 1] = {role = role, content = line}
            end
            user = not user
        end
    end
    return messages
end

local function get_buffer_text(bufnr)
    local linecount = vim.api.nvim_buf_line_count(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, linecount, true)
    local text = ''
    for _, line in ipairs(lines) do
        text = text .. line .. '\n'
    end
    return text:sub(1, -2)
end

local namespace = vim.api.nvim_create_namespace('Genius')

local function is_bufname_ok(bufname)
    return bufname ~= '' -- and vim.fn.filereadable(bufname) == 1
end

local function utf8_cut_fix(text)
    while #text > 0 and (text:byte() >= 128 and text:byte() <= 191) do
        text = text:sub(2)
    end
    local i, n = #text, 0
    while i > 0 and n <= 4 and (text:byte(i) >= 128 and text:byte(i) <= 191) do
        n = n + 1
        i = i - 1
    end
    local corrupt = 0
    if n == 1 then
        if i == 0 or not (text:byte(i) >= 192 and text:byte(i) <= 223) then
            corrupt = 2
        end
    elseif n == 2 then
        if i == 0 or not (text:byte(i) >= 224 and text:byte(i) <= 239) then
            corrupt = 3
        end
    elseif n == 3 then
        if i == 0 or not (text:byte(i) >= 240 and text:byte(i) <= 247) then
            corrupt = 4
        end
    end
    if corrupt ~= 0 then
        text = text:sub(1, -1 - corrupt)
    end
    return text
end

local function utf8_count_nth(text, n)
    local count = 0
    for i = 1, #text do
        if not (text:byte() >= 128 and text:byte() <= 191) then
            count = count + 1
        end
        if count == n then
            return i
        end
    end
    return #text
end

local function utf8_text_width(text) -- U+2e80~U+ff60 and U+20000~U+2fa1f have display width 2
    local width = 0
    for i = 1, #text do
        local c = text:byte(i)
        if c == 9 then
            width = width + vim.bo.tabstop - (width % vim.bo.tabstop)
        elseif c >= 0 and c <= 127 then
            width = width + 1
        elseif c >= 192 and c <= 223 then
            width = width + 1
        elseif c >= 224 and c <= 225 then
            width = width + 1
        elseif c >= 226 and c <= 239 then
            width = width + 2
        elseif c >= 240 and c <= 247 then
            width = width + 1
        end
    end
    return width
end

local function fetch_current_buffer(cwd, opts, cursor)
    local curname = vim.api.nvim_buf_get_name(0)
    if not is_bufname_ok(curname) then return nil, nil, nil, nil end

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

local function fetch_code(cwd, opts)
    local curbuf = vim.api.nvim_get_current_buf()
    local curprefix, cursuffix, cursor, curname = fetch_current_buffer(cwd, opts)
    if curprefix == nil then
        return nil, nil, nil
    end
    curprefix = escape_content(curprefix, opts)
    cursuffix = escape_content(cursuffix, opts)

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
                if is_bufname_ok(bufname) then
                    bufname = escape_content(bufname, opts)
                    if exceeded then
                        local code = opts.infill_marks.file_name .. bufname .. opts.infill_marks.file_content .. opts.infill_marks.file_eos
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
                            code = escape_content(code, opts)
                            code = opts.infill_marks.file_name .. bufname .. opts.infill_marks.file_content .. code .. opts.infill_marks.file_eos
                            fullprefix = fullprefix .. code
                        end
                    end
                end
            end
        end
        if nbufs > 1 or opts.single_buffer_has_mark then
            curname = escape_content(curname, opts)
            curprefix = opts.infill_marks.file_name .. curname .. opts.infill_marks.file_content .. curprefix
        end
        if #fullprefix ~= 0 then
            curprefix = fullprefix .. opts.infill_marks.begin_above_mark .. curprefix
        end

    elseif opts.single_buffer_has_mark then
        curname = escape_content(curname, opts)
        curprefix = opts.infill_marks.file_name .. curname .. opts.infill_marks.file_content .. curprefix
    end

    if opts.list_cwd_files then
        local scanner = vim.loop.fs_scandir(cwd)
        if scanner then
            local fileinfo = opts.infill_marks.cwd_files
            local had = false
            while true do
                local file = vim.loop.fs_scandir_next(scanner)
                if not file then break end
                if vim.fn.isdirectory(file) == 1 then
                    file = file .. '/'
                end
                file = escape_content(file, opts)
                fileinfo = fileinfo .. file .. '\n'
                had = true
            end
            fileinfo = fileinfo .. opts.infill_marks.cwd_eos
            if had then
                curprefix = fileinfo .. curprefix
            end
        end
    end

    return curprefix, cursuffix, cursor
end

local function trim_prefix_and_suffix(prefix, suffix, opts)
    if opts.trimming_window ~= 0 then
        local nsuffix = opts.infill_marks.insertion and math.max(1, math.floor(opts.trimming_window * opts.trimming_suffix_portion)) or 0
        local nprefix = math.max(1, opts.trimming_window - nsuffix)
        if #prefix < nprefix then
            nsuffix = nsuffix + (nprefix - #prefix)
            nprefix = #prefix
        end
        if #suffix < nsuffix then
            nsuffix = #suffix
        end
        if nprefix < #prefix then prefix = utf8_cut_fix(prefix:sub(#prefix - nprefix)) end
        if nsuffix < #suffix then suffix = utf8_cut_fix(suffix:sub(1, nsuffix)) end
    end
    return prefix, suffix
end

local function dissmiss_hint_at_cursor(buf)
    vim.api.nvim_buf_del_extmark(buf, namespace, 1)
end

local function show_hint_at_cursor(code, cursor, buf, info)
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
        virt_text_win_col = utf8_text_width(text:sub(1, col)),
        virt_lines = virt_lines,
        virt_text = {{firstline, 'GeniusSuggestion'}, {info, 'GeniusInformation'}},
    }
    vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, col, data)
end

local function insert_at_cursor(code, cursor, buf, notrigger)
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
                completion_notrigger = true
            end
            vim.api.nvim_win_set_cursor(0, {newline, newcol})
        end
    end
    return {newline, newcol}
end

local function delete_at_cursor(nchars, cursor, buf, notrigger)
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
                completion_notrigger = true
            end
            vim.api.nvim_win_set_cursor(0, {newline, newcol})
        end
    end
    vim.api.nvim_buf_set_lines(buf, newline - 1, line, true, {text})
    return {newline, newcol}
end

local function append_to_end(code, buf)
    local line = vim.api.nvim_buf_line_count(buf)
    local lastline = vim.api.nvim_buf_get_lines(buf, line - 1, line, true)[1]
    code = vim.split(code, '\n', {plain = true})
    assert(#code > 0)
    code[1] = lastline .. code[1]
    vim.api.nvim_buf_set_lines(buf, line - 1, line, true, code)
    return {line, #code[#code]}
end

local current_suggestion = {}

function M.is_completion_enabled()
    return plugin_enabled
end

function M.toggle_completion()
    plugin_enabled = not plugin_enabled
    if plugin_enabled then
        vim.notify('Genius enabled', vim.log.levels.INFO, {title = 'Genius'})
    else
        for buf, suggestion in pairs(current_suggestion) do
            if suggestion[1] == 'WAITING' or suggestion[1] == 'REQUESTING' then
                suggestion[2]()
            end
            dissmiss_hint_at_cursor(buf)
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
    local opts = default_opts
    if delay and completion_notrigger then
        completion_notrigger = false
        return
    end
    if delay and opts.completion_delay_ms == -1 then
        return function () end
    end

    local bufname = vim.api.nvim_buf_get_name(0)
    if not is_bufname_ok(bufname) then return end

    local curbuf = vim.api.nvim_get_current_buf()
    dissmiss_hint_at_cursor(curbuf)

    local function begin_request()
        if not vim.api.nvim_buf_is_valid(curbuf) then return function () end end

        local cwd = vim.loop.cwd() .. '/'
        local prefix, suffix, cursor = fetch_code(cwd, opts)
        if prefix == nil then
            return function () end
        end
        prefix, suffix = trim_prefix_and_suffix(prefix, suffix, opts)

        local ridspace = 0
        local ridnewline = 0
        -- if opts.api_type ~= 'openai' then
            if opts.rid_prefix_space then
                while #prefix > 0 and prefix:byte(-1) == 32 do
                    prefix = prefix:sub(1, -2)
                    ridspace = ridspace + 1
                end
            end
            if opts.rid_prefix_newline then
                while #prefix > 0 and prefix:byte(-1) == 10 do
                    prefix = prefix:sub(1, -2)
                    ridnewline = ridnewline + 1
                end
            end
        -- end

        local function on_complete(result, time)
            if not vim.api.nvim_buf_is_valid(curbuf) then return end
            local sugguestion = current_suggestion[curbuf]
            if sugguestion ~= nil and sugguestion[1] == 'REQUESTING' then
                current_suggestion[curbuf] = {'FINISHED', result, cursor, '', {}}
                show_hint_at_cursor(result, cursor, curbuf, format_time(time))
            end
        end
        local canceler
        if opts.api_type == 'openai' then
            -- canceler = request_chat({role = 'user', content = prompt}, -1, opts, opts.infill_options, on_complete, false)
            local prompt = opts.infill_marks.completion .. prefix
            dump(prompt .. '<INSERT>' .. suffix)
            canceler = request_legacy_completion(prompt, suffix, -1, opts, opts.infill_options, on_complete, false, ridspace, ridnewline)
        else
            local prompt = apply_infill_template(prefix, suffix, opts)
            dump(prompt)
            canceler = request_completion(prompt, -1, opts, opts.infill_options, on_complete, false, ridspace, ridnewline)
        end
        current_suggestion[curbuf] = {'REQUESTING', canceler}
        return canceler
    end

    if not delay then
        local suggestion = current_suggestion[curbuf]
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
        local suggestion = current_suggestion[curbuf]
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

        local timer = vim.loop.new_timer()
        local canceler = function ()
            timer:stop()
            if not timer:is_closing() then
                timer:close()
            end
        end
        current_suggestion[curbuf] = {'WAITING', canceler}

        if opts.completion_delay_ms == 0 then
            canceler = begin_request()
        else
            timer:start(opts.completion_delay_ms, 0, vim.schedule_wrap(function ()
                timer:stop()
                if not timer:is_closing() then
                    timer:close()
                end
                canceler = begin_request()
            end))
        end
        return canceler
    end
end

function M.chat_completion(lines, bufnr)
    local opts = default_opts
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if lines then
        assert(type(lines) == 'table' and #lines > 0)
        local linecount = vim.api.nvim_buf_line_count(bufnr)
        lines = vim.list_extend({opts.chat_sep_user}, lines)
        lines = vim.list_extend(lines, {opts.chat_sep_assistant, ''})
        vim.api.nvim_buf_set_lines(bufnr, linecount, linecount, true, lines)
    end

    local function on_stream(res, time, stop)
        local cursor = append_to_end(res, bufnr)
        show_hint_at_cursor("", cursor, bufnr, format_time(time))
    end

    local text = get_buffer_text(bufnr)
    if opts.api_type == 'openai' then
        local messages = parse_chat_template(text, opts)
        return request_chat(messages, -1, opts, opts.chat_options, on_stream, opts.chat_stream)
    else
        text = apply_chat_template(text, opts)
        return request_completion(text, -1, opts, opts.chat_options, on_stream, opts.chat_stream, 1, 0)
    end
end

local function suggestion_backward(suggestion, buf, step)
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
    delete_at_cursor(step, cursor, buf, true)
    local curlist = suggestion[5]
    cursor = assert(curlist[#curlist + 1 - step])
    suggestion[5] = vim.list_slice(curlist, 1, #curlist - step)
    suggestion[2] = suggest
    suggestion[3] = cursor
    suggestion[4] = accepted
    local info = string.format(' %d/%d', #accepted, #suggest + #accepted)
    show_hint_at_cursor(suggest, cursor, buf, info)
    return false
end

local function suggestion_advance(suggestion, buf, step)
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
    insert_at_cursor(delta, cursor, buf, true)
    cursor = {line, col}
    suggestion[2] = suggest
    suggestion[3] = cursor
    suggestion[4] = accepted
    suggestion[5] = curlist
    local info = string.format(' %d/%d', #accepted, #suggest + #accepted)
    show_hint_at_cursor(suggest, cursor, buf, info)
    return #suggest == 0
end

local function find_boundary_word(s, rev)
    if rev then s = s:reverse() end
    return (s:find('%f[%W]') or #s + 1) - 1
end

local function find_boundary_bigword(s, rev)
    if rev then s = s:reverse() end
    return (s:find('%f[%s]') or #s + 1) - 1
end

local function find_boundary_line(s, rev)
    if rev then s = s:reverse() end
    return (s:find('\n', 2) or #s + 1) - 1
end

function M.completion_dismiss(step)
    local buf = vim.api.nvim_get_current_buf()
    local suggestion = current_suggestion[buf]
    if suggestion ~= nil then
        if suggestion[1] == 'WAITING' or suggestion[1] == 'REQUESTING' then
            suggestion[2]()
        elseif suggestion[1] == 'FINISHED' then
            local die
            if step == 'char' then
                die = suggestion_backward(suggestion, buf, 1)
            elseif step == 'word' then
                die = suggestion_backward(suggestion, buf, find_boundary_word(suggestion[4], true))
            elseif step == 'line' then
                die = suggestion_backward(suggestion, buf, find_boundary_line(suggestion[4], true))
            else
                assert(step == 'all', 'invalid step specified: ' .. vim.inspect(step))
                die = true
            end
            if die then
                current_suggestion[buf] = nil
                dissmiss_hint_at_cursor(buf)
            end
        end
    end
end

function M.completion_accept(step)
    local buf = vim.api.nvim_get_current_buf()
    local suggestion = current_suggestion[buf]
    if suggestion ~= nil and suggestion[1] == 'FINISHED' then
        local die
        if step == 'char' then
            die = suggestion_advance(suggestion, buf, 1)
        elseif step == 'word' then
            die = suggestion_advance(suggestion, buf, find_boundary_word(suggestion[2]))
        elseif step == 'line' then
            die = suggestion_advance(suggestion, buf, find_boundary_line(suggestion[2]))
        else
            assert(step == 'all', 'invalid step specified: ' .. vim.inspect(step))
            insert_at_cursor(suggestion[2], suggestion[3], buf)
            current_suggestion[buf] = nil
            dissmiss_hint_at_cursor(buf)
            die = false
        end
        return die
    end
end

function M.completion_visible()
    local buf = vim.api.nvim_get_current_buf()
    local suggestion = current_suggestion[buf]
    return suggestion ~= nil and suggestion[1] == 'FINISHED'
end

return M
