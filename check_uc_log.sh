#!/bin/bash

# write by leitiannet
# purpose: 分析uc相关日志
#          requestid格式：msgserver-10.255.0.68-1494032304.356359546.431和1494032304.356359546.431
# 		   日志文件格式：msgserver-2016-04-20.log、msgserver.log-20170424、msgserver.log、msgserver.log.1和msgserver.log.1.gz
# note：1、支持本地和远程（仅支持msgserver-10.255.0.68-1494032304.356359546.431格式的requestid）
#     	2、支持文件和目录
#		3、支持压缩文件
#		4、远程用户名和密码默认为yanfa/yanfa，可以在命令行指定USER和PASSWD指定
# TODO：使用map保存整行浪费内存？输出后作个标记

# 日志和远程主机默认信息
# LogDir和RemoteDir以/结尾
LogDir='/var/log/uclog/'
LogSuffix='.log'
RemotePort=22
RemoteDir="/tmp/"

# 脚本信息
PROGNAME=$(basename $0)
ScriptFile=`basename $0`
ScriptDir=`dirname $0`

#Request相关的全局变量
RequestId=""
RequestServer=""
RequestServerIp=""
RequestTimestamp=""
RequestDate=""

Reset()
{
	RequestId=""
	RequestServer=""
	RequestServerIp=""
	RequestTimestamp=""
	RequestDate=""
}

# FUNCNAME是一个数组，bash中会将它维护成类似一个堆栈的形式
ShowFunc()
{
	[[ "$_DEBUG_" == "on" ]] && echo `date +"%F %T"` "function: ${FUNCNAME[1]} $@" 
}

ShowInfo()
{
	[[ "$_DEBUG_" == "on" ]] && echo `date +"%F %T"` "function: ${FUNCNAME[1]} $1"
}

