--Alphabuff.lua
--by Rawmotion

local version = '3.5.0'

local mq = require('mq')
local imgui = require('ImGui')
local icons = require('mq.Icons')


print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')

---@alias BuffType 0|1

---@type BuffType
local BUFFS = 0

---@type BuffType
local SONGS = 1

---@class BuffItem
---@field slot number
---@field name string
---@field denom number
---@field favorite boolean

---@alias SortParam 0|1|2

local SORT_BY_SLOT = 0
local SORT_BY_NAME = 1
local SORT_BY_TYPE = 2

---@alias FavoriteMode 0|1|2|3
local FAV_SHOW_DISABLE = 0
local FAV_SHOW_ONLY_ACTIVE = 1
local FAV_SHOW_ONLY_MISSING = 2
local FAV_SHOW_BOTH = 3

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

---@type string[]
local favoriteBuffs = {}

---@type string[]
local favoriteSongs = {}


local sortedBBy = 'slot'
local sortedSBy = 'slot'

---@type LegacySettings
local settings = MakeDefaults()

local function GetSettingsFilename()
    return string.format("Alphabuff_%s.lua", mq.TLO.Me.Name())
end

local function SaveSettings()
    mq.pickle(GetSettingsFilename(), { settings=settings, favbuffs=favoriteBuffs, favsongs=favoriteSongs })
end

local function ResetDefaults()
    settings = MakeDefaults()
    favoriteBuffs = {}
    favoriteSongs = {}
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
            conf = { settings = sets, favbuffs = favoriteBuffs, favsongs = favoriteSongs }
        end
        settings = conf.settings
        favoriteBuffs = conf.favbuffs
        favoriteSongs = conf.favsongs

        -- Load settings and fill in any blanks
        -- Check font and reset if its invalid
        if type(settings.font) ~= 'number' or settings.font < 8 or settings.font > 11 then
            settings.font = nil
        end
        for k, v in pairs(DEFAULT_SETTINGS) do
            if settings[k] == nil then
                settings[k] = v
            end
        end

        SaveSettings()
    end
end
LoadSettings()

--#endregion

local WIDGET_SIZES = {
    [8] = {
        progressBarHeight = 14,
        progressBarSpacing = 0,
        labelOffset = 18,
    },
    [9] = {
        progressBarHeight = 15,
        progressBarSpacing = 2,
        labelOffset = 20,
    },
    [10] = {
        progressBarHeight = 16,
        progressBarSpacing = 3,
        labelOffset = 21,
    },
    [11] = {
        progressBarHeight = 18,
        progressBarSpacing = 4,
        labelOffset = 22,
    }
}

local toon = mq.TLO.Me.Name() or ''
local server = mq.TLO.EverQuest.Server() or ''

local A_SpellIcons = mq.FindTextureAnimation('A_SpellIcons')

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

---Get a Buff by slot and type
---@param slot number
---@param type BuffType
---@return MQBuff
local function GetSpell(slot, type)
    if type == BUFFS then
        return mq.TLO.Me.Buff(slot)
    else
        return mq.TLO.Me.Song(slot)
    end
end

---@param slot number
---@param type BuffType
---@return string
local function name(slot, type)
    local name = GetSpell(slot, type).Name() or 'zz'
    return name
end

---@param slot number
---@param type BuffType
---@return number
local function remaining(slot, type)
    local remaining = GetSpell(slot, type).Duration() or 0
    remaining = remaining / 1000
    local trunc = tonumber(string.format("%.0f",remaining))
    return trunc or 0
end

---@param slot number
---@param type BuffType
---@return number
local function duration(slot, type)
    return GetSpell(slot, type).MyDuration.TotalSeconds() or 0
end

---@param slot number
---@param type BuffType
---@return number
local function denom(slot, type)
    local rem = remaining(slot, type)
    local dur = duration(slot, type)
    return math.max(rem, dur)
end

