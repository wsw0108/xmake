--!A cross-platform build utility based on Lua
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
-- Copyright (C) 2015-present, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        main.lua
--

-- imports
import("core.base.option")
import("core.base.hashset")
import("utils.binary.deplibs", {alias = "get_depend_libraries"})
import("utils.binary.rpath", {alias = "rpath_utils"})

function _get_target_package_libfiles(target, opt)
    if option.get("nopkgs") then
        return {}
    end
    local libfiles = {}
    local bindir = target:is_plat("windows", "mingw") and target:bindir() or target:libdir()
    for _, pkg in ipairs(target:orderpkgs(opt)) do
        if pkg:enabled() and pkg:get("libfiles") then
            for _, libfile in ipairs(table.wrap(pkg:get("libfiles"))) do
                local filename = path.filename(libfile)
                if filename:endswith(".dll") or filename:endswith(".so") or filename:find("%.so%.%d+$") or filename:endswith(".dylib") then
                    table.insert(libfiles, path.joinenv({libfile, bindir}))
                end
            end
        end
    end
    -- we can only reserve used libraries
    if target:is_binary() or target:is_shared() then
        local depends = hashset.new()
        local targetfile = target:targetfile()
        local depend_libraries = get_depend_libraries(targetfile, {plat = target:plat(), arch = target:arch()})
        for _, libfile in ipairs(depend_libraries) do
            depends:insert(path.filename(libfile))
        end
        table.remove_if(libfiles, function (_, libfile)
            libfile = path.splitenv(libfile)[1]
            return not depends:has(path.filename(libfile))
        end)
    end
    return libfiles
end

-- copy file with symlinks
function _copy_file_with_symlinks(srcfile, outputdir)
    if os.islink(srcfile) then
        local srcfile_symlink = os.readlink(srcfile)
        if not path.is_absolute(srcfile_symlink) then
            srcfile_symlink = path.join(path.directory(srcfile), srcfile_symlink)
        end
        _copy_file_with_symlinks(srcfile_symlink, outputdir)
        os.vcp(srcfile, path.join(outputdir, path.filename(srcfile)), {symlink = true, force = true})
    else
        os.vcp(srcfile, path.join(outputdir, path.filename(srcfile)))
    end
end

-- install files
function _install_files(target)
    local srcfiles, dstfiles = target:installfiles()
    if srcfiles and dstfiles then
        for idx, srcfile in ipairs(srcfiles) do
            os.vcp(srcfile, dstfiles[idx])
        end
    end
    for _, dep in ipairs(target:orderdeps()) do
        local srcfiles, dstfiles = dep:installfiles(dep:installdir(), {interface = true})
        if srcfiles and dstfiles then
            for idx, srcfile in ipairs(srcfiles) do
                os.vcp(srcfile, dstfiles[idx])
            end
        end
    end
end

-- install headers
function _install_headers(target, opt)
    local srcheaders, dstheaders = target:headerfiles(target:includedir(), {installonly = true})
    if srcheaders and dstheaders then
        for idx, srcheader in ipairs(srcheaders) do
            os.vcp(srcheader, dstheaders[idx])
        end
    end
    for _, dep in ipairs(target:orderdeps()) do
        local srcfiles, dstfiles = dep:headerfiles(dep:includedir(), {installonly = true, interface = true})
        if srcfiles and dstfiles then
            for idx, srcfile in ipairs(srcfiles) do
                os.vcp(srcfile, dstfiles[idx])
            end
        end
    end
end

-- install shared libraries
function _install_shared_libraries(target, opt)

    -- get all dependent shared libraries
    local libfiles = {}
    for _, dep in ipairs(target:orderdeps()) do
        local bindir = dep:is_plat("windows", "mingw") and dep:bindir() or dep:libdir()
        if dep:kind() == "shared" then
            local depfile = dep:targetfile()
            if os.isfile(depfile) then
                table.insert(libfiles, path.joinenv({depfile, bindir}))
            end
        end
        table.join2(libfiles, _get_target_package_libfiles(dep, {interface = true}))
    end
    table.join2(libfiles, _get_target_package_libfiles(target))

    -- deduplicate libfiles, prevent packages using the same libfiles from overwriting each other
    libfiles = table.unique(libfiles)

    -- do install
    for _, libfile in ipairs(libfiles) do
        local splitinfo = path.splitenv(libfile)
        libfile = splitinfo[1]
        local bindir = splitinfo[2]
        assert(libfile and bindir)
        local filename = path.filename(libfile)
        local filepath = path.join(bindir, filename)
        if os.isfile(filepath) and hash.sha256(filepath) ~= hash.sha256(libfile) then
            wprint("'%s' already exists in install dir, we are copying '%s' to overwrite it.", filepath, libfile)
        end
        _copy_file_with_symlinks(libfile, bindir)
    end
