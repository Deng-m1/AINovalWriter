@echo off
echo 正在以性能测试模式启动AI小说助手系统...

REM 设置Spring配置文件为性能测试配置
set SPRING_PROFILES_ACTIVE=performance-test

REM 启动应用程序
echo 启动Spring Boot应用...
start cmd /k "mvn spring-boot:run -Dspring-boot.run.profiles=performance-test"

REM 等待应用程序启动
echo 等待应用程序启动...
timeout /t 15

REM 启动性能测试脚本
echo 启动性能测试脚本...
set TEST_MODE=true
start cmd /k "node performance_test_script.js"

echo 性能测试环境已启动！
echo 应用程序运行在: http://localhost:8088/api
echo 测试脚本在单独的命令窗口中运行 