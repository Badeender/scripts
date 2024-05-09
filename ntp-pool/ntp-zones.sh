#!/bin/bash
# ntp_zones.sh - Script to gather NTP server zone information from the NTP Pool Project
#
# This script retrieves the zones of NTP servers based on their IP addresses from the NTP Pool Project website.
# It first checks if the information is already cached locally, downloads the necessary data if not cached,
# and finally, extracts and prints the count, IP address, and associated zones.
#
# Usage:
# 1. Generate 'sorted_pool.txt' containing the sorted and unique counts of IPs:
#    a. Run the following command to collect NTP server IPs:
#       dig +short pool.ntp.org >> pool.txt
#    b. Repeat the command above several times to get a good sample size.
#    c. Generate a sorted and unique list of IP addresses with counts:
#       sort pool.txt | uniq -c | sort -nr > sorted_pool.txt
#
# 2. Make the script executable:
#    chmod +x ntp_zones.sh
#
# 3. Run the script:
#    ./ntp_zones.sh
#
# 4. Optional: Redirect the output to a file:
#    ./ntp_zones.sh > output.txt
#
# Requirements:
# - curl
# - xargs
# - awk
# - grep
#
# The script caches downloaded pages in the 'ntp_cache' directory.
# Verbose output from `curl` is logged to 'ntp_cache/curl_verbose.log'.

# Input file with sorted unique IPs and counts
input_file="sorted_pool_test.txt"

# Directory to cache pages
cache_dir="ntp_cache"
mkdir -p "$cache_dir"

# Log file for verbose curl output
curl_log="$cache_dir/curl_verbose.log"
> "$curl_log"

# Cloudflare IPs (IPv4 and IPv6)
cloudflare_ips=("162.159.200.1" "162.159.200.123" "2606:4700:f1::1" "2606:4700:f1::123")

# Function to check if an IP is a Cloudflare IP
is_cloudflare_ip() {
    local ip="$1"
    for cf_ip in "${cloudflare_ips[@]}"; do
        if [[ "$ip" == "$cf_ip" ]]; then
            return 0
        fi
    done
    return 1
}

# Create a URL list file with output targets
url_list_file="url_list.txt"
> "$url_list_file"
while IFS= read -r line
do
    ip=$(echo "$line" | awk '{print $2}')
    cache_file="$cache_dir/$ip.html"

    if ! is_cloudflare_ip "$ip"; then
        echo "--url https://www.ntppool.org/scores/$ip -z $cache_file -o $cache_file" >> "$url_list_file"
    fi
done < "$input_file"

# Download all pages using a single curl command with parallel processing and verbose logging
curl --compressed --keepalive-time 60 -v $(cat "$url_list_file") >> "$curl_log" 2>&1

# Process each IP to print the count, IP, and zones
while IFS= read -r line
do
    count=$(echo "$line" | awk '{print $1}')
    ip=$(echo "$line" | awk '{print $2}')
    cache_file="$cache_dir/$ip.html"

    if is_cloudflare_ip "$ip"; then
        zones="Cloudflare"
    else
        zones=$(grep 'data-zones=' "$cache_file" | awk -F'data-zones="' '{print $2}' | awk -F'"' '{print $1}')
    fi

    echo "$count $ip $zones"

done < "$input_file"

echo "Verbose output written to $curl_log."
