#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
install_quest_matrix.py -- installs the Quest-Matrix / Quest-Info client into the MultiBot addon.

Idempotent and upgradeable: safe to run again, e.g. after a MultiBot update overwrote the patches. Every block this
script inserts into an addon file is fenced with "-- [QuestMatrix begin]" / "-- [QuestMatrix end]" comments, so a
re-run removes the old blocks and writes the current ones.

What it does
  1. copies MultiBotQuestMatrixFrame.lua and MultiBotQuestInfo.lua next to the addon's other UI files (UI/)
  2. Core/MultiBotComm.lua     : reads the QUEST_MATRIX_V1 / QUEST_INFO_V1 capabilities, routes the QM_*, QI_*, QP_*,
                                 QUEST_GIVE_RESULT and QUEST_TURNIN_RESULT packets and the ERR packets of our requests
  3. UI/MultiBotQuestsMenu.lua : the "Quest matrix" button in the quests menu
  4. MultiBot.toc              : loads the new files
  5. AzerothAdmin (optional)   : its chat-link handler turned every plain click on a quest link into
                                 ".quest add <id>:<level>" (fails with the ":level", and hides any quest popup). The plain
                                 quest-link branch is removed; its explicit [Add]/[Remove] links keep working.

Usage:
    python install_quest_matrix.py
    python install_quest_matrix.py --addon-dir "D:/WoW3.3.5a/Interface/AddOns/MultiBot"

