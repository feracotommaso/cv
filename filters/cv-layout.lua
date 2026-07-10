-- Format-specific layout for the CV. HTML keeps the semantic Div structure
-- for CSS Grid; LaTeX converts selected Divs to compact CV macros.

local function has_class(el, class_name)
  for _, class in ipairs(el.classes or {}) do
    if class == class_name then return true end
  end
  return false
end

local function child_div(el, class_name)
  for _, block in ipairs(el.content or {}) do
    if block.t == "Div" and has_class(block, class_name) then
      return block
    end
  end
  return pandoc.Div({})
end

local function blocks_to_latex(blocks)
  local doc = pandoc.Pandoc(blocks or {})
  local text = pandoc.write(doc, "latex")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

function Span(el)
  if FORMAT:match("latex") and has_class(el, "pub-flags") then
    local text = pandoc.utils.stringify(el.content)
    return pandoc.RawInline("latex", string.format("\\pubflags{%s}", text))
  end
  return nil
end

function Div(el)
  if not FORMAT:match("latex") then
    return nil
  end

  if has_class(el, "cv-header") then
    local name = blocks_to_latex(child_div(el, "cv-name").content)
    local subtitle = blocks_to_latex(child_div(el, "cv-subtitle").content)
    return pandoc.RawBlock("latex", string.format("\\cvheader{%s}{%s}", name, subtitle))
  end

  if has_class(el, "cv-entry") then
    local date = blocks_to_latex(child_div(el, "cv-date").content)
    local body = blocks_to_latex(child_div(el, "cv-body").content)
    return pandoc.RawBlock("latex", string.format("\\cvitemblock{%s}{%s}", date, body))
  end

  if has_class(el, "cv-publication") then
    local number = blocks_to_latex(child_div(el, "cv-pub-number").content)
    local text = blocks_to_latex(child_div(el, "cv-pub-text").content)
    local badges = blocks_to_latex(child_div(el, "cv-pub-badges").content)
    return pandoc.RawBlock("latex", string.format("\\cvpublication{%s}{%s}{%s}", number, text, badges))
  end

  return nil
end
