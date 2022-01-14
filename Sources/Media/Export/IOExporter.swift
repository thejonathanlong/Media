//
//  IOExporter.swift
//  Created on 12/15/21.
//

import Foundation

class IOExporter {
    let pair: Exporter.InputOutputHolder
    let queue: DispatchQueue
    var finished = false
    
    init(pair: Exporter.InputOutputHolder, queue: DispatchQueue) {
        self.pair = pair
        self.queue = queue
    }
    
    func setupDataPipe(completion: @escaping () -> Void) async {
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
