local M = {}

local opts = require 'genius.config'

function M.get_bot(name)
    name = name or opts.api_type
    return require('genius.bots.' .. name)
end

function M.switch_bot(name)
    assert(type(name) == 'string')
    opts.default_bot = name
end

return M
