//
//  UnblurApp.swift
//  Unblur
//
//  Created by Nathan Zhao on 6/4/2026.
//

import SwiftUI

@main
struct UnblurApp: App {
    var body: some Scene {
        WindowGroup {
            EpisodeListView()
                .tint(Color(red: 242/255, green: 140/255, blue: 56/255))
        }
    }
}