---@param slot number
---@param type BuffType
---@return number
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
---@param type BuffType
---@return BarColor
local function GetBarColor(slot, type)
    local spell = GetSpell(slot, type)
    if spell.SpellType() == 'Detrimental' then
        return 'red'
    end

    local duration = spell.MyDuration.TotalSeconds() or 0

    if duration < 0 or duration > 36000 then
        return 'gray'
    end
    if duration > 0 and duration < 1200 then
        return 'green'
    end
    if duration == 0 then
        return 'none'
    end
    
    return 'blue'
end

---@param slot number
---@param type BuffType
local function DrawIcon(slot, type)
    local gemicon = GetSpell(slot, type).SpellIcon()
    if gemicon ~= nil then
        A_SpellIcons:SetTextureCell(gemicon)
        ImGui.DrawTextureAnimation(A_SpellIcons, 17, 17)
    end
end

---Calculate ratio used for progress of buff bar
---@param buffSlot number
---@param type BuffType
---@param denom number
---@return number
local function CalcRatio(buffSlot, type, denom)
    local color = GetBarColor(buffSlot, type)
    local ratio
    if color == 'gray' then
        ratio = 1
    elseif color == 'green' or color == 'red' then
        ratio = remaining(buffSlot,type) / denom
    elseif color == 'blue' and remaining(buffSlot,type) / 60 >= 20 then
        ratio = 1
    elseif color == 'blue' and remaining(buffSlot,type) / 60 < 20 then
        ratio = (remaining(buffSlot,type) / 60) / 20
    else
        ratio = 0
    end
    return ratio
end

---@type BuffItem[]
local buffs = {}
---@type BuffItem[]
local songs = {}

local function LoadBuffs()
    for i = 1,47 do  -- made up number?

        ---@type BuffItem
        local buff = {
            slot = i,
            name = name(i, BUFFS),
            denom = denom(i, BUFFS),
            favorite = false
        }

        table.insert(buffs, buff)
    end
end
LoadBuffs()

local function LoadSongs()
    for i = 1,30 do

        ---@type BuffItem
        local song = {
            slot = i,
            name = name(i, SONGS),
            denom = denom(i, SONGS),
            favorite = false
        }

        table.insert(songs, song)
    end
end
LoadSongs()

---@param type BuffType
---@return number
local function HasFavorites(type)
    local buffs = type == BUFFS and favoriteBuffs or favoriteSongs
    if buffs == nil then return 0 end

    local length = 0
    for _, _ in pairs(buffs) do
        length = length + 1
    end
    return length
end

local function ApplyFavorites()
    if HasFavorites(BUFFS) > 0 then
        for _, buffItem in pairs(buffs) do
            for favIndex, favName in pairs(favoriteBuffs) do
                if buffItem.name == favName then
                    buffItem.favorite = true
                end
                if favName == 'zz' then
                    favoriteBuffs[favIndex] = nil
                end
            end
        end
    end
    if HasFavorites(SONGS) > 0 then
        for _, buffItem in pairs(songs) do
            for l,w in pairs(favoriteSongs) do
                if buffItem.name == w then
                    buffItem.favorite = true
                end
                if w == 'zz' then favoriteSongs[l] = nil end
            end
        end
    end
end
ApplyFavorites()

---@param a BuffItem
---@param b BuffItem
---@return boolean
local function SortBySlot(a, b)
    return a.slot - b.slot < 0
end

---@param a BuffItem
---@param b BuffItem
---@return boolean
local function SortByName(a, b)
    local delta = 0
    if a.name < b.name then
        delta = -1
    elseif b.name < a.name then
        delta = 1
    end

    if delta == 0 then
        delta = a.slot - b.slot
    end

    return delta < 0
end

