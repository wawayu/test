local base = require "UI.UILuaBase"
local M = base:Extend()

local AnswerData = dataMgr.AnswerData

local AnswerTable = excelLoader.AnswerTable
local ItemTable = excelLoader.ItemTable

local answer_reward = excelLoader.SettingTable.answer_reward

M.AnswerState = {
    Prepare=1,
    Begin=2,
    Continue=3
}
---答题间隔
local NEXT_DELTA = 1
local openTime = 0

local AnswerChar = {'A', 'B', 'C', 'D'}

M.fixedInfoData = {
	isShow = true,
	showPos = Vector2.zero,
	ItemID = {Const.ITEM_ID_VCOIN, Const.ITEM_ID_SILVER, Const.ITEM_ID_COPPER}
}
--M.needPlayShowSE = true

local randomTalk = {"答题开始啦~\n你要加油哦~","认真答题,不要瞎点(╯▔皿▔)╯","好好学习,天天答题","哈哈哈哈哈哈哈,不会了吧"}

function M.Open()
    if not AnswerData.IsAnswerFinished(true) then
        uiMgr.ShowAsync("UIAnswer")
    end
end

function M.GetShowState()
    if not AnswerData.IsPlayerBeginTimeInActivity() then
        return M.AnswerState.Prepare
    -- elseif t  > 0 then
    --     return M.AnswerState.Continue
    end
    return M.AnswerState.Begin
end

function M:Awake()
	base.Awake(self)
	self.offset = self:FindTransform("Offset")

    self.panels = {
        [M.AnswerState.Prepare] = self:FindTransform("Offset/Right/PanelPrepare"),
        [M.AnswerState.Begin] = self:FindTransform("Offset/Right/PanelBegin"),
        [M.AnswerState.Continue] = self:FindTransform("Offset/Right/PanelContinue"),
    }
    self.textTime = self:FindText("Offset/Right/PanelBegin/TextTime")
	self.textAt = self:FindText("Offset/Right/PanelBegin/TextAt")
	self.textQuestion = self:FindText("Offset/Right/PanelBegin/TextQuestion")
    self.textRightNum = self:FindText("Offset/Left/TextRightNum")
    self.textTalk = self:FindText("Offset/Left/HeadInfo/Talk/TextTalk")

	self.rewardItemTrans = {
        self:FindTransform("Offset/Left/Item (1)"),
        self:FindTransform("Offset/Left/Item (2)"),
    } 
    self.answerItems = {}    
    for i = 1, 4 do
        local tmpTrans = self:FindTransform(string.format("Offset/Right/PanelBegin/Grid/Item (%s)", i))
        self.answerItems[i] = {
            trans = tmpTrans,
            label = self:FindText("TextDesc", tmpTrans),
            imageRight = self:FindImage("ImageRight", tmpTrans),
            imageWrong = self:FindImage("ImageWrong", tmpTrans),
            imageSelect = self:FindImage("ImageSelect", tmpTrans),
            btn = tmpTrans.gameObject:GetComponent(typeof(Button))
        }
        local index = i
        UguiLuaEvent.ButtonClick(tmpTrans.gameObject, nil, function(go)
            self:OnClickChoose(index)
        end)
    end
	
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/ButtonClose"), self, M.OnClickClose)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/Right/PanelPrepare/ButtonStart"), self, M.OnClickStart)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/Right/PanelContinue/ButtonStart"), self, M.OnClickContinue)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Offset/Left/HeadInfo/Image"), self, M.OnClickTalk)

end

function M:Show()
    base.Show(self)
    self.textTalk.text = randomTalk[1]
    openTime = Time.realtimeSinceStartup
    local answerInfo = dataMgr.AnswerData.GetAnswerInfo(true)
    self.currentQuestionIndex = answerInfo.answer + 1    
    self:Refresh()
    self:TweenOpen(self.offset.gameObject)
end

function M:OnLocalMsg(cmd, msg)
	if cmd == LocalCmds.Answer then
        local serverCmd = msg.id
        if serverCmd == Cmds.GetAnswerInfo.index then
            self:ShowQuestion(AnswerData.GetAnswerInfo().answer+1)
        elseif serverCmd == Cmds.StartAnswer.index then
            self:ShowQuestion(AnswerData.GetAnswerInfo().answer+1)   
        elseif serverCmd == Cmds.Answer.index then
            self:OnFinish()
        end
        self:Refresh()
	end
end

function M:Update()
    if self.showNext and ( (Time.realtimeSinceStartup - self.lastChooseTime) > NEXT_DELTA) then
        self.showNext = false
        self:ShowQuestion(self.currentQuestionIndex+1)
    end
    if AnswerData.GetBeginTime() > 0 then
        self.textTime.text = Utility.FormatTimeHourMinSec(netMgr.mainClient:GetServerTime() - AnswerData.GetBeginTime())
    end
    if Time.realtimeSinceStartup - openTime > 1 then
        self:OnTimeOut()
    end
