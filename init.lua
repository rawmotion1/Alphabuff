--Alphabuff.lua
--by Rawmotion
local version = '3.3.5'
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local toon = mq.TLO.Me.Name() or ''
local server = mq.TLO.EverQuest.Server() or ''
local path = 'Alphabuff_'..toon..'.lua'
local settings = {}
local favbuffs = {}
local favsongs = {}
local font_scale = {
    {
         label = "Tiny",
         size = 8
    },
    {
         label = "Small",
         size = 9
    },
    {
         label = "Normal",
         size = 10
    },
    {
         label = "Large",
         size  = 11
    }
}

local function saveSettings()
    mq.pickle(path, { settings=settings, favbuffs=favbuffs, favsongs=favsongs })
end

local function defaults(a)
    if a == 'all' or settings.alphaB == nil then settings.alphaB = 70 end
    if a == 'all' or settings.alphaS == nil then settings.alphaS = 70 end
    if a == 'all' or settings.titleB == nil then settings.titleB = true end
    if a == 'all' or settings.titleS == nil then settings.titleS = true end
    if a == 'all' or settings.lockedB == nil then settings.lockedB = false end
    if a == 'all' or settings.lockedS == nil then settings.lockedS = false end
    if a == 'all' or settings.sizeBX == nil then settings.sizeBX = 176 end
    if a == 'all' or settings.sizeBY == nil then settings.sizeBY = 890 end
    if a == 'all' or settings.sizeSX == nil then settings.sizeSX = 176 end
    if a == 'all' or settings.sizeSY == nil then settings.sizeSY = 650 end
    if a == 'all' or settings.posBX == nil then settings.posBX = 236 end
    if a == 'all' or settings.posBY == nil then settings.posBY = 60 end
    if a == 'all' or settings.posSX == nil then settings.posSX = 60 end
    if a == 'all' or settings.posSY == nil then settings.posSY = 60 end
    if a == 'all' or settings.favBShow == nil then settings.favBShow = 3 end
    if a == 'all' or settings.favSShow == nil then settings.favSShow = 3 end
    if a == 'all' or settings.hideB == nil then settings.hideB = false end
    if a == 'all' or settings.hideS == nil then settings.hideS = false end
    if a == 'all' or settings.font == nil then settings.font = 10 end
    saveSettings()
end

local function setup()
    local conf = {}
    local configData, err = loadfile(mq.configDir..'/'..path)
    if err then
        defaults('all')
        print('\at[Alphabuff]\aw Creating config file...')
    elseif configData then
        conf = configData()
        if not conf.settings then
            local sets = conf
            conf = { settings = sets, favbuffs=favbuffs, favsongs=favsongs }
        end
        settings = conf.settings
        favbuffs = conf.favbuffs
        favsongs = conf.favsongs
        defaults()
        print('\at[Alphabuff]\aw Loading config file...')
    end
end
setup()

print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')

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

local function hitCount(s,t)
    local hits = spell(s,t).HitCount() or 0
    return hits
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
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, 1, 6, .4)
        color = 'none'
    else
        barcolor = ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, .6, 1, .4)
        color = 'blue'
    end
    return barcolor, color
end

local anim = mq.FindTextureAnimation('A_SpellIcons')
local function icon(s,t)
    local gemicon = spell(s,t).SpellIcon()
    anim:SetTextureCell(gemicon)
    return ImGui.DrawTextureAnimation(anim, 17, 17)
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

local buffs = {}
local function loadBuffs()
    for i = 1,42 do
        local buff = {
            slot = i,
            name = name(i,0),
            denom = denom(i,0),
            favorite = false}
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
            denom = denom(i,1),
            favorite = false}
        table.insert(songs, song)
    end
end
loadSongs()

local function areFavorites(t)
    local blength = 0
    local slength = 0
    if favbuffs == nil then return 0 end
    for k,v in pairs(favbuffs) do
        blength = blength + 1
    end
    if favsongs == nil then return 0 end
    for k,v in pairs(favsongs) do
        slength = slength + 1
    end
    if t == 0 then
        return blength
    else
        return slength
    end
end

