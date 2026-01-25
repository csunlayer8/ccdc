from xkcdpass import xkcd_password as xp
from random import random as rng

from generate_wordlist import generate_wordlist

# get input parameters
print("~ Params ~")
word_len = input("Word Length: ")
word_ct = input("Word Count: ")

# interpret params or set default values
try : word_len = int(word_len); assert word_len >= 3 and word_len <= 9, "No words"
except : print("!! Invalid Params !! Defaulting Word Length"); word_len = 6

try : word_ct = int(word_ct); assert word_ct > 0 and word_ct < 100, "What are you doing"
except : print("!! Invalid Params !! Defaulting Word Count"); word_ct = 4

print()
# create a wordlist from the default wordfile
# use words between X and Y letters long
mywords = generate_wordlist(word_len, word_len)
# wordfile = xp.locate_wordfile("")
# mywords = xp.generate_wordlist(wordfile=wordfile, min_length=word_len, max_length=word_len)

# generates a password based on params
def get_pass() :
    words = xp.generate_xkcdpassword(mywords, word_ct).split(" ")
    words = [word.title() for word in words] # capitalize & remove gap
    number = int(rng()*1000) # append a 3 digit zero-padded number
    return f"{"".join(words)}{number:03}" 

# generate sets of 10 passphrases
while True :
    for _ in range(10):
        print(get_pass())
    if input("\n Generate More? (y/n) ").lower().strip() == 'n' : break
    else : print() # whitespace