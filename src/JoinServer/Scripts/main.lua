--[[
  JoinServer — свой «оверлей» захода на сервер Dread Hunger по IP
  by whivipe / dreadhunger.fun   (аналог Server Overlay by Serega, без инъекции)

  КАК ЗАЙТИ:
   0) КЛАВИША O (Щ) — поверх игры откроется окошко: вписать/вставить IP →
      «Подключиться» (или Enter) → заход сразу, без корабля. Окно всегда одно,
      клик по игре мимо окна закрывает его. Окно: popup\join_popup.ps1,
      сторож окна поднимается сам при старте игры (ничего запускать не надо).
   1) (консоль UE4SS в сборке выключена; для отладки — GuiConsoleVisible=1) команда:
          join 203.0.113.5
          join 203.0.113.5:2777      (если порт другой)
      Порт по умолчанию 7777, если не указан. Адрес запоминается.
   2) БЫСТРО зайти на последний/сохранённый адрес — хоткей:
          F9            (или запасной CTRL+SHIFT+J)

  Показать текущий сохранённый адрес:   команда  joinwhere
  Адрес хранится (можно править Блокнотом):
      %LOCALAPPDATA%\DreadHunger\Saved\SaveData\join_target.txt
  Лог: %LOCALAPPDATA%\DreadHunger\Saved\Logs\joinserver.log

  Механизм захода (с 2026-09-16, проверен вживую) — ШТАТНЫЙ: мод заполняет
  родное окошко игры «Подключиться по IP» и жмёт его кнопку → лобби хоста едет
  на сервер ЦЕЛИКОМ (все игроки + голос). Жмёт ХОСТ лобби; остальные ничего
  не делают — их увезёт само. Если подключение не началось (не хост / не в
  лобби) — через 8 с запасной движковый  open ip:port  (в одиночку, без голоса).
]]

local UEHelpers = require("UEHelpers")

local DEFAULT_IP   = "203.0.113.5"
local DEFAULT_PORT = "7777"
local DEFAULT_URI  = DEFAULT_IP .. ":" .. DEFAULT_PORT

local localAppData = os.getenv("LOCALAPPDATA") or ""
local logDir     = localAppData .. "\\DreadHunger\\Saved\\Logs"
local saveDir    = localAppData .. "\\DreadHunger\\Saved\\SaveData"
local logPath    = logDir  .. "\\joinserver.log"
local targetFile = saveDir .. "\\join_target.txt"

os.execute('mkdir "' .. logDir  .. '" 2>nul')
os.execute('mkdir "' .. saveDir .. '" 2>nul')

local function Log(msg)
    print("[JoinServer] " .. tostring(msg) .. "\n")
    local f = io.open(logPath, "a")
    if f then f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n") f:close() end
end

-- нормализовать ввод в "ip:port": принимает "1.2.3.4", "1.2.3.4:2777",
-- "open 1.2.3.4", мусор с пробелами и т.п. Порт добавляет по умолчанию.
local function Normalize(raw)
    if not raw then return nil end
    local s = tostring(raw)
    local ip, port = s:match("(%d+%.%d+%.%d+%.%d+):(%d+)")
    if ip then return ip .. ":" .. port end
    ip = s:match("(%d+%.%d+%.%d+%.%d+)")
    if ip then return ip .. ":" .. DEFAULT_PORT end
    return nil
end

local function SaveTarget(uri)
    local w = io.open(targetFile, "w")
    if w then w:write(uri .. "\n") w:close() end
end

local function EnsureTargetFile()
    local f = io.open(targetFile, "r")
    if f then f:close() return end
    SaveTarget(DEFAULT_URI)
    Log("Создан " .. targetFile .. " (по умолчанию " .. DEFAULT_URI .. ")")
end

local function LoadTarget()
    local f = io.open(targetFile, "r")
    if f then
        local line = f:read("*l"); f:close()
        local uri = Normalize(line)
        if uri then return uri end
    end
    return DEFAULT_URI
