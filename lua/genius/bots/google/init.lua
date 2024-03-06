local M = {}

local request_http = require 'genius.http'
local utils = require 'genius.utils'
local opts = require 'genius.config'

function M.request_chat(contents, options, chat_options, callback, stream, nocodeblocks)
    local api_key = ''
    local model = 'gemini-pro'
    if options.api_key then
        api_key = '?key=' .. options.api_key
    end
    if chat_options.model then
        model = chat_options.model
    end
    -- vim.notify(vim.inspect(api_key))
    -- vim.notify(vim.inspect(messages))
    return request_http(options.base_url, '/v1beta/models/' .. model .. ':generateContent' .. api_key, {
        contents = contents,
        safetySettings = chat_options.safetySettings,
        generationConfig = chat_options.generationConfig,
    }, function (res, time)
        -- vim.notify(vim.inspect(res))
        assert(res ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res) == 'table')
        if type(res.candidates) ~= 'table' then
            utils.report('bad server response: ' .. vim.inspect(res))
            return
        end
        local parts
        if stream then
            parts = res.candidates[1].content.parts or {{text = ''}}
        else
            parts = res.candidates[1].content.parts or {{text = ''}}
        end
        -- if not stream and res.usage then
        --     local price = (res.usage.prompt_tokens * opts.chat_marks.input_price + res.usage.completion_tokens * opts.chat_marks.output_price) * 0.001
        -- end
        local content = ''
        for _, part in ipairs(parts) do
            assert(type(part.text) == 'string')
            content = content .. part.text
        end
        if nocodeblocks then
            content = content:gsub('^```%w*\n', ''):gsub('\n```$', '')
        end
        return callback(content, time)
    end, stream)
end

function M.on_complete(prefix, suffix, on_complete, options)
    if options.infill_marks.completion then
        prefix = options.infill_marks.completion .. prefix
    end
    if (#suffix ~= 0 or options.infill_marks.may_no_suffix) and options.infill_marks.suffix then
        prefix = options.infill_marks.prefix .. prefix .. options.infill_marks.suffix .. suffix .. options.infill_marks.middle
    elseif options.infill_marks.completion then
        prefix = options.infill_marks.completion .. prefix
    end
    utils.dump(prefix)
    local contents = {
        {parts = {{text = prefix}}},
    }
    return M.request_chat(contents, options, options.infill_options, on_complete, false, true)
end

function M.on_chat(messages, on_stream, options)
    utils.dump(messages)
    local contents = {}
    for _, message in ipairs(messages) do
        local role = nil
        if message.role == 'user' then
            role = 'user'
        elseif message.role == 'assistant' then
            role = 'model'
        end
        if role then
            contents[#contents] = {parts = {{text = message.content, role = role}}}
        end
    end
    return M.request_chat(contents, options, options.chat_options, on_stream, opts.chat_stream, false)
end

return M
