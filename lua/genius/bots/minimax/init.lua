local M = {}

local request_http = require 'genius.http'
local utils = require 'genius.utils'
local opts = require 'genius.config'

function M.request_chat_pro(messages, seed, options, chat_options, callback, stream, nocodeblocks)
    local api_key = options.api_key
    local group_id = ''
    if options.group_id then
        group_id = '?GroupId=' .. options.group_id
    end
    -- vim.notify(vim.inspect(api_key))
    -- vim.notify(vim.inspect(messages))
    return request_http(options.base_url, '/v1/text/chatcompletion_pro' .. group_id, vim.tbl_extend('force', {
        messages = messages,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, chat_options), function (res, time)
        -- vim.notify(vim.inspect(res))
        assert(res ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res) == 'table')
        if res.base_resp.status_code ~= 0 then
            -- utils.report('API key: ' .. vim.inspect(options))
            utils.report(res.base_resp.status_msg)
            return
        end
        local m = res.choices[1].messages
        local content = m[#m].text or ''
        if nocodeblocks then
            content = content:gsub('^```%w*\n', ''):gsub('\n```$', '')
        end
        -- if not stream and res.usage then
        --     local price = (res.usage.prompt_tokens * opts.chat_marks.input_price + res.usage.completion_tokens * opts.chat_marks.output_price) * 0.001
        -- end
        assert(type(content) == 'string')
        return callback(content, time)
    end, stream, api_key and 'Bearer ' .. api_key)
end

-- function M.on_edit(code, on_edit, options)
--     if options.edit_marks.edition then
--         code = options.edit_marks.edition .. code
--     end
--     if options.edit_marks.edition_end then
--         code = code .. options.edit_marks.edition_end
--     end
--     utils.dump(code)
--     local chatopts = vim.tbl_extend('force', options.edit_options, {
--         reply_constraints = {
--             sender_type = "BOT",
--             sender_name = "assistant",
--         },
--         bot_setting = {
--             {
--                 bot_name = "assistant",
--                 content = options.edit_marks.instruction,
--             },
--         },
--     })
--     local messages = {
--         {
--             sender_type = 'USER',
--             sender_name = 'user',
--             text = code,
--         },
--     }
--     return M.request_chat_pro(messages, -1, options, chatopts, on_edit, false)
-- end

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
    local chatopts = vim.tbl_extend('force', options.infill_options, {
        reply_constraints = {
            sender_type = "BOT",
            sender_name = "assistant",
        },
        bot_setting = {
            {
                bot_name = "assistant",
                content = options.infill_marks.instruction,
            },
        },
    })
    local messages = {
        {
            sender_type = 'USER',
            sender_name = 'user',
            text = prefix,
        },
    }
    return M.request_chat_pro(messages, -1, options, chatopts, on_complete, false, true)
end

function M.on_chat(messages, on_stream, options)
    utils.dump(messages)
    local new_messages = {}
    for i = 1, #messages do
        new_messages[i].role = messages[i].sender_type == 'USER' and 'user' or 'assistant'
        new_messages[i].content = messages[i].text
    end
    local chatopts = vim.tbl_extend('force', options.infill_options, {
        reply_constraints = {
            sender_type = "BOT",
            sender_name = "assistant",
        },
        bot_setting = {
            {
                bot_name = "assistant",
                content = options.chat_marks.instruction,
            },
        },
    })
    return M.request_chat_pro(new_messages, -1, options, chatopts, on_stream, opts.chat_stream, true)
end

return M
