#!/bin/sh
#
# 注：升级和配置恢复是两个互补的操作，不存在冗余，所以升级不会
#     修改删除任何已有的配置文件（本脚本中ignore_files变量所指
#     的文件都是配置文件，这个变量的内容也即ConfigBackup.sh脚本
#     中$files变量的内容），这点在制时要注意；而配置恢复只更新
#     配置文件，不修改非配置文件。
#

# sync time
#sudo ntpdate 202.120.2.101
#sudo ntpdate 192.168.188.100

UPGRADE_PWD=K0a1Upgrade5;
DATE=$(date +"%y%m%d_%H%M%S");

# 确定需要升级的文件
#
echo "请选择自定义升级的配置文件：";
select UPGRADE_FILE in $(find . -name "*.upgrade"); do
	if test -f $UPGRADE_FILE; then
		source $UPGRADE_FILE;
		break;
	else
		echo "请选择自定义升级的配置文件：";
	fi;
done;

# 从文件名中获取升级包名称
UPGRADE_DIR=${UPGRADE_FILE%/*};
UPGRADE_NAME=${UPGRADE_FILE%%.upgrade};
UPGRADE_NAME=${UPGRADE_NAME##*/};

# 如果升级包名称最后已经包含日期，则后缀中不用再包含时间
echo $UPGRADE_NAME | egrep "[0-9]{6}$" && { 
	echo "Strip date from $DATE";
	DATE=$(date +"%H%M%S"); 
}

# SSL5系列的升级包文件内容必须为root权限
sudo chown -R root:root $UPGRADE_NAME

UPGRADE_TARBALL="$UPGRADE_DIR/kssl-upgrade.tar";
UPGRADE_PACKAGE="$UPGRADE_DIR/$UPGRADE_NAME"."$DATE.z";
UPGRADE_LOG="$UPGRADE_DIR/$UPGRADE_NAME"."$DATE.log";
#UPGRADE_REV=$(LANG=C svn info https://ssl.koal.com/svn/SSL | egrep "Last Changed Rev:" | egrep -o "[0-9]+")
UPGRADE_REV=$(LANG=C git log | egrep "commit" | awk -F" " '{print $2}' | head -n 1 | cut -b 1-5)

UPGRADE_HOME=$UPGRADE_DIR/$UPGRADE_NAME; 

echo "rm -f $UPGRADE_PACKAGE $UPGRADE_TARBALL"
rm -f $UPGRADE_PACKAGE;
rm -f $UPGRADE_TARBALL;
echo -n > $UPGRADE_LOG;

# 将需要备份的文件逐一添加到tarball中，注意：目录则只添加空目录
#
for yard in $yard_files; do
	for f in $(grep -v "#" "$yard" | awk '{print $NF}'); do 
	
		for ignore_file in $ignore_files; do
			if [ $f = $ignore_file ]; then
				f="/ingore";
				break;
			fi;
		done;

		# 根据$f的第一个字符是否为"/"来判断这是一个绝对路径还是相对路径
		#
		if [ ${f:0:3} == "DOM" ]; then
			TAR_BASE_DIR=${yard%%/yard*};
			echo "DOM dir: $TAR_BASE_DIR";
			exit 0;
		else
			TAR_BASE_DIR="/";
		fi;

		if test -f $TAR_BASE_DIR/$f; then 
			tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f >/dev/null 2>&1;
			if [ "$?" != "0" ]; then
				echo "tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f failed" | tee -a $UPGRADE_LOG;
				exit;
			else
				echo $f | tee -a $UPGRADE_LOG;
			fi;
		else
			if test -d $TAR_BASE_DIR/$f; then
				if [ "$(ls $f)" = "" ]; then
					tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f >/dev/null 2>&1;
					if [ "$?" != "0" ]; then
						echo "tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f failed" | tee -a $UPGRADE_LOG;
						exit;
					else
						echo $f | tee -a $UPGRADE_LOG;
					fi;
				fi;
			else
				if [ ${f:0:1} == "/" ]; then
					echo "[$yard]: $f dosen't exist";
				else
					echo "[$yard]: $TAR_BASE_DIR/$f dosen't exist";
				fi;

				exit;
			fi;
		fi;
	done;
done;

for f in $additional_files; do

	# 根据$f的第一个字符是否为"/"来判断这是一个绝对路径还是相对路径
	#
	if [ ${f:0:1} == "/" ]; then
		TAR_BASE_DIR="/";
		fpath=$f;
	else
		TAR_BASE_DIR=$UPGRADE_HOME;
		fpath=$TAR_BASE_DIR/$f;
	fi;
	
	if test -f $fpath; then
		tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f >/dev/null 2>&1;
		if [ "$?" != "0" ]; then
			echo "tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f failed" | tee -a $UPGRADE_LOG;
			exit;
		else
			echo $f | tee -a $UPGRADE_LOG;
		fi;
	else
		if test -d $fpath; then
			if [ "$(ls $fpath)" = "" ]; then
				tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f >/dev/null 2>&1;
				if [ "$?" != "0" ]; then
					echo "tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f failed" | tee -a $UPGRADE_LOG;
					exit;
				else
					echo $f | tee -a $UPGRADE_LOG;
				fi;
			else
				echo "[additional]: $f is a directory but not empty";
				exit;
			fi;
		else
			echo "[additional]: $fpath dosen't exist";
			exit;
		fi;
	fi;
done;

for f in $optional_files; do

	# 根据$f的第一个字符是否为"/"来判断这是一个绝对路径还是相对路径
	#
	if [ ${f:0:1} == "/" ]; then
		TAR_BASE_DIR="/";
		fpath=$f;
	else
		TAR_BASE_DIR=$UPGRADE_HOME;
		fpath=$TAR_BASE_DIR/$f;
	fi;
	
	if test -f $fpath; then
		tar -r --no-recursion -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f > /dev/null 2>&1 && echo $f | tee -a $UPGRADE_LOG;
	else 
		if test -d $fpath; then
			if [ "$(ls $fpath)" = "" ]; then
				tar -r -f $UPGRADE_TARBALL -C $TAR_BASE_DIR $f > /dev/null 2>&1 && echo $f | tee -a $UPGRADE_LOG;
			else
				echo "[optional]: $fpath is a directory but not empty";
			fi;
		fi
	fi;
done;

# 添加升级包描述到升级包中
#
echo $UPGRADE_NAME.$DATE.z[$UPGRADE_REV] > $UPGRADE_DIR/upgrade-info
#echo "SSL5.2.4_VPN_C2C_20130222.104126.z"[$UPGRADE_REV] > $UPGRADE_DIR/upgrade-info
cat  $UPGRADE_LOG >> $UPGRADE_DIR/upgrade-info
tar -r --no-recursion -f $UPGRADE_TARBALL -C $UPGRADE_DIR upgrade-info > /dev/null 2>&1;
rm -f $UPGRADE_DIR/upgrade-info

# 压缩得到最终的升级包
#
zip -P $UPGRADE_PWD $UPGRADE_PACKAGE $UPGRADE_TARBALL
rm -f $UPGRADE_TARBALL;

# 将升级包内容的目录权限改回当前用户
CUR_USER=$(whoami)
CUR_GROUP=$(groups | awk '{print $1}')
echo sudo chown -R $CUR_USER:$CUR_GROUP $UPGRADE_NAME
sudo chown -R $CUR_USER:$CUR_GROUP $UPGRADE_NAME

echo $UPGRADE_PACKAGE;
echo

