--Alphabuff.lua
--by Rawmotion

local version = '3.4.2'

local mq = require('mq')
local imgui = require('ImGui')
local icons = require('mq.Icons')

local toon = mq.TLO.Me.Name() or ''
local server = mq.TLO.EverQuest.Server() or ''

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

---@generic T : any
---@param orig T
---@return T
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--
--#region Settings
--

---@class LegacySettings
---@field alphaB integer
---@field alphaS integer
---@field titleB boolean
---@field titleS boolean
---@field lockedB boolean
---@field lockedS boolean
---@field sizeBX integer
---@field sizeBY integer
---@field sizeSX integer
---@field sizeSY integer
---@field posBX integer
---@field posBY integer
---@field posSX integer
---@field posSY integer
---@field favBShow integer
---@field favSShow integer
---@field hideB boolean
---@field hideS boolean
---@field font integer

---@class WindowSettings
---@field alpha integer
---@field title boolean
---@field locked boolean
---@field sizeX integer
---@field sizeY integer
---@field posX integer
---@field posY integer
---@field favShow integer
---@field hide boolean

---@class Settings
---@field buffWindow WindowSettings
---@field songWindow WindowSettings
---@field font integer


---@enum BuffType
local BuffType = {
    Buff = 0,
    Song = 1
}

---@type LegacySettings
local DEFAULT_SETTINGS = {

    alphaB = 70,
    titleB = true,
    lockedB = false,
    sizeBX = 176,
    sizeBY = 890,
    posBX = 236,
    posBY = 60,
    favBShow = 3,
    hideB = false,

    alphaS = 70,
    titleS = true,
    lockedS = false,
    sizeSX = 176,
    sizeSY = 650,
    posSX = 60,
    posSY = 60,
    favSShow = 3,
    hideS = false,

    font = 10,
}

---@type Settings
local DEFAULT_SETTINGS_NEW = {
    buffWindow = {
        alpha = 70,
        title = true,
        locked = false,
        sizeX = 176,
        sizeY = 890,
        posX = 236,
        posY = 60,
        favShow = 3,
        hide = false,
    },
    songWindow = {
        alpha = 70,
        title = true,
        locked = false,
        sizeX = 176,
        sizeY = 650,
        posX = 60,
        posY = 60,
        favShow = 3,
        hide = false,
    },
    font = 10,
    favoriteBuffs = {},
    favoriteSongs = {},
}

---@return Settings
local function MakeDefaultsNew()
    ---@type Settings
    local settings = deepcopy(DEFAULT_SETTINGS_NEW)


    return settings
end


