# Used2BeTXT
Converting (synopsis) TXT files to (gamelist) XML

Trying to do what was requested here: https://retropie.org.uk/forum/post/79022

Executing the `Used2BeTXT.sh` script with `--help` gives an idea of what the script does:

```
[PROMPT]$ ./Used2BeTXT.sh --help

Usage:
./Used2BeTXT.sh [OPTIONS] synopsis1.txt [synopsisN.txt ...]

The script gets data from "synopsis1.txt" and adds those data in xml format to
a file named "PLATFORM_gamelist.xml", where PLATFORM is the one indicated in
'Platform:' line in "synopsis.txt".

The OPTIONS are:

-h|--help       print this message and exit.

-u|--update     update the script and exit.

--only-new      only add new entries to "gamelist.xml" (do not update
                existing entries).

--no-desc       do not generate <desc> entries.

--full          generate gamelist.xml using all metadata from "synopsis1.txt",
                including the ones unused for EmulationStation. The converted
                file will be named "PLATFORM_FULL_gamelist.xml"
                (see: --default-gamelist).

--default-gamelist  the converted file will be named "PLATFORM_gamelist.xml" 
                    even if using --full option.

--image TYPE    choose the art type for <image>. Valid options for
                TYPE: boxfront, cart, title, action, 3dbox.

--only-image    if updating a "gamelist.xml", only update the <image>,
                useful for changing image TYPE (see: --image).
```
