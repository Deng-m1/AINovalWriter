@echo off
echo 正在以测试模式启动AINovalServer...
echo 测试模式下，所有API请求将被允许通过，无需认证

set JAVA_OPTS=-Dspring.profiles.active=test -Dlogging.level.root=INFO -Dlogging.level.com.ainovel=DEBUG -Dlogging.level.org.springframework.security=DEBUG -Dlogging.level.org.springframework.web=DEBUG

echo 使用以下Java选项: %JAVA_OPTS%

cd %~dp0
call mvnw spring-boot:run -Dspring-boot.run.jvmArguments="%JAVA_OPTS%"

echo 应用程序已停止运行 