#!/usr/bin/perl

#    mkpatch - Create patches against the Linux kernel
#    Copyright (c) 1999  Frodo Looijaard <frodol@dds.nl>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

use strict;

# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
# $_[2]: Name of the kernel file
# $_[3]: Name of the patched file
sub print_diff
{
  my ($package_root,$kernel_root,$kernel_file,$package_file) = @_;
  my ($diff_command,$dummy);

  $diff_command = "diff -u2 $kernel_root/$kernel_file ";
  $diff_command .= "$package_root/$package_file";
  open INPUT, "$diff_command|";
  $dummy = <INPUT>;
  $dummy = <INPUT>;
  print "--- linux-old/$kernel_file\t".`date`;
  print "+++ linux/$kernel_file\t".`date`;
    
  while (<INPUT>) {
    print;
  }
  close INPUT;
}

# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
sub gen_Makefile
{
  my ($package_root,$kernel_root) = @_;
  my $kernel_file = "Makefile";
  my $package_file = "mkpatch/.temp";

  open INPUT,"$kernel_root/$kernel_file"
        or die "Can't open `$kernel_root/$kernel_file'";
  open OUTPUT,">$package_root/mkpatch/.temp"
        or die "Can't open $package_root/$package_file";
  while(<INPUT>) {
    if (m@CONFIG_SENSORS@) {
      $_ = <INPUT> while not m@endif@;
      $_ = <INPUT>;
      $_ = <INPUT> if m@^$@;
    }
    if (m@include arch/\$\(ARCH\)/Makefile@) {
      print OUTPUT <<'EOF';
ifeq ($(CONFIG_SENSORS),y)
DRIVERS := $(DRIVERS) drivers/sensors/sensors.a
endif

EOF
    }
    print OUTPUT;
  }
  close INPUT;
  close OUTPUT;
  print_diff $package_root,$kernel_root,$kernel_file,$package_file;
}

# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
sub gen_drivers_Makefile
{
  my ($package_root,$kernel_root) = @_;
  my $kernel_file = "drivers/Makefile";
  my $package_file = "mkpatch/.temp";
  my $sensors_present;

  open INPUT,"$kernel_root/$kernel_file"
        or die "Can't open `$kernel_root/$kernel_file'";
  open OUTPUT,">$package_root/mkpatch/.temp"
        or die "Can't open $package_root/$package_file";
  while(<INPUT>) {
    if (m@^ALL_SUB_DIRS\s*:=@) {
      $sensors_present = 0;
      while (m@\\$@) {
        $sensors_present = 1 if m@sensors@;
        print OUTPUT;
        $_ = <INPUT>;
      }
      $sensors_present = 1 if m@sensors@;
      s@$@ sensors@ if (not $sensors_present);
    } 
    if (m@CONFIG_SENSORS@) {
      $_ = <INPUT> while not m@^endif@;
      $_ = <INPUT>;
      $_ = <INPUT> if m@^$@;
    } 
    if (m@^include \$\(TOPDIR\)/Rules.make$@) {
      print OUTPUT <<'EOF';
ifeq ($(CONFIG_SENSORS),y)
SUB_DIRS += sensors
MOD_SUB_DIRS += sensors
else
  ifeq ($(CONFIG_SENSORS),m)
  MOD_SUB_DIRS += sensors
  endif
endif

EOF
    }
    print OUTPUT;
  }
  close INPUT;
  close OUTPUT;
  print_diff $package_root,$kernel_root,$kernel_file,$package_file;
}

# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
sub gen_drivers_char_Config_in
{
  my ($package_root,$kernel_root) = @_;
  my $kernel_file = "drivers/char/Config.in";
  my $package_file = "mkpatch/.temp";
  my $ready = 0;
  my $done = 0;

  open INPUT,"$kernel_root/$kernel_file"
        or die "Can't open `$kernel_root/$kernel_file'";
  open OUTPUT,">$package_root/mkpatch/.temp"
        or die "Can't open $package_root/$package_file";
  while(<INPUT>) {
    if (m@source drivers/i2c/Config.in@) {
      print OUTPUT;
      print OUTPUT 'source drivers/sensors/Config.in';
      $_ = <INPUT>;
    }
    if (m@sensors@) {
      $_ = <INPUT>;
      $_ = <INPUT> if (m@^$@);
    }
    print OUTPUT;
  }
  close INPUT;
  close OUTPUT;
  print_diff $package_root,$kernel_root,$kernel_file,$package_file;
}
 

# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
sub gen_drivers_char_mem_c
{
  my ($package_root,$kernel_root) = @_;
  my $kernel_file = "drivers/char/mem.c";
  my $package_file = "mkpatch/.temp";
  my $right_place = 0;
  my $done = 0;
  my $atstart = 1;

  open INPUT,"$kernel_root/$kernel_file"
        or die "Can't open `$kernel_root/$kernel_file'";
  open OUTPUT,">$package_root/mkpatch/.temp"
        or die "Can't open $package_root/$package_file";
  while(<INPUT>) {
    if ($atstart and m@#ifdef@) {
      print OUTPUT << 'EOF';
#ifdef CONFIG_SENSORS
extern void sensors_init_all(void);
#endif
EOF
      $atstart = 0;
    }
    if (not $right_place and m@CONFIG_SENSORS@) {
      $_ = <INPUT> while not m@#endif@;
      $_ = <INPUT>;
    }
    $right_place = 1 if (m@lp_init\(\);@);
    if ($right_place and not $done and
        (m@CONFIG_SENSORS@ or m@return 0;@)) {
      if (not m@return 0;@) {
        $_ = <INPUT> while not m@#endif@;
        $_ = <INPUT>;
        $_ = <INPUT> if m@^$@;
      }
      print OUTPUT <<'EOF';
#ifdef CONFIG_SENSORS
	sensors_init_all();
#endif

EOF
      $done = 1;
    }
    print OUTPUT;
  }
  close INPUT;
  close OUTPUT;
  print_diff $package_root,$kernel_root,$kernel_file,$package_file;
}


# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
sub gen_drivers_i2c_Config_in
{
  my ($package_root,$kernel_root) = @_;
  my $kernel_file = "drivers/i2c/Config.in";
  my $package_file = "mkpatch/.temp";

  open INPUT,"$kernel_root/$kernel_file"
        or die "Can't open `$kernel_root/$kernel_file'";
  open OUTPUT,">$package_root/mkpatch/.temp"
        or die "Can't open $package_root/$package_file";
  while(<INPUT>) {
    if (m@CONFIG_I2C_MAINBOARD@) {
      $_ = <INPUT> while not m@^  fi$@;
      $_ = <INPUT>;
    }
    if (m@CONFIG_I2C_CHARDEV@) {
      print OUTPUT << 'EOF'
  dep_bool 'I2C mainboard interfaces' CONFIG_I2C_SMBUS $CONFIG_I2C
  if [ "$CONFIG_I2C_MAINBOARD" = "y" ]; then
    dep_tristate '  Acer Labs ALI 1533 and 1543C' CONFIG_I2C_ALI5X3 $CONFIG_I2C_MAINBOARD
    dep_tristate '  Apple Hydra Mac I/O' CONFIG_I2C_HYDRA $CONFIG_I2C_MAINBOARD
    dep_tristate '  Intel 82371AB PIIX4(E)' CONFIG_I2C_PIIX4 $CONFIG_I2C_MAINBOARD
    dep_tristate '  VIA Technologies, Inc. VT82C586B' CONFIG_I2C_VIA $CONFIG_I2C_MAINBOARD
  fi

EOF
    }
    print OUTPUT;
  }
  close INPUT;
  close OUTPUT;
  print_diff $package_root,$kernel_root,$kernel_file,$package_file;
}

# $_[0]: sensors package root (like /tmp/sensors)
# $_[1]: Linux kernel tree (like /usr/src/linux)
sub gen_drivers_i2c_Makefile
{
  my ($package_root,$kernel_root) = @_;
  my $kernel_file = "drivers/i2c/Makefile";
  my $package_file = "mkpatch/.temp";

  open INPUT,"$kernel_root/$kernel_file"
        or die "Can't open `$kernel_root/$kernel_file'";
  open OUTPUT,">$package_root/mkpatch/.temp"
        or die "Can't open $package_root/$package_file";
  while(<INPUT>) {
    while (m@CONFIG_I2C_ALI5X4@ or m@CONFIG_I2C_HYDRA@ or m@CONFIG_I2C_PIIX$@ or
        m@CONFIG_I2C_VIA@) {
      $_ = <INPUT> while not m@^endif@;
      $_ = <INPUT>;
      $_ = <INPUT> if m@^$@;
    }
    if (m@Rules.make@) {
      print OUTPUT << 'EOF'
ifeq ($(CONFIG_I2C_ALI5X3),y)
  L_OBJS += i2c-ali5x3.c
else 
  ifeq ($(CONFIG_I2C_ALI5X3),m)
    M_OBJS += i2c-ali5x3.o
  endif
endif

ifeq ($(CONFIG_I2C_HYDRA),y)
  L_OBJS += i2c-hydra.c
else 
  ifeq ($(CONFIG_I2C_HYDRA),m)
    M_OBJS += i2c-hydra.o
  endif
endif

ifeq ($(CONFIG_I2C_PIIX4),y)
  L_OBJS += i2c-piix4.c
else 
  ifeq ($(CONFIG_I2C_PIIX4),m)
    M_OBJS += i2c-piix4.o
  endif
endif

ifeq ($(CONFIG_I2C_VIA),y)
  L_OBJS += i2c-via.c
else 
  ifeq ($(CONFIG_I2C_VIA),m)
    M_OBJS += i2c-via.o
  endif
endif

EOF
    }
    print OUTPUT;
  }
  close INPUT;
  close OUTPUT;
  print_diff $package_root,$kernel_root,$kernel_file,$package_file;
}



