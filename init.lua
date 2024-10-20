-- Alphabuff.lua
-- created by Raw
-- refactored by brainiac

local version = '3.5.0'

local mq = require('mq')
local imgui = require('ImGui')
local icons = require('mq.Icons')
local utils = require('utils')

--#region Globals & Constants

---@alias BuffType 0|1
local BUFFS = 0
local SONGS = 1

---@alias SortParam 0|1|2
local SORT_BY_SLOT = 0
local SORT_BY_NAME = 1
local SORT_BY_TYPE = 2

---@alias FavoriteMode 0|1|2|3
local FAV_SHOW_DISABLE = 0
local FAV_SHOW_ONLY_ACTIVE = 1
local FAV_SHOW_ONLY_MISSING = 2
local FAV_SHOW_BOTH = 3

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

---@class FontItem
---@field label string
---@field size number

---@type FontItem[]
local FONT_SCALE = {
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

---@type { [BarColor]: ImVec4 }
local COLORS_FROM_NAMES = {
    red   = ImVec4(0.7, 0.0, 0.0, 0.7),
    gray  = ImVec4(1.0, 1.0, 1.0, 0.2),
    green = ImVec4(0.2, 1.0, 6.0, 0.4),
    none  = ImVec4(0.2, 1.0, 6.0, 0.4),
    blue  = ImVec4(0.2, 0.6, 1.0, 0.4),
}

-- Spell Icons texture used for rendering icons to the window
local A_SpellIcons = mq.FindTextureAnimation('A_SpellIcons')
local LightGrey = ImVec4(1.0, 1.0, 1.0, 0.7)

---@type BuffWindow
local buffWindow
---@type BuffWindow
local songWindow

---@type Settings
local settings

--#endregion

--#region Settings

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
---@field sortBy SortParam
---@field favorites string[]

---@class Settings
---@field buffWindow WindowSettings
---@field songWindow WindowSettings
---@field font integer
---@field showDebugWindow boolean

---@type Settings
local DEFAULT_SETTINGS = {
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
        sortBy = SORT_BY_SLOT,
        favorites = {},
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
        sortBy = SORT_BY_SLOT,
        favorites = {},
    },
    font = 10,
    showDebugWindow = false,
}

---@return Settings
local function MakeDefaults()
    return utils.deepcopy(DEFAULT_SETTINGS)
end

local function GetSettingsFilename()
    return string.format("Alphabuff_%s.lua", mq.TLO.Me.Name())
end

local function SaveSettings()
    mq.pickle(GetSettingsFilename(), settings)
end

---@return Settings
local function LoadSettings()
    local configData, err = loadfile(mq.configDir .. '/'.. GetSettingsFilename())
    local settings

    if err then
        -- Reset to defaults
        settings = MakeDefaults()
        print('\at[Alphabuff]\aw Creating config file...')
    elseif configData then
        print('\at[Alphabuff]\aw Loading config file...')

        local conf = configData()
        if type(conf) ~= 'table' then
            conf = {}
        end

        if conf.settings ~= nil then
            local oldSettings = conf.settings

            -- This is the old format. Convert it into the new format.
            settings = MakeDefaults()
            settings.buffWindow.alpha = oldSettings.alphaB
            settings.buffWindow.title = oldSettings.titleB
            settings.buffWindow.locked = oldSettings.lockedB
            settings.buffWindow.sizeX = oldSettings.sizeBX
            settings.buffWindow.sizeY = oldSettings.sizeBY
            settings.buffWindow.posX = oldSettings.posBX
            settings.buffWindow.posY = oldSettings.posBY
            settings.buffWindow.favShow = oldSettings.favBShow
            settings.buffWindow.hide = oldSettings.hideB
            settings.buffWindow.favorites = conf.favbuffs
            settings.songWindow.alpha = oldSettings.alphaS
            settings.songWindow.title = oldSettings.titleS
            settings.songWindow.locked = oldSettings.lockedS
            settings.songWindow.sizeX = oldSettings.sizeSX
            settings.songWindow.sizeY = oldSettings.sizeSY
            settings.songWindow.posX = oldSettings.posSX
            settings.songWindow.posY = oldSettings.posSY
            settings.songWindow.favShow = oldSettings.favSShow
            settings.songWindow.hide = oldSettings.hideS
            settings.songWindow.favorites = conf.favsongs
            settings.font = oldSettings.font
        else
            settings = conf
        end

        -- Fill in any blanks
        if type(settings.font) ~= 'number' or settings.font < 8 or settings.font > 11 then
            settings.font = DEFAULT_SETTINGS.font
        end
        if type(settings.showDebugWindow) ~= 'boolean' then
            settings.showDebugWindow = DEFAULT_SETTINGS.showDebugWindow
        end
        for _, window in ipairs({"buffWindow", "songWindow"}) do
            local src = DEFAULT_SETTINGS[window] --[[@as WindowSettings]]
            local dst = settings[window] --[[@as WindowSettings]]
            for k, v in pairs(src) do
                if dst[k] == nil or type(dst[k]) ~= type(src[k]) then dst[k] = v end
            end
        end
    end

    return settings
