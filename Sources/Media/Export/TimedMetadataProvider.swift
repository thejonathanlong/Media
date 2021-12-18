//
//  TimedMetadataProvider.swift
//  
//
//  Created by Jonathan Long on 12/15/21.
//

import AVFoundation
import Foundation

class TimedMetadataProvider: TimedMetadataSampleProvider {
    let timedMetadataGroups: [AVTimedMetadataGroup]
    
    lazy var iterator = timedMetadataGroups.makeIterator()
    
    var outputSettings = [String: Any]()
    
    init(timedMetadataGroups: [AVTimedMetadataGroup]) {
        self.timedMetadataGroups = timedMetadataGroups
    }
    
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup? {
        iterator.next()
    }
}
