#class_name ProcSen
# In order to autoload this script it instead needs to extend Node
extends Node


# The context has just one purpose: if a noun is in the context then
# ["a", noun] becomes "the noun" (i.e. only when "a" is explicitly given).
# It doesn't cause the noun to immediately be referred to with a pronoun.
# (TODO: but perhaps could cause shortnames to be immediately used)

# FIXME: ProcSen shouldn't be a singleton, because it has this state?
var context := []

func add_context(item):
	if context.size() > 3:
		context.pop_front()
	context.append(item)

func wipe_context():
	context = []

class Noun:
	var unique = false         # Proper noun? If true, never use "a" or "the"
	var always_plural = false  # E.g. if .name == "Pills"
	var name = "thing"
	var pronoun = "it"         # "he", "she", "they" or "it" (subjective case)
	var shortname = ""         # If the pronoun can't be used, this is used instead if unique
	var modifier = ""          # Added to name, e.g. "green". Also added to shortname if not otherwise unique
	#var firstperson = false


	func get_name() -> String:
		var ret = self.name
		if not self.unique and self.modifier:
			ret = self.modifier + " " + ret
		return ret

	func get_pronoun() -> String:
		if self.always_plural and self.pronoun == "it":
			return "them"
		return self.pronoun

	func _to_string() -> String:
		return self.get_name()

func pluralise(string : String) -> String:
	if string.ends_with("s"):
		return string + "es"
	else:
		return string + "s"

func possessivise(string : String) -> String:
	"?!?"
	if string == "you":
		return "your"
	elif string == "it":
		return "its"
	elif string.ends_with("s"):
		return string + "'"
	else:
		return string + "'s"

func first_personise(string : String) -> String:
	"""Convert a verb's inflection from third to first person. Must be in third-person,
	but can be in any tense. If not present tense (doesn't end in "s") does nothing."""
	if string == "is":
		return "are"
	elif string == "isn't":
		return "aren't"
	elif string == "has":
		return "have"
	elif string.ends_with("ies"):
		# E.g. flies, readies
		if string in ["belies", "birdies", "dies", "lies", "ties", "underlies", "unties", "vies"]:
			return string.trim_suffix("s")
		else:
			return string.trim_suffix("ies") + "y"
	elif string.right(3) in ["oes", "xes"] or string.right(4) in ["ches", "shes", "sses", "tzes", "zzes"]:
		# E.g. goes, mixes, launches, bashes, misses, waltzes, buzzes
		if string in ["axes", "aches", "avalanches", "caches", "canoes", "hoes", "shoes", "toes"]:
			return string.trim_suffix("s")
		elif string in ["gasses", "degasses", "outgasses"]:
			return string.trim_suffix("ses")
		elif string in ["quizzes", "whizzes"]:
			return string.trim_suffix("zes")
		else:
			return string.trim_suffix("es")
	elif string.ends_with("s"):
		# E.g. bathes
		if string in ["aliases", "biases", "canvases", "choruses", "focuses"]:
			return string.trim_suffix("es")
		else:
			return string.trim_suffix("s")
	return string

func a_or_an(phrase):
	if phrase.left(1).to_lower() in "aeiou":
		return "an " + phrase
	else:
		return "a " + phrase

class GrammarState:
	var possess = false
	var capitalise = false
	var put_the = false
	var pluralise = false
	var firstperson = false
	var put_a = false

class HIDE_NUM:
	"Wrapper used to not output a number, but only use it for plurisation."
	var value
	func _init(_value):
		value = _value

func strend(string : String, length=1) -> String:
	if len(string) <= length:
		return string
	return string.right(len(string) - length)

func ord(chr : String) -> int:
	"Replacement for Godot 3 ord()"
	return chr.unicode_at(0)

func isalnum(chr : String) -> bool:
	var o = ord(chr)
	return (o >= ord("a") and o <= ord("z")) or (o >= ord("A") and o <= ord("Z")) or (o >= ord("0") and o <= ord("9"))

func simple_capitalize(phrase : String) -> String:
	return phrase.left(1).capitalize() + phrase.substr(1)