end

--#endregion

--#region BuffItem

---@alias BarColor 'red'|'gray'|'green'|'none'|'blue'

---@class BuffItem
---@field slot number
---@field type BuffType
---@field name string
---@field denom number
---@field buff MQBuff
---@field valid boolean
---@field remaining number
---@field duration number
---@field barColor BarColor
---@field hitCount number
---@field spellIcon number | nil
---@field ratio number
local BuffItem     = {}
BuffItem.__index   = BuffItem
BuffItem.name      = nil
BuffItem.denom     = 0
BuffItem.favorite  = false
BuffItem.valid     = false
BuffItem.remaining = 0
BuffItem.duration  = 0
BuffItem.hitCount  = 0
BuffItem.spellIcon = nil
BuffItem.ratio     = 0
BuffItem.barColor = 'none'

---@param slot number
---@param type BuffType
function BuffItem.new(slot, type)
    local newItem = setmetatable({}, BuffItem)
    newItem.slot = slot
    newItem.type = type
    newItem.buff = newItem:_GetSpell()
    newItem.valid = false
    newItem:Update()

    return newItem
end

---@return boolean changed
function BuffItem:Update()
    local changed = false
    local name = self.buff.Name()
    if name ~= self.name then
        self.valid = (name ~= nil)
        self.name = name
        self.duration = self:_GetDuration()
        self.remaining = self:_GetRemaining()
        self.denom = math.max(self.duration, self.remaining)
        self.hitCount = self.buff.HitCount()
        self.spellIcon = self.buff.SpellIcon()
        self.barColor = self:_GetBarColor()
        self.ratio = self:_CalcRatio()
        self.favorite = false  -- will need to be re-applied
        changed = true
    else
        local remaining = self:_GetRemaining()
        if remaining ~= self.remaining then
            self.remaining = remaining
            self.duration = self:_GetDuration()
            self.denom = math.max(self.duration, self.remaining)
            self.barColor = self:_GetBarColor()
            self.ratio = self:_CalcRatio()
            changed = true
        end

        local hitCount = self.buff.HitCount() or 0
        if hitCount ~= self.hitCount then
            self.hitCount = hitCount
            changed = true
        end
    end

    return changed
end

---@private
---@return MQBuff
function BuffItem:_GetSpell()
    if self.type == BUFFS then
        return mq.TLO.Me.Buff(self.slot)
    else
        return mq.TLO.Me.Song(self.slot)
    end
end

---@private
---@return number
function BuffItem:_GetRemaining()
    local remaining = self.buff.Duration() or 0
    remaining = remaining / 1000
    local trunc = tonumber(string.format("%.0f",remaining))
    return trunc or 0
end

---@private
---@return number
function BuffItem:_GetDuration()
    return self.buff.MyDuration.TotalSeconds() or 0
end

---Get appropriate bar color for a given buff
---@private
---@return BarColor
function BuffItem:_GetBarColor()
    if self.buff.SpellType() == 'Detrimental' then
        return 'red'
    end

    if self.duration < 0 or self.duration > 36000 then
        return 'gray'
    end
    if self.duration > 0 and self.duration < 1200 then
        return 'green'
    end
    if self.duration == 0 then
        return 'none'
    end

    return 'blue'
end

