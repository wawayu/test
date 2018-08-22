local ActivityTable = require "Excel.ActivityTable"
local RecordTable = require "Excel.RecordTable"
local SettingTable = require "Excel.SettingTable"
local RewardTable = require "Excel.RewardTable"
local ActivityCalendarTable = require "Excel.ActivityCalendarTable"
local ConfRule = require "ConfRule"
local TimeSync = require "TimeSync"

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")

local base = require "UI.UILuaBase"
local M = base:Extend()

local openParams = nil

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true
local notifPosition = Vector3.New(35, 30, 0)
local getType = 0


local panelNames = {}
for i = 1, 3 do
    panelNames[i] = string.format("Offset/Panel%s", i)
end

M.childPanelConfig = {
    [panelNames[1]] = "UI.Activity.UIActInfo",--活动
    [panelNames[2]] = "UI.Activity.UIActMustDo",--每日必做
    [panelNames[3]] = "UI.Activity.UIActWeek",--周历
}

function M.Open(params)
	openParams = params or {}
    
    uiMgr.ShowAsync("UIActivity")
end

function M:Awake()
	base.Awake(self)

	self.offsetGameObject = self:FindGameObject("Offset")

	local onCallback = function(_idx)
        self:ShowChildPanelByIndex(_idx)
    end
	self.toggles = UITools.BindTogglesEvent(self:FindTransform("Offset/ToggleGroup"), #panelNames, onCallback)

	self.btnClose = self:FindGameObject("Offset/ButtonClose")
	UguiLuaEvent.ButtonClick(self.btnClose, self, M.CloseUI)
end

function M:Show()
    base.Show(self)
    self.curSelectPanel = openParams.panel or 1

    self:TweenOpen(self.offsetGameObject)

    self:ResetData()
end

function M:GetChildUI(panelindex)
    local panelPath = panelNames[panelindex]
    if panelPath ~= nil then
        return self.childs[panelPath]
    end

    return nil
end

function M:CloseUI()
    self.curSelectPanel = 1
    local reset=self:GetChildUI(1)
    reset:ResetSelect()
    self:Hide()
end

function M:ResetData()
    UITools.SetToggleOnIndex(self.toggles, self.curSelectPanel)
    self:UpdateNotify()
end

function M:ShowChildPanelByIndex(index)
    self.curSelectPanel = index
    local panelPath = panelNames[index]
    if panelPath ~= nil then
        local child = self.childs[panelPath]
        --当前面板show，其他面板hide
        self:ShowSingleChild(child)
    end
end

function M:UpdateNotify()
    --添加红点
    local must = self:FindGameObject("Offset/ToggleGroup/Toggle (2)")
    notifyMgr.AddNotify(must, dataMgr.ActMustDoData.IsMustDoNotify(), notifPosition, notifyMgr.NotifyType.Common)    
end

--本地监听
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
        self:UpdateNotify()
    end
end

return M