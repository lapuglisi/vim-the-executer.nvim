local M = {}

M.options = {}

M.default_options = {
	execute_key = "<F5>",
	height_ratio = 0.8,
	width_ratio = 0.8,
	float_window = {
		title = " vim-the-executer ",
		title_pos = "center",
		border = "rounded",
		border_fg = "",
		border_bg = "",
		border_bold = false,
	},
}

---@private
local function current_text_into_argv()
	local mode = vim.api.nvim_get_mode().mode
	local argv = {}
	local text = ""

	if mode == "v" or mode == "V" or mode == "\22" then
		-- Proceed to get the current selection
		local texts = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode })
		text = vim.fn.join(texts, " ")
	else
		-- just get the current line
		text = vim.api.nvim_get_current_line()
	end

	text = text:gsub("[\r\n\t]+", "")

	-- Proceed to actual split
	local in_quote = false
	local match = ""
	for t in text:gmatch("%S+") do
		local s = t:sub(1, 1)
		local e = t:sub(-1)

		if s == '"' or s == "'" then
			if e == '"' or e == "'" then
				-- no need to start in_quote
				-- remove ""
				t = t:gsub("[" .. e .. "]+", "")
				table.insert(argv, t)
			else
				in_quote = true
				match = match .. t .. " "
			end
		elseif e == '"' or e == "'" then
			match = match .. t .. " "
			if in_quote then
				match = vim.fn.trim(match)
				match = match:gsub("[" .. e .. "]+", "")

				table.insert(argv, match)
				match = ""
				in_quote = false
			end
		else
			table.insert(argv, t)
		end
	end

	return argv
end

local function setup_internals(opts)
	opts.float_window = opts.float_window or M.default_options.float_window
	M.options = {
		execute_key = opts.execute_key or M.default_options.execute_key,
		height_ratio = opts.height_ratio or M.default_options.height_ratio,
		width_ratio = opts.width_ratio or M.default_options.width_ratio,
		float_window = {
			title = opts.float_window.title or M.default_options.float_window.title,
			title_pos = opts.float_window.title_pos or M.default_options.float_window.title_pos,
			border = opts.float_window.border or M.default_options.float_window.border,
			border_fg = opts.float_window.border_fg or M.default_options.float_window.border_fg,
			border_bg = opts.float_window.border_bg or M.default_options.float_window.border_bg,
			border_bold = opts.float_window.border_bold or M.default_options.float_window.border_bold,
		},
	}

	-- create our highlight group
	vim.api.nvim_set_hl(0, "vim-the-executer-hl", {
		fg = M.options.float_window.border_fg,
		bg = M.options.float_window.border_bg,
		bold = M.options.float_window.border_bold,
	})
end

local function create_executor_win()
	local buf = vim.api.nvim_create_buf(false, true)

	-- New window options
	local wratio = M.options.width_ratio
	local hratio = M.options.height_ratio
	local win_width = math.ceil(vim.fn.winwidth(0) * wratio)
	local win_height = math.ceil(vim.fn.winheight(0) * hratio)
	local opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		col = (vim.fn.winwidth(0) / 2) - (win_width / 2),
		row = (vim.fn.winheight(0) / 2) - (win_height / 2),
		anchor = "NW", -- North-West anchor
		style = "minimal",
		border = M.options.float_window.border, -- 'bold', 'double', 'none', 'rounded', 'shadow', 'single', 'solid'
		title = M.options.float_window.title,
		title_pos = M.options.float_window.title_pos,
	}

	-- test window existance
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- apply our hl group to window
	vim.api.nvim_set_option_value("winhl", "FloatBorder:vim-the-executer-hl", { win = win })

	vim.api.nvim_buf_set_keymap(buf, "n", "q", "<cmd>bdelete " .. buf .. "<cr>", {})
	vim.api.nvim_buf_set_keymap(buf, "n", M.options.execute_key, "<cmd>bdelete " .. buf .. "<cr>", {})
	vim.api.nvim_buf_set_keymap(buf, "i", M.options.execute_key, "<cmd>bdelete " .. buf .. "<cr>", {})

	return buf, win
end

M.do_the_harlem_shake = function()
	-- get current text (selection or current line)
	local argv = current_text_into_argv()

	local buf, win = create_executor_win()

	-- Actual command execution
	if #argv == 0 then
		vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "Current text is empty." })
		return
	else
		vim.api.nvim_buf_set_lines(buf, 0, 0, false, { "Executing command: " .. vim.inspect(argv), "" })
	end

	local buflinenr = (vim.fn.line("$", win) or 1) + 1
	local out = ""
	local ok, res = pcall(vim.system, argv, { text = true, timeout = 5000 })

	if ok then
		local obj = res:wait()
		out = (obj.stdout or "") .. (obj.stderr or "")
	else
		out = vim.inspect(res)
	end

	local lines = vim.fn.split(out, "\\%x00")
	vim.api.nvim_buf_set_lines(buf, buflinenr - 1, -1, true, lines)
end

M.setup = function(opts)
	setup_internals(opts)

	vim.api.nvim_create_user_command("VimTheExecuter", M.do_the_harlem_shake, { nargs = 0 })
	vim.keymap.set("n", M.options.execute_key, "<cmd>VimTheExecuter<cr>")
	vim.keymap.set("v", M.options.execute_key, "<cmd>VimTheExecuter<cr>")
end

return M
