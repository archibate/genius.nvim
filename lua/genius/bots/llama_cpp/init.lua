local M = {}

local request_http = require 'genius.http'
local utils = require 'genius.utils'
local opts = require 'genius.config'

function M.request_embedding(content, callback, options)
    return request_http(options.base_url, '/embedding', {
        content = content,
    }, function (res, time)
        assert(res.embedding ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.embedding) == 'table')
        return callback(res.embedding, time)
    end)
end

function M.request_tokenize(content, callback, options)
    return request_http(options.base_url, '/tokenize', {
        content = content,
    }, function (res, time)
        assert(res.tokens ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.tokens) == 'table')
        return callback(res.tokens, time)
    end)
end

function M.request_detokenize(tokens, callback, options)
    return request_http(options.base_url, '/detokenize', {
        tokens = tokens,
    }, function (res, time)
        assert(res.content ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.content) == 'table')
        return callback(res.content, time)
    end)
end

function M.request_completion(prompt, seed, options, callback, stream)
    return request_http(options.base_url, '/completion', vim.tbl_extend('force', {
        prompt = prompt,
        stream = stream,
        seed = seed ~= -1 and seed or nil,
    }, options.infill_options), function (res, time)
        local content = res.content
        assert(content ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(content) == 'string')
        return callback(content, time, res.stop)
    end, stream)
end

function M.escape_content(text, options)
    if options.escape_list then
        for _, pair in ipairs(options.escape_list) do
            text = text:gsub(pair[1], pair[2])
        end
    end
    return text
end

function M.on_complete(prefix, suffix, on_complete, options)
    prefix = M.escape_content(prefix, options)
    suffix = M.escape_content(suffix, options)
    if (#suffix ~= 0 or options.infill_marks.may_no_suffix) and options.infill_marks.suffix then
        prefix = options.infill_marks.prefix .. prefix .. options.infill_marks.suffix .. suffix .. options.infill_marks.middle
    elseif options.infill_marks.completion then
        prefix = options.infill_marks.completion .. prefix
    end
    utils.dump(prefix)
    return M.request_completion(prefix, -1, options, on_complete, false)
end

return M
