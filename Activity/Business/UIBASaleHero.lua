--[[
	名将促销
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ItemTable = require "Excel.ItemTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local commonParamsTable = {}
local preUpdateTime = -1
local ConstValQuality = 4

function M.Open()
	local id = BusinessData.GetOpenID(Const.BAGROUP_SALEHERO)
	if id > 0 then
		OpenUI("UIBusinessActivity", {bid=id})
	end
end

function M:Awake()
	base.Awake(self)
	self.transOffset = self:FindTransform("Offset")
	self.textTime = self:FindText("Offset/Top/LeftTime/TxtTime")

	--模型预览
	local cameraPath = "Offset/Right/Hero/PanelModel/CameraModel"
	local rawPath = "Offset/Right/Hero/PanelModel/RawImage"
    self.rawImage = self:LoadRenderTexture(cameraPath, rawPath, "RenderTexture1")
    self.modelParent = self:FindTransform("Offset/Right/Hero/PanelModel/CameraModel/Model")
	self.transHero = self:FindTransform("Offset/Right/Hero")

	self.transBg = self:FindTransform("Offset/BG")

	self.panelHero = {
        panelQuality=self:FindTransform("Quality", self.transHero),
        panelCamp=self:FindTransform("HeroCamp", self.transHero),
        panelDesc=self:FindTransform("HeroDesc", self.transHero),
    }

	--UIloop
	self.uiItemLoop = self:FindLoop("Scroll View/Viewport/Content", self.transOffset)
    self:BindLoopEventEx(self.uiItemLoop, M.OnCreateItem, M.UpdateItem)

	UguiLuaEvent.ButtonClick(self:FindTransform("Offset/ButtonGet").gameObject, self, function(_, go)
			self:OnClickGet()
	end)

	self.heroDatas = nil
	self.openDatas = {}
	self.heroIds = nil
	self.heroDesc = nil
	self.heroShopIds = nil

	effectMgr:SpawnToUI("2d_sj7z", Vector3.zero, self:FindTransform("Offset/Top/BG"), 0)
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

	self:OnChoose(1)
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

	self.heroShopIds = self.script:GetHeroShopIds()
	if not self.heroShopIds then
		return
	end

	self.heroIds = {}
	for i,v in ipairs(self.heroShopIds) do
		table.insert(self.heroIds, excelLoader.ShopItemTable[v].item.itemid)
	end

	local param2 = bconfig.param2
	self.heroDesc = param2 and param2.desc
	if not self.heroDesc or #self.heroDesc == 0 then
		Debugger.LogWarning("BusinessActivityTable param2.desc error")
		return
	end
	
	if not self.heroDatas then
		self.heroDatas = {}

		local hero
		for i,heroId in ipairs(self.heroIds) do
			hero = dataMgr.HeroData.CreateHero(heroId)
			hero.awake = true
			hero.growth = 1680
			hero.score = 10000
			hero.lv = 1
			self.heroDatas[heroId] = hero
		end
	end

	self.uiItemLoop.ItemsCount = #self.heroIds

	local chooseId = self:GetLoopItem(self.selectIndex)
	self.openDatas.heroInfo = self.heroDatas[chooseId]
	self.openDatas.motion = MotionHash.Pose1
	self:GenHero(self.openDatas)

	self.endTime = self.script:GetEndTime(self.data.id)
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
        HeroTool.LoadHeroModel(heroInfo, "ba_sale_hero", self.modelParent, function(unitBase)
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
        UITools.LoadModel(nil, "ba_sale_hero")
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

function M:GetLoopItem(idx)
    return self.heroIds[idx]
end

--道具
function M:OnCreateItem(index, coms)
	coms.textName = self:FindText("TextName", coms.trans)
	coms.textDesc = self:FindText("TextDesc", coms.trans)
	coms.goSelect = self:FindGameObject("ImageSelect", coms.trans)
	coms.transItem = self:FindTransform("Item", coms.trans)
	
	UguiLuaEvent.ButtonClick(coms.trans.gameObject, nil, function(go)
		self:OnChoose(self.uiItemLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:OnChoose(index, go)
	self.selectIndex = index
	self:ResetData()
end

function M:UpdateItem(index, coms)
	local heroId = self:GetLoopItem(index)
	local heroInfo = self.heroDatas[heroId]
	local heroConfig = excelLoader.HeroTable[heroId]
	if not heroConfig then
		Debugger.LogWarning("Herotable no id"..tostring(heroId))
		return
	end
	coms.textName.text = dataMgr.HeroData.FormatHeroName(heroInfo, false, false)
	coms.textDesc.text = (self.heroDesc and self.heroDesc[index]) or ""

	coms.goSelect:SetActive(index == self.selectIndex)

	HeroTool.SetHeroInfo(coms.transItem, heroInfo)
	HeroTool.SetHeroType(self:FindTransform("Info/ImageType", coms.transItem), heroConfig)
	local imgqua = self:FindImage("Info/ImageQuality", coms.transItem)
	UITools.SetQualityBg(imgqua, ConstValQuality)
end

function M:UpdateChild()
	local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
	self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
end

function M:OnClickGet()
	local heroShopId = self.heroShopIds[self.selectIndex]

	OpenUI("UIHeroShop", {panelIndex=2, shopItemId = heroShopId})
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
		
    end
end

return M