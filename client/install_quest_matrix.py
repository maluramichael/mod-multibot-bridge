#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
install_quest_matrix.py -- installs the Quest-Matrix client into the MultiBot addon.

What it does (idempotent: safe to run again, e.g. after a MultiBot update overwrote the patches):
  1. copies MultiBotQuestMatrixFrame.lua next to the addon's other UI files (UI/)
  2. Core/MultiBotComm.lua : advertises/reads the QUEST_MATRIX_V1 capability, routes the QM_* / QUEST_GIVE_RESULT
                             packets to MultiBot.QuestMatrix, forwards ERR packets of our two requests
  3. UI/MultiBotQuestsMenu.lua : adds the "Quest matrix" button to the quests menu
  4. MultiBot.toc          : loads the new file

Usage:
    python install_quest_matrix.py                       # default addon dir below
    python install_quest_matrix.py --addon-dir "D:/WoW3.3.5a/Interface/AddOns/MultiBot"

Each patched file gets a one-time "<file>.pre-quest-matrix" backup next to it.
"""

import argparse
import os
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PANEL = "MultiBotQuestMatrixFrame.lua"
BS = chr(92)  # backslash, spelled out so no escaping surprises


def load(path):
    raw = open(path, "rb").read().decode("utf-8")
    crlf = "\r\n" in raw
    return raw.replace("\r\n", "\n"), crlf


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


def patch_comm(addon):
    path = os.path.join(addon, "Core", "MultiBotComm.lua")
    text, crlf = load(path)
    if "QUEST_MATRIX_CAPABILITY" in text:
        print("  Core/MultiBotComm.lua: already patched")
        return

    text = insert(text, 'local ENCHANT_TRADE_CAPABILITY = "ENCHANT_TRADE_V1"\n',
                  'local QUEST_MATRIX_CAPABILITY = "QUEST_MATRIX_V1"\n', before=False)
    text = insert(text, '    state.enchantTradeCapable = false\n',
                  '    state.questMatrixCapable = false\n', before=False)
    text = insert(text, '        state.enchantTradeCapable = true\n',
                  '      elseif capability == QUEST_MATRIX_CAPABILITY then\n'
                  '        state.questMatrixCapable = true\n', before=False)

    dispatch = (
        '  if opcode == "QM_BEGIN" or opcode == "QM_MEMBER" or opcode == "QM_ROW" or opcode == "QM_END"'
        ' or opcode == "QUEST_GIVE_RESULT" then\n'
        '    state.connected = true\n'
        '    state.lastError = nil\n'
        '    if MultiBot.QuestMatrix and MultiBot.QuestMatrix.OnPacket then\n'
        '      MultiBot.QuestMatrix.OnPacket(opcode, payload)\n'
        '    end\n'
        '    return true\n'
        '  end\n\n'
    )
    text = insert(text, '  if opcode == "QUESTS_BEGIN" then\n', dispatch, before=True)

    err = (
        '        elseif (requestType == "QUEST_MATRIX" or requestType == "QUEST_GIVE")'
        ' and MultiBot.QuestMatrix and MultiBot.QuestMatrix.OnError then\n'
        '          MultiBot.QuestMatrix.OnError(requestType, token, reason)\n'
    )
    text = insert(text, '        elseif (requestType == "STATE" or requestType == "STATES") and state.stateRequests[token] then\n',
                  err, before=True)

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
    if PANEL in text:
        print("  MultiBot.toc: already patched")
        return

    menu_line = "UI" + BS + "MultiBotQuestsMenu.lua\n"
    panel_line = "UI" + BS + PANEL + "\n"
    text = insert(text, menu_line, panel_line, before=False)

    backup_once(path)
    save(path, text, crlf)
    print("  MultiBot.toc: patched")


def main():
    ap = argparse.ArgumentParser(description="Install the Quest-Matrix client into MultiBot")
    ap.add_argument("--addon-dir", default="D:/WoW3.3.5a/Interface/AddOns/MultiBot")
    args = ap.parse_args()

    addon = args.addon_dir
    if not os.path.isfile(os.path.join(addon, "MultiBot.toc")):
        raise SystemExit("not a MultiBot addon dir: " + addon)

    print("Installing Quest-Matrix into " + addon)
    shutil.copy2(os.path.join(HERE, PANEL), os.path.join(addon, "UI", PANEL))
    print("  UI/" + PANEL + ": copied")

    patch_comm(addon)
    patch_menu(addon)
    patch_toc(addon)
    print("Done. Restart the WoW client (or /reload) to load it.")


if __name__ == "__main__":
    main()
