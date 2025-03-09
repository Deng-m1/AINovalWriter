package com.example;

import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.math.BigInteger;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.regex.Pattern;

import org.apache.poi.xwpf.usermodel.ParagraphAlignment;
import org.apache.poi.xwpf.usermodel.XWPFDocument;
import org.apache.poi.xwpf.usermodel.XWPFParagraph;
import org.apache.poi.xwpf.usermodel.XWPFRun;
import org.apache.poi.xwpf.usermodel.XWPFStyle;
import org.apache.poi.xwpf.usermodel.XWPFStyles;
import org.openxmlformats.schemas.wordprocessingml.x2006.main.CTString;
import org.openxmlformats.schemas.wordprocessingml.x2006.main.CTStyle;
import org.openxmlformats.schemas.wordprocessingml.x2006.main.STStyleType;

public class NovelFormatter {
    // 固定的输入输出文件路径
    private static final String INPUT_FILE = "src\\main\\resources\\input\\novel.docx";
    private static final String OUTPUT_FILE = "src\\main\\resources\\output\\novel_formatted.docx";
    
    // 标题匹配模式：匹配"第X章"格式，其中X可以是任意数字
    private static final Pattern CHAPTER_PATTERN = Pattern.compile("第[0-9一二三四五六七八九十百千]+章.*");

    public static void main(String[] args) {
        try {
            // 确保输入和输出目录都存在
            Path inputPath = Paths.get(INPUT_FILE);
            Path outputPath = Paths.get(OUTPUT_FILE);
            inputPath.getParent().toFile().mkdirs();
            outputPath.getParent().toFile().mkdirs();
            
            // 检查输入文件是否存在
            if (!inputPath.toFile().exists()) {
                System.err.println("错误：输入文件不存在，请将小说文件放在以下位置：" + INPUT_FILE);
                return;
            }
            
            formatNovelTitles(INPUT_FILE, OUTPUT_FILE);
            System.out.println("文件处理完成！输出文件保存在: " + OUTPUT_FILE);
        } catch (IOException e) {
            System.err.println("处理文件时发生错误: " + e.getMessage());
            e.printStackTrace();
        }
    }

    private static void formatNovelTitles(String inputFile, String outputFile) throws IOException {
        try (XWPFDocument doc = new XWPFDocument(new FileInputStream(inputFile))) {
            // 确保样式存在
            createHeadingStylesIfNotExists(doc);
            
            // 处理文档中的每个段落
            for (XWPFParagraph paragraph : doc.getParagraphs()) {
                String text = paragraph.getText().trim();
                if (isTitleLine(text)) {
                    System.out.println("找到章节标题: " + text);
                    
                    // 清除段落中现有的运行
                    while (paragraph.getRuns().size() > 0) {
                        paragraph.removeRun(0);
                    }
                    
                    // 设置段落样式为标题1
                    paragraph.setStyle("Heading1");
                    
                    // 创建新的运行并设置格式
                    XWPFRun run = paragraph.createRun();
                    run.setText(text);
                    run.setBold(true);                // 粗体
                    run.setFontSize(16);              // 16号字体
                    run.setFontFamily("宋体");         // 宋体
                    
                    // 设置段落格式
                    paragraph.setAlignment(ParagraphAlignment.CENTER);  // 居中对齐
                    paragraph.setSpacingBefore(240);   // 段前距离
                    paragraph.setSpacingAfter(240);    // 段后距离
                }
            }

            // 保存修改后的文档
            try (FileOutputStream out = new FileOutputStream(outputFile)) {
                doc.write(out);
            }
        }
    }
    
    /**
     * 在文档中创建头部样式
     */
    private static void createHeadingStylesIfNotExists(XWPFDocument doc) {
        XWPFStyles styles = doc.createStyles();
        if (styles == null) {
            styles = doc.createStyles();
        }
        
        // 检查Heading 1样式是否存在，如不存在则创建
        if (styles.getStyle("Heading1") == null) {
            // 创建新样式
            CTStyle ctStyle = CTStyle.Factory.newInstance();
            ctStyle.setStyleId("Heading1");
            
            // 设置样式名称
            CTString styleName = CTString.Factory.newInstance();
            styleName.setVal("heading 1");
            ctStyle.setName(styleName);
            
            // 设置样式类型为段落
            ctStyle.setType(STStyleType.PARAGRAPH);
            
            // 设置大纲级别
            ctStyle.addNewPPr().addNewOutlineLvl().setVal(BigInteger.ZERO);
            
            // 将样式添加到文档中
            XWPFStyle style = new XWPFStyle(ctStyle);
            styles.addStyle(style);
            
            // 设置标题样式的具体格式
            XWPFParagraph paragraph = doc.createParagraph();
            paragraph.setStyle("Heading1");
            XWPFRun run = paragraph.createRun();
            run.setBold(true);
            run.setFontSize(16);
            run.setFontFamily("宋体");
            paragraph.setAlignment(ParagraphAlignment.CENTER);
            paragraph.setSpacingBefore(240);
            paragraph.setSpacingAfter(240);
            
            // 删除用于设置样式的临时段落
            int pos = doc.getParagraphs().size() - 1;
            doc.removeBodyElement(pos);
        }
    }

    private static boolean isTitleLine(String text) {
        // 使用正则表达式匹配"第X章"格式
        return CHAPTER_PATTERN.matcher(text).matches();
    }
}
