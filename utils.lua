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

local YELLOW = ImVec4(1, 1, 0, 1)
local RED = ImVec4(1, 0, 0, 1)
local function drawNestedTableTree(table)
    for k, v in pairs(table) do
        ImGui.TableNextRow()
        ImGui.TableNextColumn()
        if type(v) == 'table' then
            local open = ImGui.TreeNodeEx(tostring(k), ImGuiTreeNodeFlags.SpanFullWidth)
            if open then
                drawNestedTableTree(v)
                ImGui.TreePop()
            end
        else
            ImGui.TextColored(YELLOW, '%s', k)
            ImGui.TableNextColumn()
            ImGui.TextColored(RED, '%s', v)
            ImGui.TableNextColumn()
        end
    end
end

local function matchFilters(k, filters)
    for filter,_ in pairs(filters) do
        if k:lower():find(filter) then return true end
    end
end


local TABLE_FLAGS = bit32.bor(ImGuiTableFlags.ScrollY,ImGuiTableFlags.RowBg,ImGuiTableFlags.BordersOuter,ImGuiTableFlags.BordersV,ImGuiTableFlags.SizingStretchSame,ImGuiTableFlags.Sortable,
                                ImGuiTableFlags.Hideable, ImGuiTableFlags.Resizable, ImGuiTableFlags.Reorderable)

function utils.drawTableTree(table, filter)
    local filters = nil
    if filter then
        filters = utils.splitSet(filter:lower(), '|')
    end
    if ImGui.BeginTable('StateTable', 2, TABLE_FLAGS, -1, -1) then
        ImGui.TableSetupScrollFreeze(0, 1)
        ImGui.TableSetupColumn('Key', ImGuiTableColumnFlags.None, 2, 1)
        ImGui.TableSetupColumn('Value', ImGuiTableColumnFlags.None, 2, 2)
        ImGui.TableHeadersRow()
        for k, v in pairs(table) do
            if not filters or matchFilters(k, filters) then
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                if type(v) == 'table' then
                    local open = ImGui.TreeNodeEx(tostring(k), ImGuiTreeNodeFlags.SpanFullWidth)
                    if open then
                        drawNestedTableTree(v)
                        ImGui.TreePop()
                    end
                elseif type(v) ~= 'function' then
                    ImGui.TextColored(YELLOW, '%s', k)
                    ImGui.TableNextColumn()
                    ImGui.TextColored(RED, '%s', v)
                    ImGui.TableNextColumn()
                end
            end
        end
        ImGui.EndTable()
    end
end

return utils
