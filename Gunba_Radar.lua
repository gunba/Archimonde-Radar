function()
    --<<GNB@FROSTMOURNE>>--
    --Though there are a lot of functions in this WA, not many of them are reusable
    --The point is to be able to easily create radars for future bosses (by duplicating the WA)
    
    ----<<HIDE THE AURA IF ITS THE FIRST FRAME>>----
    if not aura_env.isShown or aura_env.isShown == false then aura_env.this:Hide() end
    
    ----<<GET AURA SIZE FOR SCALING>>----
    local RADAR_SIZE = aura_env.this:GetWidth()
    aura_env.this:SetHeight(RADAR_SIZE)
    
    ----<<SCALE RED WARNING BACKGROUND>>----
    aura_env.this.bg:SetSize(RADAR_SIZE * 0.69, RADAR_SIZE * 0.69);
    
    ----<<MUST BE IN A BOSS ENCOUNTER>>----
    if not UnitExists('boss1') then return false end
    
    ----<<BOSS HEALTH (DETERMINES PHASE)>>----
    local bhp = (UnitHealth('boss1') / UnitHealthMax('boss1')) * 100
    
    ----<<RADAR SCALING OPTIONS>>----
    local DEFAULTSCALE = 2.8
    if not aura_env.radarScale then aura_env.radarScale = DEFAULTSCALE end
    
    --==<<GENERIC RADAR OPTIONS AND VARIABLES>>----
    local MAX_DIST_GUI = RADAR_SIZE/3 --how far things are allowed to go on the gui
    local RADARSCALE = aura_env.radarScale --scale of the actual radar (i.e. how zoomed in/out)
    local DIST_MULT = RADARSCALE * 2 --conversion of pixels to distance (for drawing accurate circles)
    local MAX_DIST = MAX_DIST_GUI /  RADARSCALE --max ig distance based on radar scale
    local LINESIZE = 64 * RADARSCALE --wrought/focused chaos length relative to radarscale
    local LINEDEPTH = RADARSCALE / 2.5 --thickness of lines relative to radarscale
    local RADAR_FPS = 60 --how often this aura updates (fps)
    local TICKRATE = 1 / RADAR_FPS -- how often this aura updates (converted into tickrate)
    local DEFANCHOR = "CENTER" --default anchor location (we never really use anything else)
    local PLAYERSIZE = 8 * RADARSCALE
    local LINEFACTOR = 256/254; -- Multiplying factor for texture coordinates
    local LINEFACTOR_2 = LINEFACTOR / 2; -- Half o that
    local BASEDIST = MAX_DIST_GUI / DEFAULTSCALE
    local SOUND_ENABLED = false --set to true to enable 'sonar' sound when in a red mechanic (SetRadarBG)
    local SOUND_INTERVAL = 2 --how often the sonar plays
    local PLAYERGUID = UnitGUID('player')
    
    ----<<MATH RELATED VARIABLES (ANGLES AND TRIANGLES)>>----
    local f = GetPlayerFacing("player") 
    local pX,pY = UnitPosition( "player" )
    local pi = math.pi
    local pi_doubled = pi*2
    local piv = pi_doubled - f;
    local sin = math.sin
    local cos = math.cos
    
    ----<<ENCOUNTER SPECIFIC VARIABLES (ABILITY SIZES IN YARDS)>>----
    aura_env.dsize = {}
    aura_env.dsize.sf  = 8 * DIST_MULT
    aura_env.dsize.motl = 10 * DIST_MULT
    aura_env.dsize.df = 10 * DIST_MULT
    aura_env.dsize.st = 25 * DIST_MULT
    aura_env.dsize.dff = 5 * DIST_MULT
    aura_env.dsize.nb = 8 * DIST_MULT
    aura_env.dsize.conduit = 8 * DIST_MULT
    
    ----<<DENCOUNTER SPECIFIC VARIABLES (ABILITY STRINGS)>>----
    aura_env.dstr = {}
    aura_env.dstr.st = "Shackled Torment";
    aura_env.dstr.wc = "Wrought Chaos";
    aura_env.dstr.df = "Doomfire";
    aura_env.dstr.fc = "Focused Chaos";
    aura_env.dstr.motl = "Mark of the Legion";
    aura_env.dstr.sf = "Shadowfel Burst";
    aura_env.dstr.dff = "Doomfire Fixate";
    aura_env.dstr.nb = "Nether Banish";
    aura_env.dstr.sc = "Source of Chaos"
    
    function GetDist(x1, y1, x2, y2)
        --Calculate distance between any two points (GUI or in-game)
        return ((x1 - x2)^2 + (y1 - y2)^2)^0.5
    end
    
    function GetCulledPoints(x1, y1, x2, y2)
        --Return line points within radar (even if input is out of radar)
        
        --Calculate mid-point
        mX = (x1+x2)/2;
        mY = (y1+y2)/2;
        
        --Get dist to all three points from mid
        local d1 = GetDist(0, 0, x1, y1)
        local d2 = GetDist(0, 0, x2, y2)
        local dTE = GetDist(0, 0, mX, mY)
        
        --None of these points are visible
        if d1 > MAX_DIST_GUI and d2 > MAX_DIST_GUI and dTE > MAX_DIST_GUI then
            return 0,0,0,0
        end
        
        --The startpoint is outside
        if d1 > MAX_DIST_GUI then
            --Gotta bring the shooter in
            x1, y1 = CalcPoint(x1, y1, mX, mY, d1, dTE)
        end
        --The endpoint is outside
        if d2 > MAX_DIST_GUI then
            --Gotta bring the catcher in
            x2, y2 = CalcPoint(x2, y2, mX, mY, d2, dTE)
        end
        
        return x1, y1, x2, y2
    end
    
    function CalcPoint(x1, y1, x2, y2, d1, d2)
        local totalGap = d1 - d2
        local excessDist = d1 - MAX_DIST_GUI
        local r = 1 - (excessDist / totalGap)
        x1=r*x1+(1-r)*x2
        y1=r*y1+(1-r)*y2
        return x1, y1
    end
    
    function GetRelativeRadarPos(uX, uY)
        --Return radar location from an in-game position
        local d = GetDist(pX, pY, uX, uY)
        
        local sine, cosine =  -sin(piv), -cos(piv);
        local dX, dY = uX - pX, uY - pY;
        
        local rX = ((dY*cosine) - (-dX*sine)) * RADARSCALE
        local rY = ((dY*sine) + (-dX*cosine)) * RADARSCALE
        
        return rX, rY, d
    end
    
    function GetRaidID(id)
        --Convert unit or unitname to raid #
        for j = 1,GetNumGroupMembers() do
            --Return value is inconsistent - we will make extra sure
            if id == 'raid' .. j or UnitName(id) == aura_env.rD[j].name or UnitGUID(id) == aura_env.rD[j].guid then
                return j
            end
        end
    end
    
    function SetCircle(ntable, index, color, alpha, size, x, y, texture, tc1, tc2, tc3, tc4)
        --Creates an actual circle on the radar
        
        --Set custom texture (optional)
        if texture then
            aura_env.this[ntable][index]:SetTexture(texture)
        end
        
        --Warp texture coordinates (optional - used to switch between raid markers and class circles)
        if tc1 then
            aura_env.this[ntable][index]:SetTexCoord(tc1, tc2, tc3, tc4)
        end
        
        aura_env.isShown = true
        
        --Show circle
        aura_env.this[ntable][index]:SetVertexColor(color.r, color.g, color.b, alpha)
        aura_env.this[ntable][index]:SetSize(size, size)
        aura_env.this[ntable][index]:SetPoint(DEFANCHOR, aura_env.this, DEFANCHOR, x, y)
        aura_env.this[ntable][index]:Show();
        
    end
    
    function SetCircleText(ntable, index, text, color)
        --Set circle text (just text and color)
        aura_env.this[ntable][index]:SetText(text);
        aura_env.this[ntable][index]:SetVertexColor(color.r, color.g, color.b, 1)
    end
    
    function SetRadarBG()
        --Function is run to indicate user is in a mechanic for this tick.
        --Also handles playing of sound (if enabled).
        if not aura_env.lastWarn or (GetTime() - aura_env.lastWarn) > SOUND_INTERVAL then
            if SOUND_ENABLED then
                PlaySoundFile(WeakAuras.PowerAurasSoundPath.."sonar.ogg", "master")
            end
            aura_env.lastWarn = GetTime() 
        end
        
        --Show red background
        aura_env.this.bg:Show();
    end
    
    function SetLine(ntable, index, color, x1, y1, x2, y2)
        --Create a line from a starting position to an end position
        aura_env.this[ntable][index]:SetVertexColor(color.r, color.g, color.b, 1)
        aura_env.this[ntable][index]:Show()
        
        DrawLine(aura_env.this[ntable][index], aura_env.this, x1, y1, x2, y2, 3*RADARSCALE, DEFANCHOR)
    end
    
    function AdjustRadarScale(newDist)
        --Function that maintains track of the 'furthest' object that has called this.
        --We determine whether or not to zoom out the radar for any given mechanic by attaching this call (and some basic data about the circle or player)
        if newDist > (BASEDIST) and newDist > aura_env.maxCircDist then
            aura_env.maxCircDist = newDist
            aura_env.radarScale = ((BASEDIST) / newDist) * DEFAULTSCALE
        end  
    end
    
    function BuildPlayerTable()
        
        --We set the player icon here. This is quite an ugly solution. 
        --It is used to keep the size of the player consistent regardless of whether or not they are marked.
        if aura_env.pD.mark then
            aura_env.this.player:SetTexture(aura_env.iconMarkers .. aura_env.pD.mark)
            aura_env.this.player:SetSize(PLAYERSIZE, PLAYERSIZE)
        else
            aura_env.this.player:SetTexture(aura_env.iconPlayer)
            aura_env.this.player:SetSize(PLAYERSIZE * 1.5, PLAYERSIZE * 1.5)
        end
        
        --Build the actual raid on the radar. Set to invisible of out of range (so we can target them for lines, etc.)
        for i = 1,GetNumGroupMembers() do
            if aura_env.rD[i] then
                --We either draw the player visible (with or without a marker), or we draw them invisible (if they are out of range)
                if aura_env.rD[i].udist < MAX_DIST and aura_env.rD[i].guid ~= aura_env.pD.guid then
                    if aura_env.rD[i].dead then
                        SetCircle("raid", i, {r = 1, g = 0, b = 0}, 0.2, PLAYERSIZE, aura_env.rD[i].gx, aura_env.rD[i].gy, aura_env.iconRaid, 0.5, 0.625, 0, 0.25)
                    elseif aura_env.rD[i].mark then
                        SetCircle("raid", i, {r = 1, g = 1, b = 1}, 1, PLAYERSIZE * 0.8, aura_env.rD[i].gx, aura_env.rD[i].gy, aura_env.iconMarkers .. aura_env.rD[i].mark, 0, 1, 0, 1)
                    else
                        SetCircle("raid", i, aura_env.rD[i].col, 1, PLAYERSIZE, aura_env.rD[i].gx, aura_env.rD[i].gy, aura_env.iconRaid, 0.5, 0.625, 0, 0.25)
                    end
                else
                    SetCircle("raid", i, aura_env.rD[i].col, 0, PLAYERSIZE, aura_env.rD[i].gx, aura_env.rD[i].gy)
                end
            end
        end    
        
    end
    
    function BuildPlayerData()
        --Function to build the player table for all the crap we're going to request over and over.
        --Better to just do it now rather than having to constantly run UnitPosition, GetDist, etc.
        --Sometimes this kind of stuff is unavoidable though - distance between each unit to each other, dist to torment, etc.
        aura_env.rD = {}
        aura_env.pD = {}
        for i=0,GetNumGroupMembers() do
            if UnitExists('raid' .. i) then
                --Name, Pos, GUI Pos, Class Color, Class, RaidMarker, Alive/Dead, Dist, GUI Dist.
                aura_env.rD[i] = {}
                aura_env.rD[i].name = UnitName('raid' .. i)
                aura_env.rD[i].ux, aura_env.rD[i].uy = UnitPosition('raid' .. i)
                aura_env.rD[i].gx, aura_env.rD[i].gy, aura_env.rD[i].udist  = GetRelativeRadarPos(aura_env.rD[i].ux, aura_env.rD[i].uy)
                aura_env.rD[i].col = GetClassColor(i)
                aura_env.rD[i].cla = select(2, UnitClass('raid' .. i))
                aura_env.rD[i].mark = GetRaidTargetIndex('raid' .. i) 
                aura_env.rD[i].dead = UnitIsDeadOrGhost('raid' .. i)
                aura_env.rD[i].gdist = GetDist(0, 0, aura_env.rD[i].gx, aura_env.rD[i].gy)
                aura_env.rD[i].guid = UnitGUID('raid' .. i)
                
                --If this entry is the player, create a seperate reference.
                if aura_env.rD[i].guid == PLAYERGUID then
                    aura_env.pD = aura_env.rD[i]
                end
            end
        end
        
    end
    
    function HideExistingTextures()
        --This function gets run at the start of every tick - we then rebuild the radar
        --At some point this probably shouldn't be a fixed 30 textures - better if it created dynamically or something..
        for i = 1,aura_env.MAX_RAID do
            aura_env.this.circle[i]:Hide() --hide circles
            aura_env.this.line[i]:Hide() --hide lines
            aura_env.this.raid[i]:Hide() --hide players
            aura_env.this.circletext[i]:SetText(""); --set text to ""
            aura_env.this.circle[i]:SetTexture(aura_env.iconBackground) --set all circles back to 'non-player' version
        end
        
        for i = 1,aura_env.MAX_GROUND do
            aura_env.this.ground[i]:Hide(); --hide ground mechanics (conduits)
        end
        
        --Hide red background
        aura_env.this.bg:Hide();
        
        --Reset radar scale
        aura_env.radarScale = nil
        aura_env.maxCircDist = 0;
    end
    
    function SetGenericCircle(debuff, r, g, b, a, size, spellid, ttype, btype)
        --Create circles on all raid members who have a certain debuff or spellID
        --Also handles setting of text values for each circle (either a class colored UnitName or timer)
        for i = 1,GetNumGroupMembers() do
            if aura_env.rD[i] and not aura_env.rD[i].dead and UnitDebuff('raid' .. i, debuff) then
                
                local name, rank, icon, stacks, dispelType, duration, expires, caster, isStealable, shouldConsolidate, tSpellID, canApplyAura, isBossDebuff, value1, value2, value3
                
                if btype == "debuff" then
                    name, rank, icon, stacks, dispelType, duration, expires, caster, isStealable, shouldConsolidate, tSpellID, canApplyAura, isBossDebuff, value1, value2, value3 = UnitDebuff('raid' .. i, debuff)
                elseif btype == "buff" then
                    name, rank, icon, stacks, dispelType, duration, expires, caster, isStealable, shouldConsolidate, tSpellID, canApplyAura, isBossDebuff, value1, value2, value3 = UnitDebuff('raid' .. i, buff)
                else
                    name, rank, icon, stacks, dispelType, duration, expires, caster, isStealable, shouldConsolidate, tSpellID, canApplyAura, isBossDebuff, value1, value2, value3 = UnitDebuff('raid' .. i, debuff)
                end
                
                --If no spellID is set, or the spellID set matches the debuff ID
                if not spellid or spellid == tSpellID then 
                    
                    --Default color is the same color as the circle (with a black outline)
                    local defaultColor = {r = r, g = g, b = b}
                    local texture = nil
                    
                    --If its the player, set the custom player texture type
                    if aura_env.rD[i].guid == aura_env.pD.guid then
                        texture = aura_env.iconCircle
                    end
                    
                    local textColor = defaultColor
                    local txtString = ""
                    
                    --Options for different things that can be shown on circles..
                    if not ttype or string.find(ttype, "expires") and expires then
                        txtString = txtString .. "(" .. math.ceil(expires - GetTime()) .. ")"
                    end
                    
                    if string.find(ttype, "stacks") and stacks then
                        txtString = txtString .. "[" .. stacks .. "]"
                    end
                    
                    if string.find(ttype, "name") then
                        textColor = aura_env.rD[i].col
                        txtString = txtString .. aura_env.rD[i].name
                    end
                    
                    if string.find(ttype, "icon") and icon then
                        txtString = "|T" .. icon .. ":0|t" .. txtString
                    end
                    
                    SetCircleText("circletext", i, txtString, textColor)
                    
                    --Show the circle
                    SetCircle("circle", i, {r = r, g = g, b = b}, a, size, aura_env.rD[i].gx, aura_env.rD[i].gy, texture)
                    
                    --Scale radar by the distance of this unit if needed
                    AdjustRadarScale(GetDist(pX, pY, aura_env.rD[i].ux, aura_env.rD[i].uy) + (size/DIST_MULT))
                    
                end
            end
        end
    end
    
    function GetClassColor(index)
        --Get class color of a unit from index.
        local _, classCaps, _ = UnitClass('raid' .. index)
        local color = RAID_CLASS_COLORS[classCaps];
        if not color then color = {r = 1, g = 1, b = 1}  end
        return color
    end
    
    function SetGenericLine(xOffset, yOffset, xOffsetTar, yOffsetTar, xOffsetP, yOffsetP, sIndex, eIndex, lineFixed, lineSize, lineDepth) 
        --This function determines where the line should go (shortening/extending, coloring, etc.).
        --Another function is actually responsible for drawing the line.
        
        local d, dA, dX, dY
        
        --Create local versions of the variables (can we edit function parameters in lua?)
        local xOffset = xOffset
        local yOffset = yOffset
        local xOffsetTar = xOffsetTar
        local yOffsetTar = yOffsetTar
        
        --If user wants to set the line to a fixed distance (i.e. Wrought Chaos -> 150)
        if lineFixed then
            d = GetDist(xOffset, yOffset, xOffsetTar, yOffsetTar)
            dA = d + (lineFixed-d)
            dX = (xOffsetTar - xOffset) / d
            dY = (yOffsetTar - yOffset) / d
            xOffsetTar, yOffsetTar = xOffset + dA * dX, yOffset + dA * dY;
        end
        
        --Keep the line inside the radar itself
        xOffset, yOffset, xOffsetTar, yOffsetTar = GetCulledPoints(xOffset, yOffset, xOffsetTar, yOffsetTar);
        
        --Are we in a line?
        local distA = GetDist(xOffset, yOffset, xOffsetP, yOffsetP)
        local distB = GetDist(xOffsetP, yOffsetP, xOffsetTar, yOffsetTar)
        local distC = GetDist(xOffset, yOffset, xOffsetTar, yOffsetTar)
        local playerIsInLine = (distA + distB) - distC
        
        
        --We need to color the line (and set BG if we are in it)
        local lineColor
        if aura_env.rD[sIndex].guid == aura_env.pD.guid or aura_env.rD[eIndex].guid == aura_env.pD.guid then
            lineColor = {r = 0, g = 0, b = 1}
        elseif playerIsInLine < lineDepth then
            lineColor = {r = 1, g = 0, b = 0}
            SetRadarBG()
        else
            lineColor = {r = 0, g = 1, b = 0}
        end
        
        --Run SetLine function
        SetLine("line", sIndex, lineColor, xOffset, yOffset, xOffsetTar, yOffsetTar, lineSize)
    end
    
    
    function DrawLine(T, C, sx, sy, ex, ey, w, relPoint)
        --<<FUNCTION PROVIDED BY 'Iriel' from 2006~>>--
        --I have not had to make any significant changes :^)--
        
        -- T        - Texture
        -- C        - Canvas Frame (for anchoring)
        -- sx,sy    - Coordinate of start of line
        -- ex,ey    - Coordinate of end of line
        -- w        - Width of line
        -- relPoint - Relative point on canvas to interpret coords (Default BOTTOMLEFT)
        
        if (not relPoint) then relPoint = "BOTTOMLEFT"; end
        
        -- Determine dimensions and center point of line
        local dx,dy = ex - sx, ey - sy;
        local cx,cy = (sx + ex) / 2, (sy + ey) / 2;
        
        -- Normalize direction if necessary
        if (dx < 0) then
            dx,dy = -dx,-dy;
        end
        
        -- Calculate actual length of line
        local l = sqrt((dx * dx) + (dy * dy));
        
        -- Quick escape if it's zero length
        if (l == 0) then
            T:SetTexCoord(0,0,0,0,0,0,0,0);
            T:SetPoint("BOTTOMLEFT", C, relPoint, cx,cy);
            T:SetPoint("TOPRIGHT",   C, relPoint, cx,cy);
            return;
        end
        
        -- Sin and Cosine of rotation, and combination (for later)
        local s,c = -dy / l, dx / l;
        local sc = s * c;
        
        -- Calculate bounding box size and texture coordinates
        local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy;
        if (dy >= 0) then
            Bwid = ((l * c) - (w * s)) * LINEFACTOR_2;
            Bhgt = ((w * c) - (l * s)) * LINEFACTOR_2;
            BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc;
            BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx; 
            TRy = BRx;
        else
            Bwid = ((l * c) + (w * s)) * LINEFACTOR_2;
            Bhgt = ((w * c) + (l * s)) * LINEFACTOR_2;
            BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc;
            BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy;
            TRx = TLy;
        end
        
        -- Set texture coordinates and anchors
        T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy);
        T:SetPoint("BOTTOMLEFT", C, relPoint, cx - Bwid, cy - Bhgt);
        T:SetPoint("TOPRIGHT",   C, relPoint, cx + Bwid, cy + Bhgt);
        
        aura_env.isShown = true
    end
    
    
    --This is the main 'loop' that runs every 'TICKRATE' 
    --Everything here should be encounter specific code that relies on code above.
    if not aura_env.recentTick or (GetTime() - aura_env.recentTick) > TICKRATE then
        
        HideExistingTextures() --hide all existing data
        BuildPlayerData() --get all the player data.
        BuildPlayerTable() --create raid circles, etc.
        
        aura_env.isShown = false
        
        --Doomfire (P1 and P2) (We'll add Doomfire text manually)
        if bhp > 40 then
            SetGenericCircle(aura_env.dstr.df, 0, 1, 0.5, 0.2, aura_env.dsize.df, nil, "stacks")
        end
        
        --Shadowfel and Doomfire Fixate (P1)
        if bhp > 70 then
            SetGenericCircle(aura_env.dstr.dff, 1, 0, 0, 0.5, aura_env.dsize.dff, nil, "nameicon")
            SetGenericCircle(aura_env.dstr.sf, 1, 0, 1, 0.5, aura_env.dsize.sf , nil, "name")
        end
        
        --Nether Banish, Torment, Wrought (P2 and P3)
        if bhp < 70 then
            SetGenericCircle(aura_env.dstr.nb, 1, 0.5, 0, 0.5, aura_env.dsize.nb, 186961, "nameexpires")
            
            --Add entries for torment - we have an event for this but it's slow - use this initially. Event will replace.
            for i = 1, aura_env.MAX_RAID do
                if not aura_env.shackleTable[UnitName('raid' .. i)] and UnitDebuff('raid' .. i, aura_env.dstr.st) then
                    aura_env.shackleTable[UnitName('raid' .. i)] = {x = aura_env.rD[i].ux, y = aura_env.rD[i].uy}
                end
            end
            
            --Remove all entries from torment table that don't have Shackled Torment
            for k,v in pairs(aura_env.shackleTable) do
                local rid = GetRaidID(k)
                if not aura_env.rD[rid] or not UnitDebuff('raid' .. rid, aura_env.dstr.st) then
                    aura_env.shackleTable[k] = nil
                end
            end
            
            --Draw shackles from resulting table
            for k,v in pairs(aura_env.shackleTable) do
                local rid = GetRaidID(k)
                
                local radarPosX, radarPosY, radarPosD = GetRelativeRadarPos(v.x, v.y)
                local shackleOpacity = 0.25;
                local shackleColor;
                local shackleTexture = nil
                
                if aura_env.rD[rid].guid == aura_env.pD.guid then
                    shackleTexture = aura_env.iconCircle
                    shackleOpacity = 0.5
                end
                
                local shackleCount = 0
                for i = 1,GetNumGroupMembers() do
                    if not aura_env.rD[rid].dead then
                        local dSt = GetDist(aura_env.rD[rid].ux, aura_env.rD[rid].uy, v.x, v.y)
                        if dSt < 25 then
                            shackleCount = shackleCount + 1
                        end
                    end
                end
                
                --Code here colors it by the state - is player in it? Is anyone in it? No one is in it.
                if radarPosD < 25 then 
                    shackleColor = {r = 1, g = 0, b = 0}
                    SetRadarBG();
                elseif shackleCount > 0 then
                    shackleColor = {r = 1, g = 0.5, b = 0}
                else
                    shackleColor = {r = 0, g = 1, b = 0}
                end
                
                AdjustRadarScale(radarPosD + (aura_env.dsize.st / DIST_MULT))
                
                SetCircle("circle", rid, shackleColor, shackleOpacity, aura_env.dsize.st, radarPosX, radarPosY, shackleTexture)
                SetCircleText("circletext", rid, aura_env.rD[rid].name .. "(" .. shackleCount .. ")", aura_env.rD[rid].col)  
            end
            
            --Focused Chaos - draw line between the two players (using 'UnitCaster')
            for i = 1,GetNumGroupMembers() do
                local unitCaster = select(8, UnitDebuff('raid' .. i, aura_env.dstr.fc))  
                if unitCaster then
                    local casterIndex = GetRaidID(unitCaster);
                    if aura_env.this.raid[casterIndex]:IsShown() or aura_env.this.raid[i]:IsShown() then
                        SetGenericLine(aura_env.rD[casterIndex].gx, aura_env.rD[casterIndex].gy, aura_env.rD[i].gx, aura_env.rD[i].gy, aura_env.pD.gx, aura_env.pD.gy, i, casterIndex, LINESIZE, 3*RADARSCALE, LINEDEPTH)
                    end
                end
            end
            
        end
        
        --Mark of the Legion, Dark Conduit*, Source of Chaos (P3)
        
        --*Dark Conduit is fed from a seperate weakaura that generates an event and sets aura_env.groundTable
        --This is needed since the radar does not support events.
        if bhp < 50 then
            SetGenericCircle(aura_env.dstr.motl, 1, 0.5, 0, 0.5, aura_env.dsize.motl, nil, "expiresicon")
            
            --No point adding a function or resuable code for this. 
            if aura_env.groundTable then
                local conduitCounter = 1
                for k,v in pairs(aura_env.groundTable) do
                    if conduitCounter > 100 then break end
                    
                    local relPosX, relPosY, relPosD = GetRelativeRadarPos(v.x, v.y)
                    if (relPosD+(aura_env.dsize.conduit/DIST_MULT)) < MAX_DIST then
                        local conduitColor
                        if relPosD < 8 then
                            conduitColor = {r = 1, g = 0, b = 0}
                        else
                            conduitColor = {r = 0, g = 1, b = 0}
                        end
                        
                        SetCircle("ground", conduitCounter, conduitColor, 0.5, aura_env.dsize.conduit, relPosX, relPosY, nil)
                        conduitCounter = conduitCounter + 1
                    end
                end
            end
            
            --Source of Chaos (hardcoded spellID). Should draw a line from 4069.6 -2254.1 to the tank.
            for i = 1,GetNumGroupMembers() do
                tSpellID = select(11, UnitDebuff('raid' .. i, aura_env.dstr.sc))
                if tSpellID == 190703 then -- we found a debuff with an identifiable caster
                    local radarPosX, radarPosY, radarPosD = GetRelativeRadarPos(4069.6, -2254.1)
                    SetGenericLine(radarPosX, radarPosY,  aura_env.rD[i].gx, aura_env.rD[i].gy, aura_env.pD.gx, aura_env.pD.gy, i, i, nil, 4*RADARSCALE, LINEDEPTH * 1.2)
                end
            end
            
        end
        
        aura_env.recentTick = GetTime();
        
    end
    
    --If nothing was drawn, don't show radar.
    if aura_env.isShown == false then
        aura_env.this:Hide()
    else
        aura_env.this:Show()
    end
    
    return true
    
end


--the name of this matters.. used for anchoring stuff
aura_env.this = WeakAuras.regions[aura_env.id].region
aura_env.this:Hide()

--conduit table
aura_env.groundTable = {}
aura_env.shackleTable = {} 

--texture counts..
aura_env.MAX_RAID = 30
aura_env.MAX_GROUND = 100

--icons for each type
aura_env.iconPlayer = "Interface\\Minimap\\MiniMap-DeadArrow"
aura_env.iconRaid = "Interface\\Minimap\\PartyRaidBlips"
aura_env.iconLine = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Square_White"
aura_env.iconBackground = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_White_Border.tga";
aura_env.iconCircle = "Interface\\AddOns\\WeakAuras\\Media\\Textures\\Circle_Squirrel.tga"
aura_env.iconMarkers = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"

--if no player - create. we do it this way to allow copy and pasting of auras.
--possible to do some other shit like aura_env.this = aura_env.this or <<create>> but no difference
if not aura_env.this.player then 
    aura_env.this.player = aura_env.this:CreateTexture(nil);
    aura_env.this.player:SetDrawLayer("OVERLAY", 5);
    aura_env.this.player:SetTexture(aura_env.iconPlayer);
    aura_env.this.player:SetPoint("CENTER", aura_env.this, "CENTER", 0, 0)
    
    aura_env.this.bg = aura_env.this:CreateTexture(nil);
    aura_env.this.bg:SetDrawLayer("BACKGROUND", 1);
    aura_env.this.bg:SetTexture(aura_env.iconBackground);
    aura_env.this.bg:SetPoint("CENTER", aura_env.this, "CENTER", 0, 0)
    aura_env.this.bg:SetVertexColor(0.5, 0, 0, 0.2);
    aura_env.this.bg:SetSize(270, 270);
    aura_env.this.bg:Hide();
end

if not aura_env.this.line then aura_env.this.line = {} end
if not aura_env.this.circle then aura_env.this.circle = {} end
if not aura_env.this.raid then aura_env.this.raid = {} end 
if not aura_env.this.ground then aura_env.this.ground = {} end 
if not aura_env.this.circletext then aura_env.this.circletext = {} end

--it might be better to create the auras more 'efficiently' - i.e. only creating 3 torments
--however i feel this creates difficulty in reusability (we will often want a circle per player or more..)
for i = 1,aura_env.MAX_RAID do
    if not aura_env.this.line[i] then
        aura_env.this.line[i] = aura_env.this:CreateTexture(nil);
        aura_env.this.line[i]:SetTexture(aura_env.iconLine);
        aura_env.this.line[i]:SetDrawLayer("OVERLAY", 3);
        aura_env.this.line[i]:SetPoint("CENTER", aura_env.this, "CENTER", 0, 0)
        aura_env.this.line[i]:Hide();
    end
    
    if not aura_env.this.circle[i] then
        aura_env.this.circle[i] = aura_env.this:CreateTexture(nil);
        aura_env.this.circle[i]:SetTexture(aura_env.iconBackground);
        aura_env.this.circle[i]:SetDrawLayer("OVERLAY", 2);
        aura_env.this.circle[i]:SetPoint("CENTER", aura_env.this, "CENTER", 0, 0)
        aura_env.this.circle[i]:Hide();
        
        aura_env.this.circletext[i] = aura_env.this:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        aura_env.this.circletext[i]:SetPoint("CENTER", aura_env.this.circle[i], "TOP", 0, 0)
        aura_env.this.circletext[i]:SetText("");
        aura_env.this.circletext[i]:SetJustifyH("CENTER");
        aura_env.this.circletext[i]:SetJustifyV("CENTER");
    end
    
    if not aura_env.this.raid[i] then 
        aura_env.this.raid[i] = aura_env.this:CreateTexture(nil);
        aura_env.this.raid[i]:SetTexture(aura_env.iconRaid);
        aura_env.this.raid[i]:SetTexCoord(0.5, 0.625, 0, 0.25) 
        aura_env.this.raid[i]:SetDrawLayer("OVERLAY", 4);
        aura_env.this.raid[i]:SetPoint("CENTER", aura_env.this, "CENTER", 0, 0)
        aura_env.this.raid[i]:Hide();
    end
    
end

--I don't like creating 100 textures here but is there really a better solution? We can't garbage collect them so at best case we don't have 100 textures until the one point at which there is 100 mechanics (i.e. Reap), and then we do have 100 textures until the user reloads UI. We might as well just save a lot of effort and complexity and make 100 here.

for i = 1, aura_env.MAX_GROUND do
    if not aura_env.this.ground[i] then
        aura_env.this.ground[i] = aura_env.this:CreateTexture(nil);
        aura_env.this.ground[i]:SetTexture(aura_env.iconBackground);
        aura_env.this.ground[i]:SetDrawLayer("OVERLAY", 1);
        aura_env.this.ground[i]:SetPoint("CENTER", aura_env.this, "CENTER", 0, 0)
        aura_env.this.ground[i]:Hide();
    end
end















































































