---@return LegacySettings
local function MakeDefaults()
    local settings = {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        settings[k] = v
    end
    return settings
end



local favbuffs = {}
local favsongs = {}

---@type LegacySettings
local settings = MakeDefaults()

local function GetSettingsFilename()
    return string.format("Alphabuff_%s.lua", mq.TLO.Me.Name())
end

local function SaveSettings()
    mq.pickle(GetSettingsFilename(), { settings=settings, favbuffs=favbuffs, favsongs=favsongs })
end

local function ResetDefaults()
    settings = MakeDefaults()
    favbuffs = {}
    favsongs = {}
    SaveSettings()
end

local function LoadSettings()
    local configData, err = loadfile(mq.configDir..'/'..GetSettingsFilename())
    if err then
        ResetDefaults()
        print('\at[Alphabuff]\aw Creating config file...')
    elseif configData then
        print('\at[Alphabuff]\aw Loading config file...')
        ---@type table
        local conf = configData()
        if type(conf) ~= 'table' then
            conf = {}
        end
        if not conf.settings then
            local sets = conf
            conf = { settings = sets, favbuffs = favbuffs, favsongs = favsongs }
        end

        -- Load settings and fill in any blanks
        settings = conf.settings
        for k, v in pairs(DEFAULT_SETTINGS) do
            if settings[k] == nil then
                settings[k] = v
            end
        end
        favbuffs = conf.favbuffs
        favsongs = conf.favsongs

        SaveSettings()
    end
end
LoadSettings()

--#endregion

print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')

local progHeight
local progSpacing
local labelOffset
local function ApplySizes()
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
ApplySizes()

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

---Get a Buff by slot and type
---@param slot number
---@param type number
---@return MQBuff | nil
local function GetSpell(slot, type)
    if type == 0 then
        return mq.TLO.Me.Buff(slot)
    elseif type == 1 then
        return mq.TLO.Me.Song(slot)
    end
    return nil
end

---@param slot number
---@param type number
---@return string
local function name(slot, type)
    local name = GetSpell(slot, type).Name() or 'zz'
    return name
end

local function remaining(slot, type)
    local remaining = GetSpell(slot, type).Duration() or 0
    remaining = remaining / 1000
    local trunc = tonumber(string.format("%.0f",remaining))
    return trunc
end

local function duration(slot, type)
    return GetSpell(slot, type).MyDuration.TotalSeconds() or 0
end

local function denom(slot, type)
    local rem = remaining(slot, type)
    local dur = duration(slot, type)
    return math.max(rem, dur)
end

local function GetHitCount(slot, type)
    local hits = GetSpell(slot, type).HitCount() or 0
    return hits
end

---@alias BarColor 'red'|'gray'|'green'|'none'|'blue'

---@type { [BarColor]: ImVec4 }
local COLORS_FROM_NAMES = {
    red   = ImVec4(0.7, 0.0, 0.0, 0.7),
    gray  = ImVec4(1.0, 1.0, 1.0, 0.2),
    green = ImVec4(0.2, 1.0, 6.0, 0.4),
    none  = ImVec4(0.2, 1.0, 6.0, 0.4),
    blue  = ImVec4(0.2, 0.6, 1.0, 0.4),
}

---Get appropriate bar color for a given buff
---@param slot number
---@param type number
---@return BarColor
local function GetBarColor(slot, type)
    ---@type string
    local color

    if GetSpell(slot, type).SpellType() == 'Detrimental' then
        color = 'red'
    elseif duration(slot, type) < 0 or duration(slot, type) > 36000 then
        color = 'gray'
    elseif duration(slot, type) > 0 and duration(slot, type) < 1200 then
        color = 'green'
    elseif duration(slot, type) == 0 then
        color = 'none'
    else
        color = 'blue'
    end
    return color
end

local anim = mq.FindTextureAnimation('A_SpellIcons')

local function DrawIcon(slot, type)
    local gemicon = GetSpell(slot, type).SpellIcon()
    if gemicon ~= nil then
        anim:SetTextureCell(gemicon)
        ImGui.DrawTextureAnimation(anim, 17, 17)
    else
        printf('gemicon is nil')
    end
end

local function calcRatio(s,t,d)
    local color = GetBarColor(s,t)
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
    for i = 1,47 do
        local buff = {
            slot = i,
            name = name(i,0),
            denom = denom(i,0),
            favorite = false
        }
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
            favorite = false
        }
        table.insert(songs, song)
    end
end
loadSongs()

local function HasFavorites(type)
    local buffs = type == 0 and favbuffs or favsongs
    if buffs == nil then return 0 end

    local length = 0
    for k, v in pairs(buffs) do
        length = length + 1
    end
    return length
end

local function applyFavorites()
    if HasFavorites(0) > 0 then
        for k,v in pairs(buffs) do
            for l,w in pairs(favbuffs) do
                if v.name == w then
                    v.favorite = true
                end
                if w == 'zz' then favbuffs[l] = nil end
            end
        end
    end
    if HasFavorites(1) > 0 then
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
    for k, v in pairs(buffs) do
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
    SaveSettings()
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
    local length = HasFavorites(t)
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

local function unFavorite(slot, type)
    local fav = name(slot, type)
    if type == 0 then
        for k,v in pairs(favbuffs) do
            if v == fav then favbuffs[k] = nil end
        end
        for l,w in pairs(buffs) do
            if w.name == fav then
               w.favorite = false
            end
        end
    elseif type == 1 then
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

