#!/bin/bash

#examples:

#using vaapi:
#ffmpeg -y -threads 4 -hwaccel vaapi -vaapi_device /dev/dri/renderD128 -i "$FILE" -map 0 -c:v h264 -bf 0 -vf format=yuv420p,scale=1920:1080 -c:a ac3 -ac 2 "$outputfile" >/dev/null 2>&1

#using CUDA:
#ffmpeg -y -hwaccel cuda -hwaccel_output_format cuda -i input.mkv -map 0:v -map 0:a:m:language:ita -map 0:a:m:language:eng? -map 0:s -disposition:a:0 default -c:v h264_nvenc -bf 0 -pixel_format yuv420p -vf scale_cuda=1920:1080 -c:a ac3 -ac 2 output.mkv

#Reset
Color_Off='\033[0m' #Text Reset
#Regular Colors
Black='\033[0;30m'  #Black
Red='\033[0;31m'    #Red
Green='\033[0;32m'  #Green
Yellow='\033[0;33m' #Yellow
Blue='\033[0;34m'   #Blue
Purple='\033[0;35m' #Purple
Cyan='\033[0;36m'   #Cyan
White='\033[0;37m'  #White

recursionLevel=0
removeMode=0
removeString=""
currentPath=()
pathString=""

#convert keeping only the preferred language and english
function convertPreferredLanguage() { 

    case $mode in
    nvdec)
        ffmpeg -y -hwaccel nvdec -i "$1" -map 0:v -map 0:a:m:language:"$lang" -map 0:a:m:language:eng? -disposition:a:0 default -c:v h264_nvenc -bf 0 -vf scale=1920:1080,setsar=1,format=yuv420p -c:a ac3 -ac 2 "$2" >/dev/null 2>&1
        ;;
    cuda)
        ffmpeg -y -hwaccel cuda -hwaccel_output_format cuda -i "$1" -map 0:v -map 0:a:m:language:"$lang" -map 0:a:m:language:eng? -disposition:a:0 default -c:v h264_nvenc -bf 0 -pixel_format yuv420p -vf scale_cuda=1920:1080 -c:a ac3 -ac 2 "$2" >/dev/null 2>&1
        ;;
    vaapi)
        ffmpeg -y -threads 4 -hwaccel vaapi -vaapi_device /dev/dri/renderD128 -i "$1" -map 0 -c:v h264 -bf 0 -vf format=yuv420p,scale=1920:1080 -c:a ac3 -ac 2 "$2" >/dev/null 2>&1
        ;;
    *)
        echo "not implemented mode, please fix"
        exit 1
        ;;
    esac

    return $?
}

#convert all streams
function convert() { 

    case $mode in
    nvdec)
        ffmpeg -y -hwaccel nvdec -i "$1" -map 0 -sn -c:v h264_nvenc -bf 0 -vf scale=1920:1080,setsar=1,format=yuv420p -c:a ac3 -ac 2 "$2" >/dev/null 2>&1
        ;;
    cuda)
        ffmpeg -y -hwaccel cuda -hwaccel_output_format cuda -i "$1" -map 0 -sn -c:v h264_nvenc -bf 0 -pixel_format yuv420p -vf scale_cuda=1920:1080 -c:a ac3 -ac 2 "$2" >/dev/null 2>&1
        ;;
    *)
        echo "not implemented mode, please fix"
        exit 1
        ;;
    esac

    return $?
}

#convert only the first stream
function convertOnlyFirst() { 

    case $mode in
    nvdec)
        ffmpeg -y -hwaccel nvdec -i "$1" -map 0:v:0 -map 0:a -c:v h264_nvenc -bf 0 -vf scale=1920:1080,setsar=1,format=yuv420p -c:a ac3 -ac 2 -c:s copy "$2" >/dev/null 2>&1
        ;;
    cuda)
        ffmpeg -y -hwaccel cuda -hwaccel_output_format cuda -i "$1" -map 0:v:0 -map 0:a -c:v h264_nvenc -bf 0 -pixel_format yuv420p -vf scale_cuda=1920:1080 -c:a ac3 -ac 2 c:s copy "$2" >/dev/null 2>&1
        ;;
    *)
        echo "not implemented mode, please fix"
        exit 1
        ;;
    esac

    return $?
}

