//
//  Item.swift
//  Habit
//
//  Created by Liam Byrne on 8/8/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
