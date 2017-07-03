//
//  BotFace.swift
//  EmoBot
//
//  Created by Lea Marolt on 6/24/17.
//  Copyright © 2017 elemes. All rights reserved.
//

import Foundation
import Affdex

public enum botFace: Int {
    case simple
    case big
    case small
    case evil
    case duh
    case superDuh
    case quirky
    case sad
    case depressed
    case confused
    case superCute
    case smallSurprise
    case bigSurprise
    case nonChalant
    case cool
    case tongue
    case angry
    
    func description() -> String {
        switch self {
        case .simple:
            return "simple" // smile = 70, joy = 80
        case .big:
            return "big" // smile = 70, mouthOpen = 90, joy = 80
        case .small:
            return "small" // smile = 70
        case .evil:
            return "evil" // cheekRaise = 40, smile = 90, attention = 90, engagement = 90
        case .duh:
            return "duh"
        case .superDuh:
            return "superDuh"
        case .quirky:
            return "quirky"
        case .sad:
            return "sad" // sadness = 70, valence = -10 or less
        case .depressed:
            return "depressed"
        case .confused:
            return "confused"
        case .superCute:
            return "superCute" // eyesClosed = 90, joy = 90
        case .smallSurprise:
            return "smallSurprise"
        case .bigSurprise:
            return "bigSurprise"
        case .nonChalant:
            return "nonChalant"
        case .cool:
            return "cool"
        case .tongue:
            return "tongue" // tongue stuck out emoji = 90
        case .angry:
            return "angry" // angry = 90
        }
    }
    
    func matchingFace(face: AFDXFace) -> Bool {
        guard let emotions = face.emotions,
            let emojis = face.emojis,
            let expressions = face.expressions,
            let appearance = face.appearance else { return false }
        
//        print("EMOJIS")
//        print(emojis)
//        
//        print("EMOTIONS")
//        print(emotions)
//        
//        print("EXPRESSIONS")
//        print(expressions)
//        
//        print("APPEARANCE")
//        print(appearance)
//        
        switch self {
        case .simple:
            return emotions.joy > 80 && expressions.smile > 70
        case .small:
            return expressions.smile > 70
        case .big:
            return emotions.joy > 80 && emotions.contempt > 0 && expressions.mouthOpen > 90
        case .evil:
            return expressions.browFurrow > 60 && emotions.engagement > 80 && expressions.lipSuck > 50
        case .sad, .depressed: // the same for now
            return emotions.sadness > 60 && emotions.valence < -5
        case .superCute:
            return emotions.joy > 90 && expressions.eyeClosure > 90
        case .tongue:
            return emojis.stuckOutTongue > 40
        case .angry:
            return emotions.anger > 90
        case .bigSurprise, .smallSurprise:
            return emotions.surprise > 80
        case .superDuh:
            return emotions.contempt > 90
        case .quirky:
            return expressions.lipPress > 50 && emotions.joy > 80
        case .confused: // need to map out still!!
            return expressions.eyeWiden > 40 && expressions.mouthOpen > 50
        case .nonChalant:
            return appearance.glasses.rawValue == 1
        case .duh:
            return emojis.smirk > 25
        case .cool:
            return appearance.glasses.rawValue == 1 && expressions.smile > 50
        }
    }
}
