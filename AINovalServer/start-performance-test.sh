#!/bin/bash
echo "正在以性能测试模式启动AI小说助手系统..."

# 设置Spring配置文件为性能测试配置
export SPRING_PROFILES_ACTIVE=performance-test

# 启动应用程序
echo "启动Spring Boot应用..."
mvn spring-boot:run -Dspring-boot.run.profiles=performance-test &
APP_PID=$!

# 等待应用程序启动
echo "等待应用程序启动..."
sleep 15

# 启动性能测试脚本
echo "启动性能测试脚本..."
export TEST_MODE=true
node performance_test_script.js

# 提示如何停止应用
echo "测试完成后，使用以下命令停止应用程序："
echo "kill $APP_PID" 