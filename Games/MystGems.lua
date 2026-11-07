local _, addon = ...

-- MystGems: a small match-3 game using WoW's own gem icons. /mqol gems toggles it.
-- Click a gem, then a neighbour, to swap them. Lines of 3+ clear, gems fall, chains score more.
-- A line of 4 leaves a Power Gem (explodes its 3x3 area when matched). A line of 5 leaves a
-- Prism; swap it with any gem to clear every gem of that colour.

local SIZE = 8
local CELL = 40
local STEP = 44
local BOARD = SIZE * STEP - (STEP - CELL)
local HINT_AFTER = 8
local PRISM = 0

-- Star Ruby, Blue Sapphire, Huge Emerald, Arcane Crystal, Azerothian Diamond, Large Opal, Shadowgem.
local GEM_ITEMS = { 7910, 12361, 12364, 12363, 12800, 12799, 1210 }
local GEM_FALLBACK = {
    "INV_Misc_Gem_Ruby_02", "INV_Misc_Gem_Sapphire_02", "INV_Misc_Gem_Emerald_02",
    "INV_Misc_Gem_Crystal_01", "INV_Misc_Gem_Diamond_02", "INV_Misc_Gem_Opal_01",
    "INV_Misc_Gem_Amethyst_02",
}
local PRISM_ICON = "Interface\\Icons\\INV_Enchant_ShardPrismaticLarge"
local TYPES = #GEM_ITEMS
local BAR_TEXTURE = [[Interface\Buttons\WHITE8x8]]

local frame, boardFrame, scoreText, bestText, statusText, flightBar
local cells = {}
local board = {}   -- board[r][c] = gem kind 1..TYPES, or PRISM
local power = {}   -- power[r][c] = true for Power Gems
local icons = {}
local selected, hintCell, lastSwap
local busy = false
local score, idle, clock = 0, 0, 0
local openedByFlight = false
local flight -- { key, dest, start, length } while on a flight path

-- Sound kit 888 is the level-up fanfare. Chain matches use the backpack coin click, or the
-- loot coin sound if that kit is missing.
local SOUND_PRISM = 888
local SOUND_MATCH = SOUNDKIT and SOUNDKIT.LOOT_WINDOW_COIN_SOUND
local SOUND_CHAIN = SOUNDKIT and SOUNDKIT.IG_BACKPACK_COIN_OK or SOUND_MATCH

local function play(sound)
    if type(sound) == "string" then
        PlaySoundFile(sound, addon.db.sound_channel or "Master")
    elseif sound then
        PlaySound(sound, addon.db.sound_channel or "SFX")
    end
end

-- Background music: plays while the window is open, loops, and can be muted.
local MUSIC = "Interface\\AddOns\\MysteriousQoL\\Sounds\\MystGems\\nyancat.ogg"
local MUSIC_LENGTH = 216.7 -- seconds, restarts the track when it ends
local musicHandle, musicTimer

local function stopMusic()
    if musicTimer then
        musicTimer:Cancel()
        musicTimer = nil
    end
    if musicHandle then
        StopSound(musicHandle, 300)
        musicHandle = nil
    end
end

local function startMusic()
    stopMusic()
    if addon.db.fun_mystGems_muted or not (frame and frame:IsShown()) then return end
    local willPlay, handle = PlaySoundFile(MUSIC, addon.db.sound_channel or "Master")
    if willPlay then musicHandle = handle end
    if MUSIC_LENGTH > 0 then
        musicTimer = C_Timer.NewTimer(MUSIC_LENGTH, startMusic)
    end
end

local function gemIcon(kind)
    if kind == PRISM then return PRISM_ICON end
    if not icons[kind] then
        local icon = select(5, C_Item.GetItemInfoInstant(GEM_ITEMS[kind]))
        icons[kind] = icon or ("Interface\\Icons\\" .. GEM_FALLBACK[kind])
    end
    return icons[kind]
end

local function setStatus(text)
    statusText:SetText(text or "")