local function applyFavorites()
    if areFavorites(0) > 0 then
        for k,v in pairs(buffs) do
            for l,w in pairs(favbuffs) do
                if v.name == w then
                    v.favorite = true
                end
                if w == 'zz' then favbuffs[l] = nil end
            end
        end
    end
    if areFavorites(1) > 0 then
        for k,v in pairs(songs) do
            for l,w in pairs(favsongs) do
                if v.name == w then
                    v.favorite = true
                end
                if w == 'zz' then favsongs[l] = nil end
            end
        end
    end
end
applyFavorites()

local function updateTables()
    for k,v in pairs(buffs) do
        if sortedBBy == 'slot' then
            if mq.TLO.Me.Buff(k)() then
                if v.name ~= name(k,0) then
                    v.name = name(k,0)
                    v.denom = denom(k,0)
                    v.favorite = false
                    table.sort(buffs, sortBSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    v.favorite = false
                    table.sort(buffs, sortBSlot)
                end
            end
        elseif sortedBBy == 'name' then
            if mq.TLO.Me.Buff(v.slot)() then
                if v.name ~= name(v.slot,0) then
                    v.name = name(v.slot,0)
                    v.denom = denom(v.slot,0)
                    v.favorite = false
                    table.sort(buffs, sortBName)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    v.favorite = false
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
                    v.favorite = false
                    table.sort(songs, sortSSlot)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    v.favorite = false
                    table.sort(songs, sortSSlot)
                end
            end
        elseif sortedSBy == 'name' then
            if mq.TLO.Me.Song(v.slot)() then
                if v.name ~= name(v.slot,1) then
                    v.name = name(v.slot,1)
                    v.denom = denom(v.slot,1)
                    v.favorite = false
                    table.sort(songs, sortSName)
                end
            else
                if v.name ~= 'zz' then
                    v.name = 'zz'
                    v.denom = 0
                    v.favorite = false
                    table.sort(songs, sortSName)
                end
            end
        end
    end
end

local function reIndex()
    local indexB = 1
    local tmpB = {}
    for _,v in pairs(favbuffs) do
        tmpB[indexB] = v
        indexB = indexB + 1
    end
    favbuffs = tmpB
    local indexS = 1
    local tmpS = {}
    for _,v in pairs(favsongs) do
        tmpS[indexS] = v
        indexS = indexS + 1
    end
    favsongs = tmpS
    saveSettings()
end

local function moveUp(n,t)
    local list
    if t == 0 then list = favbuffs
    elseif t == 1 then list = favsongs end
    local mover
    local moved
    local moverIdx
    local movedIdx
    for k,v in pairs(list) do
        if v == n then
            if k == 0 then return end
            mover = v
            moved = list[k-1]
            moverIdx = k
            movedIdx = k-1
        end
    end
    list[movedIdx] = mover
    list[moverIdx] = moved
    reIndex()
end

local function moveDown(n,t)
    local length = areFavorites(t)
    local list
    if t == 0 then list = favbuffs
    elseif t == 1 then list = favsongs end
    local mover
    local moved
    local moverIdx
    local movedIdx
    for k,v in pairs(list) do
        if v == n then
            if k == length then return end
            mover = v
            moved = list[k+1]
            moverIdx = k
            movedIdx = k+1
        end
    end
    list[movedIdx] = mover
    list[moverIdx] = moved
    reIndex()
end

local function addFavorite(s,t)
    local fav = name(s,t)
    if fav == 'zz' then return end
    if t == 0 then
        for _,v in pairs(favbuffs) do
            if v == fav then return end
        end
        table.insert(favbuffs, fav)
        for l,w in pairs(buffs) do
            if w.name == fav then
               w.favorite = true
            end
        end
    elseif t == 1 then
        for _,v in pairs(favsongs) do
            if v == fav then return end
        end
        table.insert(favsongs, fav)
        for l,w in pairs(songs) do
            if w.name == fav then
               w.favorite = true
            end
        end
    end
    reIndex()
end

local function unFavorite(s,t)
    local fav = name(s,t)
    if t == 0 then
        for k,v in pairs(favbuffs) do
            if v == fav then favbuffs[k] = nil end
        end
        for l,w in pairs(buffs) do
            if w.name == fav then
               w.favorite = false
            end
        end
    elseif t == 1 then
        for k,v in pairs(favsongs) do
            if v == fav then favsongs[k] = nil end
        end
        for l,w in pairs(songs) do
            if w.name == fav then
               w.favorite = false
            end
        end
    end
    reIndex()
end

local function unFavoriteGray(n,t)
    if t == 0 then
        for k,v in pairs(favbuffs) do
            if v == n then favbuffs[k] = nil end
        end
    elseif t == 1 then
        for k,v in pairs(favsongs) do
            if v == n then favsongs[k] = nil end
        end
    end
    reIndex()
end

local function spellContext(n,s,t)
    ImGui.SetWindowFontScale(1)
    if ImGui.BeginPopupContextItem('##n') then 
        if ImGui.Selectable('\xee\xa1\xbd'..' Favorite') then addFavorite(s,t) end
        ImGui.Separator()
        if ImGui.Selectable('\xee\xa2\xb6'..' Inspect') then
            if mq.TLO.MacroQuest.BuildName()=='Emu' then
                if mq.TLO.Me.Buff(n).ID() then mq.cmd('/nomodkey /altkey /notify BuffWindow Buff'..(s-1)..' leftmouseup')
                elseif mq.TLO.Me.Song(n).ID() then mq.cmd('/nomodkey /altkey /notify ShortDurationBuffWindow Buff'..(s-1)..' leftmouseup') end
            else
                spell(s,t).Inspect()
            end
        end
        if ImGui.Selectable('\xee\xa1\xb2'..' Remove') then mq.cmdf('/removebuff %s', n) end
        ImGui.Separator()
        if ImGui.Selectable('\xee\x97\x8d'..' Block spell') then mq.cmdf('/blockspell add me %s', spell(s,t).Spell.ID()) end     
    ImGui.EndPopup()
    end
    ImGui.SetWindowFontScale(settings.font/10)
end

local function favContext(n,s,t)
    ImGui.SetWindowFontScale(1)
    if ImGui.BeginPopupContextItem('##n') then
        if ImGui.Selectable('\xee\x97\x87'..' Move up') then moveUp(n,t) end
        if ImGui.Selectable('\xee\x97\x85'..' Move down') then moveDown(n,t) end
        ImGui.Separator()
        if ImGui.Selectable('\xef\x82\x8a'..' Unfavorite') then unFavorite(s,t) end
        ImGui.Separator()
        if ImGui.Selectable('\xee\xa2\xb6'..' Inspect') then
            if mq.TLO.MacroQuest.BuildName()=='Emu' then
                if mq.TLO.Me.Buff(n).ID() then mq.cmd('/nomodkey /altkey /notify BuffWindow Buff'..(s-1)..' leftmouseup')
                elseif mq.TLO.Me.Song(n).ID() then mq.cmd('/nomodkey /altkey /notify ShortDurationBuffWindow Buff'..(s-1)..' leftmouseup') end
            else
                spell(s,t).Inspect()
            end
        end
        if ImGui.Selectable('\xee\xa1\xb2'..' Remove') then mq.cmdf('/removebuff %s', n) end
        ImGui.Separator()
        if ImGui.Selectable('\xee\x97\x8d'..' Block spell') then mq.cmdf('/blockspell add me %s', spell(s,t).Spell.ID()) end     
    ImGui.EndPopup()
    end
    ImGui.SetWindowFontScale(settings.font/10)
end

local function favContextGray(n,t)
    ImGui.SetWindowFontScale(1)
    if ImGui.BeginPopupContextItem('##nn') then
        if ImGui.Selectable('\xee\x97\x87'..' Move up') then moveUp(n,t) end
        if ImGui.Selectable('\xee\x97\x85'..' Move down') then moveDown(n,t) end
        ImGui.Separator()
        if ImGui.Selectable('\xef\x82\x8a'..' Unfavorite') then unFavoriteGray(n,t) end
    ImGui.EndPopup()
    end
    ImGui.SetWindowFontScale(settings.font/10)
end

local progHeight
local progSpacing
local labelOffset
local function sizes()
    if settings.font == 8 then
        progHeight = 14
        progSpacing = 0
        labelOffset = 18
    elseif settings.font == 9 then
        progHeight = 15
        progSpacing = 2
        labelOffset = 20
    elseif settings.font == 10 then
        progHeight = 16
        progSpacing = 3
        labelOffset = 21
    elseif settings.font == 11 then
        progHeight = 18
        progSpacing = 4
        labelOffset = 22
    end
end
sizes()

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
        local hitcount
        if hitCount(item.slot,b) ~= 0 then hitcount = '['..hitCount(item.slot,b)..'] ' else hitcount = '' end
        if (b == 0 and (settings.hideB == false or select(2,barColor(item.slot,0)) == 'red')) or (b == 1 and (settings.hideS == false or select(2,barColor(item.slot,1)) == 'red')) then
            if (item.favorite == false or (b == 0 and (settings.favBShow == 0 or settings.favBShow == 2)) or (b == 1 and (settings.favSShow == 0 or settings.favSShow == 2))) and ((c and select(2,barColor(item.slot,b)) == c) or not c) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, progSpacing)
                    ImGui.PushID(item.name)
                        if item.name ~= 'zz' then
                            ImGui.BeginGroup()
                                
                                    icon(item.slot,b)
                                    ImGui.SameLine()
                                    barColor(item.slot,b)
                                        ImGui.ProgressBar(calcRatio(item.slot,b,item.denom), ImGui.GetContentRegionAvail(), progHeight, '##'..item.name)
                                        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - labelOffset)
                                        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                                        ImGui.Text(hitcount..item.name)
                                    ImGui.PopStyleColor()
                                
                            ImGui.EndGroup()
                            ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
                            spellContext(item.name,item.slot,b)
                            ImGui.PopStyleVar()
                            if ImGui.IsItemClicked(ImGuiMouseButton.Left) then mq.cmdf('/removebuff %s', item.name) end
                            local hms
                            if select(2,barColor(item.slot,b)) =='gray' then hms = 'Permanent' else hms = spell(item.slot,b).Duration.TimeHMS() or 0 end
                            if (ImGui.IsItemHovered()) and item.name ~= 'zz' then ImGui.SetTooltip(string.format("%02d", item.slot)..' '..hitcount..item.name..'('..hms..')') end
                        elseif item.name == 'zz' then
                            ImGui.TextColored(1,1,1,.5,string.format("%02d", item.slot))
                        end
                        
                    ImGui.PopID()
                ImGui.PopStyleVar()
            end
        end
    end
