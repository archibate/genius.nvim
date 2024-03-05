local default_opts = {
    api_type = 'openai',
    config_openai = {
        api_key = os.getenv("OPENAI_API_KEY"),
        base_url = "https://api.openai.com",
        chat_marks = {
            inst_prefix_bos = "### User:\n",
            inst_prefix_eos = "\n### User:\n",
            inst_suffix = "\n### Assistant:\n",
            input_price = 0.0005,
            output_price = 0.0015,
        },
        chat_options = {
            max_tokens = 512,
            model = "gpt-3.5-turbo",
            temperature = 0.8,
        },
        infill_marks = {
            completion = "Do code completion based on the following code. No repeat. Indentation must be correct. Be short and relevant.\n\n",
            cwd_eos = "\n",
            cwd_files = "### List of current directory:\n",
            file_content = "\n",
            file_eos = "\n",
            file_name = "### File: ",
            begin_above_mark = "\n### Based on the existing files listed above, do code completion for the following file:\n",
            insertion = { "", "<INSERT_HERE>", "" },
            input_price = 0.0015,
            output_price = 0.0020,
        },
        infill_options = {
            max_tokens = 100,
            model = "gpt-3.5-turbo-instruct",
            temperature = 0.8,
        },
    },
    config_deepseek = {
        base_url = "http://127.0.0.1:8080",
        chat_marks = {
            inst_prefix_bos = "Expert Q&A\nQuestion: ",
            inst_prefix_eos = "<|EOT|>\nQuestion: ",
            inst_suffix = "\nAnswer:",
        },
        chat_options = {
            n_predict = -1,
            stop = { "\nQuestion:" },
            temperature = 0.8,
        },
        escape_list = { { "<｜([%l▁]+)｜>", "<|%1|>" }, { "<|(%u+)|>", "<｜%1｜>" } },
        infill_marks = {
            completion = "",
            cwd_eos = "<|EOT|>",
            cwd_files = "### List of current directory:\n",
            file_content = "\n",
            file_eos = "<|EOT|>",
            file_name = "### File: ",
            begin_above_mark = "",
            insertion = { "<｜fim▁begin｜>", "<｜fim▁hole｜>", "<｜fim▁end｜>" },
        },
        infill_options = {
            n_predict = 100,
            temperature = 0.8,
        },
    },
    config_mistral = {
        base_url = "http://127.0.0.1:8080",
        chat_marks = {
            inst_prefix_bos = "<s>[INST] ",
            inst_prefix_eos = "</s>[INST] ",
            inst_suffix = " [/INST]",
        },
        chat_options = {
            n_predict = -1,
            temperature = 0.8,
        },
        escape_list = { { "</?[su]n?k?>", string.upper }, { "<0x[0-9A-F][0-9A-F]>", string.upper } },
        infill_marks = {
            completion = "Do code completion based on the following code. No repeat. Indentation must be correct. Be short and relevant.\n\n",
            cwd_eos = "</s>",
            cwd_files = "### List of current directory:\n",
            file_content = "\n",
            file_eos = "</s>",
            file_name = "### File: ",
            begin_above_mark = "",
        },
        infill_options = {
            n_predict = 100,
            stop = { "### File:" },
            temperature = 0.8,
        },
    },
    completion_buffers = 1,
    single_buffer_has_mark = false,
    buffers_sort_mru = true,
    exceeded_buffer_has_mark = true,
    completion_delay_ms = 2000,
    complete_only_on_eol = false,
    trimming_window = 7200,
    trimming_suffix_portion = 0.28,
    buffers_in_cwd_only = true,
    list_cwd_files = false,
    escape_special_tokens = true,
    rid_prefix_space = true,
    rid_prefix_newline = true,
    keymaps = {
        tab = true,
        shifttab = true,
        delete = true,
        leftright = true,
        homeend = true,
        freeend = true,
    },
    filetype_hints = {
        gitcommit = 'Please write a unique and memorizable commit message based on files changed, no comments or quotes:\n\n\n',
    },
    chat_stream = true,
    chat_sep_assistant = '🤖',
    chat_sep_user = '😊',
    report_error = true,
}

setmetatable(default_opts, {
    __index = function (t, k)
        local v = rawget(t, k)
        if v ~= nil then return v end
        local a = rawget(t, 'api_type')
        if type(a) ~= 'string' then return nil end
        local cfg = rawget(t, 'config_' .. a)
        if cfg == nil then return nil end
        return cfg[k]
    end,
})

return default_opts
