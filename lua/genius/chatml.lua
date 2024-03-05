local M = {}

-- function M.apply_infill_template(prefix, suffix, opts)
--     if #suffix ~= 0 and opts.infill_marks.insertion then
--         return opts.infill_marks.insertion[1] .. prefix .. opts.infill_marks.insertion[2] .. suffix .. opts.infill_marks.insertion[3]
--     else
--         return opts.infill_marks.completion .. prefix
--     end
-- end

-- function M.escape_content(text, opts)
--     if opts.escape_special_tokens then
--         local escape_list = opts.escape_list
--         if escape_list then
--             for _, pair in ipairs(escape_list) do
--                 text = text:gsub(pair[1], pair[2])
--             end
--         end
--     end
--     return text
-- end
--
-- function M.apply_chat_template(text, opts)
--     local prompt = ''
--     local system = true
--     local user = true
--     local eos = false
--     for _, line in ipairs(vim.split(text:gsub('\n' .. opts.chat_sep_assistant .. '\n',
--         '\n' .. opts.chat_sep_user .. '\n'), '\n' .. opts.chat_sep_user .. '\n', {plain = true})) do
--         line = M.escape_content(line, opts)
--         if system then
--             system = false
--         else
--             if user then
--                 local inst_prefix = opts.chat_marks.inst_prefix_bos
--                 if eos then
--                     inst_prefix = opts.chat_marks.inst_prefix_eos
--                 end
--                 eos = true
--                 line = inst_prefix .. line .. opts.chat_marks.inst_suffix
--             end
--             prompt = prompt .. line
--             user = not user
--         end
--     end
--     return prompt
-- end

function M.parse_chat_template(text, opts)
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

return M
