//
//  TimedMetadataReader.swift
//  
//
//  Created by Jonathan Long on 12/15/21.
//

import AVFoundation
import Foundation

class TimedMetadataReader {

    let assetReader: AVAssetReader?
    
    init(asset: AVAsset) {
        assetReader = try? AVAssetReader(asset: asset)
    }
    
    /// Reads the timed metadata from an asset up front.
    /// - returns: An array of arrays of timedMetadata. Each array corresponds to each track of timedMetadata.
    func readTimedMetadata() async -> [[AVTimedMetadataGroup]] {
        guard let timedMetadataTracks = assetReader?.asset.tracks(withMediaType: .metadata) else { return [] }
        
        let trackOutputs = timedMetadataTracks.map { AVAssetReaderTrackOutput(track: $0, outputSettings: nil) }
        let adapters = trackOutputs.map { AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: $0) }
        trackOutputs.forEach { assetReader?.add($0) }
        
        assetReader?.startReading()
        
        var timedMetadataGroups: [[AVTimedMetadataGroup]] = []
        
        adapters.forEach {
            var next = [AVTimedMetadataGroup]()
            while let timedMetadataGroup = $0.nextTimedMetadataGroup() {
                next.append(timedMetadataGroup)
            }
            timedMetadataGroups.append(next)
        }
        
        return timedMetadataGroups
    }
}
