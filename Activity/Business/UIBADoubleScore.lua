local PlayerData = require "Data.PlayerData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"
local preUpdateTime = -999
local base = require "UI.UILuaBase"
local M = base:Extend()



--[[双倍积分奖励]]

function M:Awake()
    base.Awake(self)
    
    self.textTime=self:FindText("Offset/Time/TimeText")
    self.btnGo=self:FindGameObject("Offset/Button/")
    self.descText=self:FindText("Offset/DescText")
    self.descImage=self:FindImage("Offset/DescImage/Image (1)")
    self.descImage2=self:FindImage("Offset/DescImage/Image (2)")
    UguiLuaEvent.ButtonClick( self.btnGo.gameObject, self, M.OnClickGo)
end

function M:Show()
	base.Show(self)
    --self:ResetData()
    if self.data.id then
		self.businessTab = BusinessActivityTable[self.data.id]
    end
    
    self:ResetData()
end

--点击跳转事件
function M:OnClickGo()
    -- body
    if self.businessTab and self.businessTab.goMenuID then
		local MenuEventManager = require "Manager.MenuEventManager"
		MenuEventManager.DoMenu(self.businessTab.goMenuID)
	end
end

function M:ResetData()
    -- body
    --活动描述
    self.descText.text=self.businessTab.desc
    --时间
    self.endTime = BusinessData.GetEndTime(self.data.id)
    local imgIcon = self.businessTab.param2.name
    local imgIcon2 = self.businessTab.param2.name2
	--local titleTab = excelLoader.TitleTable[titleid]
    UITools.SetImageIcon(self.descImage, Const.atlasName.Activity, imgIcon)
    UITools.SetImageIcon(self.descImage2, Const.atlasName.Activity, imgIcon2)
end

function M:Update()
    base.Update(self)
	if Time.time - preUpdateTime < 1 then
		return
	end
	preUpdateTime = Time.time
	local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
	self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
end
return M