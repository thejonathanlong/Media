//
//  ExportProtocols.swift
//  
//
//  Created by Jonathan Long on 12/15/21.
//

import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

//MARK: - SampleProvider
protocol SampleProvider { }

protocol SampleBufferProvider: SampleProvider {
    func copyNextSampleBuffer() -> CMSampleBuffer?
}

protocol TimedMetadataSampleProvider: SampleProvider {
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup?
}

protocol PixelBufferProvider: SampleProvider {
    func copyNextPixelBuffer() -> TimedPixelBuffer?
}

//MARK: -
protocol SampleAdaptable { }

protocol TimedMetadataAdaptable: SampleAdaptable {
    func append(_ timedMetadataGroup: AVTimedMetadataGroup) -> Bool
}

protocol PixelBufferAdaptable: SampleAdaptable {
    func append(_ pixelBuffer: CVPixelBuffer, withPresentationTime: CMTime) -> Bool
}

//MARK: - TimedPixelBuffer
struct TimedPixelBuffer {
    let pixelBuffer: CVPixelBuffer
    let time: CMTime
}

//MARK: - SampleConsumer
protocol SampleConsumer {
    var isReadyForMoreMediaData: Bool { get }
    func append(_ sampleBuffer: CMSampleBuffer) -> Bool
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void)
    func markAsFinished()
}

extension SampleConsumer {
    
    func append(from provider: SampleProvider, with adapter: SampleAdaptable?) -> Bool {
        switch (provider, adapter) {
            case (let provider as SampleBufferProvider, _):
                guard let sampleBuffer = provider.copyNextSampleBuffer() else { return false }
                return append(sampleBuffer)
            
            case (let provider as TimedMetadataProvider, let adapter as TimedMetadataAdaptable):
                guard let timedMetadata = provider.copyNextTimedMetadataGroup() else { return false }
                return adapter.append(timedMetadata)
                
            case (let provider as PixelBufferProvider, let adapter as PixelBufferAdaptable):
                guard let timedPixelBuffer = provider.copyNextPixelBuffer() else { return false }
                return adapter.append(timedPixelBuffer.pixelBuffer, withPresentationTime: timedPixelBuffer.time)
                
            default:
                assertionFailure("This combination of provide and adapter was not handled. Provider: \(provider) adapter: \(String(describing: adapter))")
        }
        
        return false
    }
}
