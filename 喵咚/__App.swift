//
//  __App.swift
//  喵咚
//
//  Created by Justin Xing on 2026/5/16.
//

import SwiftUI

@main
struct MiaodongApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