sub main
{
  my ($package_root,$kernel_root,%files,%includes,$package_file,$kernel_file);
  my ($diff_command,$dummy,$data0,$data1,$sedscript,$version_string);

  # --> Read the command-lineo
  $package_root = $ARGV[0];
  die "Package root `$package_root' is not found\n" 
        unless -d "$package_root/mkpatch";
  $kernel_root = $ARGV[1];
  die "Kernel root `$kernel_root' is not found\n" 
        unless -f "$kernel_root/Rules.make";

  # --> Read FILES
  open INPUT, "$package_root/mkpatch/FILES" 
        or die "Can't open `$package_root/mkpatch/FILES'";
  while (<INPUT>) {
    ($data0,$data1) = /(\S+)\s+(\S+)/;
    $files{$data0} = $data1;
  } 
  close INPUT;

  # --> Read INCLUDES
  open INPUT, "$package_root/mkpatch/INCLUDES" 
        or die "Can't open `$package_root/mkpatch/INCLUDES'";
  while (<INPUT>) {
    ($data0,$data1) = /(\S+)\s+(\S+)/;
    $includes{$data0} = $data1;
    $sedscript .= 's,(#\s*include\s*)'.$data0.'(\s*),\1'."$data1".'\2, ; ';
  } 
  close INPUT;

  # --> Read "version.h"
  open INPUT, "$package_root/version.h"
        or die "Can't open `$package_root/version.h'";
  $version_string .= $_ while <INPUT>;
  close INPUT;
 
  # --> Start generating
  foreach $package_file (sort keys %files) {
    $kernel_file = $files{$package_file};
    $diff_command = "diff -u2 ";
    if ( -f "$kernel_root/$kernel_file") {
      $diff_command .= "$kernel_root/$kernel_file";
    } else {
      $diff_command .= "/dev/null";
    }
    $diff_command .= " $package_root/$package_file";
    open INPUT, "$diff_command|";
    $dummy = <INPUT>;
    $dummy = <INPUT>;
    print "--- linux-old/$kernel_file\t".`date`;
    print "+++ linux/$kernel_file\t".`date`;
    
    while (<INPUT>) {
      eval $sedscript;
      if (m@#\s*include\s*"version.h"@) {
        print $version_string;
      } elsif (m@#\s*include\s*"compat.h"@) {
        print << 'EOF';

/* --> COMPATIBILITY SECTION FOR OLD (2.0, 2.1) KERNELS */

#ifdef MODULE
#include <linux/module.h>
#ifndef MODULE_AUTHOR
#define MODULE_AUTHOR(whatever)
#endif
#ifndef MODULE_DESCRIPTION
#define MODULE_DESCRIPTION(whatever)
#endif
#endif /* def MODULE */

EOF
        if (`grep KERNEL_VERSION "$package_root/$package_file"`) {
          print << 'EOF';
#include <linux/version.h>
#ifndef KERNEL_VERSION
#define KERNEL_VERSION(a,b,c) (((a) << 16) | ((b) << 8) | (c))
#endif

EOF
        }
        if (`grep 'copy_from_user\|copy_to_user\|get_user_data' "$package_root/$package_file"`) {
          print << 'EOF';
/* copy_from/to_usr is called memcpy_from/to_fs in 2.0 kernels 
   get_user was redefined in 2.1 kernels to use two arguments, and returns
   an error code */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,1,4))
#define copy_from_user memcpy_fromfs
#define copy_to_user memcpy_tofs
#define get_user_data(to,from) ((to) = get_user(from),0)
#else
#include <asm/uaccess.h>
#define get_user_data(to,from) get_user(to,from)
#endif

EOF
        }
        if (`grep 'schedule_timeout' "$package_root/$package_file"`) {
          print << 'EOF';
/* Add a scheduling fix for the new code in kernel 2.1.127 */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,1,127))
#define schedule_timeout(x) ( current->timeout = jiffies + (x), schedule() )
#endif

EOF
        }
        if (`grep 'pci_' "$package_root/$package_file"`) {
          print << 'EOF';
/* If the new PCI interface is not present, fall back on the old PCI BIOS
   interface. We also define some things to unite both interfaces. Not
   very nice, but it works like a charm. 
   device is the 2.1 struct pci_dev, bus is the 2.0 bus number, dev is the
   2.0 device/function code, com is the PCI command, and res is the result. */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,1,54))
