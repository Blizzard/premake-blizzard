---
-- Battle.net package management extension
-- Copyright (c) 2014-2016 Blizzard Entertainment
---

	bnet = bnet or {}

--
-- Given a source file path, return a corresponding virtual path based on
-- the vpath entries in the project. If no matching vpath entry is found,
-- the original path is returned.
--

	function bnet.getvpath(prj, abspath)
		-- If there is no match, the result is the original filename
		local vpath = abspath

		-- The file's name must be maintained in the resulting path; use these
		-- to make sure I don't cut off too much

		local fname = path.getname(abspath)
		local max = abspath:len() - fname:len()

		-- Look for matching patterns. Virtual paths are stored as an array
		-- for tables, each table continuing the path key, which looks up the
		-- array of paths with should match against that path.

		local function sort_by_length(a, b)
			local lena = string.len(a)
			local lenb = string.len(b)
			if (lena == lenb) then
				return a > b
			end
			return lena > lenb
		end

		-- cache patterns.
		local keys         = prj.cached_vpath_keys
		local vpaths       = prj.cached_vpaths
		local wildcards    = prj.cached_wildcards

		if not vpaths then
			vpaths = {}
			keys = {}
			wildcards = {}

			-- flatten vpaths.
			for _, v in ipairs(prj.vpaths) do
				for replacement, patterns in pairs(v) do
					for _, pattern in ipairs(patterns) do
						vpaths[pattern] = replacement
					end
				end
			end

			-- sort keys by length,  we want the longest most unique vpaths first.
			for pattern, _ in pairs(vpaths) do
				table.insert(keys, pattern)
			end
			table.sort(keys, sort_by_length)

			-- cache wildcard results, path.wildcards is expensive!!!
			for index, pattern in ipairs(keys) do
				wildcards[index] = path.wildcards(pattern)
			end

			-- store result.
			prj.cached_vpath_keys = keys
			prj.cached_vpaths     = vpaths
			prj.cached_wildcards  = wildcards
		end

		-- enumerate vpaths.
		for index, pattern in ipairs(keys) do
			local i = abspath:find(wildcards[index])
			if i == 1 then

				-- Trim out the part of the name that matched the pattern; what's
				-- left is the part that gets appended to the replacement to make
				-- the virtual path. So a pattern like "src/**.h" matching the
				-- file src/include/hello.h, I want to trim out the src/ part,
				-- leaving include/hello.h.

				-- Find out where the wildcard appears in the match. If there is
				-- no wildcard, the match includes the entire pattern

				i = pattern:find("*", 1, true) or (pattern:len() + 1)

				-- Trim, taking care to keep the actual file name intact.

				local leaf
				if i < max then
					leaf = abspath:sub(i)
				else
					leaf = fname
				end

				if leaf:startswith("/") then
					leaf = leaf:sub(2)
				end

				-- check for (and remove) stars in the replacement pattern.
				-- If there are none, then trim all path info from the leaf
				-- and use just the filename in the replacement (stars should
				-- really only appear at the end; I'm cheating here)

				local replacement = vpaths[pattern]

				local stem = ""
				if replacement:len() > 0 then
					stem, stars = replacement:gsub("%*", "")
					if stars == 0 then
						leaf = path.getname(leaf)
					end
				else
					leaf = path.getname(leaf)
				end

				vpath = path.join(stem, leaf)
				return vpath
			end
		end

		return vpath
	end


--
-- register the override.
--
	premake.override(premake.project, "getvpath", function (base, prj, abspath)
		return bnet.getvpath(prj, abspath)
	end)