local function DrawSpellContextMenu(name, slot, type, isFavorite)
    ImGui.SetWindowFontScale(1)
    if ImGui.BeginPopupContextItem('BuffContextMenu') then
        if isFavorite then
            -- Move up and down
            if ImGui.Selectable(string.format('%s Move up', icons.MD_ARROW_DROP_UP)) then moveUp(name, type) end
            if ImGui.Selectable(string.format('%s Move down', icons.MD_ARROW_DROP_DOWN)) then moveDown(name,type) end
            ImGui.Separator()

            -- Toggle favorite
            if ImGui.Selectable(string.format('%s Unfavorite', icons.FA_HEART_O)) then unFavorite(slot,type) end
            ImGui.Separator()
        else
            -- Toggle favorite
            if ImGui.Selectable(string.format('%s Favorite', icons.MD_FAVORITE)) then addFavorite(slot,type) end
            ImGui.Separator()
        end

        -- Inspect spell (open spell display window)
        if ImGui.Selectable(string.format('%s Inspect', icons.MD_SEARCH)) then
            GetSpell(slot, type).Inspect()
        end

        -- Remove the buff
        if ImGui.Selectable(string.format('%s Remove', icons.MD_DELETE)) then mq.cmdf('/removebuff %s', name) end
        ImGui.Separator()

        -- Block the buff
        if ImGui.Selectable(string.format('%s Block spell', icons.MD_CLOSE)) then
            mq.cmdf('/blockspell add me %s', GetSpell(slot,type).Spell.ID())
        end
        ImGui.EndPopup()
    end
    ImGui.SetWindowFontScale(settings.font / 10)
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

---@param a any
---@param buffType number
---@param filterColor BarColor | nil
local function DrawBuffTable(a, buffType, filterColor)
    -- if a == 1 and buffType == 0 and sortedBBy == 'name' then
    --     table.sort(buffs, sortBSlot)
    -- elseif a == 2 and buffType == 0 and sortedBBy == 'slot' then
    --     table.sort(buffs, sortBName)
    -- elseif a == 1 and buffType == 1 and sortedSBy == 'name' then
    --     table.sort(songs, sortSSlot)
    -- elseif a == 2 and buffType == 1 and sortedSBy == 'slot' then
    --     table.sort(songs, sortSName)
    -- end

    local spells
    if buffType == 0 then
        spells = buffs
    elseif buffType == 1 then
        spells = songs
    end

    for k, _ in pairs(spells) do
        local item = spells[k]

        local hitcount = ''
        if GetHitCount(item.slot, buffType) ~= 0 then
            hitcount = string.format('[%s] ', item.slot, buffType)
        end

        local barColor = GetBarColor(item.slot, buffType)

        if         (buffType == 0 and (not settings.hideB or barColor == 'red'))
                or (buffType == 1 and (not settings.hideS or barColor == 'red'))
        then
            if (       (not item.favorite)
                    or (buffType == 0 and (settings.favBShow == 0 or settings.favBShow == 2))
                    or (buffType == 1 and (settings.favSShow == 0 or settings.favSShow == 2))
                ) and ((filterColor and barColor == filterColor) or not filterColor)
            then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, progSpacing)
                ImGui.PushID(item.name)

                if item.name ~= 'zz' then
                    -- Draw icon, bar and name
                    ImGui.BeginGroup()
                        DrawIcon(item.slot, buffType)
                        ImGui.SameLine()

                        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, COLORS_FROM_NAMES[barColor])
                            ImGui.ProgressBar(calcRatio(item.slot,buffType,item.denom), ImGui.GetContentRegionAvail(), progHeight, '##'..item.name)
                            ImGui.SetCursorPosY(ImGui.GetCursorPosY() - labelOffset)
                            ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                            ImGui.Text("%s%s", hitcount, item.name)
                        ImGui.PopStyleColor()
                    ImGui.EndGroup()

                    -- Handle context menu (right click)
                    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
                        DrawSpellContextMenu(item.name, item.slot, buffType, false)
                    ImGui.PopStyleVar()

                    -- Remove buff if left clicked
                    if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
                        mq.cmdf('/removebuff %s', item.name)
                    end

                    -- Hover tooltip includes duration
                    if ImGui.IsItemHovered() and item.name ~= 'zz' then
                        local hms
                        if select(2, GetBarColor(item.slot, buffType)) == 'gray' then
                            hms = 'Permanent'
                        else
                            hms = GetSpell(item.slot,buffType).Duration.TimeHMS() or 0
                        end
                        ImGui.SetTooltip("%02d %s%s (%s)", item.slot, hitcount, item.name, hms)
                    end
                elseif item.name == 'zz' then
                    ImGui.TextColored(ImVec4(1, 1, 1, .5), "%02d", item.slot)
                end

                ImGui.PopID()
                ImGui.PopStyleVar()
            end
        end
    end
