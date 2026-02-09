#!/usr/bin/python
import os
import shutil
import re
import json
import sys

dir_conf = "./src/config/"
file_list = "./src/cursorList"


def try_utf8(data):
    "Returns a Unicode object on success, or None on failure"
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def gen_xcursors(dir_src, dir_out):
    if not os.path.isdir(dir_out):
        os.makedirs(dir_out)

    with open(file_list, "r") as f:
        lines = f.readlines()
        for line in lines:
            file = re.findall(r"(.*) (.*)", line)
            if len(file) > 0:
                file = file[0]
                with open(dir_out + file[0], "w") as c:
                    c.write(file[1])

    os.system(
        'kcursorgen --svg-theme-to-xcursor --svg-dir="'
        + dir_src
        + '" --xcursor-dir="'
        + dir_out
        + '" --sizes=24 --scales=1,1.3333,2,2.5,3'
    )

    # Fix broken/missing links of kcursorgen (this is needed for xwayland and other old cursor)
    files = os.listdir(dir_out)
    for file1 in files:
        with open(dir_out + file1, "rb") as f:
            content = try_utf8(f.readline())

            if content is not None:
                for file2 in files:
                    if content == file2:
                        os.remove(dir_out + file1)
                        os.system("ln -sr " + dir_out + file2 + " " + dir_out + file1)


def gen_svgcursors(dir_src, dir_base, dir_out):
    files = os.listdir(dir_src)

    if not os.path.isdir(dir_out):
        os.makedirs(dir_out)

    with open(dir_base + "index.theme", "w") as f:
        f.write(
            "[Icon Theme]\n" + "Name=Volantes Cursors\n" + "Comment=design by varlesh\n"
        )

    for file in files:
        if file.endswith("_24.svg"):
            name = file.removesuffix("_24.svg")

            if file.startswith("wait"):
                path = "wait"
            elif file.startswith("progress"):
                path = "progress"
            else:
                path = name

            dir_cur = dir_out + path + "/"

            if not os.path.isdir(dir_cur):
                os.makedirs(dir_cur)

            shutil.copy(dir_src + file, dir_cur + name + ".svg")

            with open(dir_conf + path + ".cursor") as f:
                frames = f.read()
                frames = re.findall(
                    r"24 *([0-9]+) *([0-9]+) *(.*)_24_24.png *([0-9]+)?", frames
                )

                data = []

                for frame in frames:
                    hotspot_x = int(frame[0])
                    hotspot_y = int(frame[1])
                    filename = str(frame[2])
                    animation = str(frame[3])

                    item = {
                        "filename": filename + ".svg",
                        "hotspot_x": hotspot_x,
                        "hotspot_y": hotspot_y,
                        "nominal_size": 24,
                    }

                    if animation.isdecimal():
                        item["delay"] = int(animation)

                    data.append(item)

                with open(dir_cur + "metadata.json", "w") as j:
                    json.dump(data, j, indent=4)


def gen_hyprcursors(dir_src, dir_base, dir_out):
    files = os.listdir(dir_src)

    if os.path.isdir(dir_base):
        shutil.rmtree(dir_base)

    if not os.path.isdir(dir_out):
        os.makedirs(dir_out)

    with open(dir_base + "manifest.hl", "w") as f:
        f.write(
            "name = Volantes Cursors\n"
            + "description = desgin by varlesh\n"
            + "cursors_directory = hyprcursor\n"
        )

    for file in files:
        if file.endswith("_24.svg"):
            name = file.removesuffix("_24.svg")

            if file.startswith("wait"):
                path = "wait"
            elif file.startswith("progress"):
                path = "progress"
            else:
                path = name
            dir_cur = dir_out + path + "/"

            if not os.path.isdir(dir_cur):
                os.makedirs(dir_cur)

            shutil.copy(dir_src + file, dir_cur + name + ".svg")

            with open(dir_conf + path + ".cursor") as f:
                frames = f.read()
                frames = re.findall(
                    r"24 *([0-9]+) *([0-9]+) *(.*)_24_24.png *([0-9]+)?", frames
                )

                data = []
                once = False

                for frame in frames:
                    hotspot_x = int(frame[0])
                    hotspot_y = int(frame[1])
                    filename = str(frame[2])
                    animation = str(frame[3])

                    if not once:
                        data.append("hotspot_x = " + str(float(hotspot_x) / 24) + "\n")
                        data.append("hotspot_y = " + str(float(hotspot_y) / 24) + "\n")
                        once = True

                    item = "define_size = 24, " + filename + ".svg"

                    if animation.isdecimal():
                        item += ", " + animation

                    item += "\n"

                    data.append(item)

                with open(dir_cur + "meta.hl", "w") as j:
                    for line in data:
                        j.write(line)

    files = os.listdir(dir_out)
    with open(dir_src + "../cursorList", "r") as f:
        for line in f.readlines():
            content = line.strip().split(" ")
            found = False

            for file1 in files:
                if content[0] == file1:
                    found = True

            if not found:
                dir_ref = dir_out + content[1] + "/meta.hl"
                if os.path.exists(dir_ref):
                    with open(dir_ref, "a") as j:
                        j.write("define_override = " + content[0] + "\n")

    dir_tmp = "/tmp/hyprcursor_volantes"

    if os.path.isdir(dir_tmp):
        shutil.rmtree(dir_tmp)
    os.makedirs(dir_tmp)

    os.system("hyprcursor-util --create " + dir_base + " -o " + dir_tmp)

    shutil.rmtree(dir_out)
    shutil.copytree(dir_tmp + "/theme_Volantes Cursors/hyprcursor", dir_out)


def create_cursors(NAME, hypr):
    dir_src = "./src/" + NAME + "/"
    dir_base = "./build/" + NAME + "/"
    dir_hypr = dir_base + "hyprcursor/"
    dir_out = dir_base + "cursors_scalable/"
    dir_png = dir_base + "cursors/"

    if hypr:
        gen_hyprcursors(dir_src, dir_base, dir_hypr)
    gen_svgcursors(dir_src, dir_base, dir_out)
    gen_xcursors(dir_out, dir_png)

    os.system("cd build && tar -cf " + NAME.replace("_", "-") + ".tar.gz " + NAME)


dir_base = "./build"
if os.path.isdir(dir_base):
    shutil.rmtree(dir_base)

hypr = False

for arg in sys.argv[1:]:
    if arg == "--hyprcursor":
        hypr = True
    else:
        print("Unkown arg: ", arg)
        print("Use --hyprcursor to generate hyprcursors!")
        exit()

create_cursors("volantes_cursors", hypr)