end

local function updateScore()
    scoreText:SetText("Score  |cffffffff" .. score .. "|r")
    if score > addon.db.fun_mystGems_best then
        addon.db.fun_mystGems_best = score
    end
    bestText:SetText("Best  |cffffffff" .. addon.db.fun_mystGems_best .. "|r")
end

-- Board logic

local function inBounds(r, c)
    return r >= 1 and r <= SIZE and c >= 1 and c <= SIZE
end

-- Same-coloured gems in a straight line from (r, c), not counting (r, c). Prisms never match.
local function runLength(r, c, dr, dc)
    local kind, n = board[r][c], 0
    if kind == PRISM then return 0 end
    r, c = r + dr, c + dc
    while inBounds(r, c) and board[r][c] == kind do
        n = n + 1
        r, c = r + dr, c + dc
    end
    return n
end

local function matchAt(r, c)
    return runLength(r, c, 0, -1) + runLength(r, c, 0, 1) >= 2
        or runLength(r, c, -1, 0) + runLength(r, c, 1, 0) >= 2
end

local function swapValues(r1, c1, r2, c2)
    board[r1][c1], board[r2][c2] = board[r2][c2], board[r1][c1]
    power[r1][c1], power[r2][c2] = power[r2][c2], power[r1][c1]
end

-- Returns the first swap that does something, or nil when the board is stuck.
local function findMove()
    for r = 1, SIZE do
        for c = 1, SIZE do
            for _, d in ipairs({ { 0, 1 }, { 1, 0 } }) do
                local r2, c2 = r + d[1], c + d[2]
                if r2 <= SIZE and c2 <= SIZE then
                    if board[r][c] == PRISM or board[r2][c2] == PRISM then
                        return r, c, r2, c2
                    end
                    if board[r][c] ~= board[r2][c2] then
                        swapValues(r, c, r2, c2)
                        local ok = matchAt(r, c) or matchAt(r2, c2)
                        swapValues(r, c, r2, c2)
                        if ok then return r, c, r2, c2 end
                    end
                end
            end
        end
    end
end

local function newMarks()
    local marked = {}
    for r = 1, SIZE do marked[r] = {} end
    return marked
end

