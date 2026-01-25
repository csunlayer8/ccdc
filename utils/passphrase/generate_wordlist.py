import re
from wordlist import WORDS
## Ripped (modified for embedding) from xkcd_password source code

def generate_wordlist(min_length=5,
                      max_length=9,
                      valid_chars='.'):
    """
    Generate a word list from the larger word list
    valid_chars is a regular expression match condition (default - all chars)
    """

    words = set()

    regexp = re.compile("^{0}{{{1},{2}}}$".format(valid_chars,
                                                  min_length,
                                                  max_length))
    for thisword in WORDS:
        if regexp.match(thisword) is not None:
            words.add(thisword)
    if len(words):
        return list(words)  # deduplicate, just in case
    else:
        raise SystemExit("Error: Provided arguments result in emtpy wordlist. (Probably because there aren't any words that match your --min and --max options) Exiting.")