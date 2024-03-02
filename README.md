# genius.nvim

Blazing fast 🚀 code completion in NeoVim powered by 🤖 GPT-3.5-Turbo!

## Installation

It's suggested to use [packer.nvim](https://github.com/wbthomason/packer.nvim) to manage NeoVim plugins:

```lua
use {
    'archibate/genius.nvim',
    requires = {
        'nvim-lua/plenary.nvim',
        'MunifTanjim/nui.nvim',
    },
    config = function()
        require'genius'.setup {
            -- This plugin supports many backends, openai backend is the default:
            api_type = 'openai',
            -- You may obtain an API key from OpenAI as long as you have an account: https://platform.openai.com/account/api-keys
            -- Either set the environment variable OPENAI_API_KEY in .bashrc, or set api_key option in the setup here:
            config_openai = {
                api_key = os.getenv("OPENAI_API_KEY"),
            },
            -- Otherwise, you may run DeepSeek-Coder locally instead:
            -- api_type = 'deepseek',
            -- See sections below for detailed instructions on setting up this model.
        }
    end,
}
```

## Usage

In insert mode, hold cursor for 2 seconds (can be changed in setup), and completion will shows up. Press `<Tab>` to accept the completion.

[TODO: image here]

The hold delay can be customized in the setup:

```lua
require"genius".setup {
    completion_delay_ms = 2000, -- microseconds before completion triggers, set this to -1 to disable and only allows manual trigger
}
```

If the completion didn't shows up in time or you've setup `completion_delay_ms = -1`, you may press `<S-Tab>` to manually trigger AI completion in insert mode.

Pressing `<End>` when cursor at the end of a line in insert mode triggers AI completion too.

Also, use `:GeniusChat` to enter free chat mode in a popup window.

> This plugin mainly focus on code completion, so chat mode is still work in progress.

## Tips & Tricks

When completion is visible. You may press:

- `<Tab>` to accept the whole completion.
- `<Right>` arrow to accept a single word.
- `<Left>` arrow to revoke a single word.
- `<End>` to accept a whole line.
- `<Home>` to revoke a whole line.
- `<S-Tab>` to regenerate a new completion.
- `<Del>` to dismiss the completion.
- Continue typing or leaving insert mode will dismiss the rest of the completion.

Note these keymaps only works when the completion is visible. The default behavior when no completion is shown remains still.

[TODO: image here]

If you dislike these keymaps, you may optionally disable them one by one in the setup:

```lua
require"genius".setup {
    keymaps = {
        tab = false, -- tab for accept all
        shifttab = false, -- shift+tab for manual trigger and regenerating completion
        delete = false, -- <Del> for dismiss completion
        leftright = false, -- arrow keys for accept/revoke words
        homeend = false, -- <Home> and <End> for lines
        freeend = false, -- <End> at the end of line for manual trigger
    },
}
```

If you'd like to use a custom key binding, just map to the `:GeniusComplete` command. For example:

```vim
inoremap <C-Space> <Cmd>GeniusComplete<CR>
```

# Available backends

## ChatGPT

By default, this plugin use ChatGPT as backend, it reads the `$OPENAI_API_KEY` environment variable by default if not configured in the setup.

You may change the other completion options in the setup:

```lua
require"genius".setup {
    api_type = 'openai',
    config_openai = {
        -- In order to use genius.nvim with GPT backend. You may obtain an API key from OpenAI: https://platform.openai.com/account/api-keys
        -- Either set the environment variable OPENAI_API_KEY in .bashrc, or set in the setup options here:
        api_key = os.getenv("OPENAI_API_KEY"),
        infill_options = {
            max_tokens = 100,  -- maximum number of tokens allowed to generate in a single completion
            model = "gpt-3.5-turbo-instruct",  -- must be instruct model here, no chat models! you may only replace this with code-davinci-002 for example
            temperature = 0.8,  -- temperature varies from 0 to 1, higher means more random (and more funny) results
        },
    },
}
```

## Deepseek Coder

This plugin can also be customized to use the [Deepseek Coder](https://github.com/deepseek-ai/DeepSeek-Coder) model which can be deployed locally on your machine:

```lua
require'genius'.setup {
    api_type = 'deepseek',
    config_deekseek = {
        base_url = "http://127.0.0.1:8080",  -- 🦙 llama.cpp server address
        infill_options = {
            n_predict = 100, -- number of tokens to generate in a single completion
            temperature = 0.8, -- higher means more random (and more funny) results
        },
    },
}
```

### Download the Model

To get started with DeepSeek Coder, let's first download the GGUF model file [deepseek-coder-6.7b-base.Q4_K_M.gguf](https://huggingface.co/TheBloke/deepseek-coder-6.7B-base-GGUF/blob/main/deepseek-coder-6.7b-base.Q4_K_M.gguf):

```bash
curl -L "https://huggingface.co/TheBloke/deepseek-coder-6.7B-base-GGUF/resolve/main/deepseek-coder-6.7b-base.Q4_K_M.gguf" -o ~/Downloads/deepseek-coder-6.7b-base.Q4_K_M.gguf
```

### Download and Build llama.cpp

Download the [llama.cpp](https://github.com/ggerganov/llama.cpp) repository and build the `server` target in it:

```bash
git clone https://github.com/ggerganov/llama.cpp --depth=1
cd llama.cpp
make LLAMA_CUBLAS=1 LLAMA_FAST=1 -j 8 server
```

> Consider remove the `LLAMA_CUBLAS=1` option if you don't have a NVIDIA card, or you don't have enough (~6 GB) memory on your NVIDIA card. So that the model will run completely on CPU.

### Start llama.cpp Server

Start the server before you can use this plugin:

```bash
./server -t 8 -ngl 64 -c 4096 -m ~/Downloads/deepseek-coder-6.7b-base.Q4_K_M.gguf
```

- `-t 8` means using 8 CPU threads.
- `-ngl 64` means 64 layers will be offloaded to GPU (the rest on CPU).
- `-c 4096` means the model will be limited to 4096 context length.

💣 CAUTION: `-ngl 64` consumes approximately 5 GB of GPU memory. If you don't have too much GPU memory, consider reduce the `-ngl` parameter. Specify `-ngl 0` to run the model completely on CPU.

## Mistral

Using the Mistral backend is roughly the same as DeepSeek Coder, as it can be also served on llama.cpp, just use `api_type = 'mistral'` instead.

# Full Setup

Below is the default setup for this plugin:

```lua
require'genius'.setup {
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
            completion = "",
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
    completion_buffers = 1, -- setting to 3 include 2 recently used buffer into the prompt, 1 for only using the current editing buffer
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
        gitcommit = '# Please write a memorizable commit message based on files changed:\n',
    },
    chat_stream = true,
    chat_sep_assistant = '🤖',
    chat_sep_user = '😊',
    report_error = true, -- set this to false for disable error notification.
}
```

If you encounter any trouble, let me know in the [GitHub issues](https://github.com/archibate/genius/issues), thanks for your support!
