<div align="center">

# mod-multibot-bridge

### AzerothCore server-side bridge module for MultiBot Chatless

<strong>mod-multibot-bridge</strong> is the companion AzerothCore module used by the
<a href="https://github.com/Wishmaster117/MultiBot-Chatless">MultiBot-Chatless</a>
World of Warcraft addon.

It provides a structured addon-message bridge between the client UI and the server,
allowing MultiBot to refresh bot data without relying on automatic legacy chat parsing.

<br>

<a href="https://github.com/Wishmaster117/mod-multibot-bridge">
  <img alt="Repository" src="https://img.shields.io/badge/repository-mod--multibot--bridge-blue" />
</a>
<a href="https://github.com/Wishmaster117/MultiBot-Chatless">
  <img alt="Addon" src="https://img.shields.io/badge/addon-MultiBot--Chatless-green" />
</a>
<img alt="Core" src="https://img.shields.io/badge/core-AzerothCore-orange" />
<img alt="Architecture" src="https://img.shields.io/badge/protocol-MBOT-success" />
<img alt="Client" src="https://img.shields.io/badge/client-WotLK%203.3.5a-lightgrey" />

<br>

<img alt="linux-build" src="https://github.com/Wishmaster117/mod-multibot-bridge/actions/workflows/linux-build.yml/badge.svg?branch=main" />
<img alt="windows-build" src="https://github.com/Wishmaster117/mod-multibot-bridge/actions/workflows/windows-build.yml/badge.svg?branch=main" />
<img alt="macos-build" src="https://github.com/Wishmaster117/mod-multibot-bridge/actions/workflows/macos-build.yml/badge.svg?branch=main" />

<br><br>

<table>
  <tr>
    <th>Component</th>
    <th>Repository</th>
    <th>Install Location</th>
  </tr>
  <tr>
    <td><strong>Server Module</strong></td>
    <td>
      <a href="https://github.com/Wishmaster117/mod-multibot-bridge">
        mod-multibot-bridge
      </a>
    </td>
    <td>
      <code>azerothcore/modules/mod-multibot-bridge</code>
    </td>
  </tr>
  <tr>
    <td><strong>Client Addon</strong></td>
    <td>
      <a href="https://github.com/Wishmaster117/MultiBot-Chatless">
        MultiBot-Chatless
      </a>
    </td>
    <td>
      <code>World of Warcraft/Interface/AddOns/MultiBot</code>
    </td>
  </tr>
</table>

</div>

---

## Important Notice

This repository contains **only the AzerothCore server-side bridge module**.

You also need the client addon:

<div align="center">

### 👉 <a href="https://github.com/Wishmaster117/MultiBot-Chatless">MultiBot-Chatless</a>

</div>

Without the addon, this module does nothing visible by itself.  
Without this module, the addon cannot use the new bridge-first / mostly chatless UI refresh paths.

---

# What is mod-multibot-bridge?

`mod-multibot-bridge` is a server-side module that exposes structured Playerbot data to the MultiBot addon using addon messages.

Instead of forcing the addon to trigger bot commands and parse localized chat replies, the addon can send structured `MBOT GET~...` requests to the server.

The bridge then answers with structured payloads that the addon can consume directly.

<div align="center">

<table>
  <tr>
    <th>Legacy behavior</th>
    <th>Bridge-first behavior</th>
  </tr>
  <tr>
    <td>Addon triggers bot commands</td>
    <td>Addon sends structured <code>MBOT GET~...</code> requests</td>
  </tr>
  <tr>
    <td>Bots answer with chat text</td>
    <td>Bridge answers with structured addon messages</td>
  </tr>
  <tr>
    <td>Addon parses localized chat lines</td>
    <td>Addon consumes stable protocol payloads</td>
  </tr>
  <tr>
    <td>Automatic UI refresh creates chat spam</td>
    <td>Main UI refresh paths become mostly chatless</td>
  </tr>
</table>

</div>

---

# Requirements

## Server

- AzerothCore WotLK.
- AzerothCore source build environment.
- `mod-playerbots` installed and working.
- Ability to rebuild the server after adding a module.

## Client

