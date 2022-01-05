//
//  SpeechRecognizer.swift
//  
//
//  Created by Jonathan Long on 12/20/21.
//

import Foundation
import Speech

public class SpeechRecognizer {
    
    //MARK: - Error
    public enum SpeechRecognizerError: Error {
        case unknown
    }
    
    //MARK: - State
    public enum State {
        case unknown
        case recognitionStateNotDetermined
        case recognitionAuthorizationDenied
        case recognitionIsRestricted
        case recognitionIsAuthorized
        case recognitionFailed(Error)
        case completed(TimedStrings)
    }
    
    //MARK: - Public
    
    public var state = State.unknown
    
    public var url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func generateTimedStrings() async -> TimedStrings? {
        queue.addOperation(requestAuthorizationOperation)
        queue.addOperation(recognitionTaskOperation)
        queue.waitUntilAllOperationsAreFinished()
        
        switch state {
            case .completed(let utterance):
                return utterance
            default:
                return nil
        }
    }
    
    //MARK: - Private
    
    private let speechRecognizer = SFSpeechRecognizer()
    
    private let queue = OperationQueue()
    
    //MARK: Operations
    
    private lazy var requestAuthorizationOperation: BlockOperation = BlockOperation { [weak self] in
        guard let self = self,
              SFSpeechRecognizer.authorizationStatus() == .notDetermined
        else { return }
        
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
                case .denied:
                    self.state = .recognitionAuthorizationDenied
                    
                case .restricted:
                    self.state = .recognitionIsRestricted
                    
                case .authorized:
                    self.state = .recognitionIsAuthorized
                    
                case .notDetermined:
                    self.state = .recognitionStateNotDetermined
                    
                @unknown default:
                    self.state = .unknown
            }
        }
    }
    
    private lazy var recognitionTaskOperation: BlockOperation = BlockOperation { [weak self] in
        guard let self = self else { return }
        let request = SFSpeechURLRecognitionRequest(url: self.url)
        let recognitionTaskOperationDispatchGroup = DispatchGroup()
        recognitionTaskOperationDispatchGroup.enter()
        self.speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            self.queue.addOperation(self.speechRecognitionRequestFinished(with: result, error: error))
            recognitionTaskOperationDispatchGroup.leave()
        }
        recognitionTaskOperationDispatchGroup.wait()
    }
    
    private func speechRecognitionRequestFinished(with result: SFSpeechRecognitionResult?, error: Error?) -> BlockOperation {
        BlockOperation { [weak self] in
            guard let self = self else { return }
            
            switch (error, result) {
                case (.some(let error), _ ):
                    self.state = .recognitionFailed(error)
                
                case (_, .some(let result)):
                    let formattedStrings = result
                        .transcriptions
                        .map {
                            $0.formattedString
                        }
                    let timedUtterance = TimedStrings(formattedString: formattedStrings, duration: result.speechRecognitionMetadata?.speechDuration ?? 0)
                    self.state = .completed(timedUtterance)
                
                default:
                    self.state = .recognitionFailed(SpeechRecognizerError.unknown)
            }
        }
    }
}

//MARK: - TimedUtterance
public struct TimedStrings {
    public let formattedString: [String]
    public let duration: TimeInterval
}