local function UpdateBuffTables()
    local buffsChanged = false
    for _, buffItem in pairs(buffs) do
        if mq.TLO.Me.Buff(buffItem.slot)() then
            if buffItem.name ~= name(buffItem.slot, BUFFS) then
                buffItem.name = name(buffItem.slot, BUFFS)
                buffItem.denom = denom(buffItem.slot, BUFFS)
                buffItem.favorite = false
                buffsChanged = true
            end
        else
            if buffItem.name ~= 'zz' then
                buffItem.name = 'zz'
                buffItem.denom = 0
                buffItem.favorite = false
                buffsChanged = true
            end
        end
    end
    if buffsChanged then
        if sortedBBy == 'name' then
            table.sort(buffs, SortByName)
        elseif sortedBBy == 'slot' then
            table.sort(buffs, SortBySlot)
        end
    end

    local songsChanged = false
    for _, buffItem in pairs(songs) do
        if mq.TLO.Me.Song(buffItem.slot)() then
            if buffItem.name ~= name(buffItem.slot, SONGS) then
                buffItem.name = name(buffItem.slot, SONGS)
                buffItem.denom = denom(buffItem.slot, SONGS)
                buffItem.favorite = false
                songsChanged = true
            end
        else
            if buffItem.name ~= 'zz' then
                buffItem.name = 'zz'
                buffItem.denom = 0
                buffItem.favorite = false
                songsChanged = true
            end
        end
    end
    if songsChanged then
        if sortedSBy == 'name' then
            table.sort(songs, SortByName)
        elseif sortedSBy == 'slot' then
            table.sort(songs, SortBySlot)
        end
    end
end

local function ReIndexFavorites()
    local indexB = 1
    local tmpB = {}
    for _,v in pairs(favoriteBuffs) do
        tmpB[indexB] = v
        indexB = indexB + 1
    end
    favoriteBuffs = tmpB
    local indexS = 1
    local tmpS = {}
    for _,v in pairs(favoriteSongs) do
        tmpS[indexS] = v
        indexS = indexS + 1
    end
    favoriteSongs = tmpS
    SaveSettings()
end

---@param name string
---@param type BuffType
local function MoveFavoriteUp(name, type)
    local list
    if type == BUFFS then list = favoriteBuffs
    elseif type == SONGS then list = favoriteSongs end
    local mover
    local moved
    local moverIdx
    local movedIdx
    for k,v in pairs(list) do
        if v == name then
            if k == 0 then return end
            mover = v
            moved = list[k-1]
            moverIdx = k
            movedIdx = k-1
        end
    end
    list[movedIdx] = mover
    list[moverIdx] = moved
    ReIndexFavorites()
end

---@param name string
---@param type BuffType
local function MoveFavoriteDown(name, type)
    local length = HasFavorites(type)
    local list
    if type == BUFFS then list = favoriteBuffs
    elseif type == SONGS then list = favoriteSongs end
    local mover
    local moved
    local moverIdx
    local movedIdx
    for k,v in pairs(list) do
        if v == name then
            if k == length then return end
            mover = v
            moved = list[k+1]
            moverIdx = k
            movedIdx = k+1
        end
    end
    list[movedIdx] = mover
    list[moverIdx] = moved
    ReIndexFavorites()
end

---@param slot number
---@param type BuffType
local function AddFavorite(slot, type)
    local buffName = name(slot, type)
    if buffName == 'zz' then return end

    if type == BUFFS then
        -- Check that favorite doesn't already exist, then add it
        for _, favName in pairs(favoriteBuffs) do
            if favName == buffName then return end
        end
        table.insert(favoriteBuffs, buffName)

        -- Flag buff as favorite
        for _, item in pairs(buffs) do
            if item.name == buffName then
               item.favorite = true
            end
        end
    elseif type == SONGS then
        -- Check that favorite doesn't already exist, then add it
        for _, favName in pairs(favoriteSongs) do
            if favName == buffName then return end
        end
        table.insert(favoriteSongs, buffName)

        -- Flag buff as favorite
        for _, item in pairs(songs) do
            if item.name == buffName then
               item.favorite = true
            end
        end
    end

    ReIndexFavorites()
