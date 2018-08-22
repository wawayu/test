local base = require "UI.UILuaBase"
local M = base:Extend()

local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {isnative = true, showQualityEffect = true, showtips = true}
local rotation90 = Vector3.New(0, 90, 0)
local animationDuration = 0.3

local endCallback= nil
local ConstLen = 10
local evCurAngle
local businesspb
local TT = dataMgr.BusinessData.CreateTable(ConstLen)

function M:Awake()
	base.Awake(self)

	self.buttonTabs = {}
	self.textTabs = {}
	self.transCardBg = self:FindTransform("Offset/Cards/CardDataImage")
	self.transCardFace = self:FindTransform("Offset/Cards/ButtonGroundCards")
	for i=1, 3 do
		self.textTabs[i] = self:FindText(string.format("NumImage (%d)/Text", i), self.transCardBg)
        self.buttonTabs[i] = self:FindButton(string.format("Button (%d)", i), self.transCardFace)
	end
	self.textTime = self:FindText("Offset/Top/LeftTime/TxtLeft")
	self.textContent = self:FindText("Offset/Top/Desc/TxtContent")
	self.textEnergy = self:FindText("Offset/Top/TextEnergy")
	self.textGold = self:FindText("Offset/Top/TextGold")
	self.textNum = self:FindText("Offset/Bottom/TextNum")

	self.transPointer = self:FindTransform("Offset/Table/Wheel/Pointer")
	self.transTriangle = self:FindTransform("Offset/Table/Wheel/Triangle")

	self.imageOK = self:FindImage("Offset/Bottom/ButtonOK")
	self.imageWheel = self:FindImage("Offset/Table/Wheel/ButtonWheel")
	self.btnTurn=self:FindImage("Offset/Bottom/ButtonTurn")
	
	UITools.AddBtnsListenrList(self:FindTransform("Offset"), self, M.OnClick, ButtonScale)

	TT.Init(self.transPointer, function()
		self:AnimationEnd()
    end)
	
	local fullangle = 360 / ConstLen			-- 每一个物品占的角度
	local halfangle = fullangle / 2		-- 半个角度
	TT.AddAngleEvent(halfangle, function(angle, index)
        self.transTriangle.localEulerAngles = Vector3.New(0, 0, index * fullangle)
    end)
end

function M:Show()
	base.Show(self)

	self.startTime = -1
	self.transTriangle.localEulerAngles = Vector3.New(0,0,0)
	TT.Reset()
	
	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end

	self.transTriangle.localEulerAngles = Vector3.zero
	self.transPointer.localEulerAngles = Vector3.zero

	-- 隐藏物体
	local remain, use = self.script:GetRemain()
	for i=1,3 do
		self.buttonTabs[i].gameObject:SetActive(use < i)
		self.buttonTabs[i].transform.localRotation = Quaternion.identity
	end

	self.total = 0
	self.codeList = {}
	for i=1,3 do 
		self.codeList[i] = tonumber(self.script:GetCardCode(i))
	end
	if #self.codeList == 3 then
		self.total = (self.codeList[1] * 10 + self.codeList[2]) * self.codeList[3]
	end
	
	self:ResetData()
end

function M:FlipCard(index)
	self.buttonTabs[index].gameObject:SetActive(true)
    TweenRotation.Begin(self.buttonTabs[index].gameObject, Vector3.zero, rotation90, animationDuration, 0)
end

function M:OnClick(go)
	local name = go.name

	if not self.info or not self.tab then
		return
	end

	if name == "ButtonWheel" then
		self:OnClickOK()
	elseif name == "ButtonTurn" then
		self:OnClickOK()
	elseif name == "ButtonOK" then
		if self.startTime and self.startTime > 0 then
			Tips("转盘运转中")
			return
		end
		if self.info.chargeCount > 0 then
			Tips("奖励已领取")
			return
		end
		if self.use ~= 3 then
			Tips("次数未满3次，不能领取")
			return
		end
		self.script:SendRotate()
	elseif name == "ButtonTips" then
		Hint({rectTransform = go.transform, content = self.tab.itemdesc, alignment = 0})
	end
end

function M:ResetData()
	self.info = self.script:Info()
	if not self.info then
		return
	end
	self.remain, self.use = self.script:GetRemain()
	self.textNum.text = self.remain

	-- 不隐藏
	for i=1,3 do 
		self.textTabs[i].text = self.codeList[i]
	end

	self.textGold.text = ""
	if self.use == 3 then
		self.textGold.text = string.format("可获得元宝:%s", self.total)
	end

	local energy = dataMgr.ActivityData.GetActiveValue()
	self.tab = BusinessActivityTable[self.data.id]
	local te = 0
	for i, v in ipairs(self.tab.rewardconfig.score) do
		if energy < v then
			te = v
			break
		end
	end
	if te > 0 then
		self.textEnergy.text = string.format("今日活力 : <color=#00aa00>%s</color>(达到<color=#00aa00>%s</color>可获得一次机会)", energy, te)
	else
		self.textEnergy.text = string.format("今日活力 : <color=#00aa00>%s</color>", energy)
	end
	
	self.textContent.text = self.tab.desc
	self.endTime = self.script:GetEndTime()

	UITools.SetImageGrey(self.imageOK, self.info.chargeCount > 0 or self.use < 3)
	UITools.SetImageGrey(self.imageWheel, self.remain == 0)
	self.btnTurn.gameObject:SetActive(self.remain > 0 and self.use < 3)
end

function M:OnClickOK()
	if self.startTime and self.startTime > 0 then
		Tips("转盘运转中")
		return
	end

	if self.remain <= 0 then
		Tips("次数不足")
		return
	end

	if self.info.chargeCount > 0 then
		Tips("奖励已领取")
		return
	end

	self.script:SendGetGold()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
        if msg.cmd == Cmds.GetBusinessActivityInfo.index then
			self:ResetData()
		elseif msg.cmd == Cmds.SyncBusinessInfo.index then
			self:ResetData()
		elseif msg.cmd == Cmds.GetBusinessReward.index then
			if not self.info or not self.tab then
				return
			end
            if msg.pb and #msg.pb.list > 0 then
				businesspb = msg.pb.list[1]
				local code = tonumber(self.script:GetCardCode(businesspb.intparam))
				local index = 0
				for i,v in ipairs(self.tab.param2.order) do
					if v == code then
						index = i
						break
					end
				end
				if index > 0 then
					self:StartRotate(index)
				end
			end
		end
    end
end

local preUpdateTime = -999
function M:Update()
    base.Update(self)

    TT.UpdateTable()

    if Time.time - preUpdateTime < 0.3 then
		return
	end
	preUpdateTime = Time.time

    if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#2cffee>%s</color>", strTime)
	end
end

function M:StartRotate(index)
	self.targetIndex = index
	self.startTime = Time.time
	TT.Start(Time.time, index)
end

function M:End()
	if endCallback then
		local _endCallback = endCallback
		endCallback = nil
		_endCallback()
    end
    
    if businesspb then
		self:FlipCard(businesspb.intparam)
        self:ResetData()
    end
    businesspb = nil
end

function M:AnimationEnd()
	self.startTime = -1
	local fullangle = 360/ConstLen
	self.transTriangle.localEulerAngles = Vector3.New(0, 0, 360-(self.targetIndex-1) * fullangle)
	self:End()
	self:ResetData()
end

function M:Hide()
	self:End()

	base.Hide(self)
end

return M