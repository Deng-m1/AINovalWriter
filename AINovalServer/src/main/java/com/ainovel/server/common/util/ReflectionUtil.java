package com.ainovel.server.common.util;

import java.lang.reflect.Field;
import java.lang.reflect.Method;

/**
 * 反射工具类
 */
public class ReflectionUtil {

    /**
     * 获取对象的属性值
     * 
     * @param obj 对象
     * @param propertyName 属性名
     * @param defaultValue 默认值
     * @return 属性值，如果获取失败则返回默认值
     */
    public static Object getPropertyValue(Object obj, String propertyName, Object defaultValue) {
        if (obj == null || propertyName == null || propertyName.isEmpty()) {
            return defaultValue;
        }
        
        try {
            // 尝试通过getter方法获取
            String getterName = "get" + propertyName.substring(0, 1).toUpperCase() + propertyName.substring(1);
            Method getter = obj.getClass().getMethod(getterName);
            return getter.invoke(obj);
        } catch (Exception e) {
            try {
                // 尝试通过属性名直接获取
                Field field = obj.getClass().getDeclaredField(propertyName);
                field.setAccessible(true);
                return field.get(obj);
            } catch (Exception ex) {
                return defaultValue;
            }
        }
    }

    /**
     * 设置对象的属性值
     * 
     * @param obj 对象
     * @param propertyName 属性名
     * @param value 值
     * @return 是否设置成功
     */
    public static boolean setPropertyValue(Object obj, String propertyName, Object value) {
        if (obj == null || propertyName == null || propertyName.isEmpty()) {
            return false;
        }
        
        try {
            // 尝试通过setter方法设置
            String setterName = "set" + propertyName.substring(0, 1).toUpperCase() + propertyName.substring(1);
            Method setter = null;
            
            // 查找与属性名匹配的setter方法
            for (Method method : obj.getClass().getMethods()) {
                if (method.getName().equals(setterName) && method.getParameterCount() == 1) {
                    setter = method;
                    break;
                }
            }
            
            if (setter != null) {
                setter.invoke(obj, value);
                return true;
            }
            
            // 尝试通过属性名直接设置
            Field field = obj.getClass().getDeclaredField(propertyName);
            field.setAccessible(true);
            field.set(obj, value);
            return true;
        } catch (Exception e) {
            return false;
        }
    }
} 