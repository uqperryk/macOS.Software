#!/bin/bash

###################################################################################################
# Script Name:  license_SPSS.sh
# By:  Zack Thompson / Created:  1/3/2018
# Version:  1.6.0 / Updated:  1/12/2019 / By:  ZT
#
# Description:  This script applies the license for SPSS applications.
#
###################################################################################################

echo "*****  License SPSS process:  START  *****"

##################################################
# Turn on case-insensitive pattern matching
shopt -s nocasematch

# Determine License Type
case "${4}" in
	"T&R" | "Teaching and Research" | "Academic" )
		licenseType="Academic"
	;;
	"Admin" | "Administrative" )
		licenseType="Administrative"
	;;
	* )
		echo "ERROR:  Invalid License Type provided"
		echo "*****  License SPSS process:  FAILED  *****"
		exit 1
	;;
esac

echo "Licensing Type:  ${licenseType}"

# Determine License Mechanism
case "${5}" in
	"LM" | "License Manager" | "Network" )
		licenseMechanism="Network"
	;;
	"Stand Alone" | "Local" )
		licenseMechanism="Local"
	;;
	* )
		echo "ERROR:  Invalid License Mechanism provided"
		echo "*****  License SPSS process:  FAILED  *****"
		exit 2
	;;
esac

# Turn off case-insensitive pattern matching
shopt -u nocasematch

echo "Licensing Mechanism:  ${licenseMechanism}"

##################################################
# Define Functions

function LicenseInfo {
	if [[ $licenseType == "Academic" ]]; then
		licenseManager="server.company.com"
		commuterDays="7"

		# Determine License Code
		case "${versionSPSS}" in
			"25" )
				licenseCode="2512345678910"
			;;
			"24" )
				licenseCode="2412345678910"
			;;
			"23" )
				licenseCode="2312345678910"
			;;
		esac
	elif [[ $licenseType == "Administrative" ]]; then
		licenseManager="server.company.com"
		commuterDays="7"

		# Determine License Code
		case "${versionSPSS}" in
			"25" )
				licenseCode="2512345678911"
			;;
			"24" )
				licenseCode="2412345678911"
			;;
			"23" )
				licenseCode="2312345678911"
			;;
		esac
	fi
}

##################################################
# Bits staged, license software...

# Find all install SPSS versions.
appPaths=$( /usr/bin/find -E /Applications -iregex ".*[/](SPSS) ?(Statistics) ?([0-9]{2})?[.]app" -type d -prune )

# Verify that a SPSS version was found.
if [[ -z "${appPaths}" ]]; then
	echo "A version of SPSS was not found in the expected location!"
	echo "*****  License SPSS process:  FAILED  *****"
	exit 3
else
	# If the machine has multiple SPSS Applications, loop through them...
	while IFS="\n" read -r appPath; do

		##################################################
		# Define Variables
		# Get the SPSS version
		versionSPSS=$( /usr/bin/defaults read "${appPath}/Contents/Info.plist" CFBundleShortVersionString | /usr/bin/awk -F "." '{print $1}' )
		# Get the App Bundle name
		appName=$( echo "${appPath}" | /usr/bin/awk -F "/" '{print $NF}' )
		# Get only the install path
		installPath=$( echo "${appPath}" | /usr/bin/awk -F "/${appName}" '{print $1}' )
		# Set the location of bin folder
		licensePath="${appPath}/Contents/bin"
		# Set the Network License file path
		networkLicense="${licensePath}/spssprod.inf"
		# Set the Local License Location file path
		localLicense="${licensePath}/lservrc"
		##################################################

		# Setting permissions to resolve issues seen in:  https://www-01.ibm.com/support/docview.wss?uid=swg21966637
		echo "Setting permissions on SPSS ${majorVersion} files..."
		/usr/sbin/chown -R root:admin "${installPath}"

		if [[ $licenseMechanism == "Network" ]]; then
			echo "Configuring the License Manager Server for version:  ${versionSPSS}"

			# Function LicenseInfo
			LicenseInfo

			# Inject the License Manager Server Name and number of days allowed to check out a license.
			/usr/bin/sed -i '' 's/DaemonHost=.*/'"DaemonHost=${licenseManager}"'/' "${networkLicense}"
			/usr/bin/sed -i '' 's/CommuterMaxLife=.*/'"CommuterMaxLife=${commuterDays}"'/' "${networkLicense}"

			if [[ -e "${localLicense}" ]]; then
				echo "Local License file exists; deleting..."
				/bin/rm -rf "${localLicense}"
			fi

		elif [[ $licenseMechanism == "Local" ]]; then
			echo "Apply License Code for version:  ${versionSPSS}"

			# Function LicenseInfo
			LicenseInfo

			# Apply License Code
			exitStatus=$( cd "${licensePath}" && "${licensePath}"/licenseactivator "${licenseCode}" )

			if [[ $exitStatus == *"Authorization succeeded"* ]]; then
				echo "License Code applied successfully!"

				# If the network license file exists, remove the License Manager server name.
				if [[ -e "${networkLicense}" ]]; then
					echo "Removing Network License Manager info..."
					/usr/bin/sed -i '' 's/DaemonHost=.*/DaemonHost=/' "${networkLicense}"
				fi

				# Setting permissions to resolve issues as it relates to (this step is not described, but helps to resolve):  https://www-01.ibm.com/support/docview.wss?uid=swg21966637
				echo "Setting permissions on the SPSS ${majorVersion} license file..."
				/bin/chmod 644 "${localLicense}"

			else
				echo "ERROR:  Failed to apply License Code"
				echo "ERROR Contents:  ${exitStatus}"
				echo "*****  License SPSS process:  FAILED  *****"
				exit 4
			fi
		fi
	done < <( echo "${appPaths}" )
fi

echo "SPSS has been activated!"
echo "*****  License SPSS process:  COMPLETE  *****"
exit 0