---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

bnet = bnet or {}

bnet.build_custom_variant = nil
bnet.build_dir    = path.join(_MAIN_SCRIPT_DIR, _OPTIONS["to"])
bnet.bin_dir      = path.join(_MAIN_SCRIPT_DIR, "bin/%{cfg.buildcfg}")
bnet.obj_dir      = "%{bnet.build_dir}/%{_build_variant(cfg)}/obj"
bnet.lib_dir      = "%{bnet.build_dir}/%{_build_variant(cfg)}/lib"
bnet.projects_dir = "%{bnet.build_dir}/projects"

verbosef("bnet.build_dir   : %s", bnet.build_dir)
verbosef("bnet.obj_dir     : %s", bnet.obj_dir)
verbosef("bnet.lib_dir     : %s", bnet.lib_dir)
verbosef("bnet.bin_dir     : %s", bnet.bin_dir)
verbosef("bnet.projects_dir: %s", bnet.projects_dir)


function bnet.new()
	return {
		variant = _build_variant
	}
end

premake.override(premake.context, "new", function (base, cfgset, environ)
	local ctx = base(cfgset, environ)
	ctx.bnet = bnet.new()
	return ctx
end)

-- spyware...
-- premake.override(premake.main, "postAction", function (base)
-- 	if http and not _OPTIONS['no-http'] then
-- 		local user = "UNKNOWN"
-- 		if os.get() == "windows" then
-- 			user = os.getenv("USERNAME") or user
-- 		else
-- 			user = os.getenv("LOGNAME") or user
-- 		end
--
-- 		local duration = (os.clock() - _PREMAKE_STARTTIME) * 1000;
--
-- 		local file = "spy?app=premake&version=" .. escape_url_param(_PREMAKE_VERSION)
-- 		http.get('http://***REMOVED***/' .. file,
-- 		{
-- 			headers = {
-- 				"X-Premake-User: "     .. user,
-- 				"X-Premake-Platform: " .. _OS,
-- 				"X-Premake-WorkDir: "  .. _WORKING_DIR,
-- 				"X-Premake-Time: "     .. duration,
-- 				"X-Premake-CmdLine: "  .. table.concat(_ARGV, ' '),
-- 			}
-- 		})
-- 	end
--
-- 	base()
-- end)

