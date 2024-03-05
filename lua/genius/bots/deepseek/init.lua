local M = {}

local request_http = require 'genius.http'
local utils = require 'genius.utils'

function M.request_embedding(content, callback, opts)
    return request_http(opts.base_url, '/embedding', {
        content = content,
    }, function (res, time)
        assert(res.embedding ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.embedding) == 'table')
        return callback(res.embedding, time)
    end)
end

function M.request_tokenize(content, callback, opts)
    return request_http(opts.base_url, '/tokenize', {
        content = content,
    }, function (res, time)
        assert(res.tokens ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.tokens) == 'table')
        return callback(res.tokens, time)
    end)
end

function M.request_detokenize(tokens, callback, opts)
    return request_http(opts.base_url, '/detokenize', {
        tokens = tokens,
    }, function (res, time)
        assert(res.content ~= nil, 'invalid server response: ' .. vim.inspect(res))
        assert(type(res.content) == 'table')
        return callback(res.content, time)
    end)
end

function M.request_completion(prompt, seed, opts, options, callback, stream, ridspace, ridnewline)
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

return M
