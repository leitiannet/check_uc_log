#!/usr/bin/expect

# write by leitiannet
# purpose: 远程主机上执行命令和上传文件

proc Usage {} {
	# 使用双冒号（::）声明全局变量
	regsub ".*/" $::argv0 "" name  
	send_user "Usage:\t$name \[shell|upload\] args...\n" 
	send_user "\t$name shell remotehost remoteport remoteuser remotepwd remotecmd\n" 
	send_user "\t$name upload remotehost remoteport remoteuser remotepwd localfile remotefile\n" 
}

# 定义远程执行过程以及输入输出参数
proc RemoteExec {in_host in_port in_user in_pwd in_cmd out_res} {
	# 定义引用（reference）
	upvar $out_res response
	
	set timeout -1
	for {set i 1} {$i < 3} {incr i} {
        spawn -noecho ssh $in_user@$in_host -p $in_port "$in_cmd"
        expect {
            -nocase "password:"
            {
                send "$in_pwd\n"
                break
            }
            -nocase "(yes/no)"
            {
                send "yes\n"
                continue
            }
            timeout
            {
                set response "Timeout while connecting to host $in_host"
                return -1
            }
        }
		sleep 1
    }
	expect {
        -nocase "password:"
        {
            set response "Wrong password inputed for $in_user@$in_host"
            return -2
        }
        -nocase "denied"
        {	
			set response "Wrong password inputed for $in_user@$in_host"
            return -2
        }
        timeout
        {
            set response "Timeout while checking password for $in_user@$in_host"
            return -3
        }
		eof
		{
		}	
    }
	return 0
}

# 定义远程上传过程以及输入输出参数
proc RemoteUpload {in_host in_port in_user in_pwd in_lfile in_rfile out_res} {
	# 定义引用（reference）
	upvar $out_res response
	
	set timeout 100
	spawn scp -r -P $in_port $in_lfile $in_user@$in_host:$in_rfile
	expect {
		-nocase "password:"
		{
			send "$in_pwd\r"
		}
		-nocase "(yes/no)"
		{
			send "yes\n"
			expect "password"
			send "$remotepwd\r"
		}
		timeout
		{
			set response "Timeout while connecting to host $in_host"
			return -1
		}
	}
	expect {
        -nocase "denied"
        {	
			set response "Wrong password inputed for $in_user@$in_host"
            return -2
        }
        timeout
        {
            set response "Timeout while checking password for $in_user@$in_host"
            return -3
        }
		eof
		{
		}		
    }
	return 0
}

# 定义远程下载过程以及输入输出参数
proc RemoteDownload {in_host in_port in_user in_pwd in_lfile in_rfile out_res} {
	# 定义引用（reference）
	upvar $out_res response
	
	set timeout 100
	spawn scp -r -P $in_port $in_user@$in_host:$in_rfile $in_lfile 
	expect {
		-nocase "password:"
		{
			send "$in_pwd\r"
		}
		-nocase "(yes/no)"
		{
			send "yes\n"
			expect "password"
			send "$remotepwd\r"
		}
		timeout
		{
			set response "Timeout while connecting to host $in_host"
			return -1
		}
	}
	expect {
        -nocase "denied"
        {	
			set response "Wrong password inputed for $in_user@$in_host"
            return -2
        }
		"*No such file*" {
			set response "No such file"
            return -4
		}
        timeout
        {
            set response "Timeout while checking password for $in_user@$in_host"
            return -3
        }
		eof
		{
		}		
    }
	return 0
}

##判断参数个数
puts "script: $argv0"
puts "arguments is: $argc"
puts "arguments are: $argv"
if {$argc < 4} {
	Usage
	exit 1  
}

#log_user 0
#log_file remote_log.txt

set ret ""
set out_res ""
set remoteop "[lindex $argv 0]"
if {$remoteop=="shell"} {
	set remotehost 	"[lindex $argv 1]"
	set remoteport 	"[lindex $argv 2]"
	set remoteuser 	"[lindex $argv 3]"
	set remotepwd  	"[lindex $argv 4]"
	set remotecmd	"[lindex $argv 5]"
	set ret [RemoteExec $remotehost $remoteport $remoteuser $remotepwd $remotecmd out_res]
} elseif {$remoteop=="upload" || $remoteop=="download"} {
	set remotehost "[lindex $argv 1]"
	set remoteport "[lindex $argv 2]"
	set remoteuser "[lindex $argv 3]"
	set remotepwd  "[lindex $argv 4]"
	set localfile  "[lindex $argv 5]"
	set remotefile "[lindex $argv 6]"
	if {$remoteop=="upload"} {
		set ret [RemoteUpload $remotehost $remoteport $remoteuser $remotepwd $localfile $remotefile out_res]
	} else {
		set ret [RemoteDownload $remotehost $remoteport $remoteuser $remotepwd $localfile $remotefile out_res]
	}
} else {
	Usage
	exit 1
}

if {$ret < 0} {
    puts "RemoteExec failed (code: $ret, msg: $out_res)."
    exit 1
} else {
	exit 0
}



