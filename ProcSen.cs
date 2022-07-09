using System;
using System.Collections;
using System.Collections.Generic;

namespace ProcSen
{
    public static class StringExtensions
    {
        //Stolen parts from https://kodify.net/csharp/strings/left-right-mid/
        public static string TrimSuffix(this string s, string suffix)
        {
            if (s.EndsWith(suffix))
            {
                return s.Substring(0, s.Length - suffix.Length);
            }
            else
            {
                return s;
            }
        }

        public static string Right(this string input, int count)
        {
            return input.Substring(Math.Max(input.Length - count, 0), Math.Min(count, input.Length));
        }

        public static string Left(this string input, int count)
        {
            return input.Substring(0, Math.Min(input.Length, count));
        }

    }

    public class ProcSen
    {
        private List<Object> context = new List<Object>();

        public List<object> Context { get => context; set => context = value; }

        public void AddContext(Object item)
        {

            if (Context.Count > 3) Context.RemoveAt(0);
            Context.Append(item);

        }
        public string strend(string str, int length = 1)
        {
            if (str.Length <= length)
            { return str; }
            return str.Right(str.Length - length);
        }

        public bool IsAlnum(char chr)
        {
            int o = (int)chr;
            return (o >= (int)'a' && o <= (int)'z') || (o >= (int)'A' && o <= (int)'Z') || (o >= (int)'0' && o <= (int)'9');
        }

        public bool IsAlnum(string chr)
        {
            int o = (int)chr[0];
            return (o >= (int)'a' && o <= (int)'z') || (o >= (int)'A' && o <= (int)'Z') || (o >= (int)'0' && o <= (int)'9');
        }

        public string SimpleCapitalize(string input) =>
            //https://stackoverflow.com/questions/4135317/make-first-letter-of-a-string-upper-case-with-maximum-performance
            input switch
            {
                null => throw new ArgumentNullException(nameof(input)),
                "" => input,
                _ => string.Concat(input[0].ToString().ToUpper(), input.AsSpan(1))
            };

        public string MaybeUsePronoun(Noun part, Dictionary<Object, Object> mentioned, Dictionary<Object, Object> usedPronouns)
        {

            if (!mentioned.ContainsKey(part))
            {
                return null;
            }

            string pronoun = part.GetPronoun();
            if (usedPronouns.ContainsKey(pronoun) && usedPronouns[pronoun] != part)
            {
                return null;
            }
            usedPronouns[pronoun] = part;
            return pronoun;

        }

