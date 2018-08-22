local PlayerData = require "Data.PlayerData"
local ItemData = require "Data.ItemData"
local RechargeData = require "Data.RechargeData"

local ItemTable = require "Excel.ItemTable"
local ExpendTable = require "Excel.ExpendTable"

local base = require "UI.UILuaBase"
local M = base:Extend()

--[[奖励——一本万利]]

function M:Awake()
    --按钮。ButtonScale
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, false)
	UguiLuaEvent.ButtonClicksInChildren(self.gameObject, self, M.OnClick, true)
	
	--充值、已购买
	self.uiBtnRecharge = self:FindGameObject("Buttom/BtnRecharge")
	self.uiBtnAlreadyBuy = self:FindGameObject("Buttom/BtnAlreadyBuy")
	-- self.txtDesc = self:FindText("Buttom/TxtDesc")
	self.imgDesc = self:FindImage("Buttom/ImgDesc")

    --右边UILoop
	self.uiRewardLoop = self:FindGameObject("Scroll View/Viewport/Content"):GetComponent(typeof(UILoop))
	self:BindLoopEvent(self.uiRewardLoop, M.UpdateItem, nil, function(_self, index, go)
		UguiLuaEvent.ButtonClick(go, nil, function(_go)
        	self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(go) + 1, go, 1)                
        end)
		--领取
		UguiLuaEvent.ButtonClick(self:FindGameObject("BtnGet", go.transform), nil, function(_go)
			self:OnChoose(self.uiRewardLoop:GetItemGlobalIndex(go) + 1, go, 2)                
		end)
	end)

	--toggle
	self.toggles = {}
    for i=1,2 do
        local tog = self:FindToggle(string.format("Top/BtnProfit (%d)" , i))
		table.insert(self.toggles, tog)
        UguiLuaEvent.ToggleClick(tog.gameObject, self, function(_self, _go, _isOn)
        	if _isOn then
        		if i == 1 then
        			--奇货可居
        			self.getBackType = 1
        		elseif i == 2 then
        			--一本万利
        			self.getBackType = 2
        		end

				self:RefreshPanel()
        	end
        end)
    end
end

function M:Show()
	base.Show(self)

	self.toggles[1].isOn = true

	self:RefreshPanel()
end

function M:OnLocalMsg(cmd, msg)
	if cmd == LocalCmds.Recharge then
		self:RefreshPanel()
    end
end

local toggleNotifyPos = Vector3.New(60,25,0)

function M:RefreshPanel()
	local rechargeTab = RechargeData.GetProfitChargeTableByType(self.getBackType)
	local info = RechargeData.GetRechargeInfoById(rechargeTab.id)
	local profitChargeTab = RechargeData.GetProfitTableByType(self.getBackType)

	if info then
		--已购买
		self.uiBtnRecharge:SetActive(false)
		self.uiBtnAlreadyBuy:SetActive(true)
	else
		--未购买
		self.uiBtnRecharge:SetActive(true)
		self.uiBtnAlreadyBuy:SetActive(false)
	end

	--描述图片
	if rechargeTab.id == 201 then
		--奇货可居
		UITools.SetImageIcon(self.imgDesc, Const.atlasName.Background, "Flqhkj", true)
	elseif rechargeTab.id == 202 then
		--一本万利
		UITools.SetImageIcon(self.imgDesc, Const.atlasName.Background, "Flybwl", true)
	end
	-- self.txtDesc.text = rechargeTab.desc

	--刷新UILoop
	self.uiRewardLoop.ItemsCount = #profitChargeTab

	notifyMgr.AddNotify(self.toggles[1], notifyMgr.IsProfitQiHuoNotify(), toggleNotifyPos, notifyMgr.NotifyType.Common)
	notifyMgr.AddNotify(self.toggles[2], notifyMgr.IsProfitWanLiNotify(), toggleNotifyPos, notifyMgr.NotifyType.Common)
end

function M:OnClick(go)
	local btnName = go.name
	if btnName == "BtnRecharge" then
		--充值
		self:OnClickRecharge()
	end
end

function M:OnClickRecharge()
	local rechargeInfo = RechargeData.GetProfitChargeInfoByType(self.getBackType)
	if rechargeInfo then
		Tips("已经充值")
	else
		local rechargeTab = RechargeData.GetProfitChargeTableByType(self.getBackType)
		if rechargeTab then
			--充值
			require("SDK.PayOrderRequest").RequestOrder(rechargeTab.id)
		end
	end
end

--点击领取按钮
function M:OnChoose(index, go, tp)
	if tp == 1 then
		
	elseif tp == 2 then
		local profitChargeTab = RechargeData.GetProfitTableByType(self.getBackType)[index]
		if profitChargeTab ~= nil then
			--领取
			RechargeData.RequestGetRechargeReward(RechargeData.GetProfitChargeTableByType(self.getBackType).id, 
				index)
		end
	end
end

--签到奖励
function M:UpdateItem(index, go)
	local profitChargeTab = RechargeData.GetProfitTableByType(self.getBackType)[index]
	local trans = go.transform
	if profitChargeTab ~= nil then
		--组件
		local txtName = self:FindText("TxName", trans)--名称
		local uiBtnGet = self:FindGameObject("BtnGet", trans)--领取
		local uiBtnAlreadyGet = self:FindGameObject("BtnAlreadyGet", trans)--已领取
		local uiBtnDone = self:FindGameObject("BtnDone", trans)--已领取
		local txtBtnAlreadyGetName = self:FindText("BtnAlreadyGet/Text", trans)--已领取

		--名称
		txtName.text = string.format("第%d天", index)
		
		--奖励物品（元宝）
		local rewardData = ItemData.GetRewardSingle(profitChargeTab.rewardid)
		if rewardData ~= nil then
			local imgCostItem = self:FindImage("CostItem", trans)--元宝
			local txtNum = self:FindText("CostItem/TxtNum", trans)--个数
			UITools.SetCostMoneyInfo(txtNum, imgCostItem, rewardData.itemid, rewardData.num, "")
		end

		local rechargeInfo = RechargeData.GetProfitChargeInfoByType(self.getBackType)
		if rechargeInfo then
			--已购买
			local rechargeTab = RechargeData.GetProfitChargeTableByType(self.getBackType)
			if RechargeData.IsRechargeRewardGetted(rechargeTab.id, index) then
				--已领取
				uiBtnGet:SetActive(false)
				uiBtnAlreadyGet:SetActive(false)
				uiBtnDone:SetActive(true)
				
				-- txtBtnAlreadyGetName.text = "已领取"
			else
				--未领取
				local left = RechargeData.GetRechargeRewardLeftDay(rechargeTab.id)
				local day = rechargeTab.daynum - left + 1
				-- print(day, left)
				if day >= index then
					uiBtnGet:SetActive(true)
					uiBtnAlreadyGet:SetActive(false)
					uiBtnDone:SetActive(false)
				else
					--时间未到
					uiBtnGet:SetActive(false)
					uiBtnAlreadyGet:SetActive(true)
					uiBtnDone:SetActive(false)
					-- txtBtnAlreadyGetName.text = "未达成"
				end
			end
		else
			--未购买
			uiBtnGet:SetActive(false)
			uiBtnAlreadyGet:SetActive(true)
			uiBtnDone:SetActive(false)
			-- txtBtnAlreadyGetName.text = "领取"
		end
	end
end

return M