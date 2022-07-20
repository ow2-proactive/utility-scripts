#!/bin/bash

# This bash script is designed to retrieve the public ip address from a linux machine using several online services. 
# If the service failed to return a valid IP, then the exit code will increase by one and the next service is used.
# If all the services failed then the script will return 6 as the exit code. 
# Author: Ali Jawad FAHS, Activeeon

# mask the stderr
exec 2>/dev/null

ip_valid() {
  # Set up local variables
  local ip=${1:-1.2.3.4}
  local IFS=.; local -a a=($ip)
  # Start with a regex format test
  [[ $ip =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  # Test values of quads
  local quad
  for quad in {0..3}; do
    [[ "${a[$quad]}" -gt 255 ]] && return 1
  done
  return 0
}

get_from_google(){
	ip_google=`dig -4 TXT +short o-o.myaddr.l.google.com @ns1.google.com | sed 's|"||g'`
}
get_from_ipecho(){
	ip_ipecho=`curl -4 -s http://ipecho.net/plain`
}

get_from_icanhazip(){
	ip_icanhazip=`curl -4 -s http://icanhazip.com/`
}

get_from_dnsomatic(){
	ip_dnsomatic=`curl -4 -s http://myip.dnsomatic.com`
}

get_from_ident(){
	ip_ident=`curl -4 -s http://ident.me`
}

get_from_ifconfig(){
	ip_ifconfig=`curl -s -4 ifconfig.co/`
}


get_from_google && { ip_valid $ip_google && ip=$ip_google && code=0; } || \
{ get_from_ifconfig && ip_valid $ip_ifconfig && ip=$ip_ifconfig && code=1; } || \
{ get_from_ipecho && ip_valid $ip_ipecho && ip=$ip_ipecho && code=2; } || \
{ get_from_ident && ip_valid $ip_ident && ip=$ip_ident && code=3; } || \
{ get_from_dnsomatic && ip_valid $ip_dnsomatic && ip=$ip_dnsomatic && code=4; } || \
{ get_from_icanhazip && ip_valid $ip_icanhazip && ip=$ip_icanhazip && code=5; } || \
{ echo "Error: all the public ip sites failed" && exit 6; }


echo $ip
exit $code

