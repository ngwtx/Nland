#!/bin/bash

set -e

INSTALL_PATH="/usr/local/phantom"
MANAGER="null"
SYSTEM_TYPE="null"
BOOT="null"

# 卸载phantom
function uninstall()
{
	if [ $MANAGER = "systemctl" ]; then
		systemctl disable phantom
		systemctl stop phantom
		rm -rf /etc/systemd/system/phantom.service
		systemctl daemon-reload
	elif [ $MANAGER = "service" ]; then
		if [ $BOOT == "chkonfig" ]; then chkconfig --del phantom
		elif [ $BOOT == "update-rc.d" ]; then update-rc.d -f phantom remove; fi
		service phantom stop
		rm -rf /etc/init.d/phantom
	fi
	rm -rf $INSTALL_PATH
}

# 可执行文件安装
function update_bin()
{
	if [ $SYSTEM_TYPE == 32 ]; then
		cp -r phantom/32/* $INSTALL_PATH/
	elif [ $SYSTEM_TYPE == 64 ]; then
		cp -r phantom/64/* $INSTALL_PATH/
	fi
  chmod +x $INSTALL_PATH/main/main
  chmod +x $INSTALL_PATH/phantom.sh
	echo "Create phantom executable file in $INSTALL_PATH"

	# 设置配置文件
	cp -f phantom/config.ini $INSTALL_PATH/etc/config.ini
	echo "set config file $INSTALL_PATH/etc/config.ini"
}

function create_system_service()
{
	if [ $MANAGER == "systemctl" ]; then
		cat ./services/phantom.service | sed "s@#INSTALL_PATH#@$INSTALL_PATH@" \
			> /etc/systemd/system/phantom.service
		echo "Add phantom.service in /etc/systemd/system/."
		systemctl daemon-reload
		echo "systemctl set success."
	elif [ $MANAGER == "service" ]; then
		cat ./services/lsb.sh | sed "s@#INSTALL_PATH#@$INSTALL_PATH@" \
			> /etc/init.d/phantom
		chmod +x /etc/init.d/phantom
		echo "Add phantom in /etc/init.d/."
		echo "service set seccess."
	fi
}

# 设置启动项
function set_boot()
{
	if [ $MANAGER == "systemctl" ]; then
		systemctl enable phantom
	else
		if [ $BOOT == "chkonfig" ]; then
			chkconfig --add phantom
		elif [ $BOOT == "update-rc.d" ]; then
			update-rc.d phantom defaults 99
		fi
	fi
}

# 初始化环境变量 ------------------------------------------------------------
# 系统服务管理
echo "安装脚本启动"

if [ `type systemctl > /dev/null 2>&1;echo $?` == 0 ]; then
	MANAGER="systemctl"
elif [ `type service > /dev/null 2>&1;echo $?` == 0 ]; then 
	MANAGER='service'
fi
if [ $MANAGER == "null" ]; then
	echo -e "\033[31mERROR\033[0m 系统任务管理获取失败，安装退出，建议手动安装。"
	exit 1
fi

# 启动项获取
if [ `type update-rc.d > /dev/null 2>&1;echo $?` == 0 ]; then
	BOOT="update-rc.d"
elif [ `type chkconfig > /dev/null 2>&1;echo $?` == 0 ]; then
	BOOT="chkonfig"
fi

# 系统位数
SYSTEM_TYPE=`getconf LONG_BIT`
if [ $SYSTEM_TYPE != 32 ] && [ $SYSTEM_TYPE != 64 ]; then
	echo -e "\033[31mERROR\033[0m 系统类型获取失败，安装退出，建议手动安装。"
	exit 1
fi

# Uninstall
if [ ${1:-"null"} == "uninstall" ]; then
	uninstall
	echo "代理客户端卸载完成。"
	exit 0
fi

echo "Environment："
echo "	安装路径：$INSTALL_PATH"
echo "	系统服务托管：$MANAGER"
echo "	操作系统类型：Linux $SYSTEM_TYPE位"
if [ $MANAGER != "systemctl" ]; then echo "	启动项设置工具：$BOOT"; fi

# main --------------------------------------------------------------------

#spawn scp root@10.20.29.123:/home/update_pks.tar.gz /home/phantom/ df -Th
#expect "*password"
#send "dbapp#2020\n"
#expect eof

if [ ! -d $INSTALL_PATH ];then
	mkdir -p $INSTALL_PATH/log
else
#	read -t 10 -p "检测到已安装代理客户端，是否覆盖安装。（警告：这将会丢失之前安装的代理客户端）[Y/n]" input
#	if [[ ${input:-"yes"} =~ [yY][eE][sS]|[yY] ]];then
		uninstall
#		echo "已经卸载旧流量代理客户端。"
fi
	mkdir -p $INSTALL_PATH/log

update_bin
if [ $? != 0 ];then
	echo -e "\033[31mERROR\033[0m 可执行文件安装失败，将退出安装。 请确认当前用户是否有$INSTALL_PATH的写入权限。"
	uninstall
	exit 1
fi

create_system_service
if [ $? != 0 ];then
	echo -e "\033[31mERROR\033[0m 系统服务创建失败, 将退出安装。"
	uninstall
	exit 1
fi

read -t 10 -p "是否将设置代理客户端开机自启？[Y/n]" input
if [ $Boot!="null" ];then
	if [[ ${input:-"yes"} =~ [yY][eE][sS]|[yY] ]];then
		set_boot
		echo "设置开机自启成功。"
	fi
else
	echo -e "\033[31mERROR\033[0m 无法找到开机启动项设置，需要手动添加开机启动项！"
fi


read -t 10 -p "是否立即启动代理客户端？[Y/n]" input
if [[ ${input:-"yes"} =~ [yY][eE][sS]|[yY] ]];then
	if [ $MANAGER == "systemctl" ]; then systemctl start phantom
	elif [ $MANAGER == "service" ]; then service phantom start; fi
	echo "代理客户端已启动。"
fi

echo "代理客户端安装成功,请到中心配置代理规则。"
