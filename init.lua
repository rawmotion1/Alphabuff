--Alphabuff.lua
--by Rawmotion
local version = '1.7.0'
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local sortedBy = 'slot'
local function sortSlot(a, b)
    sortedBy = 'slot'
    local delta = 0
    delta = a.slot - b.slot
    if delta ~= 0 then
        return delta < 0
    end
    return a.slot - b.slot < 0
end

local function sortName(a, b)
    sortedBy = 'name'
    local delta = 0
    if a.name < b.name then
        delta = -1
    elseif b.name < a.name then
        delta = 1
    else
        delta = 0
    end
    if delta ~= 0 then
        return delta < 0
    end
    return a.slot - b.slot < 0
end

local function buff(s)
    local buff = mq.TLO.Me.Buff(s)
    return buff
end

local function buffName(s)
    local name = buff(s)() or 'zz'
    return name
end

local function buffRemaining(s)
    local remaining = buff(s).Duration() or 0
    remaining = remaining / 1000
    return remaining
end

local function buffDuration(s)
    local duration = buff(s).MyDuration() or 0
    duration = duration * 6
    return duration
end

local function buffDenom(s) 
    local rem = buffRemaining(s)
    local dur = buffDuration(s)
    return math.max(rem, dur)
end

local function barColor(s)
    local barcolor
    local color
    if buff(s).SpellType() == 'Detrimental' then
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .7, 0, 0, .7)
        color = 'red'
    elseif buffDuration(s) < 0 or buffDuration(s) > 36000 then
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 1, 1, 1, .2)
        color = 'gray'
    elseif buffDuration(s) > 0 and buffDuration(s) < 1200 then
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, 1, 6, .4)
        color = 'green'
    elseif buffDuration(s) == 0 then
        color = 'none'
    else
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, .6, 1, .4)
        color = 'blue'
    end
    return barcolor, color
end

local anim = mq.FindTextureAnimation('A_SpellIcons')
local function buffIcon(s)
    local icon = buff(s).SpellIcon()
    anim:SetTextureCell(icon)
    return ImGui.DrawTextureAnimation(anim, 17, 17)
end

local buffs = {}
local function loadBuffs()
    for i = 1,42 do
        local buff = {
            slot = i,
            name = buffName(i),
            denom = buffDenom(i)}
        table.insert(buffs, buff)
    end
end
loadBuffs()

local function updateBuffs()
    for k,v in pairs(buffs) do
        if sortedBy == 'slot' then
            if mq.TLO.Me.Buff(k)() then
                if v.name ~= buffName(k) then
                    v.name = buffName(k)
                    v.denom = buffDenom(k)
                    table.sort(buffs, sortSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    table.sort(buffs, sortSlot)
                end
            end
        elseif sortedBy == 'name' then
            if mq.TLO.Me.Buff(v.slot)() then
                if v.name ~= buffName(v.slot) then
                    v.name = buffName(v.slot)
                    v.denom = buffDenom(v.slot)
                    table.sort(buffs, sortName)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    table.sort(buffs, sortName)
                end
            end
        end
    end
end

local function calcRatio(s, d)
    local _, buff = barColor(s)
    local ratio
    if buff == 'gray' then
        ratio = 1
    elseif buff == 'green' or buff == 'red' then
        ratio = buffRemaining(s) / d
    elseif buff == 'blue' and buffRemaining(s) / 60 >= 20 then
        ratio = 1
    elseif buff == 'blue' and buffRemaining(s) / 60 < 20 then
        ratio = (buffRemaining(s) / 60) / 20
    else
        ratio = 0
    end
    return ratio
end

local Open, ShowUI = true, true
local function buildWindow()
    ImGui.SetWindowSize(200, 900, ImGuiCond.Once)
    ImGui.SetWindowFontScale(1)
    local function drawTable(a, b)
        if a == 1 and sortedBy == 'name' then
            table.sort(buffs, sortSlot)
        elseif a ==2 and sortedBy == 'slot' then
            table.sort(buffs, sortName)
        end
        for k,_ in pairs(buffs) do
            local item = buffs[k]
            if (b and select(2,barColor(item.slot)) == b) or not b then
                ImGui.PushID(item)                     
                    ImGui.BeginGroup()
                        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
                            if item.name ~= 'zz' then
                                buffIcon(item.slot)
                                ImGui.SameLine()
                                barColor(item.slot)
                                    ImGui.ProgressBar(calcRatio(item.slot, item.denom), ImGui.GetContentRegionAvail(), 16, '##'..item.name)
                                    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 21)
                                    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                                    ImGui.Text(item.name)
                                ImGui.PopStyleColor()
                            else
                                ImGui.TextColored(1,1,1,.5,string.format("%02d", item.slot))
                            end
                        ImGui.PopStyleVar()
                    ImGui.EndGroup()
                    if ImGui.IsItemClicked(ImGuiMouseButton.Left) then mq.cmdf('/removebuff %s', item.name) end
                    if ImGui.IsItemClicked(ImGuiMouseButton.Right) then buff(item.slot).Inspect() end
                    local hms
                    if barColor(item.slot) =='gray' then hms = 'Permanent' else hms = buff(item.slot).Duration.TimeHMS() or 0 end
                    if (ImGui.IsItemHovered()) and item.name ~= 'zz' then ImGui.SetTooltip(string.format("%02d", item.slot)..' '..item.name..' ('..hms..')') end
                ImGui.PopID()
            end
        end
    end
    ImGui.BeginTabBar('sortbar')
        ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 12, 4)
        ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 1, 4)
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 3)
            if ImGui.BeginTabItem('By slot') then
                drawTable(1)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem('By name') then
                drawTable(2)
                ImGui.EndTabItem()
            end
            if ImGui.BeginTabItem('By type') then
                drawTable(2, 'gray')
                drawTable(2, 'blue')
                drawTable(2, 'green')
                drawTable(2, 'red')
                drawTable(2, 'none')
                ImGui.EndTabItem()
            end
        ImGui.PopStyleVar(3)
    ImGui.EndTabBar()
    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(1,1,1,.7, ' v'..version)
    ImGui.SetWindowFontScale(1)
end

local function ab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    ImGui.SetNextWindowBgAlpha(0.7)
    Open, ShowUI = ImGui.Begin('Alphabuff', Open)
    if ShowUI then buildWindow() end
    ImGui.End()
    ImGui.PopStyleVar(2)
end

mq.imgui.init('Alphabuff', ab)

local terminate = false
while not terminate do
    updateBuffs()
    mq.delay(250)
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then break end
	if not Open then return end
end