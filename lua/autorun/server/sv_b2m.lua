/*
    b2m server lua

    coded by smokingplaya<3
        thx dj smokey for nuke radio
*/

if not b2m then
    require("b2m")

    if not b2m then
        return print("B2M wasn't loaded!")
    end
end

local ip

// it's horrible
// facepunch, i'am wait for u fix it -----> https://github.com/Facepunch/garrysmod-issues/issues/3001
if SERVER then
    local old_value = GetConVar("sv_hibernate_think"):GetInt()

    RunConsoleCommand("sv_hibernate_think", 1)

    local function check_ip()
        local ip_ = game.GetIPAddress()

        if ip_:find("0.0.0.0") then
            return
        end

        ip = ip_
    end

    // do u now why its horrible?
    // cause players can join to server when server doesn't know self ip lol
    // => players can't check packages

    local timer_name = "b2m_ip"
    timer.Create(timer_name, 0.1, 0, function()
        check_ip()

        if ip == nil then
            return
        end

        b2m.Print("Setup server packages")

        b2m:UpdatePackages()

        RunConsoleCommand("sv_hibernate_think", old_value)

        timer.Remove(timer_name)
    end)
end

if MENU_DLL then
    require("b2mmenu")
end

local baseUrl = "https://autumngmod.ru/b2m/"

/*
    better requiring
    requiring only for binary modules
*/

local modules_enabled = CreateConVar("b2m_binaryenabled", 1, FCVAR_NONE, "Can binary modules be loaded?", 0, 1)

function b2m.Require(module_name)
    if not modules_enabled:GetBool() then
        return false
    end

    if not util.IsBinaryModuleInstalled(module_name) then
        b2m.Print("Module \"" .. (module_name or "N/A") .. "\" not found.")
        return false
    end

    require(module_name)

    return true
end

function b2m:UpdatePackages()
    http.Post(baseUrl .. "api/packages/updateServer", {serverIP = ip, packages = b2m.DB:GetClientPackagesTableJSON()})
end

/* using sqlite like a local storage */

function b2m.DB:Initialize()
    if not sql.TableExists("b2m_pkgs") then
        sql.Query("CREATE TABLE IF NOT EXISTS b2m_pkgs(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, version TEXT, clientonly INT, serveronly INT)")
    end
end

b2m.DB:Initialize()

function b2m.DB:GetPackages()
    local data = sql.Query("SELECT * FROM b2m_pkgs")

    return data and data or {}
end

function b2m.DB:GetPackagesTable()
    local packages = {}

    local pkgs = b2m.DB:GetPackages()

    for _, v in ipairs(pkgs) do
        packages[v.name] = v.version
    end

    return packages
end

function b2m.DB:GetPackagesTableJSON()
    return util.TableToJSON(self:GetPackagesTable())
end

function b2m.DB:GetClientPackagesTable()
    local pkgs = self:GetPackages()

    local res = {}

    for k, v in ipairs(pkgs) do
        local iscl = tonumber(v.clientonly) == 1
        local issv = tonumber(v.serveronly) == 1

        if (iscl and not issv) || not iscl and not issv then
            res[v.name] = v.version
        end
    end

    return res
end

function b2m.DB:GetClientPackagesTableJSON()
    return util.TableToJSON(self:GetClientPackagesTable())
end

function b2m.DB:Add(name, version, tab)
    local res = sql.Query("SELECT id FROM b2m_pkgs WHERE name=\"" .. name .. "\"")

    if istable(res) and #res > 0 then
        local q = "UPDATE b2m_pkgs SET version=\"%s\",clientonly=\"%s\",serveronly=\"%s\" WHERE name=\"%s\""
        sql.Query(q:format(version, tab.client and 1 or 0, tab.server and 1 or 0, name))

        return
    end

    local q = "INSERT INTO b2m_pkgs(name, version, clientonly, serveronly) VALUES(\"%s\",\"%s\",\"%s\",\"%s\")"
    sql.Query(q:format(name, version, tab.client and 1 or 0, tab.server and 1 or 0))
end

function b2m.DB:Remove(name)
    local res = sql.Query("SELECT id FROM b2m_pkgs WHERE name=\"" .. name .. "\"")

    if istable(res) and #res > 0 then
        sql.Query("DELETE FROM b2m_pkgs WHERE name=\"" .. name .. "\"")

        return
    end
end

function b2m.DB:HasPackage(pkg)
    local result = false

    local pkgs = self:GetPackages()
    for _, tab in ipairs(pkgs) do
        if tab.name != pkg then
            continue
        end

        result = true
        break
    end

    return result
end

/*
    yeah, you can use

    b2m.OnServerConnect = b2m.CheckPackages

    but here i can add something later
*/

if MENU_DLL then
    function b2m:OnServerConnect(ip)
        b2m.CheckPackages(ip)
    end

    gameevent.Listen("client_beginconnect")
    hook.Add( "client_beginconnect", "client_beginconnect_example", function( data )
        b2m:OnServerConnect(data.address || "")
    end)
