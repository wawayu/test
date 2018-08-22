local RechargeData = require "Data.RechargeData"
local BusinessData = require "Data.BusinessData"

local ActivityTable = require "Excel.ActivityTable"
local SettingTable = require "Excel.SettingTable"
local ItemTable = require "Excel.ItemTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {isnative = true, showQualityEffect = true}
local preUpdateTime = -1
local ConfRule = require "ConfRule"

local base = require "UI.UILuaBase"
local notifPosition = Vector3.New(35, 30, 0)
local transPosition = Vector3.New(-50, -60, 0)
local M = base:Extend()


local bid	-- 活動id
function M.Open(params)
	bid = params and params.id or BusinessData.GetSkyGiftID()
	if bid<0 then
		return
	end
    uiMgr.ShowAsync("UISkyGift")
end


function M:Awake()
    base.Awake(self);
    self.uiOffset = self:FindGameObject("Offset")
    self.payText = self:FindText("Offset/Text/PayText")

      --奖励物品
    self.transRewardItem = self:FindTransform("Offset/#105RewardList/Viewport/Grid/Item")


    --按钮
    self.btnRecharge = self:FindGameObject("Offset/BtnRoot/BtnRecharge")
    self.btnGet = self:FindGameObject("Offset/BtnRoot/GetBtn")
    self.btnAlreadyGet = self:FindGameObject("Offset/BtnRoot/AlreadyGetBtn")

    --倒计时
    self.textTime = self:FindText("Offset/Top/TopTime/TimeText")
    --点选礼包类型
    self.toggleTabs = {}
    for i=1, 3 do
    	local tog = self:FindToggle(string.format("Offset/ToggleGroup/Toggle (%d)", i))
        self.toggleTabs[i] = tog
        local transBG=self:FindTransform(string.format("Offset/ToggleGroup/Toggle (%d)/Bg1", i))
        effectMgr:SpawnToUI("2d_jchd_xscg", transPosition, transBG, 0)
    	UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
            if _isOn then
            	self:SwitchPanel(i)
            end
    	end)
    end

    --按钮事件
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.OnClick)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/BtnRoot/BtnRecharge"), self, M.OnClick)
    UguiLuaEvent.ButtonClick(self.btnGet, self, M.GetRewardOnClick)
    
end


function M:Show()
    base.Show(self)  

    self.script = BusinessData.GetScript(bid)
	if not self.script then
		self:Hide()
		return
	end

	self.businessTab = BusinessActivityTable[bid]
    self:TweenOpen(self.uiOffset)
    self.curIndex = 1
    for i=1,3 do
        if self.script:GetSkyGiftStatus(i)==1 then
            self.curIndex=i
            break
        end
     end
    self.toggleTabs[self.curIndex].isOn = true  
    self:ResetData()
end 

--点击按钮
function M:OnClick(go)
	if go.name == "ButtonClose" then
		self:Hide()
	elseif go.name == "BtnRecharge" then
		OpenUI("UIRecharge")
	end
end

--选中充值类型，显示相应的面板
function M:SwitchPanel(index)
	self.curIndex = index
    self:ResetData()
end

--监听本地
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
        for i=1,3 do
           if self.script:GetSkyGiftStatus(i)==1 then
                self.curIndex=i
                break
           end
        end
        self.toggleTabs[self.curIndex].isOn = true
        self:SwitchPanel(self.curIndex)
    end
end

--领取奖励按钮
function M:GetRewardOnClick()
    if not self.script:IsSkyGiftGot(self.curIndex) then      
        self.script:SendSkyGift(self.curIndex) 
        self:ResetData()
    end
end


function M:ResetData()
    local payMoney = self.script:GetSkyNeedRecharge(self.curIndex)
    self.payText.text = string.format("再充值<color=#5aff1e>%s</color>元宝即可开启", payMoney)    
    if payMoney<=0 then
        self.payText.text = string.format("再充值0元宝即可开启", payMoney) 
    end

   

    self.rewardList = self.script:GetSkyGiftReward(self.curIndex)
    self.endTime = self.script:GetEndTime()
    --空表
    if self.rewardGoList == nil then
			self.rewardGoList = {} 
	end
    local data = self.rewardList
	-- 刷新奖励
	UITools.CopyRewardList({data.rewardid}, self.rewardGoList, self.transRewardItem, rewardExParams)

        local state=self.script:GetSkyGiftStatus(self.curIndex)
        self.btnAlreadyGet:SetActive(false)
        if state==0 then
            self.btnRecharge:SetActive(true)
            self.btnGet:SetActive(false)
        elseif state==1 then
            self.btnRecharge:SetActive(false)
            self.btnGet:SetActive(true)
        else
            self.btnRecharge:SetActive(false)
            self.btnGet:SetActive(false)
            self.btnAlreadyGet:SetActive(true)
        end



    for i=1, 3 do
        --红点
        notifyMgr.AddNotify(self.toggleTabs[i], self.script:IsShowSkyNotify(i), notifPosition, notifyMgr.NotifyType.Common)
    end
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