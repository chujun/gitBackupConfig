@echo off
echo please run as adminstrator role ,fail:
echo select JAVA version:
echo 1. JAVA 8 
echo 2. JAVA  11
echo 3. JAVA 17
set /p choice=please input selector(1/2/3):

if "%choice%"=="1" set NEW_JAVA_HOME=D:\Program Files\jdk\openjdk-8u44-windows-i586\java-se-8u44-ri
if "%choice%"=="2" set NEW_JAVA_HOME=D:\Program Files\jdk\openjdk-11.0.2_windows-x64_bin\jdk-11.0.2
if "%choice%"=="3" set NEW_JAVA_HOME=D:\Program Files\jdk\openjdk-17.0.2_windows-x64_bin\jdk-17.0.2

REM 永久生效
setx JAVA_HOME "%NEW_JAVA_HOME%" /REM
echo JAVA_HOME= %NEW_JAVA_HOME%
echo please reopen cmd window ,and active config

echo current java version:
java -version

REM 按任意键退出
pasue