Each patched file gets a one-time "<file>.pre-quest-matrix" backup next to it.
"""

import argparse
import os
import re
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
PANELS = ["MultiBotQuestMatrixFrame.lua", "MultiBotQuestInfo.lua"]
BS = chr(92)  # backslash, spelled out so no escaping surprises
BEGIN = "-- [QuestMatrix begin]"
END = "-- [QuestMatrix end]"
FENCED = re.compile(r"[ \t]*-- \[QuestMatrix begin\][^\n]*\n.*?[ \t]*-- \[QuestMatrix end\]\n", re.S)


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    return raw.replace("\r\n", "\n"), "\r\n" in raw


def save(path, text, crlf):
    if crlf:
        text = text.replace("\n", "\r\n")
    open(path, "wb").write(text.encode("utf-8"))


def backup_once(path):
    bak = path + ".pre-quest-matrix"
    if not os.path.exists(bak):
        shutil.copy2(path, bak)


def insert(text, anchor, new, before):
    if text.count(anchor) != 1:
        raise SystemExit("anchor not found exactly once (addon version changed?):\n  " + anchor.strip())
    return text.replace(anchor, (new + anchor) if before else (anchor + new))


def fenced(body, indent=""):
    return indent + BEGIN + "\n" + body + indent + END + "\n"


# ---- the first version of this installer inserted unfenced blocks; remove exactly those ------------------------------
V1_BLOCKS = [
    'local QUEST_MATRIX_CAPABILITY = "QUEST_MATRIX_V1"\n',
    '    state.questMatrixCapable = false\n',
    '      elseif capability == QUEST_MATRIX_CAPABILITY then\n        state.questMatrixCapable = true\n',
    (
        '  if opcode == "QM_BEGIN" or opcode == "QM_MEMBER" or opcode == "QM_ROW" or opcode == "QM_END"'
        ' or opcode == "QUEST_GIVE_RESULT" then\n'
        '    state.connected = true\n'
        '    state.lastError = nil\n'
        '    if MultiBot.QuestMatrix and MultiBot.QuestMatrix.OnPacket then\n'
        '      MultiBot.QuestMatrix.OnPacket(opcode, payload)\n'
        '    end\n'
        '    return true\n'
        '  end\n\n'
    ),
    (
        '        elseif (requestType == "QUEST_MATRIX" or requestType == "QUEST_GIVE")'
        ' and MultiBot.QuestMatrix and MultiBot.QuestMatrix.OnError then\n'
        '          MultiBot.QuestMatrix.OnError(requestType, token, reason)\n'
    ),
]


def patch_comm(addon):
    path = os.path.join(addon, "Core", "MultiBotComm.lua")
    text, crlf = load(path)
    original = text

    for block in V1_BLOCKS:
        text = text.replace(block, "")
    text = FENCED.sub("", text)

    text = insert(text, 'local ENCHANT_TRADE_CAPABILITY = "ENCHANT_TRADE_V1"\n', fenced(
        'local QUEST_MATRIX_CAPABILITY = "QUEST_MATRIX_V1"\n'
        'local QUEST_INFO_CAPABILITY = "QUEST_INFO_V1"\n'), before=False)

    text = insert(text, '    state.enchantTradeCapable = false\n', fenced(
        '    state.questMatrixCapable = false\n'
        '    state.questInfoCapable = false\n', "    "), before=False)

    text = insert(text, '        state.enchantTradeCapable = true\n', fenced(
        '      elseif capability == QUEST_MATRIX_CAPABILITY then\n'
        '        state.questMatrixCapable = true\n'
        '      elseif capability == QUEST_INFO_CAPABILITY then\n'
        '        state.questInfoCapable = true\n', "      "), before=False)

    dispatch = fenced(
        '  if opcode == "QM_BEGIN" or opcode == "QM_MEMBER" or opcode == "QM_ROW" or opcode == "QM_END"'
        ' or opcode == "QUEST_GIVE_RESULT" or opcode == "QUEST_TURNIN_RESULT" then\n'
        '    state.connected = true\n'
        '    state.lastError = nil\n'
        '    if MultiBot.QuestMatrix and MultiBot.QuestMatrix.OnPacket then\n'
        '      MultiBot.QuestMatrix.OnPacket(opcode, payload)\n'
        '    end\n'
        '    return true\n'
        '  end\n'
        '\n'
        '  if string.sub(opcode, 1, 3) == "QI_" or string.sub(opcode, 1, 3) == "QP_" then\n'
        '    state.connected = true\n'
        '    state.lastError = nil\n'
        '    if MultiBot.QuestInfo and MultiBot.QuestInfo.OnPacket then\n'
        '      MultiBot.QuestInfo.OnPacket(opcode, payload)\n'
        '    end\n'
        '    return true\n'
        '  end\n', "  ")
    text = insert(text, '  if opcode == "QUESTS_BEGIN" then\n', dispatch, before=True)

    err = fenced(
        '        elseif (requestType == "QUEST_MATRIX" or requestType == "QUEST_GIVE" or requestType == "QUEST_TURNIN")'
        ' and MultiBot.QuestMatrix and MultiBot.QuestMatrix.OnError then\n'
        '          MultiBot.QuestMatrix.OnError(requestType, token, reason)\n'
        '        elseif (requestType == "QUEST_INFO" or requestType == "QUEST_PROGRESS")'
        ' and MultiBot.QuestInfo and MultiBot.QuestInfo.OnError then\n'
        '          MultiBot.QuestInfo.OnError(requestType, token, reason)\n', "        ")
    text = insert(text, '        elseif (requestType == "STATE" or requestType == "STATES") and state.stateRequests[token] then\n',
                  err, before=True)

    if text == original:
        print("  Core/MultiBotComm.lua: up to date")
        return
    backup_once(path)
    save(path, text, crlf)
    print("  Core/MultiBotComm.lua: patched")


def patch_menu(addon):
    path = os.path.join(addon, "UI", "MultiBotQuestsMenu.lua")
    text, crlf = load(path)
    if "BotQuestMatrix" in text:
        print("  UI/MultiBotQuestsMenu.lua: already patched")
        return

    button = (
        '    local matrixTip = (GetLocale() == "deDE") and "Quest-Matrix (alle Quests der Party, Bots direkt beauftragen)"'
        ' or "Quest matrix (all party quests, give quests to bots directly)"\n'
        '    local matrixButton = menu.addButton("BotQuestMatrix", 0, 180, "Interface/Icons/INV_Misc_Note_01", matrixTip)\n'
        '    matrixButton.doLeft = function()\n'
        '        if MultiBot.QuestMatrix and MultiBot.QuestMatrix.Toggle then\n'
        '            MultiBot.QuestMatrix.Toggle()\n'
        '        end\n'
        '    end\n'
        '    tRight.buttons["BotQuestMatrix"] = matrixButton\n\n'
    )
    text = insert(text, '    local gobButton = menu.addButton("BotUseGOB", 0, 150', button, before=True)

    backup_once(path)
    save(path, text, crlf)
    print("  UI/MultiBotQuestsMenu.lua: patched")


def patch_toc(addon):
    path = os.path.join(addon, "MultiBot.toc")
    text, crlf = load(path)
    changed = False

    menu_line = "UI" + BS + "MultiBotQuestsMenu.lua\n"
    for panel in PANELS:
        line = "UI" + BS + panel + "\n"
        if line in text:
            continue
        text = insert(text, menu_line, line, before=False)
        changed = True

    if not changed:
        print("  MultiBot.toc: already patched")
        return
    backup_once(path)
    save(path, text, crlf)
    print("  MultiBot.toc: patched")


def patch_azerothadmin(addons_dir):
    path = os.path.join(addons_dir, "AzerothAdmin", "Modules", "Linkifier.lua")
    if not os.path.isfile(path):
        print("  AzerothAdmin: not installed, skipped")
        return

    text, crlf = load(path)
    if BEGIN in text:
        print("  AzerothAdmin/Modules/Linkifier.lua: already patched")
        return

    old = (
        '  elseif ( strsub(link, 1, 5) == "quest" ) then\n'
        '    SendChatMessage(".quest add "..strsub(link, 7), say, nil, nil)\n'
        '    return;\n'
    )
    new = fenced(
        '  -- plain quest links are no longer turned into ".quest add <id>:<level>" (the ":level" made it fail and it hid\n'
        '  -- the quest popup). The explicit [Add] / [Remove] links (lookupquestadd / lookupquestrem) below still work.\n')
    if text.count(old) != 1:
        raise SystemExit("AzerothAdmin quest-link branch not found exactly once (version changed?)")
    text = text.replace(old, new)

    backup_once(path)
    save(path, text, crlf)
    print("  AzerothAdmin/Modules/Linkifier.lua: plain quest-link hijack removed")


def main():
    ap = argparse.ArgumentParser(description="Install the Quest-Matrix / Quest-Info client into MultiBot")
    ap.add_argument("--addon-dir", default="D:/WoW3.3.5a/Interface/AddOns/MultiBot")
    ap.add_argument("--no-azerothadmin", action="store_true", help="leave the AzerothAdmin addon alone")
    args = ap.parse_args()

    addon = args.addon_dir
    if not os.path.isfile(os.path.join(addon, "MultiBot.toc")):
        raise SystemExit("not a MultiBot addon dir: " + addon)

    print("Installing Quest-Matrix / Quest-Info into " + addon)
    for panel in PANELS:
        shutil.copy2(os.path.join(HERE, panel), os.path.join(addon, "UI", panel))
        print("  UI/" + panel + ": copied")

    patch_comm(addon)
    patch_menu(addon)
    patch_toc(addon)
    if not args.no_azerothadmin:
        patch_azerothadmin(os.path.dirname(os.path.abspath(addon)))
    print("Done. Restart the WoW client (or /reload) to load it.")


if __name__ == "__main__":
    main()
