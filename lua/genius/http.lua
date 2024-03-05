local curl = require 'plenary.curl'
local state = require 'genius.state'
local utils = require 'genius.utils'

local function request_http(base_url, uri, data, callback, stream, authorization)
    if not state.plugin_enabled then
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
                return utils.report(msg)
            end),
        }
        if stream then
                -- vim.notify(opts.body)
            opts.stream = vim.schedule_wrap(function (err, res)
                if canceled then return end
                if err then
                    local msg = string.format("--- CURL STREAM ERROR ---\n%s", err)
                    return utils.report(msg)
                end
                if vim.startswith(res, 'data: ') then
                    local body = res:sub(7)
                    if body == "[DONE]" then return end
                    local success, result = pcall(vim.fn.json_decode, body)
                    if not success then
                        local msg = string.format("--- JSON LINE DECODE FAILURE ---\n%s", body)
                        return utils.report(msg)
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
                    return utils.report(msg)
                end
                local success, result = pcall(vim.fn.json_decode, res.body)
                if not success then
                    local msg = string.format("--- JSON DECODE FAILURE ---\n%s", res.body)
                    return utils.report(msg)
                end
                local dt = vim.fn.reltimefloat(vim.fn.reltime(t0))
                return callback(result, dt)
            end)
        end
        local success, job = pcall(curl.post, base_url .. uri, opts)
        -- vim.notify(vim.inspect(job))
        if not success then
            utils.report('curl.post invocation failed')
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
    if state.plugin_ready == true then
        return begin_request()
    elseif state.plugin_ready == nil then
        local canceler = nil
        local canceled = false
        if string.match(uri, '^/v1/') then
            curl.get(base_url .. '/v1/models', {
                on_error = vim.schedule_wrap(function ()
                    state.plugin_ready = false
                    utils.report('completion server not ready (failed to connect)')
                end),
                callback = vim.schedule_wrap(function (res)
                    if res.status ~= 200 then
                        state.plugin_ready = false
                        if res.status == 401 then
                            utils.report('completion server not ready (status 401, invalid API key)')
                        else
                            utils.report('completion server not ready (status ' .. res.status .. ')')
                        end
                    else
                        state.plugin_ready = true
                        if canceled then return end
                        canceler = begin_request()
                    end
                end),
            })
        else
            curl.get(base_url .. '/', {
                on_error = vim.schedule_wrap(function ()
                    state.plugin_ready = false
                    utils.report('completion server not ready (failed to connect)')
                end),
                callback = vim.schedule_wrap(function (res)
                    _ = res
                    state.plugin_ready = true
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

return request_http