end

local function DrawFavorites(b)
    if HasFavorites(b) > 0 then
        local spells
        local favs
    
        if b == 0 then
            spells = buffs
            favs = favbuffs
        elseif b == 1 then
            spells = songs
            favs = favsongs
        end
    
        for _, v in pairs(favs) do
            local index
            for l, w in pairs(spells) do
                if v == w.name then index = l end
            end

            local item = spells[index]
            if item ~= nil then
                local hitcount
                if GetHitCount(item.slot,b) ~= 0 then hitcount = '['..GetHitCount(item.slot,b)..'] ' else hitcount = '' end
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, progSpacing)
                    ImGui.PushID(v)
                        if (b == 0 and settings.favBShow ~= 2 and item.name ~= 'zz') or (b == 1 and settings.favSShow ~= 2 and item.name ~= 'zz') then
                            ImGui.BeginGroup()
                                    DrawIcon(item.slot,b)
                                    ImGui.SameLine()
                                    ImGui.SameLine()
                                    local ctmp = {
                                        [1] = 1,
                                        [2] = 1,
                                        [3] = 1,
                                        [4] = 1
                                    }
                                    ctmp = GetBarColor(item.slot,b)
                                    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, ImVec4(ctmp[1],ctmp[2],ctmp[3],ctmp[4]))
                                        ImGui.ProgressBar(calcRatio(item.slot,b,item.denom), ImGui.GetContentRegionAvail(), progHeight, '##'..item.name)
                                        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - labelOffset)
                                        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                                        ImGui.Text(hitcount..item.name)
                                    ImGui.PopStyleColor()
                            ImGui.EndGroup()
                        end
                        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
                            DrawSpellContextMenu(item.name, item.slot, b, true)
                        ImGui.PopStyleVar()
                        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then mq.cmdf('/removebuff %s', item.name) end
                        local hms
                        if select(2,GetBarColor(item.slot,b)) =='gray' then hms = 'Permanent' else hms = GetSpell(item.slot,b).Duration.TimeHMS() or 0 end
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

local alphaSliderChanged = false

