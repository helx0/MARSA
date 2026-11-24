@echo off
setlocal
set APP_HOME=%~dp0
cd /d "%APP_HOME%"
java -cp "%APP_HOME%gradle\wrapper\gradle-wrapper.jar" org.gradle.wrapper.GradleWrapperMain %*
exit /b %ERRORLEVEL%
