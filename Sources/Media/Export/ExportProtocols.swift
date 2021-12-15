//
//  ExportProtocols.swift
//  
//
//  Created by Jonathan Long on 12/15/21.
//

import AVFoundation
import CoreMedia
import Foundation

//MARK: - SampleProvider
protocol SampleProvider {
    var expectsTimedMetadata: Bool { get }
    func copyNextSampleBuffer() -> CMSampleBuffer?
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup?
}

extension SampleProvider {
    var expectsTimedMetadata: Bool {
        false
    }
}

//MARK: - SampleConsumer
protocol SampleConsumer {
    var isReadyForMoreMediaData: Bool { get }
    func append(_ sampleBuffer: CMSampleBuffer) -> Bool
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void)
    func markAsFinished()
}

extension SampleConsumer {
    func append(from output: SampleProvider, with adapter: AVAssetWriterInputMetadataAdaptor?) -> Bool {
        if adapter != nil && output.expectsTimedMetadata {
            guard let timedMetadata = output.copyNextTimedMetadataGroup() else { return false }
            return adapter?.append(timedMetadata) ?? false
        } else {
            guard let sampleBuffer = output.copyNextSampleBuffer() else { return false }
            return append(sampleBuffer)
        }
    }
}

//MARK: AVFoundation Extensions
extension AVAssetReaderTrackOutput: SampleProvider {
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup? {
        nil
    }
}

extension AVAssetWriterInput: SampleConsumer { }
