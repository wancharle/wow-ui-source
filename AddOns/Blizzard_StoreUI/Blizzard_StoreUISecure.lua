---------------
--NOTE - Please do not change this section without talking to Jacob
--We usually don't want to call out of this environment from this file. Calls should usually go through Outbound
local _, tbl = ...;

tbl.SecureCapsuleGet = SecureCapsuleGet;
--Debug
tbl.CreateForbiddenFrame = CreateFrame;
--End debug
setfenv(1, tbl);
----------------

--Local references to frames
local StoreFrame;
local StoreConfirmationFrame

--Local variables (here instead of as members on frames for now)
local CurrentGroupID = nil;
local CurrentProductID = nil;
local JustOrderedProduct = false;
local WaitingOnConfirmation = false;

local function Import(name)
	tbl[name] = SecureCapsuleGet(name);
end

--Imports
Import("C_PurchaseAPI");
Import("math");
Import("pairs");
Import("tostring");
Import("LoadURLIndex");
Import("GetContainerNumFreeSlots");
Import("BACKPACK_CONTAINER");
Import("NUM_BAG_SLOTS");

--GlobalStrings
Import("BLIZZARD_STORE");
Import("BLIZZARD_STORE_ON_SALE");
Import("BLIZZARD_STORE_BUY");
Import("BLIZZARD_STORE_PLUS_TAX");
Import("BLIZZARD_STORE_PRODUCT_INDEX");
Import("BLIZZARD_STORE_CANCEL_PURCHASE");
Import("BLIZZARD_STORE_FINAL_BUY");
Import("BLIZZARD_STORE_CONFIRMATION_TITLE");
Import("BLIZZARD_STORE_CONFIRMATION_INSTRUCTION");
Import("BLIZZARD_STORE_FINAL_PRICE_LABEL");
Import("BLIZZARD_STORE_PAYMENT_METHOD");
Import("BLIZZARD_STORE_PAYMENT_METHOD_EXTRA");
Import("BLIZZARD_STORE_LOADING");
Import("BLIZZARD_STORE_PLEASE_WAIT");
Import("BLIZZARD_STORE_NO_ITEMS");
Import("BLIZZARD_STORE_CHECK_BACK_LATER");
Import("BLIZZARD_STORE_TRANSACTION_IN_PROGRESS");
Import("BLIZZARD_STORE_CONNECTING");
Import("BLIZZARD_STORE_VISIT_WEBSITE");
Import("BLIZZARD_STORE_VISIT_WEBSITE_WARNING");
Import("BLIZZARD_STORE_BAG_FULL");
Import("BLIZZARD_STORE_BAG_FULL_DESC");
Import("BLIZZARD_STORE_CONFIRMATION_GENERIC");
Import("BLIZZARD_STORE_CONFIRMATION_TEST");
Import("BLIZZARD_STORE_BROWSE_TEST_CURRENCY");
Import("BLIZZARD_STORE_CURRENCY_FORMAT_USD");
Import("BLIZZARD_STORE_CURRENCY_FORMAT_KRW_LONG");
Import("BLIZZARD_STORE_CURRENCY_FORMAT_CPT_LONG");
Import("BLIZZARD_STORE_CURRENCY_FORMAT_TPT");
Import("BLIZZARD_STORE_CURRENCY_RAW_ASTERISK");
Import("BLIZZARD_STORE_CURRENCY_BETA");
Import("BLIZZARD_STORE_BROWSE_BATTLE_COINS_KR");
Import("BLIZZARD_STORE_BROWSE_BATTLE_COINS_CN");
Import("BLIZZARD_STORE_ASTERISK");
Import("BLIZZARD_STORE_INTERNAL_ERROR");
Import("BLIZZARD_STORE_INTERNAL_ERROR_SUBTEXT");

Import("OKAY");
Import("LARGE_NUMBER_SEPERATOR");
Import("DECIMAL_SEPERATOR");

--Data
CURRENCY_UNKNOWN = 0;
CURRENCY_USD = 1;
CURRENCY_KRW = 3;
CURRENCY_CPT = 14;
CURRENCY_TPT = 15;
CURRENCY_BETA = 16;

