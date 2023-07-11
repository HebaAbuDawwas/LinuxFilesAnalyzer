#!/bin/bash

show_help() {
	echo -e "Usage:\n ./assignment.sh [directory_path] [extension]"
	echo -e "\nSearches for files with the given extension in the specified directory and generates a file analysis report."
	echo -e "\nIf the directory path or extension is not provided as arguments, the script will prompt for user input."
	echo -e "\nAlso we provide a filter option where you can apply multiple filters."
	echo -e "Options:"
	echo -e "  -h, --help    Show this help message and exit."
}
			


declare -A owner_files_map
declare -A file_details_map
declare -A files_sizes_map
declare -A owner_files_total_size
declare -A owner_files_total_count
sorted_files=()
report_file="file_analysis.txt"

process_files() {
	local directory_path="$1"
	local extension="$2"	

	if [[ -f "$report_file" ]]; then
		rm "$report_file"
	fi

	echo -e "\nSearching for files with extensions: $extensions in $directory_path and its subdirectories...\n"
	local files=$(find "$directory_path" -type f -name "*.$extension")

	if [ -z "$files" ]; then
		echo "No files with extensions: $extensions found in $directory_path and its subdirectories."
	  	exit 1
	fi

	echo -e "\nGenerating file analysis report : $report_file\n"

	echo -e "\nimporting files details\n"

	for file in $files; do 
		local size=$(du -b "$file" | awk '{print $1 }')
		local owner=$(stat -c "%U" "$file")
		local permissions=$(stat -c "%A" "$file")
		local last_modified=$(stat -c "%y" "$file")
		files_sizes_map["$file"]=$size
		file_details_map["$file"]+="File: $file\nSize: $size\nPermissions: $permissions\nLast Modified: $last_modified\n\n"

		if [[ -v owner_files_map["$owner"] ]]; then
			owner_files_map["$owner"]+="|$file"
		else
      			owner_files_map["$owner"]="$file"
       		fi 
	done

}

filter_files(){
        if [ -n "$skip_filter" ]; then
		sorted_files=(${owner_files_array[@]})
	else
		echo -e "filtering $owner files based on ypur filter option"
		included_file=true
		for file in "${owner_files_array[@]}"; do
			if [ -n "$min_size_filter" ] && [ -n "$max_size_filter" ]; then				
				file_size=$(du -b "$file" | awk '{print $1}')	
	      			if [[ "$file_size" -lt "$min_size_filter" || "$file_size" -gt "$max_size_filter" ]]; then
					included_file=false
				fi
			fi
			if [ -n "$permissions_filter" ]; then
				file_permissions=$(stat -c "%A" "$file")
				if [[ "${file_permissions:1}" != *"${permissions_filter:1}"* ]]; then
					included_file=false
				fi
			fi
			if [ -n "$min_timestamp" ] && [ -n "$max_timestamp" ]; then
				file_timestamp=$(date -d "$(stat -c "%y" "$file")" +%s)
				if [[ "$file_timestamp" -lt "$min_timestamp" || "$file_timestamp" -gt "$max_timestamp" ]]; then
					included_file=false
				fi
			fi
			if [ "$included_file" = true ]; then
				sorted_files+=("$file")
			fi
		done
	fi

}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
	show_help
	exit 1
fi

directory_path=$1
extension=$2

if [ -z "$directory_path" ]; then
       	read -p "Enter the directory path you want to search files in: " directory_path; 
	if [ -z "$directory_path" ]; then 
		echo "directory path should be valid ex. /path/to/directory"
		exit 1
	fi
fi
if [ -z "$extension" ]; then
       	read -p "Enter file extention you want a rebort about: " extension; 
	if [-z "$extension" ]; then 
		echo "extension should be valid ex: txt, sh"
		exit 1
	fi
fi

process_files "$directory_path" "$extension"


echo "Enter your search criteria:"
echo "1. Filter by size (in bytes)"
echo "2. Filter by permissions"
echo "3. Filter by last modified timestamp"
echo "4. Skip filtering"
echo "Enter your choice(s) (1-4): ex: 1 2"
echo "note that if you entered multiple filters and one of them is skip filtering then we will skip your input and no filter will be applied"
read -a choices
for choice in "${choices[@]}"; do

	case $choice in
		1)

			echo "Enter the minimum size (in bytes):"
			read min_size_filter
			echo "Enter the maximum size (in bytes):"
			read max_size_filter
			;;
		2)
			echo "Enter the permissions (e.g., rwx):"
			read permissions_filter
			;;
		3)
			echo "Enter the minimum last modified timestamp (YYYY-MM-DD HH:MM:SS):"
			read min_timestamp
			min_timestamp=$(date -d "$min_timestamp" +%s)

			echo "Enter the maximum last modified timestamp (YYYY-MM-DD HH:MM:SS):"
			read max_timestamp
			max_timestamp=$(date -d "$max_timestamp" +%s)
			;;
		4)
			skip_filter=1;
			;;
		*)
			echo "Invalid choice!"
			exit 1
			;;
	esac
done

for owner in "${!owner_files_map[@]}"; do
	printf "\nOwner : $owner\n\n" >> "$report_file"
	IFS='|' read -ra owner_files_array <<< "${owner_files_map[$owner]}"	
  
	sorted_files=()
	filter_files 
	echo -e "\nsorting $owner files based on size in ascending order\n"
	sorted_files=($(printf '%s\n' "${sorted_files[@]}" | xargs -I{} du -b {} | sort -n -k1 | cut -f2-))
	
	echo -e "\nprinting $owner files details in $report_file\n"
	owner_files_total_size["$owner"]=0
	owner_files_total_count["$owner"]=0
	for file in "${sorted_files[@]}"; do
		owner_files_total_size["$owner"]=$((owner_files_total_size["$owner"] + "${files_sizes_map["$file"]}" ))
		owner_files_total_count["$owner"]=$((owner_files_total_count["$owner"] + 1))
		printf "\n${file_details_map["$file"]}\n" >> "$report_file"
	done
        printf "\n----------------SUMMARY-----------------\n" >> "$report_file" >> "$report_file"
	printf "$owner files count : "${owner_files_total_count["$owner"]}" \n" >> "$report_file"
	printf "$owner files total size : "${owner_files_total_size["$owner"]}" \n" >> "$report_file"

	printf "\n\n\n-----------------------------------------------------------------------------\n" >> "$report_file"
done

echo -e "\nthe report is ready, you can check it in $report_file\n"

