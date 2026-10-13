-- P-Tech : Lunaria / game prototype
-- All hidden roles and actions remain server-side.
local game = {
    phase = 'lobby',
    players = {}, -- [serverId] = {name, alive, role}
    votes = {},
    attacks = {},
    inspections = {},
    round = 0
}

local function say(to, message)
    TriggerClientEvent('chat:addMessage', to, {
        color = { 175, 150, 230 },
        args = { 'Lunaria', message }
    })
end

local function broadcast(message)
    say(-1, message)
end

local function admin(src)
    return src == 0 or IsPlayerAceAllowed(src, 'lunaria.admin')
end

local function playerCount()
    local count = 0
    for _ in pairs(game.players) do count = count + 1 end
    return count
end

local function aliveCount(role)
    local count = 0
    for _, p in pairs(game.players) do
        if p.alive and (not role or p.role == role) then
            count = count + 1
        end
    end
    return count
end

local function displayName(id)
    local p = game.players[id]
    return p and ('%s [%d]'):format(p.name, id) or tostring(id)
end

local function publicStatus(src)
    say(src, ('フェーズ: %s / ラウンド: %d / 参加者: %d / 生存者: %d')
        :format(game.phase, game.round, playerCount(), aliveCount()))
    local entries = {}
    for id, p in pairs(game.players) do
        entries[#entries + 1] = ('%s [%d] %s'):format(p.name, id, p.alive and '生存' or '脱落')
    end
    table.sort(entries)
    say(src, #entries > 0 and table.concat(entries, ' | ') or '参加者なし')
end

local function reset()
    game.phase = 'lobby'
    game.players = {}
    game.votes = {}
    game.attacks = {}
    game.inspections = {}
    game.round = 0
end

local function shuffledIds()
    local ids = {}
    for id in pairs(game.players) do ids[#ids + 1] = id end
    for i = #ids, 2, -1 do
        local j = math.random(i)
        ids[i], ids[j] = ids[j], ids[i]
    end
    return ids
end

local function checkWinner()
    if game.phase == 'lobby' or game.phase == 'ended' then return true end
    local wolves = aliveCount('wolf')
    local other = aliveCount() - wolves
    if wolves == 0 then
        game.phase = 'ended'
        broadcast('ゲーム終了！ 村人陣営の勝利です。')
        return true
    end
    if wolves >= other then
        game.phase = 'ended'
        broadcast('ゲーム終了！ 人狼陣営の勝利です。')
        return true
    end
    return false
end

local function mostVoted(votes)
    local counts = {}
    for actor, target in pairs(votes) do
        local a, t = game.players[actor], game.players[target]
        if a and a.alive and t and t.alive then
            counts[target] = (counts[target] or 0) + 1
        end
    end
    local winner, high, tie = nil, 0, false
    for target, count in pairs(counts) do
        if count > high then
            winner, high, tie = target, count, false
        elseif count == high then
            tie = true
        end
    end
    if tie then return nil end
    return winner
end

local function eliminate(id, why)
    local p = game.players[id]
    if not p or not p.alive then return end
    p.alive = false
    broadcast(('%s は%sにより脱落しました。（役職：%s）')
        :format(displayName(id), why, p.role))
end

RegisterCommand('ljoin', function(src)
    if src <= 0 then return end
    if game.phase ~= 'lobby' then say(src, '募集は終了しています。') return end
    if game.players[src] then say(src, '参加済みです。') return end
    game.players[src] = {name = GetPlayerName(src) or ('Player ' .. src), alive = true}
    broadcast(displayName(src) .. ' が参加しました。')
end, false)

RegisterCommand('lleave', function(src)
    if src <= 0 or not game.players[src] then return end
    if game.phase ~= 'lobby' then
        say(src, '進行中は退出できません。管理者に相談してください。')
        return
    end
    local name = displayName(src)
    game.players[src] = nil
    broadcast(name .. ' が退出しました。')
end, false)

RegisterCommand('lstatus', function(src)
    if src <= 0 then return end
    publicStatus(src)
end, false)

RegisterCommand('lstart', function(src)
    if not admin(src) then say(src, '管理権限がありません。') return end
    if game.phase ~= 'lobby' then say(src, '現在のゲームを終了してから開始してください。') return end
    local n = playerCount()
    if n < 4 then say(src, '開始には4人以上必要です。') return end
    local ids = shuffledIds()
    local wolfCount = n >= 7 and 2 or 1
    for i, id in ipairs(ids) do
        local p = game.players[id]
        p.alive = true
        p.role = i <= wolfCount and 'wolf' or (i == wolfCount + 1 and 'seer' or 'villager')
        say(id, 'あなたの役職: ' .. p.role)
    end
    game.votes, game.attacks, game.inspections = {}, {}, {}
    game.round = 1
    game.phase = 'night'
    broadcast(('ゲーム開始！ %d人 / 第1夜です。人狼は /lkill ID、占い師は /linspect ID'):format(n))
end, false)

RegisterCommand('lvote', function(src, args)
    local actor = game.players[src]
    if game.phase ~= 'day' or not actor or not actor.alive then
        say(src, '昼の生存者のみ投票できます。') return
    end
    local target = tonumber(args[1])
    if not target or target == src or not game.players[target] or not game.players[target].alive then
        say(src, '有効な生存者のIDを指定してください（自分以外）。') return
    end
    game.votes[src] = target
    say(src, '投票を受け付けました: ' .. displayName(target))
end, false)

RegisterCommand('lkill', function(src, args)
    local actor = game.players[src]
    if game.phase ~= 'night' or not actor or not actor.alive or actor.role ~= 'wolf' then
        say(src, 'この行動は実行できません。') return
    end
    local target = tonumber(args[1])
    if not target or not game.players[target] or not game.players[target].alive
        or game.players[target].role == 'wolf' then
        say(src, '有効な襲撃対象のIDを指定してください。') return
    end
    game.attacks[src] = target
    say(src, '襲撃対象を受け付けました。')
end, false)

RegisterCommand('linspect', function(src, args)
    local actor = game.players[src]
    if game.phase ~= 'night' or not actor or not actor.alive or actor.role ~= 'seer' then
        say(src, 'この行動は実行できません。') return
    end
    if game.inspections[src] then say(src, '今夜は占い済みです。') return end
    local target = tonumber(args[1])
    if not target or target == src or not game.players[target] or not game.players[target].alive then
        say(src, '有効な占い対象のIDを指定してください。') return
    end
    game.inspections[src] = target
    say(src, displayName(target) .. ' の判定: ' ..
        (game.players[target].role == 'wolf' and '人狼' or '人狼ではない'))
end, false)

RegisterCommand('lnext', function(src)
    if not admin(src) then say(src, '管理権限がありません。') return end
    if game.phase == 'night' then
        local target = mostVoted(game.attacks)
        if target then eliminate(target, '夜の襲撃')
        else broadcast('今夜の犠牲者はいませんでした。') end
        if checkWinner() then return end
        game.attacks, game.inspections, game.votes = {}, {}, {}
        game.phase = 'day'
        broadcast(('第%d日 昼。議論後、/lvote ID で投票してください。'):format(game.round))
    elseif game.phase == 'day' then
        local target = mostVoted(game.votes)
        if target then eliminate(target, '投票')
        else broadcast('投票同数または投票なしのため、処刑者はいません。') end
        if checkWinner() then return end
        game.votes, game.attacks, game.inspections = {}, {}, {}
        game.round = game.round + 1
        game.phase = 'night'
        broadcast(('第%d夜になりました。'):format(game.round))
    else
        say(src, '進行中のゲームがありません。')
    end
end, false)

RegisterCommand('lreset', function(src)
    if not admin(src) then say(src, '管理権限がありません。') return end
    reset()
    broadcast('ゲームを初期化しました。新しい参加受付を開始します。')
end, false)

AddEventHandler('playerDropped', function()
    local id = source
    local p = game.players[id]
    if not p then return end
    local name = displayName(id)
    if game.phase ~= 'lobby' and game.phase ~= 'ended' and p.alive then
        p.alive = false
        broadcast(name .. ' は切断により脱落しました。')
        checkWinner()
    elseif game.phase == 'lobby' then
        game.players[id] = nil
        broadcast(name .. ' が退出しました。')
    end
end)

math.randomseed(os.time())
print('[Lunaria] ptech_lunaria_game v0.1.0 ready')
