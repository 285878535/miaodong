//
//  UpdateChecker.swift
//  喵咚
//
//  从 GitHub Releases API 检查最新版本，比较版本号后决定是否提示更新。
//

import Foundation
import AppKit

// MARK: - 版本检查结果

enum UpdateCheckResult {
    case upToDate
    case newVersion(tag: String, notes: String?)
    case error(String)
}

// MARK: - UpdateChecker

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let apiURL = URL(string: "https://api.github.com/repos/285878535/miaodong/releases/latest")!
    private let releasesPageURL = URL(string: "https://github.com/285878535/miaodong/releases")!

    /// 每次 check 的最新结果，供 UI 订阅
    private(set) var lastResult: UpdateCheckResult?

    // MARK: - 主检查方法

    func check() async -> UpdateCheckResult {
        var request = URLRequest(url: apiURL, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // GitHub 返回 404 时表示没有任何 release
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                let result = UpdateCheckResult.upToDate
                lastResult = result
                return result
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestTag = release.tagName                            // e.g. "v1.2.0"
            let latestVer = latestTag.drop(while: { !$0.isNumber })   // "1.2.0"
            let currentVer = Bundle.main.shortVersion                 // e.g. "1.0.0"

            let result: UpdateCheckResult
            if isNewer(String(latestVer), than: currentVer) {
                result = .newVersion(tag: latestTag, notes: release.body)
            } else {
                result = .upToDate
            }
            lastResult = result
            return result

        } catch {
            let result = UpdateCheckResult.error(error.localizedDescription)
            lastResult = result
            return result
        }
    }

    // MARK: - 打开 Release 页

    func openReleasesPage() {
        NSWorkspace.shared.open(releasesPageURL)
    }

    // MARK: - 版本比较（语义化版本，逐段比较）

    private func isNewer(_ latest: String, than current: String) -> Bool {
        let parse: (String) -> [Int] = {
            $0.split(separator: ".").compactMap { Int($0) }
        }
        let lv = parse(latest)
        let cv = parse(current)
        for i in 0..<max(lv.count, cv.count) {
            let l = i < lv.count ? lv[i] : 0
            let c = i < cv.count ? cv[i] : 0
            if l > c { return true }
            if l < c { return false }
        }
        return false
    }

    // MARK: - 自动检查 + 系统 Alert（AppDelegate 调用）

    func checkAndAlertIfNeeded() {
        Task {
            let result = await check()
            if case .newVersion(let tag, _) = result {
                showUpdateAlert(tag: tag)
            }
        }
    }

    private func showUpdateAlert(tag: String) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(tag) 🎉"
        alert.informativeText = "喵咚 \(tag) 已发布，是否前往下载最新版本？"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后再说")

        // 优先附加到已有窗口（非阻塞 sheet），无窗口时降级为普通 Alert
        if let window = NSApp.windows.first(where: { $0.isVisible && !$0.isMiniaturized }) {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.openReleasesPage()
                }
            }
        } else {
            // 后台 task 调用，避免在主运行循环初始化期间 runModal
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self else { return }
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.openReleasesPage()
                }
            }
        }
    }
}

// MARK: - GitHub API 数据模型

private struct GitHubRelease: Decodable {
    let tagName: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
    }
}

// MARK: - Bundle 便捷属性

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}
