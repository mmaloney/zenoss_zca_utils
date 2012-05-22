#!/bin/bash
####################################################
#
# A silly little script to make installing a 
# Zenoss Core 4.x beta development/testing machine
# to save me a little time next time a new release is cut
# VERY Centos/RHEL centric/dependant.
# Its assumed you are running this on a bare/clean machine
#
#
###################################################

try() {
	"$@"
	if [ $? -ne 0 ]; then
		echo "Command failure: $@"
		exit 1
	fi
}

cd /tmp

arch="x86_64"

#Now that RHEL6 RPMs are released, lets try to be smart and pick RPMs based on that
if [ -f /etc/redhat-release ]; then
	elv=`cat /etc/redhat-release | gawk 'BEGIN {FS="release "} {print $2}' | gawk 'BEGIN {FS="."} {print $1}'`
	#EnterpriseLinux Version String. Just a shortcut to be used later
	els=el$elv
else
	#Bail
	echo "Unable to determine version. I can't continue"
	exit 1
fi

if [ "$elv" == "6" ]; then
	epel_v=6-6
elif [ "$elv" == "5" ]; then
	epel_v=5-4
else
	echo "Unrecognized enterprise Linux: $els. Exiting."
	exit 1
fi

epel_rpm_file=epel-release-$epel_v.noarch.rpm
epel_rpm_url=http://download.fedoraproject.org/pub/epel/$elv/i386/$epel_rpm_file

echo "Enabling EPEL Repo"
if [ `rpm -qa | grep -c -i epel` -eq 0 ]; then
	try wget -N $epel_rpm_url
	try rpm -ivh $epel_rpm_file
fi

# Defaults for user provided input
# ftp mirror for MySQL to use for version auto-detection:
#mysql_ftp_mirror="ftp://mirror.anl.gov/pub/mysql/Downloads/MySQL-5.5/"

# Auto-detect latest build:
#zenoss_base_url="http://downloads.sourceforge.net/project/zenoss/zenoss-beta"
#try wget -N $zenoss_base_url/builds/+
#build="$(cat +)"
#zenoss_base_url="$zenoss_base_url/builds/$build"
build=4.1.1-1396

zenoss_parts="zenoss zenoss-core-zenpacks zenoss-enterprise-zenpacks"
zenoss_rpm_files=""
for part in $zenoss_parts; do
	if [ "$part" == "zenoss" ]; then
		zenoss_rpm_file="zenoss-$build.$els.$arch.rpm"
	else
		zenoss_rpm_files="$zenoss_rpm_files $part-$build.$els.$arch.rpm"
	fi	
done
zends_rpm_file="zends-5.5.15-1.r51230.el5.x86_64.rpm"

# Let's grab Zenoss first...

zenoss_gpg_key="http://dev.zenoss.org/yum/RPM-GPG-KEY-zenoss"
for file in $zenoss_rpm_files; do
	if [ ! -f $file ];then
		echo "Downloading $file"
		try wget -N $zenoss_base_url/$file
	fi
done

if [ `rpm -qa gpg-pubkey* | grep -c "aa5a1ad7-4829c08a"` -eq 0  ];then
	echo "Importing Zenoss GPG Key"
	try rpm --import $zenoss_gpg_key
fi
#echo "Auto-detecting most recent MySQL Community release"
#try rm -f .listing
#try wget --no-remove-listing $mysql_ftp_mirror >/dev/null 2>&1
#mysql_v=`cat .listing | awk '{ print $9 }' | grep MySQL-client | grep el6.x86_64.rpm | sort | tail -n 1`
# tweaks to isolate MySQL version:
#mysql_v="${mysql_v##MySQL-client-}"
#mysql_v="${mysql_v%%.el6.*}"
#if [ "${mysql_v:0:1}" != "5" ]; then
#	# sanity check
#	mysql_v="5.5.24"
#fi
#rm -f .listing

#echo "Ensuring This server is in a clean state before we start"
#mysql_installed=0
#if [ `rpm -qa | egrep -c -i "^mysql-(libs|server)?"` -gt 0 ]; then
#	if [ `rpm -qa | egrep -i "^mysql-(libs|server)?" | grep -c -v 5.5` -gt 0 ]; then
#		echo "It appears you already have an older version of MySQL packages installed"
#		echo "I'm too scared to continue. Please remove the following existing MySQL Packages:"
#		rpm -qa | egrep -i "^mysql-(libs|server)?"
#		exit 1
#	else
#		if [ `rpm -qa | egrep -c -i "mysql-server"` -gt 0 ];then
#			echo "It appears MySQL 5.5 server is already installed. MySQL Installation  will be skipped"
#			mysql_installed=1
#		else
#			echo "It appears you have some MySQL 5.5 packages, but not MySQL Server. I'll try to install"
#		fi
#	fi
#fi

