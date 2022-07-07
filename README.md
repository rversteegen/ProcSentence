ProcSentence (ProcSen)
======================

ProcSentence is a simple but powerful library for procedurally generating grammatical English (for now) text from a list of text fragments, Noun objects, special tokens and random choice lists. It's designed to be easy to use for dynamic or procedural content, as in roguelikes (used in five so far.) Being small, it can be quickly ported to new languages.

```
sentence(["the", entity1, "^offers", "the", entity2, entity1, "'s", item, ".",
          "the", entity2, "^accepts", "the", item])
	-> "Joules offers you his cash.  You accept it."
	-> "Joules offers the shopkeeper his car keys.  The shopkeeper accepts them."
	-> "You offer the vending machine your banknote.  The machine accepts the note."
```

It has so far been ported to (these versions are not in sync with each other):
* GDScript (for [Godot](https://godotengine.org))
  * The most full-featured version
  * Used in [Slumber](https://seilburg.itch.io/slumber) (2019 7DRL), [Portlligat](https://seilburg.itch.io/portlligat) (unreleased 2020 7DRL), [BattleTier Ascend!](https://voxelate.itch.io/battletier-ascend) (2021 7DRL)
* Python 2
  * Long out-of-date
  * Used in Geiger AD '42 (2011 7DRL)
* Preprocessed HamsterSpeak (for the [OHRRPGCE](https://rpg.hamsterrepublic.com/ohrrpgce/))
  * Long out-of-date
  * Used in [Carcere Vicis](https://www.slimesalad.com/forum/viewgame.php?p=105547)
  * Can't be used as-is; some accomplishing scripts aren't included, and currently requires use of the [HamsterSpeak pre-processor](https://github.com/rversteegen/ohrrpgce/blob/hspp/hspp.exw). In future will be ported to standard HamsterSpeak once HS gains necessary features.
