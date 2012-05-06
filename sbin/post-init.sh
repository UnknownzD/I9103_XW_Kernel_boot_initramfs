#!/system/bin/sh

busybox="/sbin/busybox"
sleep 3

# Ext4 tweak
#####$busybox mount -o remount,noauto_da_alloc /cache /cache
#####$busybox mount -o remount,noauto_da_alloc /data /data

# SD Speed tweaks
#####echo "2048" > /sys/devices/virtual/bdi/179:0/read_ahead_kb;
#####echo "2048" > /sys/devices/virtual/bdi/7:0/read_ahead_kb

##### Install SU #####

$busybox mount -o remount,rw /system
if [ ! -x /system/bin/su ]; then
	$busybox chmod -R 777 /system/bin/su
	$busybox rm -rf /system/bin/su
	$busybox cp /sbin/su /system/bin/su
	$busybox chown 0:0 /system/bin/su
	$busybox chmod 4755 /system/bin/su
fi
if [ ! -e /system/app/Superuser.apk ]; then
	$busybox chmod -R 777 /system/bin/su
	$busybox rm -rf /system/app/Superuser.apk
	$busybox cp /sbin/Superuser.apk /system/app/Superuser.apk
	$busybox chown 644 /system/app/Superuser.apk
fi
if [ ! -h /system/xbin/su ]; then
	$busybox chmod -R 777 /system/xbin/su
	$busybox rm -rf /system/xbin/su
	$busybox ln -s /system/bin/su /system/xbin/su
fi

##### /system/etc/init.d tweak (run custom scripts) #####
if [-d /system/etc/init.d]; then
    for file in /system/etc/init.d/* ; do
	if [-f $file]; then
		/system/bin/sh "$file"
	fi
    done
fi

##### Install busybox #####
if [ ! -x /system/xbin/busybox]; then
	$busybox chmod -R 777 /system/xbin/busybox
	$busybox cp /sbin/busybox /system/xbin/busybox
	$busybox chown 0:0 /system/xbin/busybox
	$busybox chmod 755 /system/xbin/busybox
fi

$busybox mount -o remount,ro /system

