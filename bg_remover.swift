import Foundation
import Vision
import CoreImage
import AppKit

func processFile(inputURL: URL, outputURL: URL) {
    print("⏳ 正在处理: \(inputURL.lastPathComponent)...")
    
    guard let nsImage = NSImage(contentsOf: inputURL),
          let tiffData = nsImage.tiffRepresentation,
          let ciImage = CIImage(data: tiffData) else {
        print("❌ 无法加载图像: \(inputURL.path)")
        return
    }

    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
    let request = VNGenerateForegroundInstanceMaskRequest()

    do {
        try handler.perform([request])
        guard let result = request.results?.first else {
            print("⚠️ 无法生成掩码: \(inputURL.lastPathComponent)")
            return
        }

        // 直接使用 Vision 框架原生抠图 API，直接获取抠图后的像素缓冲区 (CVPixelBuffer)
        let maskedPixelBuffer = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )
        
        let outputCIImage = CIImage(cvPixelBuffer: maskedPixelBuffer)

        // 渲染为 PNG
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {
            print("❌ 无法创建 CGImage")
            return
        }

        let newNSImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        guard let pngData = newNSImage.pngRepresentation else {
            print("❌ 无法转换成 PNG 格式")
            return
        }

        try pngData.write(to: outputURL)
        print("✅ 处理成功! 已保存至: \(outputURL.path)")
    } catch {
        print("❌ 处理失败 \(inputURL.lastPathComponent): \(error.localizedDescription)")
    }
}

extension NSImage {
    var pngRepresentation: Data? {
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

func processDirectory(inputURL: URL, outputURL: URL) {
    do {
        let files = try FileManager.default.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        let imageFiles = files.filter { 
            let ext = $0.pathExtension.lowercased()
            return ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "webp"
        }
        
        if imageFiles.isEmpty {
            print("⚠️ 文件夹内未找到 PNG/JPG/WEBP 图片。")
            return
        }

        print("🔍 发现 \(imageFiles.count) 张图片，开始批量处理...")
        for file in imageFiles {
            let fileName = file.deletingPathExtension().lastPathComponent + "_transparent.png"
            let fileOutURL = outputURL.appendingPathComponent(fileName)
            processFile(inputURL: file, outputURL: fileOutURL)
        }
    } catch {
        print("❌ 读取文件夹错误: \(error)")
    }
}

// 命令行参数解析
let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("""
    ===================================================
    macOS 原生图片背景去除工具 (基于 Apple Vision 神经网络)
    ===================================================
    使用方法:
      swift bg_remover.swift <输入图片或文件夹路径> [输出目标路径]
    
    示例:
      # 处理单张图片 (会在同目录下生成 *_transparent.png)
      swift bg_remover.swift my_image.png
      
      # 批量处理文件夹中的所有图片 (会在同目录下生成 output_transparent 文件夹)
      swift bg_remover.swift ./my_images
      
      # 处理单张图片并指定输出路径
      swift bg_remover.swift my_image.png ./output_folder/done.png
    """)
    exit(0)
}

let inputPath = arguments[1]
let outputPath = arguments.count > 2 ? arguments[2] : nil

let inputURL = URL(fileURLWithPath: inputPath)
var isDir: ObjCBool = false
guard FileManager.default.fileExists(atPath: inputURL.path, isDirectory: &isDir) else {
    print("❌ 输入路径不存在: \(inputPath)")
    exit(1)
}

if isDir.boolValue {
    let outURL = outputPath != nil ? URL(fileURLWithPath: outputPath!) : inputURL.appendingPathComponent("output_transparent")
    try? FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true, attributes: nil)
    processDirectory(inputURL: inputURL, outputURL: outURL)
} else {
    let outURL: URL
    if let outPath = outputPath {
        let outPathURL = URL(fileURLWithPath: outPath)
        var outIsDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: outPathURL.path, isDirectory: &outIsDir) && outIsDir.boolValue {
            let fileName = inputURL.deletingPathExtension().lastPathComponent + "_transparent.png"
            outURL = outPathURL.appendingPathComponent(fileName)
        } else {
            outURL = outPathURL
        }
    } else {
        let fileName = inputURL.deletingPathExtension().lastPathComponent + "_transparent.png"
        outURL = inputURL.deletingLastPathComponent().appendingPathComponent(fileName)
    }
    processFile(inputURL: inputURL, outputURL: outURL)
}
