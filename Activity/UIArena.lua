
--[[
本地物品tips
无使用，无出售按钮

]]

local UguiLuaEvent = require "UguiLuaEvent"

local PVPData = require "Data.PVPData"
local ItemTable = require "Excel.ItemTable"

local UICommonItem = require "UI.Widgets.UICommonItem"
local UIWidgetBase = require("UI.Widgets.UIWidgetBase")

local base = require "UI.UILuaBase"
local M = base:Extend()
local SettingTable = require "Excel.SettingTable"
local GradeTable = require "Excel.GradeTable"
local ItemData = require("Data.ItemData")

M.fixedInfoData = {
    isShow = true,
    showPos = Vector2.zero,
    ItemID =  {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, 806}
}
--M.needPlayShowSE = true

local txtRewardDesc = {"本日成功挑战一名玩家", "本日挑战竞技场五次", "本日挑战竞技场十次"}

local openPanelIndex = 1
-- panelID 1 演武，2进阶
function M.Open(params)
    if type(params) == "number" then
        openPanelIndex = params
    else
        openPanelIndex = 1
    end
    
    uiMgr.ShowAsync("UIArena")
end

function M:Awake()
    base.Awake(self)

    self.uiOffset = self:FindGameObject("Offset")
    self.panelYanwu = self:FindTransform("Offset/Panel (0)")
    self.panelTable = {}
    for i = 0,1 do 
        table.insert(self.panelTable , self:FindTransform(string.format("Offset/Panel (%d)" , i)))
    end

    self.transFightPrefab = self:FindTransform("Right/Scroll View/Viewport/Content/FightPrefab", self.panelYanwu)
    self.transFightPrefabParent = self.transFightPrefab.parent
    self.panelYanwuChallenge = self:FindTransform("PanelRewardCha", self.panelYanwu)
    self.panelYanwuLeft = self:FindTransform("Left", self.panelYanwu)
    self.textFresh = self:FindText("Right/BtnRefresh/Text", self.panelYanwu)

    self.transFightPrefab.gameObject:SetActive(false)

    UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)

    self.toggles = {}
    for i=1,2 do
        local tog = self:FindToggle(string.format("Offset/ToggleGroup/Toggle (%d)" , i))
        table.insert(self.toggles, tog)
        UguiLuaEvent.ToggleClick(tog.gameObject, self, M.OnClickTog)
    end

    UguiLuaEvent.ExternalOnDown(self.panelYanwuChallenge.gameObject, self, M.OnClickPanelChallenge)

    self.guideTrans = nil

    self.transHeadMe = self:FindTransform("Offset/Panel (0)/Left/HeadMe")

    self.btnShop = self:FindTransform("Offset/Panel (0)/Right/BtnShop")
end

function M:Show()
    base.Show(self)
    self.isSendRefresh = false

    self.panelYanwuChallenge.gameObject:SetActive(false)
    self:ChangePanel(openPanelIndex)
    --界面打开，缩放动画
    self:TweenOpen(self.uiOffset)
    self.toggles[self.curSelectPanel].isOn = true

    local playerInfo = dataMgr.PlayerData.GetRoleInfo()
    UITools.SetFriendInfo(self.transHeadMe, playerInfo)

    -- 打开界面就请求一次数据
    PVPData.SendSyncPvpInfo()
    PVPData.SendGetPvpRecord()

    -- 有列表显示（不允许为空，难看)且次数为0时就不向服务器请求刷新了
    local needRefresh = true
    local targetListPB = PVPData.GetPvpTargetList()
    local remainNum = PVPData.GetPvpRemainNum()
    if targetListPB and #targetListPB.list == 4 and remainNum == 0  then
        needRefresh = false
    end 
    if needRefresh then
        PVPData.SendPVPRefresh(false, false, true)
    end
end