        public string Form(List<Object> parts, bool addPeriod = false)
        {
            Dictionary<Object, Object> mentioned = new Dictionary<Object, Object>();
            Dictionary<Object, Object> usedPronouns = new Dictionary<Object, Object>();
            string ret = "";

            GrammarState cur = new GrammarState();
            cur.Capitalise = true;
            if (parts.Count > 0 && parts[0] is false)
            {
                cur.Capitalise = false;
                parts.RemoveAt(0);
            }

            int i = 0;

            while (i < parts.Count)
            {
                Object? part = parts[i];
                Object? nexttok = i + 1 < parts.Count ? parts[i + 1] : null;
                GrammarState next = new GrammarState();
                string phrase = "";

                while (part is Array) //when given an array of strings or other appropriate type
                {
                    Random rng = new Random();
                    Object[] partArray = (Object[])part;
                    part = partArray[rng.Next() % partArray.Length];
                }

                if (part is null || (part is string && (string)part == ""))
                {
                    i += 1;
                    continue;
                }

                if (part is Object)
                {
                    var n = part.GetType().GetProperty("noun");
                    if (n is not null)
                    {
                        part = n.GetValue(part);
                    }
                }

                if (part!.GetType() == typeof(int) || part is HIDE_NUM)
                {
                    int val = 0;
                    if (part.GetType() == typeof(int))
                    {
                        val = (int)part;
                    }
                    else if (part is HIDE_NUM)
                    {
                        HIDE_NUM hnPart = (HIDE_NUM)part;
                        val = hnPart.Value;
                    }

                    if (val == 1)
                    {
                        phrase = "a";
                    }
                    else
                    {
                        phrase = val != 0 ? val.ToString() : "no";
                        next.Pluralise = true;
                    }

                    if (part is HIDE_NUM) phrase = "";
                }
                else if (part is Noun)
                {
                    Noun partNoun = (Noun)part;
                    string pronoun = MaybeUsePronoun((Noun)part, mentioned, usedPronouns);
                    if (pronoun is not null)
                    {
                        phrase = pronoun;
                        cur.PutThe = false;
                        cur.PutA = false;
                    }
                    else
                    {
                        phrase = partNoun.GetName();
                        mentioned[part] = true;
                        if (!partNoun.Unique)
                        {
                            if (Context.Contains(part))
                            {
                                if (cur.PutA)
                                {
                                    cur.PutA = false;
                                    cur.PutThe = true;
                                }
                            }
                            if (cur.PutA)
                            {
                                if (partNoun.AlwaysPlural)
                                {
                                    if (cur.Pluralise)
                                    {
                                        phrase = "lots of " + phrase;
                                    }
                                    else
                                    {
                                        phrase = "some " + phrase;
                                    }
                                }
                                else
                                {
                                    phrase = Noun.AOrAn(phrase);
                                }
                            }
                            else if (cur.PutThe)
                            {
                                phrase = "the " + phrase;
                            }
                        }
                        cur.PutThe = false;
                        cur.PutA = false;
                    }
                    if (phrase == "you")
                    {
                        next.Firstperson = true;
                    }
                    if (nexttok is string)
                    {
                        string nexttokString = (string)nexttok;
                        if (nexttokString.StartsWith("'s"))
                        {
                            nexttok = "";
                            parts[i + 1] = nexttok;
                            phrase = Noun.Possessivise(phrase);
                            next.PutA = false;
                        }
                    }
                    if (cur.Pluralise) phrase = Noun.Pluralise(phrase);
                    AddContext(part);
                }

                else if (part is not string) phrase = (string)part;
                else if (part.ToString().StartsWith("^"))
                {

                    List<string> words = part.ToString().Split(" ").ToList();
                    for (int j = 0; j < words.Count; j++)
                    {
                        var word = words[j];
                        if (word[0] == '^')
                        {
                            word = word.Substring(1);
                            if (cur.Firstperson)
                            {
                                var stripped = word.TrimEnd("!?.:;,\"'()/\\".ToCharArray());
                                var suffix = word.Substring(stripped.Count());
                                word = Noun.FirstPersonise(stripped) + suffix;
                            }
                            words[j] = word;
                        }
                    }
                    phrase = String.Join(" ", words);
                }
                else if ((string)part == "'s")
                {
                    throw new Exception("Found floating \"'s\" in args: " + parts.ToString());
                }
                else if ((string)part == "a")
                {
                    next = cur;
                    cur = new GrammarState();
                    next.PutA = true;
                }
                else if ((string)part == "the")
                {
                    next = cur;
                    cur = new GrammarState();
                    next.PutThe = true;
                }
                else
                {
                    phrase = part.ToString();
                    var words = phrase.Split(" ");
                    if (cur.Pluralise)
                    {
                        words[0] = Noun.Pluralise(words[0]);
                    }
                    phrase = String.Join(" ", words);
                }


                if (cur.PutA) phrase = Noun.AOrAn(phrase);
                if (cur.PutThe) phrase = "the " + phrase;
                if (cur.Capitalise)
                {
                    phrase = SimpleCapitalize(phrase);
                    if (phrase == "")
                    {
                        next.Capitalise = true;
                    }
                }
                var phraseTest = phrase;
                if (phraseTest.TrimEnd(" ".ToCharArray()).EndsWith("."))
                {
                    phrase.TrimEnd(" ".ToCharArray());
                    next.Capitalise = true;
                }
                if (ret.Count() != 0)
                {
                    char[] symb = ",;.'!?".ToCharArray();
                    char match = ret[ret.Count() - 1];
                    //var leftOne = phrase.Left(1);
                    if ((IsAlnum(ret[ret.Count() - 1]) || (Array.Exists(symb, x => x == match))) && phrase is not null && IsAlnum(phrase.Left(1)))
                    {
                        symb = ".!?".ToCharArray();
                        if (Array.Exists(symb, x => x == ret[ret.Count() - 1]))
                        {
                            ret += "  "; //Double space
                        }
                        else
                        {
                            ret += " ";
                        }
                    }
                }
                ret += phrase;
                cur = next;
                i += 1;
            }
            if (addPeriod && ret.Count() != 0)
            {
                var match = ret.TrimEnd(" ".ToCharArray())[-1];
                char[] symb = ".?!:;,".ToCharArray();
                if (!Array.Exists(symb, x => x == match))
                {
                    ret += ". ";
                }
                else if (ret[ret.Count() - 1] != ' ')
                {
                    ret += "  ";
                }

            }
            return ret;
        }

        public string GetSentence(List<Object> arr)
        {
            return Form(arr, true);
        }

        public string EndSentence(string s)
        {
            var match = s.TrimEnd(' ')[-1];
            var symb = ".?!:;,".ToCharArray();
            if (Array.Exists(symb, x => x == match))
            {
                s += ". ";
            }
            else if (!s.EndsWith(" "))
            {
                s += "  ";
            }
            return s;
        }

