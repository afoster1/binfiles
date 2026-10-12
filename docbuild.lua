local verbose = (os.getenv("DB_VERBOSE") == "1")

local directive_state = {
  global = {},
  pending = {}
}

local callout_env_map = {
  hidden = { env = "Hidden", label = "", color = "white" },
  note = { env = "Note", label = "", color = "noteBorder!20" },
  info = { env = "Note", label = "", color = "noteBorder!20" },
  tip = { env = "Tip", label = "", color = "tipBorder!20" },
  important = { env = "Important", label = "", color = "importantBorder!20" },
  warning = { env = "Warning", label = "", color = "warningBorder!20" },
  red = { env = "Red", label = "", color = "red!20" },
  green = { env = "Green", label = "", color = "green!20" },
  yellow = { env = "Yellow", label = "", color = "yellow!20" },
  orange = { env = "Orange", label = "", color = "orange!20" },
  blue = { env = "Blue", label = "", color = "blue!20" },
  indigo = { env = "Indigo", label = "", color = "indigo!20" },
  violet = { env = "Violet", label = "", color = "violet!20" }
}

local callout_text_color_map = {
  note = "noteText",
  info = "noteText",
  tip = "tipText",
  important = "importantText",
  warning = "warningText",
  green = "white",
  yellow = "black",
  orange = "black",
  red = "white",
  blue = "white",
  indigo = "white",
  violet = "white"
}

local function normalize_scalar(value)
  local item = tostring(value):match("^%s*(.-)%s*$")
  item = item:gsub("^%[", ""):gsub("%]$", "")
  item = item:gsub("^%(", ""):gsub("%)$", "")
  item = item:gsub("^\"(.*)\"$", "%1")
  item = item:gsub("^'(.*)'$", "%1")
  return item:match("^%s*(.-)%s*$")
end

local function parse_widths(value)
  local items = {}

  if type(value) == "table" then
    for _, item in ipairs(value) do
      local num = tonumber(tostring(item))
      if num then
        table.insert(items, num)
      end
    end
  elseif type(value) == "string" then
    for part in value:gmatch("[%d%.%-%+]+") do
      local num = tonumber(part)
      if num then
        table.insert(items, num)
      end
    end
  end

  if #items == 0 then
    return nil
  end

  return items
end

local function parse_boolean(value)
  if value == nil then
    return nil
  end

  local normalized = tostring(value):lower():match("^%s*(.-)%s*$")
  if normalized == "true" or normalized == "yes" or normalized == "1" then
    return true
  end

  if normalized == "false" or normalized == "no" or normalized == "0" then
    return false
  end

  return nil
end

local function get_classes(block)
  if not block then
    return {}
  end

  if block.classes then
    return block.classes
  end

  if block.attr and block.attr.classes then
    return block.attr.classes
  end

  return {}
end

local function has_class(block, name)
  for _, cls in ipairs(get_classes(block)) do
    if cls == name then
      return true
    end
  end

  return false
end

local function parse_book_builder_yaml(text)
  local result = {}
  local current_key = nil

  for raw_line in text:gmatch("([^\n]+)") do
    local line = raw_line:gsub("\r$", "")
    local trimmed = line:match("^%s*(.-)%s*$")

    if trimmed ~= "" and not trimmed:match("^#") then
      local nested_key, nested_value = trimmed:match("^([%w%-]+)%s*:%s*(.*)$")

      if current_key and nested_key then
        if result[current_key] == nil then
          result[current_key] = {}
        end
        result[current_key][nested_key] = nested_value
      else
        local key, value = trimmed:match("^([%w%-]+)%s*:%s*(.*)$")
        if key then
          if value == "" then
            current_key = key
            result[key] = {}
          else
            current_key = nil
            result[key] = value
          end
        elseif current_key and trimmed:match("^%-%s+") then
          local item = trimmed:match("^%-%s*(.-)%s*$")
          table.insert(result[current_key], item)
        end
      end
    end
  end

  return result
end

local function latex(ltx)
  return pandoc.Blocks(pandoc.RawBlock('latex', ltx))
end

local function escape_latex_text(raw_text)
  local text = tostring(raw_text or "")
  text = text:gsub("\\", "\\textbackslash{}")
  text = text:gsub("&", "\\&")
  text = text:gsub("%$", "\\$")
  text = text:gsub("#", "\\#")
  text = text:gsub("_", "\\_")
  text = text:gsub("%{", "\\{")
  text = text:gsub("%}", "\\}")
  text = text:gsub("~", "\\textasciitilde{}")
  text = text:gsub("^%s+", "")
  text = text:gsub("%s+$", "")
  return text
