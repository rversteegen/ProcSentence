#######################   SENTENCES ##########################################

class _MetaNoun(type):
    "Ignore me"
    def __str__(self):
        return self.__name__

class Noun(object):
    __metaclass__ = _MetaNoun
    unique = False
    always_plural = False  #e.g. "Pills"
    name = ""
    pronoun = "it"
    #firstperson = False

    def get_name(self):
        ret = self.name
        if not self.unique and hasattr(self, 'modifier'):
            ret = self.modifier + " " + ret
        return ret
    
    def get_pronoun(self):
        if self.always_plural and self.pronoun == "it":
            return "them"
        return self.pronoun

    def __str__(self):
        return self.get_name()

def pluralise(string):
    if string[-1:] == "s":
        return string + "es"
    else:
        return string + "s"

def possessivise(string):
    "?!?"
    if string == "you":
        return "your"
    elif string == "it":
        return "its"
    elif string[-1:] == "s":
        return string + "'"
    else:
        return string + "'s"

def first_personise(string):
    "special cases go here!"
    if string == "is":
        return "are"
    elif string == "has":
        return "have"
    elif string == "readies":
        return "ready"
    elif string[-2:] == "es" and string not in ("takes", "consumes", "fires", "convulses", "dies", "struggles"):
        return string[:-2]
    elif string[-1:] == "s":
        return string[:-1]
    return string

context = []

class GrammarState(object):
    possess = False
    capitalise = False
    put_the = False
    pluralise = False
    firstperson = False
    put_a = False

class HIDE_NUM(int):
    pass

def form_msg(*parts):
    global context

    """Form a message from a list of free form strings (if prepended with ^, the first
    word is taken as a verb in third person), numbers or HIDE_NUM(number) wrappers
    (causes pluralisation of following word), keywords (strings), and Noun objects. Any word
    after a number is assumed to be a noun and subject to pluralisation.

    keywords are: "'s", "a", "the" (hint to produce 'the' instead of 'a' for following noun)

    If the first argument is False, the string is not capitalised.

    Examples:
    form_msg("the", entity, "^is shot through by", bolts.count, "bolt of energy.", entity, "^is mortally wounded!")
    -> "You are shot through by a bolt of energy. You are mortally wounded!"
    -> "The three-armed ape is shot through by 3 bolts of energy. It is mortally wounded!"

    form_msg("the", entity, "'s", weapon, "explodes as", entity, "^fires it!")
    -> "Your rifle explodes as you fire it!"
    -> "The chemist's Laser Lv-02 explodes as he fires it!"

    form_msg("a", item)
    -> "An eight-sided coin"
    """

    mentioned = set()
    ret = ""

    cur = GrammarState()
    cur.capitalise = True
    if len(parts) > 0 and parts[0] is False:
        cur.capitalise = False
        parts = parts[1:]
    i = 0
    #for i, part in enumerate(parts):
    while i < len(parts):
        part = parts[i]
        #print "part:", repr(part)
        nexttok = parts[i + 1] if i+1 < len(parts) else None
        next = GrammarState()
        phrase = ""

        if isinstance(part, str) and part[0:1] == "^":
            #verb
            first = part.split()[0][1:]
            rest = part.split()[1:]
            if cur.firstperson:
                first = first_personise(first)
            phrase = " ".join([first] + rest)

        elif part == "'s":
            raise Exception("Found floating \"'s\" in args: " + str(parts))

        elif part == "a":
            next = cur
            cur = GrammarState()
            next.put_a = True

        elif part == "the":
            next = cur
            cur = GrammarState()
            next.put_the = True

        elif isinstance(part, str):
            # other string
            phrase = part
            first = phrase.split(" ")[0]
            rest = phrase.split(" ")[1:]
            if cur.pluralise:
                first = pluralise(first)
            phrase = " ".join([first] + rest)

        elif isinstance(part, int):
            if part == 1:
                phrase = "a"
            else:
                phrase = str(part) if part != 0 else "no"
                next.pluralise = True
            if isinstance(part, HIDE_NUM):
                phrase = ""

        elif isinstance(part, Noun):
            if part in mentioned:
                phrase = part.get_pronoun()
            else:
                phrase = part.get_name()
                mentioned.add(part)
                if not part.unique:
                    if part in context:
                        if cur.put_a:
                            cur.put_a = False
                            cur.put_the = True
                    if cur.put_a:
                        if part.always_plural:
                            if cur.pluralise:
                                phrase = "lots of " + phrase
                            else:
                                phrase = "some " + phrase
                        elif phrase[:1] in ("a", "e", "i", "o", "u"):
                            phrase = "an " + phrase
                        else:
                            phrase = "a " + phrase
                    elif cur.put_the:  # and not part.proper_noun:
                        phrase = "the " + phrase
                cur.put_the = False
                cur.put_a = False
                    
            if phrase == "you":
                next.firstperson = True
            if nexttok == "'s":  #cur.possess:
                i += 1 #skip
                phrase = possessivise(phrase)
                next.put_a = False
            if cur.pluralise:
                phrase = pluralise(phrase)
            context.append(part)

        else:
            phrase = str(part)

        if cur.put_a:
            phrase = "a " + phrase
        if cur.put_the:
            phrase = "the " + phrase
        if cur.capitalise:
            phrase = phrase.capitalize()
            if phrase == "":
                next.capitalise = True
        if phrase.rstrip()[-1:] == ".":
            next.capitalise = True
        #Auto add space
        if (ret[-1:].isalnum() or len(ret) and ret[-1:] in ".'!?") and phrase[0:1].isalnum():
            ret += " "
        #print "phrase '%s'" % phrase
        ret += phrase
        cur = next
        i += 1
    return ret

if __name__ == "__main__":
    player = Noun()
    player.name = player.pronoun = "you"
    player.unique = True
    #player.firstperson = True

    James = Noun()
    James.name = "James"
    James.pronoun = "he"
    James.unique = True

    weapon = Noun()
    weapon.name = "rifle"

    entity = Noun()
    entity.name = "three-armed ape"

    ret = form_msg("the", player, "^is shot through by", 1, "bolt of energy.", player, "^is mortally wounded!")
    ans = "You are shot through by a bolt of energy. You are mortally wounded!"
    if ret != ans: print "Error! Got '" + ret + "'"

    ret = form_msg("the", entity, "^is shot through by", 3, "bolt of energy.", entity, "^is mortally wounded!")
    ans = "The three-armed ape is shot through by 3 bolts of energy. It is mortally wounded!"
    if ret != ans: print "Error! Got '" + ret + "'"

    ret = form_msg("the", player, "'s", weapon, "explodes as", player, "^fires it!")
    ans = "Your rifle explodes as you fire it!"
    if ret != ans: print "Error! Got '" + ret + "'"

    entity = Noun()
    entity.name = "chemist"
    entity.pronoun = "he"
    weapon.name = "Laser Lv-02"
    ret = form_msg("the", entity, "'s", weapon, "explodes as", entity, "^fires it!")
    ans = "The chemist's Laser Lv-02 explodes as he fires it!"
    if ret != ans: print "Error! Got '" + ret + "'"

    item = Noun()
    item.name = "eight-sided coin"

    ret = form_msg("a", item)
    ans = "An eight-sided coin"
    if ret != ans: print "Error! Got '" + ret + "'"

    ret = form_msg("the", item)
    ans = "The eight-sided coin"
    if ret != ans: print "Error! Got '" + ret + "'"

    print "tests done."
