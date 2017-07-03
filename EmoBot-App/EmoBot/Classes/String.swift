//
//  String.swift
//  EmoBot
//
//  Created by Lea Marolt on 6/17/17.
//  Copyright © 2017 elemes. All rights reserved.
//

import Foundation

extension String {
    var boolValue: Bool? {
        switch lowercased() {
        case "true", "yes", "1":
            return true
        case "false", "no", "0":
            return false
        default:
            return nil
        }
    }
}
