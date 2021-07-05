//

import Foundation
import RangicCore

struct DateAndFiles {
    let date: String
    let exportedPaths: [String]
    let originalPaths: [String]

    init(_ date: String, _ exported: [String], _ original: [String]) {
        self.date = date
        self.exportedPaths = exported
        self.originalPaths = original
    }
}

class ImportMedia {
    static func run(_ rootDirectory: String, _ importList: [DateAndFiles], _ logger: LogResults) {
        ImportMedia(rootDirectory, logger).run(importList)
    }

    private let rootDirectory: String
    private let logger: LogResults
    private init(_ rootDirectory: String, _ logger: LogResults) {
        self.rootDirectory = rootDirectory
        self.logger = logger
    }

    private func run(_ importList: [DateAndFiles]) {
        // Create directory if it doesn't exist
        // Move exported, setting the file date to the exif date
        // Move originals, renaming any .JPG or .JPEG as ({file}-org.{ext}) to avoid conflict with exported
        // Convert videos from originals

        do {
            for daf in importList {
                logger.log("Importing \(daf.date):\n")
                let targetFolder = try createDirectory(daf.date)
                logger.log("  Moving exported media:\n")
                try move(targetFolder, daf.exportedPaths, false)
                logger.log("  Moving original media:\n")
                try move(targetFolder, daf.originalPaths, true)
                try convertVideos(targetFolder)
            }
        } catch {
            logger.log("Error importing: \(error)")
        }

    }

    private func convertVideos(_ folder: String) throws {
        let videos = try FileManager.default.contentsOfDirectory(atPath: folder)
            .filter { !$0.hasSuffix("_V.MP4") && SupportedMediaTypes.getType(URL(fileURLWithPath: "\(folder)/\($0)")) == .video }

        if videos.isEmpty {
            return
        }

        logger.log("  Converting videos:\n")
        for v in videos {
            let url = URL(fileURLWithPath: "\(folder)/\(v)")
            let md = FileMediaData.create(url, mediaType: SupportedMediaTypes.getType(url))
            let rotationOption = HandBrakeRunner.getRotationOption(md.rotation)

            let sourceName = "\(folder)/\(v)"
            let destFilename = "\((v as NSString).deletingPathExtension)_V.MP4"
            let destPath = "\(folder)/\(destFilename)"
            logger.log("Convert \(v) -> \(destFilename)\n")
            HandBrakeRunner.convertVideo(sourceName, destPath, rotationOption, logger)
        }
    }

    private func move(_ folder: String, _ filePaths: [String], _ isOriginal: Bool) throws {
        for f in filePaths {
            let sourceFilename = (f as NSString).lastPathComponent
            let destFilename = generateFilename(sourceFilename, isOriginal)
            logger.log("    \(sourceFilename) -> \(destFilename)\n")

            if !isOriginal {
                let url = URL(fileURLWithPath: f)
                let md = FileMediaData.create(url, mediaType: SupportedMediaTypes.getType(url))
                let (succeeded, message) = md.setFileDateToExifDate()
                if !succeeded {
                    logger.log("      ---> failed updating file date: \(message)")
                }
            }

            try FileManager.default.moveItem(atPath: f, toPath: "\(folder)/\(destFilename)")
        }
    }

    private func generateFilename(_ name: String, _ isOriginal: Bool) -> String {
        if !isOriginal {
            return name
        }
        let fileExtension = (name as NSString).pathExtension
        if fileExtension.caseInsensitiveCompare("jpg") != .orderedSame && fileExtension.caseInsensitiveCompare("jpeg") != .orderedSame {
            return name
        }
        return (name as NSString).deletingPathExtension.appending("-org.\(fileExtension)")
    }

    // The date is in "YYYY-mm-DD" format; it gets created as "<root>/YYYY/YYYY-mm-DD"
    private func createDirectory(_ date: String) throws -> String {
        let year = date.prefix(4)
        let folder = "\(rootDirectory)/\(year)/\(date)"
        if !FileManager.default.fileExists(atPath: folder) {
            logger.log("  Creating \(year)/\(date)\n")
            try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true, attributes: nil)
        }
        return folder
    }
}