end

local function drawFavorites(b)
    if areFavorites(b) > 0 then
        local spells
        local favs
        if b == 0 then
            spells = buffs
            favs = favbuffs
        elseif b == 1 then
            spells = songs
            favs = favsongs
        end
        for _,v in pairs(favs) do
            local index
            for l,w in pairs(spells) do
                if v == w.name then index = l end
            end
            local item = spells[index]
            if item ~= nil then
                local hitcount
                if hitCount(item.slot,b) ~= 0 then hitcount = '['..hitCount(item.slot,b)..'] ' else hitcount = '' end
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, progSpacing)
                    ImGui.PushID(v)
                        if (b == 0 and settings.favBShow ~= 2 and item.name ~= 'zz') or (b == 1 and settings.favSShow ~= 2 and item.name ~= 'zz') then
                            ImGui.BeginGroup()
                                    icon(item.slot,b)
                                    ImGui.SameLine()
                                    barColor(item.slot,b)
                                        ImGui.ProgressBar(calcRatio(item.slot,b,item.denom), ImGui.GetContentRegionAvail(), progHeight, '##'..item.name)
                                        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - labelOffset)
                                        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                                        ImGui.Text(hitcount..item.name)
                                    ImGui.PopStyleColor()
                            ImGui.EndGroup()
                        end
                        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
                            favContext(item.name,item.slot,b)
                        ImGui.PopStyleVar()
                        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then mq.cmdf('/removebuff %s', item.name) end
                        local hms
                        if select(2,barColor(item.slot,b)) =='gray' then hms = 'Permanent' else hms = spell(item.slot,b).Duration.TimeHMS() or 0 end
                        if (ImGui.IsItemHovered()) and item.name ~= 'zz' then ImGui.SetTooltip(string.format("%02d", item.slot)..' '..hitcount..item.name..'('..hms..')') end
                    ImGui.PopID()
                ImGui.PopStyleVar()
            elseif (b == 0 and settings.favBShow ~= 1) or (b == 1 and settings.favSShow ~= 1) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, progSpacing)
                    ImGui.PushID(v..'off')
                            ImGui.BeginGroup()
                                anim:SetTextureCell(mq.TLO.Spell(v).SpellIcon())
                                ImGui.DrawTextureAnimation(anim, 17, 17)
                                ImGui.SameLine()
                                ImGui.ProgressBar(0, ImGui.GetContentRegionAvail(), progHeight, '##'..v)
                                ImGui.SetCursorPosY(ImGui.GetCursorPosY() - labelOffset)
                                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                                ImGui.TextColored(1,1,1,.3,v)
                                ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 19)
                                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 1)
                                ImGui.TextColored(.5,.5,.5,.5,'\xee\xa4\x89')
                            ImGui.EndGroup()
                        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
                            favContextGray(v,b)
                        ImGui.PopStyleVar()
                    ImGui.PopID()
                ImGui.PopStyleVar()
            end
        end
        ImGui.Separator()
    end
