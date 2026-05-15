//
//  BacklineLogger.swift
//  backline
//

import Foundation

/// Safe logging utility that only prints in DEBUG mode.
func blPrint(_ items: Any...) {
    #if DEBUG
    print(items.map { "\($0)" }.joined(separator: " "))
    #endif
}
