--Alphabuff.lua
--by Rawmotion
local version = '1.6.0'
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local sortedBy = 'slot'
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

local function sortSlot(a, b)
    sortedBy = 'slot'
    local delta = 0
    delta = a.slot - b.slot
    if delta ~= 0 then
        return delta < 0
    end
    return a.slot - b.slot < 0
end

local function calcDuration(b)
    local winner
    local color
    local current = mq.TLO.Me.Buff(b).Duration() or 0
    local scurrent = mq.TLO.Me.Buff(b).MyDuration() or 0
    current = current / 1000 --to seconds
    scurrent = scurrent * 6 --to seconds
    winner = math.max(current, scurrent)
    if mq.TLO.Me.Buff(b).SpellType() == 'Detrimental' then
        color = 'red'
    elseif scurrent == -6 or scurrent > 36000 then
        color = 'gray'
    elseif scurrent <= 1200 then
        color = 'green'
    else
        color = 'blue'
    end
    return winner, color
end

local function calcRatio(s,d,c)
    local ratio
    local current = mq.TLO.Me.Buff(s).Duration() or 0
    current = current / 1000
    if c == 'gray' then
        ratio = 1
    elseif c == 'green' or c == 'red' then
        ratio = current / d
    elseif current / 60 > 20 then
        ratio = 1
    else
        ratio = (current / 60) / 20
    end
    return ratio
end

local buffs = {}
local function loadBuffs()
    for i = 1,42 do
        local name
        local duration --seconds
        local color
        if mq.TLO.Me.Buff(i)() then
            name = mq.TLO.Me.Buff(i)()
            if mq.TLO.Me.Buff(i).Duration() < 300 then
                duration = 0
            else
                duration, color = calcDuration(i)
            end
        else
            name = 'zz'
            duration = 0
            color = 'none'
        end
        local buff = {
            slot = i,
            name = name,
            duration = duration,
            color = color}
        table.insert(buffs, buff)
        --mq.pickle('alb2.lua', buffs)
    end
end
loadBuffs()

local function updateBuffs()
    for k,v in pairs(buffs) do
        if sortedBy == 'slot' then
            if mq.TLO.Me.Buff(k)() then
                if v.name ~= mq.TLO.Me.Buff(k)() then 
                    v.name = mq.TLO.Me.Buff(k)()
                    if mq.TLO.Me.Buff(k).Duration() < 300 then
                        v.duration = 0
                    else
                        v.duration, v.color = calcDuration(k)
                    end
                    table.sort(buffs, sortSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.duration = 0
                    v.color = 'none'
                    table.sort(buffs, sortSlot)
                end
            end
        elseif sortedBy == 'name' then
            if mq.TLO.Me.Buff(v.slot)() then
                if v.name ~= mq.TLO.Me.Buff(v.slot)() then --of course this will always be inequal because if Abracadabra is in buffs[1] but in slot 40
                    v.name = mq.TLO.Me.Buff(v.slot)()
                    if mq.TLO.Me.Buff(v.slot).Duration() < 300 then
                        v.duration = 0
                    else
                        v.duration, v.color = calcDuration(v.slot)
                    end
                    table.sort(buffs, sortSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.duration = 0
                    v.color = 'none'
                    table.sort(buffs, sortSlot)
                end
            end
        end
    end
end

local Open, ShowUI = true, true
local anim = mq.FindTextureAnimation('A_SpellIcons')
local function buildWindow()
    ImGui.SetWindowSize(200, 900, ImGuiCond.Once)
    ImGui.SetWindowFontScale(1)
    local function drawTable(a, b)
        if a == 1 and sortedBy == 'name' then table.sort(buffs, sortSlot)
        elseif a ==2 and sortedBy == 'slot' then table.sort(buffs, sortName) end
        for k,v in pairs(buffs) do
            local buff = buffs[k]
            if (b and buff.color == b) or not b then
                ImGui.PushID(buff)
                local icon
                local function getIcon()
                    if buff.name ~= 'zz' then
                        anim:SetTextureCell(mq.TLO.Me.Buff(buff.slot).SpellIcon())
                        icon = ImGui.DrawTextureAnimation(anim, 17, 17)
                    else
                        icon = ImGui.TextColored(1,1,1,.5,string.format("%02d", buff.slot))
                    end
                    return icon
                end
                local ratio
                if buff.name ~= nil and buff.duration ~= nil and buff.duration ~= 0 then
                    ratio = calcRatio(buff.slot, buff.duration, buff.color)
                else
                    ratio = 0
                end
                ImGui.BeginGroup()
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
                getIcon()
                ImGui.SameLine()
                if buff.name ~= 'zz' then
                    if buff.color == 'red' then
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .7, 0, 0, .7)
                    elseif buff.color == 'green' then
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, 1, 6, .4)
                    elseif buff.color == 'gray' then
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 1, 1, 1, .2)
                    else
                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, .6, 1, .4)
                    end
                    ImGui.ProgressBar(ratio, ImGui.GetContentRegionAvail(), 16, '##'..buff.name) 
                    ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 21)
                    ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                    ImGui.Text(buff.name)
                    ImGui.PopStyleColor()
                end
                ImGui.PopStyleVar()
                ImGui.EndGroup()
                if ImGui.IsItemClicked(ImGuiMouseButton.Left) then mq.cmdf('/removebuff %s', buff.name) end
                if ImGui.IsItemClicked(ImGuiMouseButton.Right) then mq.TLO.Me.Buff(buff.slot).Inspect() end
                local hms
                if color =='gray' then hms = 'Permanent' else hms = mq.TLO.Me.Buff(buff.slot).Duration.TimeHMS() or 0 end
                if (ImGui.IsItemHovered()) and buff.name ~= 'zz' then ImGui.SetTooltip(string.format("%02d", buff.slot)..' '..buff.name..' ('..hms..')') end
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
    
end

local function ab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    ImGui.PushStyleColor(ImGuiCol.WindowBg, 0,0,0,.8)
    Open, ShowUI = ImGui.Begin('Alphabuff '..version, Open)
    if ShowUI then buildWindow() end
    ImGui.End()
    ImGui.PopStyleColor()
    ImGui.PopStyleVar(2)
end

mq.imgui.init('Alphabuff', ab)

local terminate = false
while not terminate do
    updateBuffs()
    mq.delay(250)
	if not Open then return end
end