---@private
---@return number
function BuffItem:_CalcRatio()
    if self.barColor == 'gray' then
        return 1
    end

    if self.barColor == 'green' or self.barColor == 'red' then
        return self.remaining / self.denom
    end

    if self.barColor == 'blue' then
        local remaining = self.remaining / 60
        if remaining >= 20 then
            return 1
        end
        return remaining / 20
    end

    return 0
end

function BuffItem:DrawIcon()
    if self.spellIcon ~= nil then
        A_SpellIcons:SetTextureCell(self.spellIcon)
        imgui.DrawTextureAnimation(A_SpellIcons, 17, 17)
    end
end

--#endregion BuffItem

--#region BuffWindow

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
    if a.name == b.name then return a.slot - b.slot < 0 end
    if a.name == nil then return false end
    if b.name == nil then return true end

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

---@class BuffWindow
---@field title string
---@field type BuffType
---@field buffs BuffItem[]
---@field favorites string[]
---@field favoritesMap { [string]: number }
---@field settings WindowSettings
---@field alphaSliderChanged boolean
---@field onLoad boolean
---@field open boolean
---@field show boolean
---@field windowFlags number
---@field maxBuffs number
local BuffWindow     = {}
BuffWindow.__index   = BuffWindow

---@param title string
---@param type BuffType
---@param windowSettings WindowSettings
function BuffWindow.new(title, type, windowSettings, maxBuffs)
    local newWindow = setmetatable({}, BuffWindow)

    local toon = mq.TLO.Me.Name() or ''
    local server = mq.TLO.EverQuest.Server() or ''
    newWindow.title = string.format("%s##%s_%s", title, server, toon)
    newWindow.type = type
    newWindow.settings = windowSettings
    newWindow.favorites = windowSettings.favorites
    newWindow.alphaSliderChanged = false
    newWindow.onLoad = true
    newWindow.open = true
    newWindow.show = true
    newWindow.windowFlags = newWindow:CalculateWindowFlags()
    newWindow.maxBuffs = maxBuffs or 15

    -- Create mapping of favorites
    newWindow.favoritesMap = {}
    for index, favorite in ipairs(newWindow.favorites) do
        newWindow.favoritesMap[favorite] = index
    end

    -- Load all buffs from the game data
    newWindow:LoadBuffs()

    return newWindow
end

function BuffWindow:CalculateWindowFlags()
    -- build flags for the window based on settings
    local windowFlags = bit32.bor(
        ImGuiWindowFlags.NoFocusOnAppearing,
        (not self.settings.title) and ImGuiWindowFlags.NoTitleBar or 0,
        self.settings.locked and bit32.bor(ImGuiWindowFlags.NoMove, ImGuiWindowFlags.NoResize) or 0
    )
    
    return windowFlags
end

function BuffWindow:LoadBuffs()
    self.buffs = {}
    for i = 1, self.maxBuffs do
        local newBuff = BuffItem.new(i, self.type)
        if newBuff.valid then
            newBuff.favorite = self.favoritesMap[newBuff.name] ~= nil
        end
        table.insert(self.buffs, newBuff)
    end
end

function BuffWindow:UpdateBuffs()
    local buffsChanged = false

    for _, item in ipairs(self.buffs) do
        if item:Update() then
            if item.name ~= nil then
                item.favorite = self.favoritesMap[item.name] ~= nil
            else
                item.favorite = false
            end
            buffsChanged = true
        end
    end

    if buffsChanged then
        self:SortBuffs()
    end
end

function BuffWindow:SortBuffs()
    if self.settings.sortBy == SORT_BY_NAME then
        table.sort(self.buffs, SortByName)
    elseif self.settings.sortBy == SORT_BY_SLOT then
        table.sort(self.buffs, SortBySlot)
    end
end

function BuffWindow:SetSortMethod(sortBy)
    self.settings.sortBy = sortBy
    self:SortBuffs()
end

---@param name string
function BuffWindow:MoveFavoriteUp(name)
    local index = self.favoritesMap[name]
    if index == nil then return end
    if index <= 1 then return end
    local newIndex = index - 1
    self.favoritesMap[self.favorites[newIndex]] = index
    self.favoritesMap[name] = newIndex
    table.remove(self.favorites, index)
    table.insert(self.favorites, newIndex, name)

    SaveSettings()
