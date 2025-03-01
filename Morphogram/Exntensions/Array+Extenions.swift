//
//  Array+Extenions.swift
//  Morphogram
//
//  Created by Osman Tufekci on 1.03.2025.
//

import Foundation

extension Array {
    mutating func safeInsert(_ element: Element, at index: Int) {
        if index <= self.count {
            self.insert(element, at: index) // Mevcut eleman sayısına eşitse de doğru çalışır
        } else {
            self.append(element) // Geçersiz bir indeksse sona ekler
        }
    }
}