echo "Ensuring Zenoss RPMs are not already present"
if [ `rpm -qa | grep -c -i zenoss` -gt 0 ]; then
	echo "I see Zenoss Packages already installed. I can't handle that"
	exit 1
fi

# Where to get stuff. Base decisions on arch. Originally I was going to just
# use the arch variable, but its a little dicey in that file names don't always
# translate clearly. So just using if with a little duplication
if [ "$arch" = "x86_64" ]; then
	jre_file="jre-6u31-linux-x64-rpm.bin"
	jre_url="http://javadl.sun.com/webapps/download/AutoDL?BundleId=59622"
#	mysql_client_rpm="MySQL-client-$mysql_v.linux2.6.x86_64.rpm"
#	mysql_server_rpm="MySQL-server-$mysql_v.linux2.6.x86_64.rpm"
#	mysql_shared_rpm="MySQL-shared-$mysql_v.linux2.6.x86_64.rpm"
	#rpmforge_rpm_file="rpmforge-release-0.5.2-2.$els.rf.x86_64.rpm"
else
	echo "Don't know where to get files for arch $arch"
	exit 1
fi
echo "Installing Required Packages"
try yum -y install libaio tk unixODBC erlang rabbitmq-server memcached perl-DBI net-snmp \
net-snmp-utils gmp libgomp libgcj.$arch libxslt dmidecode sysstat

#Some Package names are depend on el release
if [ "$elv" == "5" ]; then
	try yum -y install liberation-fonts
elif [ "$elv" == "6" ]; then
	try yum -y install liberation-fonts-common pkgconfig liberation-mono-fonts liberation-sans-fonts liberation-serif-fonts
fi

echo "Downloading Files"
if [ `rpm -qa | grep -c -i jre` -eq 0 ]; then
	if [ ! -f $jre_file ];then
		echo "Downloading Oracle JRE"
		try wget -N -O $jre_file $jre_url
		try chmod +x $jre_file
	fi
	if [ `rpm -qa | grep -c jre` -eq 0 ]; then
		echo "Installating JRE"
		try ./$jre_file
	fi
else
	echo "Appears you already have a JRE installed. I'm not going to install another one"
fi

services="rabbitmq-server memcached snmpd"
#echo "Downloading and installing MySQL RPMs"
#if [ $mysql_installed -eq 0 ]; then
#	#Only install if MySQL Is not already installed
#	for file in $mysql_client_rpm $mysql_server_rpm $mysql_shared_rpm;
#	do
#		if [ ! -f $file ];then
#			try wget -N http://dev.mysql.com/get/Downloads/MySQL-5.5/$file/from/http://mirror.services.wisc.edu/mysql/
#		fi
#		if [ ! -f $file ];then
#			echo "Failed to download $file. I can't continue"
#			exit 1
#		fi
#		rpm_entry=`echo $file | sed s/.x86_64.rpm//g | sed s/.i386.rpm//g | sed s/.i586.rpm//g`
#		if [ `rpm -qa | grep -c $rpm_entry` -eq 0 ];then
#			try rpm -ivh $file
#		fi
#	done
	services="$services mysql"
	echo "Configuring MySQL"
	try /sbin/service mysql restart
	try /usr/bin/mysqladmin -u root password ''
	try /usr/bin/mysqladmin -u root -h localhost password ''
#fi

#echo "Installing Zenoss Dependency Repo"
#There is no EL6 rpm for this as of now. I'm not even entirelly sure we really need it if we have epel
#rpm -ivh http://deps.zenoss.com/yum/zenossdeps.el5.noarch.rpm

echo "Configuring and Starting some Base Services"
for service in $services; do
	try /sbin/chkconfig $service on
	try /sbin/service $service start
done

# set up rrdtool, etc.

#if [ "$elv" = "6" ]; then
#	echo "Installing rrdtool"
#	try yum -y install xorg-x11-fonts-Type1 ruby libdbi
#	try wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.$arch.rpm
#	try rpm -ivh rpmforge-release-0.5.2-2.el6.rf.$arch.rpm
#	
#	try wget http://pkgs.repoforge.org/rrdtool/rrdtool-1.4.7-1.el6.rfx.$arch.rpm
#	try wget http://pkgs.repoforge.org/rrdtool/perl-rrdtool-1.4.7-1.el6.rfx.$arch.rpm
#
#	try yum -y localinstall rrdtool-1.4.7-1.el6.rfx.$arch.rpm perl-rrdtool-1.4.7-1.el6.rfx.$arch.rpm
#fi
# TODO: el5 rrdtool install

echo "Installing zends"

try rpm -ivh $zends_rpm_file
try /sbin/service zends start
try chkconfig zends on

echo "Installing Zenoss"
try rpm -ivh $zenoss_rpm_file

try /sbin/service zenoss start

for r in $zenoss_rpm_files; do
	echo "Installing $r"
	try rpm -ivh $r
done