-- Marks every line of 3+ and returns the lines, so 4s and 5s can leave special gems.
local function findMatches()
    local marked, runs = newMarks(), {}
    local function scan(r, c, dr, dc)
        local len = 1 + runLength(r, c, dr, dc)
        if len >= 3 then
            local run = { kind = board[r][c] }
            for i = 0, len - 1 do
                marked[r + dr * i][c + dc * i] = true
                run[#run + 1] = { r + dr * i, c + dc * i }
            end
            runs[#runs + 1] = run
        end
        return len
    end
    for r = 1, SIZE do
        local c = 1
        while c <= SIZE do c = c + scan(r, c, 0, 1) end
    end
    for c = 1, SIZE do
        local r = 1
        while r <= SIZE do r = r + scan(r, c, 1, 0) end
    end
    return marked, runs
end

local function markColour(marked, kind)
    for r = 1, SIZE do
        for c = 1, SIZE do
            if kind == nil or board[r][c] == kind then marked[r][c] = true end
        end
    end
end

-- Power Gems caught in a clear blow up their 3x3 area, which can set off more of them.
-- Prisms caught in a clear wipe out a random colour. Returns the number of blasts.
local function detonate(marked, done)
    local blasts, changed = 0, true
    while changed do
        changed = false
        for r = 1, SIZE do
            for c = 1, SIZE do
                local key = r * 16 + c
                if marked[r][c] and not done[key] then
                    done[key] = true
                    if power[r][c] then
                        blasts = blasts + 1
                        changed = true
                        for dr = -1, 1 do
                            for dc = -1, 1 do
                                if inBounds(r + dr, c + dc) then marked[r + dr][c + dc] = true end
                            end
                        end
                    elseif board[r][c] == PRISM then
                        blasts = blasts + 1
                        changed = true
                        markColour(marked, math.random(TYPES))
                    end
                end
            end
        end
    end
    return blasts
end

-- A fresh board with no ready-made lines and at least one move.
local function fillBoard()
    repeat
        for r = 1, SIZE do
            board[r], power[r] = {}, {}
            for c = 1, SIZE do
                local kind
                repeat
                    kind = math.random(TYPES)
                until not ((c > 2 and board[r][c - 1] == kind and board[r][c - 2] == kind)
                    or (r > 2 and board[r - 1][c] == kind and board[r - 2][c] == kind))
                board[r][c] = kind
            end
        end
    until findMove()
end

-- Drawing and animation

local function showCell(r, c)
    local cell = cells[r][c]
    cell.icon:SetTexture(gemIcon(board[r][c]))
    cell.icon:SetAlpha(1)
    cell.icon:SetPoint("CENTER", cell, "CENTER", 0, 0)
    cell.glow:SetShown(power[r][c] == true or board[r][c] == PRISM)
end

local function showBoard()
    for r = 1, SIZE do
        for c = 1, SIZE do showCell(r, c) end
    end
end

local function setSelected(cell)
    if selected then selected.selection:Hide() end
    selected = cell
    if cell then cell.selection:Show() end
end

local function clearHint()
    if hintCell then hintCell.hint:Hide() end
    hintCell = nil
    idle = 0
end

local animFrame = CreateFrame("Frame")
local anims = {}

-- Each entry slides an icon from (x0, y0) back to its cell and/or fades it from a0 to a1.
local function animate(duration, done)
    busy = true
    local t = 0
    animFrame:SetScript("OnUpdate", function(_, elapsed)
        t = t + elapsed
        local p = math.min(t / duration, 1)
        local eased = 1 - (1 - p) * (1 - p)
        for _, a in ipairs(anims) do
            a.cell.icon:SetPoint("CENTER", a.cell, "CENTER", (a.x0 or 0) * (1 - eased), (a.y0 or 0) * (1 - eased))
            if a.a0 then a.cell.icon:SetAlpha(a.a0 + (a.a1 - a.a0) * p) end
        end
        if p >= 1 then
            animFrame:SetScript("OnUpdate", nil)
            wipe(anims)
            busy = false
            done()
        end
    end)
end

local function animateSwap(r1, c1, r2, c2, done)
    showCell(r1, c1)
    showCell(r2, c2)
    anims[#anims + 1] = { cell = cells[r1][c1], x0 = (c2 - c1) * STEP, y0 = (r1 - r2) * STEP }
    anims[#anims + 1] = { cell = cells[r2][c2], x0 = (c1 - c2) * STEP, y0 = (r2 - r1) * STEP }
    animate(0.15, done)
end

local resolve

-- Clears the marked gems (after any blasts), leaves new special gems behind, then drops
-- everything above and fills the gaps from the top.
local function clearCells(marked, chain, creations, done)
    local blasts = detonate(marked, done or {})
    for _, made in ipairs(creations or {}) do
        marked[made.r][made.c] = nil
    end

    local count = 0
    for r = 1, SIZE do
        for c = 1, SIZE do
            if marked[r][c] then
                count = count + 1
                cells[r][c].glow:Hide()
                anims[#anims + 1] = { cell = cells[r][c], a0 = 1, a1 = 0 }
            end
        end
    end
    score = score + count * 10 * chain + blasts * 50
    updateScore()
    if blasts > 0 then
        setStatus(chain > 1 and ("Boom! Chain x" .. chain) or "Boom!")
    elseif chain > 1 then
        setStatus("Chain x" .. chain .. "!")
    end
    -- A line of 5 plays the level-up fanfare. Otherwise the swap's own match plays the loot
    -- coin sound and every chain match after it plays the backpack coin click.
    local sound = chain > 1 and SOUND_CHAIN or SOUND_MATCH
    for _, made in ipairs(creations or {}) do
        if made.kind == PRISM then sound = SOUND_PRISM end
    end
    play(sound)

    for _, made in ipairs(creations or {}) do
        board[made.r][made.c] = made.kind
        power[made.r][made.c] = made.power
        showCell(made.r, made.c)
    end

    animate(0.18, function()
        for c = 1, SIZE do
            local write = SIZE
            local column = {}
            for r = SIZE, 1, -1 do
                if not marked[r][c] then
                    column[write] = { kind = board[r][c], power = power[r][c], fall = write - r }
                    write = write - 1
                end
            end
            for r = write, 1, -1 do
                column[r] = { kind = math.random(TYPES), fall = write }
            end
            for r = 1, SIZE do
                board[r][c] = column[r].kind
                power[r][c] = column[r].power
                showCell(r, c)
                if column[r].fall > 0 then
                    anims[#anims + 1] = { cell = cells[r][c], x0 = 0, y0 = column[r].fall * STEP }
                end
            end
        end
        animate(0.25, function() resolve(chain + 1) end)
    end)
end

-- Where a line of 4 or 5 leaves its special gem: the swapped gem if it is in the line,
-- otherwise the middle of the line.
local function creationsFor(runs)
    local creations = {}
    for _, run in ipairs(runs) do
        if #run >= 4 then
            local spot = run[math.ceil(#run / 2)]
            for _, pos in ipairs(run) do
                if lastSwap and ((pos[1] == lastSwap[1] and pos[2] == lastSwap[2])
                    or (pos[1] == lastSwap[3] and pos[2] == lastSwap[4])) then
                    spot = pos
                end
            end
            if #run >= 5 then
                creations[#creations + 1] = { r = spot[1], c = spot[2], kind = PRISM }
            else
                creations[#creations + 1] = { r = spot[1], c = spot[2], kind = run.kind, power = true }
            end
        end
    end
    return creations
end

function resolve(chain)
    local marked, runs = findMatches()
    if #runs > 0 then
        local creations = creationsFor(runs)
        lastSwap = nil
        clearCells(marked, chain, creations)
    elseif not findMove() then
        setStatus("No moves left - reshuffled")
        fillBoard()
        showBoard()
    end
end

-- A Prism swapped with a gem clears that colour; two Prisms clear the whole board.
local function firePrism(r1, c1, r2, c2)
    local marked, done = newMarks(), {}
    local k1, k2 = board[r1][c1], board[r2][c2]
    if k1 == PRISM and k2 == PRISM then
        markColour(marked, nil)
    else
        markColour(marked, k1 == PRISM and k2 or k1)
    end
    for _, pos in ipairs({ { r1, c1 }, { r2, c2 } }) do
        if board[pos[1]][pos[2]] == PRISM then
            marked[pos[1]][pos[2]] = true
            done[pos[1] * 16 + pos[2]] = true
        end
    end
    clearCells(marked, 1, nil, done)
end

local function trySwap(r1, c1, r2, c2)
    swapValues(r1, c1, r2, c2)
    animateSwap(r1, c1, r2, c2, function()
        if board[r1][c1] == PRISM or board[r2][c2] == PRISM then
            firePrism(r1, c1, r2, c2)
        elseif matchAt(r1, c1) or matchAt(r2, c2) then
            lastSwap = { r1, c1, r2, c2 }
            resolve(1)
        else
            -- No line made: swap back.
            play(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
            swapValues(r1, c1, r2, c2)
            animateSwap(r1, c1, r2, c2, function() end)
        end
    end)
end

local function onCellClick(cell)
    if busy then return end
    clearHint()
    setStatus(nil)
    if not selected then
        setSelected(cell)
        play(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        return
    end
    local a = selected
    setSelected(nil)
    if a == cell then return end
    if math.abs(a.r - cell.r) + math.abs(a.c - cell.c) == 1 then
        trySwap(a.r, a.c, cell.r, cell.c)
    else
        setSelected(cell)
        play(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

local function newGame()
    if busy then return end
    score = 0
    setSelected(nil)
    clearHint()
    setStatus(nil)
    fillBoard()
    showBoard()
    updateScore()
end

-- Flight bar: fills up across the bottom of the window while on a flight path.

local function formatTime(seconds)
    seconds = math.max(math.floor(seconds + 0.5), 0)
    return string.format("%d:%02d", seconds / 60, seconds % 60)
end

local function updateFlightBar()
    local show = flight ~= nil
    if flightBar:IsShown() ~= show then
        flightBar:SetShown(show)
        frame:SetHeight(BOARD + (show and 120 or 96))
        statusText:ClearAllPoints()
        statusText:SetPoint("BOTTOM", 0, show and 34 or 10)
    end
    if not show then return end

    local elapsed = GetTime() - flight.start
    local dest = flight.dest and flight.dest:match("^[^,]+") or "destination"
    if flight.length then
        flightBar:SetMinMaxValues(0, flight.length)
        flightBar:SetValue(math.min(elapsed, flight.length))
        flightBar:SetAlpha(1)
        flightBar.text:SetText(string.format("%s  -  %s left", dest, formatTime(flight.length - elapsed)))
    else
        -- First time on this route: no time to count down yet, so it is timed instead.
        flightBar:SetMinMaxValues(0, 1)
        flightBar:SetValue(1)
        flightBar:SetAlpha(0.45 + 0.25 * math.sin(clock * 3))
        flightBar.text:SetText(string.format("%s  -  timing this flight  %s", dest, formatTime(elapsed)))
    end
end

-- Window

local function createFrame()
    if frame then return end

    frame = CreateFrame("Frame", "MysteriousQoL_MystGemsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(BOARD + 32, BOARD + 96)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = BAR_TEXTURE,
        edgeFile = BAR_TEXTURE,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.045, 0.05, 0.06, 0.98)
    frame:SetBackdropBorderColor(0.008, 0.486, 0.565, 0.8)
    frame:Hide()
    frame:SetScript("OnShow", startMusic)
    frame:SetScript("OnHide", stopMusic)
    table.insert(UISpecialFrames, "MysteriousQoL_MystGemsFrame")

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", -1, -1)
    accent:SetHeight(3)
    accent:SetColorTexture(0.008, 0.486, 0.565, 1)

    local mute = CreateFrame("Button", nil, frame)
    mute:SetSize(20, 20)
    mute:SetPoint("TOPLEFT", 10, -12)
    mute.icon = mute:CreateTexture(nil, "ARTWORK")
    mute.icon:SetAllPoints()
    mute:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function refreshMute()
        local muted = addon.db.fun_mystGems_muted
        if not mute.icon:SetAtlas(muted and "voicechat-icon-speaker-mute" or "voicechat-icon-speaker") then
            mute.icon:SetTexture(muted and "Interface\\Common\\VoiceChat-Muted" or "Interface\\Common\\VoiceChat-Speaker")
        end
    end
    mute:SetScript("OnClick", function()
        addon.db.fun_mystGems_muted = not addon.db.fun_mystGems_muted
        refreshMute()
        startMusic()
        if GameTooltip:GetOwner() == mute then mute:GetScript("OnEnter")(mute) end
    end)
    mute:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(addon.db.fun_mystGems_muted and "Unmute music" or "Mute music")
        GameTooltip:Show()
    end)
    mute:SetScript("OnLeave", GameTooltip_Hide)
    refreshMute()

    local title = frame:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    title:SetPoint("LEFT", mute, "RIGHT", 6, 0)
    title:SetTextColor(1, 1, 1, 1)
    title:SetText("MYSTGEMS")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -3, -4)
    close:SetScript("OnClick", function() frame:Hide() end)

    scoreText = frame:CreateFontString(nil, "OVERLAY")
    scoreText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    scoreText:SetPoint("TOPLEFT", mute, "BOTTOMLEFT", 6, -8)
    scoreText:SetTextColor(0.5, 0.6, 0.63, 1)

    bestText = frame:CreateFontString(nil, "OVERLAY")
    bestText:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    bestText:SetPoint("LEFT", scoreText, "RIGHT", 24, 0)
    bestText:SetTextColor(0.5, 0.6, 0.63, 1)

    local newButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    newButton:SetSize(96, 22)
    newButton:SetPoint("TOPRIGHT", -32, -30)
    newButton:SetText("New Game")
    newButton:SetScript("OnClick", newGame)

    boardFrame = CreateFrame("Frame", nil, frame)
    boardFrame:SetSize(BOARD, BOARD)
    boardFrame:SetPoint("TOP", 0, -64)
    boardFrame:SetClipsChildren(true)

    statusText = frame:CreateFontString(nil, "OVERLAY")
    statusText:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    statusText:SetPoint("BOTTOM", 0, 10)
    statusText:SetTextColor(0.2, 0.84, 0.91, 1)

    for r = 1, SIZE do
        cells[r] = {}
        for c = 1, SIZE do
            local cell = CreateFrame("Button", nil, boardFrame)
            cell:SetSize(CELL, CELL)
            cell:SetPoint("TOPLEFT", (c - 1) * STEP, -(r - 1) * STEP)
            cell.r, cell.c = r, c

            local bg = cell:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints()
            bg:SetColorTexture(1, 1, 1, (r + c) % 2 == 0 and 0.04 or 0.07)

            cell.icon = cell:CreateTexture(nil, "ARTWORK")
            cell.icon:SetSize(CELL - 4, CELL - 4)
            cell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            -- Pulsing border on Power Gems and Prisms. It follows the icon as it moves.
            cell.glow = cell:CreateTexture(nil, "OVERLAY")
            cell.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
            cell.glow:SetBlendMode("ADD")
            cell.glow:SetPoint("TOPLEFT", cell.icon, "TOPLEFT", -14, 14)
            cell.glow:SetPoint("BOTTOMRIGHT", cell.icon, "BOTTOMRIGHT", 14, -14)
            cell.glow:Hide()

            cell.selection = cell:CreateTexture(nil, "OVERLAY")
            cell.selection:SetAllPoints()
            cell.selection:SetColorTexture(0.2, 0.84, 0.91, 0.35)
            cell.selection:Hide()

            cell.hint = cell:CreateTexture(nil, "OVERLAY")
            cell.hint:SetAllPoints()
            cell.hint:SetColorTexture(1, 0.85, 0.2, 0.3)
            cell.hint:Hide()

            cell:SetScript("OnClick", onCellClick)
            cells[r][c] = cell
        end
    end

    flightBar = CreateFrame("StatusBar", nil, frame)
    flightBar:SetHeight(18)
    flightBar:SetPoint("BOTTOMLEFT", 16, 10)
    flightBar:SetPoint("BOTTOMRIGHT", -16, 10)
    flightBar:SetStatusBarTexture(BAR_TEXTURE)
    flightBar:SetStatusBarColor(0.008, 0.486, 0.565, 1)
    local barBg = flightBar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints()
    barBg:SetColorTexture(1, 1, 1, 0.08)
    flightBar.text = flightBar:CreateFontString(nil, "OVERLAY")
    flightBar.text:SetFont("Fonts\\FRIZQT__.TTF", 11, "OUTLINE")
    flightBar.text:SetPoint("CENTER")
    flightBar.text:SetTextColor(1, 1, 1, 1)
    flightBar:Hide()

    frame:SetScript("OnUpdate", function(_, elapsed)
        clock = clock + elapsed
        local pulse = 0.55 + 0.45 * math.sin(clock * 4)
        for r = 1, SIZE do
            for c = 1, SIZE do cells[r][c].glow:SetAlpha(pulse) end
        end
        updateFlightBar()
        -- Hint: after a while without a move, pulse one gem that can be swapped.
        if busy then return end
        idle = idle + elapsed
        if idle >= HINT_AFTER and not hintCell then
            local r, c = findMove()
            if r then
                hintCell = cells[r][c]
                hintCell.hint:Show()
            end
        end
        if hintCell then
            hintCell.hint:SetAlpha(0.5 + 0.5 * math.sin(idle * 5))
        end
    end)

    newGame()
end

function addon.MI_MystGems_Toggle()
    if not addon.db.fun_mystGems_enabled then
        print("|cff20d5e8MysteriousQoL:|r MystGems is turned off. Turn it on under Fun in /mqol.")
        return
    end
    createFrame()
    openedByFlight = false
    frame:SetShown(not frame:IsShown())
end

-- Flight paths: open when the flight starts (if that option is on), close on landing if the
-- flight opened it. WoW has no "time left" for a flight, so each route is timed on its first
-- flight and saved; later flights on that route count down.

local flightFrame = CreateFrame("Frame")
local pendingRoute

local function flightTimes()
    if type(addon.db.fun_mystGems_flightTimes) ~= "table" then
        addon.db.fun_mystGems_flightTimes = {}
    end
    return addon.db.fun_mystGems_flightTimes
end

-- Taxi node IDs and names of where the flight starts and the picked destination.
local function routeEnds(slot)
    local mapID = GetTaxiMapID and GetTaxiMapID()
    local nodes = mapID and C_TaxiMap and C_TaxiMap.GetAllTaxiNodes(mapID)
    local from, to
    for _, node in ipairs(nodes or {}) do
        if node.state == Enum.FlightPathState.Current then from = node end
        if node.slotIndex == slot then to = node end
    end
    return from, to
end

-- Read-only: notes where the flight goes when a flight master route is picked.
if TakeTaxiNode then
    hooksecurefunc("TakeTaxiNode", function(slot)
        local from, to = routeEnds(slot)
        if from and to then
            pendingRoute = {
                key = from.nodeID .. ">" .. to.nodeID,
                dest = to.name,
            }
        elseif TaxiNodeName then
            -- No node IDs: fall back to the destination name so the route can still be timed.
            local dest = TaxiNodeName(slot)
            pendingRoute = dest and { key = "name:" .. dest, dest = dest } or nil
        else
            pendingRoute = nil
        end
    end)
end

local function onFlightCheck()
    if not addon.db.fun_mystGems_enabled then return end
    if UnitOnTaxi("player") then
        if not flight then
            local route = pendingRoute or {}
            pendingRoute = nil
            flight = {
                key = route.key,
                dest = route.dest,
                start = GetTime(),
                length = route.key and flightTimes()[route.key],
            }
        end
        if addon.db.fun_mystGems_flight and not (frame and frame:IsShown()) and not InCombatLockdown() then
            createFrame()
            openedByFlight = true
            frame:Show()
        end
    else
        if flight then
            local took = GetTime() - flight.start
            if flight.key and took > 10 then
                flightTimes()[flight.key] = math.floor(took + 0.5)
            end
            flight = nil
        end
        if openedByFlight and frame and frame:IsShown() then
            openedByFlight = false
            frame:Hide()
        end
    end
end

flightFrame:SetScript("OnEvent", function()
    -- UnitOnTaxi turns true a moment after the flight starts.
    C_Timer.After(1, onFlightCheck)
end)

function addon.MI_MystGems_SetEnabled()
    flightFrame:UnregisterAllEvents()
    if not addon.db.fun_mystGems_enabled then
        flight = nil
        if frame then frame:Hide() end
        return
    end
    -- Flights are always tracked so the bar works when the game is opened mid-flight.
    flightFrame:RegisterEvent("TAXIMAP_CLOSED")
    flightFrame:RegisterEvent("PLAYER_CONTROL_LOST")
    flightFrame:RegisterEvent("PLAYER_CONTROL_GAINED")
    flightFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
end
