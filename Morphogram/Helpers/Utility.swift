//
//  Utility.swift
//  Morphogram
//
//  Created by Osman Tufekci on 12.02.2025.
//

import Foundation

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter.string(from: date)
}
