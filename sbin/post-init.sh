#!/system/bin/sh

busybox="/sbin/busybox"
sleep 3

# Ext4 tweak
#####$busybox mount -o remount,noauto_da_alloc /cache /cache
#####$busybox mount -o remount,noauto_da_alloc /data /data

# SD Speed tweaks
#####echo "2048" > /sys/devices/virtual/bdi/179:0/read_ahead_kb;
#####echo "2048" > /sys/devices/virtual/bdi/7:0/read_ahead_kb

del_file()
{
	$busybox chmod -R 777 $1 >/dev/null 2>&1
	$busybox rm -rf $1 >/dev/null 2>&1
}

# install_file (src,dest,type,mode,owner);
# type 0 = executable
# type 1 = regular file
# type 2 = link file
copy_file ()
{
	local write_file=0;
	if [ $3 -eq 0 ]; then
		if [ ! -x "$2" ]; then
			write_file=1;
		fi
	elif [ $3 -eq 1 ]; then
		if [ ! -f "$2" ]; then
			write_file=1;
		fi
	elif [ $3 -eq 2 ]; then
		# Do NOT change the following line to use single qoute instead of double quote, which disabled the variable evaluation
		if !([ "$(eval readlink $2)" == "$1" ]); then
			write_file=2;
		else
			write_file=3;
		fi
	fi
	if [ $write_file -lt 2 ]; then
		if [ $write_file -eq 1 ]; then
			del_file $2
			$busybox cp -f -L $1 $2 >/dev/null 2>&1
		fi
		$busybox chown $5 $2 >/dev/null 2>&1
		$busybox chmod $4 $2 >/dev/null 2>&1
	elif [ $write_file -eq 2 ]; then
		$busybox rm -rf $1 >/dev/null 2>&1
		$busybox ln -fs $1 $2 >/dev/null 2>&1
	fi
}

$busybox mount -o remount,rw /system
$busybox mount -o remount,rw /data

##### Install SU #####
# Mode 6755 = SetUID, SetGID and 755 access right
copy_file /sbin/su /system/bin/su 0 6755 0:0
copy_file /sbin/Superuser.apk /system/app/Superuser.apk 1 644 0:0
copy_file /system/bin/su /system/xbin/su 2

##### Install busybox #####
copy_file /sbin/busybox /system/bin/busybox 0 755 0:0
copy_file /sbin/e2fsck /system/bin/e2fsck 0 755 0:0
copy_file /sbin/mke2fs /system/bin/mke2fs 0 755 0:0
copy_file /sbin/parted /system/bin/parted 0 755 0:0
copy_file /sbin/tune2fs /system/bin/tune2fs 0 755 0:0
cd /sbin/
for file in ./*; do
	if [ "$(eval readlink $file)" == 'busybox' ]; then 
		copy_file busybox /system/bin/$file 2
	fi
done

##### Install voodoo sound control #####
if [ ! -f "$(eval find /data/app | grep '/system/app/org.projectvoodoo.controlapp')" ]; then
copy_file /sbin/org.projectvoodoo.controlapp.apk /system/app/org.projectvoodoo.controlapp.apk 1 644 0:0
fi
copy_file /sbin/libvoodoo_sound_hardware_init.so /data/data/org.projectvoodoo.controlapp/lib/libvoodoo_sound_hardware_init.so 1 755 0:0
fi

##### Load configuration #####
sysctl -p /sysctl.conf	

##### /system/etc/init.d tweak (run custom scripts) #####
if [ -d '/system/etc/init.d' ]; then
    for file in /system/etc/init.d/* ; do
	if [ -f "$file" ]; then
		/system/bin/sh "$file" >/dev/null 2>&1
	fi
    done
fi

$busybox mount -o remount,ro /system
