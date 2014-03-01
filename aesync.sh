#!/bin/bash

config=~/.config/AESync
target="default"
caller=n

mkdir -p "$config/$target"
source ${config}/settings.conf

while getopts ":f:adgls" opt; do
    case ${opt} in
        a) caller=a;;
        d) caller=d;;
        g) caller=g;;
        l) caller=l;;
        s) caller=s;;
        f)
            target="${OPTARG}"
            mkdir -p "$config/$target"
            ;;
        ?)
            echo "Unknown option, or missing argument for: -${OPTARG}"
            ;;
    esac
done
shift $((OPTIND-1))

function calculate_indent {
    local length=$1
    length=${#length}
    local indent=$(($length + 4))
    indent=$(($indent / 8))
    indent=$((4 - $indent))

    while [ $indent -gt 0 ]; do
        echo -n -e "\t"
        indent=$((indent - 1))
    done
}

function add_files {
    for file in "$@"; do
        test -f "$file" || test -d "$file" || continue

        if [ -f "$config/$target/$file" ]; then
            local display="$file"

            # Append ... if the filename is long.
            local length=${#file}
            if [ $length -gt 24 ]; then
                display="${display:0:24}..."
            fi

            # Print out info regarding each file.
            echo -e -n "  ? "
            print_directory "$display"
            calculate_indent "$display"
            echo -e -n "Already exists, overwrite? [Y/n] "
            read -n 1 choice
            echo

            if [ "$choice" == "n" ]; then
                continue
            fi
        elif [ -d "$file" ]; then
            echo -n "  ? Recurse into $file? [Y/n] "
            read -n 1 choice
            echo

            if [ "$choice" == "n" ]; then
                continue
            fi

            mkdir -p "$config/$target/$file"
            add_files $file/*
        else
            echo -n "  + "
            print_directory "$file"
            echo

            # Actually encrypt and add the file.
            openssl enc \
                -aes-256-ctr \
                -e \
                -salt \
                -pass "pass:${encrypt_password}" \
                -in "$file" \
                -out "$config/$target/$(basename $file)"
        fi
    done
}

function remove_files {
    for file in "$@"; do
        if [ -f "$config/$target/$file" ]; then
            echo -n "  - "
            print_directory "$file"
            echo

            rm "$config/$target/$file"
        elif [ -d "$file" ]; then
            echo -n "  ? Recurse into $file? [Y/n] "
            read -n 1 choice
            echo

            if [ "$choice" == "n" ]; then
                continue
            fi

            remove_files $file/*
        #else
        #    local display="$file"

        #    # Append ... if the filename is long.
        #    local length=${#file}
        #    if [ $length -gt 24 ]; then
        #        display="${display:0:24}..."
        #    fi

        #    echo -e -n "  ? $display"
        #    calculate_indent "$display"
        #    echo -e -n "File doesn't seem to be saved?"
        #    echo
        fi
    done

    find "$config/" -type d -empty -delete
}

function get_files {
    for file in "$@"; do
        if [ -f "$config/$target/$file" ]; then
            echo -n "  > "
            print_directory "$file"
            echo

            openssl enc \
                -aes-256-ctr \
                -d \
                -salt \
                -pass "pass:${encrypt_password}" \
                -in "$config/$target/$file" \
                -out "$file"
        elif [ -d "$file" ]; then
            echo -n "  ? Recurse into $file? [Y/n] "
            read -n 1 choice
            echo

            if [ "$choice" == "n" ]; then
                continue
            fi

            get_files $file/*
        #else
        #    local display="$file"

        #    # Append ... if the filename is long.
        #    local length=${#file}
        #    if [ $length -gt 24 ]; then
        #        display="${display:0:24}..."
        #    fi

        #    echo -e -n "  ? "
        #    print_directory "$display"
        #    calculate_indent "$display"
        #    echo -e -n "File doesn't seem to be saved?"
        #    echo
        fi
    done
}

function list_files {
    echo "Files in ${target}:"

    # Set the search string for the `find` command.
    local search_string="*"
    if [ ! -z "$1" ]; then
        search_string="$1"
    fi

    local OIFS=$IFS
    IFS=$'\n'
    for line in $(find $config/$target/ -name "$search_string"); do
        line="${line#$config/$target/}"

        # Print directory names in Blue.
        if [ -z "$line" ]; then
            continue
        elif [ -d "$config/$target/$line" ]; then
            tput setaf 4
            echo "  $line"
        # And file names in green.
        elif [ -f "$config/$target/$line" ]; then
            # But, make sure the leading directories (if there are any) are
            # also blue.
            echo -n "  "
            print_directory "$line"
            echo
            tput setaf 2
        fi

        tput sgr0
    done
    IFS=$OIFS
}

function print_directory {
    path_full="$1"
    path_start="${path_full##*/}"
    path_finish="${path_full%${path_start}}"

    tput setaf 4
    echo -n "$path_finish"
    tput setaf 2
    echo -n "$path_start"
    tput sgr0
}

function take_snapshot {
    local snapname="default"
    echo -n "You are about to take a snapshot of this directory, continue? [Y/n] "
    read -n 1 choice
    echo

    if [ ! -z "$1" ]; then
        snapname="$1"
    fi

    if [ "$choice" != "n" ]; then
        echo -e "\n" > snapshot
        echo "# AESync Snapshot" >> snapshot
        echo "# Created: $(date)" >> snapshot
        echo "# Directory: $(pwd)" >> snapshot
        echo "# By: $(whoami)" >> snapshot
        echo "# Files: " >> snapshot
        nano snapshot

        echo "Creating snapshot tarfile."
        local filename="$snapname-snap-$(date +%s).tar.xz"
        echo "$config/$filename"
        tar -Jcf "$config/$filename" "./"
        add_files "$config/$filename"
        rm "$config/$filename"
        rm snapshot
    fi
}

case $caller in
    a)
        echo "Adding files:"
        add_files $@
        ;;
    d)
        echo "Removing files:"
        remove_files $@
        ;;
    g)
        echo "Fetching files:"
        get_files $@
        ;;
    l)
        list_files "$1"
        ;;
    s)
        take_snapshot "$1"
        ;;
    n)
        ;;
esac
