extends Node
#class_name Sentence

var context = []


class Noun:
	#__metaclass__ = _MetaNoun
	var unique = false
	var always_plural = false  #e.g. "Pills"
	var name = ""
	var pronoun = "it"
	var modifier = ""
	#var firstperson = false


	func get_name():
		var ret = self.name
		if not self.unique and self.modifier:
			ret = self.modifier + " " + ret
		return ret

	func get_pronoun():
		if self.always_plural and self.pronoun == "it":
			return "them"
		return self.pronoun

	func _to_string():
		return self.get_name()

func pluralise(string):
	if string.ends_with("s"):
		return string + "es"
	else:
		return string + "s"

func possessivise(string):
	"?!?"
	if string == "you":
		return "your"
	elif string == "it":
		return "its"
	elif string.ends_with("s"):
		return string + "'"
	else:
		return string + "'s"

func first_personise(string):
	"special cases go here!"
	if string == "is":
		return "are"
	elif string == "has":
		return "have"
	elif string == "readies":
		return "ready"
	elif string.ends_with("es") and not string in ["takes", "consumes", "fires", "convulses", "dies", "struggles"]:
		return string.trim_suffix("es")
	elif string.ends_with("s"):
		return string.trim_suffix("s")
	return string

class GrammarState:
	var possess = false
	var capitalise = false
	var put_the = false
	var pluralise = false
	var firstperson = false
	var put_a = false

class HIDE_NUM:
	var value
	func _init(_value):
		value = _value

func strend(string, length=1):
	if len(string) <= length:
		return string
	return string.right(len(string) - length)

func isalnum(chr):
	var o = ord(chr)
	return (o >= ord("a") and o <= ord("z")) or (o >= ord("A") and o <= ord("Z")) or (o >= ord("0") and o <= ord("9"))

func simple_capitalize(phrase):
	return phrase.left(1).capitalize() + phrase.right(1)

func form(parts):

	# """Form a message from a list of free form strings (if prepended with ^, the first
	# word is taken as a verb in third person), numbers or HIDE_NUM(number) wrappers
	# (causes pluralisation of following word), keywords (strings), and Noun objects. Any word
	# after a number is assumed to be a noun and subject to pluralisation.

	# keywords are: "'s", "a", "the" (hint to produce 'the' instead of 'a' for following noun)

	# If the first argument is false, the string is not capitalised.

	# Examples:
	# form("the", entity, "^is shot through by", bolts.count, "bolt of energy.", entity, "^is mortally wounded!")
	# -> "You are shot through by a bolt of energy. You are mortally wounded!"
	# -> "The three-armed ape is shot through by 3 bolts of energy. It is mortally wounded!"

	# form("the", entity, "'s", weapon, "explodes as", entity, "^fires it!")
	# -> "Your rifle explodes as you fire it!"
	# -> "The chemist's Laser Lv-02 explodes as he fires it!"

	# form("a", item)
	# -> "An eight-sided coin"
	# """

	var mentioned = {} #set()
	var ret = ""

	var cur = GrammarState.new()
	cur.capitalise = true
	if len(parts) > 0 and parts[0] in [false]:
		cur.capitalise = false
		parts.pop_front()
	var i = 0
	#for i, part in enumerate(parts):
	while i < len(parts):
		var part = parts[i]
		print("part: ", part, " cap: ", cur.capitalise)
		var nexttok = parts[i + 1] if i+1 < len(parts) else null
		var next = GrammarState.new()
		var phrase = ""
		var first

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
			if part in mentioned:
				phrase = part.get_pronoun()
			else:
				phrase = part.get_name()
				mentioned[part] = true
				if not part.unique:
					if part in context:
						if cur.put_a:
							cur.put_a = false
							cur.put_the = true
					if cur.put_a:
						if part.always_plural:
							if cur.pluralise:
								phrase = "lots of " + phrase
							else:
								phrase = "some " + phrase
						elif phrase.left(1) in "aeiou":
							phrase = "an " + phrase
						else:
							phrase = "a " + phrase
					elif cur.put_the:  # and not part.proper_noun:
						phrase = "the " + phrase
				cur.put_the = false
				cur.put_a = false
					
			if phrase == "you":
				next.firstperson = true
			if nexttok == "'s":  #cur.possess:
				i += 1 #skip
				phrase = possessivise(phrase)
				next.put_a = false
			if cur.pluralise:
				phrase = pluralise(phrase)
			context.append(part)

		elif not part is String:
			phrase = str(part)

		# part is String
		elif part.begins_with("^"):
			#verb
			var words = part.split(" ")
			first = words[0].substr(1)
			if cur.firstperson:
				first = first_personise(first)
			words[0] = first
			phrase = words.join(" ")

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
			phrase = words.join(" ")



		if cur.put_a:
			phrase = "a " + phrase
		if cur.put_the:
			phrase = "the " + phrase
		if cur.capitalise:
			phrase = simple_capitalize(phrase)
			if phrase == "":
				next.capitalise = true
		if phrase.rstrip(" ").ends_with("."):
			next.capitalise = true
		#Auto add space
		if (len(ret) and (isalnum(strend(ret)) or strend(ret) in ".'!?")) and isalnum(phrase.left(1)):
			ret += " "
		ret += phrase
		cur = next
		i += 1
	return ret

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

	var ret
	var ans
	ret = form(["the", player, "^is shot through by", 1, "bolt of energy.", player, "^is mortally wounded!"])
	ans = "You are shot through by a bolt of energy. You are mortally wounded!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", entity, "^is shot through by", 3, "bolt of energy.", entity, "^is mortally wounded!"])
	ans = "The three-armed ape is shot through by 3 bolts of energy. It is mortally wounded!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", player, "'s", weapon, "explodes as", player, "^fires it!"])
	ans = "Your rifle explodes as you fire it!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	entity = Noun.new()
	entity.name = "chemist"
	entity.pronoun = "he"
	weapon.name = "Laser Lv-02"
	ret = form(["the", entity, "'s", weapon, "explodes as", entity, "^fires it!"])
	ans = "The chemist's Laser Lv-02 explodes as he fires it!"
	if ret != ans: print( "Error! Got '" + ret + "'")

	var item = Noun.new()
	item.name = "eight-sided coin"

	ret = form(["a", item])
	ans = "An eight-sided coin"
	if ret != ans: print( "Error! Got '" + ret + "'")

	ret = form(["the", item])
	ans = "The eight-sided coin"
	if ret != ans: print( "Error! Got '" + ret + "'")

	print( "tests done.")