local currencyMult = 1; --10000;

local function formatLargeNumber(amount)
	amount = tostring(amount);
	local newDisplay = "";
	local strlen = amount:len();
	--Add each thing behind a comma
	for i=4, strlen, 3 do
		newDisplay = LARGE_NUMBER_SEPERATOR..amount:sub(-(i - 1), -(i - 3))..newDisplay;
	end
	--Add everything before the first comma
	newDisplay = amount:sub(1, (strlen % 3 == 0) and 3 or (strlen % 3))..newDisplay;
	return newDisplay;
end

local function largeAmount(num)
	return formatLargeNumber(math.floor(num / currencyMult));
end

--Currency functions
--[[ For testing
BLIZZARD_STORE_CURRENCY_FORMAT_USD = "$%s%s%02d";
local function currencyFormatUSD(amount)
	return BLIZZARD_STORE_CURRENCY_FORMAT_USD:format(largeAmount(amount / 100), DECIMAL_SEPERATOR, (amount / currencyMult) % 100);
end
--]]

local function currencyFormatKRWLong(amount)
	return BLIZZARD_STORE_CURRENCY_FORMAT_KRW_LONG:format(largeAmount(amount));
end

local function currencyFormatCPTLong(amount)
	return BLIZZARD_STORE_CURRENCY_FORMAT_CPT_LONG:format(largeAmount(amount));
end

local function currencyFormatTPT(amount)
	return BLIZZARD_STORE_CURRENCY_FORMAT_TPT:format(largeAmount(amount));
end

local function currencyFormatRawStar(amount)
	return BLIZZARD_STORE_CURRENCY_RAW_ASTERISK:format(largeAmount(amount));
end

local function currencyFormatBeta(amount)
	return BLIZZARD_STORE_CURRENCY_BETA:format(largeAmount(amount));
end

local currencySpecific = {
	--[[
	[CURRENCY_USD] = {
		formatShort = currencyFormatUSD,
		formatLong = currencyFormatUSD,
		browseNotice = BLIZZARD_STORE_PLUS_TAX,
		confirmationNotice = BLIZZARD_STORE_CONFIRMATION_GENERIC,
		paymentMethodText = BLIZZARD_STORE_PAYMENT_METHOD,
		paymentMethodSubtext = BLIZZARD_STORE_PAYMENT_METHOD_EXTRA,
		browseHasStar = true,
	},]]
	[CURRENCY_KRW] = {
		formatShort = currencyFormatRawStar,
		formatLong = currencyFormatKRWLong,
		browseNotice = BLIZZARD_STORE_BROWSE_BATTLE_COINS_KR,
		confirmationNotice = BLIZZARD_STORE_CONFIRMATION_GENERIC,
		paymentMethodText = "",
		paymentMethodSubtext = "",
		browseHasStar = false,
	},
	[CURRENCY_CPT] = {
		formatShort = currencyFormatRawStar,
		formatLong = currencyFormatCPTLong,
		browseNotice = BLIZZARD_STORE_BROWSE_BATTLE_COINS_CN,
		confirmationNotice = BLIZZARD_STORE_CONFIRMATION_GENERIC,
		paymentMethodText = "",
		paymentMethodSubtext = "",
		browseHasStar = false,
	},
	[CURRENCY_TPT] = {
		formatShort = currencyFormatTPT,
		formatLong = currencyFormatTPT,
		browseNotice = "",
		confirmationNotice = BLIZZARD_STORE_CONFIRMATION_GENERIC,
		paymentMethodText = "",
		paymentMethodSubtext = "",
		browseHasStar = false,
	},
	[CURRENCY_BETA] = {
		formatShort = currencyFormatBeta,
		formatLong = currencyFormatBeta,
		browseNotice = BLIZZARD_STORE_BROWSE_TEST_CURRENCY,
		confirmationNotice = BLIZZARD_STORE_CONFIRMATION_TEST,
		paymentMethodText = BLIZZARD_STORE_PAYMENT_METHOD,
		paymentMethodSubtext = BLIZZARD_STORE_PAYMENT_METHOD_EXTRA,
		browseHasStar = true,
	},
};

