-- Based on http://gist.github.com/556247

local io,string,table = io,string,table
local assert,tostring,type = assert,tostring,type
local tex,texio,node,unicode,font=tex,texio,node,unicode,font

module(..., package.seeall)

-- tostring(a_node) looks like "<node    nil <    172 >    nil : hlist 2>", so we can
-- grab the number in the middle (172 here) as a unique id. So the node
-- is named "node172"
local function get_nodename(n)
  return "\"n" .. string.gsub(tostring(n), "^<node%s+%S+%s+<%s+(%d+).*","%1") .. "\""
end

local function get_subtype(n)
  typ = node.type(n.id)
  local subtypes = {
    hlist = {
      [0] = "unknown origin",
      "created by linebreaking",
      "explicit box command",
      "parindent",
      "alignment column or row",
      "alignment cell",
    },
    glyph = {
      [0] = "character",
      "glyph",
      "ligature",
    },
    disc  = {
      [0] = "\\discretionary",
      "\\-",
      "- (auto)",
      "h&j (simple)",
      "h&j (hard, first item)",
      "h&j (hard, second item)",
    },
    glue = {
      [0]   = "skip",
      [1]   = "lineskip",
      [2]   = "baselineskip",
      [3]   = "parskip",
      [4]   = "abovedisplayskip",
      [5]   = "belowdisplayskip",
      [6]   = "abovedisplayshortskip",
      [7]   = "belowdisplayshortskip",
      [8]   = "leftskip",
      [9]   = "rightskip",
      [10]  = "topskip",
      [11]  = "splittopskip",
      [12]  = "tabskip",
      [13]  = "spaceskip",
      [14]  = "xspaceskip",
      [15]  = "parfillskip",
      [16]  = "thinmuskip",
      [17]  = "medmuskip",
      [18]  = "thickmuskip",
      [100] = "leaders",
      [101] = "cleaders",
      [102] = "xleaders",
      [103] = "gleaders"
    },
  }
  subtypes.whatsit = node.whatsits()
  if subtypes[typ] then
    return subtypes[typ][n.subtype] or tostring(n.subtype)
  else
    return tostring(n.subtype)
  end
  assert(false)
end

local function label(n,tab)
  local typ = node.type(n.id)
  local nodename = get_nodename(n)
  local subtype = get_subtype(n)
  local ret = string.format("name: %s; type: %s;",typ or "??",subtype or "?") .. "; "
  if tab then
    for i=1,#tab do
      if tab[i][1] then
        ret = ret .. string.format("%s: %s; ",tab[i][1],tab[i][2])
      end
    end
  end
  return format_type(typ) .. ret .. "\n"
end

