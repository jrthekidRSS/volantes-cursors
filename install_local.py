#!/usr/bin/python

import os


def rm_exist(path):
    if os.path.isdir(path):
        os.system("rm -r " + path)


rm_exist("~/.local/share/icons/volantes_cursors/")

os.system("cp -r ./build/volantes_cursors/ ~/.local/share/icons/")
