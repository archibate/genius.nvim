local default_opts = {
    default_bot = 'openai',
    config_openai = {
        api_type = 'openai',
        api_key = os.getenv("OPENAI_API_KEY"),
        base_url = "https://api.openai.com",
        chat_options = {
            max_tokens = 1024,
            model = "gpt-3.5-turbo",
            temperature = 0.5,
        },
        infill_marks = {
            completion = "Do code completion based on the following code. No repeat. Indentation must be correct. Be short and relevant.\n\n",
        },
        infill_options = {
            max_tokens = 100,
            model = "gpt-3.5-turbo-instruct",
            temperature = 0.5,
        },
    },
    config_deepseek = {
        api_type = 'llama_cpp',
        base_url = "http://127.0.0.1:8080",
        chat_marks = {
            inst_prefix_bos = "Expert Q&A\nQuestion: ",
            inst_prefix_eos = "<|EOT|>\nQuestion: ",
            inst_suffix = "\nAnswer:",
        },
        chat_options = {
            n_predict = -1,
            stop = { "\nQuestion:" },
            temperature = 0.5,
        },
        escape_list = { { "<｜([%l▁]+)｜>", "<|%1|>" }, { "<|(%u+)|>", "<｜%1｜>" } },
        infill_marks = {
            may_no_suffix = false,
            prefix = "<｜fim▁begin｜>",
            suffix = "<｜fim▁hole｜>",
            middle = "<｜fim▁end｜>",
        },
        infill_options = {
            n_predict = 100,
            temperature = 0.5,
        },
    },
    config_mistral = {
        api_type = 'llama_cpp',
        base_url = "http://127.0.0.1:8080",
        chat_marks = {
            inst_prefix_bos = "<s>[INST] ",
            inst_prefix_eos = "</s>[INST] ",
            inst_suffix = " [/INST]",
        },
        chat_options = {
            n_predict = -1,
            temperature = 0.5,
        },
        escape_list = { { "</?[su]n?k?>", string.upper }, { "<0x[0-9A-F][0-9A-F]>", string.upper } },
        infill_marks = {
            completion = "Do code completion based on the following code. No repeat. Indentation must be correct. Be short and relevant.\n\n",
        },
        infill_options = {
            n_predict = 100,
            stop = { "### File:" },
            temperature = 0.5,
        },
    },
    config_google = {
        api_type = 'google',
        api_key = os.getenv("GOOGLE_API_KEY"),
        base_url = "https://generativelanguage.googleapis.com",
        chat_options = {
            model = 'gemini-pro',
            generationConfig = {
                maxOutputTokens = 1024,
                temperature = 0.5,
            },
        },
        infill_marks = {
            may_no_suffix = false,
            prefix = 'What should be inserted at <CURSOR>?\n',
            suffix = '<CURSOR>',
            middle = '',
        },
        infill_options = {
            model = 'gemini-pro',
            generationConfig = {
                maxOutputTokens = 100,
                temperature = 0.5,
            },
        },
    },
    config_minimax = {
        api_type = 'minimax',
        group_id = os.getenv("MINIMAX_GROUP_ID"),
        api_key = os.getenv("MINIMAX_API_KEY"),
        base_url = 'https://api.minimax.chat',
        chat_marks = {
            instruction = "一个代码助手，帮助用户编写代码，解决编程问题。",
        },
        chat_options = {
            model = "abab6-chat",
            tokens_to_generate = 1024,
            temperature = 0.5,
        },
        infill_marks = {
            may_no_suffix = false,
            instruction = "一个代码补全机器人，针对用户输入的代码，输出补全的结果，不要解释。",
            prefix = '<CURSOR>处应该插入什么内容？\n',
            suffix = '<CURSOR>',
            middle = '',
        },
        infill_options = {
            model = "abab6-chat",
            tokens_to_generate = 100,
            temperature = 0.5,
        },
    },
    marks = {
        cwd_files = "### List of current directory:\n",
        file_content = "\n",
        file_eos = "\n",
        file_name = "### File: ",
        begin_above_mark = "",
    },
    edit_template = 'Edit the following code, to make it complete and correct:\n```$filetype\n$code\n```\nOutput the edited code. Do not explain.',
    instruct_edit_template = 'Edit the code concisely following the instruction: $instruction\n```$filetype\n$code\n```\nOutput the edited code. Do not explain.',
    completion_buffers = 1,
    single_buffer_has_mark = false,
    buffers_sort_mru = true,
    exceeded_buffer_has_mark = true,
    completion_delay_ms = 2000,
    complete_only_on_eol = false,
    trimming_window = 7200,
    trimming_suffix_portion = 0.3,
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
        local a = rawget(t, 'default_bot')
        if type(a) ~= 'string' then return nil end
        local cfg = rawget(t, 'config_' .. a)
        if cfg == nil then return nil end
        return cfg[k]
    end,
})

return default_opts
