-- This is a custom writer for pandoc.  It started as their sample
-- that is very similar to that of pandoc's HTML writer and just a few
-- modifications have been made to get the xwiki syntax that I have
-- needed so far.  If something comes up that I haven't used yet
-- you'll probably get some html in your xwiki output.  If that
-- happens, just search for that html in here and fix it.  So far I
-- haven't really needed to know lua to do that.
--
-- A note on footnotes.  It seems xwiki only puts anchors on headings,
-- it doesn't let you put them whereever you want.  So footnotes all
-- just link to the heading.  I think this originally had a way to
-- create a link back to the footnote at the end of the document to
-- where it is in the document.  The anchor restriction doens't allow
-- that either, obviously.
--
-- Invoke with: pandoc -t xwiki.lua
--
-- Note:  you need not have lua installed on your system to use this
-- custom writer.  However, if you do have lua installed, you can
-- use it to test changes to the script.  'lua sample.lua' will
-- produce informative error messages if your code contains
-- syntax errors.

-- Character escaping
-- I don't think we need any escaping.
local function escape(s, in_attribute)
  return s
end

-- Helper function to convert an attributes table into
-- a string that can be put into HTML tags.
local function attributes(attr)
  local attr_table = {}
  for x,y in pairs(attr) do
    if y and y ~= "" then
      table.insert(attr_table, ' ' .. x .. '="' .. escape(y,true) .. '"')
    end
  end
  return table.concat(attr_table)
end

-- Run cmd on a temporary file containing inp and return result.
local function pipe(cmd, inp)
  local tmp = os.tmpname()
  local tmph = io.open(tmp, "w")
  tmph:write(inp)
  tmph:close()
  local outh = io.popen(cmd .. " " .. tmp,"r")
  local result = outh:read("*all")
  outh:close()
  os.remove(tmp)
  return result
end

-- Table to store footnotes, so they can be included at the end.
local notes = {}
local bullets = {}
local orders = {}

-- Blocksep is used to separate block elements.
function Blocksep()
  return bullets[1] and "\n" or orders[1] and "\n" or "\n\n"
--  return "\n\n"
end

-- This function is called once for the whole document. Parameters:
-- body is a string, metadata is a table, variables is a table.
-- This gives you a fragment.  You could use the metadata table to
-- fill variables in a custom lua template.  Or, pass `--template=...`
-- to pandoc, and pandoc will add do the template processing as
-- usual.
function Doc(body, metadata, variables)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add(body)
  if #notes > 0 then
    for _,note in pairs(notes) do
      add(note)
    end
  end
  return table.concat(buffer,'\n') .. '\n'
end

-- The functions that follow render corresponding pandoc elements.
-- s is always a string, attr is always a table of attributes, and
-- items is always an array of strings (the items in a list).
-- Comments indicate the types of other variables.

function Str(s)
  return escape(s)
end

function Space()
  return " "
end

function SoftBreak()
  return "\n"
end

function LineBreak()
  return "\n"
end

function Emph(s)
  return "//" .. s .. "//"
end

function Strong(s)
  return "**" .. s .. "**"
end

function Subscript(s)
   -- return ",," .. s .. ",,"
   return s
end

function Superscript(s)
  return "^^" .. s .. "^^"
end

function SmallCaps(s)
  return '<span style="font-variant: small-caps;">' .. s .. '</span>'
end

function Strikeout(s)
  return '--' .. s .. '--'
end

function Link(s, src, tit, attr)
   if s == src then
      return s
   elseif s.sub(s, 1, 5) == "image" then
      -- image link
      return "[[[[" .. escape(s) .. "]]>>" .. escape(src,true) .."]]"
   else
     return "[[" .. s .. ">>" .. escape(src,true) .."]]"
     -- return "{{html}}<a href='" .. escape(src,true) .. "'>" .. s .."</a>{{/html}}"
  end
end

function Image(s, src, tit, attr)
   -- return "<img src='" .. escape(src,true) .. "' title='" ..
   --       escape(tit,true) .. "'/>"
   return src
end

function Code(s, attr)
  return "{{code language=" .. attributes(attr) .. "}}" .. escape(s) .. "{{/code}}"
end

function InlineMath(s)
  return "\\(" .. escape(s) .. "\\)"
end

function DisplayMath(s)
  return "\\[" .. escape(s) .. "\\]"
end

function Note(s)
  local num = #notes + 1
  -- insert the back reference right before the final closing tag.
  s = string.gsub(s,
          '(.*)</', '%1 <a href="#fnref' .. num ..  '">&#8617;</a></')
  -- add a list item with the note to the note table.
  table.insert(notes, '1. ' .. s .. '')
  -- return the footnote reference, linked to the note.
  -- return '<a id="fnref' .. num .. '" href="#fn' .. num ..
  --           '"><sup>' .. num .. '</sup></a>'
  return '[[^^' .. num .. '^^>>||anchor="HFootnotes"]]'
end

function Span(s, attr)
  return "<span" .. attributes(attr) .. ">" .. s .. "</span>"
end

function RawInline(format, str)
  if format == "html" then
    return str
  else
    return ''
  end
end

function Cite(s, cs)
  local ids = {}
  for _,cit in ipairs(cs) do
    table.insert(ids, cit.citationId)
  end
  return "<span class=\"cite\" data-citation-ids=\"" .. table.concat(ids, ",") ..
    "\">" .. s .. "</span>"