local function currencyInfo()
	local currency = C_PurchaseAPI.GetCurrencyID();
	local info = currencySpecific[currency];
	return info;
end

--Code
local function getIndex(tbl, value)
	for k, v in pairs(tbl) do
		if ( v == value ) then
			return k;
		end
	end
end

function StoreFrame_OnLoad(self)
	StoreFrame = self;	--Save off a reference for us
	self:RegisterEvent("STORE_PRODUCTS_UPDATED");
	self:RegisterEvent("STORE_PURCHASE_LIST_UPDATED");
	self:RegisterEvent("BAG_UPDATE_DELAYED"); --Used for showing the panel when all bags are full
	C_PurchaseAPI.GetProductList();
	C_PurchaseAPI.GetPurchaseList();
	C_PurchaseAPI.GetDistributionList();

	self.Title:SetText(BLIZZARD_STORE);
	self.Browse.ProductDescription:SetPoint("BOTTOM", self.Browse.QuantitySelection, "TOP", 0, 5);
	self.Browse.BuyButton:SetText(BLIZZARD_STORE_BUY);
	self.Notice.NopButton:SetText(BLIZZARD_STORE_BUY);
	self.Notice.NopButton:Disable();

	self:SetPoint("CENTER", nil, "CENTER", 0, 77); --Intentionally not anchored to UIParent.

	StoreFrame_UpdateActivePanel(self);
end

function StoreFrame_OnEvent(self, event, ...)
	if ( event == "STORE_PRODUCTS_UPDATED" ) then
		StoreFrame_UpdateActivePanel(self);
	elseif ( event == "STORE_PURCHASE_LIST_UPDATED" ) then
		JustOrderedProduct = false;
		StoreFrame_UpdateActivePanel(self);
	elseif ( self:IsShown() and event == "BAG_UPDATE_DELAYED" ) then
		StoreFrame_UpdateActivePanel(self);
	end
end

function StoreFrame_OnShow(self)
	self:SetAttribute("IsShown", true);
	WaitingOnConfirmation = false;
	StoreFrame_UpdateActivePanel(self);
	Outbound.UpdateMicroButtons();
end

function StoreFrame_OnAttributeChanged(self, name, value)
	--Note - Setting attributes is how the external UI should communicate with this frame. That way, their taint won't be spread to this code.
	if ( name == "action" ) then
		if ( value == "Show" ) then
			self:Show();
		elseif ( value == "Hide" ) then
			self:Hide();
		elseif ( value == "EscapePressed" ) then
			local handled = false;
			if ( self:IsShown() ) then
				if ( StoreConfirmationFrame:IsShown() ) then
					--We eat the click, but don't close anything. Make them explicitly press "Cancel".
					handled = true;
				else
					self:Hide();
					handled = true;
				end
			end
			self:SetAttribute("EscapeResult", handled);
		end
	end
end

