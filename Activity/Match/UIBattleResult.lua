
local base = require "UI.UILuaBase"
local M = base:Extend()

local battleNum = 0
local panelLen = 5

--[[
	battleInfo = msg.battleInfo, isWin = msg.isWin, damageList = content.damageList
	itemid, cur_pvpscore,pre_pvpscore, name
]]
local openParams
function M.Open(params)
	openParams = params
	if not openParams then
		return
	end
    uiMgr.ShowAsync("UIBattleResult")
end

function M:Awake()
	base.Awake(self)

	self.uiOffset = self:FindGameObject("Offset")

	--标题
	self.goTitleWin = self:FindGameObject("Offset/Title/ImgWin")
	self.goTitleLose = self:FindGameObject("Offset/Title/ImgLose")

	self.imageTitleBg = self:FindImage("Offset/Title/ImgBg")

	--Left ScrollView
	self.tranLeftContent = self:FindTransform("Offset/Left/Scroll View/Viewport/Content")

	--Right ScrollView
	self.tranRightContent = self:FindTransform("Offset/Right/Scroll View/Viewport/Content")
	
	--Bottom
	self.textDesc = self:FindText("Offset/Buttom/TextDesc")
	self.textPoint = self:FindText("Offset/Buttom/TextDesc/ImgPoint/TxtPoint")
	self.imagePoint = self:FindImage("Offset/Buttom/TextDesc/ImgPoint")

    --按钮。Button，ButtonScale
    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)

	self.comsLeft = {}
	self.comsRight = {}
	for i = 1,panelLen do
		self.comsLeft[i] = {}
		self.comsLeft[i].trans = self:FindTransform(string.format("Offset/Left/Scroll View/Viewport/Content/Item (%s)", i))
		self:OnCreateItem(1, i, self.comsLeft[i])

		self.comsRight[i] = {}
		self.comsRight[i].trans = self:FindTransform(string.format("Offset/Right/Scroll View/Viewport/Content/Item (%s)", i))
		self:OnCreateItem(2, i, self.comsRight[i])
	end
end

function M:InitConfig()
	-- 演武
	if openParams.fightType == Const.BATTLE_TYPE_PVP then
		openParams.pre_pvpscore = dataMgr.PVPData.content.pre_pvpscore
		openParams.cur_pvpscore = dataMgr.PVPData.content.cur_pvpscore
		openParams.name = "演武"
		openParams.iconName = "bei"
		openParams.iconAtlas = Const.atlasName.Common
		openParams.okCallback = function () 
			dataMgr.PVPData.OpenArenaUI()
		end
	elseif openParams.fightType == Const.BATTLE_TYPE_DOUJI then
		openParams.cur_pvpscore = dataMgr.ActivityData.GetDouJiScore(1)
		openParams.pre_pvpscore = dataMgr.ActivityData.content.oldDoujiScore
		openParams.name = "斗技"
		openParams.iconName = "money_banggong"
		openParams.iconAtlas = Const.atlasName.ItemIcon
		openParams.okCallback = function () 
			OpenUI("UIBattleMatch")
		end
	end
end

function M:Show()
	base.Show(self)

	self:TweenOpen(self.uiOffset)

	self:InitConfig()
	openParams.pre_pvpscore = openParams.pre_pvpscore or 0
	openParams.cur_pvpscore = openParams.cur_pvpscore or 0

	self:ResetData()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.PlayerSkill then
    end
end

--点击按钮
function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnOk" then
		self:Hide()

		if openParams and openParams.okCallback then
			openParams.okCallback()
		end
	end
end

function M:GetMembersDamage(memberlist, damageList, battleInfo)
	local damageMap = {}
	for i,v in ipairs(damageList) do
		damageMap[v.guid] = v.damage
	end

	local res = {}
	local myGuid = dataMgr.PlayerData.GetRoleInfo().guid
	res.list = {}
	for i,v in ipairs(memberlist) do
		local newRes = {guid = v.guid, damage = damageMap[v.guid] or 0}
		newRes.name = fightMgr.GetUnitName(v)
		newRes.lv = fightMgr.GetUnitLv(v, battleInfo)
		
		newRes.tableID, newRes.unitTab, newRes.idType = unitMgr.UnpackUnitGuid(newRes.guid)

		if myGuid == v.guid then
			newRes.ext = openParams.cur_pvpscore
			newRes.floatExt = openParams.cur_pvpscore - openParams.pre_pvpscore
		else
			newRes.ext = -1
		end
		
		table.insert(res.list, newRes)
		res.totalDamage = (res.totalDamage or 0) + newRes.damage
	end

	table.sort(res.list, M.SortFunc)

	return res
end

local tpa,tpb
function M.SortFunc(a, b)
	tpa = a.idType == Const.ID_TYPE_CHARACTER or a.idType == Const.ID_TYPE_CHARACTER_COPY
	tpb = b.idType == Const.ID_TYPE_CHARACTER or b.idType == Const.ID_TYPE_CHARACTER_COPY
	if tpa ~= tpb then
		return tpa
	else
		if a.unitTab.isPlayer ~= b.unitTab.isPlayer then
			return a.unitTab.isPlayer
		elseif a.damage == b.damage then
			return a.guid < b.guid
		else
			return a.damage > b.damage
		end
	end
end