end

local function menu(t)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 4, 0)
    if ImGui.BeginPopupContextItem('Settings Menu') then
        local update
        ImGui.Text('Settings')
        ImGui.Separator()
        if t == 0 then
            settings.lockedB, update = ImGui.Checkbox('Lock window', settings.lockedB)
            if update then switch(settings.lockedB) end
            settings.titleB, update = ImGui.Checkbox('Show title bar', settings.titleB)
            if update then switch(settings.titleB) end
            ImGui.PushItemWidth(100)
            settings.alphaB, update = ImGui.SliderInt('Alpha', settings.alphaB, 0, 100)
            ImGui.PopItemWidth()
            if update == true then updated = true end
            if updated == true and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                saveSettings()
                updated = false
            end
            ImGui.Separator()
            if ImGui.BeginMenu("Font Scale") then
                for _,v in pairs(font_scale) do
                    local checked = settings.font == v.size
                    if ImGui.MenuItem(v.label, nil, checked) then settings.font = v.size saveSettings() sizes() break end
                end
                ImGui.EndMenu()
            end
            
            ImGui.Separator()
            ImGui.Text('Favorites')
            settings.favBShow, update = ImGui.RadioButton('Disable', settings.favBShow, 0)
            if update then saveSettings() end
            settings.favBShow, update = ImGui.RadioButton('Only active', settings.favBShow, 1)
            if update then saveSettings() end
            settings.favBShow, update = ImGui.RadioButton('Only missing', settings.favBShow, 2)
            if update then saveSettings() end
            settings.favBShow, update = ImGui.RadioButton('Show both', settings.favBShow, 3)
            if update then saveSettings() end
            ImGui.Separator()
            settings.hideB, update = ImGui.Checkbox('Hide non-favoties', settings.hideB)
            if update then switch(settings.hideB) end

        elseif t == 1 then
            settings.lockedS, update = ImGui.Checkbox('Lock window', settings.lockedS)
            if update then switch(settings.lockedS) end
            settings.titleS, update = ImGui.Checkbox('Show title bar', settings.titleS)
            if update then switch(settings.titleS) end
            ImGui.PushItemWidth(100)
            settings.alphaS, update = ImGui.SliderInt('Alpha', settings.alphaS, 0, 100)
            ImGui.PopItemWidth()
            if update == true then updated = true end
            if updated == true and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                saveSettings()
                updated = false
            end
            ImGui.Separator()
            if ImGui.BeginMenu("Font Scale") then
                for _,v in pairs(font_scale) do
                    local checked = settings.font == v.size
                    if ImGui.MenuItem(v.label, nil, checked) then settings.font = v.size saveSettings() sizes() break end
                end
                ImGui.EndMenu()
            end
            
            ImGui.Separator()
            ImGui.Text('Favorites')
            settings.favSShow, update = ImGui.RadioButton('Disable', settings.favSShow, 0)
            if update then saveSettings() end
            settings.favSShow, update = ImGui.RadioButton('Only active', settings.favSShow, 1)
            if update then saveSettings() end
            settings.favSShow, update = ImGui.RadioButton('Only missing', settings.favSShow, 2)
            if update then saveSettings() end
            settings.favSShow, update = ImGui.RadioButton('Show both', settings.favSShow, 3)
            if update then saveSettings() end
            ImGui.Separator()
            settings.hideS, update = ImGui.Checkbox('Hide non-favoties', settings.hideS)
            if update then switch(settings.hideS) end

        end
    ImGui.EndPopup()
    end
    ImGui.PopStyleVar(2)