function toPathString() {
    pathString=""

    for element in "${currentPath[@]}"; do
        pathString+="${element}/"
    done
}

function append() {
    echo "$*" >>"${dbfile}"
}

function iterate() {
    toPathString
    local dir="${pathString}${1}/"

    echo -e "\u251C\u2500\u2500\u2500${Purple}Checking${Color_Off} $dir"

    grep -Fxq "$dir" "$dbfile"

    if [ $? -eq 0 ]; then
        echo -e "\u2502   \u2514\u2500\u2500\u2500${Yellow}Found in DB, skipping${Color_Off}"
        return 0
    else
        cd "$1"
        currentPath+=("${1}")
    fi

    local FILES=()
    local DIRS=()

    for ELEMENT in *; do

        if [[ "$ELEMENT" == *"skip"* ]]; then #skip
            continue
        fi

        if [[ -d "$ELEMENT" ]]; then
            DIRS+=("${ELEMENT}")
        fi

        if [[ "$ELEMENT" == *.mkv ]] || [[ "$ELEMENT" == *.avi ]] || [[ "$ELEMENT" == *.mp4 ]] || [[ "$ELEMENT" == *.mov ]]; then

            if [[ -f "$ELEMENT" ]]; then
                checkPath="${dir}${ELEMENT}"
                grep -Fxq "$checkPath" "$dbfile"
                if [ $? -ne 0 ]; then
                    FILES+=("${ELEMENT}")
                fi
            fi
        fi
    done

    local counter=${#FILES[@]}

    echo -e "\u2502   Iterating over ${dir}${Cyan} (f:${#FILES[@]} d:${#DIRS[@]})${Color_Off}"

    local successcounter=0

    for FILE in "${FILES[@]}"; do
        ((counter--))

        local outputExtension=".mkv" #wanted output container
        local fileName="${FILE%.*}"  #the file name without extension
        local outputFile="${fileName}${outputExtension}"
        local tempFile="${fileName}-temp${outputExtension}"
        local outputDifferentFile="${fileName}-converted-FHD${outputExtension}"
        local path="${dir}${FILE}"
        local path_2="${dir}${outputDifferentFile}"

        if [[ $counter -eq 0 ]]; then
            echo -e "\u2502   \u2514\u2500\u2500\u2500Converting '$FILE' ..."
        else
            echo -e "\u2502   \u251C\u2500\u2500\u2500Converting '$FILE' ..."
        fi

        #try converting preferred language
        convertPreferredLanguage "$FILE" "$tempFile"

        if [[ $? -eq 0 ]]; then

            if [[ $counter -eq 0 ]]; then
                echo -e "\u2502       \u2514\u2500\u2500\u2500Conversion performed ${Green}successfully${Color_Off}${removeString}"
            else
                echo -e "\u2502   \u2502   \u2514\u2500\u2500\u2500Conversion performed ${Green}successfully${Color_Off}${removeString}"
            fi

            if [[ $removeMode -eq 1 ]]; then
                rm "$FILE"
                mv "$tempFile" "$outputFile"
            else
                mv "$tempFile" "$outputDifferentFile"
                append $path_2
            fi

            append $path

        else

            if [[ $counter -eq 0 ]]; then
                echo -e "\u2502       \u251C\u2500\u2500\u2500${Red}Conversion failure${Color_Off}, trying to convert all streams"
            else
                echo -e "\u2502   \u2502   \u251C\u2500\u2500\u2500${Red}Conversion failure${Color_Off}, trying to convert all streams"
            fi

            #retry converting all outputs
            convert "$FILE" "$tempFile"

            if [[ $? -eq 0 ]]; then

                if [[ $counter -eq 0 ]]; then
                    echo -e "\u2502       \u2514\u2500\u2500\u2500Conversion performed ${Green}successfully${Color_Off}${removeString}"
                else
                    echo -e "\u2502   \u2502   \u2514\u2500\u2500\u2500Conversion performed ${Green}successfully${Color_Off}${removeString}"
                fi

                if [[ $removeMode -eq 1 ]]; then
                    rm "$FILE"
                    mv "$tempFile" "$outputFile"
                else
                    mv "$tempFile" "$outputDifferentFile"
                    append $path_2
                fi

                append $path

            else

                if [[ $counter -eq 0 ]]; then
                    echo -e "\u2502       \u251C\u2500\u2500\u2500${Red}Conversion failure${Color_Off}, trying to convert only first stream, removal disabled"
                else
                    echo -e "\u2502   \u2502   \u251C\u2500\u2500\u2500${Red}Conversion failure${Color_Off}, trying to convert only first stream, removal disabled"
                fi

                #retry converting only first stream
                convertOnlyFirst "$FILE" "$tempFile"

                if [[ $? -eq 0 ]]; then

                    if [[ $counter -eq 0 ]]; then
                        echo -e "\u2502       \u2514\u2500\u2500\u2500Conversion performed ${Green}successfully${Color_Off}"
                    else
                        echo -e "\u2502   \u2502   \u2514\u2500\u2500\u2500Conversion performed ${Green}successfully${Color_Off}"
                    fi

                    mv "$tempFile" "$outputDifferentFile"

                    append $path
                    append $path_2

                else

                    if [[ $counter -eq 0 ]]; then
                        echo -e "\u2502       \u2514\u2500\u2500\u2500${Red}Conversion failure${Color_Off}"
                    else
                        echo -e "\u2502   \u2502   \u2514\u2500\u2500\u2500${Red}Conversion failure${Color_Off}"
                    fi
                fi
            fi
        fi

    done

    for DIR in "${DIRS[@]}"; do
        ((recursionLevel++))
        iterate "$DIR"
        ((recursionLevel--))
    done

    cd ..
    unset currentPath[-1]
}

if [[ "$1" == "--help" ]]; then
    echo "Usage:"
    echo "$0 --path=<video root path> [--db=<DB file>] [--hwaccel=<hardware acceleration method>] [--lang=<preferred language>] [--remove]"
    echo ""
    echo "The video root directory is the root which contains all the movies directories"
    echo "The DB file contains a list of already visited folders that must be excluded"
    echo "This script will update the DB at each execution, appending the visited folder names if at least one conversion succeeded"
    echo "If --remove parameter is specified, the script will automatically delete from disk the source file if the conversion is performed with success"
    echo "The HW acceleration method can be cuda, nvdec, vaapi and none. default=none"
    echo "The lang parameter must contain the preferred language for the audio of the output file. default=eng"
    exit 0
fi

#argument parsing

for i in "$@"; do
    case $i in
    -p=* | --path=*)
        videoroot="${i#*=}"
        shift
        ;;
    -d=* | --db=*)
        dbfile="${i#*=}"
        shift
        ;;
    -h=* | --hwaccel=*)
        mode="${i#*=}"
        shift
        ;;
    -l=* | --lang=*)
        lang="${i#*=}"
        shift
        ;;
    --remove)
        removeMode=1
        shift
        ;;
    -* | --*)
        echo "Unknown option $i"
        exit 1
        ;;
    *) ;;

    esac