end

-- сообщение на экране (best-effort)
local function Toast(text)
    pcall(function()
        local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        local world = UEHelpers.GetWorld and UEHelpers.GetWorld() or nil
        if ksl and ksl:IsValid() and world then
            ksl:PrintString(world, text, true, false, {R=0.18,G=0.75,B=0.62,A=1.0}, 6.0)
        end
    end)
end

-- собственно заход по адресу
--
-- ДВА ПУТИ:
--  1) ШТАТНЫЙ (2026-09-16, проверен вживую в лобби): мод делает ровно то, что
--     делает хост руками в родном окошке «Подключиться по IP»: находит живой
--     виджет WBP_ConnectToIP (он всегда есть в HUD лобби / титульном экране),
--     вписывает 4 октета + порт в его поля и зовёт его же обработчик кнопки
--     OnConnectButtonClicked → StartGame → OnlineSession.SetPublicConnectForIP
--     → лобби едет на сервер целиком (голос EOS-лобби живёт). Жмёт ХОСТ.
--  2) ЗАПАСНОЙ: движковый  open ip:port  через KismetSystemLibrary — едет
--     ТОЛЬКО этот клиент (лобби не следует → в матче нет голоса). Включается,
--     если за NATIVE_WAIT с после штатного пути игра даже не начала коннект
--     (нет PendingNetGame и карта та же).
--
-- ⚠️ UE4SS 3.0.1 на этой игре: свойства BP-объектов по имени (w.IPAddress)
-- НЕ читаются, ForEachProperty/ForEachFunction рвутся после 1-го элемента,
-- Lua-таблица как TArray-параметр НЕ передаётся (StartGame({..}) молча
-- ничего не делает). Зато вызовы функций (w:OnConnectButtonClicked(),
-- et:SetText(FText(...))) и FindAllOf работают. Поэтому поля ищем по имени
-- объекта среди всех EditableText, а не через свойства виджета.
local NATIVE_WAIT = 8

local function MapName()
    local ok, name = pcall(function()
        local w = UEHelpers.GetWorld()
        return (w and w:IsValid()) and w:GetFullName() or "?"
    end)
    return ok and tostring(name) or "?"
end

-- идёт ли уже подключение (движок создаёт PendingNetGame на Browse)
local function Connecting()
    local ok, r = pcall(function()
        local p = FindFirstOf("PendingNetGame")
        return p and p:IsValid() or false
    end)
    return ok and r or false
end

local function OpenFallback(uri)
    local ok, e = pcall(function()
        local ksl = StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
        local ctx = UEHelpers.GetPlayerController()
        if not (ctx and ctx:IsValid()) then ctx = UEHelpers.GetWorld() end
        ksl:ExecuteConsoleCommand(ctx, "open " .. uri, nil)
    end)
    if ok then Log("open " .. uri .. " (KSL) OK — еду один, без лобби")
    else Log("KSL open ошибка: " .. tostring(e)) end
    return ok
end

-- штатный путь: родное окошко «Подключиться по IP» — заполнить и нажать
local function NativeLobbyJoin(uri)
    local a, b, c, d, port = uri:match("(%d+)%.(%d+)%.(%d+)%.(%d+):(%d+)")
    if not a then return false end
    local ok, e = pcall(function()
        -- живой экземпляр (в /Engine/Transient), не шаблон класса
        local w = nil
        for _, x in ipairs(FindAllOf("WBP_ConnectToIP_C") or {}) do
            if x:IsValid() and x:GetFullName():find("/Engine/Transient", 1, true) then w = x end
        end
        if not w then error("нет живого виджета ConnectToIP") end
        local wname = w:GetFullName():gsub("^%S+%s", "")
        local want = { IPAddressAEditableBox = a, IPAddressBEditableBox = b, IPAddressCEditableBox = c,
                       IPAddressDEditableBox = d, IPAddressPortEditableBox = port }
        local filled = 0
        for _, et in ipairs(FindAllOf("EditableText") or {}) do
            if et:IsValid() then
                local fn = et:GetFullName()
                local short = fn:match("([%w_]+)$")
                if want[short] and fn:find(wname, 1, true) then
                    et:SetText(FText(want[short]))
                    filled = filled + 1
                end
            end
        end
        if filled ~= 5 then error("заполнено полей " .. filled .. " из 5") end
        w:OnConnectButtonClicked()
    end)
    if ok then Log("штатно: окошко «Подключиться по IP» заполнено (" .. uri .. "), кнопка нажата")
    else Log("штатный путь ✗ " .. tostring(e)) end
    return ok
