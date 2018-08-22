--[[
	幸运进阶
]]

local PlayerData = require "Data.PlayerData"
local RewardData = require "Data.RewardData"
local BusinessData = require "Data.BusinessData"

local ItemTable = require "Excel.ItemTable"
local ActivityTable = require "Excel.ActivityTable"
local ExpendTable = require "Excel.ExpendTable"
local SignTable = require "Excel.SignTable"

local BusinessActivityTable = require "Excel.BusinessActivityTable"
local rewardExParams = {isnative = true, showQualityEffect = true}

local base = require "UI.UILuaBase"
local M = base:Extend()

function M:Awake()
	base.Awake(self)

	self.textTime = self:FindText("Offset/LeftTime/TxtLeft")

	--模型预览
	self.modelTb = {}
	self:InitModelInfo(self.modelTb, 1)
	self:InitModelInfo(self.modelTb, 2)

	UguiLuaEvent.ButtonClick(self:FindTransform("Offset/BtnGo").gameObject, self, M.OnClickGo)

	self.imageLogo = self:FindImage("Offset/BG/Image (4)")

	self.transList = {}
end

function M:InitModelInfo(tb, index)
	tb[index] = {}
	local child = tb[index]
	local root = string.format("Offset/ModelInfo%s/",index)
	local cameraPath = root.."CameraModel"
	local rawPath = root.."RawImage"
    child.rawImage = self:LoadRenderTexture(cameraPath, rawPath, "RenderTexture"..(index-1))
	child.modelParent = self:FindTransform(cameraPath.."/Model")
	child.modelParent2 = self:FindTransform(cameraPath.."/Model (1)")
	
end

function M:Show()
	base.Show(self)

	self.businessTab = BusinessActivityTable[self.data.id]
	if not self.businessTab then
		self:Hide()
		return
	end

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		print("-------------1")
		self:Hide()
		return
	end

	self:ResetData()
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Business then
		self:ResetData()
	end
end

--跳转
function M:OnClickGo()
	if self.curConfig and self.curConfig.goMenuID then
		local MenuEventManager = require "Manager.MenuEventManager"
		MenuEventManager.DoMenu(self.curConfig.goMenuID)
	end
end

function M:ResetData()
	if not self.data.id or not self.businessTab then
		return
	end

	local isOpen, index, openid = self.script:IsLuckyUpgradeOpen()
	if not isOpen then
		return
	end

	self.curConfig = self.businessTab.param2[index]
	UITools.SetImageIcon(self.imageLogo, Const.atlasName.Activity, self.curConfig.img, true)

	self.endTime = BusinessData.GetEndTime(openid)

	if openid == Const.BAGROUP_LOOPSCORE_HALO then
		self.transList[1] = UITools.LoadEffect(self.curConfig.stage1, self.modelTb[1].modelParent2)
		self.transList[2] = UITools.LoadEffect(self.curConfig.stage2, self.modelTb[2].modelParent2)
		
		UITools.SetActive(self.modelTb[1].modelParent2, true)
		UITools.SetActive(self.modelTb[2].modelParent2, true)
		UITools.SetActive(self.modelTb[1].modelParent, false)
		UITools.SetActive(self.modelTb[2].modelParent, false)
	else
		self.transList[3] = UITools.LoadModel(self.curConfig.stage1, "luckyupgrade1", self.modelTb[1].modelParent)
		self.transList[4] = UITools.LoadModel(self.curConfig.stage2, "luckyupgrade2", self.modelTb[2].modelParent)

		UITools.SetActive(self.modelTb[1].modelParent, true)
		UITools.SetActive(self.modelTb[2].modelParent, true)
		UITools.SetActive(self.modelTb[1].modelParent2, false)
		UITools.SetActive(self.modelTb[2].modelParent2, false)
	end

end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#00aa00>%s</color>", strTime)
	end
end

return M