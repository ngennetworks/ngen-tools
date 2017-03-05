Intel C-State Control (c-state_patch)
=====================================

What does it do?
****************

  This patch/tool reconfigures Linux systems (RedHat/CentOS 5-7 currently supported) to disable Intel C-State technology at boot.

Why do I need it?
*****************

  Some motherboards/BIOS have issues with Intel Xeon processors, particularly members of the E5 series, will reduce power supplied to the CPU under low utilization in the interest of saving power. With certain combinations, this power reduction results in power delivered to the CPU below the minimum operating threshold for the CPU. What happens? The CPU goes into the computing equivalent of a coma and you have to reboot/power cycle the system.

How does it work?
*****************

  * This is a very simple tool which adds a couple of options to the kernel line in the Grub/Grub2 configuration to prevent C-States from being utilized.
  * The net effect is that the CPU runs at full power at all times. This is really only a concern if heat or power consumption is a concern in your particular situation.

Usage
*****

  To use, simply execute the script as root, or with sudo
    ./disable_c-states.sh
  The script will issue generic risk warnings and ask one final time whether you want to continue.

  NOTE: Upon successful completion, a reboot is required to activate the change.

Cautionary Notices
******************

  As with any software/script/tool/patch, you should not use this in any production environment without a full understanding of what will happen if you do. This type of activity should always be lab tested before executing in production.
