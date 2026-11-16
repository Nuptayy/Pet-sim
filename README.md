# Egg Opening Simulator (WIP)

*No official name yet, I'll find one someday.*

A small incremental game made with **Godot 4.6** where you open eggs to get pets. Equipped pets give you bonuses, bonuses let you open more eggs faster, and so on. Basically my own take on all those "simulator" games you find on Roblox.

It's a personal project, I'm the only one working on it, and it's not meant to be sold. I'm not a pro dev, so don't expect perfect code, I'm learning as I go.

## What's in the game right now

- **Eggs** : open 1, open max, or auto-open. Each egg has its own pet pool and drop chances.
- **Pets** : every pet has a rarity and a type (Classic, Golden, Rainbow, Glitch, Virus). Rarer types have a shader effect and better stats.
- **Team** : equip pets to boost your coins/s, gems/s and luck.
- **Fusion** : 10 pets of the same type make 1 pet of the next type.
- **Index** : keeps track of every pet you discovered, with rewards when you complete an egg.
- **Gem shop** : permanent upgrades (team slots, hatch amount, hatch speed, luck, coin multiplier, inventory size, offline rewards).
- **Auto-delete** : pick which rarities/types get deleted automatically when hatched.
- **Offline rewards** : once unlocked, the game keeps hatching while it's closed.
- **Stats page, options, pause menu**, the usual stuff.

## Content

| Egg | Cost | Pets (common → secret) |
| --- | --- | --- |
| Basic Egg | 10 coins | Cat, Rabbit, Bee, Fox, Phoenix, Dragon, + 1 secret |
| Mystic Egg | 2,500 coins | Owl, Wolf, Golem, Unicorn, Griffin, Hydra, + 1 secret |

Only Cat, Rabbit and Bee have a real 3D model so far. Every other pet uses the egg model as a placeholder until I make (or find) proper ones. All the numbers live in `Scripts/GameConfig.gd` if you want to mess with the balancing.

## Controls (PC)

| Key | Action |
| --- | --- |
| `E` | Open 1 egg |
| `R` | Open the max amount of eggs |
| `T` | Toggle auto-open |
| `F` | Open / close the inventory |
| `Esc` | Pause menu |

No touch controls yet, so it's keyboard only for the moment.

There's also a debug menu on the `²` key (give coins/gems/pets, reset stuff, negative amounts remove currency). It's open to everyone on purpose while the game is still a test build.

## Running it

1. Install [Godot 4.6](https://godotengine.org/download) (standard version, no .NET needed).
2. Clone the repo and open `project.godot` in the editor.
3. Press F5.

Builds are not stored in the repo anymore. When there's something worth sharing I'll put it in the GitHub Releases.

## Known issues

The game is playable but far from clean. A full audit was done recently and the worst gameplay bugs are fixed now (unequipping pets, "Fuse All" breaking the team, the empty screen when auto-open ran out of coins, saves getting corrupted on a crash). What's still not great:

- the UI is only made for 1920x1080 landscape, portrait is unusable
- no touch controls at all
- saves are plain local files, so they're easy to edit
- most pets still use a placeholder model

## Roadmap

Roughly in this order:

1. ~~**Bug fixes** on the current local version.~~ Done.
2. ~~**Code cleanup** so the game logic is separated from the UI (needed for the server part).~~ Done, every player action now goes through a `Backend` layer (local for now).
3. **Responsive UI + mobile** : landscape and portrait, touch controls, Android build. *(on hold for now)*
4. **Authoritative server** : pet rolls and saves handled by a server (Python / FastAPI + PostgreSQL on a self-hosted Ubuntu VM) so nothing can be cheated or lost client-side. *(on hold too, everything stays local until I have the server back)*
5. **Actual content** : real pets, more eggs, balancing. *(in progress: second egg and named pets are in, 3D models still missing)*

## Project layout

```
Assets/    3D models and textures
Scenes/    Godot scenes (.tscn)
Scripts/   GDScript (.gd)
Shaders/   pet type effects (.gdshader)
style/     UI style resources
```

## Contributing

I would love your help! Contribute by forking the repo and opening pull requests.
