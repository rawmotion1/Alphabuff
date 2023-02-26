--Alphabuff.lua
--by Rawmotion
local version = '2.1.0'
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local settings = {}
local path = 'Alphabuff_'..mq.TLO.Me.Name()..'.lua'

local function setup()
    local configData, err = loadfile(mq.configDir..'/'..path)
    if err then
        settings = {
            alphaB = 70,
            alphaS = 70,
            titleB = true,
            titleS = true
        }
        mq.pickle(path, settings)
        print('\at[Alphabuff]\aw Creating config file...')
    elseif configData then
        settings = configData()
        print('\at[Alphabuff]\aw Loading config file...')
    end
end
setup()

local function saveSettings()
    mq.pickle(path, settings)
end

local function switch(v)
    v = not v
    saveSettings()
end

local updated

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

local function drawTable(a, b, c)
    if a == 1 and b == 0 and sortedBBy == 'name' then
        table.sort(buffs, sortBSlot)
    elseif a ==2 and b == 0 and sortedBBy == 'slot' then
        table.sort(buffs, sortBName)
    elseif a ==1 and b == 1 and sortedSBy == 'name' then
        table.sort(songs, sortSSlot)
    elseif a ==2 and b == 1 and sortedSBy == 'slot' then
        table.sort(songs, sortSName)
    end
    local spells
    if b == 0 then 
        spells = buffs
    elseif b == 1 then
        spells = songs
    end
    for k,_ in pairs(spells) do
        local item = spells[k]
        if (c and select(2,barColor(item.slot,b)) == c) or not c then
            ImGui.PushID(item)                     
                ImGui.BeginGroup()
                    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
                        if item.name ~= 'zz' then
                            icon(item.slot,b)
                            ImGui.SameLine()
                            barColor(item.slot,b)
                                ImGui.ProgressBar(calcRatio(item.slot,b,item.denom), ImGui.GetContentRegionAvail(), 16, '##'..item.name)
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
                if select(2,barColor(item.slot,b)) =='gray' then hms = 'Permanent' else hms = spell(item.slot,b).Duration.TimeHMS() or 0 end
                if (ImGui.IsItemHovered()) and item.name ~= 'zz' then ImGui.SetTooltip(string.format("%02d", item.slot)..' '..item.name..' ('..hms..')') end
            ImGui.PopID()
        end
    end
end

local function menu(t)
   if ImGui.BeginPopupContextItem('Settings Menu') then
        local update
        ImGui.Text('Settings')
        ImGui.Separator()
        if t == 0 then
            settings.titleB, update = ImGui.Checkbox('Show title bar', settings.titleB)
            if update then switch(settings.titleB) end
            settings.alphaB, update = ImGui.SliderInt('Alpha', settings.alphaB, 0, 100)
            if update == true then updated = true end
            if updated == true and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                saveSettings()
                updated = false
            end
        elseif t == 1 then
            settings.titleS, update = ImGui.Checkbox('Show title bar', settings.titleS)
            if update then switch(settings.titleS) end
            settings.alphaS, update = ImGui.SliderInt('Alpha', settings.alphaS, 0, 100)
            if update == true then updated = true end
            if updated == true and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                saveSettings()
                updated = false
            end
        end
    ImGui.EndPopup()
    end
end

local function tabs(t)
    ImGui.BeginTabBar('sortbar')
    if ImGui.BeginTabItem('Slot') then
        drawTable(1,t)
        ImGui.EndTabItem()
    end
    if ImGui.BeginTabItem('Name') then
        drawTable(2,t)
        ImGui.EndTabItem()
    end
    if ImGui.BeginTabItem('Type') then
        drawTable(2,t,'gray')
        drawTable(2,t,'blue')
        drawTable(2,t,'green')
        drawTable(2,t,'red')
        drawTable(2,t,'none')
        ImGui.EndTabItem()
    end
    ImGui.EndTabBar()
end

local function buffWindow()
    ImGui.SetWindowSize(200, 900, ImGuiCond.Once)
    ImGui.SetWindowFontScale(1)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 1, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 3)
        ImGui.Button('\xee\xa2\xb8##p')
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        menu(0)
        ImGui.PopStyleVar()     
        ImGui.SameLine()
        tabs(0)
    ImGui.PopStyleVar(3)
    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(1,1,1,.7, ' v'..version)
    ImGui.SetWindowFontScale(1)
end

local function songWindow()
    ImGui.SetWindowSize(200, 660, ImGuiCond.Once)
    ImGui.SetWindowFontScale(1)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 1, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 3)
        ImGui.Button('\xee\xa2\xb8##p')
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        menu(1)
        ImGui.PopStyleVar()     
        ImGui.SameLine()
        tabs(1)
    ImGui.PopStyleVar(3)
    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(1,1,1,.7, ' v'..version)
    ImGui.SetWindowFontScale(1)
end

local openB, showBUI = true, true
local openS, showSUI = true, true

local function ab()
    local buffWindowFlags
    local songWindowFlags
    if settings.titleB == false then
        buffWindowFlags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoFocusOnAppearing)
    else
        buffWindowFlags = ImGuiWindowFlags.NoFocusOnAppearing
    end
    if settings.titleS == false then
        songWindowFlags = bit32.bor(ImGuiWindowFlags.NoTitleBar, ImGuiWindowFlags.NoFocusOnAppearing)
    else
        songWindowFlags = ImGuiWindowFlags.NoFocusOnAppearing
    end
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 5)
    if openB then
        ImGui.SetNextWindowBgAlpha(settings.alphaB/100)
        openB, showBUI = ImGui.Begin('Alphabuff', openB, buffWindowFlags)
        if showBUI then buffWindow() end
        ImGui.End()
    end
    if openS then
        ImGui.SetNextWindowBgAlpha(settings.alphaS/100)
        openS, showSUI = ImGui.Begin('Alphasong', openS, songWindowFlags)
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