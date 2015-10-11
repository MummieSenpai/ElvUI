local E, L, V, P, G = unpack(select(2, ...));
local UF = E:GetModule("UnitFrames");

local _, ns = ...;
local ElvUF = ns.oUF;
assert(ElvUF, "ElvUI was unable to locate oUF.");
local tinsert = table.insert;

function UF:Construct_RaidpetFrames(unitGroup)
	self:SetScript("OnEnter", UnitFrame_OnEnter);
	self:SetScript("OnLeave", UnitFrame_OnLeave);
	
	self.RaisedElementParent = CreateFrame("Frame", nil, self);
	self.RaisedElementParent:SetFrameStrata("MEDIUM");
	self.RaisedElementParent:SetFrameLevel(self:GetFrameLevel() + 10);
	
	self.Health = UF:Construct_HealthBar(self, true, true, "RIGHT");
	self.Name = UF:Construct_NameText(self);
	self.Buffs = UF:Construct_Buffs(self);
	self.Debuffs = UF:Construct_Debuffs(self);
	self.AuraWatch = UF:Construct_AuraWatch(self);
	self.RaidDebuffs = UF:Construct_RaidDebuffs(self);
	self.DebuffHighlight = UF:Construct_DebuffHighlight(self);
	self.TargetGlow = UF:Construct_TargetGlow(self);
	tinsert(self.__elements, UF.UpdateTargetGlow);
	self:RegisterEvent("PLAYER_TARGET_CHANGED", UF.UpdateTargetGlow);
	self:RegisterEvent("PLAYER_ENTERING_WORLD", UF.UpdateTargetGlow);
	
	self.Threat = UF:Construct_Threat(self);
	self.RaidIcon = UF:Construct_RaidIcon(self);
	self.Range = UF:Construct_Range(self);
	self.HealCommBar = UF:Construct_HealComm(self);
	
	self.customTexts = {};
	UF:Update_RaidpetFrames(self, UF.db["units"]["raidpet"]);
	UF:Update_StatusBars();
	UF:Update_FontStrings();
	
	return self;
end

function UF:RaidPetsSmartVisibility(event)
	if(not self.db or (self.db and not self.db.enable) or (UF.db and not UF.db.smartRaidFilter) or self.isForced) then return; end
	if(event == "PLAYER_REGEN_ENABLED") then self:UnregisterEvent("PLAYER_REGEN_ENABLED") end
	
	if(not InCombatLockdown()) then
		local inInstance, instanceType = IsInInstance();
		if(inInstance and instanceType == "raid") then
			UnregisterStateDriver(self, "visibility");
			self:Show();
		elseif(self.db.visibility) then
			RegisterStateDriver(self, "visibility", self.db.visibility);
		end
	else
		self:RegisterEvent("PLAYER_REGEN_ENABLED");
		return;
	end
end

function UF:Update_RaidpetHeader(header, db)
	header.db = db;
	
	local headerHolder = header:GetParent();
	headerHolder.db = db;
	
	if(not headerHolder.positioned) then
		headerHolder:ClearAllPoints();
		headerHolder:Point("BOTTOMLEFT", E.UIParent, "BOTTOMLEFT", 4, 574);
		
		E:CreateMover(headerHolder, headerHolder:GetName().."Mover", L["Raid Pet Frames"], nil, nil, nil, "ALL,RAID10,RAID25,RAID40");
		headerHolder.positioned = true;

		headerHolder:RegisterEvent("PLAYER_ENTERING_WORLD");
		headerHolder:RegisterEvent("ZONE_CHANGED_NEW_AREA");
		headerHolder:SetScript("OnEvent", UF["RaidPetsSmartVisibility"]);
	end
	
	UF.RaidPetsSmartVisibility(headerHolder);
end