function StoreFrame_UpdateActivePanel(self)
	if ( WaitingOnConfirmation ) then
		StoreFrame_SetAlert(self, BLIZZARD_STORE_CONNECTING, BLIZZARD_STORE_PLEASE_WAIT);
	elseif ( JustOrderedProduct ) then
		StoreFrame_SetAlert(self, BLIZZARD_STORE_TRANSACTION_IN_PROGRESS, BLIZZARD_STORE_CHECK_BACK_LATER);
	elseif ( C_PurchaseAPI.HasPurchaseInProgress() ) then --Even if we don't have every list, if we know we have something in progress, we can display that.
		StoreFrame_SetAlert(self, BLIZZARD_STORE_TRANSACTION_IN_PROGRESS, BLIZZARD_STORE_CHECK_BACK_LATER);
	elseif ( not C_PurchaseAPI.HasPurchaseList() or not C_PurchaseAPI.HasProductList() or not C_PurchaseAPI.HasDistributionList() ) then
		StoreFrame_SetAlert(self, BLIZZARD_STORE_LOADING, BLIZZARD_STORE_PLEASE_WAIT);
	elseif ( #C_PurchaseAPI.GetProductGroups() == 0 ) then
		StoreFrame_SetAlert(self, BLIZZARD_STORE_NO_ITEMS, BLIZZARD_STORE_CHECK_BACK_LATER);
	elseif ( not StoreFrame_HasFreeBagSlots() ) then
		StoreFrame_SetAlert(self, BLIZZARD_STORE_BAG_FULL, BLIZZARD_STORE_BAG_FULL_DESC);
	elseif ( not currencyInfo() ) then
		StoreFrame_SetAlert(self, BLIZZARD_STORE_INTERNAL_ERROR, BLIZZARD_STORE_INTERNAL_ERROR_SUBTEXT);
	else
		StoreFrame_SetBrowse(self);
	end
end

function StoreFrame_SetBrowse(self)
	self.Notice:Hide();
	StoreFrameBrowse_Advance(self.Browse, 0); --Advancing by 0 will just make sure that we have a valid group selected.
	StoreFrameBrowse_Update(self.Browse);
	self.Browse:Show();
end

function StoreFrame_SetAlert(self, title, desc)
	self.Browse:Hide();
	self.Notice.Title:SetText(title);
	self.Notice.Description:SetText(desc);
	self.Notice:Show();
end

local ActiveURLIndex = nil;
function StoreFrame_ShowError(self, title, desc, urlIndex)
	local height = 110;
	self.ErrorFrame.Error.Title:SetText(title);
	self.ErrorFrame.Error.Description:SetText(desc);
	self.ErrorFrame.Error.AcceptButton:SetText(OKAY);
	height = height + self.ErrorFrame.Error.Description:GetHeight() + self.ErrorFrame.Error.Title:GetHeight();

	if ( urlIndex ) then
		self.ErrorFrame.Error.AcceptButton:ClearAllPoints();
		self.ErrorFrame.Error.AcceptButton:SetPoint("BOTTOMRIGHT", self.ErrorFrame.Error, "BOTTOM", -10, 20);
		self.ErrorFrame.Error.WebsiteButton:ClearAllPoints();
		self.ErrorFrame.Error.WebsiteButton:SetPoint("BOTTOMLEFT", self.ErrorFrame.Error, "BOTTOM", 10, 20);
		self.ErrorFrame.Error.WebsiteButton:Show();
		self.ErrorFrame.Error.WebsiteButton:SetText(BLIZZARD_STORE_VISIT_WEBSITE);
		self.ErrorFrame.Error.WebsiteWarning:Show();
		self.ErrorFrame.Error.WebsiteWarning:SetText(BLIZZARD_STORE_VISIT_WEBSITE_WARNING);
		height = height + self.ErrorFrame.Error.WebsiteWarning:GetHeight() + 5;
		ActiveURLIndex = urlIndex;
	else
		self.ErrorFrame.Error.AcceptButton:ClearAllPoints();
		self.ErrorFrame.Error.AcceptButton:SetPoint("BOTTOM", self.ErrorFrame.Error, "BOTTOM", 0, 20);
		self.ErrorFrame.Error.WebsiteButton:Hide();
		self.ErrorFrame.Error.WebsiteWarning:Hide();
		ActiveURLIndex = nil;
	end
	self.ErrorFrame:Show();
	self.ErrorFrame.Error:SetHeight(height);
end

function StoreFrameErrorAcceptButton_OnClick(self)
	StoreFrame.ErrorFrame:Hide();
end

function StoreFrameErrorWebsiteButton_OnClick(self)
	LoadURLIndex(ActiveURLIndex);
end

function StoreFrameBrowseNextItem_OnClick(self)
	StoreFrameBrowse_Advance(self:GetParent(), 1);
end

function StoreFrameBrowsePrevItem_OnClick(self)
	StoreFrameBrowse_Advance(self:GetParent(), -1);
end

function StoreFrameBrowse_Advance(self, amount)
	local groups = C_PurchaseAPI.GetProductGroups();

	local oldGroupID = CurrentGroupID;
	local nextIndex = getIndex(groups, CurrentGroupID);
	if ( nextIndex ) then
		nextIndex = nextIndex + amount;
	else
		nextIndex = 1;
	end

	if ( nextIndex > #groups ) then
		nextIndex = 1;
	elseif ( nextIndex < 1 ) then
		nextIndex = #groups;
	end

	CurrentGroupID = groups[nextIndex];
	if ( oldGroupID ~= CurrentGroupID ) then
		CurrentProductID = nil;	--Update fills out the product ID with the first value in the group
	end

	StoreFrameBrowse_Update(self)

	self.ProductIndex:SetFormattedText(BLIZZARD_STORE_PRODUCT_INDEX, nextIndex, #groups);
end

function StoreFrameBrowse_Update(self)
	local id, name, description, icon = C_PurchaseAPI.GetProductGroupInfo(CurrentGroupID);
	self.ProductName:SetText(name);
	self.ProductDescription:SetText(description);
	self.Icon:SetTexture(icon);
	self.PlusTax:SetText(currencyInfo().browseNotice);

	StoreFrameBrowse_UpdateQuantitySelection(self);
end

function StoreFrameBrowse_SetSale(self, normalPrice, currentPrice)
	self.NormalPriceFrame:Hide();
	
	self.SaleFrame.SalePrice:SetText(currencyInfo().formatLong(currentPrice)..(currencyInfo().browseHasStar and BLIZZARD_STORE_ASTERISK or ""));
	self.SaleFrame.NormalPrice:SetText(currencyInfo().formatLong(normalPrice));
	self.PlusTax:SetPoint("BOTTOMRIGHT", self.SaleFrame.SalePrice, "BOTTOMLEFT", -5, 0);

	self.SaleFrame:Show();
end

function StoreFrameBrowse_SetNormalPrice(self, price)
	self.SaleFrame:Hide();

	self.NormalPriceFrame.Price:SetText(currencyInfo().formatLong(price)..(currencyInfo().browseHasStar and BLIZZARD_STORE_ASTERISK or ""));
	self.PlusTax:SetPoint("BOTTOMRIGHT", self.NormalPriceFrame.Price, "BOTTOMLEFT", -5, 0);

	self.NormalPriceFrame:Show();
end

function StoreFrameBrowse_UpdateQuantitySelection(self)
	local products = C_PurchaseAPI.GetProducts(CurrentGroupID);
	local quant = self.QuantitySelection;

	if ( not CurrentProductID or not getIndex(products, CurrentProductID) ) then
		CurrentProductID = products[1];
	end

	for i=1, #products do
		local button = quant.buttons[i];
		if ( not button ) then
			quant.buttons[i] = CreateForbiddenFrame("CheckButton", nil, quant, "StoreQuantitySelectionTemplate");
			button = quant.buttons[i];
			button:SetScript("OnClick", StoreFrameBrowseQuantitySelectButton_OnClick);

			if ( i % 2 == 0 ) then
				button:SetPoint("LEFT", quant.buttons[i-1], "RIGHT", 155, 0);
			else
				button:SetPoint("TOP", quant.buttons[i-2], "BOTTOM", 0, -5);
			end
		end

		local id, title, normalPrice, currentPrice = C_PurchaseAPI.GetProductInfo(products[i]);
		button:SetID(id);
		button.Title:SetText(title);
		button.Price:SetText(currencyInfo().formatShort(currentPrice));
		button:SetChecked(id == CurrentProductID);
		button:SetEnabled(id ~= CurrentProductID);
		button:Show();

		if ( id == CurrentProductID ) then
			if ( normalPrice == currentPrice ) then
				StoreFrameBrowse_SetNormalPrice(self, currentPrice);
			else
				StoreFrameBrowse_SetSale(self, normalPrice, currentPrice);
			end
		end
	end

	for i=#products + 1, #quant.buttons do
		quant.buttons[i]:Hide();
	end

	if ( #products == 1 ) then
		quant:SetHeight(1);
		quant:Hide();
	else
		quant:SetHeight(20 * math.ceil(#products / 2) + 5);
		quant:Show();
	end
end

function StoreFrameBrowseQuantitySelectButton_OnClick(self)
	CurrentProductID = self:GetID();
	StoreFrameBrowse_UpdateQuantitySelection(StoreFrame.Browse);
end

function StoreFrameCloseButton_OnClick(self)
	StoreFrame:Hide();
end

function StoreFrameBuyButton_OnClick(self)
	StoreFrame_BeginPurchase(CurrentProductID);
end

function StoreFrame_BeginPurchase(productID)
	WaitingOnConfirmation = true;
	StoreFrame_UpdateActivePanel(StoreFrame);
	C_PurchaseAPI.PurchaseProduct(productID);
end

function StoreFrame_HasFreeBagSlots()
	for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
		local freeSlots, bagFamily = GetContainerNumFreeSlots(i);
		if ( freeSlots > 0 and bagFamily == 0 ) then
			return true;
		end
	end
	return false;
end

------------------------------------------
function StoreConfirmationFrame_OnLoad(self)
	StoreConfirmationFrame = self;

	self:RegisterEvent("STORE_CONFIRM_PURCHASE");

	self.Title:SetText(BLIZZARD_STORE_CONFIRMATION_TITLE);
	self.Instruction:SetText(BLIZZARD_STORE_CONFIRMATION_INSTRUCTION);
	self.CancelButton:SetText(BLIZZARD_STORE_CANCEL_PURCHASE);
	self.FinalBuyButton:SetText(BLIZZARD_STORE_FINAL_BUY);
	self.FinalPriceLabel:SetText(BLIZZARD_STORE_FINAL_PRICE_LABEL);
	self.PaymentMethod:SetText(BLIZZARD_STORE_PAYMENT_METHOD);
	self.PaymentMethodExtra:SetText(BLIZZARD_STORE_PAYMENT_METHOD_EXTRA);
end

function StoreConfirmationFrame_OnEvent(self, event, ...)
	if ( event == "STORE_CONFIRM_PURCHASE" ) then
		WaitingOnConfirmation = false;
		StoreFrame_UpdateActivePanel(StoreFrame);
		if ( StoreFrame:IsShown() ) then
			StoreConfirmationFrame_Update(self);
			self:Show();
		else
			C_PurchaseAPI.PurchaseProductConfirm(false);
		end
	end
end

function StoreConfirmationFrame_OnShow(self)
	StoreFrame.Cover:Show();
	self:Raise();
end

function StoreConfirmationFrame_OnHide(self)
	StoreFrame.Cover:Hide();
end

local FinalPrice;
function StoreConfirmationFrame_Update(self)
	local productID = C_PurchaseAPI.GetConfirmationInfo();
	if ( not productID ) then
		self:Hide(); --May want to show an error message
		return;
	end

	local id, title, normalPrice, currentPrice, groupID = C_PurchaseAPI.GetProductInfo(productID);
	if ( not groupID ) then
		self:Hide(); --Should never happen, but may want to handle and throw an error message.
		return;
	end

	local id, name, description, icon = C_PurchaseAPI.GetProductGroupInfo(groupID);
	self.Icon:SetTexture(icon);
	self.GroupName:SetText(name);
	self.Notice:SetText(currencyInfo().confirmationNotice);
	self.FinalPrice:SetText(currencyInfo().formatLong(currentPrice));
	self.PaymentMethod:SetText(currencyInfo().paymentMethodText);
	self.PaymentMethodExtra:SetText(currencyInfo().paymentMethodSubtext);
	FinalPrice = currentPrice;
end

function StoreConfirmationCancel_OnClick(self)
	C_PurchaseAPI.PurchaseProductConfirm(false);
	StoreConfirmationFrame:Hide();
end

function StoreConfirmationFinalBuy_OnClick(self)
	JustOrderedProduct = true;
	C_PurchaseAPI.PurchaseProductConfirm(true, FinalPrice);
	StoreFrame_UpdateActivePanel(StoreFrame);
	StoreConfirmationFrame:Hide();
end
