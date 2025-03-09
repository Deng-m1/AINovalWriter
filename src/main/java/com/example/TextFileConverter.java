package com.example;

import java.io.*;
import java.nio.charset.*;
import java.nio.file.*;
import java.util.stream.Stream;

public class TextFileConverter {
    // 固定的输入目录路径
    private static final String INPUT_DIR = "src\\main\\resources\\input";
    
    public static void main(String[] args) {
        try {
            // 确保输入目录存在
            Path inputPath = Paths.get(INPUT_DIR);
            if (!Files.exists(inputPath)) {
                Files.createDirectories(inputPath);
                System.out.println("已创建输入目录：" + INPUT_DIR);
                System.out.println("请将需要转换的txt文件放入该目录");
                return;
            }
            
            // 获取所有txt文件并处理
            try (Stream<Path> paths = Files.walk(inputPath)) {
                paths.filter(path -> path.toString().toLowerCase().endsWith(".txt"))
                     .forEach(TextFileConverter::convertToUtf8);
            }
            
            System.out.println("所有文件处理完成！");
            
        } catch (IOException e) {
            System.err.println("处理文件时发生错误: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    private static void convertToUtf8(Path file) {
        System.out.println("正在处理文件: " + file);
        
        try {
            // 尝试检测文件的编码
            String encoding = detectEncoding(file);
            System.out.println("检测到文件编码: " + encoding);
            
            // 如果文件已经是UTF-8格式，则跳过处理
            if ("UTF-8".equals(encoding)) {
                System.out.println("文件已经是UTF-8格式，无需转换: " + file);
                return;
            }
            
            // 创建临时文件路径
            Path tempFile = Paths.get(file.toString() + ".temp");
            
            try {
                // 读取原文件内容并以UTF-8格式写入临时文件
                try (BufferedReader reader = new BufferedReader(new InputStreamReader(
                        new FileInputStream(file.toFile()), encoding));
                     BufferedWriter writer = new BufferedWriter(new OutputStreamWriter(
                        new FileOutputStream(tempFile.toFile()), StandardCharsets.UTF_8))) {
                    
                    String line;
                    while ((line = reader.readLine()) != null) {
                        writer.write(line);
                        writer.newLine();
                    }
                }
                
                // 删除原文件
                Files.delete(file);
                // 将临时文件重命名为原文件名
                Files.move(tempFile, file);
                
                System.out.println("文件已转换为UTF-8格式: " + file);
                
            } catch (IOException e) {
                System.err.println("转换文件时发生错误: " + file);
                e.printStackTrace();
                // 如果发生错误，清理临时文件
                try {
                    Files.deleteIfExists(tempFile);
                } catch (IOException ex) {
                    // 忽略清理临时文件时的错误
                }
            }
        } catch (IOException e) {
            System.err.println("检测文件编码时发生错误: " + file);
            e.printStackTrace();
        }
    }
    
    private static String detectEncoding(Path file) throws IOException {
        // 读取文件的前几个字节来检测编码
        byte[] bytes = new byte[4];
        try (InputStream input = new FileInputStream(file.toFile())) {
            int read = input.read(bytes);
            if (read >= 3 && 
                bytes[0] == (byte)0xEF && 
                bytes[1] == (byte)0xBB && 
                bytes[2] == (byte)0xBF) {
                return "UTF-8";
            }
            
            if (read >= 2 && 
                bytes[0] == (byte)0xFF && 
                bytes[1] == (byte)0xFE) {
                return "UTF-16LE";
            }
            
            if (read >= 2 && 
                bytes[0] == (byte)0xFE && 
                bytes[1] == (byte)0xFF) {
                return "UTF-16BE";
            }
        }
        
        // 如果没有BOM，尝试检测是否为UTF-8编码
        try {
            byte[] content = Files.readAllBytes(file);
            // 检查是否符合UTF-8编码规则
            if (isValidUTF8(content)) {
                return "UTF-8";
            }
        } catch (Exception e) {
            // 如果读取失败，使用默认的GBK编码
        }
        
        // 如果不是UTF-8，默认使用GBK（考虑到中文环境）
        return "GBK";
    }
    
    /**
     * 检查字节数组是否是有效的UTF-8编码
     */
    private static boolean isValidUTF8(byte[] bytes) {
        try {
            CharsetDecoder decoder = StandardCharsets.UTF_8.newDecoder();
            decoder.decode(ByteBuffer.wrap(bytes));
            return true;
        } catch (CharacterCodingException e) {
            return false;
        }
    }
} 