require('packer').startup(
    function()
        use { 'kabouzeid/nvim-lspinstall', requires = 'neovim/nvim-lspconfig' }

        use { 'mfussenegger/nvim-dap' }
    end)

local dap = require 'dap'

local M = {}

function M.execute_buf_command(command, callback)
    vim.lsp.buf_request(
        0, 'workspace/executeCommand', command, function(err, _, res)
            if callback then
                callback(err, res)
            elseif err then
                print('Execute command failed: ' .. err.message)
            end
        end)
end

function M.execute_command(command, callback)
    if type(command) == 'string' then command = { command = command } end

    M.execute_buf_command(
        command, function(err, res)
            assert(not err, err and (err.message or Log.ins(err)))
            callback(res)
        end)
end

--[[
-- Starts the dubug session and returns the port
--
-- @Param callback {function(port: number)}
--]]
function M.start_debug_session(callback)
    M.execute_command('vscode.java.startDebugSession', callback)
end

--[[
-- Returns all the main classes in the project
--
-- @Param callback {function(main_classes: List<List<String>)}
-- { {
--     filePath = "/home/s1n7ax/Workspace/demo/src/main/java/com/example/demo/DemoApplication.java",
--     mainClass = "com.example.demo.DemoApplication",
--     projectName = "demo"
-- } }
--]]
function M.resolve_main_classes(callback)
    M.execute_command('vscode.java.resolveMainClass', callback)
end

--[[
-- Returns classpath for the given main class
--
-- @Param main_class {string} of which classpath should be returned
-- @Param callback {function(classpath: List<List<String>>)}
-- { {},
-- {
--     "/home/s1n7ax/Workspace/demo/bin/main",
--     "/home/s1n7ax/.gradle/.../spring-boot-starter-web/2.5.4/2bef2cedf/spring-boot-starter-web-2.5.4.jar",
-- }
--]]
function M.resolve_class_path(main_class, project_name, callback)
    M.execute_command(
        {
            command = 'vscode.java.resolveClasspath',
            arguments = { main_class, project_name },
        }, callback)
end

--[[
-- Returns list of main class and classpath map
--
-- @Param callback {function(classpaths: List<Map>)}
--]]
function M.resolve_class_paths(callback)
    local classpaths = {}

    local function resolve_all_class_paths(class_iter)
        local class_info = class_iter.next()

        if not class_info then return callback(classpaths) end

        M.resolve_class_path(
            class_info.mainClass, class_info.projectName, function(class_path)
                table.insert(
                    classpaths,
                    { class_info = class_info, class_path = class_path })

                resolve_all_class_paths(class_iter)
            end)
    end

    M.resolve_main_classes(
        function(main_class_info)
            local index = 1

            local main_class_iter = {
                next = function()
                    local temp_index = index
                    index = index + 1
                    return main_class_info[temp_index]
                end,
            }

            resolve_all_class_paths(main_class_iter)
        end)
end

--[[
-- Returns dap java debug configuration
--
-- @Param callback {function(config: Map)}
--]]
function M.get_dap_config(callback)
    M.resolve_class_paths(
        function(class_paths_info)
            local conf = {}

            for index, classpath_info in ipairs(class_paths_info) do
                local main_class = classpath_info.class_info.mainClass
                local project_name = classpath_info.class_info.projectName
                local class_paths = classpath_info.class_path

                table.insert(
                    conf, {
                        name = string.format(
                            '(%d) Launch -> %s -> %s', index, project_name,
                            main_class),
                        projectName = project_name,
                        mainClass = main_class,
                        classPaths = vim.tbl_flatten(class_paths),
                        modulePaths = {},
                        request = 'launch',
                        type = 'java',
                        javaExec = '/usr/bin/java',
                    })
            end

            callback(conf)
        end)
end

local on_attach = function(client, bufnr)
    if client.name == 'java' then
        M.get_dap_config(
            function(conf)
                dap.configurations.java = conf
                print('Debugger is ready')
            end)
    end

    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

    -- Mappings.
    local opts = { noremap = true, silent = true }

    -- See `:help vim.lsp.*` for documentation on any of the below functions
    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.lsp.buf.implementation()<CR>', opts)
    buf_set_keymap(
        'n', '<C-k>', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap(
        'n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>',
        opts)
    buf_set_keymap(
        'n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>',
        opts)
    buf_set_keymap(
        'n', '<space>wl',
        '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>',
        opts)
    buf_set_keymap(
        'n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    buf_set_keymap(
        'n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    buf_set_keymap('n', 'gr', '<cmd>lua vim.lsp.buf.references()<CR>', opts)
    buf_set_keymap(
        'n', '<space>e',
        '<cmd>lua vim.lsp.diagnostic.show_line_diagnostics()<CR>', opts)
    buf_set_keymap(
        'n', '[d', '<cmd>lua vim.lsp.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap(
        'n', ']d', '<cmd>lua vim.lsp.diagnostic.goto_next()<CR>', opts)
    buf_set_keymap(
        'n', '<space>q', '<cmd>lua vim.lsp.diagnostic.set_loclist()<CR>', opts)
    buf_set_keymap(
        'n', '<space>f', '<cmd>lua vim.lsp.buf.formatting()<CR>', opts)
end

local servers = require'lspinstall'.installed_servers()

function setup_servers()
    require'lspinstall'.setup()

    for _, server in ipairs(servers) do
        local config = { on_attach = on_attach }

        if server == 'java' then
            config['init_options'] = {
                bundles = {
                    vim.fn.glob(
                        vim.loop.os_homedir() ..
                            '/.m2/repository/com/microsoft/java' ..
                            '/com.microsoft.java.debug.plugin/0.32.0/' ..
                            'com.microsoft.java.debug.plugin-0.32.0.jar'),
                },
            }
        end
        require'lspconfig'[server].setup(config)

    end
end

setup_servers()

dap.adapters.java = function(callback)
    M.start_debug_session(
        function(port)
            callback({ type = 'server', host = '127.0.0.1', port = port })
        end)
end

vim.g.mapleader = ' '
vim.api.nvim_exec(
    [[
    nnoremap <silent> <leader>dc :lua require'dap'.continue()<CR>
    nnoremap <silent> <F10> :lua require'dap'.step_over()<CR>
    nnoremap <silent> <F11> :lua require'dap'.step_into()<CR>
    nnoremap <silent> <F12> :lua require'dap'.step_out()<CR>
    nnoremap <silent> <leader>dt :lua require'dap'.toggle_breakpoint()<CR>
    nnoremap <silent> <leader>B :lua require'dap'.set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>
    nnoremap <silent> <leader>lp :lua require'dap'.set_breakpoint(nil, nil, vim.fn.input('Log point message: '))<CR>
    nnoremap <silent> <leader>dr :lua require'dap'.repl.open()<CR>
    nnoremap <silent> <leader>dl :lua require'dap'.run_last()<CR>
    ]], false)