end

local function tabs(t)
    ImGui.SetWindowFontScale(settings.font/10)
    ImGui.BeginTabBar('sortbar')
    if ImGui.BeginTabItem('Slot') then
        if (t == 0 and settings.favBShow ~= 0) or (t == 1 and settings.favSShow ~= 0) then
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                drawFavorites(t)
            ImGui.PopStyleVar()
        end
        drawTable(1,t)
        ImGui.EndTabItem()
    end
    if ImGui.BeginTabItem('Name') then
        if (t == 0 and settings.favBShow ~= 0) or (t == 1 and settings.favSShow ~= 0) then
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                drawFavorites(t)
            ImGui.PopStyleVar()
        end
        drawTable(2,t)
        ImGui.EndTabItem()
    end
    if ImGui.BeginTabItem('Type') then
        if (t == 0 and settings.favBShow ~= 0) or (t == 1 and settings.favSShow ~= 0) then
            ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                drawFavorites(t)
            ImGui.PopStyleVar()
        end
        drawTable(2,t,'gray')
        drawTable(2,t,'blue')
        drawTable(2,t,'green')
        drawTable(2,t,'red')
        drawTable(2,t,'none')
        ImGui.EndTabItem()
    end
    ImGui.EndTabBar()
end

local onloadB = true
local function buffWindow()
    if onloadB == true then
        ImGui.SetWindowSize(settings.sizeBX, settings.sizeBY)
        ImGui.SetWindowPos(settings.posBX, settings.posBY)
        onloadB = false
    end
    if settings.sizeBX ~= ImGui.GetWindowWidth() or settings.sizeBY ~= ImGui.GetWindowHeight() then
        settings.sizeBX, settings.sizeBY = ImGui.GetWindowSize()
        saveSettings()
    end
    if settings.posBX ~= ImGui.GetWindowPos() or settings.posBY ~= select(2,ImGui.GetWindowPos()) then
        settings.posBX, settings.posBY = ImGui.GetWindowPos()
        saveSettings()
    end
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

