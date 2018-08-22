local ActivityTable = require "Excel.ActivityTable"
local RecordTable = require "Excel.RecordTable"
local SettingTable = require "Excel.SettingTable"
local RewardTable = require "Excel.RewardTable"
local ActivityCalendarTable = require "Excel.ActivityCalendarTable"
local ConfRule = require "ConfRule"
local TimeSync = require "TimeSync"
local ScoreBuilder = require "ScoreBuilder"

local PlayerData = require "Data.PlayerData"
local ActivityData = require "Data.ActivityData"

local UIWidgetBase = require("UI.Widgets.UIWidgetBase")

local transPosition = Vector3.New(-50, -60, 0)
local base          = require "UI.UILuaBase"
local M             = base:Extend()
--红点位置
local notifExtra = Vector3.New(28, 25, 0)
local notifUpLv = Vector3.New(62, 17, 0)
local notifBack = Vector3.New(80, 23, 0)



local rewardExParams = {isnative = true, showQualityEffect = true}

function M.Open()
    OpenUI("UIActivity", {panel=2})
end

function M:Awake()
    base.Awake(self)  
    ---------------------------------左侧
    --额外奖励
    self.btnExtra = self:FindGameObject("Left/Top/BtnExtraAward")
    self.btnPromat = self:FindGameObject("Left/Top/BtnPromat")

    self.extraText = self:FindText("Left/Top/AwardText")
    self.allFight = self:FindText("Left/Top/FightText")
    self.fightAdd = self:FindText("Left/Top/NextText")
    self.titleName = self:FindText("Left/Top/TitleName")
    --升级找回按钮
    self.btnUP = self:FindGameObject("Left/Down/Buttom/Slider/ButtonEnergy")
    self.btnBack = self:FindGameObject("Right/BtnFindAll")

    --当前信息
    self.hpAdd = self:FindText("Left/Down/HPText")
    self.hpNext = self:FindText("Left/Down/HPText/NextText")
    self.atkAdd = self:FindText("Left/Down/ATKText")
    self.atkNext = self:FindText("Left/Down/ATKText/NextText")
    self.defAdd = self:FindText("Left/Down/DEFText")
    self.defNext = self:FindText("Left/Down/DEFText/NextText")
    --加成信息
    self.allHpAdd = self:FindText("Left/Down/HPAllText")
    self.allHpNext = self:FindText("Left/Down/HPAllText/NextText")
    self.allAtkAdd = self:FindText("Left/Down/ATKAllText")
    self.allAtkNext = self:FindText("Left/Down/ATKAllText/NextText")
    self.allDefAdd = self:FindText("Left/Down/DEFAllText")
    self.allDefNext = self:FindText("Left/Down/DEFAllText/NextText")
    --奖励以及等级
    self.transRewardItem = self:FindTransform("Left/Down/Buttom/#105RewardList/Viewport/Grid/Item")
    self.sliderLv = self:FindSlider("Left/Down/Buttom/Slider")
    self.LV = self:FindText("Left/Down/Buttom/Slider/TextLv")
    self.expText = self:FindText("Left/Down/Buttom/Slider/Text")

    self.showLvText =  self:FindText("Left/Top/ShowUpText")
    self.effectTran = self:FindTransform("Left/Top/PanelModel")

    self.btnLast = self:FindImage("Left/Top/BtnLast")
    self.btnNext = self:FindImage("Left/Top/BtnNext")
  
    ---------------------------------右侧

    --活动，UIloop
	self.uiActLoop = self:FindLoop("Right/Scroll View Right/Viewport/Content")
    self:BindLoopEventAdvance(self.uiActLoop, M.OnCreateActItem, M.UpdateActItem)
    
    --按钮。Button
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
end


function M:Show()
    base.Show(self)
    if not self.lv then
        self.lv = 0
    end
    self.selectNum = 1 
    self:RefreshData()

    
end

--刷新数据
function M:RefreshData()
    activityMgr.MustDoActivitySort()
    --每日必做活动
    self.activeInfo = activityMgr.mustDoActive
    self.ActiveInfo = self:SortActiveInfo()
    --必做信息
    self.mustdoInfo = dataMgr.ActMustDoData.MustDoInfo()
 
    self:RefreshRightData()
    self:RefreshLeftData()  

    --开启时跳转至对应模型
    self.moduleTable = excelLoader.SettingTable["mrbz_effect"] 
    for i,v in ipairs(self.moduleTable) do
        if self.mustdoInfo.lv >= v.lv then
            self.selectNum = i
        end
    end
    --模型
    self:RefreshModule()
    --红点
    self:IsorNotNotify()
end

function M:OnCreateActItem(coms)
    coms.imgActIcon = self:FindImage("ActTypeImg", coms.trans) 
    coms.actName = self:FindText("ActName",coms.trans)
    coms.actNum = self:FindText("Num",coms.trans)
    coms.actExp = self:FindText("Exp",coms.trans)
    coms.hasdone = self:FindGameObject("HasDone",coms.trans)

    UguiLuaEvent.ButtonClick(coms.go, nil, function(go)
		self:OnClickItem(self.uiActLoop:GetItemGlobalIndex(coms.go) + 1, coms)
	end)