end

---@param name string
function BuffWindow:MoveFavoriteDown(name)
    local index = self.favoritesMap[name]
    if index == nil then return end
    if index >= #self.favorites then return end
    local newIndex = index + 1
    self.favoritesMap[self.favorites[newIndex]] = index
    self.favoritesMap[name] = newIndex
    table.remove(self.favorites, index)
    table.insert(self.favorites, newIndex, name)

    SaveSettings()
end

---@param name string
function BuffWindow:AddFavorite(name)
    if self.favoritesMap[name] ~= nil then return end
    table.insert(self.favorites, name)
    self.favoritesMap[name] = #self.favorites

    -- Check for buffs that match
    for _, item in ipairs(self.buffs) do
        if item.name == name then
            item.favorite = true
        end
    end

    SaveSettings()
end

---@param name string
function BuffWindow:RemoveFavorite(name)
    local index = self.favoritesMap[name]
    if index == nil then return end
    table.remove(self.favorites, index)
    self.favoritesMap[name] = nil
    for i = index, #self.favorites do
        self.favoritesMap[self.favorites[i]] = i
    end

    -- Check for buffs that match
    for _, item in ipairs(self.buffs) do
        if item.name == name then
            item.favorite = false
        end
    end

    SaveSettings()
end

---@param item BuffItem
function BuffWindow:DrawSpellContextMenu(item)
    imgui.SetWindowFontScale(1)
    if imgui.BeginPopupContextItem('BuffContextMenu') then
        if item.favorite then
            -- Move up and down
            imgui.BeginDisabled(self.favoritesMap[item.name] <= 1)
            if imgui.Selectable(string.format('%s Move up', icons.FA_CHEVRON_UP)) then self:MoveFavoriteUp(item.name) end
            imgui.EndDisabled()
            imgui.BeginDisabled(self.favoritesMap[item.name] >= #self.favorites)
            if imgui.Selectable(string.format('%s Move down', icons.FA_CHEVRON_DOWN)) then self:MoveFavoriteDown(item.name) end
            imgui.EndDisabled()
            imgui.Separator()

            -- Toggle favorite
            if imgui.Selectable(string.format('%s Unfavorite', icons.FA_HEART_O)) then
                self:RemoveFavorite(item.name)
            end
            imgui.Separator()
        else
            -- Toggle favorite
            if imgui.Selectable(string.format('%s Favorite', icons.MD_FAVORITE)) then
                self:AddFavorite(item.name)
            end
            imgui.Separator()
        end

        -- Inspect spell (open spell display window)
        if imgui.Selectable(string.format('%s Inspect', icons.MD_SEARCH)) then
            item.buff.Inspect()
        end

        -- Remove the buff
        if imgui.Selectable(string.format('%s Remove', icons.MD_DELETE)) then
            mq.cmdf('/removebuff %s', item.name)
        end
        imgui.Separator()

        -- Block the buff
        if imgui.Selectable(string.format('%s Block spell', icons.MD_CLOSE)) then
            mq.cmdf('/blockspell add me %s', item.buff.ID())
        end

        imgui.EndPopup()
    end
    imgui.SetWindowFontScale(settings.font / 10)
end

---@param name string
function BuffWindow:DrawPlaceholderContextMenu(name)
    imgui.SetWindowFontScale(1)

    if imgui.BeginPopupContextItem('BuffContextMenuPlaceholder') then
        -- Move up and down
        imgui.BeginDisabled(self.favoritesMap[name] <= 1)
        if imgui.Selectable(string.format('%s Move up', icons.FA_CHEVRON_UP)) then self:MoveFavoriteUp(name) end
        imgui.EndDisabled()
        imgui.BeginDisabled(self.favoritesMap[name] >= #self.favorites)
        if imgui.Selectable(string.format('%s Move down', icons.FA_CHEVRON_DOWN)) then self:MoveFavoriteDown(name) end
        imgui.EndDisabled()
        imgui.Separator()

        -- Inspect spell (open spell display window)
        if imgui.Selectable(string.format('%s Inspect', icons.MD_SEARCH)) then
            mq.TLO.Spell(name).Inspect()
        end
        imgui.Separator()

        if imgui.Selectable(string.format('%s Unfavorite', icons.FA_HEART_O)) then self:RemoveFavorite(name) end

        imgui.EndPopup()
    end

    imgui.SetWindowFontScale(settings.font / 10)
end

---Draw an individual buff row in the buff window
---@param item BuffItem
function BuffWindow:DrawBuffRow(item)
    local widgetSizes = WIDGET_SIZES[settings.font]
    imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, widgetSizes.progressBarSpacing)
    imgui.PushID(item.slot)

    if item.valid then
        -- Update hitcount value
        local hitCountStr = ''
        if item.hitCount ~= 0 then
            hitCountStr = string.format('[%s] ', item.hitCount)
        end

        -- Draw icon, bar and name
        imgui.BeginGroup()
            item:DrawIcon()
            imgui.SameLine()

            imgui.PushStyleColor(ImGuiCol.PlotHistogram, COLORS_FROM_NAMES[item.barColor])
                imgui.ProgressBar(item.ratio, imgui.GetContentRegionAvail(), widgetSizes.progressBarHeight, "")
                imgui.SetCursorPosY(imgui.GetCursorPosY() - widgetSizes.labelOffset)
                imgui.SetCursorPosX(imgui.GetCursorPosX() + 20)
                imgui.Text("%s%s", hitCountStr, item.name)
            imgui.PopStyleColor()
        imgui.EndGroup()

        -- Handle context menu (right click)
        imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
            self:DrawSpellContextMenu(item)
        imgui.PopStyleVar()

        -- Remove buff if left clicked
        if imgui.IsItemClicked(ImGuiMouseButton.Left) then
            mq.cmdf('/removebuff %s', item.name)
        end

        -- Hover tooltip includes duration
        if imgui.IsItemHovered() and item.valid then
            local hms
            if item.barColor == 'gray' then
                hms = 'Permanent'
            else
                hms = item.buff.Duration.TimeHMS() or 0
            end
            imgui.SetTooltip("%02d %s%s (%s)", item.slot, hitCountStr, item.name, hms)
        end
    else
        imgui.TextColored(ImVec4(1, 1, 1, .5), "%02d", item.slot)
    end

    imgui.PopID()
    imgui.PopStyleVar()
end

---@param name string
function BuffWindow:DrawPlaceholderRow(name)
    local widgetSizes = WIDGET_SIZES[settings.font]

    imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, widgetSizes.progressBarSpacing)
    imgui.PushID(name)
        imgui.BeginGroup()
            local spellIcon = mq.TLO.Spell(name).SpellIcon()
            if spellIcon ~= nil then
                A_SpellIcons:SetTextureCell(spellIcon)
            end
            imgui.DrawTextureAnimation(A_SpellIcons, 17, 17)
            imgui.SameLine()
            imgui.ProgressBar(0, imgui.GetContentRegionAvail(), widgetSizes.progressBarHeight, "")
            imgui.SetCursorPosY(imgui.GetCursorPosY() - widgetSizes.labelOffset)
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 20)
            imgui.TextColored(1, 1, 1, .3, name)
            imgui.SetCursorPosY(imgui.GetCursorPosY() - 19)
            imgui.SetCursorPosX(imgui.GetCursorPosX() + 1)
            imgui.TextColored(.5, .5, .5, .5, icons.MD_INDETERMINATE_CHECK_BOX)
        imgui.EndGroup()

        imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, 8, 8)
            self:DrawPlaceholderContextMenu(name)
        imgui.PopStyleVar()

    imgui.PopID()
    imgui.PopStyleVar()