end

-- update install rpath, we can only get and update rpathdirs with `{installonly = true}`
-- e.g. add_rpathdirs("@loader_path/../lib", {installonly = true})
function _update_install_rpath(target, opt)
    if target:is_plat("windows", "mingw") then
        return
    end
    local bindir = target:bindir()
    local targetfile = path.join(bindir, target:filename())
    if target:policy("install.rpath") then
        rpath_utils.clean(targetfile, {plat = target:plat(), arch = target:arch()})
        local result, sources = target:get_from("rpathdirs", "*")
        if result and sources then
            for idx, rpathdirs in ipairs(result) do
                local source = sources[idx]
                local extraconf = target:extraconf_from("rpathdirs", source)
                if extraconf then
                    for _, rpathdir in ipairs(rpathdirs) do
                        local extra = extraconf[rpathdir]
                        if extra and extra.installonly then
                            rpath_utils.insert(targetfile, rpathdir, {plat = target:plat(), arch = target:arch()})
                        end
                    end
                end
            end
        end
    end
end

-- install binary
function _install_binary(target, opt)
    local bindir = target:bindir()
    os.mkdir(bindir)
    os.vcp(target:targetfile(), bindir)
    os.trycp(target:symbolfile(), path.join(bindir, path.filename(target:symbolfile())))
    _install_shared_libraries(target, opt)
    _update_install_rpath(target, opt)
end

-- install shared library
function _install_shared(target, opt)
    local bindir = target:is_plat("windows", "mingw") and target:bindir() or target:libdir()
    os.mkdir(bindir)
    local targetfile = target:targetfile()

    if target:is_plat("windows", "mingw") then
        -- install *.lib for shared/windows (*.dll) target
        -- @see https://github.com/xmake-io/xmake/issues/714
        os.vcp(target:targetfile(), bindir)
        local libdir = target:libdir()
        local targetfile_lib = path.join(path.directory(targetfile), path.basename(targetfile) .. (target:is_plat("mingw") and ".dll.a" or ".lib"))
        if os.isfile(targetfile_lib) then
            os.mkdir(libdir)
            os.vcp(targetfile_lib, libdir)
        end
    else
        -- install target with soname and symlink
        _copy_file_with_symlinks(targetfile, bindir)
    end
    os.trycp(target:symbolfile(), path.join(bindir, path.filename(target:symbolfile())))

    _install_headers(target, opt)
    _install_shared_libraries(target, opt)
end

-- install static library
function _install_static(target, opt)
    local libdir = target:libdir()
    os.mkdir(libdir)
    os.vcp(target:targetfile(), libdir)
    os.trycp(target:symbolfile(), path.join(libdir, path.filename(target:symbolfile())))
    _install_headers(target, opt)
end

-- install headeronly library
function _install_headeronly(target, opt)
    _install_headers(target, opt)
end

-- install moduleonly library
function _install_moduleonly(target, opt)
    _install_headers(target, opt)
end

function main(target, opt)
    local installdir = target:installdir()
    if not installdir then
        wprint("please use `xmake install -o installdir` or `set_installdir` to set install directory.")
        return
    end
    print("installing %s to %s ..", target:name(), installdir)

    if target:is_binary() then
        _install_binary(target, opt)
    elseif target:is_shared() then
        _install_shared(target, opt)
    elseif target:is_static() then
        _install_static(target, opt)
    elseif target:is_headeronly() then
        _install_headeronly(target, opt)
    elseif target:is_moduleonly() then
        _install_moduleonly(target, opt)
    end

    _install_files(target)
end