#define pci_present pcibios_present
#define pci_read_config_byte_united(device,bus,dev,com,res) \
                            pcibios_read_config_byte(bus,dev,com,res)
#define pci_read_config_word_united(device,bus,dev,com,res) \
                            pcibios_read_config_word(bus,dev,com,res)
#define pci_write_config_byte_united(device,bus,dev,com,res) \
                            pcibios_write_config_byte(bus,dev,com,res)
#define pci_write_config_word_united(device,bus,dev,com,res) \
                            pcibios_write_config_word(bus,dev,com,res)
#else
#define pci_read_config_byte_united(device,bus,dev,com,res) \
                            pci_read_config_byte(device,com,res)
#define pci_read_config_word_united(device,bus,dev,com,res) \
                            pci_read_config_word(device,com,res)
#define pci_write_config_byte_united(device,bus,dev,com,res) \
                            pci_write_config_byte(device,com,res)
#define pci_write_config_word_united(device,bus,dev,com,res) \
                            pci_write_config_word(device,com,res)
#endif

EOF
        }
        if (`grep 'ioremap\|iounmap' "$package_root/$package_file"`) {
          print << 'EOF';
/* I hope this is always correct, even for the PPC, but I really think so.
   And yes, the kernel version is exactly correct */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,1,0))
#include <linux/mm.h>
#define ioremap vremap
#define iounmap vfree
#endif

EOF
        }
        if (`grep 'init_MUTEX' "$package_root/$package_file"`) {
          print << 'EOF';
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,3,1))
#define init_MUTEX(s) do { *(s) = MUTEX; } while(0)
#endif
EOF

        }
        if (`grep 'PCI_DEVICE_ID_VIA_82C586_3' "$package_root/$package_file"`) {
          print << 'EOF';
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,0,34))
#define PCI_DEVICE_ID_VIA_82C586_3  0x3040
#endif
EOF

        }
        if (`grep 'PCI_DEVICE_ID_AL_M7101' "$package_root/$package_file"`) {
          print << 'EOF';
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,0,34))
#define PCI_DEVICE_ID_AL_M7101 0x7101
#endif
EOF
        }
        if (`grep 'PCI_DEVICE_ID_INTEL_82371AB_3' "$package_root/$package_file"`) {
          print << 'EOF';
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,0,31))
#define PCI_DEVICE_ID_INTEL_82371AB_3  0x7113
#endif
EOF
        }
        if (`grep 'PCI_VENDOR_ID_APPLE' "$package_root/$package_file"`) {
          print << 'EOF';
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,0,31))
#define PCI_VENDOR_ID_APPLE            0x106b
#endif
EOF
        }
        if (`grep 'PCI_DEVICE_ID_APPLE_HYDRA' "$package_root/$package_file"`) {
          print << 'EOF';
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,0,31))
#define PCI_DEVICE_ID_APPLE_HYDRA      0x000e
#endif
EOF
        }
        print << 'EOF';
/* --> END OF COMPATIBILITY SECTION */

EOF
      } else {
        print;
      }
    }
    close INPUT;
  }

  gen_Makefile $package_root, $kernel_root;
  gen_drivers_Makefile $package_root, $kernel_root;
  gen_drivers_char_Config_in $package_root, $kernel_root;
  gen_drivers_char_mem_c $package_root, $kernel_root;
  gen_drivers_i2c_Config_in $package_root, $kernel_root;
  gen_drivers_i2c_Makefile $package_root, $kernel_root;
}

main;