class NameTracker:
	# Assigned name for a Noun, also used to track which Nouns have already been mentioned.
	var name_for_noun : Dictionary  # Noun -> name
	# All possible names including ambiguous ones.
	var possible_names : Dictionary # name -> Noun, or null to mark ambiguous

	func _consider_name(noun : Noun, name : String):
		"Internal. If 'name' is unambiguous, set it as the name to use for 'noun'."
		if name == "":
			return null
		if name in possible_names and possible_names[name] != noun:
			# Multiple nouns share the same name, so don't use that name. (If the name was already
			# used earlier that's alright, but it's now become ambiguous.)  It may actually be
			# unambiguous if e.g. it were known that one noun is the subject and the other the object of
			# the current verb, but that's difficult and may sound awkward.
			possible_names[name] = null
			return
		possible_names[name] = noun
		name_for_noun[noun] = name

	func select_name(noun : Noun) -> String:
		"""Pick a name (noun phrase or pronoun) to use to refer to an instance of 'noun',
		ensuring each name is only used for one unambiguous thing per form() call.
		"""

		var mentioned = (noun in name_for_noun)
		# name_for_noun will be modified by the following.
		# Consider names in decreasing order of specificity (length) to find the simplest.
		# However need to consider all the valid ways to refer to it to check whether
		# any are ambiguous, to mark that those shouldn't be used in the sequel.

		_consider_name(noun, noun.get_name())  # Usually modifier + name
		_consider_name(noun, noun.name)
		if noun.modifier and noun.shortname:
			_consider_name(noun, noun.modifier + " " + noun.shortname)
		_consider_name(noun, noun.shortname)
		_consider_name(noun, noun.get_pronoun())

		if mentioned:
			return name_for_noun[noun]
		else:
			return noun.get_name()


func form(parts, add_period = false):
	"""Form a message from a list of free form strings (if prepended with ^, the first
	word is taken as a verb in third person), numbers or HIDE_NUM(number) wrappers
	(causes pluralisation of following word), keywords (strings), and Noun objects. Any word
	after a number is assumed to be a noun and subject to pluralisation.

	keywords are: "'s", "a", "the" (hint to produce 'the' instead of 'a' for following noun)

	If the first element of 'parts' is false, the string is not capitalised.

	Examples:
	form("the", entity, "^is shot through by", bolts.count, "bolt of energy.", entity, "^is mortally wounded!")
	-> "You are shot through by a bolt of energy. You are mortally wounded!"
	-> "The three-armed ape is shot through by 3 bolts of energy. It is mortally wounded!"

	form("the", entity, "'s", weapon, "explodes as", entity, "^fires it!")
	-> "Your rifle explodes as you fire it!"
	-> "The chemist's Laser Lv-02 explodes as he fires it!"

	form("a", item)
	-> "An eight-sided coin"
	"""

	var ret = ""

	var names = NameTracker.new()
	var cur = GrammarState.new()
	cur.capitalise = true
	if len(parts) > 0 and parts[0] in [false]:
		cur.capitalise = false
		parts.pop_front()
	var i = 0
	#for i, part in enumerate(parts):
	while i < len(parts):
		var part = parts[i]
		#print("part: ", part, " cap: ", cur.capitalise)
		var nexttok = parts[i + 1] if i+1 < len(parts) else null
		var next := GrammarState.new()
		var phrase := ""

		while part is Array:
			# Pick randomly
			part = part[randi() % part.size()]

		if part == null or (part is String and part == ""):   # fixme: doesn't seem to skip ""
			i += 1 # skip
			continue

		if part is Object:
			var n = part.get("noun")
			if n:
				part = n

		if part is int or part is HIDE_NUM:
			var val
			if part is int:
				val = part
			else:
				val = part.value
			if val == 1:
				phrase = "a"
			else:
				phrase = str(val) if val != 0 else "no"
				next.pluralise = true
			if part is HIDE_NUM:
				phrase = ""

		elif part is Noun:

			phrase = names.select_name(part)
			if phrase == part.get_pronoun():
				cur.put_the = false
				cur.put_a = false
			else:
				if not part.unique:
					if part in context:
						if cur.put_a:
							cur.put_a = false
							cur.put_the = true
					if cur.put_a:
						if part.always_plural:
							# lots/some can be applied to both countable and uncountable nouns
							if cur.pluralise:
								phrase = "lots of " + phrase
							else:
								phrase = "some " + phrase
						else:
							phrase = a_or_an(phrase)
					elif cur.put_the:  # and not part.proper_noun:
						phrase = "the " + phrase
				cur.put_the = false
				cur.put_a = false

			if phrase == "you":
				next.firstperson = true
			if nexttok is String and nexttok.begins_with("'s"):  #cur.possess:
				nexttok = nexttok.substr(3)  # trim "'s "
				parts[i + 1] = nexttok   # will be skipped if now empty
				#i += 1 #skip
				phrase = possessivise(phrase)
				next.put_a = false
			if cur.pluralise:
				phrase = pluralise(phrase)

			add_context(part)

		elif not part is String:
			phrase = str(part)

		# part is a String
		elif part.begins_with("^"):
			#verb
			var words = part.split(" ")
			for idx in range(words.size()):
				var word = words[idx]
				if word.begins_with("^"):
					word = word.substr(1)
					if cur.firstperson:
						var stripped = word.rstrip("!?.:;,\"'()/\\")
						var suffix = word.substr(stripped.length())
						word = first_personise(stripped) + suffix
					words[idx] = word
			phrase = " ".join(words)

		elif part == "'s":
			push_error("Found floating \"'s\" in args: " + str(parts))

		elif part == "a":
			next = cur
			cur = GrammarState.new()
			next.put_a = true

		elif part == "the":
			next = cur
			cur = GrammarState.new()
			next.put_the = true

		else:
			# other string
			phrase = part
			var words = phrase.split(" ")
			if cur.pluralise:
				words[0] = pluralise(words[0])
			phrase = " ".join(words)



		if cur.put_a:
			phrase = a_or_an(phrase)
		if cur.put_the:
			phrase = "the " + phrase
		if cur.capitalise:
			phrase = simple_capitalize(phrase)
			if phrase == "":
				next.capitalise = true
		if len(phrase) and phrase.rstrip(" ")[-1] in ".!?":
			next.capitalise = true

		# Auto add space (two spaces at end of a sentence) unless punctuation disallows it.
		# Maybe should automatically add a comma before a quote mark, but can be done manually.
		if (len(ret) and (isalnum(ret[-1]) or ret[-1] in ",;.'!?")) and phrase and not phrase[0] in ",;.!?":
			if ret[-1] in ".!?":
				ret += "  "
			else:
				ret += " "

		ret += phrase
		cur = next
		i += 1

	if add_period and len(ret):
		if not ret.rstrip(" ")[-1] in ".?!:;,":
			ret += ".  "
		elif not ret[-1] == " ":
			ret += "  "
	# elif ret[-1] in ".?!:;,":
	# 	ret += "  "

	return ret

