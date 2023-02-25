--Alphabuff.lua
--by Rawmotion
local version = '2.0.0'
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local sortedBBy = 'slot'
local function sortBSlot(a, b)
    sortedBBy = 'slot'
    local delta = 0
    delta = a.slot - b.slot
    if delta ~= 0 then
        return delta < 0
    end
    return a.slot - b.slot < 0
end

local function sortBName(a, b)
    sortedBBy = 'name'
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

local sortedSBy = 'slot'
local function sortSSlot(a, b)
    sortedSBy = 'slot'
    local delta = 0
    delta = a.slot - b.slot
    if delta ~= 0 then
        return delta < 0
    end
    return a.slot - b.slot < 0
end

local function sortSName(a, b)
    sortedSBy = 'name'
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

local function spell(s,t)
    if t == 0 then 
        return mq.TLO.Me.Buff(s)
    elseif t == 1 then 
        return mq.TLO.Me.Song(s)
    end
end

local function name(s,t)
    local name = spell(s,t)() or 'zz'
    return name
end

local function remaining(s,t)
    local remaining = spell(s,t).Duration() or 0
    remaining = remaining / 1000
    local trunc = tonumber(string.format("%.0f",remaining))
    return trunc
end

local function duration(s,t)
    local duration = spell(s,t).MyDuration() or 0
    duration = duration * 6
    return duration
end

local function denom(s,t) 
    local rem = remaining(s,t)
    local dur = duration(s,t)
    return math.max(rem, dur)
end

local function barColor(s,t)
    local barcolor
    local color
    if spell(s,t).SpellType() == 'Detrimental' then
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .7, 0, 0, .7)
        color = 'red'
    elseif duration(s,t) < 0 or duration(s,t) > 36000 then
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, 1, 1, 1, .2)
        color = 'gray'
    elseif duration(s,t) > 0 and duration(s,t) < 1200 then
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, 1, 6, .4)
        color = 'green'
    elseif duration(s,t) == 0 then
        color = 'none'
    else
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, .6, 1, .4)
        color = 'blue'
    end
    return barcolor, color
end

local anim = mq.FindTextureAnimation('A_SpellIcons')
local function icon(s,t)
    local icon = spell(s,t).SpellIcon()
    anim:SetTextureCell(icon)
    return ImGui.DrawTextureAnimation(anim, 17, 17)
end

local buffs = {}
local function loadBuffs()
    for i = 1,42 do
        local buff = {
            slot = i,
            name = name(i,0),
            denom = denom(i,0)}
        table.insert(buffs, buff)
    end
end
loadBuffs()

local songs = {}
local function loadSongs()
    for i = 1,30 do
        local song = {
            slot = i,
            name = name(i,1),
            denom = denom(i,1)}
        table.insert(songs, song)
    end
end
loadSongs()

