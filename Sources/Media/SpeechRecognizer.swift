//
//  SpeechRecognizer.swift
//  Created on 12/20/21.
//

import Foundation
import Speech

public class SpeechRecognizer {
    public init() { }
    
    public func generateTimeStrings(for url: URL) async -> TimedStrings? {
        let request = SFSpeechURLRecognitionRequest(url: url)
        let recognitionTaskOperationDispatchGroup = DispatchGroup()
        recognitionTaskOperationDispatchGroup.enter()
        var timedString: TimedStrings? = nil
        let task = speechRecognizer?.recognitionTask(with: request) { result, error in
            
            switch (error, result) {
                case (_, .some(let result)):
                    let formattedStrings = result.bestTranscription.formattedString
                    let timedUtterance = TimedStrings(formattedString: formattedStrings, duration: result.speechRecognitionMetadata?.speechDuration ?? 0)
                    if result.isFinal {
                        timedString = timedUtterance
                        recognitionTaskOperationDispatchGroup.leave()
                    }
                    
                default:
                    recognitionTaskOperationDispatchGroup.leave()
            }
        }
        recognitionTaskOperationDispatchGroup.wait()
        task?.finish()
        return timedString
    }
        
    //MARK: - Private
    private let speechRecognizer = SFSpeechRecognizer()
}

//MARK: - TimedUtterance
public struct TimedStrings {
    public let formattedString: String
    public let duration: TimeInterval
}
