---
-- Visual Studio Installer Extention.
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

local p = premake
require ("vstudio")

local vstudio = p.vstudio
local project = p.project

---
-- Add "Installer" kind to visual studio actions.
---
	p.api.addAllowed("kind", {"Installer"})

	for k,v in pairs({ "vs2010", "vs2012", "vs2013", "vs2015", "vs2017" }) do
		local vs = p.action.get(v)
		if vs ~= nil then
			table.insert(vs.valid_kinds, "Installer")
		end
	end

---
-- Add 'isinstaller' method to project namespace.
---

	function project.isinstaller(prj)
		return prj.kind == "Installer"
	end


---
-- Override 'p.vstudio.projectfile'
---

	p.override(vstudio, "projectfile", function(oldfn, prj)
		if project.isinstaller(prj) then
			return p.filename(prj, ".vdproj")
		end
		return oldfn(prj)
	end)


---
-- Override 'p.vstudio.tool'
---

	p.override(vstudio, "tool", function(oldfn, prj)
		if project.isinstaller(prj) then
			return "54435603-DBB4-11D2-8724-00A0C9A8B90C"
		end
		return oldfn(prj)
	end)

