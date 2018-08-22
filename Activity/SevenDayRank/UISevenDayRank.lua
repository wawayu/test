local UguiLuaEvent = require "UguiLuaEvent"
local ScoreBuilder = require "ScoreBuilder"

local SkillTable = require "Excel.SkillTable"

local BusinessData = require "Data.BusinessData"
local BusinessActivityTable = require "Excel.BusinessActivityTable"
local base = require "UI.UILuaBase"
local M = base:Extend()

local preUpdateTime = -1
--设置图片大小
local rewardExParams = {isnative = false, showQualityEffect = true}
local toggleNotifyPos = Vector3.New(90,17,0)


local dayDesc={"一","二","三","四","五","六","七"}
local notifPosition = Vector3.New(85, 25, 0)



-------------------------运营活动

function M.Open(openParams)
    uiMgr.ShowAsync("UISevenDayRank")
end


function M:Awake()
    base.Awake(self)

    -----------------左侧导航栏
    --关闭按钮
    self.tranClose = self:FindTransform("Offset/ButtonClose")
    UguiLuaEvent.ButtonClick(self.tranClose.gameObject, self, M.Hide)

    --倒计时
    self.textTime = self:FindText("Offset/Right/Center/LeftTime/TxtLeft")
    --个人排名
    self.txtMyRank = self:FindText("Offset/Right/Center/MyRank/TxtRank")
    --跳转按钮
    self.uiBtnGo = self:FindGameObject("Offset/Right/Center/BtnGo")
    self.txtBtnGo = self:FindText("Offset/Right/Center/BtnGo/Text", self.transOffset)

    --左侧导航栏
    self.transLeftItem = self:FindLoop("Offset/Left/Scroll View/Viewport/Content")
    self:BindLoopEventAdvance(self.transLeftItem,M.OnCreatLeft,M.UpdateLeft,M.OnChooseLeft)

    -----------------右侧Scroll View奖励显示
    self.awardItemLoop=self:FindLoop("Offset/Right/Scroll View/Viewport/Content")
    self:BindLoopEventAdvance(self.awardItemLoop, M.OnCreateAward, M.UpdateAward)

    -----------------右侧Top信息
    self.dayImg = self:FindImage("Offset/Right/Top/TopRight/DayImg")
    self.activityType = self:FindImage("Offset/Right/Top/TopRight/ActivityType")
    self.rankTitle = self:FindImage("Offset/Right/Top/TopRight/RankTitle")
    --战力
    self.typeFight = self:FindText("Offset/Right/Top/FightNum/Fight/FightNumTxt")
    self.fourFight = self:FindText("Offset/Right/Top/FightNum/FightFour/FightNumTxt")
    self.sevenFight = self:FindText("Offset/Right/Top/FightNum/FightSeven/FightNumTxt")
    --第一名信息
    self.firstName = self:FindText("Offset/Right/Top/FirstInfo/TxtName")
    self.firstHead = self:FindImage("Offset/Right/Top/FirstInfo/ImgHead")
    --
    self.topLeft = self:FindGameObject("Offset/Right/Top/TopLeft")
    self.allFight = self:FindGameObject("Offset/Right/Top/FightNum")
    self.topRight = self:FindGameObject("Offset/Right/Top/TopRight")

    --前七天
    self.frontDayScore = self:FindGameObject("Offset/Right/Top/SevenDayScore")
    self.frontDayLv = self:FindGameObject("Offset/Right/Top/SevenDayLv")

    --描述
    self.ActDesc = self:FindText("Offset/Right/Top/ActDesc")
end


function M:Show()
    base.Show(self)

    --默认页签(通过此得到数据)
    self.curSelectIndex = 1

    self:RefreshPanel()
end


