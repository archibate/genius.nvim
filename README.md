# auto-drive.nvim

Blazing fast 🚀 code completion in NeoVim powered by 🦙 [llama.cpp](https://github.com/ggerganov/llama.cpp).

## Installation

It's suggested to use [packer.nvim](https://github.com/wbthomason/packer.nvim) to manage NeoVim plugins:

## Usage

In insert mode, hold cursor for 1 seconds (can be changed in setup), and completion will shows up. Now just press `<TAB>` to accept completion.

## Tips & Tricks

- Use `<C-p>` and `<C-n>` to cycle through the completions. (`<C-p>` is the previous completion, `<C-n>` is the next one.)
- Use `<TAB>` to accept a completion. (`<Tab>` is actually the completion key. Use `<TAB>` to accept a completion.)
- The model uses only a few MB of RAM, so you can run it on any machine.
- The model is not very good at all. But it gets the job done, and that's what matters most here.
- The model is easy to use, even if it's a bit slow.
- The model is easy to update, and that's what it was intended for.

## Setup

```lua
use {
    'archibate/auto-drive.nvim',
    requires = { 'nvim-lua/plenary.nvim' },
    config = function()
        require'auto-drive'.setup {
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
                completion = "Complete the following code. No repeat. Indentation must be correct. Be short and relevant.\n\n",
                cwd_eos = "\n",
                cwd_files = "### List of current directory:\n",
                file_content = "\n",
                file_eos = "\n",
                file_name = "### File: ",
                insertion = { "", "<INSERT_HERE>", "" },
                input_price = 0.0015,
                output_price = 0.0020,
            },
            infill_options = {
                max_tokens = 100,
                model = "gpt-3.5-turbo-instruct",
                temperature = 0.8,
            },
            api_type = 'openai',
            completion_buffers = 1,
            current_buffer_has_mark = false,
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
                leftright = true,
                homeend = true,
                delete = true,
            },
            chat_stream = true,
            chat_sep_assistant = '🤖',
            chat_sep_user = '😊',
        }
    end,
}
```

## ChatGPT

```lua
require'auto-drive'.setup {
    api_key = os.getenv("OPENAI_API_KEY"),
    base_url = "https://api.openai.com",
    chat_marks = {
        inst_prefix_bos = "### User:\n",
        inst_prefix_eos = "\n### User:\n",
        inst_suffix = "\n### Assistant:\n"
    },
    chat_options = {
        max_tokens = 512,
        model = "gpt-3.5-turbo",
        temperature = 0.8
    },
    infill_marks = {
        completion = "",
        cwd_eos = "\n",
        cwd_files = "### List of current directory:\n",
        file_content = "\n",
        file_eos = "\n",
        file_name = "### File: ",
        insertion = { "", "<INSERT_HERE>", "" }
    },
    infill_options = {
        max_tokens = 100,
        model = "gpt-3.5-turbo-instruct",
        stop = { "### File:" },
        temperature = 0.8
    },
    api_type = 'openai'
}
```

## Deepseek

```lua
require'auto-drive'.setup {
    base_url = "http://127.0.0.1:8080",
    chat_marks = {
        inst_prefix_bos = "Expert Q&A\nQuestion: ",
        inst_prefix_eos = "<|EOT|>\nQuestion: ",
        inst_suffix = "\nAnswer:"
    },
    chat_options = {
        n_predict = -1,
        stop = { "\nQuestion:" },
        temperature = 0.8
    },
    escape_list = { { "<｜([%l▁]+)｜>", "<|%1|>" }, { "<|(%u+)|>", "<｜%1｜>" } },
    infill_marks = {
        completion = "",
        cwd_eos = "<|EOT|>",
        cwd_files = "### List of current directory:\n",
        file_content = "\n",
        file_eos = "<|EOT|>",
        file_name = "### File: ",
        insertion = { "<｜fim▁begin｜>", "<｜fim▁hole｜>", "<｜fim▁end｜>" }
    },
    infill_options = {
        n_predict = 100,
        temperature = 0.8
    },
    api_type = 'llama'
},
}
```

### Download Model

Then, let's download [deepseek-coder-6.7b-base.Q4_K_M.gguf](https://huggingface.co/TheBloke/deepseek-coder-6.7B-base-GGUF/blob/main/deepseek-coder-6.7b-base.Q4_K_M.gguf):

```bash
curl -L "https://huggingface.co/TheBloke/deepseek-coder-6.7B-base-GGUF/resolve/main/deepseek-coder-6.7b-base.Q4_K_M.gguf" -o ~/Downloads/deepseek-coder-6.7b-base.Q4_K_M.gguf
```

### Download and Build llama.cpp

```bash
git clone https://github.com/ggerganov/llama.cpp --depth=1
cd llama.cpp
make LLAMA_CUBLAS=1 LLAMA_FAST=1 -j 8 server
```

> Consider remove the `LLAMA_CUBLAS=1` option in make if you don't have NVIDIA CUDA. The model will run completely on CPU.

### Start llama.cpp Server

Start the server before you can use this plugin:

```bash
./server -t 8 -ngl 64 -c 4096 -m ~/Downloads/deepseek-coder-6.7b-base.Q4_K_M.gguf
```

- `-t 8` means using 8 CPU threads.
- `-ngl 64` means 64 layers will be offloaded to GPU (the rest on CPU).
- `-c 4096` means the model will be limited to 4096 context length.

💣 CAUTION: `-ngl 64` consumes approximately 5 GB of GPU memory. If you don't have too much GPU memory, consider reduce the `-ngl` parameter. Specifiy `-ngl 0` to run the model completely on CPU.

### See also

https://www.e2enetworks.com/blog/how-to-leverage-mistral-7b-llm-as-a-coding-assistant
