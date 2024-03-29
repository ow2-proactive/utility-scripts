#!/bin/bash

# This bash script is designed to install PWS & PAIO dependencies for Debian distros.
# If an error occur, the script will exit with the value of the PID to point at the logfile.
# Author: Ali Jawad FAHS, Activeeon


# Set up the script variables
STARTTIME=$(date +%s)
PID=$(echo $$)
EXITCODE=$PID
DATE=$(date)
LOGFILE="/var/log/install-dependencies.$PID.log"

# Set up the Singularity and VNC flags
SINGULARITY_INSTALL="false"
VNC_INSTALL="false"

# Get the OS disribution and release
RELS=$(lsb_release -rs)
DIST=$(lsb_release -is)$RELS
# Set up the logging for the script
sudo touch $LOGFILE
sudo chown $USER:$USER $LOGFILE

# All the output of this shell script is redirected to the LOGFILE
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>$LOGFILE 2>&1

# A function to print a message to the stdout as well as as the LOGFILE
log_print(){
  level=$1
  Message=$2
  echo "$level [$(date)]: $Message"
  echo "$level [$(date)]: $Message" >&3
  if [ "$level" == "ERROR" ]; then
  newline "FAILED"
  echo "Printing the last 50 logs:" >&3
  tail -n 50 $LOGFILE >&3
  echo "the full logs here: $LOGFILE";
  fi
  }

# A function to print new line with title
newline(){
	Message=$1
	n=${#Message}
	if [ -z "$COLUMNS" ]; then COLUMNS=100; fi
	DL=$COLUMNS
	num=$(expr $DL - $n - 4)
	reminder=$(expr $num % 2)
	num=$(expr $num / 2)
	num1=$(expr $num + $reminder)

	echo ""
	printf %"$num1"s |tr " " "#"
	echo -n "  $Message  "
	printf %"$num"s |tr " " "#"
	echo ""
	echo "" >&3
	printf %"$num1"s |tr " " "#" >&3
	echo -n "  $Message  " >&3
	printf %"$num"s |tr " " "#" >&3
	echo "" >&3
  }

# A function to check for the apt lock
Check_lock() {
i=0
log_print INFO "Checking for apt lock"
while [ `ps aux | grep [l]ock_is_held | wc -l` != 0 ]; do
    echo "Lock_is_held $i"
    ps aux | grep [l]ock_is_held
    sleep 10
    ((i=i+10));
done
log_print INFO "Exited the while loop, time spent: $i"
echo "ps aux | grep apt"
ps aux | grep apt
log_print INFO "Waiting for lock task ended properly."
}

newline "STARTED"
# Start the Configuration
log_print INFO "Configuration started!"
log_print INFO "Logs are saved at: $LOGFILE"

case $DIST in
	"Ubuntu18.04" | "Ubuntu20.04" | "Ubuntu22.04" | "Debian10" | "Debian11")
		log_print INFO "The OS Distribution and Release: $DIST"
		;;
  *)
    log_print INFO "The OS Distribution and Release: $DIST"
    log_print WARN "The OS Distribution $DIST is not supported"
    ;;
esac

newline "FLAGS"
# Setting the getopts
USAGE=$'ProActive Dependencies Installer: \n -s \t to install singularity \n -v \t to install vnc4server'

while getopts :svx: opt_char
do
  case $opt_char in
  s)
    SINGULARITY_INSTALL="true"
    ;;
  v)
    VNC_INSTALL="true"
    ;;
  \?)
    echo "$OPTARG is not a valid option."
    echo "$USAGE"
    exit 0
    ;;
  esac
done

log_print INFO "The SINGULARITY_INSTALL flag is set to: $SINGULARITY_INSTALL"
log_print INFO "The VNC_INSTALL flag is set to: $VNC_INSTALL"

newline "APT"
# Update the package list
log_print INFO "Updating the package list."
sudo apt-get update
sudo unattended-upgrade -d

# Check for lock
Check_lock

newline "USEFUL PACKAGES"

# Install software-properties-common
log_print INFO "Installing software-properties-common"
sudo apt-get install -y software-properties-common || log_print WARN "software-properties-common installation failed!"

# Install curl
log_print INFO "Installing curl"
sudo apt-get install -y curl || log_print WARN "curl installation failed!"