end

local function JoinURI(uri)
    Log("Захожу на " .. uri)
    Toast("Заход на сервер " .. uri .. " ...")
    local before = MapName()

    if NativeLobbyJoin(uri) then
        Toast("Лобби отправляется на " .. uri .. " …")
        local waited = 0
        LoopAsync(1000, function()
            waited = waited + 1
            if Connecting() or MapName() ~= before then
                Log("поехали штатно (подключение идёт)")
                return true
            end
            if waited >= NATIVE_WAIT then
                Log("за " .. NATIVE_WAIT .. " с подключение не началось (не хост лобби?) — запасной open")
                Toast("Лобби не поехало — захожу один")
                OpenFallback(uri)
                return true
            end
            return false
        end)
        return true
    end

    Log("штатный путь недоступен — запасной open")
    if OpenFallback(uri) then return true end
    Log("НЕ удалось зайти")
    Toast("Не удалось зайти — смотри joinserver.log")
    return false
end

-- заход по введённому/сохранённому адресу; если задан new — запомнить
local function DoJoin(newRaw)
    local uri
    if newRaw and newRaw ~= "" then
        uri = Normalize(newRaw)
        if not uri then
            Log("Не понял адрес: '" .. tostring(newRaw) .. "'. Пример: join 203.0.113.5:7777")
            Toast("Неверный IP. Пример: join 203.0.113.5:7777")
            return false
        end
        SaveTarget(uri)
        Log("Новый адрес сохранён: " .. uri)
    else
        uri = LoadTarget()
    end
    return JoinURI(uri)
end

EnsureTargetFile()
Log("Мод загружен. Текущая цель: " .. LoadTarget())
Log("Ввести IP: команда  join <ip[:port]>  |  Быстрый заход: F9  |  Показать: joinwhere")

----------------------------------------------------------------------
-- Консольные команды (окно консоли UE4SS): вводишь IP и заходишь
--   join 203.0.113.5        -> порт 7777
--   join 203.0.113.5:2777   -> свой порт
--   join                      -> зайти на сохранённый
--   connect ...               -> алиас
--   joinwhere                 -> показать сохранённый адрес
----------------------------------------------------------------------
local function CmdJoin(fullCommand, parameters, ar)
    local arg = parameters and parameters[1] or nil
    -- на случай, если порт передан отдельным словом: "join ip :port" или "ip port"
    if arg and parameters[2] then arg = arg .. tostring(parameters[2]) end
    local ok = DoJoin(arg)
    local uri = LoadTarget()
    if ar and ar.Log then ar:Log((ok and "Захожу на " or "Не удалось зайти на ") .. uri) end
    return true
end

local function CmdWhere(fullCommand, parameters, ar)
    local uri = LoadTarget()
    Log("Сохранённый адрес: " .. uri)
    if ar and ar.Log then ar:Log("Сервер: " .. uri) end
    return true
end

pcall(function() RegisterConsoleCommandGlobalHandler("join",      CmdJoin)  end)
pcall(function() RegisterConsoleCommandGlobalHandler("connect",   CmdJoin)  end)
pcall(function() RegisterConsoleCommandGlobalHandler("joinwhere", CmdWhere) end)

