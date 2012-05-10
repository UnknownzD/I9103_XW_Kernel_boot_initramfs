#!/system/bin/sh

busybox="/sbin/busybox"
sleep 3

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
			$busybox sync
		fi
		$busybox chown $5 $2 >/dev/null 2>&1
		$busybox chmod $4 $2 >/dev/null 2>&1
	elif [ $write_file -eq 2 ]; then
		$busybox rm -rf $1 >/dev/null 2>&1
		$busybox ln -fs $1 $2 >/dev/null 2>&1
		$busybox sync
	fi
}

# Only the first 4 has I/O scheduler
STL=$(ls -d /sys/block/stl*);
BML=$(ls -d /sys/block/bml*);
MMC=$(ls -d /sys/block/mmc*);
TFSR=$(ls -d /sys/block/tfsr*);
# Belows are without I/O scheduler, be careful to mess with them! Do not enable loop yet as it is causing problem!
ZRM=$(ls -d /sys/block/zram*);
RAM=$(ls -d /sys/block/ram*);
LOOP=$(ls -d /sys/block/loop*);

# Optimize non-rotating storage, only MMC and LOOP are presented on our devices
for i in $MMC
do
	# Select sio I/O scheduler as default
	if [ -e $i/queue/scheduler ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo 'sio' > $i/queue/scheduler;
	fi;
	if [ -e $i/queue/rotational ]; 
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '0' > $i/queue/rotational;
	fi;
	if [ -e $i/queue/nr_requests ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '1024' > $i/queue/nr_requests; # for starters: keep it sane
	fi;
	if [ -e $i/queue/rq_affinity ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '1' > $i/queue/rq_affinity;
	fi;
	if [ -e $i/queue/read_ahead_kb ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '2048' > $i/queue/read_ahead_kb;
	fi;
	if [ -e $i/queue/iostats ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '0' > $i/queue/iostats;
	fi;
	# Below is SIO specific configuration
	if [ -e $i/queue/iosched/async_expire ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '1000' > $i/queue/iosched/async_expire ];
	fi;
	if [ -e $i/queue/iosched/fifo_batch ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '1' > $i/queue/iosched/fifo_batch;
	fi;
	if [ -e $i/queue/iosched/sync_expire ];
	then
		$busybox sync >/dev/null 2>&1;
		$busybox echo '500' > $i/queue/iosched/sync_expire ];
	fi;
done;

##### Modify others read_ahead_kb value as well #####
#for i in $(ls -d /sys/devices/virtual/bdi/179:*/read_ahead_kb); do
for i in $($busybox ls -d /sys/devices/virtual/bdi/*/read_ahead_kb); do
	$busybox echo '2048' > $i;
done

# Remount each file system with noatime and nodiratime flags to save battery and CPU cycles

for k in $($busybox mount | grep 'relatime' | cut -d ' ' -f3)
do
	$busybox sync >/dev/null 2>&1;
	$busybox mount -o remount,noatime,norelatime,nodiratime $k >/dev/null 2>&1;
done;

for k in $($busybox mount | grep 'ext4' | cut -d ' ' -f1)
do
	if [ $k != '/dev/block/mmcblk0p1' ]; then
		$busybox sync >/dev/null 2>&1;
		$busybox mount -o remount,ro,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,nobh $k >/dev/null 2>&1;
		$busybox sync >/dev/null 2>&1;
		/sbin/tune2fs -f -o journal_data_writeback -O ^has_journal $k >/dev/null 2>&1;
		$busybox sync >/dev/null 2>&1;
		if [ "$(tune2fs -l $k | grep 'journal_data_writeback')" == '' ]; then
			$busybox mount -o remount,rw,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,nobh $k >/dev/null 2>&1;
		else
			$busybox mount -o remount,rw,async,noatime,norelatime,nodiratime,noauto_da_alloc,delalloc,barrier=0,errors=remount-ro,data=writeback,nobh $k >/dev/null 2>&1;
		fi
	fi
done;

for k in $($busybox mount | grep 'vfat' | cut -d " " -f3)
do
	$busybox sync >/dev/null 2>&1;
	$busybox mount -o remount,async,noatime,norelatime,nodiratime,errors=remount-ro $k >/dev/null 2>&1; 
done;

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
copy_file /sbin/sqlite3 /system/xbin/sqlite3 0 755 0:0
copy_file /sbin/tune2fs /system/bin/tune2fs 0 755 0:0
copy_file /sbin/zipalign /system/xbin/zipalign 0 755 0:0
cd /sbin/
for file in ./*; do
	if [ "$($busybox readlink $file)" == 'busybox' ]; then 
		copy_file busybox /system/bin/$file 2
	fi
done

##### Install voodoo sound control #####
if [ ! -f "$($busybox find /system/app | grep '/system/app/org.projectvoodoo.controlapp')" ]; then
copy_file /tmp/org.projectvoodoo.controlapp.apk /system/app/org.projectvoodoo.controlapp.apk 1 644 0:0
fi
copy_file /tmp/libvoodoo_sound_hardware_init.so /data/data/org.projectvoodoo.controlapp/lib/libvoodoo_sound_hardware_init.so 1 644 0:0

##### Install bravia engine #####
copy_file /tmp/com.sonyericsson.android.SwIqiBmp.jar /system/framework/com.sonyericsson.android.SwIqiBmp.jar 1 644 0:0
copy_file /tmp/com.sonyericsson.suquashi.jar /system/framework/com.sonyericsson.suquashi.jar 1 644 0:0
copy_file /tmp/be_movie /system/etc/be_movie 1 755 0:0
copy_file /tmp/be_photo /system/etc/be_photo 1 755 0:0
copy_file /tmp/com.sonyericsson.android.SwIqiBmp.xml /system/etc/permissions/com.sonyericsson.android.SwIqiBmp.xml 1 644 0:0
copy_file /tmp/libswiqibmpcnv.so /system/lib/libswiqibmpcnv.so 1 644 0:0

##### sqlite3 db optimization and zipalign #####
if [ -d '/data' ]; then
	if [ -d '/data/app' ]; then
		for i in $($busybox find /data/app -iname '*.apk'); do /sbin/zipalign -c 4 $i >/dev/null 2>&1; done
	fi
	for i in $($busybox find /data -iname '*.db'); do /sbin/sqlite3 $i 'VACUUM;' >/dev/null 2>&1 ; /sbin/sqlite3 $i 'REINDEX;' >/dev/null 2>&1; done
fi

if [ -d '/system' ]; then
	if [ -d '/system/app' ]; then
		for i in $($busybox find /system/app -iname '*.apk'); do /sbin/zipalign -c 4 $i >/dev/null 2>&1; done
	fi
	for i in $($busybox find /system -iname '*.db'); do /sbin/sqlite3 $i 'VACUUM;' >/dev/null 2>&1; /sbin/sqlite3 $i 'REINDEX;' >/dev/null 2>&1; done
fi

if [ -d '/mnt/sdcard' ]; then
	$busybox mount -o remount,rw /mnt/sdcard >/dev/null 2>&1;
	$busybox mount -o remount,rw /mnt/sdcard/external_sd >/dev/null 2>&1;
	for i in $($busybox find /mnt/sdcard -iname '*.db'); do /sbin/sqlite3 $i 'VACUUM;' >/dev/null 2>&1; /sbin/sqlite3 $i 'REINDEX;' >/dev/null 2>&1; done
fi	

# Disable carrieriq service
/system/bin/pm disable android/com.carrieriq.iqagent.service.IQService >/dev/null 2>&1
/system/bin/pm disable android/com.carrieriq.iqagent.service.receivers.BootCompletedReceiver >/dev/null 2>&1
/system/bin/pm disable android/com.carrieriq.iqagent.service.ui.DebugSettings >/dev/null 2>&1
/system/bin/pm disable android/com.carrieriq.iqagent.service.ui.ShowMessage >/dev/null 2>&1
/system/bin/pm disable android/com.carrieriq.iqagent.client.NativeClient >/dev/null 2>&1
/system/bin/pm disable android/com.carrieriq.iqagent.stdmetrics.survey.android.QuestionnaireLaunchActivity >/dev/null 2>&1
/system/bin/pm disable android/com.carrieriq.iqagent.stdmetrics.survey.android.QuestionnaireActivity >/dev/null 2>&1

# Disable user stat and data collection
del_file /data/system/userbehavior.db
$busybox touch /data/system/userbehavior.db >/dev/null 2>&1
$busybox chmod 000 /data/system/userbehavior.db >/dev/null 2>&1
del_file /data/system/usagestats
$busybox mkdir -m 000 /data/system/usagestats >/dev/null 2>&1
del_file /data/system/appusagestats
$busybox mkdir -m 000 /data/system/appusagestats/ >/dev/null 2>&1

#####  Load sysctl configuration #####
sysctl -p /sysctl.conf >/dev/null 2>&1

##### sleep another 2 seconds before running init.d script #####
sleep 2

##### /system/etc/init.d tweak (run custom scripts) #####
if [ -d '/system/etc/init.d' ]; then
    for file in /system/etc/init.d/* ; do
	if [ -f "$file" ]; then
		$busybox sh "$file" >/dev/null 2>&1
	fi
    done
fi

$busybox mount -o remount,ro /system >/dev/null 2>&1
