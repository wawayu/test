local base = require "UI.UILuaBase"
local HotSpringAnswerData = dataMgr.HotSpringAnswerData
local ItemTable = excelLoader.ItemTable
local SettingTable = excelLoader.SettingTable

local commonParamsTable = {showtips = true}

local M = base:Extend()

--状态
M.AnswerState = {
    Begin = 1,
    End = 2,
}


local randomTalk = {"答题开始啦~\n加油加油呦~","认真答题，\n不要瞎点","好好学习，\n天天答题"}

function M.Open(params)
    local info = HotSpringAnswerData.GetGuildAnswerInfo()
    if info == nil then
        return
    end
	uiMgr.ShowAsync("UIHotSpringAnswer")
end

function M:Awake()
    base.Awake(self)
    self.offset = self:FindGameObject("Offset")
    ---------------------------------答题界面----------------------------------
    self.panels = {
        [M.AnswerState.Begin] = self:FindTransform("Offset/PanelAnswer/Right/PanelBegin"),
        [M.AnswerState.End] = self:FindTransform("Offset/PanelAnswer/Right/PanelEnd")
    }

    self.uiPanelAnswer = self:FindGameObject("Offset/PanelAnswer")
    self.talkText = self:FindText("Offset/PanelAnswer/Left/HeadInfo/Talk/TextTalk")
    self.descText = self:FindText("Offset/PanelAnswer/Left/Desc/DescText")
    self.rightNumText = self:FindText("Offset/PanelAnswer/Left/AnswerRightNum/TextNum")
    self.answerNumText = self:FindText("Offset/PanelAnswer/Right/TextAt")
    self.timeText = self:FindText("Offset/PanelAnswer/Right/TextTime/Text")
    self.questionText = self:FindText("Offset/PanelAnswer/Right/PanelBegin/TextQuestion")

    --四个选项Item
    self.optionItems = {}
    for i=1, 4 do
        local tmpTrans = self:FindTransform(string.format("Offset/PanelAnswer/Right/PanelBegin/Grid/Item (%s)", i))
        self.optionItems[i] = {
            trans = tmpTrans,
            label = self:FindText("TextDesc", tmpTrans),
            imageSelect = self:FindImage("ImageSelect", tmpTrans),
            imageWrong = self:FindImage("ImageWrong", tmpTrans),
            imageRight = self:FindImage("ImageRight", tmpTrans),
            btn = tmpTrans.gameObject:GetComponent(typeof(Button))
        }
        UguiLuaEvent.ButtonClick(tmpTrans.gameObject, self, function(go)
            self:OnClickChoose(i)
        end)
    end
    
    self.tipBtn = self:FindTransform("Offset/TipDicingBtn")

    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/PanelAnswer/Left/HeadInfo/Image"), self, M.OnClickTalk)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/PanelAnswer/Left/Dicing/GoDicingBt"), self, M.OnClickGoDicing)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.OnClickClose)
    UguiLuaEvent.ButtonClick(self.tipBtn.gameObject, self, M.OnClickTipDicing)

    ---------------------------掷骰子界面--------------------------------------
    
    self.uiPanelDicing = self:FindGameObject("Offset/PanelDicing")

    self.uiRightLoop = self:FindLoop("Offset/PanelDicing/Right/Frame/Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiRightLoop, M.OnCreateItem, M.UpdateTabItem)

    self.noTip = self:FindGameObject("Offset/PanelDicing/Left/NoTip")

    self.myRankText = self:FindText("Offset/PanelDicing/Left/RankPanel/MyRankImg/MyRank")
    self.mypostText = self:FindText("Offset/PanelDicing/Left/RankPanel/MyRankImg/PostText")
    self.myScoreText = self:FindText("Offset/PanelDicing/Left/RankPanel/MyRankImg/ScoreImg/ScoreText")

    self.uiLeftLoop = self:FindLoop("Offset/PanelDicing/Left/RankPanel/Scroll View/Viewport/Content")
    self:BindLoopEventEx(self.uiLeftLoop, M.OnCreateRankItem, M.OnUpdateRankItem)

    self.diceEffectTrans = self:FindTransform("Offset/PanelDicing/DiceEffect")

    self.goDice = self:FindGameObject("Offset/PanelDicing/Right/Frame/DicingBg")
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/PanelDicing/Right/Frame/DicingBg/DicingBt"), self, M.OnClickDicing)
    ----------------------------------------------------------------------------
    self.toggleTabs = {}
    for i=1, 2 do
    	local tog = self:FindToggle(string.format("Offset/ToggleGroup/Toggle (%d)", i))
    	table.insert(self.toggleTabs, tog)
    	UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
            if _isOn then
            	self:SwitchPanel(i)
            end
    	end)
    end