end

local function first_header_text(blocks)
  if type(blocks) ~= "table" then
    return nil
  end

  for _, item in ipairs(blocks) do
    if item and item.t == "Div" and item.content then
      local nested = first_header_text(item.content)
      if nested and tostring(nested):match('%S') then
        return nested
      end
    end

    if item and item.t == "Header" then
      local title = pandoc.utils.stringify(item.content)
      if title and tostring(title):match('%S') then
        return title
      end
    end

    if item and type(item) == "table" and item.content then
      local nested = first_header_text(item.content)
      if nested and tostring(nested):match('%S') then
        return nested
      end
    end
  end

  return nil
end

local function wrap_in_landscape(block_like, title_source)
  local blocks = {}

  if block_like == nil then
    return {}
  end

  if type(block_like) == "table" then
    if block_like.t == "Div" and block_like.content then
      for _, item in ipairs(block_like.content) do
        table.insert(blocks, item)
      end
    elseif block_like.t then
      table.insert(blocks, block_like)
    else
      for _, item in ipairs(block_like) do
        table.insert(blocks, item)
      end
    end
  else
    table.insert(blocks, block_like)
  end

  local header_setup = '\\gdef\\docbuildlandscapeheadertext{}'
  if title_source == "previous-section" then
    header_setup = '\\gdef\\docbuildlandscapeheadertext{\\leftmark}'
  else
    local landscape_title = first_header_text(blocks)
    if landscape_title and tostring(landscape_title):match('%S') then
      local safe_title = escape_latex_text(landscape_title)
      header_setup = '\\gdef\\docbuildlandscapeheadertext{' .. safe_title .. '}'
    end
  end

  local wrapped = {
    pandoc.RawBlock('latex', '\\clearpage'),
    pandoc.RawBlock('latex', header_setup),
    pandoc.RawBlock('latex', '\\begin{landscapepage}')
  }

  for _, item in ipairs(blocks) do
    table.insert(wrapped, item)
  end

  table.insert(wrapped, pandoc.RawBlock('latex', '\\end{landscapepage}'))
  table.insert(wrapped, pandoc.RawBlock('latex', '\\clearpage'))

  return wrapped
end

local function apply_table_widths(table_obj, widths)
  if not widths then
    return table_obj
  end

  table_obj.colspecs = table_obj.colspecs:map(function (colspec, i)
    if i <= #widths then
      return {colspec[1], widths[i]}
    end
    return {colspec[1], colspec[2]}
  end)

  return table_obj
end

local function parse_callout_style_map(value)
  local styles = {}
  local labels = {}

  local function parse_list_like_value(raw_value)
    local text = normalize_scalar(raw_value)
    if text == "" then
      return {}
    end

    local inside = text:match("^%s*%[(.*)%]%s*$") or text
    local parts = {}
    for part in inside:gmatch("[^,]+") do
      local item = normalize_scalar(part)
      if item ~= "" then
        table.insert(parts, item)
      end
    end

    if #parts == 0 and text:find(",") then
      for part in text:gmatch("[^,]+") do
        local item = normalize_scalar(part)
        if item ~= "" then
          table.insert(parts, item)
        end
      end
    end

    return parts
  end

  local function register_entry(from_key, mapped_value)
    local from = normalize_scalar(from_key):lower()
    if from == "" then
      return
    end

    if type(mapped_value) == "table" then
      local has_named_fields = mapped_value.style ~= nil or mapped_value.env ~= nil or mapped_value.label ~= nil

      if not has_named_fields and #mapped_value > 0 then
        local parts = {}
        for _, part in ipairs(mapped_value) do
          local normalized = normalize_scalar(part)
          if normalized ~= "" then
            table.insert(parts, normalized)
          end
        end

        if #parts >= 2 then
          local to = normalize_scalar(parts[1]):lower()
          if to ~= "" then
            styles[from] = to
          end
          labels[from] = normalize_scalar(parts[2])
          return
        end

        if #parts >= 1 then
          local to = normalize_scalar(parts[1]):lower()
          if to ~= "" then
            styles[from] = to
          end
          return
        end
      end

      local style_value = mapped_value.style or mapped_value.env or mapped_value["style"] or mapped_value["env"]
      local label_value = mapped_value.label or mapped_value["label"]
      if style_value ~= nil then
        local to = normalize_scalar(style_value):lower()
        if to ~= "" then
          styles[from] = to
        end
      end

      if label_value ~= nil then
        labels[from] = normalize_scalar(label_value)
      end
      return
    end

    local parts = parse_list_like_value(mapped_value)
    if #parts >= 2 then
      local to = normalize_scalar(parts[1]):lower()
      if to ~= "" then
        styles[from] = to
      end
      labels[from] = normalize_scalar(parts[2])
      return
    end

    local to = normalize_scalar(mapped_value):lower()
    if to ~= "" then
      styles[from] = to
    end
  end

  if type(value) == "table" then
    for key, mapped_value in pairs(value) do
      register_entry(key, mapped_value)
    end
  else
    local text = normalize_scalar(value):lower()
    if text ~= "" then
      styles[text] = text
    end
  end

  if next(styles) == nil then
    return nil, nil
  end

  return styles, labels
