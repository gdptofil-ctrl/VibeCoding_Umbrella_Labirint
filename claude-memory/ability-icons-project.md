---
name: ability-icons-project
description: ability_icons.lua (2026-10-25) - client-side cosmetic ability icons via Panorama JS SetImage; not yet verified in game
metadata:
  node_type: memory
  type: project
  originSessionId: 6407b854-68aa-4757-b76b-2e5cacadb5f0
  modified: 2026-10-25T09:08:09.695Z
---

`ability_icons.lua` is one file now; its `local ICONS = { ... }` table is rewritten in place by `ability_icons_helper.py` (root) from items_game.txt
and the spellicons folder in pak01, reusing `engine3d/tools/find_sounds.py` VPK reader). Every 0.3 s it runs JS
that finds `lower_hud` -> `abilities` -> `AbilityImage` and calls `SetImage('file://{images}/spellicons/<mod>.png')`.

**Why:** user wanted cosmetic icons without owning/equipping the items.

**How to apply:** unverified in game as of 2026-10-25: panel ids, whether HUD resets the image (flicker), and
whether the `abilityname = ''` toggle restores the real icon. Ask the user for results before building on it.
See [[umbrella-script-style]].

2026-10-25: Dota crashed (0xC0000005 in client.dll via panorama.dll, Lua callback 0) exactly at OnGameEnd with the
script running. Suspected: the restore trick `img.abilityname = ''` and/or SetImage while the HUD tears down. Fixed by
dropping the '' toggle (restore = SetImage of the default icon), skipping empty names/invalid panels, and running only
in PRE_GAME/GAME_IN_PROGRESS and not after OnGameEnd. Not yet confirmed that the crash is gone.

2026-10-25 later: in game icons did NOT change. Cause found in docs: Engine.RunScript's contextPanel defaults to
"Dashboard", not the HUD. Now passes "Hud" and draws an own Image child `UmbAbilityIcon` inside AbilityImage
instead of SetImage on the HUD's panel. Prints one `[ability_icons] ... Hud/abilities/RunScript` line to debug.log
per hero for diagnosis. Still unverified in game.

2026-10-25: CONFIRMED working in game (Hud context + overlay Image). User wanted "Обычная" = hero's default icon
even with arcana equipped, so index 0 now overlays `spellicons/<ability>`; new last item "Как в игре" = no overlay
(kept last so saved indices don't shift). Abilities without a default file get `nodefault = true` in data.lua.

2026-10-25: added effect (particle) swapping. helper also writes `local EFFECTS = {hero_short = {{item, asset, mod, ...}}}`
from items_game "particle" asset_modifiers (paths without `particles/` and `.vpcf`). Runtime: OnParticleCreate for
own hero (entity_for_modifiers_id, else entity_id) -> Particle.Create(replacement) + SetShouldDraw(orig,false), mirror
CP updates, destroy on OnParticleDestroy. Any variant of an asset (from other sets the user wears) maps too.
Unverified in game: fullName format, whether econ particles load without precache, crash risk. Sounds not swapped.
In game: replacement particle DOES appear (counterspell), but the original stayed visible after a single
SetShouldDraw(orig,false) in OnParticleCreate. Now re-hidden every OnDraw and on each CP update while linked; result unknown.
2026-10-25: effects UI regrouped per ability (user hated reading item names). EFFECTS = {hero = {{group, {item, a, m, ...}, ...}}},
group = ability name matched by particle filename heuristic (helper `fx_group`), or #attack/#items/#other. NAMES table
(from abilities_russian.txt, names stay English there) shown via ForceLocalization on both icon and fx combos.
Whether the original counterspell is hidden now (OnDraw re-hide) was not reported yet.
2026-10-25: item icons added. ITEMS = {item_x = {default_tex, {variant, label}, ...}} from items.txt textures + panorama/images/items
variants matching arcana|_alt|_pw|_tinker (18 items, all hero-arcana/cosmetic driven; no items_game asset_modifier exists for items).
Item combos: index 0 "Как в игре" (no overlay), 1 "Обычная", then variants. JS also walks inventory_slot_0..8, tpscroll, neutral
-> ItemImage.itemname. Panel ids for inventory unverified in game.
2026-10-25: CONFIRMED in game: original counterspell hidden (OnDraw re-hide works), set particle drawn. Effect swap works.
2026-10-25: added WORLD table (helper: items without used_by_heroes, slots tool/teleport_effect/blink_effect -> tp/blink/fountain/items/misc
own-hero swaps; radianttowers/diretowers/tormentor -> any-owner swaps (fx.any, active from OnScriptsLoaded so map-load tower lamps
are caught); emblem/ancient/roshan particle_create (spawn_in_loadout_only != "1") -> ambient Particle.Create on hero /
npc_dota_goodguys_fort / npc_dota_roshan via NPCs.GetAll every 1 s). Preview: on combo change, modifiers spawned on hero for 3 s.
Random: "Случайно каждый матч" rolls all combos in build_for. All unverified in game (NPCs list containing buildings, clientside
tower particles hitting OnParticleCreate, ambient attach look).
In game towers did NOT change (lamps/attacks never reach OnParticleCreate) -> towers removed from helper and K.WORLD.
Preview of multi-effect packs made a mess on the hero -> PREVIEW_MAX 2, skip destruction/_death/error//dev/ paths.