- World of Warcraft 3.3.5a client.
- [`MultiBot-Chatless`](https://github.com/Wishmaster117/MultiBot-Chatless) installed in the client AddOns folder.

---

# Installation

## 1. Clone the module

Clone this repository into your AzerothCore `modules` directory:

```bash
cd /path/to/azerothcore/modules
git clone https://github.com/Wishmaster117/mod-multibot-bridge.git mod-multibot-bridge
```

Expected structure:

```text
azerothcore/
└── modules/
    └── mod-multibot-bridge/
        ├── conf/
        └── src/
```

---

## 2. Re-run CMake

After adding a new module, re-run CMake using your usual AzerothCore build workflow.

Example:

```bash
cd /path/to/azerothcore/build
cmake ../ -DCMAKE_INSTALL_PREFIX=/path/to/azerothcore/env/dist
```

Use the same CMake options you normally use for your server.

---

## 3. Rebuild AzerothCore

Rebuild your server after CMake detects the module.

Example:

```bash
cmake --build . --config Release
```

Or use your normal build command / IDE workflow.

---

## 4. Install or verify the module configuration

The module provides a configuration template:

```text
conf/MultiBotBridge.conf.dist
```

Depending on your AzerothCore setup, make sure the module configuration is copied, installed, or available in the configuration directory used by your worldserver.

Typical final layout may look similar to:

```text
azerothcore/env/dist/etc/modules/MultiBotBridge.conf
```

or:

```text
azerothcore/env/dist/etc/modules/MultiBotBridge.conf.dist
```

Follow the same config handling pattern you use for your other AzerothCore modules.

---

## 5. Start the server

Start `worldserver`.

When the module is loaded correctly and the addon connects, the server console should show bridge traffic similar to:

```text
MBOT HELLO
MBOT HELLO_ACK
MBOT PING
MBOT PONG
GET~ROSTER
GET~STATES
GET~DETAILS
```

---

# Client Addon Installation

Install the companion addon from:

<div align="center">

### 👉 <a href="https://github.com/Wishmaster117/MultiBot-Chatless">MultiBot-Chatless</a>

</div>

Clone it into your World of Warcraft AddOns directory:

```bash
cd "World of Warcraft/Interface/AddOns"
git clone https://github.com/Wishmaster117/MultiBot-Chatless.git MultiBot
```

Expected client structure:

```text
World of Warcraft/
└── Interface/
    └── AddOns/
        └── MultiBot/
            ├── MultiBot.toc
            ├── Core/
            ├── UI/
            └── ...
```

The addon folder must be named:

```text
MultiBot
```

not:

```text
MultiBot-Chatless
```

---

# Updating

## Update the bridge module

```bash
cd /path/to/azerothcore/modules/mod-multibot-bridge
git pull
```

Then re-run CMake if needed and rebuild AzerothCore.

## Update the addon

```bash
cd "World of Warcraft/Interface/AddOns/MultiBot"
git pull
```

---

# Protocol Overview

The bridge uses the `MBOT` addon-message prefix.

Common request / response flow:

```text
Addon  -> Server: MBOT HELLO~<protocolVersion>
Server -> Addon:  MBOT HELLO_ACK~<protocolVersion>~mod-multibot-bridge

Addon  -> Server: MBOT PING~<token>
Server -> Addon:  MBOT PONG~<token>

Addon  -> Server: MBOT GET~ROSTER
Server -> Addon:  MBOT ROSTER~...

Addon  -> Server: MBOT GET~STATES~<token>
Server -> Addon:  MBOT STATES_BEGIN~<token>~<botCount>
Server -> Addon:  MBOT STATE_BEGIN~<token>~<botName>~<combatCount>~<nonCombatCount>
Server -> Addon:  MBOT STATE_ITEM~<token>~<botName>~<scope>~<index>~<strategy>
Server -> Addon:  MBOT STATE_END~<token>~<botName>~<combatCount>~<nonCombatCount>
Server -> Addon:  MBOT STATES_END~<token>~<botCount>

Addon  -> Server: MBOT RUN~FORMATION~GROUP~~<token>~<formation>
Server -> Addon:  MBOT FORMATION_ACK~GROUP~~<token>~<success>~<failure>~<formation>

Addon  -> Server: MBOT GET~FORMATIONS~GROUP~~<token>
Server -> Addon:  MBOT FORMATIONS_BEGIN~<token>~<count>
Server -> Addon:  MBOT FORMATIONS_ITEM~<token>~<botName>~<formation>
Server -> Addon:  MBOT FORMATIONS_END~<token>~<sentCount>

Addon  -> Server: MBOT RUN~STRATEGY~<scope>~<target>~<token>~<stateScope>~<changes>
Server -> Addon:  MBOT STRATEGY_ACK~<scope>~<target>~<token>~<stateScope>~<matched>~<succeeded>~<failed>~<reason>

Addon  -> Server: MBOT GET~WEAPON_ENCHANT~<botName>~<token>
Server -> Addon:  MBOT WEAPON_ENCHANT~<token>~<botName>~<status>~<mhItem>~<mhEnchant>~<mhDuration>~<ohItem>~<ohEnchant>~<ohDuration>

Addon  -> Server: MBOT RUN~GROUP_ROLL~<token>~NORMAL
Addon  -> Server: MBOT RUN~GROUP_ROLL~<token>~ITEM~<encodedItemLink>
Server -> Addon:  MBOT GROUP_ROLL_ACK~<token>~<status>~<mode>~<scope>~<matched>~<invoked>~<reason>

Addon  -> Server: MBOT GET~ENCHANT_TRADE~<botName>~<token>
Server -> Addon:  MBOT ENCHANT_TRADE_BEGIN~<botName>~<token>~<status>~<reason>~<skill>~<maxSkill>
Server -> Addon:  MBOT ENCHANT_TRADE_ITEM~<botName>~<token>~<spellId>~<difficulty>~<available>~<hasTools>~<materialCount>
Server -> Addon:  MBOT ENCHANT_TRADE_MATERIAL~<botName>~<token>~<spellId>~<materialIndex>~<itemId>~<required>~<available>
Server -> Addon:  MBOT ENCHANT_TRADE_END~<botName>~<token>~<status>~<reason>~<count>

Addon  -> Server: MBOT RUN~ENCHANT_TRADE~<botName>~<token>~<spellId>
Server -> Addon:  MBOT ENCHANT_TRADE_RESULT~<botName>~<token>~<spellId>~<status>~<reason>~<accepted>
```

Current capability negotiation includes `STATE_FRAMING_V1`, `STRATEGY_MUTATION_V1`, `OUTFIT_V1`, `INVENTORY_V1`, `INVENTORY_BULK_SELL_V1`, `INVENTORY_OPEN_V1`, `GROUP_ROLL_V1` and `ENCHANT_TRADE_V1`.

The exact payloads are consumed internally by the MultiBot addon.

## Protocol input hardening

The server accepts bridge traffic only when the addon envelope is exactly
`MBOT\t<opcode>...` and the chat language is `LANG_ADDON`.

The bridge enforces the following input rules before any endpoint is called:

- maximum wire size: 255 bytes;
- maximum extracted bridge payload: 250 bytes;
- opcode length: 1 to 24 characters;
- request type length: 1 to 32 characters;
- existing request tokens: 1 to 64 characters using letters, digits, `-`, `_`,
  `.` or `:`;
- exact field count for every supported `GET` and `RUN` request;
- strict unsigned decimal parsing with overflow and range rejection;
- strict `%XX` field decoding;
- rejection of control characters;
- a maximum `ITEM_ACTION` count of 1000, while `0` keeps its existing
  endpoint-specific meaning;
- Group Roll item links are bounded to 160 characters and must contain a valid item-link marker before execution;
- Group Roll requests are rate-limited per requester (4 requests per 2-second window in the current implementation), and execution is restricted to bridge-visible bots in the requester's actual party/raid with Playerbots security revalidation.
- Enchant Trade list/run requests are rate-limited per requester (4 requests per 2-second window), require an exact controllable bot name and token, and accept only a positive numeric spell ID for execution.
- Enchant Trade list framing declares a per-entry material count and 1-based material indexes; the addon rejects missing, duplicate or out-of-range material frames before caching a list.
- Enchant Trade execution revalidates Playerbots security, active session/state, Enchanting skill, known active Enchanting spell identity, required tools/reagents, the exact current Trade partner and the requester's `TRADE_SLOT_NONTRADED` item before Core spell preparation.

Malformed bridge requests are consumed and answered with:

```text
MBOT ERR~<opcode>~<requestType>~<token>~<reason>
```

Console diagnostics log only the player, opcode, lengths, chat type and rejection
reason. Untrusted request and response payloads are no longer written verbatim.

The `RAID` execution scope now requires the requester and the bot to be members
of the same actual raid. It is no longer treated as the unrestricted `ALL`
scope.

## STATE response framing

Current bridge and addon versions negotiate the `STATE_FRAMING_V1` capability.
When that capability is present, state queries use tokenized requests:

```text
GET~STATE~<botName>~<token>
GET~STATES~<token>
```

The bridge returns state data as bounded `STATE_BEGIN`, `STATE_ITEM`, `STATE_END`,
`STATES_BEGIN`, and `STATES_END` frames. Before any state frame is queued or sent,
the bridge checks the actual addon wire length, including the `MBOT\t` envelope,
opcode and field separator, against the 255-byte client limit.

The unframed `GET~STATE~<botName>` and `GET~STATES` forms remain available only as
legacy compatibility paths for addons that do not negotiate `STATE_FRAMING_V1`.
Those legacy forms still use monolithic `STATE` responses and may return
`STATE_TOO_LONG` when a state cannot fit within the wire limit.

This framing guarantee currently applies to the STATE protocol. Other response
families continue to use their own bounded packet or pagination mechanisms and
should not be assumed to be generically fragmented by this capability.

---

# Supported Bridge Areas

<table>
  <tr>
    <th>Area</th>
    <th>Purpose</th>
  </tr>
  <tr>
    <td><code>HELLO</code> / <code>HELLO_ACK</code></td>
    <td>Bridge handshake and protocol detection.</td>
  </tr>
  <tr>
    <td><code>PING</code> / <code>PONG</code></td>
    <td>Connection check between addon and bridge.</td>
  </tr>
  <tr>
    <td><code>GET~ROSTER</code></td>
    <td>Refresh bot roster without legacy chat parsing.</td>
  </tr>
  <tr>
    <td><code>GET~STATE</code> / <code>GET~STATES</code></td>
    <td>Refresh bot strategies and UI state data. Current clients negotiate <code>STATE_FRAMING_V1</code> and use tokenized framed responses; unframed requests remain as legacy compatibility paths.</td>
  </tr>
  <tr>
    <td><code>GET~WEAPON_ENCHANT</code> / <code>WEAPON_ENCHANT</code></td>
    <td>On-demand diagnostic read of main-hand/off-hand item entries, temporary enchant IDs and remaining durations for one visible, controllable bot. The endpoint is rate-limited and is not a polling path.</td>
  </tr>
  <tr>
    <td><code>GET~FORMATIONS</code></td>
    <td>Read the effective current formation of every controllable bot in the player's current party or raid and return one structured item per bot.</td>
  </tr>
  <tr>
    <td><code>GET~DETAILS</code></td>
    <td>Refresh detailed bot information.</td>
  </tr>
  <tr>
    <td><code>GET~STATS</code></td>
    <td>Refresh stat panel data.</td>
  </tr>
  <tr>
    <td><code>GET~PVP_STATS</code></td>
    <td>Refresh PvP statistics panel data.</td>
  </tr>
  <tr>
    <td><code>GET~TALENT_SPEC_LIST</code></td>
    <td>Refresh available talent spec templates without automatic chat parsing.</td>
  </tr>
  <tr>
    <td><code>GET~INVENTORY</code> / <code>INVENTORY_V1</code></td>
    <td>Refresh inventory data natively through the bridge with item links and icons.</td>
  </tr>
  <tr>
    <td><code>RUN~ITEM_ACTION</code> — <code>SELL_VENDOR</code> / <code>SELL_GREY</code></td>
    <td>Run bounded bulk-sell actions after bot/security/rate-limit validation. <code>SELL_VENDOR</code> is the normal bridge-first Sell Vendor path; further SELL_GREY project work is explicitly deferred.</td>
  </tr>
  <tr>
    <td><code>RUN~ITEM_ACTION</code> — <code>OPEN_ITEMS</code></td>
    <td>Run the negotiated <code>INVENTORY_OPEN_V1</code> residual open-items path, revalidating session, controllability and the selected openable item before using the native open-item opcode.</td>
  </tr>
  <tr>
    <td><code>RUN~GROUP_ROLL</code> / <code>GROUP_ROLL_ACK</code></td>
    <td>Run normal or item-linked group rolls through <code>GROUP_ROLL_V1</code>; execution is bounded to bridge-visible, controllable bots in the requester's actual party/raid and is rate-limited per requester.</td>
  </tr>
  <tr>
    <td><code>GET~ENCHANT_TRADE</code> / <code>RUN~ENCHANT_TRADE</code></td>
    <td>Expose and execute the negotiated <code>ENCHANT_TRADE_V1</code> Enchanting Trade Service. The bridge lists only known valid Enchanting spells and their material/tool availability, then executes one validated numeric spell ID against the requester's native non-traded Trade item.</td>
  </tr>
  <tr>
    <td><code>GET~BANK</code></td>
    <td>Refresh bot bank contents when a banker is available near the bot.</td>
  </tr>
  <tr>
    <td><code>GET~GBANK</code></td>
    <td>Refresh the bot guild bank snapshot and withdrawal-rights state without requiring the player to be in the same guild.</td>
  </tr>
  <tr>
    <td><code>GET~SPELLBOOK</code></td>
    <td>Refresh spellbook data.</td>
  </tr>
  <tr>
    <td><code>GET~BOT_SKILLS</code></td>
    <td>Refresh character info skills, professions, secondary skills, weapon skills and armor skills.</td>
  </tr>
  <tr>
    <td><code>GET~BOT_REPUTATIONS</code></td>
    <td>Refresh visible bot reputation standings for the Character Info frame.</td>
  </tr>
  <tr>
    <td><code>GET~BOT_EMBLEMS</code></td>
    <td>Refresh bot emblem counts and money for the Character Info currencies tab.</td>
  </tr>
  <tr>
    <td><code>GET~PROFESSION_RECIPES</code></td>
    <td>Refresh known profession recipes, materials, craftable counts and recipe output metadata.</td>
  </tr>
  <tr>
    <td><code>GET~GLYPHS</code></td>
    <td>Refresh glyph sockets, glyph spell IDs and tooltip data.</td>
  </tr>
  <tr>
    <td><code>GET~OUTFITS</code></td>
    <td>Refresh outfit sets and bridge outfit actions.</td>
  </tr>
  <tr>
    <td><code>GET~TRAINER</code></td>
    <td>Refresh spells a bot can learn from the player's currently selected trainer, including costs and affordability.</td>
  </tr>
  <tr>
    <td><code>GET~QUESTS</code></td>
    <td>Refresh bot quest lists without localized chat parsing.</td>
  </tr>
  <tr>
    <td><code>GET~GAMEOBJECTS</code></td>
    <td>Refresh game object search results for the addon results frame.</td>
  </tr>
  <tr>
    <td><code>RUN~CRAFT_RECIPE</code></td>
    <td>Ask a bot to craft one known profession recipe and return detailed cast failure reasons.</td>
  </tr>
  <tr>
    <td><code>RUN~ITEM_ACTION</code></td>
    <td>Run whitelisted inventory actions including bank deposit/withdraw, guild bank deposit/withdraw, vendor buy, bulk sell and residual open-items operations. Each action has endpoint-specific validation; this is not a generic item-command executor.</td>
  </tr>
  <tr>
    <td><code>RUN~OUTFIT</code></td>
    <td>Run outfit create, update, reset, equip and replace actions through the bridge.</td>
  </tr>
  <tr>
    <td><code>RUN~TRAINER_LEARN</code></td>
    <td>Ask a bot to learn one trainer spell or all available trainer spells after revalidating the selected trainer.</td>
  </tr>
  <tr>
    <td><code>RUN~RTI</code></td>
    <td>Run whitelist-only RTI icon and RTI target commands.</td>
  </tr>
  <tr>
    <td><code>RUN~COMBAT</code></td>
    <td>Run whitelist-only combat strategy commands.</td>
  </tr>
  <tr>
    <td><code>RUN~POSITION</code></td>
    <td>Run whitelist-only disperse distance and disable commands.</td>
  </tr>
  <tr>
    <td><code>RUN~FORMATION</code></td>
    <td>Apply one validated formation to every controllable bot in the player's current party or raid and return aggregate success/failure counts.</td>
  </tr>
  <tr>
    <td><code>RUN~STRATEGY</code> / <code>STRATEGY_ACK</code></td>
    <td>Apply bounded structured <code>co/nc</code> strategy mutations, verify the resulting bot strategy state, and return matched/succeeded/failed counts plus a structured reason.</td>
  </tr>
  <tr>
    <td><code>RUN~LOOT</code></td>
    <td>Run whitelist-only loot rules and loot list commands without addon-side chat parsing.</td>
  </tr>
</table>

---

# Quest matrix (local extension: `QUEST_MATRIX` / `QUEST_GIVE`)

Not part of the upstream bridge. A party-wide quest overview inside MultiBot: **rows** are all quests that
anybody in the party has open or has finished (restricted to quests of the last *span* levels, default 10:
quest level >= your level - span), **columns** are you plus the bots grouped with you. Cells: `Add` (click: the quest
goes straight into that bot's log, no NPC visit), `Active`, `Turn in`, `Failed`, `Done`, or `-` (cannot take it).

Why the server has to do it: a 3.3.5 client only ever knows its *own* quest log. The logs of the bots never reach
the addon, so the bridge computes the matrix and streams it.

Capability: `QUEST_MATRIX_V1` (advertised in `CAPS`).

```
GET QUEST_MATRIX~<token>~<span>          span 0-80, one request per 1.5 s per player
  QM_BEGIN   <token>~<members>~<rows>~<refLevel>~<span>~<truncated 0|1>
  QM_MEMBER  <token>~<index>~<name>~<self 0|1>~<level>~<classId>          (index 0 = you)
  QM_ROW     <token>~<questId>~<level>~<statuses>~<title>                  one status char per member
  QM_END     <token>~<rows>

RUN QUEST_GIVE~<bot>~<token>~<questId>
  QUEST_GIVE_RESULT  <bot>~<token>~<questId>~OK|ERR~<reason>
```

Status chars: `A` active, `R` ready to turn in, `F` failed, `D` done (rewarded), `N` not taken (could take it),
`X` cannot take it. Rows are sorted "something to do first" (someone has it open, then a bot could take it, then the rest),
then by quest level, and cut at 250 rows (`truncated = 1`). Error reasons of `QUEST_GIVE`: `LEVEL CLASS RACE SKILL
REPUTATION PREREQ EXCLUSIVE CHAIN CANNOT_TAKE CANNOT_ADD ALREADY_DONE ALREADY_HAS NO_BOT NO_QUEST FORBIDDEN RATE_LIMIT`.
`QUEST_GIVE` uses the same call as the GM `.quest add` (`AddQuestAndCheckCompletion(quest, nullptr)`) after the usual
`CanTakeQuest` / `CanAddQuest` checks and the Playerbots security level check, so nothing is given that the bot could
not take at an NPC. With the quest-log overflow core patch (`Quests.MaxActive`) a full log is not a blocker.

Client side (in `client/`): `MultiBotQuestMatrixFrame.lua` is the panel (`/mbq`, or the button in the MultiBot quests
menu). `client/install_quest_matrix.py` copies it into the addon and applies the three small hooks
(`Core/MultiBotComm.lua`, `UI/MultiBotQuestsMenu.lua`, `MultiBot.toc`); it is idempotent, so re-run it after every
MultiBot update. Restart the WoW client afterwards.

# Chatless Design

This module is designed to reduce automatic chat spam caused by UI refresh operations.

It does **not** remove manual playerbot commands.

Manual commands are still useful for diagnostics and gameplay actions.  
For example, players can still intentionally use commands such as:

```text
who
co ?
nc ?
ss ?
```

The bridge replaces migrated automatic data-refresh paths and selected gameplay write paths with explicit, whitelisted contracts. It is intentionally **not** a generic Playerbots command executor.

Formation selection and inspection are also bridge-first. `RUN~FORMATION` applies a validated formation across the whole current party or raid, while `GET~FORMATIONS` reads the effective value from each controllable bot. Neither path requires PARTY, RAID, whisper or `TellMaster` output. The `GROUP` scope intentionally covers the complete party or raid; individual raid subgroups are not targeted.

## Enchanting Trade Service

The Enchanting Trade Service is intentionally narrower than a generic cast endpoint. `ENCHANT_TRADE_V1` discovers only spells the selected bot actually knows that belong to the Enchanting skill line and contain a valid non-soulbinding `SPELL_EFFECT_ENCHANT_ITEM`. Execution accepts only the numeric spell ID, revalidates the requester/bot Trade relationship and `TRADE_SLOT_NONTRADED`, then uses native `SpellCastTargets::SetTradeItemTarget()` and Core `Spell::prepare()`. The normal Trade accept path performs Core validation again before the enchant is finalized.

Discovery responses are capped at 256 enchantment entries. `ENCHANT_TRADE_END` reports the number of `ENCHANT_TRADE_ITEM` entries actually sent after that cap and per-packet budget checks.

Runtime validation on 2026-08-14 confirmed list retrieval, reagent/tool status, native Trade-window targeting and a real item enchant. No generic Playerbots command/cast executor or automatic chat path is exposed by this capability.

## Warlock strategy selectors and stone switching

The migrated Warlock Stones, Soulstones, Pets and Curses selectors use `RUN~STRATEGY` rather than direct automatic selector whispers. The bridge verifies strategy mutations before returning `STRATEGY_ACK`, allowing the addon to refresh selector state from authoritative server `STATE` data.

Firestone/Spellstone switching needs one additional bridge-side guard because Playerbots normally refuses to use a spell item on a weapon whose `TEMP_ENCHANTMENT_SLOT` is already occupied. For a real exclusive non-combat switch on a controllable Warlock, the bridge:

1. reads the current main-hand temporary enchant;
2. discovers the temporary-enchant IDs exposed by Firestone/Spellstone items actually carried by the bot;
3. refuses to clear the slot when the current enchant is not recognized as one of those Warlock stone enchants;
4. removes the recognized old enchant effects and clears the temporary slot;
5. reuses the existing Playerbots `firestone` or `spellstone` action instead of duplicating spell/item logic.

No Firestone/Spellstone enchant ID is hardcoded by this switch path, and `mod-playerbots` does not need to be modified.

For targeted verification, `GET~WEAPON_ENCHANT` / `WEAPON_ENCHANT` exposes an on-demand diagnostic snapshot of the equipped weapon temporary-enchant state. It checks bot visibility/control security and applies a 500 ms per-requester rate limit. It is not used for automatic polling.

The endpoint and switching implementation remain present, while the project's final real Firestone/Spellstone `TEMP_ENCHANTMENT_SLOT` revalidation is intentionally deferred until the end of the normal roadmap.

---

# Current Development Baseline

Documentation synchronized on **2026-08-14** against:

- addon `main`: `106074c3c93f80812f73af27e746860c7c8a4dcf` (PR #61, Group Roll UI);
- bridge `main`: `210bd1f4f6597fe4f0691ec729ec4904ebe2d463` (PR #26, Group Roll support).

Recent bridge-first milestones include `OUTFIT_V1`, `INVENTORY_V1`, hardened bank/guild-bank/vendor-buy item actions, `INVENTORY_BULK_SELL_V1`, `INVENTORY_OPEN_V1`, `GROUP_ROLL_V1` and the runtime-validated `ENCHANT_TRADE_V1` Enchanting Trade Service.

The current PR candidate adds `ENCHANT_TRADE_V1` on top of the Group Roll main baseline. Runtime validation on 2026-08-14 confirmed known-enchant listing, native Trade-slot execution and a real item enchant with no generic cast/chat executor.

The next normal roadmap item is **item-specific loot-rule add/remove**. Deferred work that must not interrupt that sequence includes the SELL_GREY/core-API follow-up and final Firestone/Spellstone TEMP_ENCHANT revalidation.


---

# Troubleshooting

<details>
<summary><strong>The module does not appear to load</strong></summary>

Check that the module is installed here:

```text
azerothcore/modules/mod-multibot-bridge
```

and that the structure is not nested incorrectly.

Correct:

```text
azerothcore/modules/mod-multibot-bridge/src
azerothcore/modules/mod-multibot-bridge/conf
```

Incorrect:

```text
azerothcore/modules/mod-multibot-bridge/mod-multibot-bridge/src
```

Then re-run CMake and rebuild the server.

</details>

<details>
<summary><strong>The addon loads but does not connect to the bridge</strong></summary>

Check that:

- `mod-multibot-bridge` was compiled into the server.
- `worldserver` was restarted after rebuilding.
- `MultiBot-Chatless` is installed in `Interface/AddOns/MultiBot`.
- The addon is enabled on the character selection screen.
- The server console shows `MBOT HELLO` / `HELLO_ACK` traffic when logging in or reloading the UI.

</details>

<details>
<summary><strong>I still see some bot chat messages</strong></summary>

The bridge removes automatic UI-refresh spam for migrated paths.

Manual commands and some gameplay write actions may still intentionally produce chat output.

In the addon, normal bridge-first usage should keep:

```lua
MultiBot.allowLegacyChatFallback = false
```

Only enable legacy fallback temporarily for debugging.

</details>

<details>
<summary><strong>Formation changes or formation status do not reach the addon</strong></summary>

Check the server console for the structured formation requests and responses:

```text
RUN~FORMATION~GROUP~~<token>~circle
FORMATION_ACK~GROUP~~<token>~<success>~<failure>~circle
GET~FORMATIONS~GROUP~~<token>
FORMATIONS_BEGIN~<token>~<count>
FORMATIONS_ITEM~<token>~<botName>~<formation>
FORMATIONS_END~<token>~<sentCount>
```

Only controllable bots in the player's current party or raid are included. The bridge does not expose or target bots outside that group, and it does not apply formations separately to raid subgroups.

</details>

<details>
<summary><strong>Inventory, spellbook, glyphs or outfits are not updating</strong></summary>

Check the server console for requests such as:

```text
GET~INVENTORY
GET~SPELLBOOK
GET~GLYPHS
GET~OUTFITS
```

If these do not appear, the addon may not be connected to the bridge.

If they appear but data is missing, verify that the target bot is online, grouped, and available to the player.

</details>

<details>
<summary><strong>Profession recipe crafting fails from the addon</strong></summary>

Check the server console for responses such as:

```text
PROFESSION_RECIPE_CRAFT~BotName~token~skillId~spellId~itemId~ERR~REQUIRES_SPELL_FOCUS
PROFESSION_RECIPE_CRAFT~BotName~token~skillId~spellId~itemId~ERR~MOVING
PROFESSION_RECIPE_CRAFT~BotName~token~skillId~spellId~itemId~ERR~NO_MATERIALS
```

The addon displays localized messages for known bridge reasons.

For cooking recipes, `REQUIRES_SPELL_FOCUS` usually means the bot must be near a cooking fire.

</details>

---

# Repository Layout

```text
mod-multibot-bridge/
├── conf/
│   └── MultiBotBridge.conf.dist
└── src/
    ├── MultiBotBridge.cpp
    └── mod_multibot_bridge.cpp
```

---

# Related Repositories

<table>
  <tr>
    <th>Repository</th>
    <th>Description</th>
  </tr>
  <tr>
    <td>
      <a href="https://github.com/Wishmaster117/MultiBot-Chatless">
        MultiBot-Chatless
      </a>
    </td>
    <td>
      Client-side World of Warcraft addon using the bridge-first UI refresh path.
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://github.com/Wishmaster117/mod-multibot-bridge">
        mod-multibot-bridge
      </a>
    </td>
    <td>
      AzerothCore server-side bridge module.
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://github.com/Wishmaster117/MultiBot-Standalone">
        MultiBot-Standalone
      </a>
    </td>
    <td>
      Deprecated combined repository kept for history.
    </td>
  </tr>
  <tr>
    <td>
      <a href="https://github.com/mod-playerbots/mod-playerbots">
        mod-playerbots
      </a>
    </td>
    <td>
      Original AzerothCore Playerbots module required for bot functionality.
    </td>
  </tr>
</table>

---

# Notes for Developers

This module is intentionally focused on exposing structured data to the addon.

Design goals:

- Keep the addon UI refresh paths independent from localized chat parsing.
- Preserve manual playerbot commands for diagnostics and gameplay.
- Keep the bridge protocol stable enough for addon-side consumers.
- Avoid unnecessary server-side behavior changes outside the bridge.
- Keep the module installable as a normal AzerothCore module.
- Keep formation operations inside the bridge by using the existing Playerbots `FormationValue` API; no modification of `mod-playerbots` is required.

---

# Credits

Built for use with AzerothCore `mod-playerbots` and the MultiBot addon ecosystem.

Thanks to the Playerbots team and the AzerothCore community.

---

<div align="center">

## mod-multibot-bridge

<strong>Structured server data for a cleaner, mostly chatless MultiBot UI.</strong>

<br><br>

<a href="https://github.com/Wishmaster117/mod-multibot-bridge">
  Bridge Module
</a>
&nbsp;•&nbsp;
<a href="https://github.com/Wishmaster117/MultiBot-Chatless">
  Client Addon
</a>

</div>
