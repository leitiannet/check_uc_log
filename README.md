# check_uc_log
# purpose: 分析uc相关日志
#          requestid格式：msgserver-10.255.0.68-1494032304.356359546.431和1494032304.356359546.431
# 		     日志文件格式：msgserver-2016-04-20.log、msgserver.log-20170424、msgserver.log、msgserver.log.1和msgserver.log.1.gz
# note:	1、支持本地和远程（仅支持msgserver-10.255.0.68-1494032304.356359546.431格式的requestid）
#       2、支持文件和目录
#		    3、支持压缩文件
#		    4、远程用户名和密码默认为yanfa/yanfa，可以在命令行指定USER和PASSWD指定
