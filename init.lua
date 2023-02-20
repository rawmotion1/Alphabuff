--Alphabuff.lua
--by Rawmotion
--v 1.0.0
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local current_sort_specs = nil
local function CompareWithSortSpecs(a, b)
    for n = 1, current_sort_specs.SpecsCount, 1 do
        local sort_spec = current_sort_specs:Specs(n)
        local delta = 0
        if sort_spec.ColumnIndex == 0 then
            delta = a.slot - b.slot
        elseif sort_spec.ColumnIndex == 1 then
            if a.name < b.name then
                delta = -1
            elseif b.name < a.name then
                delta = 1
            else
                delta = 0
            end
        end
        if delta ~= 0 then
            if sort_spec.SortDirection == ImGuiSortDirection.Ascending then
                return delta < 0
            end
            return delta > 0
        end
    end
    return a.slot - b.slot < 0
end

local buffs = {}
local function loadBuffs()
    for i = 1,42 do
        local setTime
        local hours = mq.TLO.Me.Buff(i).Duration.Hours()
        local minutes = mq.TLO.Me.Buff(i).Duration.Minutes()
        local seconds = mq.TLO.Me.Buff(i).Duration.Seconds()
        local totalTime = mq.TLO.Me.Buff(i).Duration.TimeHMS()
        if hours == nil or minutes == nil or seconds == nil then setTime = 'x'
        elseif hours < 1 and minutes < 1 then setTime = seconds..'s'
        elseif hours < 1 then setTime = minutes..'m'
        elseif hours > 24 then setTime = '\xee\xac\xbd'
        else setTime = hours..'h'
        end
        local buff = {
            slot = i,
            name = mq.TLO.Me.Buff(i)(),
            icon = mq.TLO.Me.Buff(i).SpellIcon(),
            time = setTime,
            timeHMS = totalTime
        }
        table.insert(buffs, buff)
        if buff.name == nil then buff.name = 'zz' end
    end
end
loadBuffs()

local makeDirty
local function updateBuffs()
    for k,v in pairs(buffs) do
        local setTime
        local hours = mq.TLO.Me.Buff(v.slot).Duration.Hours()
        local minutes = mq.TLO.Me.Buff(v.slot).Duration.Minutes()
        local seconds = mq.TLO.Me.Buff(v.slot).Duration.Seconds()
        local totalTime = mq.TLO.Me.Buff(v.slot).Duration.TimeHMS()
        if hours == nil or minutes == nil or seconds == nil then setTime = 'x'
        elseif hours < 1 and minutes < 1 then setTime = seconds..'s'
        elseif hours < 1 then setTime = minutes..'m'
        elseif hours > 24 then setTime = '\xee\xac\xbd'
        else setTime = hours..'h'
        end
        if mq.TLO.Me.Buff(v.slot)() ~= nil then buffs[k].name = mq.TLO.Me.Buff(v.slot)()
        else buffs[k].name = 'zz'
        end
        buffs[k].icon = mq.TLO.Me.Buff(v.slot).SpellIcon()
        buffs[k].time = setTime
        buffs[k].timeHMS = totalTime
        makeDirty = true
    end
end

local Open, ShowUI = true, true
local anim = mq.FindTextureAnimation('A_SpellIcons')
local tableSorting_flags = bit32.bor(ImGuiTableFlags.Sortable, ImGuiTableFlags.RowBg, ImGuiTableFlags.NoPadOuterX, ImGuiTableFlags.NoBordersInBody)