end

local function apply_global_directive(data)
  if data["table-column-widths"] ~= nil then
    local widths = parse_widths(data["table-column-widths"])
    if widths then
      directive_state.global.table_column_widths = widths
    end
  end

  if data["landscape-table"] ~= nil then
    local landscape = parse_boolean(data["landscape-table"])
    if landscape ~= nil then
      directive_state.global.landscape_table = landscape
    end
  end

  if data["callout-style"] ~= nil then
    local styles, labels = parse_callout_style_map(data["callout-style"])
    if styles then
      directive_state.global.callout_style = styles
    end
    if labels then
      directive_state.global.callout_label_overrides = labels
    end
  end
end

local function apply_pending_directive(data)
  if data["table-column-widths"] ~= nil then
    local widths = parse_widths(data["table-column-widths"])
    if widths then
      directive_state.pending.table_column_widths = widths
    end
  end

  if data["landscape-table"] ~= nil then
    local landscape = parse_boolean(data["landscape-table"])
    if landscape ~= nil then
      directive_state.pending.landscape_table = landscape
    end
  end

  if data["callout-style"] ~= nil then
    local styles, labels = parse_callout_style_map(data["callout-style"])
    if styles then
      directive_state.pending.callout_style = styles
    end
    if labels then
      directive_state.pending.callout_label_overrides = labels
    end
  end
end

local function handle_directive(block)
  local data = parse_book_builder_yaml(block.text)
  if type(data) ~= "table" then
    return {}
  end

  if has_class(block, "doc-build-global") then
    apply_global_directive(data)
  elseif has_class(block, "doc-build") then
    apply_pending_directive(data)
  end

  return {}
end

local function resolve_original_callout_kind(obj, style_map)
  if not obj then
    return nil
  end

  local classes = get_classes(obj)
  for _, class_name in ipairs(classes) do
    local normalized = tostring(class_name):lower()
    if callout_env_map[normalized] or (style_map and style_map[normalized]) then
      return normalized
    end
  end

  if obj.lang then
    local normalized = tostring(obj.lang):lower()
    if callout_env_map[normalized] or (style_map and style_map[normalized]) then
      return normalized
    end
  end

  return nil
end

local function resolve_box_kind(original_kind, style_map)
  if not original_kind then
    return nil
  end

  local normalized = tostring(original_kind):lower()
  if style_map and style_map[normalized] then
    return tostring(style_map[normalized]):lower()
  end

  return normalized
end

local function should_hide_callout_kind(kind)
  return tostring(kind or ""):lower() == "hidden"
end

local function render_callout_box(box_kind, original_kind, label_overrides)
  if should_hide_callout_kind(box_kind) then
    return {}
  end

  local base_spec = callout_env_map[box_kind] or callout_env_map.note
  if not base_spec then
    return nil
  end

  local label = (label_overrides and label_overrides[original_kind]) or base_spec.label
  local text_colour = callout_text_color_map[box_kind] or "black"
  local start = pandoc.RawBlock("latex", "\\begin{" .. base_spec.env .. "}\n\\calloutheader{" .. label .. "}{" .. text_colour .. "}\n")
  local finish = pandoc.RawBlock("latex", "\\end{" .. base_spec.env .. "}")
  return { start, finish }
end

local function apply_callout_style(div, style_map)
  if not div or not style_map then
    return div
  end

  local classes = get_classes(div)
  if #classes == 0 then
    return div
  end

  local changed = false
  for i, class_name in ipairs(classes) do
    local normalized = tostring(class_name):lower()
    if style_map[normalized] then
      classes[i] = style_map[normalized]
      changed = true
    end
  end

  if not changed then
    return div
  end

  if div.attr then
    div.attr.classes = classes
  else
    div.attr = pandoc.Attr("", classes, {})
  end

  return div
