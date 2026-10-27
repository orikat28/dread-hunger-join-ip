# Dread Hunger — Join by IP (key O)

**RU** | [EN](#english)

Маленький клиентский мод для Dread Hunger: в игре жмёшь **O** — поверх игры появляется окошко
**«IP → Подключиться»**. Вставляешь адрес сервера, жмёшь Enter — и ты на сервере. Не нужно отплывать
от причала и ждать родного окна ввода IP.

Сделано для гида [dreadhunger.fun](https://dreadhunger.fun) — там же инструкции, как поднять свой сервер
([на своём ПК](https://dreadhunger.fun/svoy-server-pk/), [на VPS](https://dreadhunger.fun/svoy-server-vps/)).

## Скачать

**[DH-JoinServer.zip](https://github.com/orikat28/dread-hunger-join-ip/releases/latest/download/DH-JoinServer.zip)** (≈5,5 МБ) — страница релиза: [Releases](https://github.com/orikat28/dread-hunger-join-ip/releases).

## Установка

1. Закрой игру.
2. Открой папку игры: Steam → Dread Hunger → ПКМ → «Управление» → «Просмотреть локальные файлы»
   (обычно `...\steamapps\common\Dread Hunger\`).
3. Распакуй архив **прямо в эту папку**, с заменой. Должно получиться
   `Dread Hunger\DreadHunger\Binaries\Win64\dwmapi.dll` рядом с `DreadHunger-Win64-Shipping.exe`.
4. Запусти игру.

## Как пользоваться

- **O** (на русской раскладке — **Щ**) — открыть окошко. Впиши или вставь адрес (`1.2.3.4` или `1.2.3.4:7777`;
  кнопка «Вставить» берёт его из буфера), **Enter** — подключиться, **Esc** — закрыть.
- **F9** (запасной **Ctrl+Shift+J**) — сразу зайти на последний введённый адрес.
- Порт по умолчанию — `7777`. Последний адрес хранится в
  `%LOCALAPPDATA%\DreadHunger\Saved\SaveData\join_target.txt`.

### Своя компания и голосовой чат

Мод заполняет **родное** окно игры «Подключиться по IP» и нажимает его кнопку — так же, как это происходит
после отплытия. Поэтому:

- Собирайтесь в лобби хоста. **O жмёт только хост лобби**, остальным ничего вводить не надо —
  лобби должно уехать на сервер вместе с ним, вместе с голосом.
- Если подключение штатным путём не началось за 8 секунд (ты не хост или не в лобби), мод заходит запасным
  способом `open ip:port` — **в одиночку и без голосового чата в матче**.
- **Не жмите O каждый по отдельности**: если все зайдут поодиночке, в лобби голос будет, а в матче — нет.

> Честно о проверке: заход хоста через родную кнопку проверен вживую. Что гости лобби уезжают вместе
> с хостом, отдельно со вторым игроком пока не проверялось (путь тот же, что у родной кнопки).
> Если друзей не утянуло или нет голоса — хост заходит обычным путём: отплыть от причала и ввести IP
> в окне игры.

## Антивирус

Windows Defender может ругаться на `dwmapi.dll`: так устроен UE4SS — он подгружается в игру через
подменную системную библиотеку. Это ложное срабатывание; исходники мода лежат в этом репозитории, сам UE4SS —
открытый проект [RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS). Если файл удалился — добавь папку игры в
исключения Defender и распакуй архив ещё раз.

## Удаление

Удали из `DreadHunger\Binaries\Win64\`: `dwmapi.dll`, `UE4SS.dll`, `UE4SS-settings.ini` и папку `Mods`
(если других UE4SS-модов у тебя нет; иначе — только `Mods\JoinServer` и строку `JoinServer : 1` в `Mods\mods.txt`).
Чтобы быстро выключить мод, не удаляя всё, достаточно убрать `dwmapi.dll`.

## Если не работает

- Логи: `%LOCALAPPDATA%\DreadHunger\Saved\Logs\joinserver.log` и `join_popup.log`.
- Окно рисует PowerShell (WinForms) — он есть в любой Windows 10/11.
- Вопросы — в Discord-сообществе гида [dreadhunger.fun](https://dreadhunger.fun).

## Что внутри

| Путь | Что это |
|---|---|
| `src/JoinServer/Scripts/main.lua` | мод (UE4SS Lua): клавиша O, F9, заход через родное окно игры |
| `src/JoinServer/popup/join_popup.ps1` | окошко «IP → Подключиться» (PowerShell + WinForms) |
| `src/mods.txt`, `src/UE4SS-settings.ini` | настройки UE4SS из сборки (консоль выключена) |

Бинарники UE4SS (`UE4SS.dll`, `dwmapi.dll`) в git не лежат — только в архиве релиза.
В архиве: UE4SS 3.0.1 + `shared\UEHelpers` из его поставки + файлы из `src/`.

## Лицензии

- Мод JoinServer — MIT, см. [LICENSE](LICENSE).
- UE4SS (RE-UE4SS) — MIT, © 2022 Narknon, см. [LICENSE-UE4SS.txt](LICENSE-UE4SS.txt).
- Dread Hunger — собственность её правообладателей. Это неофициальный фанатский мод, игру он не содержит.

---

## English

A small client-side mod for Dread Hunger: press **O** in game and an **"IP → Connect"** window pops up
over the game. Paste the server address, hit Enter, and you're in. No need to sail away from the dock
and wait for the game's own IP prompt.

Made for the [dreadhunger.fun](https://dreadhunger.fun) guide, which also explains how to host your own
server ([on your PC](https://dreadhunger.fun/en/host-on-pc/), [on a VPS](https://dreadhunger.fun/en/host-on-vps/)).

### Download

**[DH-JoinServer.zip](https://github.com/orikat28/dread-hunger-join-ip/releases/latest/download/DH-JoinServer.zip)** (~5.5 MB), see [Releases](https://github.com/orikat28/dread-hunger-join-ip/releases).

### Install

1. Close the game.
2. Open the game folder: Steam → Dread Hunger → right-click → Manage → Browse local files
   (usually `...\steamapps\common\Dread Hunger\`).
3. Extract the archive **right into that folder**, overwriting. You should end up with
   `Dread Hunger\DreadHunger\Binaries\Win64\dwmapi.dll` next to `DreadHunger-Win64-Shipping.exe`.
4. Start the game.

### Usage

- **O** opens the window. Type or paste an address (`1.2.3.4` or `1.2.3.4:7777`; Ctrl+V or the
  «Вставить» (Paste) button reads the clipboard), **Enter** or «ПОДКЛЮЧИТЬСЯ» connects, **Esc** closes.
- **F9** (fallback **Ctrl+Shift+J**) rejoins the last address.
- Default port is `7777`. The last address is stored in
  `%LOCALAPPDATA%\DreadHunger\Saved\SaveData\join_target.txt`.

#### Playing with friends and voice chat

The mod fills in the game's **own** "Connect to IP" window and clicks its button, the same thing that
happens after you set sail. So:

- Gather in the host's lobby. **Only the lobby host presses O**; nobody else types anything. The lobby
  should travel to the server together with the host, voice chat included.
- If the normal connect doesn't start within 8 seconds (you're not the host or not in a lobby), the mod
  falls back to `open ip:port`: **you join alone, without in-match voice chat**.
- **Don't have everyone press O separately**: if each player joins on their own, voice works in the lobby
  but not in the match.

> What has been tested: the host joining through the native button was verified live. That lobby guests
> follow the host has not been tested with a second player yet (it is the same code path as the native
> button). If your friends didn't follow or there's no voice, the host should join the usual way: sail away
> from the dock and enter the IP in the game's window.

### Antivirus

Windows Defender may flag `dwmapi.dll`. That's how UE4SS works: it loads into the game through a proxy
system library. It's a false positive. The mod source is in this repo, and UE4SS is the open-source
[RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) project. If the file got removed, add the game folder to
Defender exclusions and extract the archive again.

### Uninstall

Delete from `DreadHunger\Binaries\Win64\`: `dwmapi.dll`, `UE4SS.dll`, `UE4SS-settings.ini` and the `Mods`
folder (if you have no other UE4SS mods; otherwise remove only `Mods\JoinServer` and the `JoinServer : 1`
line in `Mods\mods.txt`). To just switch the mod off, removing `dwmapi.dll` is enough.

### Troubleshooting

- Logs: `%LOCALAPPDATA%\DreadHunger\Saved\Logs\joinserver.log` and `join_popup.log`.
- The window is drawn by PowerShell (WinForms), which ships with every Windows 10/11.
- The window and in-game messages are in Russian; the address format is the same in any language.

### Licenses

- JoinServer mod: MIT, see [LICENSE](LICENSE).
- UE4SS (RE-UE4SS): MIT, © 2022 Narknon, see [LICENSE-UE4SS.txt](LICENSE-UE4SS.txt).
- Dread Hunger belongs to its rights holders. This is an unofficial fan mod and does not contain the game.