end

---@param sortBy SortParam
---@param filterColor BarColor | nil
function BuffWindow:DrawBuffTable(sortBy, filterColor)
    if sortBy ~= self.settings.sortBy and sortBy ~= SORT_BY_TYPE then
        self:SetSortMethod(sortBy)
    end

    for _, item in ipairs(self.buffs) do
        if not self.settings.hide or item.barColor == 'red' then
            if (not item.favorite or self.settings.favShow == FAV_SHOW_DISABLE or self.settings.favShow == FAV_SHOW_ONLY_MISSING)
                and (filterColor == nil or item.barColor == filterColor)
            then
                self:DrawBuffRow(item)
            end
        end
    end
end

---@param name string
---@return BuffItem|nil
function BuffWindow:GetBuffByName(name)
    for _, item in ipairs(self.buffs) do
        if item.name == name then
            return item
        end
    end
    return nil
end

function BuffWindow:DrawFavorites()
    if #self.favorites == 0 then return end

    imgui.PushID("Favorites")

    for _, favName in ipairs(self.favorites) do
        local item = self:GetBuffByName(favName)
        if item ~= nil then
            if self.settings.favShow ~= FAV_SHOW_ONLY_MISSING then
                self:DrawBuffRow(item)
            end
        else
            if self.settings.favShow ~= FAV_SHOW_ONLY_ACTIVE then
                self:DrawPlaceholderRow(favName)
            end
        end
    end

    imgui.PopID()

    imgui.Separator()
