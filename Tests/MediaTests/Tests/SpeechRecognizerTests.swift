//
//  SpeechRecognizerTests.swift
//  Created on 12/22/21.
//

import Foundation
import AVFoundation
import Foundation
@testable import Media
import XCTest

final class SpeechRecognizerTests: XCTestCase {
    
    func testInit() throws {
        let inputURL = try XCTUnwrap(TestMedia.testSpokenWordAudio)
        let speechRecognizer = SpeechRecognizer(url: inputURL)
        
        XCTAssertEqual(speechRecognizer.url, try TestMedia.testSpokenWordAudio)
        XCTAssertEqual(speechRecognizer.state, .unknown)
    }
    
    //TODO: Re-add this test when SFSpeechRecognizer can be used in a test.
    func testTextFromURL() async throws {
        let inputURL = try XCTUnwrap(TestMedia.testSpokenWordAudio)
        let speechRecognizer = SpeechRecognizer(url: inputURL)
        let inputAsset = AVAsset(url: inputURL)
        
        let timedStringOrNil = await speechRecognizer.generateTimedStrings()
        let timedString = try XCTUnwrap(timedStringOrNil)
        
        XCTAssertEqual(inputAsset.duration.seconds.rounded(), timedString.duration.rounded())
        XCTAssertEqual(timedString.formattedString.split(separator: " "), ["modern", "electro", "acoustics"])
        XCTAssertEqual(speechRecognizer.state, .completed(timedString))
        
    }
}

//MARK: - Extensions/Utilities
extension SpeechRecognizer.State: Equatable {
    public static func == (lhs: SpeechRecognizer.State, rhs: SpeechRecognizer.State) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        
        case (.recognitionStateNotDetermined, .recognitionStateNotDetermined):
            return true
            
        case (.recognitionAuthorizationDenied, .recognitionAuthorizationDenied):
            return true
            
        case (.recognitionIsRestricted, .recognitionIsRestricted):
            return true
            
        case (.recognitionIsAuthorized, .recognitionIsAuthorized):
            return true
            
        case (.recognitionFailed(_), .recognitionFailed(_)):
            return true
            
        case (.completed(_), .completed(_)):
            return true
        
        default:
            return false
        }
    }
    
    
}