done

#---

if [[ -z "$mode" ]]; then
    mode="none"
fi

if [[ -z "$lang" ]]; then
    lang="eng"
fi

if [[ -z "$dbfile" ]]; then
    dbfilehere="$(pwd)/converter.db"

    if [[ -f "$dbfilehere" ]]; then
        echo "DB file not provided, using DB in current directory"
        dbfile=$dbfilehere
    else
        echo "Error, DB file not found"
        exit 1
    fi
fi

dbfile=$(realpath "$dbfile") #obtain absolute path

if [[ ! -f "$dbfile" ]]; then
    echo "Error, DB file not found"
    exit 1
fi

if [[ -z "$videoroot" ]]; then
    echo "Error, Root directory not provided"
    exit 1
else
    if [[ ! -d "$videoroot" ]]; then
        echo "Root directory not found"
        exit 1
    fi
fi

videoroot=${videoroot%/} #removes the last occurrence of / if there is one

if [[ $removeMode -eq 1 ]]; then
    removeString=", ${Red}removing${Color_Off} source file from disk"
    echo -e "Source video files will be ${Red}Removed${Color_Off} from disk"
fi

echo ""
echo "Iterating over root directory.."
echo -e "\u2502"

iterate "$videoroot"

echo -e "\u2502"
echo "Iteration ended"
