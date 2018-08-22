--[[
	常规运营活动--限时抢购
]]
local BusinessData = require "Data.BusinessData"
local PlayerData = require "Data.PlayerData"
local ShopData = require "Data.ShopData"
local ItemTable = require "Excel.ItemTable"
local ShopTable = require "Excel.ShopTable"
local ShopItemTable = require "Excel.ShopItemTable"
local BusinessActivityTable = require "Excel.BusinessActivityTable"

local base = require "UI.UILuaBase"
local M = base:Extend()
local commonParamsTable = {showtips = true, isnative = true, showQualityEffect = true}
local preUpdateTime = -1

function M:Awake()
	base.Awake(self)
    self.uiLoop = self:FindLoop("Offset/Scroll View/Viewport/Content")
	self:BindLoopEventEx(self.uiLoop, M.OnCreateItem, M.UpdateItem)

	self.textTime = self:FindText("Offset/Top/TextTime")
end

function M:Show()
	base.Show(self)

	self.script = BusinessData.GetScript(self.data.id)
	if not self.script then
		self:Hide()
		return
	end
	
	self:ResetData()
end

function M:ResetData()
	local bid = self.data and self.data.id
	if not bid then
		Debugger.LogWarning("uibadiscountbuy error no bid")
		return
	end

	self.busTab = BusinessActivityTable[bid]

	local shopid = self.busTab.param1.dayshopid
	if shopid == nil then
		Debugger.LogWarning("uibadiscountbuy error no shopid")
		return
	end

	-- 和开服活动限时抢购不同，没有人民币物品，所以不需要伪造
	self.itemList = ShopData.GetShopItems(shopid)
	self.uiLoop.ItemsCount = #self.itemList

	self.endTime = self.script:GetEndTime()
	if self.endTime <= 0 then
		Tips("活动结束")
		self:Hide()
	end
end

function M:GetLoopItem(idx)
    return self.itemList[idx]
end

function M:OnCreateItem(index, coms)
	coms.transFlag = self:FindTransform("Flag", coms.trans)
	coms.textFlag = self:FindText("Flag/Text", coms.trans)
	coms.transOriPrice = self:FindTransform("OriPrice", coms.trans)
	coms.transOK = self:FindTransform("ButtonOK", coms.trans)
	coms.textCost = self:FindText("ButtonOK/TextPrice", coms.trans)
	coms.textCost2 = self:FindText("ButtonOK/TextPrice2", coms.trans)
	coms.imageCost = self:FindImage("ButtonOK/TextPrice/ImageIcon", coms.trans)
	coms.goImageDone = self:FindGameObject("ImageDone", coms.trans)
	coms.transBG = self:FindTransform("Bg", coms.trans)

	coms.textOri = self:FindText("TextPrice", coms.transOriPrice)
	coms.imageOri = self:FindImage("ImageIcon", coms.transOriPrice)
	coms.textNum = self:FindText("TextNum", coms.trans)

	coms.transItemData = self:FindTransform("ItemData", coms.trans)
	coms.imgIconItemData = self:FindImage("ImgIcon", coms.transItemData)
	coms.transEffectDot = self:FindTransform("EffectDot", coms.transItemData)
	coms.textNameItemData = self:FindText("TextName", coms.transItemData)
	
	coms.transRewardItem = self:FindTransform("RewardList/Viewport/Grid/Item", coms.trans)--奖励
	coms.rewardContainer = {}

	UguiLuaEvent.ButtonClick(coms.transOK.gameObject, nil, function()
        self:OnChooseItem(self.uiLoop:GetItemGlobalIndex(coms.go) + 1, coms)
    end)

	effectMgr:SpawnToMaskUI("2d_jchd_xscg", Vector3.zero, coms.transEffectDot, 0)
end

