if lazyvim_docs then
  -- LSP Server to use for Rust.
  -- Set to "bacon-ls" to use bacon-ls instead of rust-analyzer.
  -- only for diagnostics. The rest of LSP support will still be
  -- provided by rust-analyzer.
  vim.g.lazyvim_rust_diagnostics = "rust-analyzer"
end

local diagnostics = vim.g.lazyvim_rust_diagnostics or "rust-analyzer"

return {
  recommended = function()
    return LazyVim.extras.wants({
      ft = "rust",
      root = { "Cargo.toml", "rust-project.json" },
    })
  end,

  -- Extend auto completion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      {
        "Saecki/crates.nvim",
        event = { "BufRead Cargo.toml" },
        opts = {
          completion = {
            cmp = { enabled = true },
          },
        },
      },
    },
    ---@param opts cmp.ConfigSchema
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      table.insert(opts.sources, { name = "crates" })
    end,
  },

  -- Add Rust & related to treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "rust", "ron" } },
  },

  -- Ensure Rust debugger is installed
  {
    "williamboman/mason.nvim",
    optional = true,
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "codelldb" })
      if diagnostics == "bacon-ls" then
        vim.list_extend(opts.ensure_installed, { "bacon" })
      end
    end,
  },

  {
    "mrcjkb/rustaceanvim",
    version = "^4", -- Recommended
    ft = { "rust" },
    opts = {
      server = {
        on_attach = function(_, bufnr)
          vim.keymap.set("n", "<leader>cR", function()
            vim.cmd.RustLsp("codeAction")
          end, { desc = "Code Action", buffer = bufnr })
          vim.keymap.set("n", "<leader>dr", function()
            vim.cmd.RustLsp("debuggables")
          end, { desc = "Rust Debuggables", buffer = bufnr })
        end,
        default_settings = {
          -- rust-analyzer language server configuration
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
              loadOutDirsFromCheck = true,
              buildScripts = {
                enable = true,
              },
            },
            -- Add clippy lints for Rust if using rust-analyzer
            checkOnSave = diagnostics == "rust-analyzer",
            -- Enable diagnostics if using rust-analyzer
            diagnostics = {
              enable = diagnostics == "rust-analyzer",
            },
            procMacro = {
              enable = true,
              ignored = {
                ["async-trait"] = { "async_trait" },
                ["napi-derive"] = { "napi" },
                ["async-recursion"] = { "async_recursion" },
              },
            },
          },
        },
      },
    },
    config = function(_, opts)
      -- Configure dap with codelldb
      local package_path = require("mason-registry").get_package("codelldb"):get_install_path()
      opts.dap = {
        adapter = require("rustaceanvim.config").get_codelldb_adapter(
          package_path .. "/codelldb",
          package_path .. "/extension/lldb/lib/liblldb.dylib"
        ),
      }
      vim.g.rustaceanvim = vim.tbl_deep_extend("keep", vim.g.rustaceanvim or {}, opts or {})
      if vim.fn.executable("rust-analyzer") == 0 then
        LazyVim.error(
          "**rust-analyzer** not found in PATH, please install it.\nhttps://rust-analyzer.github.io/",
          { title = "rustaceanvim" }
        )
      end
    end,
  },

  -- Correctly setup lspconfig for Rust 🚀
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        bacon_ls = {
          enabled = diagnostics == "bacon-ls",
        },
        taplo = {
          keys = {
            {
              "K",
              function()
                if vim.fn.expand("%:t") == "Cargo.toml" and require("crates").popup_available() then
                  require("crates").show_popup()
                else
                  vim.lsp.buf.hover()
                end
              end,
              desc = "Show Crate Documentation",
            },
          },
        },
      },
    },
  },

  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      adapters = {
        ["rustaceanvim.neotest"] = {},
      },
    },
  },
}