end

// package manager

local commands
commands = {
    install = {
        call = function(args, flags)
            local pkg = args[1]
            local version = args[2]

            local ver = b2m.CheckModule(pkg, version || "*", flags["--client-only"] or false)

            if ver then
                b2m.DB:Add(pkg, ver, {client = flags["--client-only"], server = flags["--server-only"]})
                b2m.Print("Module " .. pkg .. " has been installed successfully!")
            end

            b2m:UpdatePackages()
        end,

        args = {
            "name",
            "version"
        },

        flags = {
            ["--client-only"] = "Installs the binary module only on the client.",
            ["--server-only"] = "Installs the binary module only on the server."
        },

        desc = "Installs the binary module on the server."
    },

    remove = {
        call = function(args)
            local pkg = args[1]

            -- TODO: добавить логику для удаления DLL файла

            local fix = commands.fix

            if not fix then
                return
            end

            if not b2m.DB:HasPackage(pkg) then
                return b2m.Print("Package " .. pkg .. " doesn't found!")
            end

            b2m.Remove(pkg, true)
            b2m.Remove(pkg, false)
            b2m.DB:Remove(pkg)
            fix.call()
            b2m:UpdatePackages()

            b2m.Print("Removed package " .. pkg)
        end,

        args = {
            "name"
        },

        flags = {},

        desc = "Removes the binary module."
    },

    // чинит порядок списка пакетов в базе данных
    fix = {
        call = function()
            local db_cells = b2m.DB:GetPackages() //sql.Query("SELECT * FROM b2m_pkgs")

            if not db_cells then
                b2m.DB:Initialize()

                return
            end

            // используем не ipairs потому-что при b2m remove id удаляется, и по итогу порядок может быть прерван
            local id = 1
            for _, cell in pairs(db_cells) do
                if cell.id == id then
                    return
                end

                sql.Query("UPDATE b2m_pkgs SET id=\"" .. id .. "\" WHERE name=\"" .. cell.name .. "\"")

                id = id + 1

                continue
            end

            sql.Query("UPDATE sqlite_sequence SET seq=\"" .. (id-1) .. "\" WHERE name=\"b2m_pkgs\"")
        end,

        flags = {},

        desc = "Fixes the order of the modules in the database."
    },

    list = {
        call = function()
            local pkgs = b2m.DB:GetPackages()

            b2m.Print("Package list")

            for k, v in ipairs(pkgs) do
                local iscl = tonumber(v.clientonly) == 1
                local issv = tonumber(v.serveronly) == 1
                local side = (iscl and not issv and "(CLIENT)") or (not iscl and issv and "(SERVER)") or "(SHARED)"
                b2m.Print("\t" .. k .. ": " .. v.name .. " " .. v.version .. " " .. side) // TODO
            end
        end,

        flags = {},

        desc = "Prints a list of installed modules."
    },

    help = {
        call = function()
            b2m.Print("Available commands:")

            for k, v in pairs(commands) do
                b2m.Print("\t" .. k .. " - " .. (v.desc or "No description is given"))

                if not v.flags or table.IsEmpty(v.flags) then
                    continue
                end

                b2m.Print("\t\tCommand flags:")
                for k, v in pairs(v.flags) do
                    b2m.Print("\t\t\t" .. k .. " - " .. (v or "No description is given"))
                end

                print()
            end
        end,

        flags = {},

        desc = "Prints a list of available commands with their flags."
    }
}

concommand.Add("b2m", function(pl, _, args)
    if SERVER and IsValid(pl) then
        return
    end

    local sub_command = args[1]

    if not sub_command then
        b2m.Print("B2M " .. (b2m.Version || "N/A version") .. " by autumncommunity <3")

        commands.help.call()

        return
    end

    local sub_command_tab = commands[sub_command]

    if not sub_command_tab then
        b2m.Print("Unknown command. Type b2m help for help.")

        return
    end

    table.remove(args, 1) // remove command from args

    local flags = table.Copy(args)
    local argc = sub_command_tab.args and #sub_command_tab.args or 0

    if #args < argc then
        b2m.Print("You haven't stated all the arguments")

        return
    end

    // тут идёт перебор с конца
    // потому-что table.remove сдвигает элемент

    for i = argc, 1, -1 do
        table.remove(flags, i)
    end

    for k, v in ipairs(flags) do
        if not sub_command_tab.flags[v] then
            b2m.Print("Flag \"" .. v .. "\" doesn't exist in this command!")

            return
        end

        flags[v] = true
        flags[k] = nil
    end

    sub_command_tab.call(args, flags)
end, function(_, args)
    local res = {}

    args = args:lower():Trim()

    for k, v in pairs(commands) do
        if args[k] then
            res[#res+1] = k
        end
    end

    return res
end)