end

local isShowTip = true

function M:Show()
    base.Show(self)

    self.preAnswerStart = nil

    self:ShowPanel(M.AnswerState.Begin)
    --默认打开活动界面
    if self.toggleTabs[1].isOn == true then
        self:SwitchPanel(1)
    else
        self.toggleTabs[1].isOn = true
    end
    self.talkText.text = randomTalk[1]

    self:RefreshPanel()
    
    self:DiceRefreshData()                                               

    self:TweenOpen(self.offset)
end

function M:ShowPanel(state)
    self.currentState = state
    for k, panel in pairs(self.panels) do
        panel.gameObject:SetActive(state == k)
    end
end

function M:RefreshPanel()
    --共多少道题
    self.maxCount = HotSpringAnswerData.AnswerQuestionMaxCount()
    --答题进度
    self.progress = HotSpringAnswerData.GetAnswerProgress()
    --答题开始时间
    local startTime = HotSpringAnswerData.AnswerBeginTime()
    --所有题目结束时间
    self.totalEndTime = HotSpringAnswerData.AnswerEndTime()
    --当前服务器时间
    local curTime = netMgr.mainClient:GetServerTime()
    --选择的哪一个
    local chooseProgress = HotSpringAnswerData.GetAnswerChooseProgress() 
    
    -- 答题是否开始
    local isAnswerStart = curTime >= startTime and curTime <= self.totalEndTime
    -- 结束了显示提示(isShowTip true显示答题，false显示提示)
    isShowTip = isAnswerStart 

    --现在是第几道题
    self.answerCount = math.ceil((curTime - startTime)/70)

    local index = 0
    if self.answerCount == 0 then
        self.answerCount = 1
    end
    if self.answerCount > self.maxCount then    
        index = self.maxCount
    else
        index = self.answerCount
    end
    self.timeEvery = SettingTable["guildanswer_time"][1]+SettingTable["guildanswer_time"][2]
    self.endTime = startTime + index * self.timeEvery  --结束时间
    self.checkTime = startTime + (self.answerCount*60 + (self.answerCount-1)*10)  --显示答案时间
    self.optionCount = #HotSpringAnswerData.GetAnswerTab(index)
    local count 
    if self.answerCount <= self.maxCount then
        count = self.answerCount
    else
        count = 0
    end
    self.answerNumText.text = string.format("第 %d/%d 题",  count, self.maxCount)
    self.rightNumText.text = HotSpringAnswerData.AnswerRightCount()  --答对了几道题

    -- 之前是开始，现在结束了,弹出跳转框
    if self.preAnswerStart and not isAnswerStart then
       self:ShowMsgBox()
    end
    self.preAnswerStart = isAnswerStart

    if not isShowTip then
        self:ShowPanel(M.AnswerState.End)
        return
    end

    self:ShowQuestion(self.answerCount)

    self.curChoose = nil  --当前选择的
    if self.progress == self.answerCount then
        if chooseProgress ~= nil then
            self.curChoose = chooseProgress  
            self.rightAnswer = HotSpringAnswerData.GetRightAnswer(self.progress)
            self:ShowIsRightAnswerState(self.curChoose, self.rightAnswer)
        end
    end
