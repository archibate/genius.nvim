local M = {}

local request_http = require 'genius.http'
local utils = require 'genius.utils'

function M.request_legacy_completion(prompt, suffix, seed, opts, options, callback, stream, ridspace, ridnewline)
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
            utils.report('server error: ' .. res.error.message)
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

function M.request_chat(messages, seed, opts, options, callback, stream)
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

return M
