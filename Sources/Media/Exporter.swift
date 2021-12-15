//
//  Exporter.swift
//  
//
//  Created by Jonathan Long on 12/8/21.
//

import AVFoundation
import Combine
import Foundation

protocol SampleProvider {
    func copyNextSampleBuffer() -> CMSampleBuffer?
}

protocol SampleConsumer {
    var isReadyForMoreMediaData: Bool { get }
    func append(_ sampleBuffer: CMSampleBuffer) -> Bool
    func requestMediaDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void)
    func markAsFinished()
}

extension AVAssetReaderTrackOutput: SampleProvider {}

extension AVAssetWriterInput: SampleConsumer { }

public class Exporter {
    
    //MARK: - State
    public enum State {
        case unknown, exporting, cancelled, finished, failed(Error)
    }
    
    public enum ExporterError: Error {
        case unknown
    }
    
    internal struct IOPair {
        var output: SampleProvider
        var input: SampleConsumer
    }
    
    //MARK: - Public
    /// The outputURL for the exported movie
    public let outputURL: URL
    
    //MARK: - Private
    public var state = State.unknown
    
    private var assetWriter: AVAssetWriter?
    
    private var assetReader: AVAssetReader?
    
    private let queue = DispatchQueue(label: "com.Media.ExporterQ")
    
    let dispatchGroup = DispatchGroup()
    
    private let fileType: AVFileType
    
    //MARK: - init
    public init(outputURL: URL,
                 fileType: AVFileType = .mov) {
        self.outputURL = outputURL
        self.fileType = fileType
    }
    
    func export(tracks: [AVAssetTrack], with timedMetadata: [AVTimedMetadataGroup], from asset: AVAsset) async {
        do {
            
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: fileType)
            assetReader = try AVAssetReader(asset: asset)
            
            /*
             // Setup metadata track in order to write metadata samples
                         CMFormatDescriptionRef metadataFormatDescription = NULL;
                         NSArray *specs = @[
                                            @{(__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier : AAPLTimedAnnotationWriterCircleCenterCoordinateIdentifier,
                                              (__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType : (__bridge NSString *)kCMMetadataBaseDataType_PointF32},
                                            @{(__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier : AAPLTimedAnnotationWriterCircleRadiusIdentifier,
                                              (__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType : (__bridge NSString *)kCMMetadataBaseDataType_Float64},
                                            @{(__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier : AAPLTimedAnnotationWriterCommentFieldIdentifier,
                                              (__bridge NSString *)kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType : (__bridge NSString *)kCMMetadataBaseDataType_UTF8}];
                         
                         
                         OSStatus err = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, (__bridge CFArrayRef)specs, &metadataFormatDescription);
                         if (!err)
                         {
                             AVAssetWriterInput *assetWriterMetadataIn = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeMetadata outputSettings:nil sourceFormatHint:metadataFormatDescription];
                             AVAssetWriterInputMetadataAdaptor *assetWriterMetadataAdaptor = [AVAssetWriterInputMetadataAdaptor assetWriterInputMetadataAdaptorWithAssetWriterInput:assetWriterMetadataIn];
                             assetWriterMetadataIn.expectsMediaDataInRealTime = YES;
             */
            
//            let timedMetadataProvider = TimedMetadataProvider(timedMetadataGroups: timedMetadata)
//            let metadataInput = AVAssetWriterInput(mediaType: <#T##AVMediaType#>, outputSettings: <#T##[String : Any]?#>)
//            let timedMetadataInput = AVAssetWriterInputMetadataAdaptor(assetWriterInput: <#T##AVAssetWriterInput#>)
            let inputs = tracks.map { AVAssetWriterInput(mediaType: $0.mediaType, outputSettings: nil) }
            let outputs = tracks.map { AVAssetReaderTrackOutput(track: $0, outputSettings: nil) }
            let pairExporters = Array(zip(inputs, outputs)).map { PairExporter(pair: IOPair(output: $0.1, input: $0.0), queue: queue) }
            
            inputs.forEach { assetWriter?.add($0 )}
            outputs.forEach { assetReader?.add($0) }
            
            assetReader?.startReading()
            assetWriter?.startWriting()
            self.assetWriter?.startSession(atSourceTime: .zero)
            
            self.state = .exporting
            for pairExporter in pairExporters {
                dispatchGroup.enter()
                await pairExporter.setupDataPipe { [weak self] in
                    self?.dispatchGroup.leave()
                }
            }
            
            dispatchGroup.wait()
            
            try await finishWriting()
            
        } catch let e {
            state = .failed(e)
        }
    }
    
    private func finishWriting() async throws {
        if assetWriter?.status != .failed && assetReader?.status != .failed {
            await assetWriter?.finishWriting()
            switch assetWriter?.status {
            case .failed:
                throw assetWriter?.error ?? ExporterError.unknown
                
            case .cancelled:
                self.state = .cancelled
                
            case .completed:
                self.state = .finished
                
            default:
                break
            }
        } else if let assetWriterError = assetWriter?.error {
            throw assetWriterError
        } else if let assetReaderError = assetReader?.error {
            throw assetReaderError
        }
    }
}

//MARK: - PairExporter
fileprivate class PairExporter {
    let pair: Exporter.IOPair
    let queue: DispatchQueue
    var finished = false
    
    fileprivate init(pair: Exporter.IOPair, queue: DispatchQueue) {
        self.pair = pair
        self.queue = queue
    }
    
    fileprivate func setupDataPipe(completion: @escaping () -> Void) async {
        let input = pair.input
        let output = pair.output
        
        input.requestMediaDataWhenReady(on: self.queue) { [weak self] in
            guard let self = self,
                  !self.finished else {
                      return
                  }
            
            while input.isReadyForMoreMediaData && !self.finished {
                guard let sampleBuffer = output.copyNextSampleBuffer() else {
                    self.finished = true
                    break
                }
                let success = input.append(sampleBuffer)
                self.finished = !success
            }
            
            if self.finished {
                input.markAsFinished()
                completion()
            }
        }
    }
}

//MARK: - TimedMetadataProvider
class TimedMetadataProvider {
    let timedMetadataGroups: [AVTimedMetadataGroup]
    lazy var iterator = timedMetadataGroups.makeIterator()
    
    init(timedMetadataGroups: [AVTimedMetadataGroup]) {
        self.timedMetadataGroups = timedMetadataGroups
    }
    
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup? {
        iterator.next()
    }
}
