#!/usr/bin/env bash
# Used2BeTXT.sh
###############
#
# This script converts synopsis text files to gamelist.xml files.
#
# More info in this forum thread: https://retropie.org.uk/forum/post/79022
#
# meleu - 2017/Jun

readonly RP_DATA="$HOME/RetroPie"

readonly SCRIPT_DIR="$(dirname "$0")"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_FULL="$SCRIPT_DIR/$SCRIPT_NAME"
readonly SCRIPT_URL="https://raw.githubusercontent.com/meleu/Used2BeTXT/master/Used2BeTXT.sh"

readonly HELP="
Usage:
$0 [OPTIONS] synopsis1.txt [synopsisN.txt ...]

The OPTIONS are:

-h|--help       print this message and exit.

-u|--update     update the script and exit.

--no-desc       do not generate <desc> entries

--full          generate gamelist.xml using all metadata from \"synopsis1.txt\",
                including the ones unused for EmulationStation. The converted
                file will be named \"PLATFORM_FULL_gamelist.xml\".

The script gets data from \"synopsis1.txt\" and adds those data in xml format to
a file named \"PLATFORM_gamelist.xml\", where PLATFORM is the one indicated in
'Platform:' line in \"synopsis.txt\".
"

FULL_FLAG=0
NO_DESC_FLAG=0


function update_script() {
    local err_flag=0
    local err_msg

    if err_msg=$(wget "$SCRIPT_URL" -O "/tmp/$SCRIPT_NAME" 2>&1); then
        if diff -q "$SCRIPT_FULL" "/tmp/$SCRIPT_NAME" >/dev/null; then
            echo "You already have the latest version. Nothing changed."
            rm -f "/tmp/$SCRIPT_NAME"
            exit 0
        fi
        err_msg=$(mv "/tmp/$SCRIPT_NAME" "$SCRIPT_FULL" 2>&1) \
        || err_flag=1
    else
        err_flag=1
    fi

    if [[ $err_flag -ne 0 ]]; then
        err_msg=$(echo "$err_msg" | tail -1)
        echo "Failed to update \"$SCRIPT_NAME\": $err_msg" >&2
        exit 1
    fi
    
    chmod a+x "$SCRIPT_FULL"
    echo "The script has been successfully updated. You can run it again."
    exit 0
}


function get_data() {
    grep -i "^$1:" "$2" | sed -e "s/^$1: //I; s/&/&amp;/g; s/\r//g"
}

