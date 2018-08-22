--世界答题
local base = require "UI.UILuaBase"
local M = base:Extend()

local AnswerData = dataMgr.AnswerData

local showQuestionInfo

function M.Open()
    showQuestionInfo = true
    OpenUI("UISocial", {channel = Const.CHAT_CHANNEL_WORLD})
end

function M:Awake()
    base.Awake(self)
    self.panelTime = self:FindTransform("PanelTime")
    self.panelInfo = self:FindTransform("Info")
    self.imageAnswer = self:FindTransform("Info/ImageAnswer")
    self.textTime = self:FindText("PanelTime/TextTime")
    self.textQuestion = self:FindText("Info/TextQuestion")
    UguiLuaEvent.ButtonClick(self:FindGameObject("PanelTime/ButtonAnswer"), self, M.OnClickShowInfo)
    UguiLuaEvent.ButtonClick(self:FindGameObject("Info/ButtonClose"), self, M.OnClickClose)
    self.answerComs = {}
    for i=1, 4 do
        local _trans = self:FindTransform(string.format("Info/Grid/Item (%d)", i))
        self.answerComs[i] = {
            trans = _trans,
            textAnswer = self:FindText("TextDesc", _trans)
        }
    end
end

function M:Show()
    base.Show(self)  
    self:Refresh()
    self:ShowQuestionInfo(showQuestionInfo)
    showQuestionInfo = false    
end

function M:Hide()
    base.Hide(self)
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.WorldAnswer then
        self:Refresh()
    end
end

function M:Refresh()
    local answerinfo = AnswerData.GetWorldAnswerInfo()
    if answerinfo and answerinfo.timeout then
        local _time = answerinfo.timeout - netMgr.mainClient:GetServerTime()
        if _time > 0 then
            local tween = TweenText.Begin(self.textTime, _time, 0, _time, 0)
            tween.format = "世界答题正在进行...({0})"
            tween:SetOnFinished(function()
                self:Hide()
            end)
        else
            self:Hide()
        end
    else
        self:Hide()
    end
    UITools.SetActive(self.imageAnswer, AnswerData.GetWorldAnswerResult().is_answered)
end

function M:OnClickClose(go)
    self:ShowQuestionInfo(false)
end

function M:OnClickShowInfo(go)
    self:ShowQuestionInfo(true)
end

function M:ShowQuestionInfo(_show)
    UITools.SetActive(self.panelInfo, _show)
    if _show then
        local config, answer = AnswerData.GetWorldQuestion()
        if config then
            self.textQuestion.text = config.question
            local answerCount = #answer
            self.answerSequence = AnswerData.GetRandomSequence(answerCount)
            for i=1, answerCount do
                local coms = self.answerComs[i]
                UITools.SetActive(coms.trans, true)
                coms.textAnswer.text = answer[self.answerSequence[i]]
            end
            for i=#answer+1, 4 do
                UITools.SetActive(self.answerComs[i].trans, false)
            end  
        end
        UITools.SetActive(self.imageAnswer, AnswerData.GetWorldAnswerResult().is_answered)
    end
end

return M