end

---@param slot number
---@param type BuffType
local function RemoveFavorite(slot, type)
    local buffName = name(slot, type)

    if type == BUFFS then
        -- Remove from favorites
        for index, favName in pairs(favoriteBuffs) do
            if favName == buffName then
                favoriteBuffs[index] = nil
            end
        end
        -- Unflag buff as favorite
        for _, item in pairs(buffs) do
            if item.name == buffName then
               item.favorite = false
            end
        end
    elseif type == SONGS then
        -- Remove from favorites
        for index, favName in pairs(favoriteSongs) do
            if favName == buffName then favoriteSongs[index] = nil end
        end
        -- Unflag buff as favorite
        for _, item in pairs(songs) do
            if item.name == buffName then
               item.favorite = false
            end
        end
    end

    ReIndexFavorites()
end

---@param name string
---@param type BuffType
local function RemoveFavoritePlaceholder(name, type)
    if type == BUFFS then
        for index, favName in pairs(favoriteBuffs) do
            -- Remove any favorites that match the given name
            if favName == name then
                favoriteBuffs[index] = nil
            end
        end
    elseif type == SONGS then
        for index, favName in pairs(favoriteSongs) do
            -- Remove any favorites that match the given name
            if favName == name then
                favoriteSongs[index] = nil
            end
        end
    end

    ReIndexFavorites()
end

---@param name string
---@param slot number
---@param type BuffType
---@param isFavorite boolean
local function DrawSpellContextMenu(name, slot, type, isFavorite)
    ImGui.SetWindowFontScale(1)
    if ImGui.BeginPopupContextItem('BuffContextMenu') then
        if isFavorite then
            -- Move up and down
            if ImGui.Selectable(string.format('%s Move up', icons.MD_ARROW_DROP_UP)) then MoveFavoriteUp(name, type) end
            if ImGui.Selectable(string.format('%s Move down', icons.MD_ARROW_DROP_DOWN)) then MoveFavoriteDown(name, type) end
            ImGui.Separator()

            -- Toggle favorite
            if ImGui.Selectable(string.format('%s Unfavorite', icons.FA_HEART_O)) then RemoveFavorite(slot, type) end
            ImGui.Separator()
        else
            -- Toggle favorite
            if ImGui.Selectable(string.format('%s Favorite', icons.MD_FAVORITE)) then AddFavorite(slot, type) end
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

---@param name string
---@param type BuffType
local function DrawPlaceholderContextMenu(name, type)
    ImGui.SetWindowFontScale(1)

    if ImGui.BeginPopupContextItem('##nn') then
        if ImGui.Selectable(string.format('%s Move up', icons.MD_ARROW_DROP_UP)) then MoveFavoriteUp(name, type) end
        if ImGui.Selectable(string.format('%s Move down', icons.MD_ARROW_DROP_DOWN)) then MoveFavoriteDown(name, type) end
        ImGui.Separator()

        if ImGui.Selectable(string.format('%s Unfavorite', icons.FA_HEART_O)) then RemoveFavoritePlaceholder(name, type) end

        ImGui.EndPopup()
    end

    ImGui.SetWindowFontScale(settings.font / 10)
end

