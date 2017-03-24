---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

bnet = bnet or {}

newoption
{
    trigger = 'to',
    default = 'build',
    value   = 'path',
    description = 'Set the output location for the generated files'
}

bnet.build_custom_variant = nil
bnet.build_dir    = path.join(_MAIN_SCRIPT_DIR, _OPTIONS.to or 'build')
bnet.projects_dir = path.join(bnet.build_dir, 'projects')
bnet.bin_dir      = path.join(_MAIN_SCRIPT_DIR, "bin/%{cfg.buildcfg}")
bnet.obj_dir      = path.join(bnet.build_dir, "%{_build_variant(cfg)}/obj")
bnet.lib_dir      = path.join(bnet.build_dir, "%{_build_variant(cfg)}/lib")

verbosef("bnet.build_dir   : %s", bnet.build_dir)
verbosef("bnet.projects_dir: %s", bnet.projects_dir)
verbosef("bnet.obj_dir     : %s", bnet.obj_dir)
verbosef("bnet.lib_dir     : %s", bnet.lib_dir)
verbosef("bnet.bin_dir     : %s", bnet.bin_dir)

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

