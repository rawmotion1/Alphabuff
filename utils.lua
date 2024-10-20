local utils = {}

function utils.splitSet(input, sep)
    if sep == nil then
        sep = "|"
    end
    local t={}
    for str in string.gmatch(input, "([^"..sep.."]+)") do
        t[str] = true
    end
    return t
end

local TABLE_FLAGS = bit32.bor(
    ImGuiTableFlags.ScrollY,
    ImGuiTableFlags.RowBg,
    ImGuiTableFlags.BordersOuter,
    ImGuiTableFlags.BordersV,
    ImGuiTableFlags.SizingStretchSame,
    ImGuiTableFlags.Sortable,
    ImGuiTableFlags.Hideable,
    ImGuiTableFlags.Resizable,
    ImGuiTableFlags.Reorderable
)

local function matchFilters(k, filters)
    for filter,_ in pairs(filters) do
        if k:lower():find(filter) then return true end
    end
end

local YELLOW = ImVec4(1, 1, 0, 1)
local RED = ImVec4(1, 0, 0, 1)

local drawNestedTableTree

local function doTableRow(k, v)
    if type(v) == 'table' then
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        local open = ImGui.TreeNodeEx(tostring(k), ImGuiTreeNodeFlags.SpanFullWidth)
        if open then
            drawNestedTableTree(v)
            ImGui.TreePop()
        end
    elseif type(v) ~= 'function' then
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + ImGui.GetTreeNodeToLabelSpacing())
        ImGui.TextColored(YELLOW, '%s', k)
        ImGui.TableNextColumn()
        ImGui.TextColored(RED, '%s', v)
    end
end

drawNestedTableTree = function(table)
    for k, v in pairs(table) do
        if k == "__index" and type(v) ~= 'table' or v ~= table then
            doTableRow(k, v)
        end
    end
    local metatable = getmetatable(table)
    if metatable then
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        ImGui.PushStyleColor(ImGuiCol.Text, ImVec4(0.0, 1.0, 1.0, 1.0))
        local open = ImGui.TreeNodeEx("metatable", ImGuiTreeNodeFlags.SpanFullWidth)
        ImGui.PopStyleColor()
        if open then
            drawNestedTableTree(metatable)
            ImGui.TreePop()
        end
    end
end

function utils.drawTableTree(table)
    if ImGui.BeginTable('StateTable', 2, TABLE_FLAGS, -1, -1) then
        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2, 1)
        ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.None, 2, 2)
        ImGui.TableHeadersRow()

        drawNestedTableTree(table)

        ImGui.EndTable()
    end
end

---@generic T : any
---@param orig T
---@return T
function utils.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[utils.deepcopy(orig_key)] = utils.deepcopy(orig_value)
        end
        setmetatable(copy, utils.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

return utils
