# This file is for unsetting unwanted alias/function definitions.

# Functions or aliases may be removed if they do one of the following:
#   - Interfere with the reloading process
#     - This usually happens if I have recently re-made an alias as a function.
#     - These removals will themselves be removed if I am 100% positive that nothing is using the old definitions.
#   - Are an unwanted function/alias from outside of my tools modules.

# 2016-09-06
# Fighting Fedora 24 deprecation nudging by unsetting the 'ifconfig' and 'service' functions.
# These functions print complain (rightly) about the function being deprecated and exit out without doing anything.
# Note: There is also a function to override 'yum', but I am happy with leaving that in.
unset -f ifconfig service

# 2016-09-25
# Moving get-imgur-gallery to be a script as it was before being version-controlled.
unset -f get-imgur-gallery

#2017-01-03
# Moving silly functions to individual scripts or other files.
unset -f wtc wtc-stream maze maze-rainbow