end

function M:ShowMsgBox()
    local rightCount = HotSpringAnswerData.AnswerRightCount()
    local str 
    if rightCount == self.maxCount then
        str = "答题结束，恭喜你答对了所有题目！"
    else
        str = string.format("答题结束，共答对%s题，下次要努力哦~", rightCount)
    end
    UIMsgbox.ShowTipCallback(str.."\n请前往掷骰子活动吧！", function(ok, params)
        if ok == true then
            self:GoDicing()
        end
    end, nil, '提示') 
end

local preUpdateTime = -999

function M:Update()
    if Time.realtimeSinceStartup - preUpdateTime < 1 then
        return
    end
    preUpdateTime = Time.realtimeSinceStartup
    local curTime = netMgr.mainClient:GetServerTime()

    if self.endTime then
        self.timeText.text = Utility.FormatTimeRemain(self.endTime)
    end
    if self.answerCount <= self.maxCount then
        if curTime > self.endTime then
            self:RefreshPanel()
        end
    end

    if curTime > self.checkTime then 
        for i=1, self.optionCount do
           --选择框
            local tmpComp = self.optionItems[i]
            tmpComp.btn.enabled = false
        end
        if self.curChoose ~= nil then
            self:ShowRightAnswer(self.curChoose, self.rightAnswer)
        end
    end

    if self.sendDiceTime and Time.realtimeSinceStartup > self.sendDiceTime then
        self.sendDiceTime = nil
        --发送投骰子请求
        HotSpringAnswerData.SendDicingRequest()
    end
end

--点击Tab切换界面
function M:SwitchPanel(tp)
	self.currentPanel = tp
	if tp == 1 then
		self.uiPanelAnswer.gameObject:SetActive(true)
		self.uiPanelDicing.gameObject:SetActive(false)
	elseif tp == 2 then
        self.uiPanelAnswer.gameObject:SetActive(false)
        self.uiPanelDicing.gameObject:SetActive(true)
        self:DiceRefreshData()
	end
end

--显示问题(第几道题，选择第几个)
function M:ShowQuestion(questionIndex)  
    --当已答的数量大于最大题量，答题结束,跳转掷骰子界面
    if questionIndex > self.maxCount then
        return
    end
    self.curQuesIndex = questionIndex
    --问题
    self.questionText.text = HotSpringAnswerData.GetQuestion(questionIndex)
    --获取当前题的四个选项  
    for i=1, 4 do
        local tmpComp = self.optionItems[i]
        tmpComp.trans.gameObject:SetActive(i <= self.optionCount)
    end
    for i=1, self.optionCount do
        local tmpComp = self.optionItems[i]
        tmpComp.label.text = string.format("%s.%s", string.char(64+i), HotSpringAnswerData.GetAnswerTab(questionIndex)[i] )     
        tmpComp.imageSelect.gameObject:SetActive(false)
        tmpComp.imageRight.gameObject:SetActive(false)
        tmpComp.imageWrong.gameObject:SetActive(false)
        tmpComp.btn.enabled = true
    end 
end