function M:ResetDataYanwu()
    self:InitMyInfo()
    self:InitTargetList()
    self:PvpRecord()

    if self.listSavePvpTargetList and #self.listSavePvpTargetList > 0 then
        local index = Mathf.Max(1, #self.listSavePvpTargetList - 1)
        self.guideTrans = self.listSavePvpTargetList[index].goBtnChallenge.transform
    end

    self:RefreshRewardWnd(self.pvpChestBoxIdx)
end

function M.SortList(a, b)
    if a.pvpscore == b.pvpscore then
        return a.guid < b.guid
    else
        return a.pvpscore > b.pvpscore
    end
end

function M:InitTargetList()
    local targetListPB = PVPData.GetPvpTargetList()

    if self.listSavePvpTargetList == nil then
        self.listSavePvpTargetList = {}
    end
    local remainNum = PVPData.GetPvpRemainNum()
    local textTips = self:FindText("Right/TextTips", self.panelYanwu)

    local list = {}
    local str = ""
    if targetListPB and #targetListPB.list > 0 then
        list = targetListPB.list
        table.sort(list, self.SortList)
    elseif remainNum == 0 then
        str = "次数不足"
    else
        str = "没有挑战数据"
    end
    textTips.text = str
    self:CreateTargetPrefabs(self.listSavePvpTargetList, list, self.transFightPrefab.gameObject, self.transFightPrefabParent)
end

-- 创建记录prefab
-- PvpRecordList PvpTargetInfo
function M:CreateTargetPrefabs(listSave , pbList , goPrefab , transParent ,onclickCaller, onClickCallback)
    local len = #pbList
    UIWidgetBase.DynamicCreateMore(listSave , len , goPrefab , transParent , onclickCaller , onClickCallback)

    for i=1,len do
        local trans = listSave[i].go.transform
        local widgetIns = listSave[i]
        if widgetIns.transPlayerInfo == nil then
            widgetIns.transPlayerInfo = self:FindTransform("Item", trans)
            widgetIns.txtPlayerName = self:FindText("TextName", trans)
            widgetIns.txtCup = self:FindText("Cup/Text", trans)
            if widgetIns.heroHeadTbl == nil then 
                widgetIns.heroHeadTbl = {}
                for ci=1,4 do
                    widgetIns.heroHeadTbl[ci] = self:FindTransform(string.format("Heads/Item (%s)", ci), trans)
                end
            end
            widgetIns.goBtnChallenge = self:FindGameObject("BtnChallenge", trans)
            UguiLuaEvent.ButtonClick(widgetIns.goBtnChallenge, self, function(go)
                self:OnClickChallenge(widgetIns)
            end)

            widgetIns.transStars = {}
            widgetIns.transStars[1] = self:FindTransform("Stars/Image (1)", trans)
            widgetIns.transStars[2] = self:FindTransform("Stars/Image (2)", trans)
        end
        
        local playerPB = pbList[i]
        widgetIns.playerPB = playerPB
        for ci=1,4 do
            if ci <= #playerPB.herolist then
                widgetIns.heroHeadTbl[ci].gameObject:SetActive(true)
                HeroTool.SetHeroInfo(widgetIns.heroHeadTbl[ci], playerPB.herolist[ci])
            else
                widgetIns.heroHeadTbl[ci].gameObject:SetActive(false)
            end
        end
        UITools.SetUnitHead(widgetIns.transPlayerInfo, pbList[i])

        widgetIns.txtPlayerName.text = playerPB.name
        widgetIns.txtCup.text = playerPB.pvpscore

        widgetIns.transStars[1].gameObject:SetActive(playerPB.star > 0)
        widgetIns.transStars[2].gameObject:SetActive(playerPB.star > 1)
    end
end

function M:InitMyInfo()
    local pvpInfo = PVPData.GetLocalPlayerPvpInfo()
    if pvpInfo == nil then
        self.panelYanwuLeft.gameObject:SetActive(false)
        return
    else
        self.panelYanwuLeft.gameObject:SetActive(true)
    end

    local cupScore = pvpInfo.pvpscore
    local remainChaNum = PVPData.GetPvpRemainNum()
    local record = require("Data.ActivityData").GetRecordInstance()
    self.maxStar = record:Max("pvp_star")
    local startRewardID = SettingTable.pvp_star_chest[2]
    self.curStar = record:Get("pvp_star")

    if self.imgChestTransTbl == nil then
        self.imgChestTransTbl = {}
        for i=1,3 do
            self.imgChestTransTbl[i] = self:FindImage(string.format("Left/Rewards/Reward (%s)/ImgBg", i), self.panelYanwu)
        end
    end
    self:FindText("Left/Title/TextCup", self.panelYanwu).text = tostring(cupScore)
    self:FindText("Left/TextNum", self.panelYanwu).text = "挑战次数: "..tostring(remainChaNum)
    self:FindText("Left/StarSlider/ImageBG/Text", self.panelYanwu).text = string.format("%s/%s", self.curStar, self.maxStar)
    self:FindTransform("Left/StarSlider/ImageBG/Image", self.panelYanwu).localScale = Vector3.New(self.curStar/self.maxStar, 1, 1)
    local transSoulChest = self:FindTransform("Left/XinghunBaohe", self.panelYanwu)
    --notifyMgr.AddNotify(transSoulChest, self:StarSoulCanGet(), Vector3.New(33,33,0))
    local transeff = UITools.SetItemQualityEffect(transSoulChest, 4)
    if not tolua.isnull(transeff) then
        transeff.gameObject:SetActive(self:StarSoulCanGet())
    end
    
    for i=1,3 do
        local trans = self:FindTransform(string.format("Left/Rewards/Reward (%s)", i), self.panelYanwu)
        local status = self:GetRewardState(i)
        UITools.SetAllChildrenGrey(trans, status == 3)
        notifyMgr.AddNotify(trans, status == 2, Vector3.New(22,30,0))
    end
    
end

function M:PvpRecord()
    local targetList = PVPData.GetPvpRecordList()
    if self.listSavePvpRecordList == nil then
        self.listSavePvpRecordList = {}
        self.recordPrefab = self:FindTransform("Left/Scroll View/Viewport/Content/Prefab", self.panelYanwu)
        self.recordPrefabParent = self.recordPrefab.parent
        self.recordPrefab.gameObject:SetActive(false)
        self.recordTxtTips = self:FindText("Left/TextTips", self.panelYanwu)
    end

    self.recordTxtTips.text = ""
    if targetList ~= nil and #targetList.list > 0 then
        self:CreatePvpRecordPrefabs(self.listSavePvpRecordList, targetList.list, self.recordPrefab.gameObject, self.recordPrefabParent)
    else
        self.recordTxtTips.text = "没有挑战记录"
    end
end

function M:CreatePvpRecordPrefabs(listSave , pbList , goPrefab , transParent ,onclickCaller, onClickCallback)
    local len = #pbList
    UIWidgetBase.DynamicCreateMore(listSave , len , goPrefab , transParent , onclickCaller , onClickCallback)

    for i=1,len do
        local trans = listSave[i].go.transform
        local widgetIns = listSave[i]
        if widgetIns.transFanji == nil then
            widgetIns.text = self:FindText("Text", trans)
            widgetIns.transFanji = self:FindTransform("BtnFanji", trans)
            UguiLuaEvent.ButtonClick(widgetIns.transFanji.gameObject, self, function(go)
                self:OnClickFanji(widgetIns)
            end)
        end
        
        local recordPB = pbList[i]
        widgetIns.recordPB = recordPB
        local txt, needFanji = PVPData.FormatPvpRecord(recordPB)
        widgetIns.text.text = txt
        widgetIns.transFanji.gameObject:SetActive(needFanji)
    end
end

function M:RefreshRewardWnd(idx, openwnd)
    if idx == nil then return end
    
    self.pvpChestBoxIdx = idx
    local pvpInfo = PVPData.GetLocalPlayerPvpInfo()
    local isOpen = PVPData.CheckPvpChestIsOpen(idx)
    local winNum = self:GetRewardNeedNum(idx)
    local settingtbl = PVPData.GetChallengeReward(idx)
    local desc = txtRewardDesc[idx]

    if openwnd then
        self.panelYanwuChallenge.gameObject:SetActive(true)
    end

    self:RefreshRewardChallenge(settingtbl[2], isOpen, winNum, settingtbl[1], desc)
end

-- 1未达成 2 可领取 3 已领取
function M:GetRewardState(idx)
    local isOpen = PVPData.CheckPvpChestIsOpen(idx)
    if isOpen then return 3 end
    local settingtbl = PVPData.GetChallengeReward(idx)
    local needWinNum = settingtbl[1]
    local pvpInfo = PVPData.GetLocalPlayerPvpInfo()
    local winNum = self:GetRewardNeedNum(idx)
    if winNum >= needWinNum then return 2 end
    return 1
end

function M:GetRewardNeedNum(idx)
    local _winNum,_chaNum = PVPData.GetPvpNeedNum()
    local winNum = _winNum
    -- 第一次是首胜，剩余的为战斗次数
    if idx > 1 then
        winNum =  _chaNum
    end
    return winNum
end

-- winNum，needWinNum 第一次是首胜，剩余的为战斗次数 
function M:RefreshRewardChallenge(rewardID, isOpen, winNum, needWinNum, desc)
    if self.rewardChallengeTbl == nil then
        self.rewardChallengeTbl = {}
        local transParent = self:FindTransform("PanelRewardCha/Rewards", self.panelYanwu)
        for i = 1, 4 do 
            self.rewardChallengeTbl[i] = UICommonItem.DynamicCreate(transParent)
        end
    end

    local itemNums = ItemData.GetRewardList({rewardID})
    for i = 1, 4 do
        local uiitem = self.rewardChallengeTbl[i]
        if i <= #itemNums then
            uiitem:ResetInput()
            uiitem:ShowItem(ItemTable[itemNums[i].itemid], nil, itemNums[i].num, nil, true)
        else
            uiitem:ResetInput()
            uiitem:SetData()
        end
    end

    local btnStr = "达成"
    local btnStyle = "green"
    self.chestBtnStatus = 0
    if winNum < needWinNum then
        btnStr = "未达成"
        btnStyle = "disable"
        self.chestBtnStatus = 1
    end
    if isOpen then
        btnStr = "已领取"
        btnStyle = "disable"
        self.chestBtnStatus  = 2
    end
    self:FindText("PanelRewardCha/Text", self.panelYanwu).text = desc
    self:FindText("PanelRewardCha/BtnGetChestReward/Text", self.panelYanwu).text = btnStr
    UITools.SetButtonImageStyle(self:FindImage("PanelRewardCha/BtnGetChestReward", self.panelYanwu), btnStyle)
end

function M:OnClickChallenge(widgetIns)
    PVPData.SendPVPFight(widgetIns.playerPB)
end

function M:OnClickFanji(widgetIns)
    PVPData.SendFanji(widgetIns.recordPB)
end

function M:OnClick(go)
    local name = go.name
    if name == "BtnRefresh" then
        self.isSendRefresh =  PVPData.PVPRefreshWithTimeLimit()
    elseif name == "BtnShop" then
        OpenUI("UIShop", {panelIndex=3,chooseshopid=3000})
    elseif name == "BtnBuzhen" then
        OpenUI("UIFormation")
    elseif name == "BtnRank" then
        OpenUI("UITop", {topType = Const.TOP_INDEX_PVP})
    elseif name == "Reward (1)" then
        self:OnClickChallengeReward(1)
    elseif name == "Reward (2)" then
        self:OnClickChallengeReward(2)
    elseif name == "Reward (3)" then
        self:OnClickChallengeReward(3)
    elseif name == "BtnGetChestReward" then
        if self.chestBtnStatus == 0 then
            PVPData.SendGetChest(self.pvpChestBoxIdx)
        end
    elseif name == "ButtonClose" then
        self:Hide()
    elseif name == "XinghunBaohe" then
        self:OpenStarSoulChest()
    elseif name == "Toggle (0)" then
        self:ChangePanel(1)
    elseif name == "Toggle (1)" then
        self:ChangePanel(2)
    elseif name == "ButtonTips" then
        Hint({content = Lan("rule_pvp_001") , rectTransform = go.transform, alignment = 0})
    elseif name == "ButtonLevelUpCha" then
        local pvpInfo = PVPData.GetLocalPlayerPvpInfo()
        if self.nextGradeItemTb and self.nextGradeItemTb.score <= pvpInfo.pvpscore then
            PVPData.SendPvpGradeUp()
        else
            if self.nextGradeItemTb then
                Tips("杯数不足")
            else
                Tips("已达最大阶")
            end
        end
    end
end

function M:StarSoulCanGet()
    if not self.curStar or not self.maxStar then
        return false
    end

    if self.curStar < self.maxStar then
        return false
    end

    return true
end

function M:OpenStarSoulChest()
    --需要累积25颗星魂后才能打开
    if not self.curStar or not self.maxStar then
        return
    end
    if self.curStar < self.maxStar then
        Tips(string.format("需要累积%d颗星魂后才能打开", self.maxStar))
        return 
    end

    --[[
       if PVPData.CheckPvpChestIsOpen(0) then
            Tips("宝箱已经打开")
            return
        end 
    ]]

    PVPData.SendGetStarChest()
end

function M:OnClickChallengeReward(idx)
    self:RefreshRewardWnd(idx, true)
end

function M:OnClickPanelChallenge()
    self.panelYanwuChallenge.gameObject:SetActive(false)
end

function M:ResetDataStageUp()
    if self.stageUpTb == nil then
        self.stageUpTb = {}
        self.stageUpTb.panel = self:FindTransform("Offset/Panel (1)")
        local curPanel = self.stageUpTb.panel
        self.stageUpTb.transBot = self:FindTransform("Right/Bot", curPanel)
        self.stageUpTb.txtBotTips = self:FindText("Right/TxtTips", curPanel)
        self.stageUpTb.txtNeedCup = self:FindText("Right/Bot/TxtNeedScore", curPanel)
        self.stageUpTb.curStage = self:FindTransform("Left/CurStage", curPanel)
        self.stageUpTb.nextStage = self:FindTransform("Left/NextStage", curPanel)
        self.stageUpTb.shilianTbRoot = {}
        self.stageUpTb.shilianTb = {}
        self.stageUpRTTb = {}
        for i=1,3 do
            self.stageUpTb.shilianTbRoot[i] = self:FindTransform(string.format("Right/Heros/Content/Item (%d)", i), curPanel)
            self.stageUpRTTb[i] = self:LoadRenderTexture("ImgBg/CharRoot/CameraModel", "ImgBg/CharRoot/RawImage", "RT256_"..i, 
                self.stageUpTb.shilianTbRoot[i])
        end
    end
    local pvpInfo = PVPData.GetLocalPlayerPvpInfo()
    if pvpInfo == nil then
        self.stageUpTb.panel.gameObject:SetActive(false)
        return
    else
        self.stageUpTb.panel.gameObject:SetActive(true)
    end
    local GradeItemTb = PVPData.GetGradeTable(pvpInfo.grade)
    if GradeItemTb == nil then Debugger.LogWarning("GradeItemTb == nil"); return end
    local nextGradeItemTb = PVPData.GetGradeTable(pvpInfo.grade+1)
    self.nextGradeItemTb = nextGradeItemTb
    
    self:SetStageInfo(self.stageUpTb.curStage, GradeItemTb)
    self:SetStageInfo(self.stageUpTb.nextStage, nextGradeItemTb)

    local shilianDataTb = PVPData.GetJJCStageUpConfig()
    for i=1,3 do
        self.stageUpTb.shilianTb[i] = self.stageUpTb.shilianTb[i] or {}
        self:SetShiLianGuan(self.stageUpTb.shilianTbRoot[i], self.stageUpTb.shilianTb[i], shilianDataTb[i])
    end

    self.stageUpTb.transBot.gameObject:SetActive(true)
    local strNeedCup = ""
    local strTips = ""
    local status = PVPData.GetJJCStageUpStatus()
    if status == PVPData.JJCStatus.Top then
        strTips = "已达最大阶"
        self.stageUpTb.transBot.gameObject:SetActive(false)
    elseif status == PVPData.JJCStatus.ScoreNotEnough then
        local colorCode = "ff0000"
        strNeedCup = string.format("<color=#%s>%s</color>", colorCode, nextGradeItemTb.score)
    else
        local colorCode = Const.Colors.green
        strNeedCup = string.format("<color=#%s>%s</color>", colorCode, nextGradeItemTb.score)
    end
    self.stageUpTb.txtNeedCup.text = strNeedCup
    self.stageUpTb.txtBotTips.text = strTips
end

function M:SetStageInfo(root, gradeItemTb)
    if not gradeItemTb then
        root.gameObject:SetActive(false)
        return
    end
    root.gameObject:SetActive(true)
    local icon = gradeItemTb.icon
    local gradename = gradeItemTb.gradename
    local RewardTable = require "Excel.RewardTable"
    local rewardItemKvp = nil
    if gradeItemTb.rewarditem then
        rewardItemKvp = ItemData.GetRewardList({gradeItemTb.rewarditem[1]})
    end

    UITools.SetImageIcon(self:FindImage("ImageStage", root), Const.atlasName.Common, icon)
    self:FindText("TextStage", root).text = gradename
    if rewardItemKvp and rewardItemKvp[1] then
        UITools.SetCostMoneyInfo(self:FindText("Reward1/Text", root), self:FindImage("Reward1/Image", root), rewardItemKvp[1].itemid, rewardItemKvp[1].num, "")
    else
        UITools.SetCostMoneyInfo(self:FindText("Reward1/Text", root), self:FindImage("Reward1/Image", root))
    end
    
    if rewardItemKvp and rewardItemKvp[2] then
        UITools.SetCostMoneyInfo(self:FindText("Reward2/Text", root), self:FindImage("Reward2/Image", root), rewardItemKvp[2].itemid, rewardItemKvp[2].num, "")
    else
        UITools.SetCostMoneyInfo(self:FindText("Reward2/Text", root), self:FindImage("Reward2/Image", root))
    end
end

function M:SetShiLianGuan(root, saveInTb, configTb)
    if not saveInTb.isInit then
        saveInTb.isInit = true
        saveInTb.txtName = self:FindText("ImgBg/CharRoot/TxtName", root)
        saveInTb.txtScore = self:FindText("ImgBg/CharRoot/TxtScore", root)
        saveInTb.modelParent = self:FindTransform("ImgBg/CharRoot/CameraModel/Model", root)
        saveInTb.txtSort = self:FindText("ImgBg/CharRoot/ImgRight/Text", root)
        saveInTb.imgWin = self:FindImage("ImgBg/ImgWin", root)
        saveInTb.imgLock = self:FindImage("ImgBg/ImgLock", root)
        saveInTb.imgGrey = self:FindImage("ImgBg/CharRoot/ImageGrey", root)
    end

    saveInTb.txtName.text = configTb.name
    saveInTb.txtScore.text = "推荐评分:"..configTb.score
    saveInTb.imgLock.gameObject:SetActive(configTb.isLock)
    saveInTb.imgWin.gameObject:SetActive(configTb.isWin)
    saveInTb.imgGrey.gameObject:SetActive(configTb.isWin or configTb.isLock)
    saveInTb.txtSort.text = configTb.sortID

    UITools.LoadModel(configTb.npcid, "UIArenNPC"..configTb.npcid, saveInTb.modelParent)
end

function M:OnLocalMsg(cmd, msg)    
    if cmd == LocalCmds.PvpUpdate then
        self:ChangePanel()

        if msg and msg.cmd == Cmds.UpdatePvpTargetList.index and self.isSendRefresh then
            Tips("刷新成功")
            self.isSendRefresh = true
        end
    end

    if require("Data.ActivityData").CheckRecordUpdate(cmd, msg, nil, "pvp") then
        self:ChangePanel()
    end

    if cmd == LocalCmds.FightStart then
        -- 开启战斗时处理
		if fightMgr.curFightType == Const.BATTLE_TYPE_PVP then
			uiMgr.Hide("UIActivity")
            self:Hide()
		end
    end
end

-- 切换面板总开关
-- toPanelIdx = nil 时为重置当前面板
function M:ChangePanel(toPanelIdx)
    if toPanelIdx == nil then
        toPanelIdx = self.curSelectPanel
    end
    self.curSelectPanel = toPanelIdx or 1
    self:HideAllPanel(self.curSelectPanel)

    if toPanelIdx == 1 then
        self:ResetDataYanwu()
    else
        self:ResetDataStageUp()
    end

    self:UpdateNotify()
end

-- 除了showidx 的面板，其他都隐藏
function M:HideAllPanel(showIdx)
    for i = 1,2 do 
        if showIdx ~= i then
            self.panelTable[i].gameObject:SetActive(false)
        else
            self.panelTable[i].gameObject:SetActive(true)
        end
    end
end

function M:OnClickTog(go)
    if go.name == "Toggle (1)" then
        self:ChangePanel(1)
    elseif go.name == "Toggle (2)" then
        self:ChangePanel(2)
    end
end

local preUpdateTime = -999
function M:Update()
    base.Update(self)
    if Time.time - preUpdateTime < 1 then return end
    preUpdateTime = Time.time

    local remainTime = PVPData.GetPvpFreshRemainTime()
    if remainTime > 0 then
        self.textFresh.text = "刷新("..remainTime..")"
    else
        self.textFresh.text = "刷新"
    end
end 

local notifyPosition = Vector3.New(28.26,43.8,0)
function M:UpdateNotify()
    notifyMgr.AddNotify(self:FindTransform("Background", self.toggles[2].transform), notifyMgr.IsArenaNotify(), notifyPosition)  
end

return M