---Draw an individual buff row in the buff window
---@param item table
---@param buffType BuffType
---@param barColor BarColor
---@param isFavorite boolean
local function DrawBuffRow(item, buffType, barColor, isFavorite)
    local widgetSizes = WIDGET_SIZES[settings.font]
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, widgetSizes.progressBarSpacing)
    ImGui.PushID(item.name)

    if item.name ~= 'zz' then
        -- Update hitcount value
        local hitCount = ''
        local hitCountValue = GetHitCount(item.slot, buffType)
        if hitCountValue ~= 0 then
            hitCount = string.format('[%s] ', hitCountValue)
        end

        -- Draw icon, bar and name
        ImGui.BeginGroup()
            DrawIcon(item.slot, buffType)
            ImGui.SameLine()

            ImGui.PushStyleColor(ImGuiCol.PlotHistogram, COLORS_FROM_NAMES[barColor])
                ImGui.ProgressBar(CalcRatio(item.slot, buffType, item.denom), ImGui.GetContentRegionAvail(), widgetSizes.progressBarHeight, "")
                ImGui.SetCursorPosY(ImGui.GetCursorPosY() - widgetSizes.labelOffset)
                ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                ImGui.Text("%s%s", hitCount, item.name)
            ImGui.PopStyleColor()
        ImGui.EndGroup()

        -- Handle context menu (right click)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
            DrawSpellContextMenu(item.name, item.slot, buffType, isFavorite)
        ImGui.PopStyleVar()

        -- Remove buff if left clicked
        if ImGui.IsItemClicked(ImGuiMouseButton.Left) then
            mq.cmdf('/removebuff %s', item.name)
        end

        -- Hover tooltip includes duration
        if ImGui.IsItemHovered() and item.name ~= 'zz' then
            local hms
            if barColor == 'gray' then
                hms = 'Permanent'
            else
                hms = GetSpell(item.slot,buffType).Duration.TimeHMS() or 0
            end
            ImGui.SetTooltip("%02d %s%s (%s)", item.slot, hitCount, item.name, hms)
        end
    else
        ImGui.TextColored(ImVec4(1, 1, 1, .5), "%02d", item.slot)
    end

    ImGui.PopID()
    ImGui.PopStyleVar()
end

---@param sortBy SortParam
---@param buffType BuffType
---@param filterColor BarColor | nil
local function DrawBuffTable(sortBy, buffType, filterColor)
    -- check if we need to change sort method
    if sortBy == SORT_BY_SLOT then
        if buffType == BUFFS and sortedBBy == 'name' then
            sortedBBy = 'slot'
            table.sort(buffs, SortBySlot)
        elseif buffType == SONGS and sortedSBy == 'name' then
            sortedSBy = 'slot'
            table.sort(songs, SortBySlot)
        end
    elseif sortBy == SORT_BY_NAME then
        if buffType == BUFFS and sortedBBy == 'slot' then
            sortedBBy = 'name'
            table.sort(buffs, SortByName)
        elseif buffType == SONGS and sortedSBy == 'slot' then
            sortedSBy = 'name'
            table.sort(songs, SortByName)
        end
    end

    local spells
    if buffType == BUFFS then
        spells = buffs
    elseif buffType == SONGS then
        spells = songs
    end

    for _, item in pairs(spells) do
        local barColor = GetBarColor(item.slot, buffType)

        if         (buffType == BUFFS and (not settings.hideB or barColor == 'red'))
                or (buffType == SONGS and (not settings.hideS or barColor == 'red'))
        then
            if (       (not item.favorite)
                    or (buffType == BUFFS and (settings.favBShow == FAV_SHOW_DISABLE or settings.favBShow == FAV_SHOW_ONLY_MISSING))
                    or (buffType == SONGS and (settings.favSShow == FAV_SHOW_DISABLE or settings.favSShow == FAV_SHOW_ONLY_MISSING))
                ) and (filterColor == nil or (barColor == filterColor))
            then
                DrawBuffRow(item, buffType, barColor, false)
            end
        end
    end
end