function M:OnChooseItem(index, coms)
	local shopItemData = self:GetLoopItem(index)
	local itemData = shopItemData.shopiteminfo
	local itemConfig = shopItemData[1]
	--ShopData.RequestBuy(itemConfig.id, 1)
	local itemid, price = self:GetItemPrice(index)

	local ret, notEnoughs = dataMgr.PlayerData.CheckItemsNum({{itemid = itemid, num = price}}, true, true)
	if ret then
		self.script:SendBuyItem(index, itemConfig.id)
	end
end

function M:UpdateItem(index, coms)
	local shopItemData = self:GetLoopItem(index)

	-- shopitemtable
	local itemConfig = shopItemData[1]
	local itemid = itemConfig.item.itemid
	local itemTableConfig = ItemTable[itemid]

	coms.go:SetActive(itemConfig.count > 0)
	if itemConfig.count == 0 then
		return
	end

	coms.textCost.text = ""
	coms.textCost2.text = ""
	local isSellDone
	coms.imageCost.gameObject:SetActive(true)

	UITools.SetImageIcon(coms.imgIconItemData, Const.atlasName.ItemIcon, itemTableConfig.icon, true)
	coms.textNameItemData.text = UITools.FormatItemColorName(itemid)

	local info = self.script:Info()
	local curNum = self.script:GetBuyedNum(index)
	local limitbuynum = self.script:GetMaxNum(itemConfig.id)

	isSellDone = curNum >= limitbuynum
	coms.transOK.gameObject:SetActive(not isSellDone)
	coms.goImageDone:SetActive(isSellDone)

	if isSellDone then
		coms.textNum.text = ""
	else
		coms.textNum.text = string.format("剩余次数:%s/%s", limitbuynum - curNum, limitbuynum)
	end

	local rewardid = dataMgr.ItemData.GetItemToReward(itemid)
	local rewards = dataMgr.ItemData.GetRewardList({rewardid})
    UITools.CopyRewardListWithItemsEx(rewards, coms.rewardContainer, coms.transRewardItem, commonParamsTable)

	local price = itemConfig.price[1]
	local itemCurCost = ItemTable[price.itemid]
	local showprice = itemConfig.showprice 				-- {itemid,num,discount =7}
	local discount = ShopData.GetItemDiscount(itemConfig.id)
	
	if discount > 0 and discount < 1 then
		local itemOriCost = ItemTable[showprice.itemid]
		coms.transOriPrice.gameObject:SetActive(true)
		coms.textOri.text = showprice.num
		UITools.SetImageIcon(coms.imageOri, Const.atlasName.ItemIcon, itemOriCost.icon, false)

		coms.textCost.text = ShopData.FormatPrice(price.itemid, price.num)
		UITools.SetImageIcon(coms.imageCost, Const.atlasName.ItemIcon, itemCurCost.icon, false)

		coms.transFlag.gameObject:SetActive(true)
		coms.textFlag.text = ShopData.FormatDiscount(itemConfig.id)
	else
		coms.transFlag.gameObject:SetActive(false)
		coms.transOriPrice.gameObject:SetActive(false)

		coms.textCost.text = ShopData.FormatPrice(price.itemid, price.num)
		UITools.SetImageIcon(coms.imageCost, Const.atlasName.ItemIcon, itemCurCost.icon, false)
	end

	coms.transOriPrice.gameObject:SetActive(not isSellDone)
end

function M:GetItemPrice(index)
	local shopItemData = self:GetLoopItem(index)
	local itemConfig = shopItemData[1]
	local discount = ShopData.GetItemDiscount(itemConfig.id)
	local price = itemConfig.price[1]
	return price.itemid, price.num * discount
end

function M:UpdateChild()
	if self.endTime then
		local strTime = Utility.GetVaryTimeFormat(self.endTime - netMgr.mainClient:GetServerTime())
		self.textTime.text = string.format("<color=#00aa00>%s</color>", strTime)
	end
end

function M:OnLocalMsg(cmd, msg)
    if cmd == LocalCmds.Shop then
		self:ResetData()
	elseif cmd == LocalCmds.Recharge then
		self:ResetData()
	elseif cmd == LocalCmds.Business then
		self:ResetData()
    end
end

return M