--刷新整个面板
function M:ResetData()
	local battleInfo = openParams.battleInfo
	if not battleInfo then
		return
	end
	
	--胜利失败图片，下方文字
	if openParams.isWin then
		--胜利
		self.goTitleWin:SetActive(true)
		self.goTitleLose:SetActive(false)
		UITools.SetImageGrey(self.imageTitleBg, false)

		self.textDesc.text = string.format("%s中你获得了胜利，积分升至", openParams.name)
	else
		--失败
		self.goTitleWin:SetActive(false)
		self.goTitleLose:SetActive(true)
		UITools.SetImageGrey(self.imageTitleBg, true)

		self.textDesc.text = string.format("%s中你被打败了，积分降至", openParams.name)
	end
	--积分
	self.textPoint.text = tostring(openParams.cur_pvpscore)
	-- 积分图片
	UITools.SetImageIcon(self.imagePoint, openParams.iconAtlas, openParams.iconName)

	self.damageResult = {}

	local memberlist1 = battleInfo.memberlist1
	local memberlist2 = battleInfo.memberlist2
	local list1Camp,list2Camp = dataMgr.FightData.GetFightMembersCamp(battleInfo)
	if list1Camp ~= Const.FighterCamp.Ally then
		memberlist1 = battleInfo.memberlist2
		memberlist2 = battleInfo.memberlist1
	end

	if openParams and openParams.damageList then
		local res = {}
		res[1] = self:GetMembersDamage(memberlist1, openParams.damageList, battleInfo)
		res[2] = self:GetMembersDamage(memberlist2, openParams.damageList, battleInfo)

		self.damageResult = res
	end

	for i = 1,panelLen do
		self:UpdateItem(1, i, self.comsLeft[i])
		self:UpdateItem(2, i, self.comsRight[i])
	end
end

function M:GetLoopItem(side, idx)
    return self.damageResult[side].list[idx]
end

function M:OnCreateItem(side,index, coms)
	local trans = coms.trans
	
	--缓存组件
	coms.goHead = self:FindGameObject("HeadIcon", trans)
	coms.goEmpty = self:FindGameObject("TxtEmpty", trans)
	-- 头像、名字、等级
	coms.imageIcon = self:FindImage("HeadIcon/Item/Info/ImageIcon", trans)
	coms.textName = self:FindText("HeadIcon/TxtName", trans)
	coms.textLv = self:FindText("HeadIcon/Item/Info/TextNum", trans)
	coms.imageType = self:FindTransform("HeadIcon/Item/Info/ImageType", trans)
	coms.transGrade = self:FindTransform("HeadIcon/GradeValue", trans)
	--积分

	if side == 1 then
		coms.textTotalPoint = self:FindText("HeadIcon/GradeValue/ImgItem/TxtCount", trans)
		coms.textFloatPoint = self:FindText("HeadIcon/GradeValue/ImgItem/TxtCount/Arraw/TxtFloat", trans)
		coms.imageArraw = self:FindImage("HeadIcon/GradeValue/ImgItem/TxtCount/Arraw", trans)
		coms.imagePointIcon = self:FindImage("HeadIcon/GradeValue/ImgItem", trans)
	else
		coms.textTotalPoint = self:FindText("HeadIcon/GradeValue/TxtFloat/Arraw/TxtCount", trans)
		coms.textFloatPoint = self:FindText("HeadIcon/GradeValue/TxtFloat", trans)
		coms.imageArraw = self:FindImage("HeadIcon/GradeValue/TxtFloat/Arraw", trans)
		coms.imagePointIcon = self:FindImage("HeadIcon/GradeValue/TxtFloat/Arraw/TxtCount/ImgItem", trans)
	end
	
	--伤害值
	coms.sliderDamage = self:FindSlider("HeadIcon/DamageValue/Slider", trans)
	coms.textDamage = self:FindText("HeadIcon/DamageValue/Slider/TxtValue", trans)
end

function M:OnChooseItem(side,index, coms)
	
end

function M:UpdateItem(side,index, coms)
	local battleResult = self:GetLoopItem(side, index)

	coms.goEmpty.gameObject:SetActive(not battleResult)
	coms.goHead.gameObject:SetActive(battleResult ~= nil)
	if not battleResult then
		return
	end

	--名称，等级
	coms.textName.text = battleResult.name
	coms.textLv.text = battleResult.lv

	local atlas, icon = UITools.GetUnitAtlasIcon(battleResult.guid)
	uiMgr.SetSpriteAsync(coms.imageIcon, atlas, icon)
	local idType = battleResult.idType
	if idType == Const.ID_TYPE_HERO then
		coms.imageType.gameObject:SetActive(true)
		HeroTool.SetHeroType(coms.imageType, battleResult.unitTab)
	elseif idType == Const.ID_TYPE_CHARACTER or idType == Const.ID_TYPE_CHARACTER_COPY then
		coms.imageType.gameObject:SetActive(false)
	elseif idType == Const.ID_TYPE_MONSTER then
		coms.imageType.gameObject:SetActive(false)
	else
		coms.imageType.gameObject:SetActive(false)
	end

	--积分
	if battleResult.ext <= 0 then
		coms.transGrade.gameObject:SetActive(false)
	else
		coms.transGrade.gameObject:SetActive(true)
		coms.textTotalPoint.text = battleResult.ext
		coms.textFloatPoint.text = battleResult.floatExt
		if battleResult.floatExt > 0 then
			--积分上升
			uiMgr.SetSpriteAsync(coms.imageArraw, Const.atlasName.Common, "jiantou_6")
		elseif battleResult.floatExt < 0 then
			--积分下降
			uiMgr.SetSpriteAsync(coms.imageArraw, Const.atlasName.Common, "jiantou_6")
		end
		
		UITools.SetImageIcon(coms.imagePointIcon, openParams.iconAtlas, openParams.iconName)
	end
	
	--伤害值
	local total = self.damageResult[side].totalDamage
	local sliderVal = 0
	if total ~= 0 then
		sliderVal = battleResult.damage/total
	end
	coms.sliderDamage.value = sliderVal
	coms.textDamage.text = string.format("%d/%d", battleResult.damage, total)
end

return M