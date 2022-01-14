//
//  VideoBufferProvider.swift
//  Created on 12/18/21.
//

import CoreMedia
import CoreVideo
import Foundation
import UIKit

class VideoBufferProvider: PixelBufferProvider {
    let images: [UIImage]
    
    let imageTimeRanges: [CMTimeRange]
    
    lazy var imageIterator = images.makeIterator()
    lazy var timeRangeIterator = imageTimeRanges.makeIterator()
    
    var firstPixelBuffer: CVPixelBuffer? {
        images.first?.pixelBuffer
    }
    
    init(imaes: [UIImage], timeRanges: [CMTimeRange]) {
        self.images = imaes
        self.imageTimeRanges = timeRanges
    }
    
    func copyNextPixelBuffer() -> TimedPixelBuffer? {
        guard let nextImage = imageIterator.next(),
              let nextTimeRange = timeRangeIterator.next(),
              let nextPixelBuffer = nextImage.pixelBuffer
        else { return nil }
        
        return TimedPixelBuffer(pixelBuffer: nextPixelBuffer, time: nextTimeRange.start)
    }
}

extension UIImage {
    var pixelBuffer: CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
          var pixelBuffer : CVPixelBuffer?
          let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
          guard (status == kCVReturnSuccess) else {
            return nil
          }

          CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
          let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

          let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
          let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

          context?.translateBy(x: 0, y: size.height)
          context?.scaleBy(x: 1.0, y: -1.0)

          UIGraphicsPushContext(context!)
          draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
          UIGraphicsPopContext()
          CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

          return pixelBuffer
    }
}
