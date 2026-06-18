//
//  NSScreen+Notch.swift
//  喵咚
//
//  NSScreen 扩展 —— 移植自 openIsland。
//

import AppKit

extension NSScreen {
    var notchMetrics: ScreenNotchMetrics {
        ScreenNotchMetrics.detect(
            screenFrame: frame,
            safeAreaTop: safeAreaInsets.top,
            auxiliaryTopLeftWidth: auxiliaryTopLeftArea?.width,
            auxiliaryTopRightWidth: auxiliaryTopRightArea?.width
        )
    }

    var notchSize: CGSize { notchMetrics.size }

    var isBuiltinDisplay: Bool {
        guard let screenNumber = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(screenNumber) != 0
    }

    /// 优先返回带刘海的内置屏；否则返回 main
    static var notchPreferred: NSScreen? {
        if let withNotch = screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return withNotch
        }
        if let builtin = screens.first(where: { $0.isBuiltinDisplay }) {
            return builtin
        }
        return NSScreen.main
    }

    var hasPhysicalNotch: Bool { notchMetrics.hasPhysicalNotch }
}