function UF:Update_RaidpetFrames(frame, db)
	frame.db = db;
	local BORDER = E.Border;
	local SPACING = E.Spacing;
	local SHADOW_SPACING = E.PixelMode and 3 or 4;
	local UNIT_WIDTH = db.width;
	local UNIT_HEIGHT = db.height;
	
	frame.colors = ElvUF.colors;
	frame:RegisterForClicks(self.db.targetOnMouseDown and "AnyDown" or "AnyUp");
	
	frame:SetAttribute("initial-height", UNIT_HEIGHT);
	frame:SetAttribute("initial-width", UNIT_WIDTH);
	frame.Range = {insideAlpha = 1, outsideAlpha = E.db.unitframe.OORAlpha};
	if(not frame:IsElementEnabled("Range")) then
		frame:EnableElement("Range");
	end
	
	do
		local health = frame.Health;
		health.Smooth = self.db.smoothbars;
		health.frequentUpdates = db.health.frequentUpdates;
		
		local x, y = self:GetPositionOffset(db.health.position);
		health.value:ClearAllPoints();
		health.value:Point(db.health.position, health, db.health.position, x + db.health.xOffset, y + db.health.yOffset);
		frame:Tag(health.value, db.health.text_format);
		
		health.colorSmooth = nil;
		health.colorHealth = nil;
		health.colorClass = nil;
		health.colorReaction = nil;
		
		if(db.colorOverride == "FORCE_ON") then
			health.colorClass = true;
			health.colorReaction = true;
		elseif(db.colorOverride == "FORCE_OFF") then
			if(self.db["colors"].colorhealthbyvalue == true) then
				health.colorSmooth = true;
			else
				health.colorHealth = true;
			end
		else
			if(self.db["colors"].healthclass ~= true) then
				if(self.db["colors"].colorhealthbyvalue == true) then
					health.colorSmooth = true;
				else
					health.colorHealth = true;
				end
			else
				health.colorClass = true;
				health.colorReaction = true;
			end
			
			if(self.db["colors"].forcehealthreaction == true) then
				health.colorClass = false;
				health.colorReaction = true;
			end
		end
		
		health:ClearAllPoints();
		health:Point("TOPRIGHT", frame, "TOPRIGHT", -BORDER, -BORDER);
		health:Point("BOTTOMLEFT", frame, "BOTTOMLEFT", BORDER, BORDER);
		
		health:SetOrientation(db.health.orientation);
	end
	
	UF:UpdateNameSettings(frame);
	
	do
		local threat = frame.Threat;
		if(db.threatStyle ~= "NONE" and db.threatStyle ~= nil) then
			if(not frame:IsElementEnabled("Threat")) then
				frame:EnableElement("Threat");
			end

			if(db.threatStyle == "GLOW") then
				threat:SetFrameStrata("BACKGROUND");
				threat.glow:ClearAllPoints();
				threat.glow:SetBackdropBorderColor(0, 0, 0, 0);
				threat.glow:Point("TOPLEFT", frame.Health.backdrop, "TOPLEFT", -SHADOW_SPACING, SHADOW_SPACING);
				threat.glow:Point("TOPRIGHT", frame.Health.backdrop, "TOPRIGHT", SHADOW_SPACING, SHADOW_SPACING);
				threat.glow:Point("BOTTOMLEFT", frame.Health.backdrop, "BOTTOMLEFT", -SHADOW_SPACING, -SHADOW_SPACING);
				threat.glow:Point("BOTTOMRIGHT", frame.Health.backdrop, "BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING);
			elseif(db.threatStyle == "ICONTOPLEFT" or db.threatStyle == "ICONTOPRIGHT" or db.threatStyle == "ICONBOTTOMLEFT" or db.threatStyle == "ICONBOTTOMRIGHT" or db.threatStyle == "ICONTOP" or db.threatStyle == "ICONBOTTOM" or db.threatStyle == "ICONLEFT" or db.threatStyle == "ICONRIGHT") then
				threat:SetFrameStrata("HIGH");
				local point = db.threatStyle;
				point = point:gsub("ICON", "");
				
				threat.texIcon:ClearAllPoints();
				threat.texIcon:SetPoint(point, frame.Health, point);
			end
		elseif(frame:IsElementEnabled("Threat")) then
			frame:DisableElement("Threat");
		end
	end
	
	do
		local tGlow = frame.TargetGlow;
		tGlow:ClearAllPoints();
		tGlow:Point("TOPLEFT", -SHADOW_SPACING, SHADOW_SPACING);
		tGlow:Point("TOPRIGHT", SHADOW_SPACING, SHADOW_SPACING);
		tGlow:Point("BOTTOMLEFT", -SHADOW_SPACING, -SHADOW_SPACING);
		tGlow:Point("BOTTOMRIGHT", SHADOW_SPACING, -SHADOW_SPACING);
	end
	
	do
		if(db.debuffs.enable or db.buffs.enable) then
			if(not frame:IsElementEnabled("Aura")) then
				frame:EnableElement("Aura");
			end
		else
			if(frame:IsElementEnabled("Aura")) then
				frame:DisableElement("Aura");
			end
		end
		
		frame.Buffs:ClearAllPoints();
		frame.Debuffs:ClearAllPoints();
	end
	
	do
		local buffs = frame.Buffs;
		local rows = db.buffs.numrows;
		
		if(USE_POWERBAR_OFFSET) then
			buffs:SetWidth(UNIT_WIDTH - POWERBAR_OFFSET);
		else
			buffs:SetWidth(UNIT_WIDTH);
		end
		
		buffs.forceShow = frame.forceShowAuras;
		buffs.num = db.buffs.perrow * rows;
		buffs.size = db.buffs.sizeOverride ~= 0 and db.buffs.sizeOverride or ((((buffs:GetWidth() - (buffs.spacing*(buffs.num/rows - 1))) / buffs.num)) * rows);
		
		if(db.buffs.sizeOverride and db.buffs.sizeOverride > 0) then
			buffs:SetWidth(db.buffs.perrow * db.buffs.sizeOverride);
		end
		
		local x, y = E:GetXYOffset(db.buffs.anchorPoint);
		local attachTo = self:GetAuraAnchorFrame(frame, db.buffs.attachTo);
		
		buffs:Point(E.InversePoints[db.buffs.anchorPoint], attachTo, db.buffs.anchorPoint, x + db.buffs.xOffset, y + db.buffs.yOffset + (E.PixelMode and (db.buffs.anchorPoint:find("TOP") and -1 or 1) or 0));
		buffs:Height(buffs.size * rows);
		buffs["growth-y"] = db.buffs.anchorPoint:find("TOP") and "UP" or "DOWN"
		buffs["growth-x"] = db.buffs.anchorPoint == "LEFT" and "LEFT" or  db.buffs.anchorPoint == "RIGHT" and "RIGHT" or (db.buffs.anchorPoint:find("LEFT") and "RIGHT" or "LEFT");
		buffs["spacing-x"] = db.buffs.xSpacing;
		buffs["spacing-y"] = db.buffs.ySpacing;
		buffs.initialAnchor = E.InversePoints[db.buffs.anchorPoint];
		
		if(db.buffs.enable) then
			buffs:Show();
			UF:UpdateAuraIconSettings(buffs);
		else
			buffs:Hide();
		end
	end
	
	do
		local debuffs = frame.Debuffs;
		local rows = db.debuffs.numrows;
		
		if(USE_POWERBAR_OFFSET) then
			debuffs:SetWidth(UNIT_WIDTH - POWERBAR_OFFSET);
		else
			debuffs:SetWidth(UNIT_WIDTH);
		end
		
		debuffs.forceShow = frame.forceShowAuras;
		debuffs.num = db.debuffs.perrow * rows;
		debuffs.size = db.debuffs.sizeOverride ~= 0 and db.debuffs.sizeOverride or ((((debuffs:GetWidth() - (debuffs.spacing*(debuffs.num/rows - 1))) / debuffs.num)) * rows);
		
		if(db.debuffs.sizeOverride and db.debuffs.sizeOverride > 0) then
			debuffs:SetWidth(db.debuffs.perrow * db.debuffs.sizeOverride);
		end
		
		local x, y = E:GetXYOffset(db.debuffs.anchorPoint);
		local attachTo = self:GetAuraAnchorFrame(frame, db.debuffs.attachTo, db.debuffs.attachTo == "BUFFS" and db.buffs.attachTo == "DEBUFFS");
		
		debuffs:Point(E.InversePoints[db.debuffs.anchorPoint], attachTo, db.debuffs.anchorPoint, x + db.debuffs.xOffset, y + db.debuffs.yOffset);
		debuffs:Height(debuffs.size * rows);
		debuffs["growth-y"] = db.debuffs.anchorPoint:find("TOP") and "UP" or "DOWN";
		debuffs["growth-x"] = db.debuffs.anchorPoint == "LEFT" and "LEFT" or  db.debuffs.anchorPoint == "RIGHT" and "RIGHT" or (db.debuffs.anchorPoint:find("LEFT") and "RIGHT" or "LEFT");
		debuffs["spacing-x"] = db.debuffs.xSpacing;
		debuffs["spacing-y"] = db.debuffs.ySpacing;
		debuffs.initialAnchor = E.InversePoints[db.debuffs.anchorPoint];
		
		if(db.debuffs.enable) then
			debuffs:Show();
			UF:UpdateAuraIconSettings(debuffs);
		else
			debuffs:Hide();
		end
	end
	
	do
		local rdebuffs = frame.RaidDebuffs;
		if(db.rdebuffs.enable) then
			frame:EnableElement("RaidDebuffs");
			
			rdebuffs:Size(db.rdebuffs.size);
			rdebuffs:Point("BOTTOM", frame, "BOTTOM", db.rdebuffs.xOffset, db.rdebuffs.yOffset);
			rdebuffs.count:FontTemplate(nil, db.rdebuffs.fontSize, "OUTLINE");
			rdebuffs.time:FontTemplate(nil, db.rdebuffs.fontSize, "OUTLINE");
		else
			frame:DisableElement("RaidDebuffs");
			rdebuffs:Hide();
		end
	end
	
	do
		local RI = frame.RaidIcon;
		if(db.raidicon.enable) then
			frame:EnableElement("RaidIcon");
			RI:Show();
			RI:Size(db.raidicon.size);
			
			local x, y = self:GetPositionOffset(db.raidicon.attachTo);
			RI:ClearAllPoints();
			RI:Point(db.raidicon.attachTo, frame, db.raidicon.attachTo, x + db.raidicon.xOffset, y + db.raidicon.yOffset);
		else
			frame:DisableElement("RaidIcon");
			RI:Hide();
		end
	end
	
	do
		local dbh = frame.DebuffHighlight;
		if(E.db.unitframe.debuffHighlighting) then
			frame:EnableElement("DebuffHighlight");
			frame.DebuffHighlightFilterTable = E.global.unitframe.DebuffHighlightColors;
			if(E.db.unitframe.debuffHighlighting == "GLOW") then
				frame.DebuffHighlightBackdrop = true;
				frame.DBHGlow:SetAllPoints(frame.Threat.glow);
			else
				frame.DebuffHighlightBackdrop = false;
			end
		else
			frame:DisableElement("DebuffHighlight");
		end
	end
	
	do
		local range = frame.Range;
		if(db.rangeCheck) then
			if(not frame:IsElementEnabled("Range")) then
				frame:EnableElement("Range");
			end
			
			range.outsideAlpha = E.db.unitframe.OORAlpha;
		else
			if(frame:IsElementEnabled("Range")) then
				frame:DisableElement("Range");
			end
		end
	end
	
	UF:UpdateAuraWatch(frame, true);
	
	do
		local healCommBar = frame.HealCommBar;
		local color = UF.db.colors.healPrediction;
		if(db.healPrediction) then
			if(not frame:IsElementEnabled("HealComm4")) then
				frame:EnableElement("HealComm4");
			end
			
			healCommBar:SetOrientation(db.health.orientation);
			healCommBar:SetStatusBarColor(color.r, color.g, color.b, color.a);
		else
			if(frame:IsElementEnabled("HealComm4")) then
				frame:DisableElement("HealComm4");
			end
		end
	end
	
	for objectName, object in pairs(frame.customTexts) do
		if((not db.customTexts) or (db.customTexts and not db.customTexts[objectName])) then
			object:Hide();
			frame.customTexts[objectName] = nil;
		end
	end
	
	if(db.customTexts) then
		local customFont = UF.LSM:Fetch("font", UF.db.font);
		for objectName, _ in pairs(db.customTexts) do
			if(not frame.customTexts[objectName]) then
				frame.customTexts[objectName] = frame.RaisedElementParent:CreateFontString(nil, "OVERLAY");
			end
			
			local objectDB = db.customTexts[objectName];
			if(objectDB.font) then
				customFont = UF.LSM:Fetch("font", objectDB.font);
			end
			
			frame.customTexts[objectName]:FontTemplate(customFont, objectDB.size or UF.db.fontSize, objectDB.fontOutline or UF.db.fontOutline);
			frame:Tag(frame.customTexts[objectName], objectDB.text_format or "");
			frame.customTexts[objectName]:SetJustifyH(objectDB.justifyH or "CENTER");
			frame.customTexts[objectName]:ClearAllPoints();
			frame.customTexts[objectName]:SetPoint(objectDB.justifyH or "CENTER", frame, objectDB.justifyH or "CENTER", objectDB.xOffset, objectDB.yOffset);
		end
	end
	
	UF:ToggleTransparentStatusBar(UF.db.colors.transparentHealth, frame.Health, frame.Health.bg, true);
	
	frame:UpdateAllElements();
end

UF["headerstoload"]["raidpet"] = { nil, "ELVUI_UNITPET", "SecureGroupPetHeaderTemplate" };