end

local function is_known_callout_kind(candidate, style_map)
  if not candidate then
    return false
  end

  local normalized = tostring(candidate):lower()
  if callout_env_map[normalized] then
    return true
  end

  return style_map and style_map[normalized] ~= nil
end

local function convert_fenced_callout(block)
  if not block then
    return nil
  end

  local normalized = nil
  local classes = get_classes(block)
  local style_map = directive_state.pending.callout_style or directive_state.global.callout_style

  for _, class_name in ipairs(classes) do
    local candidate = tostring(class_name):lower()
    if is_known_callout_kind(candidate, style_map) then
      normalized = candidate
      break
    end
  end

  if not normalized and block.lang then
    local candidate = tostring(block.lang):lower()
    if is_known_callout_kind(candidate, style_map) then
      normalized = candidate
    end
  end

  if normalized then
    local parsed = pandoc.read(block.text, "markdown")
    local label_overrides = directive_state.pending.callout_label_overrides or directive_state.global.callout_label_overrides

    local div = pandoc.Div(parsed.blocks, pandoc.Attr("", { normalized }, {}))
    local original_kind = resolve_original_callout_kind(div, style_map) or normalized

    if style_map then
      div = apply_callout_style(div, style_map)
    end

    if not div.attr then
      div.attr = pandoc.Attr("", { normalized }, {})
    end

    local box_kind = resolve_box_kind(original_kind, style_map)
    local rendered = render_callout_box(box_kind, original_kind, label_overrides)
    if rendered == nil then
      return div
    end
    if #rendered == 0 then
      return {}
    end

    return { rendered[1], div, rendered[2] }
  end

  return nil
end

function CodeBlock(block)
  if not has_class(block, "doc-build") and not has_class(block, "doc-build-global") then
    local fenced_callout = convert_fenced_callout(block)
    if fenced_callout then
      return fenced_callout
    end

    return nil
  end

  return handle_directive(block)
end

function Table(tbl)
  local widths_to_use = directive_state.pending.table_column_widths or directive_state.global.table_column_widths
  local landscape = directive_state.pending.landscape_table
  if landscape == nil then
    landscape = directive_state.global.landscape_table
  end

  if widths_to_use then
    tbl = apply_table_widths(tbl, widths_to_use)
    if directive_state.pending.table_column_widths then
      directive_state.pending.table_column_widths = nil
    end
  end

  if landscape then
    if directive_state.pending.landscape_table ~= nil then
      directive_state.pending.landscape_table = nil
    end
    return {
      pandoc.RawBlock("latex", "\\clearpage\\begin{landscape}"),
      tbl,
      pandoc.RawBlock("latex", "\\end{landscape}\\clearpage")
    }
  end

  return latex'' .. {tbl} .. latex''
end

function Div(div)
  if has_class(div, "docbuild-landscape-page") then
    local filtered_classes = {}
    for _, cls in ipairs(get_classes(div)) do
      if tostring(cls) ~= "docbuild-landscape-page" then
        table.insert(filtered_classes, cls)
      end
    end

    if div.attr then
      div.attr.classes = filtered_classes
    else
      div.attr = pandoc.Attr("", filtered_classes, {})
    end

    return wrap_in_landscape(div, "previous-section")
  end

  if has_class(div, "docbuild-landscape-section") then
    local filtered_classes = {}
    for _, cls in ipairs(get_classes(div)) do
      if tostring(cls) ~= "docbuild-landscape-section" then
        table.insert(filtered_classes, cls)
      end
    end

    if div.attr then
      div.attr.classes = filtered_classes
    else
      div.attr = pandoc.Attr("", filtered_classes, {})
    end

    return wrap_in_landscape(div, "first-header")
  end

  local style_map = directive_state.pending.callout_style or directive_state.global.callout_style
  local label_overrides = directive_state.pending.callout_label_overrides or directive_state.global.callout_label_overrides

  local original_kind = resolve_original_callout_kind(div, style_map)
  if style_map then
    div = apply_callout_style(div, style_map)
    if directive_state.pending.callout_style then
      directive_state.pending.callout_style = nil
    end
  end

  local box_kind = resolve_box_kind(original_kind, style_map)
  if not box_kind then
    return div
  end

  local rendered = render_callout_box(box_kind, original_kind, label_overrides)
  if rendered == nil then
    return div
  end
  if #rendered == 0 then
    return {}
  end

  return { rendered[1], div, rendered[2] }
end
