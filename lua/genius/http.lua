local curl = require 'plenary.curl'
local state = require 'genius.state'
local utils = require 'genius.utils'

local function request_http(base_url, uri, data, callback, stream, authorization)
    if not state.plugin_enabled then
        return function () end
    end
    local headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = authorization,
    }
    -- base_url = 'http://127.0.0.1:8080/' .. base_url
    -- vim.notify(vim.inspect(headers))
    local function begin_request(ok_url)
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
        local success, job = pcall(curl.post, ok_url .. uri, opts)
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
    if state.plugin_ready[base_url] == nil then
        local canceler = nil
        local canceled = false
        for test_url in base_url:gmatch("[^\r\n]+") do
            if string.match(uri, '^/v1/c') then
                curl.get(test_url .. '/v1/models', {
                    on_error = vim.schedule_wrap(function ()
                        if canceled then return end
                        state.plugin_ready[base_url] = ''
                        utils.report(test_url .. ': completion server not ready (failed to connect)')
                    end),
                    callback = vim.schedule_wrap(function (res)
                        if canceled then return end
                        if res.status ~= 200 then
                            state.plugin_ready[base_url] = ''
                            if res.status == 401 then
                                utils.report(test_url .. ': completion server not ready (status 401, invalid API key)')
                            else
                                utils.report(test_url .. ': completion server not ready (status ' .. res.status .. ')')
                            end
                        else
                            canceled = true
                            state.plugin_ready[base_url] = test_url
                            canceler = begin_request(test_url)
                        end
                    end),
                    headers = {
                        ['Authorization'] = authorization,
                    },
                })
            else
                curl.get(test_url .. '/', {
                    on_error = vim.schedule_wrap(function ()
                        if canceled then return end
                        state.plugin_ready[base_url] = ''
                        utils.report(test_url .. ': completion server not ready (failed to connect)')
                    end),
                    callback = vim.schedule_wrap(function (res)
                        if canceled then return end
                        _ = res
                        canceled = true
                        state.plugin_ready[base_url] = test_url
                        canceler = begin_request(test_url)
                        -- end
                    end),
                    headers = {
                        ['Authorization'] = authorization,
                    },
                })
            end
        end
        return function ()
            canceled = true
            if canceler then
                canceler()
            end
        end
    elseif state.plugin_ready[base_url] ~= '' then
        return begin_request(state.plugin_ready[base_url])
    else
        return function () end
    end
end

return request_http