local function DrawSettingsMenu(type)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 4, 0)

    if ImGui.BeginPopupContextItem('Settings Menu') then
        local changed = false

        ImGui.Text('Settings')
        ImGui.Separator()

        if type == 0 then
            -- Lock window toggle
            settings.lockedB, changed = ImGui.Checkbox('Lock window', settings.lockedB)
            if changed then SaveSettings() end

            -- Show titlebar toggle
            settings.titleB, changed = ImGui.Checkbox('Show title bar', settings.titleB)
            if changed then SaveSettings() end

            -- Alpha slider with deferred save
            ImGui.SetNextItemWidth(100)
            settings.alphaB, changed = ImGui.SliderInt('Alpha', settings.alphaB, 0, 100)
            if changed then
                alphaSliderChanged = true
            end
            if alphaSliderChanged and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                SaveSettings()
                alphaSliderChanged = false
            end

            ImGui.Separator()
            if ImGui.BeginMenu("Font Scale") then
                for _,v in ipairs(font_scale) do
                    local checked = settings.font == v.size
                    if ImGui.MenuItem(v.label, nil, checked) then
                        settings.font = v.size
                        SaveSettings()
                        ApplySizes()
                        break
                    end
                end
                ImGui.EndMenu()
            end

            ImGui.Separator()
            ImGui.Text('Favorites')
            settings.favBShow, changed = ImGui.RadioButton('Disable', settings.favBShow, 0)
            if changed then SaveSettings() end
            settings.favBShow, changed = ImGui.RadioButton('Only active', settings.favBShow, 1)
            if changed then SaveSettings() end
            settings.favBShow, changed = ImGui.RadioButton('Only missing', settings.favBShow, 2)
            if changed then SaveSettings() end
            settings.favBShow, changed = ImGui.RadioButton('Show both', settings.favBShow, 3)
            if changed then SaveSettings() end
            ImGui.Separator()
            settings.hideB, changed = ImGui.Checkbox('Hide non-favoties', settings.hideB)
            if changed then switch(settings.hideB) end

        elseif type == 1 then
            settings.lockedS, changed = ImGui.Checkbox('Lock window', settings.lockedS)
            if changed then switch(settings.lockedS) end
            settings.titleS, changed = ImGui.Checkbox('Show title bar', settings.titleS)
            if changed then switch(settings.titleS) end
            ImGui.PushItemWidth(100)
            settings.alphaS, changed = ImGui.SliderInt('Alpha', settings.alphaS, 0, 100)
            ImGui.PopItemWidth()
            if changed == true then updated = true end
            if updated == true and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                SaveSettings()
                updated = false
            end
            ImGui.Separator()
            if ImGui.BeginMenu("Font Scale") then
                for _,v in pairs(font_scale) do
                    local checked = settings.font == v.size
                    if ImGui.MenuItem(v.label, nil, checked) then settings.font = v.size SaveSettings() ApplySizes() break end
                end
                ImGui.EndMenu()
            end

            ImGui.Separator()
            ImGui.Text('Favorites')
            settings.favSShow, changed = ImGui.RadioButton('Disable', settings.favSShow, 0)
            if changed then SaveSettings() end
            settings.favSShow, changed = ImGui.RadioButton('Only active', settings.favSShow, 1)
            if changed then SaveSettings() end
            settings.favSShow, changed = ImGui.RadioButton('Only missing', settings.favSShow, 2)
            if changed then SaveSettings() end
            settings.favSShow, changed = ImGui.RadioButton('Show both', settings.favSShow, 3)
            if changed then SaveSettings() end
            ImGui.Separator()
            settings.hideS, changed = ImGui.Checkbox('Hide non-favoties', settings.hideS)
            if changed then switch(settings.hideS) end

        end
    ImGui.EndPopup()
    end
    ImGui.PopStyleVar(2)
end

local function DrawTabs(type)
    ImGui.SetWindowFontScale(settings.font / 10)

    if ImGui.BeginTabBar('sortbar') then
        if ImGui.BeginTabItem('Slot') then
            -- Draw favorites
            if (type == 0 and settings.favBShow ~= 0) or (type == 1 and settings.favSShow ~= 0) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                    DrawFavorites(type)
                ImGui.PopStyleVar()
            end

            -- Draw everything else
            DrawBuffTable(1,type)

            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Name') then
            -- Draw favorites
            if (type == 0 and settings.favBShow ~= 0) or (type == 1 and settings.favSShow ~= 0) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                    DrawFavorites(type)
                ImGui.PopStyleVar()
            end

            -- Draw everything else
            DrawBuffTable(2, type)

            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Type') then
            -- Draw favorites
            if (type == 0 and settings.favBShow ~= 0) or (type == 1 and settings.favSShow ~= 0) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                    DrawFavorites(type)
                ImGui.PopStyleVar()
            end

            -- Draw everything else by category
            DrawBuffTable(2, type, 'gray')
            DrawBuffTable(2, type, 'blue')
            DrawBuffTable(2, type, 'green')
            DrawBuffTable(2, type, 'red')
            DrawBuffTable(2, type, 'none')

            ImGui.EndTabItem()
        end

        ImGui.EndTabBar()
    end

    ImGui.SetWindowFontScale(1)
end