local function updateTables()
    for k,v in pairs(buffs) do
        if sortedBBy == 'slot' then
            if mq.TLO.Me.Buff(k)() then
                if v.name ~= name(k,0) then
                    v.name = name(k,0)
                    v.denom = denom(k,0)
                    table.sort(buffs, sortBSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    table.sort(buffs, sortBSlot)
                end
            end
        elseif sortedBBy == 'name' then
            if mq.TLO.Me.Buff(v.slot)() then
                if v.name ~= name(v.slot,0) then
                    v.name = name(v.slot,0)
                    v.denom = denom(v.slot,0)
                    table.sort(buffs, sortBName)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    table.sort(buffs, sortBName)
                end
            end
        end
    end
    for k,v in pairs(songs) do
        if sortedSBy == 'slot' then
            if mq.TLO.Me.Song(k)() then
                if v.name ~= name(k,1) then
                    v.name = name(k,1)
                    v.denom = denom(k,1)
                    table.sort(songs, sortSSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    table.sort(songs, sortSSlot)
                end
            end
        elseif sortedSBy == 'name' then
            if mq.TLO.Me.Song(v.slot)() then
                if v.name ~= name(v.slot,1) then
                    v.name = name(v.slot,1)
                    v.denom = denom(v.slot,1)
                    table.sort(songs, sortSName)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    table.sort(songs, sortSName)
                end
            end
        end
    end
end

local function calcRatio(s,t,d)
    local _, color = barColor(s,t)
    local ratio
    if color == 'gray' then
        ratio = 1
    elseif color == 'green' or color == 'red' then
        ratio = remaining(s,t) / d
    elseif color == 'blue' and remaining(s,t) / 60 >= 20 then
        ratio = 1
    elseif color == 'blue' and remaining(s,t) / 60 < 20 then
        ratio = (remaining(s,t) / 60) / 20
    else
        ratio = 0
    end
    return ratio
end

local function buffWindow()
    ImGui.SetWindowSize(200, 900, ImGuiCond.Once)
    ImGui.SetWindowFontScale(1)
    local function drawTable(a, b)
        if a == 1 and sortedBBy == 'name' then
            table.sort(buffs, sortBSlot)
        elseif a ==2 and sortedBBy == 'slot' then
            table.sort(buffs, sortBName)
        end
        for k,_ in pairs(buffs) do
            local item = buffs[k]
            if (b and select(2,barColor(item.slot,0)) == b) or not b then
                ImGui.PushID(item)                     
                    ImGui.BeginGroup()
                        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
                            if item.name ~= 'zz' then
                                icon(item.slot,0)
                                ImGui.SameLine()
                                barColor(item.slot,0)
                                    ImGui.ProgressBar(calcRatio(item.slot,0,item.denom), ImGui.GetContentRegionAvail(), 16, '##'..item.name)
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
                    if ImGui.IsItemClicked(ImGuiMouseButton.Right) then spell(item.slot,0).Inspect() end
                    local hms
                    if select(2,barColor(item.slot,0)) =='gray' then hms = 'Permanent' else hms = spell(item.slot,0).Duration.TimeHMS() or 0 end
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

local function songWindow()
    ImGui.SetWindowSize(200, 660, ImGuiCond.Once)
    ImGui.SetWindowFontScale(1)
    local function drawTable(a, b)
        if a == 1 and sortedSBy == 'name' then
            table.sort(songs, sortSSlot)
        elseif a ==2 and sortedSBy == 'slot' then
            table.sort(songs, sortSName)
        end
        for k,_ in pairs(songs) do
            local item = songs[k]
            if (b and select(2,barColor(item.slot,1)) == b) or not b then
                ImGui.PushID(item)
                    ImGui.BeginGroup()
                        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
                            if item.name ~= 'zz' then
                                icon(item.slot,1)
                                ImGui.SameLine()
                                barColor(item.slot,1)
                                    ImGui.ProgressBar(calcRatio(item.slot,1,item.denom), ImGui.GetContentRegionAvail(), 16, '##'..item.name)
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
                    if ImGui.IsItemClicked(ImGuiMouseButton.Right) then spell(item.slot,1).Inspect() end
                    local hms
                    if select(2,barColor(item.slot,1)) == 'gray' then hms = 'Permanent' else hms = spell(item.slot,1).Duration.TimeHMS() or 0 end
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

local openB, showBUI = true, true
local openS, showSUI = true, true
local function ab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 5)
    if openB then
        ImGui.SetNextWindowBgAlpha(0.7)
        openB, showBUI = ImGui.Begin('Alphabuff', openB, ImGuiWindowFlags.NoFocusOnAppearing)
        if showBUI then buffWindow() end
        ImGui.End()
    end
    if openS then
        ImGui.SetNextWindowBgAlpha(0.7)
        openS, showSUI = ImGui.Begin('Alphasong', openS, ImGuiWindowFlags.NoFocusOnAppearing)
        if showSUI then songWindow() end
        ImGui.End()
    end
    ImGui.PopStyleVar(3)
end

mq.imgui.init('Alphabuff', ab)

local function toggleWindows(cmd)
    if cmd == 'buff' then
        openB = not openB
    elseif cmd == 'song' then
        openS = not openS
    end
end

mq.bind('/ab', toggleWindows)

print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')

local terminate = false
while not terminate do
    updateTables()
    mq.delay(100)
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then mq.exit() end
end