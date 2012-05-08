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
			$busybox cp -fL $1 $2 >/dev/null 2>&1
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

##### Remove dalvik-cache and cache #####
$busybox rm -rf /data/dalvik-cache/*
$busybox rm -rf /data/cache/*

##### Install SU #####
# Mode 6755 = SetUID, SetGID and 755 access right
copy_file /sbin/su /system/bin/su 0 6755 0:0
copy_file /tmp/Superuser.apk /system/app/Superuser.apk 1 644 0:0
copy_file /system/bin/su /system/xbin/su 2

##### Install busybox and other binaries #####
copy_file /sbin/busybox /system/bin/busybox 0 755 0:0
copy_file /sbin/e2fsck /system/bin/e2fsck 0 755 0:0
copy_file /sbin/mke2fs /system/bin/mke2fs 0 755 0:0
copy_file /sbin/parted /system/bin/parted 0 755 0:0
copy_file /sbin/sqlite3 /system/bin/sqlite3 0 755 0:0
copy_file /sbin/tune2fs /system/bin/tune2fs 0 755 0:0
copy_file /sbin/zipalign /system/bin/zipalign 0 755 0:0
cd /sbin/
for file in ./*; do
	if [ "$(eval readlink $file)" == 'busybox' ]; then 
		copy_file busybox /system/bin/$file 2
	fi
done

##### Install voodoo sound control #####
if [ ! -f "$(eval find /data/app | grep '/system/app/org.projectvoodoo.controlapp')" ]; then
copy_file /tmp/org.projectvoodoo.controlapp.apk /system/app/org.projectvoodoo.controlapp.apk 1 644 0:0
fi
copy_file /tmp/libvoodoo_sound_hardware_init.so /data/data/org.projectvoodoo.controlapp/lib/libvoodoo_sound_hardware_init.so 1 755 0:0

##### Install bravia engine #####
copy_file /tmp/com.sonyericsson.android.SwIqiBmp.jar /system/framework/com.sonyericsson.android.SwIqiBmp.jar 1 644 0:0
copy_file /tmp/com.sonyericsson.suquashi.jar /system/framework/com.sonyericsson.suquashi.jar 1 644 0:0
copy_file /tmp/be_movie /system/etc/be_movie 1 755 0:0
copy_file /tmp/be_photo /system/etc/be_photo 1 755 0:0
copy_file /tmp/com.sonyericsson.suquashi.xml /system/etc/permissions/com.sonyericsson.suquashi.xml 1 644 0:0
copy_file /tmp/libswiqibmpcnv.so /system/lib/libswiqibmpcnv.so 1 644 0:0

##### Load sysctl configuration #####
sysctl -p /sysctl.conf

##### sqlite3 db optimization #####
if [ -d "/data" ]; then
	mount -o remount,rw /data;
	for i in "$busybox find /data -iname "*.db""; 
	do \
		/sbin/sqlite3 $i 'VACUUM;'; 
		/sbin/sqlite3 $i 'REINDEX;'; 
	done;
fi;

if [ -d "/system" ]; then
	mount -o remount,rw /system;
	for i in "$busybox find /system -iname "*.db""; 
	do \
		/sbin/sqlite3 $i 'VACUUM;'; 
		/sbin/sqlite3 $i 'REINDEX;'; 
	done;
	mount -o remount,ro /system;
fi;

if [ -d "/sdcard" ]; then
	mount -o remount,rw /sdcard;
	for i in "$busybox find /sdcard -iname "*.db""; 
	do \
		/sbin/sqlite3 $i 'VACUUM;'; 
		/sbin/sqlite3 $i 'REINDEX;'; 
	done;
fi;

# FS mount tweak
$busybox sync
$busybox mount -o remount,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,data=writeback,nobh /system;
$busybox sync
$busybox mount -o remount,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,data=writeback,nobh /data;
$busybox sync
$busybox mount -o remount,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,data=writeback,nobh /cache;
$busybox sync
$busybox mount -o remount,async,noatime,norelatime,nodiratime,errors=remount-ro /mnt/sdcard;
$busybox sync
$busybox mount -o remount,async,noatime,norelatime,nodiratime,errors=remount-ro /mnt/sdcard/external_sd;

# Disable carrieriq service
/system/bin/pm disable android/com.carrieriq.iqagent.service.IQService
/system/bin/pm disable android/com.carrieriq.iqagent.service.receivers.BootCompletedReceiver
/system/bin/pm disable android/com.carrieriq.iqagent.service.ui.DebugSettings
/system/bin/pm disable android/com.carrieriq.iqagent.service.ui.ShowMessage
/system/bin/pm disable android/com.carrieriq.iqagent.client.NativeClient
/system/bin/pm disable android/com.carrieriq.iqagent.stdmetrics.survey.android.QuestionnaireLaunchActivity
/system/bin/pm disable android/com.carrieriq.iqagent.stdmetrics.survey.android.QuestionnaireActivity

# Disable user stat and data collection
$busybox chmod 000 /data/system/userbehavior.db;
$busybox chmod 000 /data/system/usagestats/;
$busybox chmod 000 /data/system/appusagestats/;

# Select sio as default IO scheduler
# Optimize non-rotating storage; 
for i in $STL $BML $MMC $TFSR $ZRAM $RAM $LOOP
do
	# Select sio I/O scheduler as default
	if [ -e $i/queue/scheduler ];
	then
		$busybox sync;
		$busybox echo "sio" > $i/queue/scheduler;
	fi;
	if [ -e $i/queue/rotational ]; 
	then
		$busybox sync;
		$busybox echo "0" > $i/queue/rotational; 
	fi;
	if [ -e $i/queue/nr_requests ];
	then
		$busybox sync;
		$busybox echo "1024" > $i/queue/nr_requests; # for starters: keep it sane
	fi;
	if [ -e $i/queue/rq_affinity ];
	then
		$busybox sync;
		$busybox echo "1"   >  $i/queue/rq_affinity;
	fi;
	if [ -e $i/queue/read_ahead_kb ];
	then
		$busybox sync;
		$busybox echo "2048" >  $i/queue/read_ahead_kb;
	fi;
	if [ -e $i/queue/iostats ];
	then
		$busybox sync;
		$busybox echo "0" > $i/queue/iostats;
	fi;
	# Below is SIO specific configuration
	if [ -e $i/queue/iosched/async_expire ];
	then
		$busybox sync;
		$busybox echo "1000" > $i/queue/iosched/async_expire ];
	fi;
	if [ -e $i/queue/iosched/fifo_batch ];
	then
		$busybox sync;
		$busybox echo "1" > $i/queue/iosched/fifo_batch;
	fi;
	if [ -e $i/queue/iosched/sync_expire ];
	then
		$busybox sync;
		$busybox echo "500" > $i/queue/iosched/sync_expire ];
	fi;
done;

# Increase the read ahead size
for file in $(ls -d /sys/devices/virtual/bdi/*/read_ahead_kb); do $busybox echo "2048" > $file; done

# Remount each file system with noatime and nodiratime flags to save battery and CPU cycles
for k in $(mount | grep relatetime | cut -d " " -f3)
do
	$busybox sync;
	$busybox mount -o remount,noatime,norelatime,nodiratime $k;
done;
for k in $(mount | grep ext4 | cut -d " " -f1)
do
	$busybox sync;
	$busybox mount -o remount,ro,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,data=writeback,nobh $k;
	$busybox sync;
	/sbin/tune2fs -f -o journal_data_writeback -O ^has_journal $k;
	$busybox sync;
	$busybox mount -o remount,rw,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,data=writeback,nobh $k;
done;
for k in $(mount | grep vfat | cut -d " " -f3)
do
	$busybox sync;
	$busybox mount -o remount,async,noatime,norelatime,nodiratime,errors=remount-ro $k;
done;


##### /system/etc/init.d tweak (run custom scripts) #####
if [ -d '/system/etc/init.d' ]; then
    for file in /system/etc/init.d/* ; do
	if [ -f "$file" ]; then
		/sbin/sh "$file" >/dev/null 2>&1
	fi
    done
fi

$busybox mount -o remount,ro /system
