//  FilteredVideoVendor.swift
//  VideoEffects
//
//  Created by Simon Gladman on 17/04/2016.
//  Copyright © 2016 Simon Gladman. All rights reserved.
//

import UIKit
import MobileCoreServices
import AVFoundation

class FilteredVideoVendor: NSObject {
  
  static let pixelBufferAttributes: [String:AnyObject] = [
    String(kCVPixelBufferPixelFormatTypeKey): NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
  
  let ciContext = CIContext()
  
  var videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: FilteredVideoVendor.pixelBufferAttributes)
  var player: AVPlayer?
  var videoTransform: CGAffineTransform?
  var unfilteredImage: CIImage?
  var currentURL: URL?
  var failedPixelBufferForItemTimeCount = 0
  
  let opencvWrapper = OpenCVWrapper()
    
  weak var delegate: FilteredVideoVendorDelegate?
  
  var ciFilter: CIFilter? {
    didSet {
      displayFilteredImage()
    }
  }
  
  var paused = true {
    didSet {
      displayLink.isPaused = paused

      if displayLink.isPaused {
        player?.pause()
      }
      else {
        player?.play()
      }
    }
  }
  
  lazy var displayLink: CADisplayLink = {
    [unowned self] in
    
    let displayLink = CADisplayLink(
      target: self,
      selector: #selector(FilteredVideoVendor.step(_:)))
    
    displayLink.add(to: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
    displayLink.isPaused = true
    
    return displayLink
    }()
 
  func openMovie(_ url: URL){
    player = AVPlayer(url: url)
    
    guard let player = player,
      let currentItem = player.currentItem,
      let videoTrack = currentItem.asset.tracks(withMediaType: AVMediaTypeVideo).first else {
        fatalError("** unable to access item **")
    }
    
    currentURL = url
    failedPixelBufferForItemTimeCount = 0

    currentItem.add(videoOutput)
    
    videoTransform = videoTrack.preferredTransform.inverted()
    
    player.isMuted = true
  }
  
  func gotoNormalisedTime(_ normalisedTime: Double) {
    guard let player = player else {
      return
    }

    let timeSeconds = player.currentItem!.asset.duration.seconds * normalisedTime
    
    let time = CMTimeMakeWithSeconds(timeSeconds, 600)
    
    player.seek(
      to: time,
      toleranceBefore: kCMTimeZero,
      toleranceAfter: kCMTimeZero)
    
    displayVideoFrame(time)
  }
  
  // MARK: Main playback loop
  func step(_ link: CADisplayLink) {
    guard let player = player,
      let currentItem = player.currentItem else {
        return
    }
    
    let itemTime = videoOutput.itemTime(forHostTime: CACurrentMediaTime())
    
    displayVideoFrame(itemTime)
    
    let normalisedTime = Float(itemTime.seconds / currentItem.asset.duration.seconds)
    
    delegate?.vendorNormalisedTimeUpdated(normalisedTime)
    
    if normalisedTime >= 1.0
    {
      paused = true
    }
  }
  
  func displayVideoFrame(_ time: CMTime) {
    guard let player = player,
      let currentItem = player.currentItem, player.status == .readyToPlay && currentItem.status == .readyToPlay else {
        return
    }
    
    if videoOutput.hasNewPixelBuffer(forItemTime: time) {
      failedPixelBufferForItemTimeCount = 0
      
      var presentationItemTime = kCMTimeZero
      
      guard let pixelBuffer = videoOutput.copyPixelBuffer(
        forItemTime: time,
        itemTimeForDisplay: &presentationItemTime) else {
          return
      }
      
      unfilteredImage = CIImage(cvImageBuffer: pixelBuffer)
      
      displayFilteredImage()
    }
    else if let currentURL = currentURL, !paused {
      failedPixelBufferForItemTimeCount += 1
      
      if failedPixelBufferForItemTimeCount > 12 {
        openMovie(currentURL)
      }
    }
  }
  
  func displayFilteredImage() {
    guard let unfilteredImage = unfilteredImage,
      let videoTransform = videoTransform else {
        return
    }
    
    let ciImage: CIImage = opencvWrapper.processImage(withOpenCV: unfilteredImage.applying(videoTransform))
    
    let cgImage = ciContext.createCGImage(
        ciImage,
        from: ciImage.extent)

    delegate?.finalOutputUpdated(UIImage(cgImage: cgImage!))
  }
  
}

protocol FilteredVideoVendorDelegate: class {
  func finalOutputUpdated(_ image: UIImage)
  func vendorNormalisedTimeUpdated(_ normalisedTime: Float)
}
