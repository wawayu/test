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

function M:Open()
    local id
    if dataMgr.BusinessData.IsGroupOpen(Const.BAGROUP_LUCKY_EQUIP) then
        id =Const.BAGROUP_LUCKY_EQUIP
    elseif dataMgr.BusinessData.IsGroupOpen(Const.BAGROUP_LUCKY_ARTIFACT) then
        id =Const.BAGROUP_LUCKY_ARTIFACT   
    end
    OpenUI("UIBusinessActivity",{bid = id})
end

--[[双倍积分奖励]]

function M:Awake()
    base.Awake(self)
    
    self.textTime=self:FindText("Offset/Time/TimeText")
    self.btnGo=self:FindGameObject("Offset/Button")
    self.descText=self:FindText("Offset/DescText")
    -- self.descImage=self:FindImage("Offset/DescImage/Image (1)")
    self.descImage2=self:FindImage("Offset/DescImage/Image (2)")
    self.btnText = self:FindText("Offset/Button/Text")
    UguiLuaEvent.ButtonClick( self.btnGo, self, M.OnClickGo)
end

function M:Show()
	base.Show(self)
    --self:ResetData()
    
    if self.data.id then
		self.businessTab = BusinessActivityTable[self.data.id]
    end
    
    if not self.data.id or not self.businessTab then
		return
	end
    
    self.script = BusinessData.GetScript(self.data.id)




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
    local isOpen, index, openid = self.script:IsLuckyDayeOpen()
	if not isOpen then
		return
	end

    self.endTime = BusinessData.GetEndTime(openid)
    --活动描述
    self.descText.text=self.businessTab.desc
    self.btnText.text = self.businessTab.buttonname
    --时间
    -- self.endTime = BusinessData.GetEndTime(self.data.id)

    local imgIcon2 = self.businessTab.param2.name
    -- local imgIcon2 = self.businessTab.param2.name2
	--local titleTab = excelLoader.TitleTable[titleid]
    -- UITools.SetImageIcon(self.descImage, Const.atlasName.Activity, imgIcon)
    UITools.SetImageIcon(self.descImage2, Const.atlasName.Town, imgIcon2)
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