ShowError()
{
	msg="error param"
	if [ $# -gt 0 ]; then
		msg=$1
	fi
	echo `date +"%F %T"` "${FUNCNAME[1]} $msg"
}

ShowRequest()
{
	if [[ "$_DEBUG_" == "on" ]]; then
		echo `date +"%F %T"` "function: ${FUNCNAME[1]}"
		echo -e "\trequestid:\t" $requestid
		echo -e "\trequestserver:\t" $RequestServer
		echo -e "\trequestip:\t" $RequestServerIp
		echo -e "\trequestdate:\t" $RequestDate
	fi
}

# 功能：是否包含子串
# 参数：str、substr
# 说明：字符串不支持正则表达式
Contains()
{
	if [ $# -lt 2 ]; then
		ShowError
		return 1
	fi
	
	local str=$1
	local substr=$2
	local result=`echo $str | grep $substr`
	if [[ "$result" != "" ]]
	then
		return 0
	fi
	return 1
}

# 功能：是否为绝对路径
# 参数：filename
IsAbsolutePath()
{
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local filename=$1
	local result=`echo $filename | grep -P '^/'`
	if [[ "$result" != "" ]]
	then
		return 0
	fi
	return 1
}

IsCompressFile()
{
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local filename=$1
	local result=`echo $filename | grep "\.gz"`
	if [[ "$result" != "" ]]
	then
		return 0
	fi
	return 1
}
# 功能：解析requestid
# 参数：requestid
ParseRequestid()
{	
	local requestid=$1
	if [ -n "$requestid" ]; then
		local server=""
		local ip=""
		local timestamp=""
		
		Contains $requestid "-"
		if [ $? == 1 ] ; then
			timestamp=`echo $requestid | cut -d "." -f1`
		else
			server=`echo $requestid | cut -d "-" -f1`
			ip=`echo $requestid | cut -d "-" -f2`
			local timestamprand=`echo $requestid | cut -d "-" -f3`
			timestamp=`echo $timestamprand | cut -d "." -f1`
		fi
		
		Reset
		RequestId=$requestid
		RequestServer=$server
		RequestServerIp=$ip
		RequestTimestamp=$timestamp
		RequestDate=`date -d @$timestamp  "+%Y-%m-%d %H:%M:%S"`
		ShowRequest
		return 0
	fi
	return 1
}

# 实现函数
FilterLogByRequestid()
{
	if [ $# -lt 2 ]; then
		ShowError
		return 1
	fi
	local requestid=$1
	local filename=$2
	if [ ! -f $filename ]; then
		ShowError "$filename not exist"
		return 1
	fi
	
	IsCompressFile $filename
	local result=$?
	#TODO:grep正则表达式更方便，但是读取大文件使用awk和sed
	if [ $result == 1 ] ; then
		eval $(awk -v req=$requestid 'BEGIN{min=0;max=0;keyArray[req]=0;}
		($0 ~ /<requestid:/ || $0 ~ /<gid:/){
			s1="";
			s2="";
			#提取requestid
			p1=match($0,/<requestid:[0-9a-z\.-]+>/);
			if(p1>0)
			{
				s1=substr($0, p1+11, RLENGTH-12);
			}
			#提取gid
			p2=match($0,/<gid:[0-9]+>/);
			if(p2>0)
			{
				s2=substr($0, p2+5, RLENGTH-6);
			}
			found=0;
			for(key in keyArray)
			{
				if(key != "" && (key == s1 || key == s2))
				{
					found=1;
					break;
				}
			}
			if(found>0)
			{
				if(min==0)
				{
					min=NR;
				}
				max=NR;
				if (s2!="")
				{
					keyArray[s2]=0
				}
			}
		}
		END{printf("startline=%d; endline=%d\n", min, max);}' $filename)
	else
		eval $(gzip -d -c $filename | awk -v req=$requestid 'BEGIN{min=0;max=0;keyArray[req]=0;}
		($0 ~ /<requestid:/ || $0 ~ /<gid:/){
			s1="";
			s2="";
			#提取requestid
			p1=match($0,/<requestid:[0-9a-z\.-]+>/);
			if(p1>0)
			{
				s1=substr($0, p1+11, RLENGTH-12);
			}
			#提取gid
			p2=match($0,/<gid:[0-9]+>/);
			if(p2>0)
			{
				s2=substr($0, p2+5, RLENGTH-6);
			}
			found=0;
			for(key in keyArray)
			{
				if(key != "" && (key == s1 || key == s2))
				{
					found=1;
					break;
				}
			}
			if(found>0)
			{
				if(min==0)
				{
					min=NR;
				}
				max=NR;
				if (s2!="")
				{
					keyArray[s2]=0
				}
			}
		}
		END{printf("startline=%d; endline=%d\n", min, max);}')
	fi 
	
	echo "FilterUcLogByRequestid():"
	echo -e "\t" startline=$startline endline=$endline
	if [ "$startline" -gt 0 -a "$endline" -gt 0 -a "$endline" -ge "$startline" ]; then
		
		printf "================================================%s================================================\n" $filename
		if [ $result == 1 ] ; then
			#sed -n "$startline, $endline p" $filename
			awk -v start=$startline -v end=$endline 'BEGIN{}
			{
				if(NR>=start && NR<=end)
				{
					print NR, "\t", $0
				}
			}' $filename
		else
			gzip -d -c $filename | awk -v start=$startline -v end=$endline 'BEGIN{}
			{
				if(NR>=start && NR<=end)
				{
					print NR, "\t", $0
				}
			}'
		fi
		
		printf "================================================%s================================================\n" $filename
		return 0
	else
		printf "\t%s found no \"%s\"\n\n" $filename $requestid
		return 1
	fi
}

# 功能：指定文件中过滤日志
# 参数：requestid、filename
# 说明：filename必须，且为全路径
FilterFileByRequestid()
{
	ShowFunc $@
	if [ $# -lt 2 ]; then
		ShowError
		return 1
	fi
	
	local requestid=$1
	local filename=$2
	IsAbsolutePath $filename
	if [ $? == 1 ] ; then
		printf "you must input absolute path\n"
		return 1
	fi
	
	FilterLogByRequestid $requestid $filename
	return $?
}

# 功能：指定目录下过滤日志
# 参数：requestid、dir
# 说明：dir必须，且为全路径，不支持..或.。文件格式：
FilterDirByRequestid()
{
	ShowFunc $@
	if [ $# -lt 2 ]; then
		ShowError
		return 1
	fi
	
	local requestid=$1
	local dir=$2
	IsAbsolutePath $dir
	if [ $? == 1 ] ; then
		printf "you must input absolute path\n"
		return 1
	fi
	local fileList=`ls -t $dir`
	for file in $fileList
	do
		local result=`echo $file | grep -P "$RequestServer.*\.log"`
		if [[ "$result" != "" ]]
		then
			FilterLogByRequestid $requestid $dir$file
			if [ $? == 0 ] ; then
				return 0
			fi
		fi
	done
}

# 功能：过滤日志
# 参数：requestid、[file|dir]
# 说明：file或dir支持全路径和相对路径
FilterLocalByRequestid()
{
	ShowFunc $@
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local requestid=$1
	local requestfile=""
	local file=""
	local dir=""
	if [ $# -lt 2 ]; then
		dir=$LogDir
	else
		requestfile=$2
		IsAbsolutePath $requestfile
		if [ $? == 1 ] ; then
			requestfile=$LogDir$requestfile
		fi
	
		if [ -f "$requestfile" ]; then
			file=$requestfile
		elif [ -d "$requestfile" ]; then  
			dir=$requestfile
			local result=`echo $dir | grep -P '/$'`
			if [[ "$result" == "" ]]
			then
				dir=$dir"/"
			fi
		else
			echo "$requestfile not file or dir"
			return 1
		fi
	fi
	echo "file:$file, dir:$dir"
	
	if [[ "$file" != "" ]]; then
		FilterFileByRequestid $requestid $file
	fi
	
	if [[ "$dir" != "" ]]; then
		FilterDirByRequestid $requestid $dir
	fi
	return $?
}

# 直接输出到控制台可能显示不全，所以首先写入远程主机然后下载并输出
FilterRemoteByRequestid()
{
	ShowFunc $@
	local scriptfile=$ScriptDir/$ScriptFile
	local remotefile=$RemoteDir$ScriptFile
	local cmd="/tmp/check_uc_log.sh -f $@";
	local tmplog=$RemoteDir$1".log"
	
	local remoteuser="yanfa"
	local remotepwd="yanfa"
	if [[ "$USER" != "" ]]; then
		remoteuser=$USER
	fi
	if [[ "$PASSWD" != "" ]]; then
		remotepwd=$PASSWD
	fi
	
	echo -e "\n*************************************************remote shell*************************************************"
	$ScriptDir/remote_shell.sh "upload" "$RequestServerIp" "$RemotePort" "$remoteuser" "$remotepwd" "$scriptfile" "$remotefile"
	if [ $? == 1 ] ; then
		return 1
	fi
	sleep 1
	echo -e "========================\n"
	$ScriptDir/remote_shell.sh "shell" "$RequestServerIp" "$RemotePort" "$remoteuser" "$remotepwd" "$cmd > $tmplog"
	sleep 1
	echo -e "========================\n"
	rm -rf $tmplog
	$ScriptDir/remote_shell.sh "download" "$RequestServerIp" "$RemotePort" "$remoteuser" "$remotepwd" "$tmplog" "$tmplog"
	sleep 1
	echo -e "========================\n"
	$ScriptDir/remote_shell.sh "shell" "$RequestServerIp" "$RemotePort" "$remoteuser" "$remotepwd" "[ -e $remotefile ] && rm -rf $remotefile;[ -e $tmplog ] && rm -rf $tmplog;"
	
	local show=1
	read -t 10 -n1 -p "Do you want to show result [Y/N]? " answer1
	case $answer1 in
		Y | y)
			show=1
			;;
		N | n)
			show=0
			;;
	esac
	echo
	if [ $show == 1 ]; then
		echo -e "\n*************************************************list result*************************************************"
		cat $tmplog
		
		local delete=1
		read -t 5 -n1 -p "Do you want to delete local temporary files:\"$tmplog\" [Y/N]? " answer2
		case $answer2 in
			Y | y)
				delete=1
				;;
			N | n)
				delete=0
				;;
		esac
		[ $delete == 1 ] && [ -e $tmplog ] && rm -rf $tmplog
		echo
	fi
	return $?
}

FilterLog()
{
	ShowFunc $@
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local requestid=$1
	local remote=1
	local internalips=(`hostname -I`)
	ParseRequestid $requestid
	if [ $? == 1 ] ; then
		printf "Parse %s fail" $requestid
		return 1
	fi
	if [ $RequestServerIp != "" ]; then
		for ip in ${internalips[@]}  
		do  
			if [ $ip = $RequestServerIp ]; then
				remote=0
				break
			fi
		done
		
	fi
	
	ShowInfo "RequestServerIp:$RequestServerIp, InternalIp:${internalips[@]}, remote:$remote"   
	if [ $remote == 1 ]; then
		FilterRemoteByRequestid $@
	else
		FilterLocalByRequestid $@
	fi
	return $?
}

# 功能：过滤err日志
# 参数：filename
# 说明：filename支持全路径和相对路径
FilterError()
{
	ShowFunc $@
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local filename=$1
	IsAbsolutePath $filename
	if [ $? == 1 ] ; then
		filename=$LogDir$filename
	fi
	
	printf "================================================%s================================================\n" $filename
	awk '{
		s1="";
		s2="";
		#提取requestid
		p1=match($0,/<requestid:[0-9a-z\.-]+>/);
		if(p1>0)
		{
			s1=substr($0, p1+11, RLENGTH-12);
		}
		#提取gid
		p2=match($0,/<gid:[0-9]+>/);
		if(p2>0)
		{
			s2=substr($0, p2+5, RLENGTH-6);
		}
		#防止gid相同
		if(s1 != "" && s2 != "")
		{
			gidMap[s2]=s1
		}
		#提取err
		if($5 ~ /err/)
		{
			printf("err\tgid:%s\trequestid:%s\n", s2, gidMap[s2])
			print NR "\t" $0
		}
	}' $filename
	printf "================================================%s================================================\n" $filename
	return 0
}

# 功能：过滤失败的请求
# 参数：filename
# 说明：filename支持全路径和相对路径
FilterFailRequest()
{
	ShowFunc $@
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local filename=$1
	IsAbsolutePath $filename
	if [ $? == 1 ] ; then
		filename=$LogDir$filename
	fi
	
	printf "================================================%s================================================\n" $filename
	awk 'BEGIN{total=0}{
		s1="";
		#提取requestid
		p1=match($0,/<requestid:[0-9a-z\.-]+>/);
		if(p1>0)
		{
			s1=substr($0, p1+11, RLENGTH-12);
		}
		#提取请求
		if($0 ~ /param/)
		{
			reqMap[s1]= NR"\t"$0
		}
		#提取code
		if($0 ~ /FinishAndSendResponse/ && $0 ~ /response:/ && $0 ~ /code/)
		{
			p3=match($0, /"code":[0-9]+,/);
			if(p3>0)
			{
				s3=substr($0, p3+7, RLENGTH-8);
				if(s3 != "" && s3 != "0")
				{
					total++
					printf("code:%s\trequestid:%s\n", s3, s1)
					print reqMap[s1]
					print NR"\t"$0
				}
			}
		}
	}END{printf("\ttotal:%d\n",total)}' $filename
	printf "================================================%s================================================\n" $filename
	return 0
}

# 功能：过滤失败的云会议调用
# 参数：filename
# 说明：filename支持全路径和相对路径
FilterFailConferenceRequest()
{
	ShowFunc $@
	if [ $# -lt 1 ]; then
		ShowError
		return 1
	fi
	
	local filename=$1
	Contains $filename "uniformserver"
	if [ $? == 1 ] ; then
		echo "must input uniformserver log"
		return 1
	fi
	
	IsAbsolutePath $filename
	if [ $? == 1 ] ; then
		filename=$LogDir$filename
	fi
	
	printf "================================================%s================================================\n" $filename
	awk 'BEGIN{total=0}{
		s1="";
		s2="";
		s3="";
		#提取requestid
		p1=match($0,/<requestid:[0-9a-z\.-]+>/);
		if(p1>0)
		{
			s1=substr($0, p1+11, RLENGTH-12);
		}
		#提取gid
		p2=match($0,/<gid:[0-9]+>/);
		if(p2>0)
		{
			s2=substr($0, p2+5, RLENGTH-6);
		}
		if(s1 != "" && s2 != "")
		{
			gidMap[s2]=s1
		}
		#提取请求
		if($0 ~ /curlrestwithcookie/ && $0 ~ /HttpCurlWithCookie/ && $0 ~ /http request/)
		{
			reqMap[s2]=NR"\t"$0
		}
		#提取status
		if($0 ~ /curlrestwithcookie/ && $0 ~ /http response code:200/ && $0 ~ /status/)
		{
			p3=match($0, /"status":[0-9]+,/);
			if(p3>0)
			{
				s3=substr($0, p3+9, RLENGTH-10);
				if(s3 != "" && s3 != "0")
				{
					total++
					statusMap[s3]++
					printf("status:%s\trequestid:%s\n", s3, gidMap[s2])
					print reqMap[s2]
					print NR"\t"$0
				}
			}
		}
	}END{for(key in statusMap) printf("%s:%d\n", key, statusMap[key]);printf("\ttotal:%d\n",total)}' $filename
	printf "================================================%s================================================\n" $filename
	return 0
}

Usage()
{
	cat << _EOF_
Usage: $PROGNAME <option> <args...>
where option is one of:
	-h                                     :display this help and exit
	-f <requestid> [file|dir]              :filter log by requestid from file or dir
	-e <filename>                          :filter error from file
	-r <filename>                          :filter fail request from file
	-c <filename>                          :filter fail conference request from file(only uniformserver)
example:
	./$PROGNAME -f "msgserver-10.255.0.68-1494647025.59224910.762"
	./$PROGNAME -e "msgserver.log"
	./$PROGNAME -r "/home/uc_message_server/golang/msgserver.log"
	./$PROGNAME -c "/home/uc_message_server/golang/uniformserver.log"
	_DEBUG_=on ./$PROGNAME -f "msgserver-10.255.0.68-1494647025.59224910.762"
	USER=yanfa PASSWD=yanfa ./$PROGNAME -f "msgserver-10.255.0.68-1494647025.59224910.762"
_EOF_
}

# 脚本入口
if [ $# -gt 0 ]; then 
	option=$1
	shift
	case $option in
		-f)
			FilterLog $@
			;;
		-e)
			FilterError $@
			;;
		-r)
			FilterFailRequest $@
			;;
		-c)
			FilterFailConferenceRequest $@
			;;
		-t)
			FilterLogByRequestid "msgserver-10.255.0.68-1494556283.765882772.463" "msgserver.log.1.gz"
			;;
		-h | --help)
			Usage
			exit 0
			;;
		*)
			echo "not implement"
			exit 1
	esac
else
	Usage
	exit 0
fi