# Install net-tools
log_print INFO "Installing net-tools"
sudo apt-get install -y net-tools || log_print WARN "net-tools installation failed!"

# Install pkg-config
log_print INFO "Installing pkg-config"
sudo apt-get install -y pkg-config || log_print WARN "pkg-config installation failed!"

# Install git
log_print INFO "Installing git"
sudo apt-get install -y git || log_print WARN "git installation failed!"

# Install jq
log_print INFO "Installing jq"
sudo apt-get install -y jq || log_print WARN "jq installation failed!"

# Install zip
log_print INFO "Installing zip"
sudo apt-get install -y zip || log_print WARN "jq installation failed!"

# Install unzip
log_print INFO "Installing unzip"
sudo apt-get install -y unzip || log_print WARN "jq installation failed!"



newline "DOCKER"
# Install Docker
log_print INFO "Installing docker"
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl status docker
sudo systemctl start docker

log_print INFO "Adding user $(whoami) to the docker group"
sudo usermod -a -G docker $(whoami)

#Check if user proactive exist and add it to docker group if so
if id -u "proactive" >/dev/null 2>&1; then
  echo "user proactive exist"
  sudo usermod -a -G docker proactive
else
  log_print WARN "user proactive does not exist"
fi

sudo docker -v || { log_print ERROR "Docker installation failed!"; exit $EXITCODE; }


newline "PYTHON"
# Check if python3 is installed
log_print INFO "Installing python3"
INS=0
python3 -V || { log_print WARN "python3 was not installed => installing now!"; sudo apt-get install -y python3; INS=1; }
if [ $INS -eq 1 ]; then python3 -V || { log_print ERROR "Unable to install python3!"; exit $EXITCODE; }; fi

# Set python3 as python
sudo apt-get install -y python-is-python3 && python -V || log_print WARN "Could not set python as python3";

if [ ! -z "$(diff <( python3 -V ) <( python -V))" ]; then log_print WARN "pyhton is not python3"; else log_print INFO "python is python3";fi

# Install pip3
log_print INFO "Installing pip3"
sudo apt-get install -y python3-pip
pip3 -V || { log_print ERROR "Unable to install pip3!"; exit $EXITCODE; }
if [ ! -z "$(diff <( pip3 -V ) <( pip -V))" ]; then log_print WARN "pip is not pip3"; else log_print INFO "pip is pip3";fi


newline "PIP PACKAGES"
# Install py4j
log_print INFO "Installing py4j"
pip3 install py4j || { log_print ERROR "py4j installation failed!"; exit $EXITCODE; }

# Install cryptography
log_print INFO "Installing cryptography"
pip3 install cryptography || { log_print ERROR "cryptography installation failed!"; exit $EXITCODE; }

# Install requests
log_print INFO "Installing requests"
pip3 install requests || { log_print ERROR "requests installation failed!"; exit $EXITCODE; }

# Install urllib3
log_print INFO "Installing urllib3"
pip3 install urllib3 || { log_print ERROR "urllib3 installation failed!"; exit $EXITCODE; }

# Install wget
log_print INFO "Installing wget"
pip3 install wget || { log_print ERROR "wget installation failed!"; exit $EXITCODE; }


