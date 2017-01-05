--!The Make-like Build Utility based on Lua
-- 
-- XMake is free software; you can redistribute it and/or modify
-- it under the terms of the GNU Lesser General Public License as published by
-- the Free Software Foundation; either version 2.1 of the License, or
-- (at your option) any later version.
-- 
-- XMake is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU Lesser General Public License for more details.
-- 
-- You should have received a copy of the GNU Lesser General Public License
-- along with XMake; 
-- If not, see <a href="http://www.gnu.org/licenses/"> http://www.gnu.org/licenses/</a>
-- 
-- Copyright (C) 2015 - 2016, ruki All rights reserved.
--
-- @author      ruki
-- @file        xmake.lua
--

-- define platform
platform("macosx")

    -- set os
    set_os("macosx")

    -- set hosts
    set_hosts("macosx")

    -- set archs
    set_archs("i386", "x86_64")

    -- set tooldirs
    set_tooldirs("/usr/bin", "/usr/local/bin", "/opt/bin", "/opt/local/bin")

    -- on check
    on_check("check")

    -- on install
    on_install("install")

    -- on uninstall
    on_uninstall("uninstall")

    -- on load
    on_load("load")

    -- set menu
    set_menu({
                config = 
                {   
                    {}   
                ,   {nil, "mm",             "kv", nil,          "the objc compiler"                 }
                ,   {nil, "mxx",            "kv", nil,          "the objc++ compiler"               }
                ,   {nil, "mflags",         "kv", nil,          "the objc compiler flags"           }
                ,   {nil, "mxflags",        "kv", nil,          "the objc/c++ compiler flags"       }
                ,   {nil, "mxxflags",       "kv", nil,          "the objc++ compiler flags"         }
                ,   {}
                ,   {nil, "xcode_dir",      "kv", "auto",       "the xcode application directory"   }
                ,   {nil, "xcode_sdkver",   "kv", "auto",       "the sdk version for xcode"         }
                ,   {nil, "target_minver",  "kv", "auto",       "the target minimal version"        }
                }

            ,   global = 
                {   
                    {}
                ,   {nil, "xcode_dir",      "kv", "auto",       "the xcode application directory"   }
                }
            })






