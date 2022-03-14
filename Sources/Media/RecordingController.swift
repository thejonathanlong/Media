//
//  RecordingController.swift
//  Created on 11/9/21.
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
            try audioSession.setCategory(.playAndRecord, mode: .default)
                try audioSession.setActive(true)
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
    
    private var currentTimeObserver: NSKeyValueObservation?
    
    private var timerCancellable: AnyCancellable?
    
    public enum State {
        case notStarted, paused, notAuthorized
        case started(TimeInterval)
        case timeUpdated(TimeInterval)
    }
    
    public enum RecordingError: Error {
        case badURL
        case microphoneAccessDenied
        case startRecordingFailed
        
        public static func ~= (lhs: Self, rhs: Error) -> Bool {
            guard let selfError = rhs as? Self else { return false }
            return selfError == lhs
        }
    }
    
    public var recordingURL: URL?
    public typealias TimePair = (start: TimeInterval, end: TimeInterval)
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
            AVSampleRateKey: 16000,
            AVEncoderBitRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]) {
            self.recordingURL = recordingURL
            self.recordingSettings = settings
        }
}

//MARK: - Public
public extension RecordingController {
    func startOrResumeRecording() {
        
        
        if let isRecording = audioRecorder?.record(),
            isRecording {
            currentPair.start = audioRecorder?.currentTime ?? .infinity
            statePublisher.send(.started(audioRecorder?.currentTime ?? 0.0))
            
            if timerCancellable == nil {
                timerCancellable = Timer.publish(every: 0.3, tolerance: nil, on: .current, in: .default)
                    .autoconnect()
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] _ in
                        guard let self = self,
                              let audioRecorder = self.audioRecorder
                        else { return }
                        self.statePublisher.send(.timeUpdated(audioRecorder.currentTime))
                    }
            }
        } else {
            statePublisher.send(completion: .failure(RecordingError.startRecordingFailed))
        }
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
        timerCancellable?.cancel()
        // The delegate isn't called sometimes. Not 100% sure why.
        statePublisher.send(completion: .finished)
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
                statePublisher.send(.notAuthorized)
                
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