--点击任务，随机显示说话内容
function M:OnClickTalk(go)
    local index = math.random(1, #randomTalk)
    self.talkText.text = randomTalk[index]
end

--选择答案
function M:OnClickChoose(chooseIndex)
    if chooseIndex ~= nil then
        self.curChoose = chooseIndex
        HotSpringAnswerData.GetAnswerChooseProgress(chooseIndex)
        --正确答案
        self.rightAnswer = HotSpringAnswerData.GetRightAnswer(self.curQuesIndex)
        if chooseIndex == self.rightAnswer then
            self.condition = 1 --正确
        else
            self.condition = 0 --错误
        end
        self:ShowIsRightAnswerState(chooseIndex, self.rightAnswer)
        HotSpringAnswerData.RequestAnswerQuestion(self.curQuesIndex, self.condition, chooseIndex)
    end
end

--显示是否是正确答案状态
function M:ShowIsRightAnswerState(curChoose, rightAnswer)
    for i=1, self.optionCount do
        local tmpComp = self.optionItems[i]
        tmpComp.imageSelect.gameObject:SetActive(i==curChoose)
        tmpComp.btn.enabled = false
        if i == curChoose then
            ---只显示选中是否正确状态
            local ischooseRight = (i == rightAnswer)              
            tmpComp.imageRight.gameObject:SetActive(ischooseRight)
            tmpComp.imageWrong.gameObject:SetActive(not ischooseRight)
        end
    end
end

--显示正确答案
function M:ShowRightAnswer(curChoose, rightAnswer)
    if curChoose ~= rightAnswer then
        for i=1, self.optionCount do
            local tmpComp = self.optionItems[i]
            if i == rightAnswer then
                --显示正确答案的状态              
                tmpComp.imageRight.gameObject:SetActive(true)
                tmpComp.imageWrong.gameObject:SetActive(false)
            end
        end
    end

end

function M:OnClickTipDicing(go)
    if self.currentState == M.AnswerState.Begin then 
        self:OnClickGoDicing()
    else
        self.tipBtn.gameObject:SetActive(false)
        self:GoDicing()
    end
end

function M:OnClickGoDicing(go)
    if self.currentState == M.AnswerState.Begin then
        UIMsgbox.ShowTip("全部问题回答完毕才能掷骰子！", '提示') 
    elseif self.currentState == M.AnswerState.End then 
        self:GoDicing()
    end  
end

---------前往掷骰子按钮
function M:GoDicing()
    self.toggleTabs[1].isOn = false
    self.uiPanelAnswer.gameObject:SetActive(false)
    self.toggleTabs[2].isOn = true
    self.uiPanelDicing.gameObject:SetActive(true)
    self:DiceRefreshData()
end

-------------关闭
function M:OnClickClose(go)
    self:Hide()
    
    -- if self.currentState == M.AnswerState.Begin then
    --     UIMsgbox.ShowChoose("题还未答完，你确定要退出吗？", function(ok, params)
    --         if ok == true then
    --             self:Hide()
    --         end
    --     end, nil, '提示')
    -- else
    --     self:Hide()
    -- end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.GuildBath then
        --军团答题
        if msg.cmd == Cmds.GetGuildAnswerInfo.index then
            self:RefreshPanel()
        elseif msg.cmd == Cmds.GuildAnswer.index then 
            self:RefreshPanel()
        --掷筛子
        elseif msg.cmd == Cmds.Dice.index then
            if HotSpringAnswerData.content.selfDiceScore then
                local score = HotSpringAnswerData.content.selfDiceScore
                Tips(string.format("获得%s点数",score))
            end
        elseif msg.cmd == Cmds.GetDiceCharList.index then
            self:DiceRefreshData()
        elseif msg.cmd == Cmds.SyncDiceScore.index then
            self:DiceRefreshData()
        elseif msg.cmd == "clear" then
            self:Hide()
        end
    end
end

------------------------------投骰子----------------------------
--掷筛子数据刷新
function M:DiceRefreshData()
    self.curRightTab = HotSpringAnswerData.DiceRankReward()
    self.uiRightLoop.ItemsCount = #self.curRightTab
    --掷骰子信息
    self.dicingInfos = HotSpringAnswerData.SortPlayerDiceSocore()
    if self.dicingInfos == nil then
        return
    end
    --排行榜长度
    self.uiLeftLoop.ItemsCount = #self.dicingInfos
    --提示
    self.noTip:SetActive(self.uiLeftLoop.ItemsCount == 0)

    --自己掷骰子信息
    local selfDicingInfo = HotSpringAnswerData.GetSelfDiceScore() 
    local count = 0
    for k,v in pairs(selfDicingInfo) do
        count = count + 1
    end

    local playerInfo= dataMgr.PlayerData.GetRoleInfo()
    self.mypostText.text = dataMgr.GuildData.GetDutyNameByGuid(playerInfo.guid)
    if count > 0 then
        self.myRankText.text = selfDicingInfo.rank
        self.myScoreText.text = tostring(selfDicingInfo.score)   
    else 
        self.myRankText.text = "0"
        self.myScoreText.text = "0"
    end

    local status = self:DiceStatus()
    local canShow = status == 1 and not self.sendDiceTime and netMgr.mainClient:GetServerTime() >= self.totalEndTime
    self.goDice:SetActive(canShow)
end

function M:DiceStatus()
    if HotSpringAnswerData.AnswerRightCount() >= SettingTable["dice_need_right"] then
        local isDice = HotSpringAnswerData.IsDice()
        if not isDice then
            return 1
        else
            return 2
        end
    else
        return 3
    end 
end

function M:OnCreateItem(index, coms)
    --排名Text
    coms.textRank = self:FindText("RankText", coms.trans)

    coms.transItem = self:FindTransform("RewardIcon", coms.trans)
	coms.comsItem = {}
	coms.comsItem.transRoot = coms.transItem

    UguiLuaEvent.ButtonClick(coms.go, nil, function(go)
        self:OnClickItem(self.uiRightLoop:GetItemGlobalIndex(coms.go) + 1, coms)
    end)
end

function M:OnClickItem(index, coms)
    --掷筛子奖励
    local items = dataMgr.TopData.GetRankRewards("guilddice_rankreward", index)
    local itemconfig = ItemTable[items[1].itemid]
    dataMgr.ItemData.ShowItemDetail(nil, itemconfig, coms.transItem)
end

function M:UpdateTabItem(index, coms)
    coms.textRank.text = string.format("第 %s 名", index)

    local items = dataMgr.TopData.GetRankRewards("guilddice_rankreward", index)
    local itemconfig = ItemTable[items[1].itemid]
    UITools.SetCommonItem(coms.comsItem, nil, itemconfig, commonParamsTable)
    coms.comsItem.textNum.text  = items[1].num
end

function M:OnCreateRankItem(index, coms)
    local trans = coms.trans
    coms.rankText = self:FindText("Rank/Text", trans)  --排名
    coms.rankIcon = self:FindImage("Rank/Icon", trans)  --头像图片
    coms.nameText = self:FindText("NameText", trans) --角色名
    coms.postText = self:FindText("PostText", trans) --职位
    coms.scoreText =self:FindText("ScoreImg/ScoreText", trans) --积分
end

function M:OnUpdateRankItem(index, coms)
    local trans = coms.trans
    local dicingInfo = self.dicingInfos[index]
    --排名
    require("UI.Top.UITop").SetPerfectRank(index, coms.rankText, coms.rankIcon)
    --头像图片
    local pTableid, pTableData = unitMgr.UnpackUnitGuid(dicingInfo.guid)
    uiMgr.SetSpriteAsync(self:FindImage("HeadIcon/ImgIcon", trans), Const.atlasName.PhotoIcon, pTableData.headIcon)
    --角色名
    coms.nameText.text = dicingInfo.name
    --职位
    coms.postText.text = dataMgr.GuildData.GetDutyNameByGuid(dicingInfo.guid)
    --积分
    coms.scoreText.text = tostring(dicingInfo.score)
end

--点击掷骰子按钮
function M:OnClickDicing()
    local status = self:DiceStatus()
    if status == 1 then
        effectMgr:SpawnToUI("2d_dice_action", Vector3.zero, self.diceEffectTrans, 0)
        self.sendDiceTime = Time.realtimeSinceStartup + 1
        self:DiceRefreshData()
    elseif status == 2 then
        Tips("你已掷过骰子")
    elseif status == 3 then   
        UIMsgbox.ShowTip("温泉答题答对3题才能掷骰子", '提示')
    end
end

return M