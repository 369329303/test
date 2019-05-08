#!/bin/sh
#
# 根据目录结构自动生成upgrade文件
# 仅适用于additional_files + optional_files的格式
#


echo "请选择需要生成升级文件的目录：";
select UPGRADE_DIR in $(find . -maxdepth 2 -mindepth 2 -type d | grep -v "/.git"); do
	echo $UPGRADE_DIR;
	break;
done;

if [ "`id -u`" -eq 0 ]; then
	SUDO_CMD=""
else
	SUDO_CMD=sudo
fi;

# 修改文件属性
test -d ${UPGRADE_DIR}/post-upgrade && { \
		$SUDO_CMD chmod 777 $UPGRADE_DIR/post-upgrade -R; \
		}
test -d ${UPGRADE_DIR}/pre-upgrade && { \
		$SUDO_CMD chmod 777 $UPGRADE_DIR/pre-upgrade -R; \
		}
		
echo additional_files=\" > ${UPGRADE_DIR}.upgrade

find $UPGRADE_DIR -type f -o -type l \
	| grep -v "/\.git" \
	| grep -v "/\.version$" \
	| grep -v "$UPGRADE_DIR/pre-upgrade" \
	| grep -v "$UPGRADE_DIR/post-upgrade" \
	| sort \
	| sed "s#$UPGRADE_DIR/##" >> ${UPGRADE_DIR}.upgrade

echo \" >> ${UPGRADE_DIR}.upgrade

echo "" >> ${UPGRADE_DIR}.upgrade

echo optional_files=\" >> ${UPGRADE_DIR}.upgrade
test -d ${UPGRADE_DIR}/pre-upgrade && find ${UPGRADE_DIR}/pre-upgrade -type f \
		| grep -v "/\.git/" \
		| sort \
		| sed "s#$UPGRADE_DIR/##" >> ${UPGRADE_DIR}.upgrade
		
test -d ${UPGRADE_DIR}/post-upgrade && find ${UPGRADE_DIR}/post-upgrade -type f \
		| grep -v "/\.git/" \
		| sort \
		| sed "s#$UPGRADE_DIR/##" >> ${UPGRADE_DIR}.upgrade		
echo \" >> ${UPGRADE_DIR}.upgrade
echo "" >> ${UPGRADE_DIR}.upgrade