---@param type BuffType
local function DrawFavorites(type)
    if HasFavorites(type) > 0 then
        local spells
        local favs

        if type == BUFFS then
            spells = buffs
            favs = favoriteBuffs
        elseif type == SONGS then
            spells = songs
            favs = favoriteSongs
        end

        local prgHeight = WIDGET_SIZES[settings.font].progressBarHeight
        local prgSpacing = WIDGET_SIZES[settings.font].progressBarSpacing
        local lblOffset = WIDGET_SIZES[settings.font].labelOffset
    
        for _, v in pairs(favs) do
            local index
            for l, w in pairs(spells) do
                if v == w.name then index = l end
            end

            local item = spells[index]
            if item ~= nil then
                local barColor = GetBarColor(item.slot, type)

                if         (type == BUFFS and settings.favBShow ~= FAV_SHOW_ONLY_MISSING and item.name ~= 'zz')
                        or (type == SONGS and settings.favSShow ~= FAV_SHOW_ONLY_MISSING and item.name ~= 'zz') then
                    DrawBuffRow(item, type, barColor, true)
                end

            elseif     (type == BUFFS and settings.favBShow ~= FAV_SHOW_ONLY_ACTIVE)
                    or (type == SONGS and settings.favSShow ~= FAV_SHOW_ONLY_ACTIVE) then

                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, prgSpacing)
                ImGui.PushID(v..'off')
                    ImGui.BeginGroup()
                        A_SpellIcons:SetTextureCell(mq.TLO.Spell(v).SpellIcon())
                        ImGui.DrawTextureAnimation(A_SpellIcons, 17, 17)
                        ImGui.SameLine()
                        ImGui.ProgressBar(0, ImGui.GetContentRegionAvail(), prgHeight, "")
                        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - lblOffset)
                        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 20)
                        ImGui.TextColored(1,1,1,.3,v)
                        ImGui.SetCursorPosY(ImGui.GetCursorPosY() - 19)
                        ImGui.SetCursorPosX(ImGui.GetCursorPosX() + 1)
                        ImGui.TextColored(.5,.5,.5,.5, icons.MD_INDETERMINATE_CHECK_BOX)
                    ImGui.EndGroup()

                    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
                        DrawPlaceholderContextMenu(v,type)
                    ImGui.PopStyleVar()

                ImGui.PopID()
                ImGui.PopStyleVar()
            end
        end
        ImGui.Separator()
    end
end

local alphaSliderChanged = false

---@param type BuffType
local function DrawSettingsMenu(type)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 5)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 4, 0)

    if ImGui.BeginPopupContextItem('Settings Menu') then
        local changed = false

        ImGui.Text('Settings')
        ImGui.Separator()

        if type == BUFFS then
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
                        break
                    end
                end
                ImGui.EndMenu()
            end

            ImGui.Separator()

            ImGui.Text('Favorites')

            settings.favBShow, changed = ImGui.RadioButton('Disable', settings.favBShow, FAV_SHOW_DISABLE)
            if changed then SaveSettings() end

            settings.favBShow, changed = ImGui.RadioButton('Only active', settings.favBShow, FAV_SHOW_ONLY_ACTIVE)
            if changed then SaveSettings() end

            settings.favBShow, changed = ImGui.RadioButton('Only missing', settings.favBShow, FAV_SHOW_ONLY_MISSING)
            if changed then SaveSettings() end

            settings.favBShow, changed = ImGui.RadioButton('Show both', settings.favBShow, FAV_SHOW_BOTH)
            if changed then SaveSettings() end

            ImGui.Separator()

            settings.hideB, changed = ImGui.Checkbox('Hide non-favorites', settings.hideB)
            if changed then SaveSettings() end

        elseif type == SONGS then
            -- Lock window toggle
            settings.lockedS, changed = ImGui.Checkbox('Lock window', settings.lockedS)
            if changed then SaveSettings() end

            -- Show title bar toggle
            settings.titleS, changed = ImGui.Checkbox('Show title bar', settings.titleS)
            if changed then SaveSettings() end

            -- Alpha slider with deferred save
            ImGui.SetNextItemWidth(100)
            settings.alphaS, changed = ImGui.SliderInt('Alpha', settings.alphaS, 0, 100)
            if changed then
                alphaSliderChanged = true
            end
            if alphaSliderChanged == true and ImGui.IsMouseReleased(ImGuiMouseButton.Left) then
                SaveSettings()
                alphaSliderChanged = false
            end

            ImGui.Separator()
            if ImGui.BeginMenu("Font Scale") then
                for _,v in pairs(font_scale) do
                    local checked = settings.font == v.size
                    if ImGui.MenuItem(v.label, nil, checked) then settings.font = v.size SaveSettings() break end
                end
                ImGui.EndMenu()
            end

            ImGui.Separator()
            ImGui.Text('Favorites')

            settings.favSShow, changed = ImGui.RadioButton('Disable', settings.favSShow, FAV_SHOW_DISABLE)
            if changed then SaveSettings() end

            settings.favSShow, changed = ImGui.RadioButton('Only active', settings.favSShow, FAV_SHOW_ONLY_ACTIVE)
            if changed then SaveSettings() end

            settings.favSShow, changed = ImGui.RadioButton('Only missing', settings.favSShow, FAV_SHOW_ONLY_MISSING)
            if changed then SaveSettings() end

            settings.favSShow, changed = ImGui.RadioButton('Show both', settings.favSShow, FAV_SHOW_BOTH)
            if changed then SaveSettings() end

            ImGui.Separator()
            settings.hideS, changed = ImGui.Checkbox('Hide non-favorites', settings.hideS)
            if changed then SaveSettings() end
        end
        ImGui.EndPopup()
    end
    ImGui.PopStyleVar(2)