----------------------------------------------------------------------
-- Хоткеи: быстрый заход на сохранённый адрес
----------------------------------------------------------------------
local ok1 = pcall(function() RegisterKeyBind(Key.F9, function() DoJoin(nil) end) end)
if not ok1 then
    pcall(function() RegisterKeyBind(Key.F9, {}, function() DoJoin(nil) end) end)
end
pcall(function()
    RegisterKeyBind(Key.J, {ModifierKey.CONTROL, ModifierKey.SHIFT}, function() DoJoin(nil) end)
end)
Log("Хоткеи: F9 и CTRL+SHIFT+J = заход на " .. LoadTarget())

----------------------------------------------------------------------
-- Клавиша O (Щ): окошко «IP → Подключиться» поверх игры
--
--   Окно рисует popup\\join_popup.ps1 (WinForms, TopMost). Показывает его
--   сторож (тот же скрипт с -Watch): мод сам поднимает его при загрузке
--   игры, он живёт пока жива игра и по файлу open_popup.flag показывает окно.
--   Ничего отдельно запускать не надо — работает при любом старте игры.
--
--   Результат окна — join_now.flag с адресом; мод его подхватывает и заходит.
----------------------------------------------------------------------
local openFlag  = saveDir .. "\\open_popup.flag"
local joinFlag  = saveDir .. "\\join_now.flag"
local aliveFile = saveDir .. "\\popup_watcher.alive"

local popupScript = nil
do
    local src = debug.getinfo(1, "S").source
    local dir = src and src:sub(2):match("(.*[/\\])") or nil
    if dir then popupScript = dir .. "..\\popup\\join_popup.ps1" end
end

local function ReadAll(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a"); f:close()
    return s
end

-- сторож пишет .NET-тики UTC в popup_watcher.alive каждые 150 мс
local function WatcherAlive()
    local s = ReadAll(aliveFile) or ReadAll(aliveFile)   -- второй шанс, если файл как раз пишут
    local ticks = s and tonumber(s:match("%d+")) or nil
    if not ticks then return false end
    local secs = ticks / 1e7 - 62135596800   -- тики → unix-секунды
    return math.abs(os.time() - secs) < 4
end

local function StartWatcher()
    if not popupScript then
        Log("не нашёл popup\\join_popup.ps1 — окно по O работать не будет")
        return false
    end
    -- консоль cmd мигнёт один раз; вызывается при загрузке игры (чёрный экран), незаметно
    os.execute('start "" /min powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "'
        .. popupScript .. '" -Watch')
    Log("сторож окна запущен")
    return true
end

local lastOpen = 0
local function OpenPopup()
    -- защита от автоповтора клавиши и дабл-клика: не чаще раза в 2 с
    local now = os.clock()
    if now - lastOpen < 2.0 then return end
    lastOpen = now

    local f = io.open(openFlag, "w")
    if f then f:write("1") f:close() end
    Log("O: окно")
    -- если через 1.5 с флаг никто не забрал — сторожа нет, поднимаем
    local checks = 0
    LoopAsync(500, function()
        checks = checks + 1
        if checks < 3 then return false end
        local still = io.open(openFlag, "r")
        if still then
            still:close()
            Log("O: сторожа нет — поднимаю, окно появится через пару секунд")
            StartWatcher()
        end
        return true
    end)
end

-- сторож поднимается вместе с игрой, чтобы O срабатывала мгновенно.
-- (запуск игры любым способом: exe, ярлык, bat — UE4SS грузит мод всегда)
if not WatcherAlive() then StartWatcher() end

-- ждём ответа окна: join_now.flag → заход
LoopAsync(400, function()
    local s = ReadAll(joinFlag)
    if not s then return false end
    os.remove(joinFlag)
    local uri = Normalize(s)
    if not uri then
        Log("join_now.flag без адреса: '" .. tostring(s) .. "'")
        return false
    end
    SaveTarget(uri)
    Log("адрес из окна: " .. uri)
    DoJoin(uri)
    return false
end)


pcall(function() RegisterKeyBind(Key.O, OpenPopup) end)
Log("Клавиша O = окошко ввода IP и заход")