end

function M:Refresh()
    self:ShowPanel(self:GetShowState())
    self:ShowReward()    
    self.textAt.text = string.format("第%d/%d题", AnswerData.GetFinishedCount())
    self.textRightNum.text = string.format("准确度<color=#18A338>%d/%d</color>", AnswerData.GetRightCount())
end

function M:ShowPanel(state)
    self.currentState = state
    for k, panel in pairs(self.panels) do
        panel.gameObject:SetActive(state == k)
    end
end

function M:ShowReward()
    local index = 1
    local rightCount = AnswerData.GetRightCount()
    for k , v in Utility.TableIterator(answer_reward) do
        local reward = dataMgr.ItemData.GetRewardSingle(v.rewardid)    
        local trans = self.rewardItemTrans[index]
        UITools.SetItemInfo(trans, reward, false, false)
        self:FindGameObject("ImageGet", trans):SetActive(rightCount >= k)
        self:FindText("TextNeedNum", trans).text = string.format("答对<color=#18A338>%s</color>题", k)
        UguiLuaEvent.ButtonClick(trans.gameObject, nil, function(go)
            dataMgr.ItemData.ShowItemDetail(nil, ItemTable[reward.itemid], go.transform)
        end)
        index = index + 1
    end
end

function M:ShowQuestion(questionindex, chooseindex)
    if questionindex > AnswerData.GetQuestionMaxCount() then
        ---答题结束
        return 
    end
    self.currentQuestionIndex = questionindex    
    local questionid = AnswerData.GetQuestionID(questionindex)
    local config = AnswerTable[questionid] or error("[AnswerTable] can not found "..tostring(questionid))
    local showRightAnswer = (chooseindex ~= nil)  
    self.textQuestion.text = config.question
    local answerCount = #config.answer
    if not chooseindex or (not self.answerSequence) then
        self.answerSequence = AnswerData.GetRandomSequence(answerCount)
    end
    
    for i=1, answerCount do
        local answerIndex = self.answerSequence[i]
        local tmpComp = self.answerItems[i]
        tmpComp.trans.gameObject:SetActive(true)
        tmpComp.label.text = string.format("%s.%s", AnswerChar[i], config.answer[answerIndex])
        if showRightAnswer then
            if (i == chooseindex) or (answerIndex == config.rightAnswers) then
                ---只显示选中答案和正确答案的状态
                local ischooseRight = (answerIndex == config.rightAnswers)              
                tmpComp.imageRight.gameObject:SetActive(ischooseRight)
                tmpComp.imageWrong.gameObject:SetActive(not ischooseRight)
            else
                tmpComp.imageRight.gameObject:SetActive(false)
                tmpComp.imageWrong.gameObject:SetActive(false)
            end
            tmpComp.imageSelect.gameObject:SetActive(i==chooseindex)
            tmpComp.btn.enabled = false
        else
            tmpComp.imageRight.gameObject:SetActive(false)
            tmpComp.imageWrong.gameObject:SetActive(false)
            tmpComp.imageSelect.gameObject:SetActive(false)
            tmpComp.btn.enabled = true
        end
    end
    for i=answerCount+1, #self.answerItems do
        self.answerItems[i].trans.gameObject:SetActive(false)
    end
end

---选择答案
function M:OnClickChoose(chooseindex)
    if dataMgr.PlayerData.NeedBagSize(2, true) then
        self:ShowQuestion(self.currentQuestionIndex, chooseindex)
        if not self.showNext then
            self.lastChooseTime = Time.realtimeSinceStartup
            self.showNext = true
        end    
        local questionid = AnswerData.GetQuestionID(self.currentQuestionIndex)
        local answerid = self.answerSequence[chooseindex]
        AnswerData.RequestAnswerQuestion(questionid, answerid)
    end
end

---关闭
function M:OnClickClose(go)
    if self.currentState == M.AnswerState.Begin then
        UIMsgbox.ShowChoose("你要退出答题吗?暂停答题后计时不暂停", function(ok, param)
            if ok == true then
                self:Hide()
            end
        end, nil, '提示')
    else
        self:Hide()
    end
end

---请求开始答题
function M:OnClickStart(go)
    AnswerData.RequestStartAnswer() 
end

---请求继续答题
function M:OnClickContinue(go)
    self:ShowPanel(M.AnswerState.Begin)
    self:ShowQuestion(AnswerData.GetAnswerInfo().answer+1) 
end

function M:OnClickTalk(go)
    local index = math.random(1, #randomTalk)
    self.textTalk.text = randomTalk[index]
end

function M:OnFinish()
    if AnswerData.IsAnswerFinished(true) then
        self:Hide()
    end
end

--答题活动结束
function M:OnTimeOut()
    if AnswerData.IsAnswerTimeOut(true) then
        self:Hide()
    end
end

return M