function M:RefreshPanel()
    --获取开服天数
    self.openDay = BusinessData.GetOpenDay()

    --活动ID信息表
    self.activeID = {}

    local readOnlyDatas = excelLoader.SettingTable["sevenid_rankinfo"]  
    for i, v in ipairs(readOnlyDatas) do
        if v.day >= self.openDay or v.day <= 0 then
            self.activeID[#self.activeID + 1] = v
        end
    end

    --增加判断
    if #self.activeID == 0 then
        self:Hide()
        return
    end

    if not self.allglobeIndex then
        self.allglobeIndex = self.activeID[1].day
    end

    if self.curSelectIndex > #self.activeID then
        self.curSelectIndex = 1
    end
    ------------------------------------------
    self.transLeftItem.ItemsCount =#self.activeID
    -------------通过ID得到活动相应的奖励，以及领取
    --进阶ID
    self.actID=self.activeID[self.curSelectIndex].id
    --排名ID    
    self.actRankID=self.activeID[self.curSelectIndex].idrank

    --通过ID的到相应的进阶以及排行表
    self.businessTab = BusinessActivityTable[self.actID]
    self.businessRankTab = BusinessActivityTable[self.actRankID]

	if not self.businessTab or not self.businessRankTab then
        --self:Hide()
        Debugger.LogWarning("exit is nil")
    end
    --进阶脚本
    --if self.allglobeIndex>0 then
    self.actScript = BusinessData.GetScript(self.actID)
    --end
    if not self.actScript then
       print(self.actID.."===========================")
    end


    --第一名信息
    local topType =self.businessRankTab.param1.topType
    self.topDatas = dataMgr.TopData.GetTopInfos(topType)
 
    --刷新数据
    self:RefreshRightData()
end

--------------------------------------左侧导航栏
function M:OnCreatLeft(coms)
    -- 天数
    coms.day=self:FindText("DayText", coms.trans)
    -- 活动
    coms.name=self:FindText("NameText",coms.trans)
    --选中框
    coms.select=self:FindGameObject("Background/Checkmark",coms.trans)

end

function M:OnChooseLeft(coms)
    preUpdateTime=-1
    local index = coms.globalIndex

    local info=self.activeID[index]
    --全局变化(以天数获得)
    self.allglobeIndex = info.day
    self.curSelectIndex = index
    self:RefreshPanel()

end
function M:UpdateLeft(coms)
    local index = coms.globalIndex
    local info=self.activeID[index]
    
    --具体天数从表中对应获得
    if info.day>0 then
        coms.day.text=string.format("第%s天",dayDesc[info.day])
    else
        coms.day.text="前七天"
    end

    coms.name.text=info.name
   
    --选择框显示
    if self.curSelectIndex == index then
        coms.select:SetActive(true)
    else
        coms.select:SetActive(false)
    end
    --活动正在进行中在
    if info.day==self.openDay and info.day>0  then
        coms.day.text=info.name
        coms.name.text="<color=#18A338FF>比拼中</color>"
    end

    local notify = dataMgr.BusinessData.SDRNotify(index,self.activeID)
    if notify then
        notifyMgr.AddNotify(coms.trans, true, notifPosition, notifyMgr.NotifyType.Common)
    else
        notifyMgr.AddNotify(coms.trans, false, notifPosition, notifyMgr.NotifyType.Common)
    end
    
    
end


--本地监听
function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Activity then
        -- if msg.cmd == Cmds.GetBackReward.index or msg.cmd == Cmds.GetGetBackInfo.index 
        -- or msg.cmd == Cmds.GetBusinessScoreReward.index or msg.cmd == Cmds.SyncRewardGet.index then
			self:RefreshPanel()
		-- end
	elseif cmd == LocalCmds.Business then
        self:RefreshPanel()
    elseif cmd == LocalCmds.Top then
        self:RefreshPanel()
    elseif cmd == LocalCmds.RoleLvUp then
        self:RefreshPanel()
    end
end

----------------------右侧奖励
--创建奖励列表
function M:OnCreateAward(coms)
    --个人领取奖励
    coms.txtName = self:FindText("TxtActivity", coms.trans)--活动名称
	coms.uiGet = self:FindGameObject("BtnFind", coms.trans)--领取
    coms.uiDone = self:FindGameObject("BtnDone", coms.trans)--已领取
    coms.mailSend = self:FindGameObject("MailSendTxt",coms.trans)--自动发放
	coms.uiNot = self:FindGameObject("ImgNot", coms.trans)
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
    coms.rewardContainer = {}

end

function M:GetLoopItem(index)
	return self.activityRewardList[index]
end

--选择领取奖励
function M:OnChoose(index, go)
    --列表下移
    local num=index-#self.rankRewardList
	local rewardData = self:GetLoopItem(num)
    self.actScript:SendGetReward(rewardData.id)
    preUpdateTime=-1
end


--更新奖励列表
function M:UpdateAward(coms)
    --先刷新个人领取列表
    local index = coms.globalIndex
    if index > #self.rankRewardList then
        local rewardData = self:GetLoopItem(index-#self.rankRewardList)
        --为空时不显示数据
        if rewardData == nil then
            return
        end
        local id = rewardData.id
        --名称,图标
        coms.txtName.text = self.actScript:GetUpgradeDesc(id)
        
        local status = self.actScript:Status(id)
        coms.uiNot:SetActive(status == 0)
        coms.uiGet:SetActive(status == 1)
        coms.uiDone:SetActive(status == 2)
        coms.mailSend:SetActive(false)
        --如果不在开启的日期内,不可领取
        if self.allglobeIndex ~= self.openDay and self.allglobeIndex>0 then
            coms.uiNot:SetActive(true)
            coms.uiGet:SetActive(false)
            coms.uiDone:SetActive(false)
        end
        -- 刷新奖励
        UITools.CopyRewardList({rewardData.rewardid}, coms.rewardContainer, coms.transRewardItem, rewardExParams)
        UguiLuaEvent.ButtonClick(coms.uiGet, nil, function(go)
            self:OnChoose(self.awardItemLoop:GetItemGlobalIndex(coms.go) + 1, coms)
        end)
    else    
        --排行奖励显示
        coms.uiNot:SetActive(false)
        coms.uiGet:SetActive(false)
        coms.uiDone:SetActive(false)
        coms.mailSend:SetActive(true)
        if self.rankRewardList then
            local rankData = self.rankRewardList[index]
            if rankData ~= nil then
                --名称,图标
                local str = ""
                if rankData.min == rankData.max then
                    str = rankData.min
                else
                    str = string.format("%s-%s", rankData.min, rankData.max)
                end
                coms.txtName.text = string.format("第%s名", str)
    
                -- 刷新奖励
                local mailid = rankData.tab.mailid
                local items = excelLoader.MailTable[mailid].items
                UITools.CopyRewardListWithItems(items, coms.rewardContainer, coms.transRewardItem, rewardExParams)            
            end
        end
    end
   	
end

--刷新右侧数据
function M:RefreshRightData()
   
     --个人进阶
     self.activityRewardList = self.actScript:GetRewards()
     --排行数据列表
     self.rankRewardList = BusinessData.GetRankRewardConfig(self.actRankID)

     --显示Loop表长度
     self.awardItemLoop.ItemsCount = #self.activityRewardList + #self.rankRewardList

    --活动结束时间
    self.endTime = BusinessData.GetEndTime(self.actRankID)


    --排行
    local rank = BusinessData.GetMyRank(self.actRankID)
    if rank > 0 then
        self.txtMyRank.text = string.format("第%s名", rank)
    else
        self.txtMyRank.text = "未上榜"
    end
    if self.allglobeIndex ~= self.openDay and self.allglobeIndex>0 then
        self.txtMyRank.text = "活动还未开启"
    end

    --按钮跳转
     if self.businessRankTab.buttonname then
        self.txtBtnGo.text = self.businessRankTab.buttonname
        UguiLuaEvent.ButtonClick(self.uiBtnGo.gameObject, self, M.OnClickGo)
    end

       -------------------------------右侧Top信息
    --前七天(控制各种按钮开关)
    if self.allglobeIndex<=0 then
        --称号ID
        self.rankTitle.gameObject:SetActive(false)
        self.typeFight.gameObject:SetActive(false)
        --左侧
        self.topLeft:SetActive(false)
        self.allFight:SetActive(false)
        self.topRight:SetActive(false)      
        if self.allglobeIndex == -1 then
                --战力
                self.frontDayScore:SetActive(true)
                self.frontDayLv:SetActive(false)
        elseif self.allglobeIndex == 0 then
                self.frontDayScore:SetActive(false)
                self.frontDayLv:SetActive(true)
        end
        self.ActDesc.gameObject:SetActive(false)
    else
        self.ActDesc.gameObject:SetActive(true)
        self.frontDayScore:SetActive(false)
        self.frontDayLv:SetActive(false)
        --称号ID
        self.rankTitle.gameObject:SetActive(true)
        self.typeFight.gameObject:SetActive(true)
        --左侧
        self.topLeft:SetActive(true)
        self.allFight:SetActive(true)
        self.topRight:SetActive(true)
        --战力
    end


    --称号ID
    if self.businessRankTab.param2.titleid then
        local titleid = self.businessRankTab.param2.titleid
        UITools.SetTitleIcon(self.rankTitle, titleid, true)
        local score = ScoreBuilder.GetTitleScore({{id=titleid}})
        self.typeFight.text = score
    end

    --七日活动天数显示
    if  self.businessRankTab.param2.day then
        self.dayImg.gameObject:SetActive(true)
        local day = self.businessRankTab.param2.day
        UITools.SetImageIcon(self.dayImg, Const.atlasName.SevenRank, day)
    end

    if self.businessRankTab.getdesc then
        --描述
        self.ActDesc.text = self.businessRankTab.getdesc
    end

 
    --排行类型图片设置
    local rankType = self.businessRankTab.param2.rankType
    UITools.SetImageIcon(self.activityType, Const.atlasName.SevenRank, rankType)
    

    
    --左侧战力信息
    self.fourFight.text = ScoreBuilder.GetTitleScore({{id=2018}})
    self.sevenFight.text = ScoreBuilder.GetTitleScore({{id=2010}})
    
    --第一名信息
    self.firstTopData = self.topDatas[1]
    if self.firstTopData then
        self.firstHead.gameObject:SetActive(true)
        local tableID, unitTab = unitMgr.UnpackUnitGuid(self.firstTopData.guid)
        uiMgr.SetSpriteAsync(self.firstHead, Const.atlasName.PhotoIcon, unitTab.headIcon)
        if self.firstTopData.name=="" then
            self.firstName.text=unitTab.name
        else
            self.firstName.text=self.firstTopData.name
        end
    else
        --没有排行榜数据
        self.firstHead.gameObject:SetActive(false)
        self.firstName.text="虚位以待"
    end
    --不在活动时间内
    if self.allglobeIndex~=self.openDay and self.allglobeIndex>0 then
        self.firstHead.gameObject:SetActive(false)
        self.firstName.text="虚位以待"
    end
end


--跳转
function M:OnClickGo()
	local topType = self.businessRankTab.param1 and self.businessRankTab.param1.topType
    
    if topType then
		OpenUI("UITop", {topType = topType})
	end
end


function M:Update()
    if Time.time - preUpdateTime < 1 then
       return
    end
    preUpdateTime = Time.time
    local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
    self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
    if self.allglobeIndex~=self.openDay and self.allglobeIndex>0 then
       self.textTime.text="活动还未开启！"
    end
end


return M