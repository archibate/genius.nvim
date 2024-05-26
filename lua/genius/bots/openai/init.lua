local M = {}

local request_http = require 'genius.http'
local utils = require 'genius.utils'
local opts = require 'genius.config'

function M.request_legacy_completion(prompt, suffix, seed, options, callback, stream)
    local api_key = options.api_key
    -- vim.notify(api_key)
    -- vim.notify(vim.inspect(api_key))
    -- vim.notify(vim.inspect(messages))
    return request_http(options.base_url, '/v1/completions', vim.tbl_extend('force', {
        prompt = prompt,
        suffix = suffix,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, options.infill_options), function (res, time)
        -- vim.notify(vim.inspect(res))
        assert(res ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res) == 'table')
        if res.error ~= nil and res.error.message ~= nil then
            utils.report('server error: ' .. res.error.message)
            return
        end
        assert(type(res.choices) == 'table', 'invalid server response: ' .. vim.inspect(res))
        local content = res.choices[1].text or ''
        -- if not stream and res.usage then
        --     local price = (res.usage.prompt_tokens * opts.infill_marks.input_price + res.usage.completion_tokens * opts.infill_marks.output_price) * 0.001
        -- end
        assert(type(content) == 'string')
        return callback(content, time)
    end, stream, api_key and 'Bearer ' .. api_key)
end

function M.request_chat(messages, seed, options, chat_options, callback, stream)
    local api_key = options.api_key
    -- vim.notify(vim.inspect(api_key))
    -- vim.notify(vim.inspect(messages))
    return request_http(options.base_url, '/v1/chat/completions', vim.tbl_extend('force', {
        messages = messages,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, chat_options), function (res, time)
        -- vim.notify(vim.inspect(res))
        assert(res ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res) == 'table')
        if type(res.choices) ~= 'table' then
            utils.report('bad server response: ' .. vim.inspect(res))
            return
        end
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

function M.on_complete(prefix, suffix, on_complete, options)
    if options.infill_marks.completion then
        prefix = options.infill_marks.completion .. prefix
    end
    utils.dump(prefix .. '<INSERT>' .. suffix)
    return M.request_legacy_completion(prefix, suffix, -1, options, on_complete, false)
end

-- function M.on_edit(code, on_edit, prompt, options)
--     if not prompt then
--         if options.edit_marks.edition then
--             code = options.edit_marks.edition .. code
--         end
--         if options.edit_marks.edition_end then
--             code = code .. options.edit_marks.edition_end
--         end
--     else
--         if options.edit_marks.edition_prompt then
--             code = options.edit_marks.edition_prompt .. code
--         end
--         if options.edit_marks.edition_prompt_end then
--             code = options.edit_marks.edition_prompt_end .. code
--         end
--     end
--     utils.dump(code)
--     local messages = {
--         {
--             role = 'user',
--             text = code,
--         },
--     }
--     return M.request_chat(messages, -1, options, options.edit_options, on_edit, false)
-- end

function M.on_chat(messages, on_stream, options)
    utils.dump(messages)
    return M.request_chat(messages, -1, options, options.chat_options, on_stream, opts.chat_stream)
end

return M
