# genius.nvim

[English](README.md) | [简体中文](README.zh_CN.md)

小彭老师自主研发的一款 NeoVim 极速代码补全 🚀

## 安装

推荐使用 [packer.nvim](https://github.com/wbthomason/packer.nvim) 来管理 NeoVim 插件：

```lua
use {
    'archibate/genius.nvim',
    requires = {
        'nvim-lua/plenary.nvim',
        'MunifTanjim/nui.nvim',
    },
    config = function()
        require'genius'.setup {
            -- 本插件支持多个后端，默认是 openai 后端：
            default_bot = 'openai',
            -- 您可以从 OpenAI 获取 API 密钥（如果您有账号的话）：https://platform.openai.com/account/api-keys
            -- 要么在 .bashrc 中设置环境变量 OPENAI_API_KEY，要么在此处设置 api_key 选项：
            config_openai = {
                api_key = os.getenv("OPENAI_API_KEY"),
            },
            -- 否则，您也可以使用 DeepSeek-Coder，在本地运行代码补全模型：
            -- default_bot = 'deepseek',
            -- 该模型安装与配置方法，详见后面的章节。
        }
    end,
}
```

## 使用

在插入模式下，光标保持不动 2 秒（延迟值可以在设置中更改），补全就会自动显示出来。按 `<Tab>` 键可以接受整个补全。

[待办事项：这里插入图片]

可以在设置中指定触发补全前的延迟：

```lua
require"genius".setup {
    completion_delay_ms = 2000, -- 补全触发前的微秒数，将其设置为 -1 可以禁用自动触发（仅允许手动触发）
}
```

如果补全没有及时显示，或者您设置了 `completion_delay_ms = -1`，您也可以按下 `<S-Tab>`，手动触发补全。

在插入模式中的行末按下 `<End>` 键也可以呼出 AI 补全。

此外，使用 `:GeniusChat` 命令还可以进入弹出窗口中的自由聊天模式。

> 此插件主要的开发重点是代码补全，因此聊天模式仍在施工中。

## 提示与技巧

当补全出现时，您可以按以下键：

- `<Tab>` 键接受整个补全。
- `<Right>` 箭头键接受单个单词。
- `<Left>` 箭头键撤销单个单词。
- `<End>` 键接受整行。
- `<Home>` 键撤销整行。
- `<S-Tab>` 键请求重新生成新的补全。
- `<Del>` 键关闭当前显示的补全。
- 继续输入不同的代码或离开插入模式将取消剩余的补全。

请注意，这些键映射仅在补全出现时起作用，不会影响没有补全时的默认行为。

[待办事项：这里插入图片]

如果您不喜欢这些键映射，可以选择在设置中逐个禁用它们：

```lua
require"genius".setup {
    keymaps = {
        tab = false, -- tab 键接受全部
        shifttab = false, -- shift+tab 用于手动触发补全和重新生成补全
        delete = false, -- <Del> 键取消当前补全
        leftright = false, -- 箭头键接受/撤销单词
        homeend = false, -- <Home> 和 <End> 用于行
        freeend = false, -- 行末的 <End> 用于手动触发补全
    },
}
```

如果你需要自定义键位，只需映射到 `:GeniusComplete` 命令即可。例如：

```vim
inoremap <C-Space> <Cmd>GeniusComplete<CR>
```

# 可用后端

## ChatGPT

默认情况下，此插件使用 ChatGPT 作为后端，如果在设置中未配置，则默认会读取 `$OPENAI_API_KEY` 环境变量。

您可以在设置中更改其他补全选项：

```lua
require"genius".setup {
    api_type = 'openai',
    config_openai = {
        -- 为了使用带有 GPT 后端的 genius.nvim。您可以从 OpenAI 获取 API 密钥：https://platform.openai.com/account/api-keys
        -- 要么在 .bashrc 中设置环境变量 OPENAI_API_KEY，要么在此处设置设置选项：
        api_key = os.getenv("OPENAI_API_KEY"),
        infill_options = {
            max_tokens = 100,  -- 允许在单个补全中生成的最大标记数
            model = "gpt-3.5-turbo-instruct",  -- 必须在此处使用 instruct 模型，不能使用聊天模型！您可以将其替换为 code-davinci-002 例如
            temperature = 0.8,  -- 温度范围从 0 到 1，更高表示更随机（更有趣）的结果
        },
    },
}
```

## Deepseek Coder

此插件还支持使用 [Deepseek Coder](https://github.com/deepseek-ai/DeepSeek-Coder) 模型（该模型的特点是完全开源且可以在本地部署）：

```lua
require'genius'.setup {
    default_bot = 'deepseek',
    config_deekseek = {
        api_type = 'llama_cpp',
        base_url = "http://127.0.0.1:8080",  -- 🦙 llama.cpp 服务器地址
        infill_options = {
            n_predict = 100, -- 在单个补全中生成的标记数
            temperature = 0.8, -- 更高表示更随机（更有趣）的结果
        },
    },
}
```

### 下载模型

要使用 DeepSeek Coder 模型，首先让我们下载他的 GGUF 模型文件 [deepseek-coder-6.7b-base.Q4_K_M.gguf](https://huggingface.co/TheBloke/deepseek-coder-6.7B-base-GGUF/blob/main/deepseek-coder-6.7b-base.Q4_K_M.gguf)：

```bash
curl -L "https://huggingface.co/TheBloke/deepseek-coder-6.7B-base-GGUF/resolve/main/deepseek-coder-6.7b-base.Q4_K_M.gguf" -o ~/Downloads/deepseek-coder-6.7b-base.Q4_K_M.gguf
```

### 下载并构建 llama.cpp

下载 [llama.cpp](https://github.com/ggerganov/llama.cpp) 仓库并构建其中的 `server` 目标：

```bash
git clone https://github.com/ggerganov/llama.cpp --depth=1
cd llama.cpp
make LLAMA_CUBLAS=1 LLAMA_FAST=1 -j 8 server
```

> 如果您没有 NVIDIA 显卡，或者有 NVIDIA 显卡但没有足够的内存（~6 GB），请考虑去除这里的 `LLAMA_CUBLAS=1` 选项，以使模型完全在 CPU 上运行。

### 启动 llama.cpp 服务器

在使用此插件之前，请先启动 llama.cpp 服务器：

```bash
./server -t 8 -ngl 64 -c 4096 -m ~/Downloads/deepseek-coder-6.7b-base.Q4_K_M.gguf
```

- `-t 8` 表示使用 8 个 CPU 线程。
- `-ngl 64` 表示将神经网络的前 64 层装载到 GPU（其余层在 CPU 上）。
- `-c 4096` 表示模型将限制为 4096 上下文长度。

💣 注意：`-ngl 64` 时大约会消耗 5 GB 左右的 GPU 内存。如果您的 GPU 内存不足，考虑减少 `-ngl` 参数。指定 `-ngl 0` 可在 CPU 上完全运行模型。

## Mistral

使用 Mistral 模型与 DeepSeek Coder 的过程大致相同，因为他们都可以通过 llama.cpp 提供服务，只需指定 `default_bot = 'mistral'` 即可。

## MiniMax 开放平台

TODO: 介绍这个

# 完整配置

以下是此插件的默认配置：

```lua
require'genius'.setup {
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
            prefix = '<CURSOR>处应该插入什么内容？',
            suffix = '<CURSOR>',
            middle = '',
        },
        infill_options = {
            model = "abab6-chat",
            tokens_to_generate = 100,
            temperature = 0.5,
        },
    },
    completion_buffers = 1, -- 设为 3 可以把最近使用过的两个缓冲区也作为补全的依据，设为 1 则只使用当前正在编辑的缓冲区
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
        delete = true,
        leftright = true,
        homeend = true,
        freeend = true,
    },
    filetype_hints = {
        gitcommit = '# Please write a memorizable commit message based on files changed:\n',
    },
    chat_stream = true,
    chat_sep_assistant = '🤖',
    chat_sep_user = '😊',
    report_error = true, -- 设为 false 可以禁用报错
}
```

如果您有任何问题，请在 [GitHub issues](https://github.com/archibate/genius/issues) 页面中告诉我，感谢您的支持！
