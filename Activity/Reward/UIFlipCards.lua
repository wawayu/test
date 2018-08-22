local PlayerData = require "Data.PlayerData"
local SevenDayData = require "Data.SevenDayData"
local ItemData = require "Data.ItemData"
local ActivityData = require "Data.ActivityData"
local BusinessData =dataMgr.BusinessData
local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"

local RewardTable = require "Excel.RewardTable"

local rotation90 = Vector3.New(0, 90, 0)
local animationDuration = 0.3

local buttonNotifyPos = Vector3.New(45,75,0)

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[翻翻乐]]

local bid	-- 活動id
function M.Open(params)
    OpenUI("UIReward", {panelIndex = 11})
end

function M:Awake()
	base.Awake(self)
    
    self.getBtn=self:FindGameObject("BtnClick/BtnGet")
    self.notBtn=self:FindGameObject("BtnClick/BtnNot")
    self.explainButton=self:FindButton("BtnClick/ButtonTips")
    --活动说明
    UguiLuaEvent.ButtonClick(self.explainButton.gameObject,self,function(_self, _go, _isOn)
            --暂用已有数据
            Hint({rectTransform = self.explainButton.transform, content = Lan("rule_flipcard_table"), alignment = 0})
    end)



	self.buttonTabs = {}
    for i=1, 7 do
    	local btn = self:FindButton(string.format("ButtonGroundCards/Button (%d)", i))
        self.buttonTabs[i] = btn 
    	UguiLuaEvent.ButtonClick(btn.gameObject, self, function(_self, _go, _isOn)
                self:SwitchPanel(i)              
    	end)
        
    end

    self.numTabs={}
    for i=1, 7 do
    	local btn = self:FindGameObject(string.format("CardDataImage/NumImage (%d)", i))
        self.numTabs[i] = btn 
    end

end


function M:Show()
    base.Show(self)  
    
    bid = BusinessData.GetFlipCardsID()
    if bid<0 then
        self:Hide()
		return
    end
    self.script = BusinessData.GetScript(bid)
    if  not self.script then
		self:Hide()
		return
    end
    --红点
    for i=1,7 do
        self:AddTabNotify(i) 
    end
    self:CardNum()
    self:ResetData()
end

--选中充值类型，显示相应的面板
function M:SwitchPanel(index)
    self:FlipCard(index)
    self:ResetData()
end

function M:CardNum()
    -- body
    local Num=self.script:CardNum()
    self.cardNum={}
    local numTable={}
    for i=1,7 do
        --numTable[i]=(Num/math.pow(10,7-i))%10
        numTable[i]=math.floor(Num/math.pow(10,7-i))%10
        if  self.script:IsFanFanDone(i) then
            self.buttonTabs[i].gameObject:SetActive(false)   
        end
        self.cardNum[i]=self:FindText(string.format("CardDataImage/NumImage (%d)/Text", i))
        --self.cardNum[i].text=math.ceil(numTable[i])-1;
        self.cardNum[i].text=numTable[i];
    end
    
end

function M:ResetData()

    self.getBtn:SetActive(false)
    if  SevenDayData.GetLoginDay()>=7 and  self.script:IsFanFanDone(7) then
        self.getBtn:SetActive(true)
        self.notBtn:SetActive(false)
        UguiLuaEvent.ButtonClick(self.getBtn, self, M.GetRewardOnClick)
    end
  
end

--监听本地
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
        self:ResetData()
    end
end

--领取奖励
function M:GetRewardOnClick()
    --判断背包是否已满
	if notifyMgr.IsBagFull(true) then
        return
    else
        self.script:SendGetCardMoney() 
        self.getBtn:SetActive(false)
        self.notBtn:SetActive(true)
	end

end

function M:FlipCard(day)
    local islogin=self.script:IsFanFanDone(day)
    --今天为登录天数
    if not islogin then
        if day<=SevenDayData.GetLoginDay() then
            local tween = TweenRotation.Begin(self.buttonTabs[day].gameObject, Vector3.zero, rotation90, animationDuration, 0)
            TweenRotation.Begin(self.numTabs[day], rotation90, Vector3.zero, animationDuration, animationDuration)                            
            tween:SetOnFinished(function()
                self.script:SendFanFan(day)
            end)
        end

         --未达到登录天数
        if day>SevenDayData.GetLoginDay() then
            Tips("明天登录后可继续翻牌！")
        end       
    end
end

--添加红点
function M:AddTabNotify(day)
    if day<=SevenDayData.GetLoginDay() and not self.script:IsFanFanDone(day) then
       notifyMgr.AddNotify(self.buttonTabs[day].gameObject, true, buttonNotifyPos, notifyMgr.NotifyType.Common)
    end
end


return M