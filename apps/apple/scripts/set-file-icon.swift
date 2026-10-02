// 把圖示貼到檔案上（讓 .dmg 在 Finder 裡顯示 App 圖示）
// 用法：swift scripts/set-file-icon.swift <圖示.icns> <檔案>
import AppKit

let args = CommandLine.arguments
guard args.count == 3, let image = NSImage(contentsOfFile: args[1]) else { print("用法：set-file-icon <icns> <file>"); exit(1) }
print(NSWorkspace.shared.setIcon(image, forFile: args[2]) ? "icon set" : "icon failed")