end

function BuffWindow:DrawSettingsMenu()
    imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 8, 5)
    imgui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 4, 0)

    if imgui.BeginPopupContextItem('Settings Menu') then
        local changed = false

        imgui.Text('Settings')
        imgui.Separator()

        -- Lock window toggle
        self.settings.locked, changed = imgui.Checkbox('Lock window', self.settings.locked)
        if changed then
            self.windowFlags = self:CalculateWindowFlags()
            SaveSettings()
        end

        -- Show titlebar toggle
        self.settings.title, changed = imgui.Checkbox('Show title bar', self.settings.title)
        if changed then
            self.windowFlags = self:CalculateWindowFlags()
            SaveSettings()
        end

        -- Alpha slider with deferred save
        imgui.SetNextItemWidth(100)
        self.settings.alpha, changed = imgui.SliderInt('Alpha', self.settings.alpha, 0, 100)
        if changed then
            self.alphaSliderChanged = true
        end
        if self.alphaSliderChanged and imgui.IsMouseReleased(ImGuiMouseButton.Left) then
            self.alphaSliderChanged = false
            SaveSettings()
        end

        imgui.Separator()
        if imgui.BeginMenu("Font Scale") then
            for _, v in ipairs(FONT_SCALE) do
                local checked = settings.font == v.size
                if imgui.MenuItem(v.label, nil, checked) then
                    settings.font = v.size
                    SaveSettings()
                    break
                end
            end
            imgui.EndMenu()
        end

        imgui.Separator()

        imgui.Text('Favorites')

        self.settings.favShow, changed = imgui.RadioButton('Disable', self.settings.favShow, FAV_SHOW_DISABLE)
        if changed then SaveSettings() end

        self.settings.favShow, changed = imgui.RadioButton('Only active', self.settings.favShow, FAV_SHOW_ONLY_ACTIVE)
        if changed then SaveSettings() end

        self.settings.favShow, changed = imgui.RadioButton('Only missing', self.settings.favShow, FAV_SHOW_ONLY_MISSING)
        if changed then SaveSettings() end

        self.settings.favShow, changed = imgui.RadioButton('Show both', self.settings.favShow, FAV_SHOW_BOTH)
        if changed then SaveSettings() end

        imgui.Separator()

        self.settings.hide, changed = imgui.Checkbox('Hide non-favorites', self.settings.hide)
        if changed then SaveSettings() end

        imgui.EndPopup()
    end
    imgui.PopStyleVar(2)
end

function BuffWindow:DrawTabs()
    imgui.SetWindowFontScale(settings.font / 10)

    if imgui.BeginTabBar('sortbar') then
        local sortMethod = self.settings.sortBy

        if imgui.BeginTabItem('Slot') then
            sortMethod = SORT_BY_SLOT
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem('Name') then
            sortMethod = SORT_BY_NAME
            imgui.EndTabItem()
        end
        if imgui.BeginTabItem('Type') then
            sortMethod = SORT_BY_TYPE
            imgui.EndTabItem()
        end

        -- Draw favorites
        if self.settings.favShow ~= FAV_SHOW_DISABLE then
            imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 7)
                self:DrawFavorites()
            imgui.PopStyleVar()
        end

        -- Draw non-favorites
        if sortMethod ~= SORT_BY_TYPE then
            self:DrawBuffTable(sortMethod)
        else
            -- Draw everything individually by category
            self:DrawBuffTable(sortMethod, 'gray')
            self:DrawBuffTable(sortMethod, 'blue')
            self:DrawBuffTable(sortMethod, 'green')
            self:DrawBuffTable(sortMethod, 'red')
            self:DrawBuffTable(sortMethod, 'none')
        end

        imgui.EndTabBar()
    end

    imgui.SetWindowFontScale(1)