local function buildWindow()
    ImGui.SetWindowSize(220, 970, ImGuiCond.Once)
    
    ImGui.BeginTable("table_sorting", 3, tableSorting_flags)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0,2)
    ImGui.TableSetupColumn("#       ", bit32.bor(ImGuiTableColumnFlags.DefaultSort, ImGuiTableColumnFlags.WidthFixed),8)
    ImGui.TableSetupColumn("Name", bit32.bor(ImGuiTableColumnFlags.PreferSortAscending, ImGuiTableColumnFlags.WidthStretch),1)
    ImGui.TableSetupColumn("\xee\xa2\xb5", bit32.bor(ImGuiTableColumnFlags.NoSort, ImGuiTableColumnFlags.WidthFixed),24)
    ImGui.TableSetupScrollFreeze(0, 1)
    local sort_specs = ImGui.TableGetSortSpecs()
    if sort_specs.SpecsDirty or makeDirty == true then
        for n = 1, sort_specs.SpecsCount, 1 do local sort_spec = sort_specs:Specs(n) end
        current_sort_specs = sort_specs
        table.sort(buffs, CompareWithSortSpecs)
        current_sort_specs = nil
        sort_specs.SpecsDirty = false
        makeDirty = false
    end
    
    ImGui.TableHeadersRow()
    
    for k,v in pairs(buffs) do
        local buff = buffs[k]
        ImGui.PushID(buff)
        
        ImGui.TableNextRow()
        ImGui.TableNextColumn()    
     
        ImGui.AlignTextToFramePadding() ImGui.SetWindowFontScale(.8)
        ImGui.TextColored(1,1,1,.5,string.format("%02d", buff.slot))
        if (ImGui.IsItemHovered()) and buff.name ~= 'zz' then
            ImGui.SetTooltip(buff.name..' ('..buff.timeHMS..')')
        end

        ImGui.TableNextColumn()

        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
        anim:SetTextureCell(buff.icon)
        if buff.icon ~= nil then ImGui.DrawTextureAnimation(anim, 17, 17) end
        if (ImGui.IsItemHovered()) and buff.name ~= 'zz' then
            ImGui.SetTooltip(buff.name..' ('..buff.timeHMS..')')
        end
        ImGui.SameLine()
        if buff.name ~= 'zz' then
            if mq.TLO.Me.Buff(buff.slot).SpellType() == 'Detrimental' then
                ImGui.AlignTextToFramePadding() ImGui.SetWindowFontScale(.9)
                ImGui.TextColored(1, 0, 0, 1, buff.name)
            else
                ImGui.AlignTextToFramePadding() ImGui.SetWindowFontScale(.9)
                ImGui.Text(buff.name)
            end
            if (ImGui.IsItemHovered()) then
                if buff.name ~= nil and buff.timeHMS ~= nil then
                    ImGui.SetTooltip(buff.name..' ('..buff.timeHMS..')')
                end
            end
        end
        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then mq.cmdf('/removebuff %s', buff.name) end
        if ImGui.IsItemClicked(ImGuiMouseButton.Right) then mq.TLO.Me.Buff(buff.slot).Inspect() end
        ImGui.PopStyleVar()
        
        ImGui.TableNextColumn()
        
        if buff.time ~= 'x' then
            if mq.TLO.Me.Buff(buff.slot).SpellType() == 'Detrimental' then
                ImGui.AlignTextToFramePadding() ImGui.SetWindowFontScale(.8)
                ImGui.TextColored(1,0,0,1,buff.time)
            else
                ImGui.AlignTextToFramePadding() ImGui.SetWindowFontScale(.8)
                ImGui.TextColored(.8,0.5,.0,1,buff.time)
            end
        end
        
        ImGui.SetWindowFontScale(.9)
        ImGui.PopID()
        
    end
    ImGui.PopStyleVar()
    ImGui.EndTable()
    
end

local windowFlags = bit32.bor(ImGuiWindowFlags.NoTitleBar)
local function ab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 10)
    Open, ShowUI = ImGui.Begin('Alphabuff', Open, windowFlags)
    ImGui.PopStyleVar()
    if ShowUI then buildWindow() end
    ImGui.End()
end

mq.imgui.init('Alphabuff', ab)

local terminate = false
while not terminate do
    updateBuffs()
    mq.delay(500)
	if not Open then return end
end