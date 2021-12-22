//
//  AVFoundationExtensions.swift
//  
//
//  Created by Jonathan Long on 12/22/21.
//

import Foundation
import AVFoundation

//MARK: - AVAssetReaderTrackOutput Extension
extension AVAssetReaderTrackOutput: SampleBufferProvider { }

//MARK: - AVAssetWriterInput Extension
extension AVAssetWriterInput: SampleConsumer { }

//MARK: - AVAssetWriterInputMetadataAdaptor Extension
extension AVAssetWriterInputMetadataAdaptor: TimedMetadataAdaptable { }

//MARK: - AVAssetWriterInputPixelBufferAdaptor Extension
extension AVAssetWriterInputPixelBufferAdaptor: PixelBufferAdaptable { }

//MARK: - Public AVTimedMetadtataGroup Extension
public extension AVTimedMetadataGroup {
    static func timedMetadataGroup(with imageURL: URL, timeRange: CMTimeRange, identifier: String) -> AVTimedMetadataGroup? {
        do {
            let metadataItem = AVMutableMetadataItem()
            metadataItem.identifier = AVMetadataItem.identifier(forKey: identifier, keySpace: .quickTimeMetadata)
            metadataItem.value = try Data(contentsOf: imageURL) as NSData
            metadataItem.dataType = kCMMetadataBaseDataType_PNG as String
            
            return AVTimedMetadataGroup(items: [metadataItem], timeRange: timeRange)
            
        } catch {
            return nil
        }
    }
    
    static func timedMetadataGroup(with strings: [String], timeRange: CMTimeRange, identifier: String) -> AVTimedMetadataGroup {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.identifier = AVMetadataItem.identifier(forKey: identifier, keySpace: .quickTimeMetadata)
        metadataItem.value = strings.joined(separator: " ") as NSString
        metadataItem.dataType = kCMMetadataBaseDataType_UTF8 as String
        
        return AVTimedMetadataGroup(items: [metadataItem], timeRange: timeRange)
        
    }
}

//MARK: - CMFormatDescription
extension CMFormatDescription {
    internal static func formatDescription(for timedMetadata: [AVTimedMetadataGroup]) throws -> CMFormatDescription {
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
