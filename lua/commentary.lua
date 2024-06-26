-- copied from https://github.com/neovim/neovim/blob/05435a915a8446a8c2d824551fbea2dc1d7b5e98/runtime/lua/vim/_comment.lua
-- and modified to avoid vim.filetype.get_option as much as possible.
-- NOTE: vim.filetype.get_option ALWAYS checks runtime files.

---cache for language → vim.filetype.get_option
---@type table<string, string|false>
local lang_cms = {}

--- Get 'commentstring' at cursor
---@return string
local function get_commentstring()
  local buf_cs = vim.bo.commentstring

  local has_ts_parser, ts_parser = pcall(vim.treesitter.get_parser)
  if not has_ts_parser then
    return buf_cs
  end

  -- Try to get 'commentstring' associated with local tree-sitter language.
  -- This is useful for injected languages (like markdown with code blocks).
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]
  local ref_range = { row, col, row, col + 1 }

  -- - Get 'commentstring' from the deepest LanguageTree which both contains
  --   reference range and has valid 'commentstring' (meaning it has at least
  --   one associated 'filetype' with valid 'commentstring').
  --   In simple cases using `parser:language_for_range()` would be enough, but
  --   it fails for languages without valid 'commentstring' (like 'comment').
  local ts_cs, res_level = nil, 0
  local buf_lang = vim.treesitter.language.get_lang(vim.bo.filetype)

  ---@param lang_tree vim.treesitter.LanguageTree
  local function traverse(lang_tree, level)
    if not lang_tree:contains(ref_range) then
      return
    end

    if level > res_level then
      local lang = lang_tree:lang()
      if lang == buf_lang and buf_cs ~= '' then
        ts_cs = buf_cs
        res_level = level
      elseif lang_cms[lang] then
        ts_cs = lang_cms[lang]
        res_level = level
      elseif lang_cms[lang] == nil then
        local filetypes = vim.treesitter.language.get_filetypes(lang)
        for _, ft in ipairs(filetypes) do
          local cur_cs = vim.filetype.get_option(ft, 'commentstring')
          if cur_cs ~= '' then
            ts_cs = cur_cs
            lang_cms[lang] = ts_cs --[[@as string]]
            res_level = level
            break
          end
        end
        if res_level ~= level then
          lang_cms[lang] = false
        end
      end
    end

    for _, child_lang_tree in pairs(lang_tree:children()) do
      traverse(child_lang_tree, level + 1)
    end
  end
  traverse(ts_parser, 1)

  return ts_cs or buf_cs
end

return { get_commentstring = get_commentstring }
