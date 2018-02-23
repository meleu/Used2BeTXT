#!/usr/bin/env bash
# Used2BeTXT.sh
###############
#
# This script converts synopsis text files to gamelist.xml files.
#
# More info in this forum thread: https://retropie.org.uk/forum/post/79022
#
# meleu - 2017/Jun

FULL_FLAG=0
NO_DESC_FLAG=0
ONLY_NEW_FLAG=0
ONLY_IMG_FLAG=0
DEFAULT_GAMELIST_FLAG=0
REVERSE_FLAG=0
PLATFORM=
IMG_DIR="Artwork/Box Front"

readonly RP_DATA="$HOME/RetroPie"

readonly SCRIPT_DIR="$(cd "$(dirname $0)" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_FULL="$SCRIPT_DIR/$SCRIPT_NAME"
readonly SCRIPT_URL="https://raw.githubusercontent.com/meleu/Used2BeTXT/master/Used2BeTXT.sh"
readonly BKP_DIR="used2betxt-backups"

readonly HELP="
Usage:
$0 [OPTIONS] synopsis1.txt [synopsisN.txt ...]

The script gets data from \"synopsis1.txt\" and adds those data in xml format to
a file named \"PLATFORM_gamelist.xml\", where PLATFORM is the one indicated in
'Platform:' line in \"synopsis.txt\".

The OPTIONS are:

-h|--help       print this message and exit.

-u|--update     update the script and exit.

--only-new      only add new entries to \"gamelist.xml\" (do not update
                existing entries).

--no-desc       do not generate <desc> entries.

--full          generate gamelist.xml using all metadata from \"synopsis1.txt\",
                including the ones unused for EmulationStation. The converted
                file will be named \"PLATFORM_FULL_gamelist.xml\"
                (see: --default-gamelist).

--default-gamelist  the converted file will be named \"PLATFORM_gamelist.xml\" 
                    even if using --full option.

--image TYPE    choose the art type for <image>. Valid options for
                TYPE: boxfront, cart, title, action, 3dbox.

--only-image    if updating a \"gamelist.xml\", only update the <image>,
                useful for changing image TYPE (see: --image).
"


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


# TODO: better management of apersand '&'
function get_data() {
    grep -m 1 -i "^$1:" "$2" | sed -e "s/^$1: //I; s/&/&amp;/g; s/\r//g"
}