end

function BuffWindow:Draw()
    imgui.SetNextWindowBgAlpha(self.settings.alpha / 100)

    self.open, self.show = imgui.Begin(self.title, self.open, self.windowFlags)
    if self.show then
        -- First time set the position from our settings.
        if self.onLoad then
            imgui.SetWindowSize(self.settings.sizeX, self.settings.sizeY)
            imgui.SetWindowPos(self.settings.posX, self.settings.posY)
            self.onLoad = false
        end

        local windowWidth, windowHeight = imgui.GetWindowSize()
        if self.settings.sizeX ~= windowWidth or self.settings.sizeY ~= windowHeight then
            self.settings.sizeX, self.settings.sizeY = windowWidth, windowHeight
            SaveSettings()
        end

        local windowPosX, windowPosY = imgui.GetWindowPos()
        if self.settings.posX ~= windowPosX or self.settings.posY ~= windowPosY then
            self.settings.posX, self.settings.posY = windowPosX, windowPosY
            SaveSettings()
        end

        imgui.SetWindowFontScale(1)
        imgui.PushStyleVar(ImGuiStyleVar.FramePadding, 8, 4)
        imgui.PushStyleVar(ImGuiStyleVar.ItemInnerSpacing, 1, 4)
        imgui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 3)

        imgui.Button(icons.MD_SETTINGS)
        imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
        self:DrawSettingsMenu()
        imgui.PopStyleVar()
        imgui.SameLine()
        self:DrawTabs()

        imgui.PopStyleVar(3)

        imgui.SetWindowFontScale(.8)
        imgui.TextColored(LightGrey, ' v%s', version)
        imgui.SetWindowFontScale(1)
    end

    imgui.End()
end

--#endregion

local function UpdateImGui()
    imgui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    imgui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    imgui.PushStyleVar(ImGuiStyleVar.ScrollbarSize, 5)

    if buffWindow.open then
        buffWindow:Draw()
    end

    if songWindow.open then
        songWindow:Draw()
    end

    imgui.PopStyleVar(3)

    if settings.showDebugWindow then
        local show
        imgui.SetNextWindowSize(ImVec2(600, 400), ImGuiCond.FirstUseEver)
        settings.showDebugWindow, show = imgui.Begin('Alphabuff Debug Window', settings.showDebugWindow)
        if not settings.showDebugWindow then
            SaveSettings()
        elseif show then
            local debugTable = {
                settings = settings,
                buffWindow = buffWindow,
                songWindow = songWindow,
            }
            utils.drawTableTree(debugTable)
        end
        imgui.End()
    end
end

---@param cmd string
local function ToggleWindowsCommand(cmd)
    if cmd == 'buff' then
        buffWindow.open = not buffWindow.open
    elseif cmd == 'song' then
        songWindow.open = not songWindow.open
    elseif cmd == 'debug' then
        settings.showDebugWindow = not settings.showDebugWindow
        SaveSettings()
    else
        print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')
    end
end

--
-- Main entry point
--

print('\at[Alphabuff]\aw Use \ay /ab buff\aw and\ay /ab song\aw to toggle windows.')
settings = LoadSettings()
SaveSettings()

buffWindow = BuffWindow.new("Alphabuff", BUFFS, settings.buffWindow, mq.TLO.Me.MaxBuffSlots())
songWindow = BuffWindow.new("Alphasong", SONGS, settings.songWindow, 30)

mq.imgui.init('Alphabuff', UpdateImGui)
mq.bind('/ab', ToggleWindowsCommand)

while mq.TLO.MacroQuest.GameState() == 'INGAME' do
    buffWindow:UpdateBuffs()
    mq.delay(200)
    songWindow:UpdateBuffs()
    mq.delay(200)
end
