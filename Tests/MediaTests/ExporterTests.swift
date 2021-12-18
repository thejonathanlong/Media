//
//  ExporterTests.swift
//  
//
//  Created by Jonathan Long on 12/11/21.
//

import AVFoundation
import Foundation
@testable import Media
import XCTest

final class ExporterTests: XCTestCase {
    
    static let exporterOutputDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ExporterTestsOutputDirectory")
    
    override func setUp() {
        guard !FileManager.default.fileExists(atPath: ExporterTests.exporterOutputDirectoryURL.path) else { return }
        do {
            try FileManager.default.createDirectory(at: ExporterTests.exporterOutputDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch let error {
            print("ExporterTests had an error trying to create the directory: \(error)")
        }
    }
    
    override func tearDown() {
        guard FileManager.default.fileExists(atPath: ExporterTests.exporterOutputDirectoryURL.path) else { return }
        do {
            try FileManager.default.removeItem(atPath: ExporterTests.exporterOutputDirectoryURL.path)
        } catch let error {
            print("ExporterTests had an error trying to delete the directory: \(error)")
        }
    }
    
    func testExporterInit() {
        let outputURL = ExporterTests.exporterOutputDirectoryURL.appendingPathComponent("ExporterInitTest").appendingPathExtension("mov")
        let exporter = Exporter(outputURL: outputURL)
        
        XCTAssertEqual(exporter.outputURL, outputURL)
    }
    
    func testExportAudio() async throws {
        let outputURL = ExporterTests.exporterOutputDirectoryURL.appendingPathComponent("testExportAudio-\(UUID())").appendingPathExtension("mov")
        let exporter = Exporter(outputURL: outputURL)
        
        XCTAssertEqual(exporter.outputURL, outputURL)
        let inputURL = try XCTUnwrap(Bundle.module.url(forResource: "testaudio", withExtension: "m4a"))
        let inputAsset = AVAsset(url: inputURL)
        
        await exporter.export(asset: inputAsset)
        
        let outputAsset = AVAsset(url: outputURL)
        XCTAssertEqual(outputAsset.tracks.count, 1)
        XCTAssertEqual(Int(outputAsset.duration.seconds), Int(inputAsset.duration.seconds))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(exporter.state, .finished)
    }
    
    func testExportTwoTracks() async throws {
        let outputURL = ExporterTests.exporterOutputDirectoryURL.appendingPathComponent("testExportTwoTracks-\(UUID())").appendingPathExtension("mov")
        let exporter = Exporter(outputURL: outputURL)
        
        XCTAssertEqual(exporter.outputURL, outputURL)
        let inputURL = try XCTUnwrap(Bundle.module.url(forResource: "testmovie", withExtension: "mov"))
        let inputAsset = AVAsset(url: inputURL)
        
        await exporter.export(asset: inputAsset)
        
        let outputAsset = AVAsset(url: outputURL)
        XCTAssertEqual(outputAsset.tracks.count, 2)
        XCTAssertEqual(Int(outputAsset.duration.seconds), Int(inputAsset.duration.seconds))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(exporter.state, .finished)
    }
    
    func testExportOneTrackWithTimedMetadata() async throws {
        let outputURL = ExporterTests.exporterOutputDirectoryURL.appendingPathComponent("testExportAudio-\(UUID())").appendingPathExtension("mov")
        let exporter = Exporter(outputURL: outputURL)
        
        XCTAssertEqual(exporter.outputURL, outputURL)
        let inputURL = try XCTUnwrap(Bundle.module.url(forResource: "testaudio", withExtension: "m4a"))
        let inputAsset = AVAsset(url: inputURL)
        
        let timedMetadata = try createTimedMetadata(startTime: .zero, duration: inputAsset.duration)
        
        await exporter.export(asset: inputAsset, timedMetadata: [timedMetadata])
        
        let outputAsset = AVAsset(url: outputURL)
        XCTAssertEqual(outputAsset.tracks.count, 2)
        XCTAssertEqual(Int(outputAsset.duration.seconds), Int(inputAsset.duration.seconds))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(exporter.state, .finished)
    }
    
    func testExportTwoTracksWithTimedMetadata() async throws {
        let outputURL = ExporterTests.exporterOutputDirectoryURL.appendingPathComponent("testExportTwoTracks-\(UUID())").appendingPathExtension("mov")
        let exporter = Exporter(outputURL: outputURL)
        
        XCTAssertEqual(exporter.outputURL, outputURL)
        let inputURL = try XCTUnwrap(Bundle.module.url(forResource: "testmovie", withExtension: "mov"))
        let inputAsset = AVAsset(url: inputURL)
        
        let timedMetadata1 = try createTimedMetadata(startTime: .zero, duration: CMTime(seconds: inputAsset.duration.seconds / 2.0, preferredTimescale: inputAsset.duration.timescale))
        let timedMetadata2 = try createTimedMetadata(startTime: CMTime(seconds: inputAsset.duration.seconds / 2.0, preferredTimescale: inputAsset.duration.timescale), duration: CMTime(seconds: inputAsset.duration.seconds / 2.0, preferredTimescale: inputAsset.duration.timescale))
        
        await exporter.export(asset: inputAsset, timedMetadata: [timedMetadata1, timedMetadata2])
        
        let outputAsset = AVAsset(url: outputURL)
        XCTAssertEqual(outputAsset.tracks.count, 3)
        XCTAssertEqual(Int(outputAsset.duration.seconds), Int(inputAsset.duration.seconds))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(exporter.state, .finished)
    }
    
    func testExportTwoTracksWithTimedMetadataAndImageVideoTrack() async throws {
        let outputURL = ExporterTests.exporterOutputDirectoryURL.appendingPathComponent("testExportTwoTracks-\(UUID())").appendingPathExtension("mov")
        let exporter = Exporter(outputURL: outputURL)
        
        XCTAssertEqual(exporter.outputURL, outputURL)
        let inputURL = try XCTUnwrap(Bundle.module.url(forResource: "testmovie", withExtension: "mov"))
        let inputAsset = AVAsset(url: inputURL)
        
        let timedMetadata1 = try createTimedMetadata(startTime: .zero, duration: CMTime(seconds: inputAsset.duration.seconds / 2.0, preferredTimescale: inputAsset.duration.timescale))
        let timedMetadata2 = try createTimedMetadata(startTime: CMTime(seconds: inputAsset.duration.seconds / 2.0, preferredTimescale: inputAsset.duration.timescale), duration: CMTime(seconds: inputAsset.duration.seconds / 2.0, preferredTimescale: inputAsset.duration.timescale))
        let imageURL = try XCTUnwrap(Bundle.module.url(forResource: "testImage", withExtension: "png"))
        let data = try XCTUnwrap(Data(contentsOf: imageURL))
        let images = [UIImage(data: data)!, UIImage(data: data)!]
        
        await exporter.export(asset: inputAsset, timedMetadata: [timedMetadata1, timedMetadata2], imageVideoTrack: (images, [timedMetadata1.timeRange, timedMetadata2.timeRange]))
        
        let outputAsset = AVAsset(url: outputURL)
        XCTAssertEqual(outputAsset.tracks.count, 3)
        XCTAssertEqual(Int(outputAsset.duration.seconds), Int(inputAsset.duration.seconds))
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(exporter.state, .finished)
    }
    
    private func createTimedMetadata(startTime: CMTime = .zero, duration: CMTime) throws -> AVTimedMetadataGroup {
        let metadataItem = AVMutableMetadataItem()
        metadataItem.identifier = AVMetadataItem.identifier(forKey: "com.mediatests.Image", keySpace: .quickTimeMetadata)
        let imageURL = try XCTUnwrap(Bundle.module.url(forResource: "testImage", withExtension: "png"))
        metadataItem.value = try Data(contentsOf: imageURL) as NSData
        metadataItem.dataType = kCMMetadataBaseDataType_PNG as String
        
        return AVTimedMetadataGroup(items: [metadataItem], timeRange: CMTimeRange(start: startTime, duration: duration))
    }
    
}

extension Exporter.State: Equatable {
    public static func == (lhs: Exporter.State, rhs: Exporter.State) -> Bool {
        switch (lhs, rhs) {
        case (Exporter.State.unknown, Exporter.State.unknown):
            return true
        case (Exporter.State.exporting, Exporter.State.exporting):
            return true
        case (Exporter.State.cancelled, Exporter.State.cancelled):
            return true
        case (Exporter.State.finished, Exporter.State.finished):
            return true
        case (Exporter.State.failed(_), Exporter.State.failed(_)):
            return true
        
        default:
            return false
        }
    }
}
