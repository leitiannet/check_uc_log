**目的：**

1. 根据requestid从本地日志文件/日志目录中提取相关请求的日志

2. 自动登录到远程机器上根据requestid提取相关请求的日志  


**说明：**
1. requestid格式：	msgserver-10.255.0.68-1494032304.356359546.431和1494032304.356359546.431
2. 日志文件格式：	msgserver-2016-04-20.log、msgserver.log-20170424、msgserver.log、msgserver.log.1和msgserver.log.1.gz
3. 远程用户名和密码默认为yanfa/yanfa，可以在命令行通过USER和PASSWD指定

**使用：**  
$./check_uc_log.sh -f "msgserver-10.255.0.68-1494647025.59224910.762"  
$_DEBUG_=on ./check_uc_log.sh -f "msgserver-10.255.0.68-1494647025.59224910.762"  
$USER=yanfa PASSWD=yanfa ./check_uc_log.sh -f "msgserver-10.255.0.68-1494647025.59224910.762
