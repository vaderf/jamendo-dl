#!/bin/bash
# Title: jamendo-dl.sh
# Version: 0.0
# Author: Vaderf <vaderf@free.fr>
# Created in: 2014-12-29
# Modified in:
# Licence : GPL v3



#======#
# Aims #
#======#

aim="Download albums from Jamendo.com"



#==========#
# Versions #
#==========#

# v0.0 - 2014-12-29: creation



#===========#
# Functions #
#===========#

# Usage message
function usage {
    echo -e "
    \e[32m ${0##*/} \e[00m -i|--id value -f|--fmt value -l|--list file -z|--kzip -c|--cat -h|--help

Aim: $aim

Options:
    -i, --id        id number of an album (eg., a1234) or an artist to download all his albums (eg., 5678).
    -f, --fmt       format of music files (mp3, ogg, flac) [default: ogg]
    -l, --list      text file with a list of ids to download (accept comments using #)
    -k, --kzip      keep the zip files downloaded
    -c, --cat       force regeneration of the Jamendo catalog (automatic if the
                        catalog is older than 7 days) (useful when using artist id only)
    -h, --help      this message
   
How to:
    - To get album id, go on Jamendo website, choose an album, look at the address bar of the web browser
        (eg., https://www.jamendo.com/fr/list/a122411/circles) and copy the id beginning by a (a122411)
    - To get album id, go on Jamendo website, choose an album, look at the address bar of the web browser
        (eg., https://www.jamendo.com/fr/artist/342854/alexander-franke) and copy the id with numbers only (342854)
    "
}


# Info message
function info {
    if [[ -t 1 ]]
    then
        echo -e "\e[32mInfo:\e[00m $1"
    else
        echo -e "Info: $1"
    fi
}


# Warning message
function warning {
    if [[ -t 1 ]]
    then
        echo -e "\e[33mWarning:\e[00m $1"
    else
        echo -e "Warning: $1"
    fi
}


# Error message
function error {
    if [[ -t 1 ]]
    then
        echo -e "\e[31mError:\e[00m $1"
        exit $2
    else
        echo -e "Error: $1"
        exit $2
    fi
}


# Dependency test
function test_dep {
    which $1 &> /dev/null
    if [[ $? != 0 ]]
    then
        error "Package $1 is needed. Exiting..." 1
    fi
}


# Album download
# usage: album_dl $myid $myformat
function album_dl {

    # Name parsing
    album_name=$(wget --spider http://storage-new.newjamendo.com/download/$1/$2/ 2>&1 | grep -m 1 "albums" | sed -n "s/.*albums\/\(.*\).zip.*/\1/p")
    
    if [[ ! $(echo "$album_name" | grep .) ]]
    then
		warning "The id \"$1\" does not correspond to an album. Skipping..."
	else
		# Download
		info "Downloading of \"${album_name}\"..."
		wget -c -O "${album_name}.zip" "http://storage-new.newjamendo.com/download/$1/$2/" &> /dev/null
		if [[ $? != 0 ]]
		then
			warning "An error occurred during downloading. Skipping..."
		fi

		# Unzipping
		info "Unzipping album..."
		keep_tmp=0
		if [[ ! -d "$album_name" ]]
		then
			unzip -d "$album_name" "${album_name}.zip" &> /dev/null
			if [[ $? != 0 ]]
			then
				error "An error occurred during unzipping. Skipping..." 1
			fi
		else
			warning "Destination directory already existing. Keep zip file. Skipping..."
			keep_tmp=1
		fi

		# Removing zip file if nothing specified
		if [[ -z $keep && $keep_tmp == 0 ]]
		then
			info "Deleting zip file..."
			rm "${album_name}.zip"
		fi
	fi

    echo ""
}


# Download of complet album list from a given artist
# usage: all_albums_dl $myid $myformat
function all_albums_dl {

    # Download the Jamendo catalog if needed
    mycat_file="dbdump_artistalbumtrack.xml.gz"
    if [[ -n $mycat || ! -e "/tmp/$mycat_file" || $(find /tmp/ -name "$mycat_file" -type f -ctime +7) ]]
    then
        mycat="/tmp/$mycat_file"
        info "Download of the Jamendo catalog. May take a while...\n"
        wget -O "$mycat" "http://imgjam.com/data/dbdump_artistalbumtrack.xml.gz" &> /dev/null
    else
        mycat="/tmp/$mycat_file"
        info "Jamendo catalog already there and not older than 7 days...\n"
    fi

    # Parsing the album ids
    mylist_tmp=$(zcat "$mycat" | grep "<artist><id>"$1"</id>" | grep -o "<album><id>[0-9]*</id>")
    if [[ ! $(echo "$mylist_tmp" | grep .) ]]
    then
		warning "The id \"$1\" does not correspond to any artist. Skipping...\n"
	fi

    # Downloading each album
    for i in $mylist_tmp
    do
        myid_tmp="a$(echo $i | sed -n "s/<album><id>\(.*\)<\/id>/\1/p")"
        album_dl "$myid_tmp" "$2"
    done

}


# Test id
# usage: test_id $myid $myformat
function test_id {
	if [[ $(echo "$1" | grep "^[0-9]") ]]
    then
        all_albums_dl "$1" "$2"
    elif [[ $(echo "$1" | grep "^a") ]]
    then
        album_dl "$1" "$2"
    elif [[ ! $(echo "$1" | grep "^[0-9]\|^a") ]]
    then
		warning "The id \"$1\" is not well formated. Skipping...\n"
		continue
    fi
}



#==============#
# Dependencies #
#==============#

test_dep wget
test_dep unzip



#===========#
# Variables #
#===========#

# Load variables
while [[ $# -gt 0 ]]
do
    case $1 in
        -i|--id     ) myid="$2" ; shift 2 ;;
        -f|--fmt    ) myformat="$2"  
                        if [[ "$myformat" == mp3 ]]
                        then
                            myformat=mp32
                        elif [[ "$myformat" == ogg ]]
                        then
                            myformat=ogg2
                        fi                                
                        shift 2 ;;
        -l|--list   ) mylist="$2" ; shift 2 ;;
        -k|--kzip   ) keep=1 ; shift ;;
        -c|--cat    ) mycat=1 ; shift ;;
        -h|--help   ) usage ; exit 0 ;;
        *           ) error "Invalid option: $1\n$(usage)" 1 ;;
    esac
done


# Check the existence of obligatory options
if [[ -z "$myid" && -z "$mylist" ]]
then
    error "The options -i or -l are required. Exiting...\n$(usage)" 1
fi

if [[ -n "$myid" && -n "$mylist" ]]
then
    error "The options -i and -l cannot be used at the same time. Exiting...\n$(usage)" 1
fi

if [[ -z "$myformat" ]]
then
    myformat="ogg2"
elif [[ "$myformat" != "mp32" && "$myformat" != "ogg2" && "$myformat" != "flac" ]]
then
    error "The format can only be mp3, ogg or flac. Exiting..." 1
fi

if [[ $(echo "$myid" | grep "^a") && -n $all ]]
then
    error "The options -a cannot be used when downloading a single album. Exiting...\n$(usage)" 1
fi



#============#
# Processing #
#============#

# Test file type of the list
if [[ -n "$mylist" && ! -e "$mylist" ]]
then
	error "The file \"$mylist\" does not exist. Exiting..." 1
elif [[ -n "$mylist" && ! $(file -b --mime-type "$mylist" | grep text) ]]
then
	error "The list file \"$mylist\" is not a text file. Exiting..." 1
fi


# Download albums
if [[ -n "$myid" ]]
then
	test_id "$myid" "$myformat"
elif [[ -n "$mylist" ]]
then
    while read myid
    do
		myid=$(echo "$myid" | sed "s/#.*$// ; s/ * //")
		echo $myid
		if [[ ! $(echo "$myid" | grep .) ]]
		then
			continue
		fi
				
		test_id "$myid" "$myformat"
       
    done < "$mylist"
fi


exit 0
