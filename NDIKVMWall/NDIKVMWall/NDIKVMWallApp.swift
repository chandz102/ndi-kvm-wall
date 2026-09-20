//
//  NDIKVMWallApp.swift
//  NDIKVMWall
//
//  Created by Anthony Chandler on 01/06/2026.
//

import SwiftUI

@main
struct NDIKVMWallApp: App {
    init() {
        guard NDIlib_initialize() else {
            fatalError("NDI initialization failed — unsupported CPU or missing library")
        }
        print("NDI initialized — version: \(String(cString: NDIlib_version()))")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
