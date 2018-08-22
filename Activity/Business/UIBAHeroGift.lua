--[[
	神将礼包
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local commonParamsTable = {}
local preUpdateTime = -1
local ConstValQuality = 4
local rewardExParams = {isnative = true, showQualityEffect = true}

function M:Awake()
	base.Awake(self)

	self.transOffset = self:FindTransform("Offset")

	self.textTime = self:FindText("Offset/LeftTime/TextTime")

	--模型预览
	local cameraPath = "Offset/Left/Hero/PanelModel/CameraModel"
	local rawPath = "Offset/Left/Hero/PanelModel/RawImage"
    self.rawImage = self:LoadRenderTexture(cameraPath, rawPath, "RenderTexture1")
    self.modelParent = self:FindTransform("Offset/Left/Hero/PanelModel/CameraModel/Model")
	self.transHero = self:FindTransform("Offset/Left/Hero")

	self.transBg = self:FindTransform("Offset/BGRoot/BG")

	self.inputField = self:FindInputField("Offset/Right/Number/InputField")

	self.transRewardItem = self:FindTransform("Offset/Right/Reward/RewardList/Viewport/Grid/Item")

	self.textPrice = self:FindText("Offset/Right/ButtonGet/TextPrice")
	self.imagePrice = self:FindImage("Offset/Right/ButtonGet/TextPrice/ImageIcon")

	self.panelHero = {
        panelQuality=self:FindTransform("Quality", self.transHero),
        panelCamp=self:FindTransform("HeroCamp", self.transHero),
        panelDesc=self:FindTransform("HeroDesc", self.transHero),
	}
	
	UguiLuaEvent.InputFieldChange(self.inputField.gameObject, nil, function(_go, _val)
		if _val then
			_val = tonumber(_val)
			if not _val then
				return
			end
			if _val > 999 then
				_val = 999
			end
			
			self:SetInputFieldNumber(_val)
		end
	end)

	UITools.AddBtnsListenrList(self.transOffset, self, M.OnClick, ButtonScale)

	self.heroDatas = nil
	self.openDatas = {}
	self.heroIds = nil
	self.heroDesc = nil
	self.heroShopIds = nil
	self.rewardContainer = {}
end

function M:Show()
	base.Show(self)

	self.transBg.gameObject:SetActive(false)
	self.transBg.anchoredPosition3D = Vector3.zero
	self.transBg.gameObject:SetActive(true)

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	self:ResetData()
end

function M:ResetData()
	local bid = self.data and self.data.id
	if not bid then
		Debugger.LogWarning("uibasinglecharge error no bid")
		return
	end

	local bconfig = excelLoader.BusinessActivityTable[bid]
	if bconfig == nil then
		Debugger.LogWarning("BusinessActivityTable has no id"..tostring(bid))
		return
	end
	self.bconfig = bconfig

	self.heroId = bconfig.param2.heroid

	if not self.heroData then
		local hero
		hero = dataMgr.HeroData.CreateHero(self.heroId)
		hero.awake = true
		hero.growth = 1680
		hero.score = 10000
		hero.lv = 1
		self.heroData = hero
	end

	self.openDatas.heroInfo = self.heroData
	self.openDatas.motion = MotionHash.Pose1
	self:GenHero(self.openDatas)

	self.endTime = self.script:GetEndTime()
	
	local rewards = dataMgr.ItemData.GetRewardList({bconfig.rewardconfig.rewardid})
    UITools.CopyRewardListWithItemsEx(rewards, self.rewardContainer, self.transRewardItem, rewardExParams)

	self:SetInputFieldNumber(self.chooseCount)
end

function M:ResetCost(chooseCount)
	self.chooseCount = chooseCount or self.chooseCount or 1
	self.cost = self.script:GetCost(self.chooseCount)
	UITools.SetCostMoneyInfo(self.textPrice, self.imagePrice, self.cost.itemid, self.cost.num, "")
end

--- {heroInfo, [motion, unitEffect, offsetXYZ, eulerAngles]}
function M:GenHero(openDatas)
	if not openDatas then
		Debugger.LogWarning("openDatas is nil")
		return
	end

	self.modelParent.localEulerAngles = Vector3.New(0, 180, 0)
    local heroInfo = openDatas.heroInfo
    local isHero = (heroInfo ~= nil)
	
    --防止闪烁
    self.rawImage.color = Color.New(1, 1, 1, 0)
    if isHero then
        HeroTool.LoadHeroModel(heroInfo, "ba_hero_gift", self.modelParent, function(unitBase)
            if openDatas.motion then
                unitBase:ChangeMotion(openDatas.motion)
            end
            if not tolua.isnull(self.rawImage) then
                self.rawImage.color = Color.white
                TweenAlpha.Begin(self.rawImage.gameObject, 0, 1, 0.3, 0)
            end
        end)
    else
        --销毁旧的显示单位
        UITools.LoadModel(nil, "ba_hero_gift")
        self.rawImage.color = Color.white
    end

    local trans = UITools.LoadEffect(openDatas.unitEffect, self.modelParent)
    if trans then
        if openDatas.offsetXYZ then
            trans.localPosition = openDatas.offsetXYZ
        end
        if openDatas.eulerAngles then
            trans.localEulerAngles = openDatas.eulerAngles
        end
    end

    if not string.isEmpty(openDatas.effect) then
    	effectMgr:SpawnToUI(openDatas.effect, Vector3.zero, nil, 0)
    end

    if not string.isEmpty(openDatas.audio) then
		audioMgr:PlayUISE(openDatas.audio, 0)
    end  
	
	------
    local heroconfig = dataMgr.HeroData.GetHeroConfig(heroInfo)
	HeroTool.SetHeroCampQuality(self.panelHero.panelCamp, heroInfo)

	self:DestroyEffect(self.effectDesc)
	self.effectDesc = effectMgr:SpawnToUI(heroconfig.descIcon, Vector3.zero, self.panelHero.panelDesc, 0)

	self:DestroyEffect(self.effectQuality)
	self.effectQuality = effectMgr:SpawnToUI(HeroTool.GetHeroQualityEffectName(heroInfo), Vector3.zero, self.panelHero.panelQuality, 0)

	HeroTool.PlayHeroSE(heroconfig)
	------

    audioMgr:PlayUISE("se_mjhd", 0)    
end

function M:DestroyEffect(effectTransform)
    if effectTransform then
        GameObject.Destroy(effectTransform.gameObject)
    end
end

function M:UpdateChild()
	if self.endTime  then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	end
end

---显示物品数量
function M:SetInputFieldNumber(num)
	num = num or 0
    local maxnum = self.maxNum or 9999
    local minnum = self.minNum or 1
    if num > maxnum then num = maxnum 
    elseif num < minnum then num = minnum end
    self.chooseCount = num
	self.inputField.text = tostring(self.chooseCount)
	
	self:ResetCost()
end

---数量减
function M:ClickSub()
    local num = self.chooseCount
    if num > 1 then
        num = num - 1
    end
    self:SetInputFieldNumber(num)
end

---数量加
function M:ClickAdd()
    local num = self.chooseCount
    num = num + 1
    self:SetInputFieldNumber(num)
end

function M:OnClick(go)
	local name = go.name

	if name == "ButtonGet" then
		if self.chooseCount and self.chooseCount > 0 and self.cost then
			self.script:SendGetReward(self.chooseCount, true)
		end
	elseif name == "ButtonJudgement" then
		OpenUI("UIHeroJudge", {hero=self.heroData})
	elseif name == "ButtonSub" then
        self:ClickSub()
    elseif name == "ButtonAdd" then
        self:ClickAdd()
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
    end
end

return M