function find_file() {
    local found
    local dir="$( echo "$1" | tr '[]&' '???')"
    local file="$(echo "$2" | tr '[]&' '???')"
    shift 2
    local args=()
    local ext

    if [[ -z "$1" ]]; then
        args=( -iname "${file}.*" )
    else
        args=( -iname "${file}.$1" )
        shift
        for ext in "$@"; do
            args+=( -o -iname "${file}.$ext" )
        done
    fi

    if [[ "$dir" == [Rr]oms ]]; then
        found="$(find "$RP_DATA/roms/$platform" -type f \( "${args[@]}" \) -print -quit 2> /dev/null)"
        if [[ -n "$found" ]]; then
            echo "${found//&/&amp;}"
            return
        fi
    fi

    found="$(find "$RP_DATA/Media/$platform/$dir" -type f \( "${args[@]}" \) -print -quit 2> /dev/null)"
    [[ -z "$found" && -n "$xtras_system" ]] \
    && found="$(find "$RP_DATA/Media" -type f -ipath "$RP_DATA/Media/$xtras_system/$dir/*" \( "${args[@]}" \) -print -quit)"

    echo "${found//&/&amp;}"
}

# MANAGING OPTIONS ###########################################################

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
            ;;
        --no-desc)
            NO_DESC_FLAG=1
            ;;
        --only-new)
            ONLY_NEW_FLAG=1
            ;;
        --only-image)
            ONLY_IMG_FLAG=1
            ;;
        --default-gamelist)
            DEFAULT_GAMELIST_FLAG=1
            ;;
        --image)
            shift
            case "$1" in
                boxfront)
                    IMG_DIR="Artwork/Box Front" ;;
                cart)
                    IMG_DIR="Artwork/Cart" ;;
                title)
                    IMG_DIR="Artwork/Titles" ;;
                action)
                    IMG_DIR="Artwork/Action" ;;
                3dbox)
                    IMG_DIR="Artwork/3D Boxart" ;;
                *)
                    echo "ERROR: invalid option for --image: \"$1\"" >&2
                    exit 1
                    ;;
            esac
            ;;
        -r|--reverse)
            shift
            xmlfile="$1"
            if [[ ! -f "$xmlfile" ]]; then
                echo "ERROR: no such file: \"$xmlfile\"" >&2
                exit 1
            fi
            REVERSE_FLAG=1
            ;;
        -p|--platform)
            shift
            PLATFORM="$1"
            if [[ -z "$PLATFORM" ]]; then
                echo "ERROR: you must set a platform." >&2
                exit 1
            fi
            ;;
        *)
            break
            ;;
    esac
    shift
done


# CONVERTING FROM GAMELIST.XML TO SYNOPSIS.TXT ###############################

if [[ "$REVERSE_FLAG" == 1 ]]; then
    if [[ -z "$PLATFORM" ]]; then
        echo "ERROR: you must set a platform with the option \"--platform\"." >&2
        exit 1
    fi

    IFS=$'\n' names=($(xmlstarlet sel -t -v "/gameList/game/name" "$xmlfile"))

    for name in "${names[@]}"; do
        echo -n "Generating \"${name}.txt\"... "
        cat > "${name}.txt" << _EoF_
$name
Platform: $PLATFORM
Region: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/region" "$xmlfile")
Media: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/media" "$xmlfile")
Controller: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/controller" "$xmlfile")
Genre: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/genre" "$xmlfile")
Gametype: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/gametype" "$xmlfile")
Release Year: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/releasedate" "$xmlfile" | grep -o '^.\{4\}')
Developer: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/developer" "$xmlfile")
Publisher: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/publisher" "$xmlfile")
Players: $(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/players" "$xmlfile")
_________________________
$(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/desc" "$xmlfile")
_EoF_
        echo "Done!"

#       PLATFORM="$(      xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/platform" "$xmlfile")"
#        path="$(          xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/path" "$xmlfile")"
#        image="$(         xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/image" "$xmlfile")"
#        video="$(         xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/video" "$xmlfile")"
#        marquee="$(       xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/marquee" "$xmlfile")"
#        xtrasname="$(     xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/xtrasname" "$xmlfile")"
#        originaltitle="$( xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/originaltitle" "$xmlfile")"
#        alternatetitle="$(xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/alternatetitle" "$xmlfile")"
#        hackedby="$(      xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/hackedby" "$xmlfile")"
#        translatedby="$(  xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/translatedby" "$xmlfile")"
#        version="$(       xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/version" "$xmlfile")"
#        cart="$(          xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/cart" "$xmlfile")"
#        title="$(         xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/title" "$xmlfile")"
#        action="$(        xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/action" "$xmlfile")"
#        threedbox="$(     xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/threedbox" "$xmlfile")"
#        gamefaq="$(       xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/gamefaq" "$xmlfile")"
#        manual="$(        xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/manual" "$xmlfile")"
#        vgmap="$(         xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/vgmap" "$xmlfile")"
#        license="$(       xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/license" "$xmlfile")"
#        programmer="$(    xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/programmer" "$xmlfile")"
#        musician="$(      xmlstarlet sel -t -v "/gameList/game[name=\"$name\"]/musician" "$xmlfile")"
    done
fi


# PROCESSING FILES ###########################################################

shopt -s nocaseglob
shopt -s nocasematch

# creating backups
mkdir -p "$BKP_DIR"
while IFS= read -r gamelist || [[ -n $gamelist ]]; do
    bkp_file="$BKP_DIR/${gamelist%%.*}_$(date +"%Y-%m-%d_%H%M%S").xml"
    if [[ ! -f "$bkp_file.gz" ]]; then
        cp "$gamelist" "$bkp_file"
        gzip "$bkp_file"
    fi
done < <(find . -maxdepth 1 -name '*_gamelist.xml')

for file in "$@"; do
    file_name="$(basename "${file%.*}")"
    platform=$(grep -m 1 "^Platform: " "$file" | cut -d: -f2 | tr -d ' \r' | tr [:upper:] [:lower:])
    [[ -z "$platform" ]] && continue

    # name : the very first line of the txt file
    name_real="$(head -1 "$file" | tr -d '\r')"
    name="${name_real//&/&amp;}"
    [[ -z "$name" ]] && continue

    ROM_EXT="zip"
    [[ "$(get_data "Media" "$file")" =~ ^(cd|compact disc)$ ]] && ROM_EXT+=" cue"
    case "$platform" in
        atari2600)
            xtras_system="atari 2600"
            ;;

        atari7800)
            xtras_system="atari 7800"
            ;;

        atari5200|atari800)
            xtras_system="atari 5200"
            ROM_EXT+=" bin"
            ;;

        nintendoentertainmentsystem|thefamilycomputerdisksystem|familycomputerdisksystem|nes)
            platform="nes" 
            xtras_system="nes"
            ;;

        nintendogameboyadvance|gba)
            platform="gba"
            xtras_system="game boy advance"
            ;;

        nintendogameboycolor|gbc)
            platform="gbc"
            xtras_system="game boy color"
            ;;

        nintendogameboy|gb)
            platform="gb"
            xtras_system="game boy"
            ;;

        nintendovirtualboy|virtualboy)
            platform="virtualboy"
            ;;

        supernintendoentertainmentsystem|snes)
            platform="snes"
            xtras_system="snes"
            ;;

        segamastersystem|mastersystem)
            platform="mastersystem"
            xtras_system="master system"
            ;;

        segagamegear|gamegear)
            platform="gamegear" ;;

        segasg-1000|sg-1000)
            platform="sg-1000" ;;

        segagenesis/megadrive|genesis|megadrive)
            platform="megadrive"
            xtras_system="genesis"
            ;;

        sega/megacd|segacd)
            platform="segacd" ;;

        turbografx-16/pcengine|pcengine)
            platform="pcengine" ;;

        neogeopocket|ngp)
            platform="ngp"
            xtras_system="neo geo pocket"
            ;;

        colecovision|coleco)
            platform="coleco" ;;

        bandaiwonderswan|wonderswan)
            platform="wonderswan" ;;

        bandaiwonderswancolor|wonderswancolor)
            platform="wonderswancolor" ;;

        magnavoxodyssey2|videopac)
            platform="videopac"
            ROM_EXT+=" bin"
            ;;
    esac

    gamelist="$platform"
    [[ "$FULL_FLAG" == 1 && "$DEFAULT_GAMELIST_FLAG" != 1 ]] && gamelist+="_FULL"
    gamelist+="_gamelist.xml"

    [[ -f "$gamelist" ]] || echo "<gameList />" > "$gamelist"

    # folder : "Folder"
    folder="$(get_data "Folder" "$file")"
    [[ -n "$folder" ]] && game=folder || game=game

    if [[ $(xmlstarlet sel -t -v "count(/gameList/$game[name=\"$name_real\"])" "$gamelist") == 0 ]]; then
        NEW_ENTRY_FLAG=1
    else
        NEW_ENTRY_FLAG=0
    fi
    [[ "$NEW_ENTRY_FLAG" == 0 && "$ONLY_NEW_FLAG" == 1 ]] && continue

    # image : find the box art
    if [[ -n "$folder" ]]; then
        image="$(find_file "Artwork/Folders" "$file_name" png jpg )"
    else
        image="$(find_file "$IMG_DIR" "$file_name" png jpg )"
    fi

    if [[ "$NEW_ENTRY_FLAG" == 1 || "$ONLY_IMG_FLAG" == 0 ]]; then
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
            path="$(find_file Roms "$file_name" $ROM_EXT )"
        fi

        # video : find the video preview
        video="$(find_file Movies "$file_name" "???")"

        # marquee : find the marquee
        # TODO: need tests
        marquee="$(find_file "Artwork/Marquee" "$file_name" png jpg )"

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
        if [[ "$NO_DESC_FLAG" == 0 ]]; then
            desc="$(sed '/^__________/,$!d' "$file" | tail -n +2 | tr -d '\r' | sed 's/&/&amp;/g')"
            desc="$(grep -Ev '^(https?|ftp)://[^\s/$.?#].[^\s]*$' <<< "$desc")"
        fi

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
            cart="$(find_file "Artwork/Cart" "$file_name" png jpg)"

            # title : find it
            title="$(find_file "Artwork/Titles" "$file_name" png jpg)"

            # action : find it
            action="$(find_file "Artwork/Action" "$file_name" png jpg)"

            # threedbox : find it
            threedbox="$(find_file "Artwork/3D Boxart" "$file_name" png jpg)"

            # gamefaq : find it
            gamefaq="$(find_file "GameFAQs" "$file_name" zip)"

            # manual : find it
            manual="$(find_file "Manuals" "$file_name" zip)"

            # vgmap : find it
            vgmap="$(find_file "VGMaps" "$file_name" zip)"
        fi # end of if FULL_FLAG
    fi # end of if ONLY_IMG_FLAG

    if [[ "$NEW_ENTRY_FLAG" == 1 ]]; then
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
    elif [[ "$ONLY_IMG_FLAG" == 1 ]]; then
        xmlstarlet ed -L \
            -u "/gameList/$game[name=\"$name_real\"]/image" -v "${image//&amp;/&}" \
            "$gamelist"
    else
        xmlstarlet ed -L \
            -u "/gameList/$game[name=\"$name_real\"]/path" -v "${path//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/image" -v "${image//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/video" -v "${video//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/marquee" -v "${marquee//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/desc" -v "${desc//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/releasedate" -v "${releasedate//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/developer" -v "${developer//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/publisher" -v "${publisher//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/genre" -v "${genre//&amp;/&}" \
            -u "/gameList/$game[name=\"$name_real\"]/players" -v "${players//&amp;/&}" \
            "$gamelist"

        if [[ "$game" == game && "$FULL_FLAG" == 1 ]]; then
            xmlstarlet ed -L \
                -u "/gameList/game[name=\"$name_real\"]/region" -v "${region//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/platform" -v "${platform//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/media" -v "${media//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/controller" -v "${controller//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/gametype" -v "${gametype//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/xtrasname" -v "${xtrasname//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/originaltitle" -v "${originaltitle//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/alternatetitle" -v "${alternatetitle//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/hackedby" -v "${hackedby//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/translatedby" -v "${translatedby//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/version" -v "${version//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/cart" -v "${cart//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/title" -v "${title//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/action" -v "${action//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/threedbox" -v "${threedbox//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/gamefaq" -v "${gamefaq//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/manual" -v "${manual//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/vgmap" -v "${vgmap//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/license" -v "${license//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/programmer" -v "${programmer//&amp;/&}" \
                -u "/gameList/game[name=\"$name_real\"]/musician" -v "${musician//&amp;/&}" \
                "$gamelist"
        fi
    fi

    echo "\"$file\" data has been added to \"$gamelist\"."
done
