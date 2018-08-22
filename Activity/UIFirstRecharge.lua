local RechargeData = require "Data.RechargeData"

local SettingTable = require "Excel.SettingTable"
local ItemTable = require "Excel.ItemTable"

local ConfRule = require "ConfRule"

local base = require "UI.UILuaBase"

local M = base:Extend()

--------------首冲

local fromPos = Vector3.New(0, 20, 0)
local toPos = Vector3.New(0, 30, 0)
local notifPosition = Vector3.New(58, 20, 0)
local rewardExParams = {isnative = true, showQualityEffect = true}

function M.Open(params)
    uiMgr.ShowAsync("UIFirstRecharge")
end

function M:Awake()
    base.Awake(self)
	self.uiOffset = self:FindGameObject("Offset")

	self.uiFirstPanel = self:FindGameObject("Offset/Panel1")
	self.uiSecondPanel = self:FindGameObject("Offset/Panel2")
	self.uiThirdPanel = self:FindGameObject("Offset/Panel3")

    self.rawImage = self:FindGameObject("Offset/Award/ModelImage/RawImage")
    
    self.payText = self:FindText("Offset/Text/PayText")

    self.settingFristRecharge = SettingTable["firstcharge_reward"]
    --奖励物品
    self.transRewardItem = self:FindTransform("Offset/#105RewardList/Viewport/Grid/Item")

    --模型1
    self.modelParent_1 = self:FindTransform("Offset/Award/ModelImage/CameraModel/Model")
    self:LoadRenderTexture("Offset/Award/ModelImage/CameraModel", "Offset/Award/ModelImage/RawImage", "RenderTexture0")
    self.modelParent_2 = self:FindTransform("Offset/Award/ModelImage/CameraModel/Model (1)") 
    --按钮
    self.btnRecharge = self:FindGameObject("Offset/BtnRoot/BtnRecharge")
    self.btnGet = self:FindGameObject("Offset/BtnRoot/GetBtn")
    self.btnAlreadyGet = self:FindGameObject("Offset/BtnRoot/AlreadyGetBtn")

    self.toggleTabs = {}
    for i=1, 3 do
    	local tog = self:FindToggle(string.format("Offset/ToggleGroup/Toggle (%d)", i))
        self.toggleTabs[i] = tog
    	UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
            if _isOn then
            	self:SwitchPanel(i)
            end
    	end)
    end

    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.OnClick)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/BtnRoot/BtnRecharge"), self, M.OnClick)
    UguiLuaEvent.ButtonClick(self.btnGet, self, M.GetRewardOnClick)

end

function M:Show()
	base.Show(self)
    self:TweenOpen(self.uiOffset)
    self.curIndex = 1
    if RechargeData.IsAlreadyGetReward(1) then
        self.curIndex = 2
    end
    if RechargeData.IsAlreadyGetReward(2) then   
        self.curIndex = 3
    end 
     --默认打开Panel
    if self.toggleTabs[self.curIndex].isOn == true then
        self:SwitchPanel(self.curIndex)
    else
        self.toggleTabs[self.curIndex].isOn = true
    end
    self:RefreshPanel()
end

function M:RefreshPanel()

    self.uiFirstPanel:SetActive(self.curIndex == 1)
    self.uiSecondPanel:SetActive(self.curIndex == 2)
    self.uiThirdPanel:SetActive(self.curIndex == 3)

    local payMoney = RechargeData.GetChargeMoney()
    self.payText.text = string.format("当前累计充值 <color=#5aff1e>%s</color> 元", payMoney)    

    self:RefreshReward()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Recharge then
        self:RefreshPanel()
    end
end

--点击按钮
function M:OnClick(go)
	if go.name == "ButtonClose" then
		self:Hide()
	elseif go.name == "BtnRecharge" then
		OpenUI("UIRecharge")
	end
end

--领取奖励按钮
function M:GetRewardOnClick()
    if not RechargeData.IsAlreadyGetReward(self.curIndex) then      
        RechargeData.RequestGetFirstRechargeReward(self.curIndex) 
    end
end

--选中充值类型，显示相应的面板
function M:SwitchPanel(index)
	self.curIndex = index
    self:RefreshPanel()
end

--刷新奖励Items,及其按钮显示
function M:RefreshReward()
	local rewardKind = self.settingFristRecharge[self.curIndex]
	if rewardKind ~= nil then
		--刷新奖励
		if self.rewardGoList == nil then
			self.rewardGoList = {} 
		end
		UITools.CopyRewardList({rewardKind.rewardid}, self.rewardGoList, self.transRewardItem, rewardExParams)
        
        local rewards = dataMgr.ItemData.GetRewardList({rewardKind.rewardid})
        local itemTab = ItemTable[rewards[1].itemid]
    	--模型2
        if itemTab.param then
            if itemTab.param.heroid then
                self.modelParent_1.gameObject:SetActive(true)	
                self.modelParent_2.gameObject:SetActive(false)
                local hero = dataMgr.HeroData.CreateHero(itemTab.param.heroid)
                hero.awake = itemTab.param.awake or hero.awake
                hero.rank = itemTab.param.rank or hero.rank
                hero.quality = itemTab.param.quality or hero.quality
                HeroTool.LoadHeroModel(hero, "firstRechargeHero", self.modelParent_1, function(tmpunit)
                    self.unitBase = tmpunit
                end, Layer.UIModel)	
                --UITools.LoadModel(rewards[1].itemid, "firstRechargeHero", self.modelParent_1)
            else
                self.modelParent_1.gameObject:SetActive(false)	
                self.modelParent_2.gameObject:SetActive(true)
                local modelWeaponItemId = rewards[1].itemid
                --print(modelWeaponItemId)
                local artifactid = dataMgr.ArtifactData.GetArtifactIDByItemID(modelWeaponItemId)
                UITools.LoadArtifact(dataMgr.ArtifactData.NewArtifactInfo(artifactid), self.modelParent_2)
            end
        elseif itemTab.models then
    		self.modelParent_1.gameObject:SetActive(true)	
            self.modelParent_2.gameObject:SetActive(false)	
    		UITools.LoadModel(rewards[1].itemid, "firstRechargeHero", self.modelParent_1)
    	end

        local tp = TweenPosition.Begin(self.rawImage, fromPos, toPos, 1, 0)
        if self.curIndex == 2 then
            tp.enabled = true
            tp.style = 2            
        else 
            tp.enabled = false
        end

        --按钮
        local rechargeNum = RechargeData.GetChargeMoney(self.curIndex)  --当前玩家充值了多少
        local getRewardMoney = rewardKind.num   --领取奖励所需要的钱数
        if rechargeNum >= getRewardMoney then
            self.btnRecharge:SetActive(false)
            local isAlreadyGet = RechargeData.IsAlreadyGetReward(self.curIndex)   --是否领取
            if isAlreadyGet then
                self.btnGet:SetActive(false)
                self.btnAlreadyGet:SetActive(true)
            else
                self.btnGet:SetActive(true)
                self.btnAlreadyGet:SetActive(false)
            end
        else
            self.btnRecharge:SetActive(true)
            self.btnGet:SetActive(false)
            self.btnAlreadyGet:SetActive(false)
        end
    end
    for i=1, 3 do
        --红点
        notifyMgr.AddNotify(self.toggleTabs[i], RechargeData.IsShowNotify(i), notifPosition, notifyMgr.NotifyType.Common)
    end
    
end

return M