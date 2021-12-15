//
//  TimedMetadataProvider.swift
//  
//
//  Created by Jonathan Long on 12/15/21.
//

import AVFoundation
import Foundation

class TimedMetadataProvider: SampleProvider {
    let timedMetadataGroups: [AVTimedMetadataGroup]
    
    lazy var iterator = timedMetadataGroups.makeIterator()
    
    var outputSettings = [String: Any]()
    
    var expectsTimedMetadata: Bool {
        true
    }
    
    init(timedMetadataGroups: [AVTimedMetadataGroup]) {
        self.timedMetadataGroups = timedMetadataGroups
    }
    
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup? {
        iterator.next()
    }
    
    func copyNextSampleBuffer() -> CMSampleBuffer? {
        nil
    }
}