func sentence(arr):
	return form(arr, true)

func end_sentence(string):
	if not string.rstrip(" ")[-1] in ".?!:;,":
		string += ".  "
	elif not string[-1] == " ":
		string += "  "
	return string


func test():
	var player = Noun.new()
	player.name = "you"
	player.pronoun = "you"
	player.unique = true
	#player.firstperson = true

	var James = Noun.new()
	James.name = "James"
	James.pronoun = "he"
	James.unique = true

	var weapon = Noun.new()
	weapon.name = "rifle"

	var entity = Noun.new()
	entity.name = "three-armed ape"
	entity.shortname = "ape"

	var entity2 = Noun.new()
	entity2.name = "ape"
	entity2.shortname = "ape"

	var entity3 = Noun.new()
	entity3.name = "ape"
	entity3.modifier = "battle-scarred"
	entity3.shortname = "ape"

	var ret
	var ans
	ret = form(["the", player, "^is shot through by", 1, "bolt of energy.", player, "^is mortally wounded!"])
	ans = "You are shot through by a bolt of energy.  You are mortally wounded!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", player, "^lunges but ^misses"])
	ans = "You lunge but miss"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["a", "image"])
	ans = "An image"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["a", "", "image"])
	ans = "An image"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["stop", ".", "a deer"])
	ans = "Stop.  A deer"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["You say", ",", "\"Hi.\""])
	ans = "You say, \"Hi.\""
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", entity, "^is shot through by", 3, "bolt of energy!", entity, "^is mortally wounded!"])
	ans = "The three-armed ape is shot through by 3 bolts of energy!  It is mortally wounded!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", player, "'s", weapon, "explodes as", player, "^fires it!"])
	ans = "Your rifle explodes as you fire it!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	# entity and weapon both have pronoun 'it'. Should use 'it' before weapon is introduced but not afterwards.
	ret = form(["the", player, "^whacks", "the", entity, "with", entity, "'s", "own", weapon, ".", player, "^breaks", "the", weapon])
	ans = "You whack the three-armed ape with its own rifle.  You break the rifle"
	if ret != ans: print( "Error! Got '" + ret + "'")

	wipe_context()
	ret = form(["a", entity, "^whacks", "a", entity2, ".", "a", entity, "^trips", "a", entity2])
	ans = "A three-armed ape whacks an ape.  The three-armed ape trips the ape"
	if ret != ans: print( "Error! Got '" + ret + "'")

	# Fails
	# Note: the subject of 'notice' is plural, but the transformation from 'notices' isn't handled by Sentence
	wipe_context()
	ret = form([player, "^sees", entity, ",", entity2, "and", entity3, ".", entity, ",", entity2, "and", entity3, "^notice", player])
	ans = "You see a three-armed ape, an ape and a battle-scarred ape.  The three-armed ape, the ape and the battle-scarred ape notice you"
	#if ret != ans: print( "Error! Got '" + ret + "'")

	var Bob = Noun.new()
	Bob.name = "Bob"
	Bob.pronoun = "he"
	Bob.unique = false

	var chemist = Noun.new()
	chemist.name = "chemist"
	chemist.pronoun = "he"
	chemist.unique = false

	weapon.name = "Laser Lv-02"
	weapon.shortname = "rifle"

	var weapon2 = Noun.new()
	weapon2.name = "rifle"
	#weapon2.shortname = "rifle"
	weapon2.modifier = "high-power"

	var weapon3 = Noun.new()
	weapon3.name = "Swiss Army knife"
	weapon3.shortname = "knife"

	ret = form(["the", chemist, "'s", weapon, "^explodes as", chemist, "^fires it!"])
	ans = "The chemist's Laser Lv-02 explodes as he fires it!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	# Should use short names
	ret = form([weapon2, "and", weapon3, "selected.", "Dropped", weapon2, "and", weapon3])
	ans = "High-power rifle and Swiss Army knife selected.  Dropped rifle and knife"
	if ret != ans: print( "Error! Got '" + ret + "'")

	# Shouldn't use short names for weapon/weapon2
	ret = form([weapon, ",", weapon2, "and", weapon3, "selected.", "Dropped", weapon, ",", weapon2, "and", weapon3])
	ans = "Laser Lv-02, high-power rifle and Swiss Army knife selected.  Dropped Laser Lv-02, high-power rifle and knife"
	if ret != ans: print( "Error! Got '" + ret + "'")

	var item = Noun.new()
	item.modifier = "eight-sided"
	item.name = "coin"

	ret = form(["a", item])
	ans = "An eight-sided coin"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", item])
	ans = "The eight-sided coin"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form([Bob, "and", player, "^argue over the", item, ".", Bob, "^punches", player])
	ans = "Bob and you argue over the eight-sided coin.  He punches you"
	if ret != ans: print( "Error! Got '" + ret + "'")

	# Fails
	ret = form([Bob, "and", player, "^argue over the", item, ".", player, "^punches", Bob])
	ans = "Bob and you argue over the eight-sided coin.  You punch him"
	#if ret != ans: print( "Error! Got '" + ret + "'")

	# Fails: uses "chemist" instead of "the chemist"
	ret = form([Bob, ",", chemist, "and", player, "^argue over the", item, ".", Bob, "^punches", chemist])
	ans = "Bob, the chemist and you argue over the eight-sided coin.  Bob punches the chemist"
	#if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form([Bob, "and", player, "^argue over the", item, ".", Bob, "^takes", item, "and", "^punches", player])
	ans = "Bob and you argue over the eight-sided coin.  He takes it and punches you"
	if ret != ans: print( "Error! Got '" + ret + "'")

	# Fails: "You take it and punches he"
	ret = form([Bob, "and", player, "^argue over the", item, ".", player, "^takes", item, "and", "^punches", Bob])
	ans = "Bob and you argue over the eight-sided coin.  You take it and punch him"
	#if ret != ans: print( "Error! Got '" + ret + "'")

	var machine = Noun.new()
	machine.name = "vending machine"
	machine.shortname = "machine"

	var coins = Noun.new()
	coins.name = "coins"
	coins.always_plural = true

	# Test always_plural -- since changes the pronoun to "them", can use "it" unambiguously for the machine
	ret = form(["the", player, "^offers", "the", machine, player, "'s", coins, ".", "the", machine, "^accepts", "the", coins])
	ans = "You offer the vending machine your coins.  It accepts them"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", player, "^offers", "the", machine, player, "'s", item, ".", "the", machine, "^accepts", "the", item])
	ans = "You offer the vending machine your eight-sided coin.  The machine accepts the coin"
	if ret != ans: print( "Error! Got '" + ret + "'")

	print( "tests done.")