function find_file() {
    local found
    local dir="$( echo "$1" | tr '[]&' '???')"
    local file="$(echo "$2" | tr '[]&' '???')"
    local ext="$3"

    [[ -z "$ext" ]] && ext="*"

    # first - search in the "ressurection.xtras" style
    found="$(find "$RP_DATA/Media" -type f -ipath "*/$xtras_system/$dir/*" -iname "${file}.$ext" -print -quit)"
    if [[ -z "$found" ]]; then
        # second - search in the "Used2BeRX" style
        found="$(find "$RP_DATA/Media" -type f -ipath "*/$platform/$dir/*" -iname "${file}.$ext" -print -quit)"
        if [[ -z "$found" && "$dir" == roms ]]; then
            # third (last) - search in the RetroPie style
            found="$(find "$RP_DATA" -type f -ipath "*/roms/$platform/*" -iname "${file}.$ext" -print -quit)"
        fi
    fi
    echo "$found" | sed "s/&/&amp;/g"
}

# START HERE #################################################################

while [[ -n "$1" ]]; do
    case "$1" in
        -h|--help)
            echo "$HELP" >&2
            exit 0
            ;;
        -u|--update)
            update_script
            ;;
        --full)
            FULL_FLAG=1
            shift
            ;;
        --no-desc)
            NO_DESC_FLAG=1
            shift
            ;;
        *)
            break
            ;;
    esac
done


for file in "$@"; do
    file_name="$(basename "${file%.*}")"
    platform=$(grep "^Platform: " "$file" | cut -d: -f2 | tr -d ' \r' | tr [:upper:] [:lower:])
    [[ -z "$platform" ]] && continue

    # name : the very first line of the txt file
    name="$(head -1 "$file" | tr -d '\r' | sed 's/&/&amp;/g')"
    [[ -z "$name" ]] && continue

    case "$platform" in
        atari2600)
            xtras_system="atari 2600"
            ;;

        atari7800)
            xtras_system="atari 7800"
            ;;

        nintendoentertainmentsystem)
            platform="nes" 
            xtras_system="nes"
            ;;

        thefamilycomputerdisksystem)
            platform="fds"
            xtras_system="nes"
            ;;

        nintendogameboyadvance)
            platform="gba"
            xtras_system="game boy advance"
            ;;

        nintendogameboycolor)
            platform="gbc"
            xtras_system="game boy color"
            ;;

        nintendogameboy)
            platform="gb"
            xtras_system="game boy"
            ;;

        segamastersystem)
            platform="mastersystem"
            xtras_system="master system"
            ;;

        segagamegear)
            platform="gamegear" ;;

        segasg-1000)
            platform="sg-1000" ;;

        segagenesis/megadrive)
            platform="megadrive"
            xtras_system="genesis"
            ;;

        sega/megacd)
            platform="segacd" ;;

        turbografx-16/pcengine)
            platform="pcengine" ;;

        neogeopocket)
            platform="ngp"
            xtras_system="neo geo pocket"
            ;;

        colecovision)
            platform="coleco" ;;

        bandaiwonderswan)
            platform="wonderswan" ;;

        bandaiwonderswancolor)
            platform="wonderswancolor" ;;
    esac

    gamelist="$platform"
    [[ "$FULL_FLAG" == 1 ]] && gamelist+="_FULL"
    gamelist+="_gamelist.xml"

    [[ -f "$gamelist" ]] || echo "<gameList />" > "$gamelist"

    # folder : "Folder"
    folder="$(get_data "Folder" "$file")"
    [[ -n "$folder" ]] && game=folder || game=game

    # path : find the path
    if [[ -n "$folder" ]]; then
        # first - search in the "ressurection.xtras" style
        path="$(find "$RP_DATA/Media" -type d -ipath "*/$xtras_system/roms/*" -iname "$folder" -print -quit)"
        if [[ -z "$path" ]]; then
            # second - search in the "Used2BeRX" style
            path="$(find "$RP_DATA/Media" -type d -ipath "*/$platform/roms/*" -iname "$folder" -print -quit)"
            if [[ -z "$path" ]]; then
                # third (last) - search in the RetroPie style
                path="$(find "$RP_DATA" -type d -ipath "*/roms/$platform/*" -iname "$folder" -print -quit)"
            fi
        fi
    else
        path="$(find_file roms "$file_name" zip)"
    fi

    # image : find the box art
    if [[ -n "$folder" ]]; then
        image="$(find_file "artwork/folders" "$file_name" "???" )"
    else
        image="$(find_file "artwork/box front" "$file_name" "???" )"
    fi

    # video : find the video preview
    video="$(find_file movies "$file_name" "???")"

    # marquee : TODO
    # there's no equivalent to marquee in ressurection.xtras

    # releasedate : "Release Year"
    releasedate="$(get_data "Release Year" "$file")"
    # Note: releasedate must be a date/time in the format %Y%m%dT%H%M%S or empty
    if [[ "$releasedate" =~ ^[[:digit:]]{1,4}$ ]]; then
        releasedate="$(date -d ${releasedate}-1-1 +%Y%m%dT%H%M%S)" || realeasedate=""
    else
        releasedate=""
    fi

    # developer : "Developer"
    developer="$(get_data "Developer" "$file")"

    # publisher : "Publisher"
    publisher="$(get_data "Publisher" "$file")"

    # genre : "Genre"
    genre="$(get_data "Genre" "$file")"

    # players : "Players"
    players="$(get_data "Players" "$file")"
    # Note: players must be an integer
    [[ -n "$players" ]] && players=$(echo $players | sed 's/[^0-9 ]//g' | tr -s ' ' '\n' | sort -nr | head -1)

    # desc : the content below "______" to the end of file
    [[ "$NO_DESC_FLAG" -eq 0 ]] && desc="$(sed '/^__________/,$!d' "$file" | tail -n +2 | tr -d '\r' | sed 's/&/&amp;/g')"

    if [[ "$FULL_FLAG" == 1 ]]; then
        if [[ -n "$folder" ]]; then
            xtrasname="$folder"
        else
            xtrasname="${file_name%.*}"
        fi

        region="$(get_data "Region" "$file")"
        media="$(get_data "Media" "$file")"
        controller="$(get_data "Controller" "$file")"
        gametype="$(get_data "Gametype" "$file")"
        originaltitle="$(get_data "Original Title" "$file")"
        alternatetitle="$(get_data "Alternate Title" "$file")"
        hackedby="$(get_data "Hacked by" "$file")"
        translatedby="$(get_data "Translated by" "$file")"
        version="$(get_data "Version" "$file")"
        license="$(get_data "License" "$file")"
        programmer="$(get_data "Programmer" "$file")"
        musician="$(get_data "Musician" "$file")"

        # cart : find it
        cart="$(find_file "artwork/cart" "$file_name" png)"

        # title : find it
        title="$(find_file "artwork/titles" "$file_name" png)"

        # action : find it
        action="$(find_file "artwork/action" "$file_name" png)"

        # threedbox : find it
        threedbox="$(find_file "artwork/3d boxart" "$file_name" png)"

        # gamefaq : find it
        gamefaq="$(find_file "gamefaqs" "$file_name" zip)"

        # manual : find it
        manual="$(find_file "manuals" "$file_name" zip)"

        # vgmap : find it
        vgmap="$(find_file "vgmaps" "$file_name" zip)"

    fi

    if [[ $(xmlstarlet sel -t -v "count(/gameList/$game[name=\"$name\"])" "$gamelist") -eq 0 ]]; then
        xmlstarlet ed -L -s "/gameList" -t elem -n "$game" -v "" \
            -s "/gameList/$game[last()]" -t elem -n "name" -v "$name" \
            -s "/gameList/$game[last()]" -t elem -n "path" -v "$path" \
            -s "/gameList/$game[last()]" -t elem -n "image" -v "$image" \
            -s "/gameList/$game[last()]" -t elem -n "video" -v "$video" \
            -s "/gameList/$game[last()]" -t elem -n "marquee" -v "$marquee" \
            -s "/gameList/$game[last()]" -t elem -n "desc" -v "$desc" \
            -s "/gameList/$game[last()]" -t elem -n "releasedate" -v "$releasedate" \
            -s "/gameList/$game[last()]" -t elem -n "developer" -v "$developer" \
            -s "/gameList/$game[last()]" -t elem -n "publisher" -v "$publisher" \
            -s "/gameList/$game[last()]" -t elem -n "genre" -v "$genre" \
            -s "/gameList/$game[last()]" -t elem -n "players" -v "$players" \
            "$gamelist"

        if [[ "$game" == game && "$FULL_FLAG" == 1 ]]; then
            xmlstarlet ed -L \
                -s "/gameList/game[last()]" -t elem -n "region" -v "$region" \
                -s "/gameList/game[last()]" -t elem -n "platform" -v "$platform" \
                -s "/gameList/game[last()]" -t elem -n "media" -v "$media" \
                -s "/gameList/game[last()]" -t elem -n "controller" -v "$controller" \
                -s "/gameList/game[last()]" -t elem -n "gametype" -v "$gametype" \
                -s "/gameList/game[last()]" -t elem -n "xtrasname" -v "$xtrasname" \
                -s "/gameList/game[last()]" -t elem -n "originaltitle" -v "$originaltitle" \
                -s "/gameList/game[last()]" -t elem -n "alternatetitle" -v "$alternatetitle" \
                -s "/gameList/game[last()]" -t elem -n "hackedby" -v "$hackedby" \
                -s "/gameList/game[last()]" -t elem -n "translatedby" -v "$translatedby" \
                -s "/gameList/game[last()]" -t elem -n "version" -v "$version" \
                -s "/gameList/game[last()]" -t elem -n "cart" -v "$cart" \
                -s "/gameList/game[last()]" -t elem -n "title" -v "$title" \
                -s "/gameList/game[last()]" -t elem -n "action" -v "$action" \
                -s "/gameList/game[last()]" -t elem -n "threedbox" -v "$threedbox" \
                -s "/gameList/game[last()]" -t elem -n "gamefaq" -v "$gamefaq" \
                -s "/gameList/game[last()]" -t elem -n "manual" -v "$manual" \
                -s "/gameList/game[last()]" -t elem -n "vgmap" -v "$vgmap" \
                -s "/gameList/game[last()]" -t elem -n "license" -v "$license" \
                -s "/gameList/game[last()]" -t elem -n "programmer" -v "$programmer" \
                -s "/gameList/game[last()]" -t elem -n "musician" -v "$musician" \
                "$gamelist"
        fi
    else
        xmlstarlet ed -L \
            -u "/gameList/$game[name=\"$name\"]/path" -v "$path" \
            -u "/gameList/$game[name=\"$name\"]/image" -v "$image" \
            -u "/gameList/$game[name=\"$name\"]/video" -v "$video" \
            -u "/gameList/$game[name=\"$name\"]/marquee" -v "$marquee" \
            -u "/gameList/$game[name=\"$name\"]/desc" -v "$desc" \
            -u "/gameList/$game[name=\"$name\"]/releasedate" -v "$releasedate" \
            -u "/gameList/$game[name=\"$name\"]/developer" -v "$developer" \
            -u "/gameList/$game[name=\"$name\"]/publisher" -v "$publisher" \
            -u "/gameList/$game[name=\"$name\"]/genre" -v "$genre" \
            -u "/gameList/$game[name=\"$name\"]/players" -v "$players" \
            "$gamelist"

        if [[ "$game" == game && "$FULL_FLAG" == 1 ]]; then
            xmlstarlet ed -L \
                -u "/gameList/game[name=\"$name\"]/region" -v "$region" \
                -u "/gameList/game[name=\"$name\"]/platform" -v "$platform" \
                -u "/gameList/game[name=\"$name\"]/media" -v "$media" \
                -u "/gameList/game[name=\"$name\"]/controller" -v "$controller" \
                -u "/gameList/game[name=\"$name\"]/gametype" -v "$gametype" \
                -u "/gameList/game[name=\"$name\"]/xtrasname" -v "$xtrasname" \
                -u "/gameList/game[name=\"$name\"]/originaltitle" -v "$originaltitle" \
                -u "/gameList/game[name=\"$name\"]/alternatetitle" -v "$alternatetitle" \
                -u "/gameList/game[name=\"$name\"]/hackedby" -v "$hackedby" \
                -u "/gameList/game[name=\"$name\"]/translatedby" -v "$translatedby" \
                -u "/gameList/game[name=\"$name\"]/version" -v "$version" \
                -u "/gameList/game[name=\"$name\"]/cart" -v "$cart" \
                -u "/gameList/game[name=\"$name\"]/title" -v "$title" \
                -u "/gameList/game[name=\"$name\"]/action" -v "$action" \
                -u "/gameList/game[name=\"$name\"]/threedbox" -v "$threedbox" \
                -u "/gameList/game[name=\"$name\"]/gamefaq" -v "$gamefaq" \
                -u "/gameList/game[name=\"$name\"]/manual" -v "$manual" \
                -u "/gameList/game[name=\"$name\"]/vgmap" -v "$vgmap" \
                -u "/gameList/game[name=\"$name\"]/license" -v "$license" \
                -u "/gameList/game[name=\"$name\"]/programmer" -v "$programmer" \
                -u "/gameList/game[name=\"$name\"]/musician" -v "$musician" \
                "$gamelist"
        fi
    fi

    echo "\"$file\" data has been added to \"$gamelist\"."
done
