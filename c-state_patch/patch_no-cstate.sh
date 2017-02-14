#!/bin/bash
###########
#######################################################
#
# NGEN Networks, LLC
# Copyright (c) 2017, NGEN Networks, LLC
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#   -Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#   -Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#   -Neither the name of the NGEN Networks, LLC, nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#######################################################
# 
# Revision History
# ----------------
# 2017-02-17 - Initial version
#
#######################################################
echo
echo "#######################################################"
echo "# Intel C-State Preemption Tool                       #"
echo "# NGEN Networks, LLC - 2017                           #"
echo "#######################################################"
echo

if [[ $EUID -ne 0 ]]
then
  echo "This script must be executed as root. Exiting without changes." 1>&2
  echo
  exit 1
fi

CONFIRMED=0
function confirm () {
  if [ "$CONFIRMED" == "YES" ]
  then
    return 0
  fi
  echo "==================="
  echo "WARRANTY DISCLAIMER"
  echo "==================="
  echo "No Warranty"
  echo "As-Is: The Software is provided 'as is,' with all"
  echo "faults, defects and errors, and without warranty of any kind."
  echo
  echo "No Liability: Licensor does not warrant that the Software"
  echo "will be free of bugs, errors, viruses or other defects,"
  echo "and Licensor shall have no liability of any kind for the"
  echo "use of or inability to use the software, the software"
  echo "content or any associated service."
  echo "==================="
  echo
  echo "This tool will disable potential power-saving features"
  echo "for Intel CPU's. Do not use this tool unless you understand"
  echo "the implications of disabling c-states." 
  echo
  echo "This process will overwrite $BOOTCFG with a patched version."
  echo "A backup copy will be created in the next step."
  echo
  echo -n "Continue? (YES/no) "
  read CONFIRMED

  if [ "$CONFIRMED" != "YES" ]
  then
    echo "Confirmation not received. Exiting."
    exit 1
  fi
}

function backup_cfg () {
  BOOTCFG=$1
  if [[ ! -f $BOOTCFG ]] || [[ ! -s $BOOTCFG ]]
  then
    echo "Invalid boot file detected: $BOOTCFG"
    exit 1
  fi
  BOOTCFG_BAK="$BOOTCFG.bak-$TS"
  echo "Saving backup copy of current boot config to $BOOTCFG_BAK"
  echo
  logger "NGEN C-State Preemption - saved copy of boot config to $BOOTCFG_BAK"
  TARFILE="/root/ngen_c-state-preempt.$TS.tgz"
  logger "NGEN C-State Preemption - created Grub tarball at $TARFILE"
  tar czf /boot/grub /boot/grub2 /etc/grub2.cfg /etc/grub.d /etc/default/grub > /dev/null 2>&1
  cp $BOOTCFG $BOOTCFG_BAK
  if [ $? -ne 0 ]
  then
    echo "Error creating backup configuration file $BOOTCFG_BAK"
    exit 1
  fi
}

function patch_rhel5 () {
  CONFIGS="/boot/grub/menu.lst /boot/grub/grub.conf"
  for BOOTCFG in $CONFIGS
  do
    confirm $BOOTCFG
    check_patch $BOOTCFG
    backup_cfg $BOOTCFG
    echo "Updating $BOOTCFG..."
    sed -i '/^\s*kernel / s/\s*$/ processor.max_cstate=1 intel_idle.max_cstate=0/' $BOOTCFG
    if [ $? -ne 0 ]
    then
      echo "ERROR: Failed to modify $BOOTCFG."
      exit 1
    else
      echo "Update successful. Change will become effective on next reboot."
    fi
  done
}

function patch_rhel6 () {
  CONFIGS="/boot/grub/menu.lst /boot/grub/grub.conf"
  for BOOTCFG in $CONFIGS
  do
    confirm $BOOTCFG
    check_patch $BOOTCFG
    backup_cfg $BOOTCFG
    echo "Updating $BOOTCFG..."
    sed -i '/^\s*kernel / s/\s*$/ processor.max_cstate=1 intel_idle.max_cstate=0/' $BOOTCFG
    if [ $? -ne 0 ]
    then
      echo "ERROR: Failed to modify $BOOTCFG."
      exit 1
    else
      echo "Update successful ($BOOTCFG). Change will become effective on next reboot."
    fi
  done
}

function patch_rhel7 () {
  BOOTCFG='/etc/default/grub'
  confirm $BOOTCFG
  check_patch $BOOTCFG
  backup_cfg $BOOTCFG
  echo "Updating $BOOTCFG..."
  sed -i '/^GRUB_CMDLINE_LINUX=/ s/"$/ processor.max_cstate=1 intel_idle.max_cstate=0"/' $BOOTCFG
  if [ $? -ne 0 ]
  then
    echo "ERROR: Failed to modify $BOOTCFG."
    exit 1
  fi
  echo "Rebuilding grub2 configuration..."
  grub2-mkconfig -o /boot/grub2/grub.cfg
  if [ $? -ne 0 ]
  then
    echo "ERROR: Failed to rebuild Grub2 config."
    exit 1
  else
    echo "Update successful. Change will become effective on next reboot."
  fi
}

function check_runtime () {
  RT_CONFIG=0
  if grep -i -q 'processor.max_cstate=1' /proc/cmdline
  then
    echo "process.max_cstate=1 detected in running kernel"
  else
    RT_CONFIG=1
  fi
  if grep -i -q 'intel_idle.max_cstate=0' /proc/cmdline
  then
    echo "intel_idle.max_cstate=0 detected in running kernel"
  else
    RT_CONFIG=1
  fi
  if [ $RT_CONFIG -eq 1 ]
  then
    echo "No C-State customization detected in running kernel."
  fi
}

function check_patch () {
  if grep -q 'processor.max_cstate=1 intel_idle.max_cstate=0' $1
  then
    echo "Patch detected in boot config. Exiting without changes."
    exit 0
  fi
}

echo
echo "This script will add parameters to disable Intel C-State power saving technology at boot."
echo

check_runtime
echo
TS=`date +%s`

if [ "$(cat /etc/redhat-release | grep 'CentOS Linux release 5' | wc -l)" == 1 ]
then
  echo "CentOS 5 Detected"
  echo
  patch_rhel5
elif [ "$(cat /etc/redhat-release | grep 'CentOS release 6' | wc -l)" == 1 ]
then
  echo "CentOS 6 Detected"
  echo
  patch_rhel6
elif [ "$(cat /etc/redhat-release | grep 'CentOS Linux release 7' | wc -l)" == 1 ]
then
  echo "CentOS 7 Detected"
  echo
  patch_rhel7
else
  echo "No supported distribution detected."
  exit 1
fi

exit 0
