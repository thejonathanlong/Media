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
    var expectsTimedMetadata: Bool { get }
    func copyNextSampleBuffer() -> CMSampleBuffer?
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup?
}

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

extension SampleProvider {
    var expectsTimedMetadata: Bool {
        false
    }
}

extension AVAssetReaderTrackOutput: SampleProvider {
    func copyNextTimedMetadataGroup() -> AVTimedMetadataGroup? {
        nil
    }
}

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
        var adapter: AVAssetWriterInputMetadataAdaptor?
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
            
            let inputs = tracks.map { AVAssetWriterInput(mediaType: $0.mediaType, outputSettings: nil) }
            let outputs = tracks.map { AVAssetReaderTrackOutput(track: $0, outputSettings: nil) }
            
            var pairExporters = Array(zip(inputs, outputs)).map { PairExporter(pair: IOPair(output: $0.1, input: $0.0), queue: queue) }
            
            inputs.forEach { assetWriter?.add($0 )}
            outputs.forEach { assetReader?.add($0) }
            
            if !timedMetadata.isEmpty {
                let metadataInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: try formatDescription(for: timedMetadata))
                let timedMetadataAdapter = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)
                let timedMetadataProvider = TimedMetadataProvider(timedMetadataGroups: timedMetadata)
                
                pairExporters.append(PairExporter(pair: IOPair(output: timedMetadataProvider, input: metadataInput, adapter: timedMetadataAdapter), queue: queue))
                assetWriter?.add(metadataInput)
            }
            
            
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
    
    private func formatDescription(for timedMetadata: [AVTimedMetadataGroup]) throws -> CMFormatDescription {
        let arrayOfSpecs = timedMetadata
            .map { $0.items }
            .flatMap { $0 }
            .compactMap { item -> [String: AnyObject]? in
                guard let identifier = item.identifier,
                      let dataType = item.dataType else {
                          return nil
                      }
                return [
                    kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String : identifier.rawValue as String,
                    kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String : dataType
                ] as [String: AnyObject]
            }
        
        return try CMFormatDescription(boxedMetadataSpecifications: arrayOfSpecs)
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
        let adapter = pair.adapter
        
        input.requestMediaDataWhenReady(on: self.queue) { [weak self] in
            guard let self = self,
                  !self.finished else {
                      return
                  }
            
            while input.isReadyForMoreMediaData && !self.finished {
                if !input.append(from: output, with: adapter) {
                    self.finished = true
                    break
                }
            }
            
            if self.finished {
                input.markAsFinished()
                completion()
            }
        }
    }
}

//MARK: - TimedMetadataProvider
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
