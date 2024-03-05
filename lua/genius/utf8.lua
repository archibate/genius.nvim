local M = {}

function M.utf8_cut_fix(text)
    while #text > 0 and (text:byte() >= 128 and text:byte() <= 191) do
        text = text:sub(2)
    end
    local i, n = #text, 0
    while i > 0 and n <= 4 and (text:byte(i) >= 128 and text:byte(i) <= 191) do
        n = n + 1
        i = i - 1
    end
    local corrupt = 0
    if n == 1 then
        if i == 0 or not (text:byte(i) >= 192 and text:byte(i) <= 223) then
            corrupt = 2
        end
    elseif n == 2 then
        if i == 0 or not (text:byte(i) >= 224 and text:byte(i) <= 239) then
            corrupt = 3
        end
    elseif n == 3 then
        if i == 0 or not (text:byte(i) >= 240 and text:byte(i) <= 247) then
            corrupt = 4
        end
    end
    if corrupt ~= 0 then
        text = text:sub(1, -1 - corrupt)
    end
    return text
end

function M.utf8_count_nth(text, n)
    local count = 0
    for i = 1, #text do
        if not (text:byte() >= 128 and text:byte() <= 191) then
            count = count + 1
        end
        if count == n then
            return i
        end
    end
    return #text
end

function M.utf8_text_width(text)
    -- U+2e80~U+9fff U+a960~U+a97f U+ac00~U+d7ff U+f900~U+faff U+fe30~U+fe6f U+ff01~U+ff60 U+ffe0~U+ffe6 and U+20000~U+2fa1f have display width 2
    local width = 0
    for i = 1, #text do
        local c = text:byte(i)
        if c == 9 then
            width = width + vim.bo.tabstop - (width % vim.bo.tabstop)
        elseif c >= 0 and c <= 127 then
            width = width + 1
        elseif c >= 192 and c <= 223 then
            width = width + 1
        elseif c >= 224 and c <= 225 then
            width = width + 1
        elseif c >= 226 and c <= 239 then
            width = width + 2
        elseif c >= 240 and c <= 247 then
            width = width + 1
        end
    end
    return width
end

function M.trim_prefix_and_suffix(prefix, suffix, opts)
    if opts.trimming_window ~= 0 then
        local nsuffix = opts.infill_marks.insertion and math.max(1, math.floor(opts.trimming_window * opts.trimming_suffix_portion)) or 0
        local nprefix = math.max(1, opts.trimming_window - nsuffix)
        if #prefix < nprefix then
            nsuffix = nsuffix + (nprefix - #prefix)
            nprefix = #prefix
        end
        if #suffix < nsuffix then
            nsuffix = #suffix
        end
        if nprefix < #prefix then prefix = M.utf8_cut_fix(prefix:sub(#prefix - nprefix)) end
        if nsuffix < #suffix then suffix = M.utf8_cut_fix(suffix:sub(1, nsuffix)) end
    end
    return prefix, suffix
end

function M.count_space_nls(prefix, rid_prefix_space, rid_prefix_newline)
    local ridspace = 0
    local ridnewline = 0
    if rid_prefix_space then
        while #prefix > 0 and prefix:byte(-1) == 32 do
            prefix = prefix:sub(1, -2)
            ridspace = ridspace + 1
        end
    end
    if rid_prefix_newline then
        while #prefix > 0 and prefix:byte(-1) == 10 do
            prefix = prefix:sub(1, -2)
            ridnewline = ridnewline + 1
        end
    end
    return prefix, ridspace, ridnewline
end

function M.rid_space_nls(result, ridspace, ridnewline)
    while ridnewline > 0 and #result ~= 0 do
        if result:byte() == 10 then
            result = result:sub(2)
            ridnewline = ridnewline - 1
        else
            ridnewline = 0
        end
    end
    while ridspace > 0 and #result ~= 0 do
        if result:byte() == 32 then
            result = result:sub(2)
            ridspace = ridspace - 1
        else
            ridspace = 0
        end
    end
    return result
end

return M
