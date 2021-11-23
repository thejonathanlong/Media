//
//  RecordingController.swift
//  
//
//  Created by Jonathan Long on 11/9/21.
//

import AVFoundation
import Combine
import Foundation

public class RecordingController: NSObject, ObservableObject {
    
    private let recordingSettings: [String: Any]
    
    private lazy var audioRecorder: AVAudioRecorder? = {
        guard let recordingURL = recordingURL else {
            statePublisher.send(completion: .failure(RecordingError.badURL))
            return nil
        }
        do {
            let recorder = try AVAudioRecorder(url: recordingURL, settings: recordingSettings)
            recorder.delegate = self
            requestMicrophoneAccessIfNeeded()
            return recorder
        } catch let e {
            statePublisher.send(completion: .failure(e))
            return nil
        }
    }()
    private var audioSession = AVAudioSession.sharedInstance()
    private var currentPair: TimePair = (TimeInterval.infinity, TimeInterval.infinity)
    
    public enum State {
        case notStarted, started, paused
    }
    
    public enum RecordingError: Error {
        case badURL
        case microphoneAccessDenied
        
        public static func ~= (lhs: Self, rhs: Error) -> Bool {
            guard let selfError = rhs as? Self else { return false }
            return selfError == lhs
        }
    }
    
    public var recordingURL: URL?
    public typealias TimePair = (start: TimeInterval, end: TimeInterval)
//    @Published public var isRecording = false
//    public var onError: ((Error) -> Void)?
//    public var onSuccess: ((Bool) -> Void)?
    public var timeIntervalPairs = [TimePair]()
    public var totalTime: TimeInterval {
        timeIntervalPairs.reduce(0) {
            $0 + ($1.1 - $1.0)
        }
    }
    
    public var statePublisher: CurrentValueSubject<State, Error> = CurrentValueSubject(.notStarted)
    
    
    public init(recordingURL: URL? = nil,
          settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]) {
        self.recordingURL = recordingURL
//        self.onSuccess = onSuccess
//        self.onError = onError
        self.recordingSettings = settings
    }
}

//MARK: - Public
public extension RecordingController {
    func startOrResumeRecording() {
        audioRecorder?.record()
        currentPair.start = audioRecorder?.currentTime ?? .infinity
        statePublisher.send(.started)
    }
    
    func pauseRecording() {
        updateCurrentEndTime()
        audioRecorder?.pause()
        statePublisher.send(.paused)
    }
    
    func finishRecording() {
        updateCurrentEndTime()
        audioRecorder?.stop()
        recordingURL = nil
    }
}

//MARK: - Private
private extension RecordingController {
    func updateCurrentEndTime() {
        currentPair.end = audioRecorder?.currentTime ?? .infinity
        timeIntervalPairs.append(currentPair)
        currentPair = (.infinity, .infinity)
    }
    
    func requestMicrophoneAccessIfNeeded() {
        switch audioSession.recordPermission {
            case .denied:
                statePublisher.send(completion: .failure(RecordingError.microphoneAccessDenied))
                
            case .undetermined:
                audioSession.requestRecordPermission { [weak self] _ in
                    self?.requestMicrophoneAccessIfNeeded()
                }
                
            case .granted:
                break
                
            @unknown default:
                break
        }
    }
}

//MARK: - AVAudioRecorderDelegate
extension RecordingController: AVAudioRecorderDelegate {
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        guard let error = error else {
            return
        }

        statePublisher.send(completion: .failure(error))
    }
    
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        statePublisher.send(completion: .finished)
    }
}