# Install singularity if required
if [ "$SINGULARITY_INSTALL" = "true" ]; then

	newline "SINGULARITY DEPENDENCIES"

	# Install build-essential
	log_print INFO "Installing build-essential"
	sudo apt-get install -y build-essential || log_print WARN "build-essential installation failed!"

	# Install libssl-dev 
	log_print INFO "Installing libssl-dev "
	sudo apt-get install -y libssl-dev || log_print WARN "libssl-dev  installation failed!"

	# Install uuid-dev
	log_print INFO "Installing uuid-dev"
	sudo apt-get install -y uuid-dev || log_print WARN "uuid-dev installation failed!"

	# Install libgpgme11-dev
	log_print INFO "Installing libgpgme11-dev"
	sudo apt-get install -y libgpgme11-dev || log_print WARN "libgpgme11-dev installation failed!"

	# Install squashfs-tools
	log_print INFO "Installing squashfs-tools"
	sudo apt-get install -y squashfs-tools || log_print WARN "squashfs-tools installation failed!"

	# Install libseccomp-dev
	log_print INFO "Installing libseccomp-dev"
	sudo apt-get install -y libseccomp-dev || log_print WARN "libseccomp-dev installation failed!"

	# Install cryptsetup
	log_print INFO "Installing cryptsetup"
	sudo apt-get install -y cryptsetup || log_print WARN "cryptsetup installation failed!"

	# Install debootstrap
	 log_print INFO "Installing debootstrap"
	sudo apt-get install -y debootstrap || log_print WARN "debootstrap installation failed!"

	newline "GOLANG"
	# Install golang
	log_print INFO "Installing golang"

	# golang version variables
	VERSION=1.18.1
	OS=linux
	ARCH=amd64
	GO_TEMP="/tmp/go"
	GO_TAR_URL="https://dl.google.com/go/go${VERSION}.${OS}-${ARCH}.tar.gz"
	GO_TAR_NAME="golang.tar.gz"

	# sudo apt-get install -y golang-go || log_print ERROR "golang installation failed!"
	if [ -d "/usr/local/go" ]; then sudo rm -r /usr/local/go; fi
	if [ -d "$GO_TEMP" ]; then sudo rm -r $GO_TEMP; fi
	mkdir $GO_TEMP

	log_print INFO "Downloading golang"
	sudo wget -O $GO_TEMP/$GO_TAR_NAME $GO_TAR_URL || log_print ERROR "Failed downloading golang tar!"
	log_print INFO "Extracting golang"
	sudo tar --directory=/usr/local -xzvf $GO_TEMP/$GO_TAR_NAME || log_print ERROR "Failed extracting golang tar!"
	log_print INFO "Exporting golang"
	echo 'export GOPATH=${HOME}/go' >> ~/.bashrc
	echo 'export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin' >> ~/.bashrc
	source ~/.bashrc
	export GOPATH=${HOME}/go
	export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin

	newline "SINGULARITY"
	# Define the links and variables 
	SING_TEMP="/tmp/singularity"
	SING_TAR_URL="https://github.com/singularityware/singularity/releases/download/v3.5.3/singularity-3.5.3.tar.gz"
	SING_TAR_NAME="singularity.tar.gz"

	mkdir $SING_TEMP || log_print ERROR "Failed creating a tmp dir for singularity failed!"


	log_print INFO "Downloading singularity"
	wget -O $SING_TEMP/$SING_TAR_NAME $SING_TAR_URL || log_print ERROR "Failed downloading singularity tar!"
	log_print INFO "Extracting singularity"
	tar --directory=$SING_TEMP -xzvf $SING_TEMP/$SING_TAR_NAME || log_print ERROR "Failed extracting singularity tar!"
	log_print INFO "Configuring singularity"
	cd $SING_TEMP/singularity
	./mconfig || log_print ERROR "Failed configuring singularity!"
	cd builddir
	log_print INFO "Installing singularity"
	make || log_print ERROR "Failed installing singularity!"
	sudo make install || log_print ERROR "Failed installing singularity!"
	. etc/bash_completion.d/singularity
	sudo cp etc/bash_completion.d/singularity /etc/bash_completion.d/
	cd 
	sudo rm -r $SING_TEMP
fi


# Install vnc if required
if [ "$VNC_INSTALL" = "true" ]; then
	newline "VNC"
	case $DIST in
		"Ubuntu20.04" | "Ubuntu22.04" | "Debian10" | "Debian11")
			# Install vnc4server
			log_print INFO "Installing vnc4server"
			REPO=1
			sudo apt-add-repository --yes "deb http://archive.ubuntu.com/ubuntu/ bionic universe" || { log_print WARN "vnc4server repo failed!"; REPO=0;}
			sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32 || { log_print WARN "vnc4server repo failed!"; REPO=0;}
			sudo apt-get update
			if [ $REPO -eq 1 ];then sudo apt-get install -y vnc4server || log_print WARN "x11vnc installation failed!"; fi
			sudo apt-add-repository --remove --yes "deb http://archive.ubuntu.com/ubuntu/ bionic universe"
			sudo apt-get update
		;;
		"Ubuntu18.04")
			# Install vnc4server
			log_print INFO "Installing vnc4server"
			sudo apt-get install -y vnc4server || log_print WARN "x11vnc installation failed!"
		;;
		*)
			# Install vnc4server
			log_print INFO "Installing vnc4server"
			log_print WARN "This operation may fail due to the distribution $DIST"
			REPO=1
			sudo apt-add-repository --yes "deb http://cn.archive.ubuntu.com/ubuntu/ bionic universe" || { log_print WARN "vnc4server repo failed!"; REPO=0;}
			sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32 || { log_print WARN "vnc4server repo failed!"; REPO=0;}
			sudo apt-get update
			if [ $REPO -eq 1 ];then sudo apt-get install -y vnc4server || log_print WARN "x11vnc installation failed!"; fi
			sudo apt-add-repository --remove --yes "deb http://cn.archive.ubuntu.com/ubuntu/ bionic universe"
			sudo apt-get update
		;;
	esac
	fi