end

---@param type BuffType
local function DrawTabs(type)
    ImGui.SetWindowFontScale(settings.font / 10)

    if ImGui.BeginTabBar('sortbar') then
        if ImGui.BeginTabItem('Slot') then
            -- Draw favorites
            if (type == BUFFS and settings.favBShow ~= FAV_SHOW_DISABLE) or (type == SONGS and settings.favSShow ~= FAV_SHOW_DISABLE) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                    DrawFavorites(type)
                ImGui.PopStyleVar()
            end

            -- Draw everything else
            DrawBuffTable(SORT_BY_SLOT, type)

            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Name') then
            -- Draw favorites
            if (type == BUFFS and settings.favBShow ~= FAV_SHOW_DISABLE) or (type == SONGS and settings.favSShow ~= FAV_SHOW_DISABLE) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                    DrawFavorites(type)
                ImGui.PopStyleVar()
            end

            -- Draw everything else
            DrawBuffTable(SORT_BY_NAME, type)

            ImGui.EndTabItem()
        end
        if ImGui.BeginTabItem('Type') then
            -- Draw favorites
            if (type == BUFFS and settings.favBShow ~= FAV_SHOW_DISABLE) or (type == SONGS and settings.favSShow ~= FAV_SHOW_DISABLE) then
                ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                    DrawFavorites(type)
                ImGui.PopStyleVar()
            end

            -- Draw everything else by category
            DrawBuffTable(SORT_BY_TYPE, type, 'gray')
            DrawBuffTable(SORT_BY_TYPE, type, 'blue')
            DrawBuffTable(SORT_BY_TYPE, type, 'green')
            DrawBuffTable(SORT_BY_TYPE, type, 'red')
            DrawBuffTable(SORT_BY_TYPE, type, 'none')

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
        ImGui.Button(icons.MD_SETTINGS)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        DrawSettingsMenu(BUFFS)
        ImGui.PopStyleVar()
        ImGui.SameLine()
        DrawTabs(BUFFS)
    ImGui.PopStyleVar(3)

    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(ImVec4(1.0, 1.0, 1.0, 0.7), ' %s', version)
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
        ImGui.Button(icons.MD_SETTINGS)
        ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        DrawSettingsMenu(SONGS)
        ImGui.PopStyleVar()
        ImGui.SameLine()
        DrawTabs(SONGS)
    ImGui.PopStyleVar(3)

    ImGui.SetWindowFontScale(.8)
    ImGui.TextColored(ImVec4(1.0, 1.0, 1.0, 0.7), ' %s', version)
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
    UpdateBuffTables()
    ApplyFavorites()

    mq.delay(100)
end
