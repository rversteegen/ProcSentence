#!/usr/bin/env python3

"""
Use (NLTK interface to) WordNet to check the predicted first-person
conjugation of all verbs in a word list for any exceptions according to
ProcSen's rules. This prints plenty of false exceptions because WordNet's
morphy() is actually very dumb and WordNet doesn't list inflected word forms
except exceptions.
"""

try:
    raise None
    from nltk.corpus import wordnet as wn
except:
    wn = None

words = set(x.rstrip() for x in open("/usr/share/dict/words").readlines())
print(f"Read {len(words)} words")

for word in words:
    if word[-1] != "s": continue
    if word.endswith("ings") or word.endswith("ss") or word.endswith("ous"): continue

    if word[-3:] in ["oes", "xes"] or word[-4:] in ["ches", "shes", "sses", "zzes", "tzes"]:
        predict = word[:-2]
        alt = word[:-1]
    elif word.endswith("ies"):
        predict = word[:-3] + "y"
        alt = word[:-1]
    elif word.endswith("es"):
        predict = word[:-1]
        alt = word[:-2]
    else:
        predict = word[:-1]
        alt = ""

    if wn:
        actual = wn.morphy(word, 'v')
        if predict == actual or actual == None:
            continue
        if predict == wn.morphy(word, 'n'):
            # This looks like a plural form of a noun rather than a verb
            #print(word, " noun ", wn.morphy(word, 'n'), " verb ", actual)
            continue

        print(word, " predicted ", predict, " actual ", actual, "(ALT)" if alt == actual else "(BAD ALT)")

    else:
        # Just see whether the prediction is a real word.
        # If the wordlist includes nouns there are a huge number of false warnings.

        if predict in words and alt in words:
            print(word, " : AMBIGUOUS, have", predict)
        elif predict not in words:
            if alt not in words:
                alt = "UNKNOWN"
            print(word, ": ", alt)