newline "VERSIONS"
# List installed versions
log_print INFO "Listing installed versions"

log_print INFO "curl version: $(curl -V | head -n 1 | cut -d" " -f2)"
log_print INFO "net-tools version: $(apt list 2>&1 | grep "net-tools" | grep -v -e "ddnet" | cut -d " " -f 2)"
log_print INFO "docker version: $(docker -v | head -n 1 | cut -d" " -f3 | sed 's/,//') "
log_print INFO "python3 version: $(python3 -V | cut -d " " -f 2)"
log_print INFO "pip3 version: $(pip3 -V | head -n 1 | cut -d" " -f 2)"
log_print INFO "py4j version: $(pip3 list --format freeze | grep py4j | cut -d "=" -f3)"
log_print INFO "cryptography version: $(pip3 list --format freeze | grep cryptography | cut -d "=" -f3)"
log_print INFO "requests version: $(pip3 list --format freeze | grep requests | head -n 1 | cut -d "=" -f3)"
log_print INFO "urllib3 version: $(pip3 list --format freeze | grep urllib3 | cut -d "=" -f3)"
log_print INFO "wget version: $(pip3 list --format freeze | grep wget | cut -d "=" -f3)"
log_print INFO "jq version: $(apt list 2>&1 | grep "jq" | head -n 1 | cut -d " " -f 2)"
log_print INFO "zip version: $(apt list 2>&1 | grep "zip" | head -n 1 | cut -d " " -f 2)"
log_print INFO "unzip version: $(apt list 2>&1 | grep "unzip" | head -n 1 | cut -d " " -f 2)"

if [ "$SINGULARITY_INSTALL" = "true" ]; then
log_print INFO "golang version: $(go version | cut -d" " -f 3)"
log_print INFO "singularity version: $(singularity version)"
log_print INFO "build-essential version: $(apt list 2>&1 | grep "build-essential" | head -n 1 | cut -d " " -f 2)"
log_print INFO "libssl-dev version: $(apt list 2>&1 | grep "libssl-dev" | head -n 1 | cut -d " " -f 2)"
log_print INFO "uuid-dev version: $(apt list 2>&1 | grep "uuid-dev" | head -n 1 | cut -d " " -f 2)"
log_print INFO "libgpgme11 version: $(apt list 2>&1 | grep "libgpgme11" | head -n 1 | cut -d " " -f 2)"
log_print INFO "squashfs-tools version: $(apt list 2>&1 | grep "squashfs-tools" | head -n 1 | cut -d " " -f 2)"
log_print INFO "libseccomp version: $(apt list 2>&1 | grep "libseccomp" | head -n 1 | cut -d " " -f 2)"
log_print INFO "cryptsetup version: $(apt list 2>&1 | grep "cryptsetup" | head -n 1 | cut -d " " -f 2)"
log_print INFO "debootstrap version: $(apt list 2>&1 | grep "debootstrap" | head -n 1 | cut -d " " -f 2)"
fi

if [ "$VNC_INSTALL" = "true" ]; then
log_print INFO "vnc4server version: $(apt list 2>&1 | grep  vnc4server | cut -d" " -f2)"
fi

newline "FINISHED"
# Declare configuration done successfully
ENDTIME=$(date +%s)
ELAPSED=$(( ENDTIME - STARTTIME ))
log_print INFO "Configuration done successfully in $ELAPSED seconds "