local onloadB = true
local function DrawBuffWindow()
    if onloadB == true then
        ImGui.SetWindowSize(settings.sizeBX, settings.sizeBY)
        ImGui.SetWindowPos(settings.posBX, settings.posBY)
        onloadB = false
    end
    if settings.sizeBX ~= ImGui.GetWindowWidth() or settings.sizeBY ~= ImGui.GetWindowHeight() then
        settings.sizeBX, settings.sizeBY = ImGui.GetWindowSize()
        SaveSettings()
    end
    if settings.posBX ~= ImGui.GetWindowPos() or settings.posBY ~= select(2,ImGui.GetWindowPos()) then
        settings.posBX, settings.posBY = ImGui.GetWindowPos()
        SaveSettings()
    end
    ImGui.SetWindowFontScale(1)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 1, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 3)
        ImGui.Button('\xee\xa2\xb8##p')
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        DrawSettingsMenu(0)
        ImGui.PopStyleVar()
        ImGui.SameLine()
        DrawTabs(0)
    ImGui.PopStyleVar(3)
    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(1,1,1,.7, ' v'..version)
    ImGui.SetWindowFontScale(1)
end

local onloadS = true
local function DrawSongWindow()
    if onloadS == true then
        ImGui.SetWindowSize(settings.sizeSX, settings.sizeSY)
        ImGui.SetWindowPos(settings.posSX, settings.posSY)
        onloadS = false
    end
    if settings.sizeSX ~= ImGui.GetWindowWidth() or settings.sizeSY ~= ImGui.GetWindowHeight() then
        settings.sizeSX, settings.sizeSY = ImGui.GetWindowSize()
        SaveSettings()
    end
    if settings.posSX ~= ImGui.GetWindowPos() or settings.posSY ~= select(2,ImGui.GetWindowPos()) then
        settings.posSX, settings.posSY = ImGui.GetWindowPos()
        SaveSettings()
    end
    ImGui.SetWindowFontScale(1)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 1, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 3)
        ImGui.Button('\xee\xa2\xb8##p')
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        DrawSettingsMenu(1)
        ImGui.PopStyleVar()
        ImGui.SameLine()
        DrawTabs(1)
    ImGui.PopStyleVar(3)
    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(1,1,1,.7, ' v'..version)
    ImGui.SetWindowFontScale(1)
end

local openB, showBUI = true, true
local openS, showSUI = true, true

local function UpdateImGui()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    ImGui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 5)

    if openB then
        ImGui.SetNextWindowBgAlpha(settings.alphaB / 100)

        -- build flags for the window based on settings
        local buffWindowFlags = bit32.bor(
            ImGuiWindowFlags.NoFocusOnAppearing,
            (not settings.titleB) and ImGuiWindowFlags.NoTitleBar or 0,
            settings.lockedB and bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize) or 0
        )
        openB, showBUI = ImGui.Begin('Alphabuff##'..server..toon, openB, buffWindowFlags)
        if showBUI then DrawBuffWindow() end
        ImGui.End()
    end

    if openS then
        ImGui.SetNextWindowBgAlpha(settings.alphaS / 100)

        -- build flags for the window based on settings
        local songWindowFlags = bit32.bor(
            ImGuiWindowFlags.NoFocusOnAppearing,
            (not settings.titleS) and ImGuiWindowFlags.NoTitleBar or 0,
            settings.lockedS and bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize) or 0
        )
        openS, showSUI = ImGui.Begin('Alphasong##'..server..toon, openS, songWindowFlags)
        if showSUI then DrawSongWindow() end
        ImGui.End()
    end

    ImGui.PopStyleVar(3)
end

mq.imgui.init('Alphabuff', UpdateImGui)

---@param cmd string
local function ToggleWindowsCommand(cmd)
    if cmd == 'buff' then
        openB = not openB
    elseif cmd == 'song' then
        openS = not openS
    else
        print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')
    end
end

mq.bind('/ab', ToggleWindowsCommand)

local terminate = false

while mq.TLO.MacroQuest.GameState() == 'INGAME' and not terminate do
    updateTables()
    applyFavorites()

    mq.delay(100)
end
