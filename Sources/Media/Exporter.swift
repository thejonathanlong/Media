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
    
    /// Holds the state of the exporter.
    public lazy var statePublisher = CurrentValueSubject<State, Error>(state)
    
    //MARK: - Private
    private var state = State.unknown {
        didSet {
            switch state {
                case .finished:
                    statePublisher.send(completion: .finished)
                
                case .failed(let error):
                    statePublisher.send(completion: .failure(error))
                
                default:
                    statePublisher.send(state)
            }
        }
    }
    
    private var assetWriter: AVAssetWriter?
    
    private var assetReader: AVAssetReader?
    
    private let queue = DispatchQueue(label: "com.Media.ExporterQ")
    
    private let fileType: AVFileType
    
    
    //MARK: - init
    public init?(outputURL: URL,
                 fileType: AVFileType = .mov) {
        self.outputURL = outputURL
        self.fileType = fileType
    }
    
    func export(tracks: [AVAssetTrack], with timedMetadata: [AVTimedMetadataGroup], from asset: AVAsset) {
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
            
            let timedMetadataProvider = TimedMetadataProvider(timedMetadataGroups: timedMetadata)
            let metadataInput = AVAssetWriterInput(mediaType: <#T##AVMediaType#>, outputSettings: <#T##[String : Any]?#>)
            let timedMetadataInput = AVAssetWriterInputMetadataAdaptor(assetWriterInput: <#T##AVAssetWriterInput#>)
            let inputs = tracks.map { AVAssetWriterInput(mediaType: $0.mediaType, outputSettings: nil) }
            let outputs = tracks.map { AVAssetReaderTrackOutput(track: $0, outputSettings: nil) }
            let pairExporters = Array(zip(inputs, outputs)).map { PairExporter(pair: IOPair(output: $0.1, input: $0.0)) }
            
            inputs.forEach { assetWriter?.add($0 )}
            outputs.forEach { assetReader?.add($0) }
            
            let dispatchGroup = DispatchGroup()
            
            pairExporters.forEach {
                dispatchGroup.enter()
                $0.setupDataPipe {
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: queue) { [weak self] in
                guard let self = self,
                      let assetReader = self.assetReader,
                      let assetWriter = self.assetWriter
                else { return }
                
                if assetWriter.status != .failed && assetReader.status == .failed {
                    dispatchGroup.enter()
                    assetWriter.finishWriting {
                        switch assetWriter.status {
                            case .failed:
                                self.state = .failed(assetWriter.error ?? ExporterError.unknown)
                                
                            case .cancelled:
                                self.state = .cancelled
                                
                            case .completed:
                                self.state = .finished
                            
                            default:
                                break
                        }
                        
                        dispatchGroup.leave()
                    }
                    
                    dispatchGroup.wait()
                } else if let assetWriterError = assetWriter.error {
                    self.state = .failed(assetWriterError)
                } else if let assetReaderError = assetReader.error {
                    self.state = .failed(assetReaderError)
                }
            }
        } catch let e {
            state = .failed(e)
        }
    }
}

//MARK: - PairExporter
fileprivate class PairExporter {
    let pair: Exporter.IOPair
    let queue: DispatchQueue
    var finished = false
    
    fileprivate init(pair: Exporter.IOPair) {
        self.pair = pair
        self.queue = DispatchQueue(label: "com.Media.Exporter.PairExporterQueue-\(UUID())")
    }
    
    fileprivate func setupDataPipe(completion: @escaping () -> Void) {
        
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
                    return
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
