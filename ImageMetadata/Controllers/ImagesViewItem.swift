//

import Cocoa
import AVKit

import Async
import RangicCore

class ImagesViewItem: NSCollectionViewItem {
    static var maxThumbnailPixelSize = 300

    // NOTE: 'textField' is the filename label
    @IBOutlet weak var timestampLabel: NSTextField!
    @IBOutlet weak var locationLabel: NSTextField!
    @IBOutlet weak var keywordsLabel: NSTextField!


    var mediaData: MediaData? {
        didSet {
            imageView?.image = nil
            textField?.stringValue = mediaData!.name!

            if mediaData!.doFileAndExifTimestampsMatch() {
                timestampLabel?.textColor = nil
                timestampLabel?.stringValue = mediaData!.formattedTime()
            } else {
                timestampLabel?.textColor = NSColor.yellow
                timestampLabel?.stringValue = mediaData!.formattedTime()
            }

            if mediaData!.keywordsString().count > 0 {
                keywordsLabel?.stringValue = mediaData!.keywordsString()
            } else {
                keywordsLabel?.stringValue = "🏷"
            }

            locationLabel?.textColor = nil
            if let location = mediaData!.location {
                locationLabel?.stringValue = location.toDecimalDegrees(true)
                if SensitiveLocations.sharedInstance.isSensitive(location) {
                    locationLabel?.textColor = NSColor.orange
                }
            } else {
                locationLabel?.stringValue = "📍"
            }

            Async.background {
                if let thumbnail = self.createThumbnail() {
                    Async.main {
                        self.imageView?.image = thumbnail
                    }
                }
            }
        }
    }

    override var isSelected: Bool {
      didSet {
        if isSelected {
            view.layer?.borderWidth = 4.0
            view.layer?.borderColor = NSColor.linkColor.cgColor

        } else {
            view.layer?.borderWidth = 0.0
            view.layer?.borderColor = nil
        }
      }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.alternatingContentBackgroundColors[1].cgColor
    }

    private func createThumbnail() -> NSImage? {
        if mediaData?.type == .image {
            if let imageSource = CGImageSourceCreateWithURL(mediaData!.url.absoluteURL as CFURL, nil) {
                if CGImageSourceGetType(imageSource) != nil {
                    let thumbnailOptions = [
                        String(kCGImageSourceCreateThumbnailFromImageAlways): true,
                        String(kCGImageSourceCreateThumbnailWithTransform): true,
                        String(kCGImageSourceThumbnailMaxPixelSize): ImagesViewItem.maxThumbnailPixelSize
                        ] as [String : Any]

                    if let thumbnailRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, thumbnailOptions as CFDictionary?) {
                        return NSImage(cgImage: thumbnailRef, size: NSSize.zero)
                    }
                }
            }
        } else if mediaData?.type == .video {
            let asset = AVAsset(url: mediaData!.url)
            let startTime = CMTimeMake(value: 0, timescale: 1)
            if let image = try? AVAssetImageGenerator(asset: asset).copyCGImage(at: startTime, actualTime: nil) {
                return NSImage(cgImage: image, size: NSSize.zero)
            }
        }
        return nil
    }
    
}
