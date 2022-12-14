
local dl = {}

function dl.shuffle (tbl)

	local aux, n = {}, #tbl

	while n > 0 do
		local v = table.remove (tbl, math.random (n))
		aux[n] = v
		n = n - 1
	end

	assert (#tbl == 0)

	for i, v in pairs (aux) do
		tbl[i] = v
	end
end

function dl.random_string ()
	local s = os.tmpname ()
	local i = string.find (s, '_', 1, true)
	return string.sub (s, i + 1)
end

local function disconnect (q, rel, irel) 
	local u, d = rel[q], irel[q]
	rel[d], irel[u] = u, d
end

local function connect (q, rel, irel) 
	local u, d = rel[q], irel[q]
	irel[u], rel[d] = q, q
end

local function monus (x, y) return math.max (x - y, 0) end

local nocolor, handledcolor, noop = {}, {}, function () end	-- just witnesses.

local function loop (start, toward, f, inclusive)

	if inclusive then
		local each = start
		repeat f (each); each = toward[each] until each == start
	else
		local each = toward[start]
		while each ~= start do f (each); each = toward[each] end
	end
end

function dl.solver (P, expand_multiplicities)

	local obase = dl.indexed (dl.random_string ())

	local llink, rlink, ulink, dlink, len, top, option, color, slack, bound, multiplicities = 
		{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}

	local primary_header = {}

	local primarysize, secondarysize = 0, 0		-- items counts.
	local primary_str, secondary_str = {}, {}

	local function addprimary (last_primary_item, mitem)

		len[mitem] = 0

		ulink[mitem], dlink[mitem] = mitem, mitem	-- self loops on the vertical dimension.
		llink[mitem], rlink[last_primary_item] = last_primary_item, mitem	-- link among the horizontal dimension.

		primarysize = primarysize + 1

		table.insert (primary_str, mitem)

		return mitem
	end

	local function addsecondary (mitem)

		len[mitem] = 0

		ulink[mitem], dlink[mitem] = mitem, mitem
		llink[mitem], rlink[mitem] = mitem, mitem

		secondarysize = secondarysize + 1

		table.insert (secondary_str, mitem)

		return mitem
	end

	local last_primary_item = primary_header	-- cursor variable for primary items.

	for item, descriptor in pairs(P.items) do	-- link primary items

		if descriptor.isprimary then


			local u, v = descriptor.atleast or 1, descriptor.atmost or 1; assert (u >= 0 and v > 0 and v >= u)

			if expand_multiplicities and v > 1 then
				
				local mul = {}

				for i = 1, u do
					local mitem = obase { item, i }		-- link `mitem` as a primary item.

					mul[i] = mitem
					slack[mitem], bound[mitem] = 0, 1

					last_primary_item = addprimary (last_primary_item, mitem)
				end

				for i = u + 1, v do
					local mitem = obase { item, i }		-- link `mitem` as a secondary item.

					mul[i] = mitem

					addsecondary (mitem)
				end

				multiplicities[item] = mul

			else 
				slack[item], bound[item] = v - u, v
				last_primary_item = addprimary (last_primary_item, item) 
			end
		else addsecondary (item) end
	end

	rlink[last_primary_item], llink[primary_header] = primary_header, last_primary_item	-- closing the doubly circular list.
	last_primary_item = nil

	local localoptions = {}

	for iopt, opt in ipairs(P.options) do

		local localopt = { {} }	-- the initial state for the cartesian product.

		for id, decoration in pairs(opt) do

			if type (id) == 'number' then id, decoration = decoration, {} end

			local mul = multiplicities[id]

			if mul then 
				
				-- <3

				local newlocalopt = {}

				for _, o in ipairs (localopt) do

					for _, m in ipairs (mul) do
						local newo = {}
						for k, v in pairs (o) do newo[k] = v end	-- copy the table.
						newo[m] = decoration
						table.insert (newlocalopt, newo)
					end
				end

				localopt = newlocalopt

			else for _, o in ipairs (localopt) do o[id] = decoration end end
		end

		if #localopt > 1 then

			local item = obase { iopt, dl.random_string () }

			addsecondary (item)

			local decoration = {}	
			
			for _, o in ipairs (localopt) do o[item] = decoration end
		end

		localoptions[{index = iopt}] = localopt		-- using a table as a key is a kind of randomization.
	end

	local optionssize, options_str = 0, {}

	for key, mopt in pairs(localoptions) do

		local iopt = key.index

		for _, opt in ipairs (mopt) do

			optionssize = optionssize + 1

			local header = {}
			local last = header

			local opt_str = {}

			for o, decoration in pairs(opt) do
			
				len[o] = len[o] + 1

				local point = {}	-- every single 1 in the model matrix.

				top[point], option[point], color[point] = o, iopt, decoration.color or nocolor

				local s = o
				if color[point] ~= nocolor then s = s .. ':' .. color[point] end
				table.insert (opt_str, s)

				local q = ulink[o]
				ulink[point], ulink[o] = q, point
				dlink[point], dlink[q] = o, point

				llink[point], rlink[last] = last, point
				last = point
			end

			table.insert (options_str, table.concat (opt_str, ' '))

			assert (not llink[header])
			local first = rlink[header]
			rlink[header] = nil
			rlink[last], llink[first]  = first, last
		end
	end

	local items_str = table.concat (primary_str, ' ') .. ' | ' .. table.concat (secondary_str, ' ')
	dl.shuffle (options_str)
	options_str = table.concat (options_str, '\n')
	local f = io.open ('partridge-8-xcc.dlx', 'w+')
	f:write (items_str, '\n', options_str, '\n')
	f:close ()

	P.primarysize, P.secondarysize, P.optionssize = primarysize, secondarysize, optionssize	-- update the given problem, in place.

	-- HELPERS  ------------------------------------------------------------------

	local function iscovered () return rlink[primary_header] == primary_header end

	local function isnode (i) return option[i] ~= nil end

	local function itemof (i) if isnode (i) then return top[i] else return i end end

	local function branch (each) return monus (len[each] + 1, monus (bound[each], slack[each])) end
		
	local function nextitem_naive () 
		local item = rlink[primary_header]
		return item, branch (item)
	end

	local function nextitem_randomized () 

		local min, pool = math.huge, nil

		loop (primary_header, rlink, function (each) 

			local l = len[each]
			if l < min then min, pool = l, {each} 
			elseif l == min then table.insert (pool, each) end
		end)

		assert (#pool > 0)	-- ensure we've found something.

		return pool[math.random (#pool)], min
	end

	local function nextitem_minlen () 

		local min, item = math.huge, nil

		loop (primary_header, rlink, function (each) 

			local lambda = branch (each)

			local es = slack[each]

			if (lambda < min) 
			   or (lambda == min and es < slack[item]) 
			   or (lambda == min and es == slack[item] and len[each] > len[item])
				then min, item = lambda, each end
		end)

		assert (item)	-- ensure we've found something.

		return item, min
	end


	local function nextitem_knuth ()

		local score, best_s, best_l = math.huge, math.huge, -1
		local pool = {}

		loop (primary_header, rlink, function (item) 
			local s, b, l = slack[item], bound[item], len[item]
			if s > b then s = b end
			local t = l + s - b + 1
			if t <= score then
				if t < score or s < best_s or (s == best_s and l > best_l) then
					score = t
					pool = {item}
					best_s = s
					best_l = l
				elseif s == best_s and l == best_l then table.insert (pool, item) end
			end
		end)

		local best_i
		local l = #pool
		if l > 0 then best_i = pool[math.random(l)] end

		return best_i, score
	end

	local function connectv (q) 
		local itm = top[q]; len[itm] = len[itm] + 1
		return connect (q, ulink, dlink) 
	end

	local function disconnectv (q) 
		local itm = top[q]; len[itm] = len[itm] - 1
		return disconnect (q, ulink, dlink) 
	end

	local function connecth (q) return connect (q, llink, rlink) end
	local function disconnecth (q) return disconnect (q, llink, rlink) end

	-- COVERING ------------------------------------------------------------------

	local function H (q) 
		local c = color[q]; assert (c)
		if c ~= handledcolor then return disconnectv (q) end end

	local function hide (p) return loop (p, rlink, H) end

	local function purify (p, c)

		local function P (q) 
			local r = color[q]; assert (r)
			if r == c then color[q] = handledcolor 
			elseif q ~= p then hide (q) end 
		end

		return loop (top[p], dlink, P)
	end

	local function cover (i)
		disconnecth (i)
		loop(i, dlink, hide)
	end

	local function commit (i, p)
		local c = color[p]
		if c == nocolor then return cover (i) 
		elseif c ~= handledcolor then return purify (p, c) end
	end

	local function covertop (p) return cover (top[p]) end

	local function covertopc (p) return commit (top[p], p) end

	local function covertopm (p)
		local item = top[p]
		local b = bound[item] 
		if b then 
			b = b - 1
			bound[item] = b
			if b == 0 then return cover (item) end 
		else return commit (item, p) end
	end

	local function coverk (c, deact)

		if deact then disconnecth (c) end

		--loop (c, dlink, function (rr) loop (rr, rlink, H) end)
		loop (c, dlink, hide)
	end

	local function purifyk (p)

		local cc, x = top[p], color[p]; assert(x)
		-- color[cc] = x
		
		loop (cc, dlink, function (rr)

			--if color[rr] ~= x then loop (rr, rlink, H)
			if color[rr] ~= x then hide (rr)
			elseif rr ~= p then color[rr] = handledcolor end
		end)
	end

	-- UNCOVERING ----------------------------------------------------------------

	local function U (q) 
		local c = color[q]; assert (c)
		if c ~= handledcolor then return connectv (q) end 
	end

	local function unhide (p) return loop(p, llink, U) end

	local function unpurify (p, c)

		local function UP (q) 
			local r = color[q]; assert (r)
			if r == handledcolor then color[q] = c 
			elseif q ~= p then unhide (q) end 
		end

		return loop (top[p], ulink, UP)
	end

	local function uncover (i)

		connecth (i)
		return loop(i, ulink, unhide)	
	end

	local function uncommit (i, p)
		local c = color[p]
		if c == nocolor then return uncover (i) 
		elseif c ~= handledcolor then return unpurify (p, c) end
	end

	local function uncovertop (p) return uncover (top[p]) end

	local function uncovertopc (p) return uncommit (top[p], p) end

	local function uncovertopm (p) 
		local item = top[p]
		local b = bound[item] 
		if b then 
			b = b + 1
			bound[item] = b
			if b == 1 then return uncover (item) end
		else return uncommit (item, p) end
	end

	local function uncoverk (c, react)

		loop (c, dlink, function (rr) loop (rr, rlink, U) end)

		if react then connecth (c) end
	end

	local function unpurifyk (p)

		local cc, x = top[p], color[p]; assert (x)

		loop (cc, ulink, function (rr)
			if color[rr] == handledcolor then color[rr] = x
			elseif rr ~= p then loop (rr, llink, U) end
		end)
	end

	-- TWEAKING ------------------------------------------------------------------
	
	local function tweakw (p, x)
		assert (x == dlink[p] and p == ulink[x])
		local d = dlink[x]
		dlink[p], ulink[d] = d, p
		len[p] = len[p] - 1
	end

	local function tweakh (p, x)
		hide (x)
		return tweakw (p, x)
	end

	local function tweak (p, x)
		if bound[p] == 0 then return tweakw (p, x) else return tweakh (p, x) end
	end

	local function tweakk (n, block)

		local nn if block then nn = rlink[n] else nn = n end

		while true do
			
			H (nn)
			if nn == n then break else nn = rlink[nn] end
		end
	end

	-- UNTWEAKING ------------------------------------------------------------------
	
	local function untweakf (a, f)

		local k = 0

		local p
		if bound[a] then p = a else p = top[a] end
		local x, y = a, p
		local z = dlink[p]

		dlink[p] = x

		while x ~= z do
			ulink[x] = y
			k = k + 1
			f (x)
			y = x
			x = dlink[x]
		end

		ulink[z] = y
		len[p] = len[p] + k

		return p
	end

	local function untweakh (a) return untweakf (a, unhide) end
	local function untweakw (a) return uncover (untweakf (a, noop)) end
	local function untweak (a)
		local item = top[a]
		if bound[item] == 0 then return untweakw (a) else return untweakh (a) end 
	end

	local function untweakk (c, x, unblock)

		local z = dlink[c]
		dlink[c] = x
		local rr, k, qq = x, 0, c

		while rr ~= z do
			
			ulink[rr] = qq
			k = k + 1

			if unblock then loop (rr, rlink, U) end
			
			qq = rr
			rr = dlink[rr]

		end

		ulink[rr] = qq
		len[c] = len[c] + k

		if not unblock then uncoverk (c, false) end
	end

	------------------------------------------------------------------------------

	local function R (l, opt, C, U, memo)

		if iscovered () then 

			local perm = {}
			while opt do
				perm[opt.level] = opt.index
				opt = opt.nextoption
			end

			table.sort(perm)

			local digest = table.concat (perm, ' ')
			if not memo[digest] then 
				memo[digest] = perm 
				coroutine.yield (perm)
			end
		else
			local item = nextitem_randomized ()

			cover (item)

			loop (item, dlink, function (ref)

				loop (ref, rlink, C) 

				R (l + 1, { 
					level = l,
					point = ref,
					index = option[ref],
					nextoption = opt,
				}, C, U, memo)

				loop (ref, llink, U)
			
			end)
			
			uncover (item)
		end
	end
	
	local function XC (l, opt) R (l, opt, covertop, uncovertop, {}) end 	-- eXact Cover.

	local function XCC (l, opt) R (l, opt, covertopc, uncovertopc, {}) end 	-- eXact Cover with Colors.

	local function MCC (l, opt)	-- Multiplicities Cover with Colors.

		if iscovered () then 

			local cpy = {} 
			while opt do 
				local i = opt.index
				if i then table.insert (cpy, i) end
				opt = opt.nextoption 
			end

			table.sort(cpy)
			local reward = coroutine.yield (cpy)	-- possibly prepare for some learning?
		else
			local item, branch = nextitem_minlen ()

			assert (branch >= 0)

			if branch == 0 then return end
				
			local s = slack[item]	-- the slack `s` doesn't change during the actual recursion step.
			local ft = dlink[item]	-- which stands for `First Tweaks`.

			assert (bound[item] >= 1)
			bound[item] = bound[item] - 1

			if bound[item] == 0 then cover (item) end

			local ref = dlink[item]
			
			::M4::
				if bound[item] == 0 and s == 0 then if ref ~= item then goto M6 else goto M8 end
				elseif (len[item] + s) <= bound[item] then goto M8
				elseif ref ~= item then tweak (item, ref)	-- then, proceed to M6.
				elseif bound[item] > 0 then goto M7
				else goto M67 end

			::M6::
				assert (ref ~= item) 

				loop (ref, rlink, covertopm) 

				MCC (l + 1, { 
					level = l,
					point = ref,
					index = option[ref],
					nextoption = opt,
				})

				loop (ref, llink, uncovertopm)

				ref = dlink[ref]

				goto M4

			::M67::
				assert (ref == item and bound[item] == 0 and s > 0)

				MCC (l + 1, { 
					level = l,
					point = item,
					index = nil,
					nextoption = opt,
				})
				connecth (item)

				goto M8

			::M7::
				assert (ref == item and bound[item] > 0)

				disconnecth (item)

				MCC (l + 1, { 
					level = l,
					point = item,
					index = nil,
					nextoption = opt,
				})

				connecth (item)
			
			::M8::
				if bound[item] == 0 and s == 0 then uncover (item) else untweak (ft) end
				bound[item] = bound[item] + 1

		end
	end

	local function K (start_level)

		local level = start_level
		local memo = {}
		local choice, first_tweak = {}, {}
		local best_itm, cur_node = nil, nil
		local score, pool, best_s, best_l  

	::forward::

		score = math.huge
		pool = {}

		loop (primary_header, rlink, function (item) 
			local s, b, l = slack[item], bound[item], len[item]
			if s > b then s = b end
			local t = l + s - b + 1
			if t <= score then
				if t < score or s < best_s or (s == best_s and l > best_l) then
					score = t
					pool = {item}
					best_s = s
					best_l = l
				elseif s == best_s and l == best_l then table.insert (pool, item) end
			end
		end)

		if score <= 0 then goto backdown end

		if score == math.huge then

			assert (iscovered ())

			local sol = {}

			assert (#choice == level - 1)

			for k = start_level, level - 1 do
				local pp = choice[k]
			 	sol[k] = option[pp] 
			end

			table.sort(sol)

			local digest = table.concat (sol, ' ')
			if not memo[digest] then
				memo[digest] = sol
				coroutine.yield (sol)
			end

			goto backdown
		end

		best_itm = pool[math.random(#pool)]

		cur_node = dlink[best_itm]
		choice[level] = cur_node

		bound[best_itm] = bound[best_itm] - 1

		if bound[best_itm] == 0 and slack[best_itm] == 0 then 
			first_tweak[level] = nil
			coverk (best_itm, true) 
		else
			first_tweak[level] = cur_node
			if bound[best_itm] == 0 then coverk (best_itm, true) end
		end

	::advance::

		assert (best_itm and bound[best_itm])	-- `best_item` has to be a primary item.

		if bound[best_itm] == 0 and slack[best_itm] == 0 then
			if cur_node == best_itm then goto backup end
		elseif len[best_itm] + slack[best_itm] <= bound[best_itm] then goto backup
		elseif cur_node ~= best_itm then tweakk (cur_node, bound[best_itm] > 0)
		elseif bound[best_itm] > 0 then disconnecth (best_itm) end

		if cur_node ~= best_itm then

			loop (cur_node, rlink, function (pp)
				
				local cc = top[pp]
				local b = bound[cc]

				if b then
					bound[cc] = b - 1
					if bound[cc] == 0 then coverk (cc, true) end
				else
					local c = color[pp]; assert (c)
					if c == nocolor then coverk (cc, true)
					elseif c ~= handledcolor then purifyk (pp) end 
				end
			end)

		end

		level = level + 1

		goto forward

	::backup::

		if bound[best_itm] == 0 and slack[best_itm] == 0 then uncoverk (best_itm, true)
		else 
			local ft = first_tweak[level]; assert (ft)
			untweakk (best_itm, ft, bound[best_itm] > 0) 
		end

		bound[best_itm] = bound[best_itm] + 1

	::backdown::

		if level == start_level then goto done end

		choice[level] = nil
		first_tweak[level] = nil

		level = level - 1

		cur_node = choice[level]
		best_itm = top[cur_node]

		if not best_itm then 
			assert (not isnode (cur_node))
			best_itm = cur_node
			connecth (best_itm)
			goto backup
		end

		assert (cur_node ~= best_itm)

		loop (cur_node, llink, function (pp)

			local cc = top[pp]
			local b = bound[cc]

			if b then
				if b == 0 then uncoverk (cc, true) end
				bound[cc] = b + 1
			else
				local c = color[pp]; assert (c)
				if c == nocolor then uncoverk (cc, true)
				elseif c ~= handledcolor then unpurifyk (pp) end
			end

		end)

		cur_node = dlink[cur_node]
		choice[level] = cur_node

		goto advance

	::done::
	
	end

	local xc  = coroutine.create (function () XC (1, nil) end)
	local xcc = coroutine.create (function () XCC (1, nil) end)
	local mcc = coroutine.create (function () MCC (1, nil) end)
	local knuth = coroutine.create (function () K (1) end)

	--return xcc, mcc
	return knuth, knuth
end

function dl.indexed(name)

	return function (tbl)
		local seq = {}
		for i, item in ipairs(tbl) do seq[i] = tostring (item) end
		return name .. '_' .. table.concat (seq, ',')
	end	
end


return dl
