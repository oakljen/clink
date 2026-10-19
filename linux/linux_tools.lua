-- License: http://opensource.org/licenses/MIT

--------------------------------------------------------------------------------
-- Makes the Linux tools that ship with Git for Windows (ls, cat, grep, rm,
-- touch, which, head, tail, etc) available in CMD by appending Git's usr\bin
-- directory to PATH.
--
-- The directory is appended (not prepended) so that Windows programs with the
-- same name (find, sort, etc) and CMD's internal commands (dir, echo, mkdir,
-- etc) keep working in batch scripts and pipes.  Doskey aliases make the Linux
-- versions of find, sort, and mkdir run when typed at the start of a command.

--------------------------------------------------------------------------------
settings.add("linux.enable", true, "Add Linux tools to PATH",
    "When enabled, the Linux tools from Git for Windows (ls, cat, grep, rm,\n"..
    "touch, which, etc) are appended to PATH so they can be used in CMD.\n"..
    "Run 'clink-reload' (Ctrl-X,Ctrl-R) after changing this setting.")

settings.add("linux.tools_dir", "", "Directory containing Linux tools",
    "The directory containing the Linux tools, such as\n"..
    "C:\\Program Files\\Git\\usr\\bin.  When empty, the directory is found\n"..
    "automatically from the Git for Windows installation.")

settings.add("linux.aliases", true, "Alias find, sort, mkdir to Linux",
    "When enabled, doskey aliases make find, sort, and mkdir run the Linux\n"..
    "versions instead of the Windows versions when typed at the start of a\n"..
    "command.  Pipes and batch scripts still use the Windows versions.\n"..
    "Run 'clink-reload' (Ctrl-X,Ctrl-R) after changing this setting.")

local alias_names = { "find", "sort", "mkdir" }

--------------------------------------------------------------------------------
local function split_path(value)
    local dirs = {}
    for dir in (value or ""):gmatch("[^;]+") do
        table.insert(dirs, dir)
    end
    return dirs
end

--------------------------------------------------------------------------------
local function same_dir(a, b)
    a = clink.lower(a):gsub("[\\/]+$", "")
    b = clink.lower(b):gsub("[\\/]+$", "")
    return a == b
end

--------------------------------------------------------------------------------
local function find_tools_dir()
    local dir = settings.get("linux.tools_dir")
    if dir and dir ~= "" then
        return os.isdir(dir) and dir or nil
    end

    -- Look for Git in its usual install locations.
    local candidates = {}
    for _, root in ipairs({ "ProgramW6432", "ProgramFiles", "LOCALAPPDATA" }) do
        local value = os.getenv(root)
        if value then
            if root == "LOCALAPPDATA" then
                value = path.join(value, "Programs")
            end
            table.insert(candidates, path.join(value, "Git\\usr\\bin"))
        end
    end

    -- Look for git.exe in PATH, which is in Git\cmd or Git\mingw64\bin.
    for _, entry in ipairs(split_path(os.getenv("PATH"))) do
        if os.isfile(path.join(entry, "git.exe")) then
            local root = path.toparent(entry)
            if clink.lower(path.getname(root)) == "mingw64" then
                root = path.toparent(root)
            end
            table.insert(candidates, path.join(root, "usr\\bin"))
        end
    end

    for _, candidate in ipairs(candidates) do
        if os.isfile(path.join(candidate, "ls.exe")) then
            return candidate
        end
    end
end

--------------------------------------------------------------------------------
local function update_path()
    local tools_dir = find_tools_dir()
    if not tools_dir then
        return
    end

    -- Remove the directory first, so that reloading after changing the
    -- linux.enable setting adds or removes it as appropriate.
    local dirs = {}
    for _, entry in ipairs(split_path(os.getenv("PATH"))) do
        if not same_dir(entry, tools_dir) then
            table.insert(dirs, entry)
        end
    end

    if settings.get("linux.enable") then
        table.insert(dirs, tools_dir)
    end

    os.setenv("PATH", table.concat(dirs, ";"))

    -- Only remove aliases this script created, so user-defined aliases with
    -- the same names are left alone.
    local want_aliases = settings.get("linux.enable") and settings.get("linux.aliases")
    for _, name in ipairs(alias_names) do
        local command = '"'..path.join(tools_dir, name..".exe")..'" $*'
        if want_aliases then
            if not os.getalias(name) then
                os.setalias(name, command)
            end
        elseif os.getalias(name) == command then
            os.setalias(name, "")
        end
    end
end

update_path()