local onloadS = true
local function songWindow()
    if onloadS == true then
        ImGui.SetWindowSize(settings.sizeSX, settings.sizeSY)
        ImGui.SetWindowPos(settings.posSX, settings.posSY)
        onloadS = false
    end
    if settings.sizeSX ~= ImGui.GetWindowWidth() or settings.sizeSY ~= ImGui.GetWindowHeight() then
        settings.sizeSX, settings.sizeSY = ImGui.GetWindowSize()
        saveSettings()
    end
    if settings.posSX ~= ImGui.GetWindowPos() or settings.posSY ~= select(2,ImGui.GetWindowPos()) then
        settings.posSX, settings.posSY = ImGui.GetWindowPos()
        saveSettings()
    end
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
    local buffWindowFlags = ImGuiWindowFlags.NoFocusOnAppearing
    local songWindowFlags = ImGuiWindowFlags.NoFocusOnAppearing
    if settings.titleB == false then buffWindowFlags = buffWindowFlags + ImGuiWindowFlags.NoTitleBar end
    if settings.lockedB == true then buffWindowFlags = buffWindowFlags + ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoResize end
    if settings.titleS == false then songWindowFlags = songWindowFlags + ImGuiWindowFlags.NoTitleBar end
    if settings.lockedS == true then songWindowFlags = songWindowFlags + ImGuiWindowFlags.NoMove + ImGuiWindowFlags.NoResize end
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 5)
    if openB then
        ImGui.SetNextWindowBgAlpha(settings.alphaB/100)
        openB, showBUI = ImGui.Begin('Alphabuff##'..server..toon, openB, buffWindowFlags)
        if showBUI then buffWindow() end
        ImGui.End()
    end
    if openS then
        ImGui.SetNextWindowBgAlpha(settings.alphaS/100)
        openS, showSUI = ImGui.Begin('Alphasong##'..server..toon, openS, songWindowFlags)
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
    else
        print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')
    end
end

mq.bind('/ab', toggleWindows)

local terminate = false
while not terminate do
    updateTables()
    applyFavorites()
    mq.delay(100)
    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then mq.exit() end
end