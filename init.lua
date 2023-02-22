--Alphabuff.lua
--by Rawmotion
local version = '1.5.0'
---@type Mq
local mq = require('mq')
---@type ImGui
require('ImGui')

local sortedBy
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
    local current = mq.TLO.Me.Buff(b).Duration() or 0
    local scurrent = mq.TLO.Me.Buff(b).MyDuration() or 0
    current = current / 1000 --to seconds
    scurrent = scurrent * 6 --to seconds
    winner = math.max(current, scurrent)
    return winner
end

local color
local function calcRatio(s,d)
    local ratio
    local current = mq.TLO.Me.Buff(s).Duration() or 0
    local scurrent = mq.TLO.Me.Buff(s).MyDuration() or 0
    current = current / 1000 --to seconds
    scurrent = scurrent * 6 --to seconds
    if scurrent == -6 or scurrent > 36000 then --Permanent, or close enough
        ratio = 1
        color = 'gray'
    elseif scurrent <= 1200 then --a short buff that lasts less than 20 min
        ratio = current / d
        color = 'green'
    elseif current / 60 > 20 then --a buff that currently has more than 20 minutes shows 100%
        ratio = 1
        color = 'blue'
    else --a buff that lasts more than 20 minutes but has less that 20min remaining
        ratio = (current / 60) / 20
        color = 'blue'
    end
    return ratio
end

local buffs = {}
local function loadBuffs()
    for i = 1,42 do
        local name
        local duration --seconds
        if mq.TLO.Me.Buff(i)() then
            name = mq.TLO.Me.Buff(i)()
            if mq.TLO.Me.Buff(i).Duration() < 300 then
                duration = 0
            else
                duration = calcDuration(i)
            end
        else
            name = 'zz'
            duration = 0
        end
        local buff = {
            slot = i,
            name = name,
            duration = duration }
        table.insert(buffs, buff)
    end
end
loadBuffs()

local function updateBuffs()
    for k,v in pairs(buffs) do
        if mq.TLO.Me.Buff(v.slot)() then
            if v.name ~= mq.TLO.Me.Buff(k)() then
                v.name = mq.TLO.Me.Buff(v.slot)()
                if mq.TLO.Me.Buff(v.slot).Duration() < 300 then
                    v.duration = 0
                else
                    v.duration = calcDuration(v.slot)
                end
                if sortedBy == 'name' then table.sort(buffs, sortName) else table.sort(buffs, sortSlot) end
            end
        else
            if v.name ~= 'zz' then
                v.name = 'zz'
                v.duration = 0
                if sortedBy == 'name' then table.sort(buffs, sortName) else table.sort(buffs, sortSlot) end
            end
        end
    end
end

local Open, ShowUI = true, true
local anim = mq.FindTextureAnimation('A_SpellIcons')
local function buildWindow()
    ImGui.SetWindowSize(200, 925, ImGuiCond.Once)
    local x,y = ImGui.GetContentRegionAvail()
    local halfWidth = x/2
    ImGui.SetWindowFontScale(1)
    ImGui.PushStyleVar(ImGuiStyleVar.FramePadding, 0,0)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 1)
    if ImGui.Button('By slot', halfWidth, 20) then table.sort(buffs, sortSlot) end
    ImGui.SameLine()
    if ImGui.Button('By name', halfWidth, 20) then table.sort(buffs, sortName) end
    ImGui.PopStyleVar(2)
    for k,v in pairs(buffs) do
        local buff = buffs[k]
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
        ratio = calcRatio(buff.slot, buff.duration)
        else 
            ratio = .05
        end 
        ImGui.BeginGroup()
        ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 1, 4)
        getIcon()
        ImGui.SameLine()
        if buff.name ~= 'zz' then
            if mq.TLO.Me.Buff(buff.slot).SpellType() == 'Detrimental' then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .7, 0, 0, .7)
            elseif color == 'green' then
                ImGui.PushStyleColor(ImGuiCol.PlotHistogram, .2, 1, 6, .4)
            elseif color == 'gray' then
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
        local hms = mq.TLO.Me.Buff(buff.slot).Duration.TimeHMS() or 0
        if (ImGui.IsItemHovered()) and buff.name ~= 'zz' then ImGui.SetTooltip(string.format("%02d", buff.slot)..' '..buff.name..' ('..hms..')') end
        ImGui.PopID()
    end
end

local function ab()
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 0, 1)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 12)
    Open, ShowUI = ImGui.Begin('Alphabuff '..version, Open)
    ImGui.PopStyleVar(2)
    if ShowUI then buildWindow() end
    ImGui.End()
end

mq.imgui.init('Alphabuff', ab)

local terminate = false
while not terminate do
    updateBuffs()
    mq.delay(250)
	if not Open then return end
end