end

function Plain(s)
  return s
end

function Para(s)
  return "" .. s .. ""
end

-- lev is an integer, the header level.
function Header(lev, s, attr)
  -- if I knew lua this would be more elegant:
  if lev == 1 then
    return "=" .. s .. "="
  end
  if lev == 2 then
    return "==" .. s .. "=="
  end
  if lev == 3 then
    return "===" .. s .. "==="
  end
  if lev == 4 then
    return "====" .. s .. "===="
  end
end

function BlockQuote(s)
  return "<blockquote>\n" .. s .. "\n</blockquote>"
end

function HorizontalRule()
  return "<hr/>"
end

function LineBlock(ls)
  return '<div style="white-space: pre-line;">' .. table.concat(ls, '\n') ..
         '</div>'
end

function CodeBlock(s, attr)
  -- If code block has class 'dot', pipe the contents through dot
  -- and base64, and include the base64-encoded png as a data: URL.
  if attr.class and string.match(' ' .. attr.class .. ' ',' dot ') then
    local png = pipe("base64", pipe("dot -Tpng", s))
    return '<img src="data:image/png;base64,' .. png .. '"/>'
  -- otherwise treat as code (one could pipe through a highlighter)
  else
    return "{{code}}" .. escape(s) .. "{{/code}}"
  end
end

-- replacement for BulletList, returned via global metatable
function BulletList_(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, table.concat(bullets) .. ' ' .. item)
  end
  -- remove bullet inserted in metatable
  table.remove(bullets)
  return table.concat(buffer, '\n')
end

function OrderedList_(items)
  local buffer = {}
  for _, item in pairs(items) do
    table.insert(buffer, table.concat(orders) .. ". " .. item)
  end
  table.remove(orders)
  return table.concat(buffer, "\n")
end

function DefinitionList(items)
  local buffer = {}
  for _,item in pairs(items) do
    local k, v = next(item)
    table.insert(buffer, "<dt>" .. k .. "</dt>\n<dd>" ..
                   table.concat(v, "</dd>\n<dd>") .. "</dd>")
  end
  return "<dl>\n" .. table.concat(buffer, "\n") .. "\n</dl>"
end

-- Convert pandoc alignment to something HTML can use.
-- align is AlignLeft, AlignRight, AlignCenter, or AlignDefault.
function html_align(align)
  if align == 'AlignLeft' then
    return 'left'
  elseif align == 'AlignRight' then
    return 'right'
  elseif align == 'AlignCenter' then
    return 'center'
  else
    return 'left'
  end
end

function CaptionedImage(src, tit, caption, attr)
   -- image file should be uploaded manually to wiki page to render
   -- hopefully the API will support CLI uploading soon
   local image_file = src:match(".+/(.*)$")
   return '[[image:' .. escape(image_file,true) .. ']]'
   --return '<div class="figure">\n<img src="' .. escape(src,true) ..
   --   '" title="' .. escape(tit,true) .. '"/>\n' ..
   --   '<p class="caption">' .. caption .. '</p>\n</div>'
end

-- Caption is a string, aligns is an array of strings,
-- widths is an array of floats, headers is an array of
-- strings, rows is an array of arrays of strings.
function Table(caption, aligns, widths, headers, rows)
  local buffer = {}
  local function add(s)
    table.insert(buffer, s)
  end
  add('{{html wiki="true}}')
  add("<table>")
  if caption ~= "" then
    add("<caption>" .. caption .. "</caption>")
  end
  if widths and widths[1] ~= 0 then
    for _, w in pairs(widths) do
      add('<col width="' .. string.format("%.0f%%", w * 100) .. '" />')
    end
  end
  local header_row = {}
  local empty_header = true
  for i, h in pairs(headers) do
    local align = html_align(aligns[i])
    table.insert(header_row,'<th align="' .. align .. '">' .. h .. '</th>')
    empty_header = empty_header and h == ""
  end
  if empty_header then
    head = ""
  else
    add('<tr class="header">')
    for _,h in pairs(header_row) do
      add(h)
    end
    add('</tr>')
  end
  local class = "even"
  for _, row in pairs(rows) do
    class = (class == "even" and "odd") or "even"
    add('<tr class="' .. class .. '">')
    for i,c in pairs(row) do
      c = c:gsub("{{html}}", "")
      c = c:gsub("{{/html}}", "")
      add('<td align="' .. html_align(aligns[i]) .. '">' .. c .. '</td>')
    end
    add('</tr>')
  end
  add('</table>')
  add("{{/html}}")
  return table.concat(buffer,'\n')
end

function RawBlock(format, str)
  if format == "html" then
    return str
  else
    return ''
  end
end

function Div(s, attr)
  return "<div" .. attributes(attr) .. ">\n" .. s .. "</div>"
end

-- The following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer.
local meta = {}
meta.__index =
  function(_, key)
    if key == 'BulletList' then
        table.insert(bullets, '*')
        return BulletList_
    elseif key == 'OrderedList' then
        table.insert(orders, '1')
        return OrderedList_
    end
    io.stderr:write(string.format("WARNING: Undefined function '%s'\n",key))
    return function() return "" end
  end
setmetatable(_G, meta)