end

function M:UpdateActItem(coms)
    local index = coms.globalIndex
    local actInfo = self.ActiveInfo[index]
    
    uiMgr.SetSpriteAsync(coms.imgActIcon, Const.atlasName.ItemIcon, actInfo.icon)
    coms.actName.text = actInfo.name
    coms.actExp.text = actInfo.dexp

    local num = dataMgr.ActMustDoData.MustDoFinNum(actInfo.id)
    local max = actInfo.dnum
    coms.actNum.text = string.format("%d/%d",num, max)

    UITools.SetActive(coms.hasdone,num >= max)
    UITools.SetActive(coms.actNum,num < max)
end


function M:OnClickItem(index, coms)
    --点击参加活动
    local activityTab = self.ActiveInfo[index]
    if activityTab.id ==2018 then
        local desc = activityTab.desc
        Tips(desc)
    else
        activityMgr.JoinActivity(activityTab)
    end

end

--点击按钮
function M:OnClick(go)
    local btnName = go.name
	--print(btnName)
    if btnName == "ButtonEnergy" then
        --虚拟
        if self.nowExp >= self.nowMaxExp then
            --require ("UI.Activity.MustDo.UIMustDoUP").Open({lv = self.lv })
            OpenUI("UIMustDoUP")
            dataMgr.ActMustDoData.RequestLevelUp()
        else
           Tips("经验不足，快去做任务哦~")
        end
      
        self:RefreshData()
    elseif btnName == "BtnFindAll" then
        --找回
        OpenUI("UIMustDoBack")
    elseif btnName == "BtnPromat" then
        --变强
        OpenUI("UIGrowEntry")
    elseif btnName == "BtnExtraAward" then
        if self.mustdoInfo.dailyexp >= self.extraLv and not self.mustdoInfo.reward then
            dataMgr.ActMustDoData.RequestExtraAward()
        else
            if self.mustdoInfo.reward  then
                Tips("今天已经领取过了奖励~")
            else
                Tips("经验不足，快去做任务哦~")
            end

        end
    elseif btnName == "BtnLast" then
        self.selectNum = self.selectNum -1
        if self.selectNum <= 1 then
            self.selectNum = 1
        end
        self:RefreshModule()
    elseif btnName == "BtnNext" then
        self.selectNum = self.selectNum +1
        if self.selectNum >= #self.moduleTable  then
            self.selectNum = #self.moduleTable
        end
        self:RefreshModule()
    --elseif btnName == "BtnDesc" then
    --    Hint({rectTransform = go.transform, content = Lan("mustdoback_desc"), alignment = 0})
	end
end

--本地监听
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
        self:RefreshData()
    end
end




--排序
function M:SortActiveInfo()

	local func = function(a, b)
		local status1 = self:ActStatue(a)
		local status2 = self:ActStatue(b)
		if status1 == status2 then
			return a.id < b.id
		else
			return status1 < status2
		end
	end
	table.sort(self.activeInfo, func)
	return self.activeInfo
end

--完成程度
function M:ActStatue(info)
    local num = dataMgr.ActMustDoData.MustDoFinNum(info.id)
    local max = info.dnum
    if num >= max then
        return 1
    else
        return 0
    end
end

