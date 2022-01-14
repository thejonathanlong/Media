//
//  TimedMetadataReaderTests.swift
//  Created on 12/15/21.
//

import AVFoundation
import Foundation
@testable import Media
import XCTest

final class TimedMetadataReaderTests: XCTestCase {
    
    func testReadTimedMetadataGroups() async throws {
        let inputURL = try TestMedia.testMovieWithImageMetadata
        let inputAsset = AVAsset(url: inputURL)
        let reader = TimedMetadataReader(asset: inputAsset)
        let groups = await reader.readTimedMetadata()
        
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 1)
        
        let firstItem = try XCTUnwrap(groups[0][0].items.first)
        
        let identifier = try XCTUnwrap(firstItem.identifier)
        XCTAssertEqual(identifier.rawValue, "mdta/com.mediatests.Image")
        XCTAssertEqual(firstItem.dataType, kCMMetadataBaseDataType_PNG as String)
        let imageURL = try XCTUnwrap(Bundle.module.url(forResource: "testImage", withExtension: "png"))
        let data = try Data(contentsOf: imageURL)
        let itemData = try XCTUnwrap(firstItem.dataValue)
        XCTAssertEqual(data, itemData)
    }
    
    func testReadTimedMetadataGroupsWithStrings() async throws {
        let inputURL = try TestMedia.testMovieWithStringMetadata
        let inputAsset = AVAsset(url: inputURL)
        let reader = TimedMetadataReader(asset: inputAsset)
        let groups = await reader.readTimedMetadata()
        
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].count, 2)
        
        let firstItem = try XCTUnwrap(groups[0][0].items.first)
        
        let identifier = try XCTUnwrap(firstItem.identifier)
        XCTAssertEqual(identifier.rawValue, "mdta/com.mediatests.Strings")
        XCTAssertEqual(firstItem.dataType, kCMMetadataBaseDataType_UTF8 as String)
        let itemStringValue = try XCTUnwrap(firstItem.stringValue)
        XCTAssertEqual("Hello World", itemStringValue)
    }
}