        public static void Test()
        {


            ProcSen sentenceSingleton = new ProcSen();
            var player = new ProcSen.Noun();
            player.Name = "you";
            player.Pronoun = "you";
            player.Unique = true;

            var James = new ProcSen.Noun();
            James.Name = "he";
            James.Pronoun = "he";
            James.Unique = true;

            List<Object> argsList = new List<Object>() { "the", player, "^is shot through by", 1, "bolt of energy.", player, "^is mortally wounded!" };
            var ret = sentenceSingleton.Form(argsList);
            var ans = "You are shot through by a bolt of energy.  You are mortally wounded!";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);

            argsList = new List<Object>() { "the", player, "^lunges but ^misses" };
            ret = sentenceSingleton.Form(argsList);
            ans = "You lunge but miss";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);

            argsList = new List<Object>() { "a", "image" };
            ret = sentenceSingleton.Form(argsList);
            ans = "An image";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);

            argsList = new List<Object>() { "stop", ".", "a deer" };
            ret = sentenceSingleton.Form(argsList);
            ans = "Stop.  A deer";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);


            argsList = new List<Object>() { "the", entity, "^is shot through by", 3, "bolt of energy.", entity, "^is mortally wounded!" };
            ret = sentenceSingleton.Form(argsList);
            ans = "The three-armed ape is shot through by 3 bolts of energy. It is mortally wounded!";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);

            argsList = new List<Object>() { "the", player, "'s", weapon, "explodes as", player, "^fires it!" };
            ret = sentenceSingleton.Form(argsList);
            ans = "Your rifle explodes as you fire it!";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);

            entity = new ProcSen.Noun();
            entity.Name = "chemist";
            entity.Pronoun = "he";
            weapon.Name = "Laser Lv-02";

            argsList = new List<Object>() { "the", entity, "'s", weapon, "explodes as", entity, "^fires it!" };
            ret = sentenceSingleton.Form(argsList);
            ans = "The chemist's Laser Lv-02 explodes as he fires it!";
            if (ret != ans) Console.WriteLine("Error! Got '" + ret + "'");
            Console.WriteLine(ret);

            return;
        }

        public class Noun
        {

            private bool unique = false;
            private bool alwaysPlural = false;
            private string name = "thing";
            private string pronoun = "it";
            private string modifier = "";

            public bool Unique { get => unique; set => unique = value; }
            public bool AlwaysPlural { get => alwaysPlural; set => alwaysPlural = value; }
            public string Name { get => name; set => name = value; }
            public string Pronoun { get => pronoun; set => pronoun = value; }
            public string Modifier { get => modifier; set => modifier = value; }

            public string GetName()
            {
                string ret = this.Name;
                if (!this.Unique && this.Modifier != "")
                {
                    ret = this.Modifier + " " + ret;
                }
                return ret;
            }

            public string GetPronoun()
            {
                if (this.AlwaysPlural && this.Pronoun == "it")
                {
                    return "them";
                }
                return this.Pronoun;

            }

            public string _ToString()
            {
                return this.GetName();
            }

            public static string Pluralise(string s)
            {
                if (s.EndsWith("s"))
                {
                    return s + "es";
                }
                else
                {
                    return s + "s";
                }
            }

            public static string Possessivise(string s)
            {
                if (s == "you") { return "your"; }
                else if (s == "it") { return "its"; }
                else if (s.EndsWith("s")) { return s + "'"; }
                else { return s + "'s"; }
            }

            public static string FirstPersonise(string s)
            {
                if (s == "is") return "are";
                if (s == "isn't") return "aren't";
                if (s == "has") return "have";
                if (s == "readies") return "ready";
                else if (s.EndsWith("shes") || s.EndsWith("ches") || s.EndsWith("sses")) return s.TrimSuffix("es");
                if (s.EndsWith("s")) return s.TrimSuffix("s");
                return s;
            }

            public static string AOrAn(string phrase)
            {
                char[] vowels = "aeiou".ToCharArray();
                char match = char.Parse(phrase.Substring(0, 1).ToLower());
                if (Array.Exists(vowels, x => x == match))
                { return "an " + phrase; }
                else { return "a " + phrase; }

            }
        }

        class GrammarState
        {
            private bool possess = false;
            private bool capitalise = false;
            private bool putThe = false;
            private bool pluralise = false;
            private bool firstperson = false;
            private bool putA = false;

            public bool Possess { get => possess; set => possess = value; }
            public bool Capitalise { get => capitalise; set => capitalise = value; }
            public bool PutThe { get => putThe; set => putThe = value; }
            public bool Pluralise { get => pluralise; set => pluralise = value; }
            public bool Firstperson { get => firstperson; set => firstperson = value; }
            public bool PutA { get => putA; set => putA = value; }
        }

        public class HIDE_NUM
        {
            private int value;

            public int Value { get => value; set => this.value = value; }
        }

    }
}