local function draw_node(n,tab)
  local ret = {}
  if not tab then
    tab = {}
  end
  local nodename = get_nodename(n)
  if n.id ~= 50 then
    local attlist = n.attr
    if attlist then
      attlist = attlist.next
      while attlist do
        tab[#tab + 1] = { "", string.format("attr%d=%d",attlist.number, attlist.value) }
        attlist = attlist.next
      end
    end
  end
  ret[#ret + 1] = label(n,tab)
  return table.concat(ret)
end

local function draw_action(n)
  local ret = {}
  ret[#ret + 1] = "name: action; "
  ret[#ret + 1] = string.format("action_type: %s", tostring(n.action_type)) .. "; "
  ret[#ret + 1] = string.format("action_id: %s",tostring(n.action_id)) .. "; "
  ret[#ret + 1] = string.format("named_id: %s",tostring(n.named_id)) .. "; "
  ret[#ret + 1] = string.format("file: %s",tostring(n.file)) .. "; "
  ret[#ret + 1] = string.format("new_window: %s",tostring(n.new_window)) .. "; "
  ret[#ret + 1] = string.format("data: %s",tostring(n.data):gsub(">","\\>"):gsub("<","\\<")) .. "; "
  ret[#ret + 1] = string.format("ref_count: %s",tostring(n.ref_count)) .. "; "

  return table.concat(ret ) .. "\n"
end


function pt(pt)
  return string.format("%gpt", pt / 2^16)
end


function format_glyph(node,typ)
  local out = format_type(typ) ..
    kv("char", string.format("%q", unicode.utf8.char(node.char))) ..
    kv("lang", string.format("%d", node.lang)) ..
    kv("font", string.format("%d", node.font)) ..
    kv("width", pt(node.width)) .. "\n"
  if node.components then
    out = out .. analyze_nodelist(node.components)
  end

  return out
end

function kv(key, value)
  return key .. ': ' .. value .. '; '
end

function format_rule(node, typ)
  local out = format_type(typ)

  if node.width == -1073741824 then
    out = out .. kv("width", "flexible")
  else
    out = out .. kv("width", pt(node.width))
  end

  if node.height == -1073741824 then
    out = out .. kv("height", "flexible")
  else
    out = out .. kv("height", pt(node.height))
  end

  if node.depth == -1073741824 then
    out = out .. kv("depth", "flexible")
  else
    out = out .. kv("depth", pt(node.depth))
  end

  return out .. "\n"
end

local function analyze_nodelist(head)
  local ret = {}
  local typ,nodename
	while head do
	  typ = node.type(head.id)
	  nodename = get_nodename(head)

    -- hlist
    --
  	if typ == "hlist" then
      local tmp = {}
      if head.width ~= 0 then
        tmp[#tmp + 1] = string.format("width %gpt; ",head.width / 2^16)
      end
      if head.height ~= 0 then
        tmp[#tmp + 1] = string.format("height %gpt; ",head.height / 2^16)
      end
      if head.depth ~= 0 then
        tmp[#tmp + 1] = string.format("depth %gpt; ",head.depth / 2^16)
      end
      if head.glue_set ~= 0 then
        tmp[#tmp + 1] = string.format("glue_set %d; ",head.glue_set)
      end
      if head.glue_sign ~= 0 then
        tmp[#tmp + 1] = string.format("glue_sign %d; ",head.glue_sign)
      end
      if head.glue_order ~= 0 then
        tmp[#tmp + 1] = string.format("glue_order %d; ",head.glue_order)
      end
      if head.shift ~= 0 then
  	    tmp[#tmp + 1] = string.format("shift d%; ",head.shift / 2^16)
      end
      ret[#ret + 1] = "\n" .. format_type(typ) .. table.concat(tmp) .. "\n"
  	  if head.head then
  	    ret[#ret + 1] = analyze_nodelist(head.head)
  	  end

    -- vlist
    --
  	elseif typ == "vlist" then
      local tmp = {}
      if head.width ~= 0 then
        local width = string.format("width %gpt",head.width / 2^16)
        tmp[#tmp + 1] = {"width",width}
      end
      if head.height ~= 0 then
        local height= string.format("height %gpt",head.height / 2^16)
        tmp[#tmp + 1] = {"height",height}
      end
      if head.depth ~= 0 then
        local depth = string.format("depth %gpt",head.depth / 2^16)
        tmp[#tmp + 1] = {"depth",depth}
      end
      if head.glue_set ~= 0 then
        local glue_set = string.format("glue_set %d",head.glue_set)
        tmp[#tmp + 1] =  {"glue_set",glue_set}
      end
      if head.glue_sign ~= 0 then
        local glue_sign = string.format("glue_sign %d",head.glue_sign)
        tmp[#tmp + 1] ={"glue_sign",glue_sign}
      end
      if head.glue_order ~= 0 then
        local glue_order = string.format("glue_order %d",head.glue_order)
        tmp[#tmp + 1] = {"glue_order",glue_order}
      end
      if head.shift ~= 0 then
  	    local shift = string.format("shift %gpt",head.shift / 2^16)
        tmp[#tmp + 1] = {"shift",shift }
      end
      tmp[#tmp + 1] = {"head", "head"}
      ret[#ret + 1] = draw_node(head, tmp)
  	  if head.head then
  	    ret[#ret + 1] = analyze_nodelist(head.head)
  	  end

    -- glue
    --
  	elseif typ == "glue" then
  	  local subtype = get_subtype(head)
  	  local spec = string.format("%gpt", head.spec.width / 2^16)
  	  if head.spec.stretch ~= 0 then
  	    local stretch_order, shrink_order
  	    if head.spec.stretch_order == 0 then
  	      stretch_order = string.format(" + %gpt",head.spec.stretch / 2^16)
  	    else
  	      stretch_order = string.format(" + %g fi%s", head.spec.stretch  / 2^16, string.rep("l",head.spec.stretch_order - 1))
  	    end
  	    spec = spec .. stretch_order
  	  end
  	  if head.spec.shrink ~= 0 then
  	    if head.spec.shrink_order == 0 then
  	      shrink_order = string.format(" - %gpt",head.spec.shrink / 2^16)
  	    else
  	      shrink_order = string.format(" - %g fi%s", head.spec.shrink  / 2^16, string.rep("l",head.spec.shrink_order - 1))
  	    end

  	    spec = spec .. shrink_order
  	  end
      ret[#ret + 1] = format_type(typ) .. subtype .. ": " .. spec .. ";\n"

    -- kern
    --
  	elseif typ == "kern" then
      ret[#ret + 1] = format_type(typ) .. string.format("kern: %gpt",head.kern / 2^16) .. ";\n"

    -- rule
    --
    elseif typ == "rule" then
      ret[#ret + 1] = format_rule(head, typ)

    -- penalty
    --
    elseif typ == "penalty" then
      ret[#ret + 1] = format_type(typ) .. head.penalty .. ";\n"

    -- disc
    --
    elseif typ == "disc" then
	    ret[#ret + 1] = format_type(typ) .. ";\n"
	    if head.pre then
	      ret[#ret + 1] = analyze_nodelist(head.pre)
	    end
	    if head.post then
	      ret[#ret + 1] = analyze_nodelist(head.post)
	    end
	    if head.replace then
	      ret[#ret + 1] = analyze_nodelist(head.replace)
	    end

    -- glyph
    --
  	elseif typ == "glyph" then
      ret[#ret + 1] = format_glyph(head,typ)

    -- math
    --
    elseif typ == "math" then
      ret[#ret + 1] = draw_node(head, { "math", head.subtype == 0 and "on" or "off" })

    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 7 then
      ret[#ret + 1] = draw_node(head, { { "dir", head.dir } })

    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 16 then
      local wd  = string.format("width (pt): %gpt",  head.width / 2^16)
      local ht  = string.format("height: %gpt", head.height / 2^16)
      local dp  = string.format("depth %gpt",  head.depth / 2^16)
      local objnum = string.format("objnum %d",head.objnum)
      ret[#ret + 1] = draw_action(head.action)
      ret[#ret + 1] = draw_node(head, {{ "subtype", "pdf_start_link"}, {"width", wd},{"widthraw",head.width}, {"height" , ht}, {"depth",dp}, {"objnum", objnum}, {"action", "action"}})

    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 39 then
      local stack = string.format("stack: %d; ", head.stack)
      local cmd   = string.format("cmd: %s; ", head.cmd)
      local data  = string.format("data: %s; ", head.data)
      ret[#ret + 1] = format_type(typ) .. "subtype: colorstack; " .. stack .. cmd .. data .. "\n"

    -- whatsit
    --
    elseif typ == "whatsit" and head.subtype == 44 then
      local uid = string.format("user_id: %s; ",tostring(head.user_id))
      local t = string.format("type: %s; ",tostring(head.type))
      local val = string.format("value: %s; ", tostring(head.value))
      ret[#ret + 1] = format_type(typ) .. "subtype: user_defined; " .. uid .. t .. val .. "\n"
    else
      ret[#ret + 1] = draw_node(head, { })
    end

    head = head.next
	end
  return table.concat(ret)
end

function format_type(typ)
  return string.upper(typ) .. " "
end

function nodelist_visualize(nodelist)
  local output = analyze_nodelist(nodelist)

  output = debug_heading("BEGIN nodelist debug (Callback: " .. callback .. ")") .. output .. debug_heading("END nodelist debug")

  texio.write(channel, output)
end

function debug_heading(heading)
  local line = '\n%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%\n'
  return '\n' .. line .. '% ' .. heading .. line .. '\n'
end

function get_luatex_callback(key)

  if key == "prelinebreak" then callback = "pre_linebreak_filter"
  elseif key == "linebreak" then callback = "linebreak_filter"
  elseif key == "postlinebreak" then callback = "post_linebreak_filter"
  elseif key == "hpack" then callback = "hpack_filter"
  elseif key == "vpack" then callback = "vpack_filter"
  elseif key == "hyphenate" then callback = "hyphenate"
  elseif key == "ligaturing" then callback = "ligaturing"
  elseif key == "kerning" then callback = "kerning"
  elseif key == "mhlist" then callback = "mlist_to_hlist"
  else callback = "post_linebreak_filter"
  end

  return callback
end