--刷新特效
function M:RefreshModule()
    
    --self.moduleTable = excelLoader.SettingTable["mrbz_effect"] 
    local effextInfo = self.moduleTable[self.selectNum]

    UITools.SetImageGrey(self.btnLast, self.selectNum == 1)
    UITools.SetImageGrey(self.btnNext, self.selectNum == #self.moduleTable)
    local needDay = effextInfo.needdaynum
    if self.lv >= effextInfo.lv then
        self.showLvText.gameObject:SetActive(false)
    else
        self.showLvText.gameObject:SetActive(true)
        self.showLvText.text = string.format("%d级可以激活(约%d天可激活)",effextInfo.lv,needDay)
    end

    self.titleName.text = effextInfo.name

    if not self.effectTrans then self.effectTrans = {} end
    local effextName = effextInfo.effectid
    if not self.effectTrans[effextName] then
        self.effectTrans[effextName] = effectMgr:SpawnToUI(effextName, transPosition, self.effectTran, 0)
    end

    for k, v in pairs(self.effectTrans) do
        UITools.SetActive(v, k==effextName)
    end
    
end

--左侧数据
function M:RefreshLeftData()

    --等级
    self.lv =  self.mustdoInfo.lv
    --当前经验
    self.nowExp = self.mustdoInfo.exp
    --奖励列表
    self.rewardTable =  dataMgr.ActMustDoData.RewardTable()
    self.rewardID = self.rewardTable[self.lv + 1]



    local expID = excelLoader.SettingTable["mrbz_expgroupid"] 
    local attrID = excelLoader.SettingTable["mrbz_attrgroupid1"]  
    local attrAddID = excelLoader.SettingTable["mrbz_attrgroupid2"] 

    --经验，基础属性，加成
    local expTable = excelLoader.ExpTable[expID * 1000 + self.lv]
    local attrTable = excelLoader.AttrGrowthTable[attrID * 1000 + self.lv]
    local attrAddTable = excelLoader.AttrGrowthTable[attrAddID * 1000 + self.lv]

    --等级区间
    local lvExtend = excelLoader.SettingTable["mrbz_attrgroupid2_lv"]
    for i,v in ipairs(lvExtend) do
        if self.lv >= v then
            self.nextLv = lvExtend[i + 1]
        end
    end

   

    --经验，基础属性，加成（下一级）
    local expNextTb = excelLoader.ExpTable[expID * 1000 + self.lv + 1]
    local attrNextTb = excelLoader.AttrGrowthTable[attrID * 1000 + self.lv + 1]
    local attrAddNextTb = excelLoader.AttrGrowthTable[attrAddID * 1000 + self.nextLv]
    local woeldExpTb = excelLoader.SettingTable["mrbz_day_reward"] 
    --世界等级
    self.worldLv = dataMgr.PlayerData.GetWorldLv() or 0
    for i,v in ipairs(woeldExpTb) do
        if  self.worldLv >= v.worldlv then
            self.extraLv = v.needexp
        end
    end

    if self.mustdoInfo.dailyexp < self.extraLv then
        self.extraText.text =   string.format("<color=#FF0025FF>%d</color>/%d经验可领取",self.mustdoInfo.dailyexp,self.extraLv) 
    else
        self.extraText.text =   string.format("%d/%d经验可领取",self.mustdoInfo.dailyexp,self.extraLv) 
    end
    if self.mustdoInfo.reward  then
        self.extraText.text = "已领取"
    end
    

    self.nowMaxExp = expTable.exp

    self.LV.text =  string.format("%d 级",self.lv)
    self.expText.text = string.format("%d/%d",self.nowExp,self.nowMaxExp)
    self.sliderLv.value = self.nowExp / self.nowMaxExp



    --属性值
    self.hpAdd.text = string.format("生命%d",attrTable.maxhp) 
    self.atkAdd.text = string.format("攻击%d",attrTable.matk)
    self.defAdd.text = string.format("防御%d",attrTable.mdef)
    self.hpNext.text = string.format("+%d(下级)",attrNextTb.maxhp - attrTable.maxhp)
    self.atkNext.text = string.format("+%d(下级)",attrNextTb.matk - attrTable.matk)
    self.defNext.text = string.format("+%d(下级)",attrNextTb.mdef - attrTable.mdef)
    --属性增长比例
    self.allHpAdd.text = string.format("生命总属性 +%d%%",attrAddTable.maxhp * 100) 
    self.allAtkAdd.text = string.format("攻击总属性 +%d%%",attrAddTable.matk * 100) 
    self.allDefAdd.text = string.format("防御总属性 +%d%%",attrAddTable.mdef * 100) 
    self.allHpNext.text = string.format("+%d%%(%d 级获得)",attrAddNextTb.maxhp * 100,self.nextLv) 
    self.allAtkNext.text = string.format("+%d%%(%d 级获得)",attrAddNextTb.matk * 100,self.nextLv) 
    self.allDefNext.text = string.format("+%d%%(%d 级获得)",attrAddNextTb.matk * 100,self.nextLv) 

    --奖励
    if self.rewardGoList == nil then
        self.rewardGoList = {} 
    end
    -- 刷新奖励
    UITools.CopyRewardList({self.rewardID.rewardid}, self.rewardGoList, self.transRewardItem, rewardExParams)

    self.allFight.text = ScoreBuilder.GetMustDoScore(self.lv)
    self.fightAdd.text = ScoreBuilder.GetMustDoScore(self.lv + 1) - ScoreBuilder.GetMustDoScore(self.lv)

    
end

--右侧数据
function M:RefreshRightData()
    self.uiActLoop.ItemsCount = #self.ActiveInfo 
end


function M:IsorNotNotify()

    local extraNotify = dataMgr.ActMustDoData.IsMustExtranNotify()
    local uplvNotify = dataMgr.ActMustDoData.IsMustUpNotify()
    --进入一次即取消红点
    local backNotify = dataMgr.ActMustDoData.IsMustBackNotify()
    --额外奖励
    notifyMgr.AddNotify(self.btnExtra, extraNotify, notifExtra, notifyMgr.NotifyType.Common)
    --升级
    notifyMgr.AddNotify(self.btnUP, uplvNotify, notifUpLv, notifyMgr.NotifyType.Common)
    --找回
    notifyMgr.AddNotify(self.btnBack, backNotify, notifBack, notifyMgr.NotifyType.Common)
end
return M