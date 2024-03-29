//
//  ExifToolRunner.swift
//

import RangicCore

public enum ExifToolError : Error {
    case notAFile(path: String)
    case updateFailed(error: String)
}

/// To see dates in images & videos:
///     exiftool -time:all -a -G0:1 -s <filename>

/// # To change metadata times in photos
///     exiftool -overwrite_original -AllDates+=1 -IFD0:ModifyDate+=1 -MakerNotes:SonyDateTime+=1 -IFD1:ModifyDate+=1 *.ARW



open class ExifToolRunner {
    static public func copyMetadata(_ sourceName: String, _ destinationName: String) throws -> String {
        return try runExifTool(["-overwrite_original", "-tagsFromFile", sourceName, destinationName])
    }

    static public func clearFileLocations(_ imageFilePaths: [String], videoFilePaths: [String]) throws {
        try checkFiles(imageFilePaths)
        try checkFiles(videoFilePaths)

        if imageFilePaths.count > 0 {
            let _ = try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                    "-exif:gpslatitude=",
                    "-exif:gpslatituderef=",
                    "-exif:gpslongitude=",
                    "-exif:gpslongituderef="]
                    + imageFilePaths)
        }

        if videoFilePaths.count > 0 {
            let _ = try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                    "-xmp:gpslatitude=",
                    "-xmp:gpslongitude="]
                    + videoFilePaths)
        }
    }

    static public func updateFileLocations(_ imageFilePaths: [String], videoFilePaths: [String], location: Location) throws {
        try checkFiles(imageFilePaths)
        try checkFiles(videoFilePaths)

        if imageFilePaths.count > 0 {
            let latRef = location.latitude < 0 ? "S" : "N"
            let lonRef = location.longitude < 0 ? "W" : "E"
            let absLat = abs(location.latitude)
            let absLon = abs(location.longitude)

            let _ = try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                "-exif:gpslatitude=\(absLat)",
                "-exif:gpslatituderef=\(latRef)",
                "-exif:gpslongitude=\(absLon)",
                "-exif:gpslongituderef=\(lonRef)"]
                + imageFilePaths)
        }

        if videoFilePaths.count > 0 {
            let latRef = location.latitude < 0 ? "S" : "N"
            let absLat = abs(location.latitude)
            let latDegrees = Int(absLat)
            let latMinutesAndSeconds = (absLat - Double(latDegrees)) * 60.0

            let lonRef = location.longitude < 0 ? "W" : "E"
            let absLong = abs(location.longitude)
            let lonDegrees = Int(absLong)
            let lonMinutesAndSeconds = (absLong - Double(lonDegrees)) * 60.0


            let _ = try runExifTool(
                [ "-P", "-fast", "-q", "-overwrite_original",
                    "-xmp:gpslatitude=\(latDegrees),\(latMinutesAndSeconds)\(latRef)",
                    "-xmp:gpslongitude=\(lonDegrees),\(lonMinutesAndSeconds)\(lonRef)"]
                    + videoFilePaths)
        }
    }

    static public func fixBadExif(_ filePaths: [String]) throws {
        let _ = try runExifTool(
            [ "-all=",
              "-tagsfromfile",
              "@",
              "-all:all",
              "-unsafe",
              "-icc_profile",
              "-m"]
            + filePaths)
    }
    
    static public func setKeywords(_ filePaths: [String], keywords: [String]) throws {
        var keywordCommands = [String]()
        for s in keywords {
            keywordCommands.append("-IPTC:Keywords=\(s)")
            keywordCommands.append("-XMP:Subject=\(s)")
        }

        let _ = try runExifTool(
            [ "-P", "-overwrite_original"]
                + keywordCommands
                + filePaths)
    }

    static public func updateKeywords(_ filePaths: [String], addedKeywords: [String], removedKeywords: [String]) throws -> Bool {
        if addedKeywords.count == 0 && removedKeywords.count == 0 {
            return false
        }

        var keywordCommands = [String]()
        for s in addedKeywords {
            keywordCommands.append("-IPTC:Keywords+=\(s)")
            keywordCommands.append("-XMP:Subject+=\(s)")
        }
        for s in removedKeywords {
            keywordCommands.append("-IPTC:Keywords-=\(s)")
            keywordCommands.append("-XMP:Subject-=\(s)")
        }

        let _ = try runExifTool(
            [ "-P", "-overwrite_original"]
                + keywordCommands
                + filePaths)

        return true
    }

    static public func setMetadataDates(_ imageFilePaths: [String], videoFilePaths: [String], newDate: NSDate) throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        let localDateString = dateFormatter.string(from: newDate as Date)

        if imageFilePaths.count > 0 {
            let _ = try runExifTool(
                ["-overwrite_original",
                    "-AllDates='\(localDateString)'",
                    "-IPTC:TimeCreated='\(localDateString)'",
                    "-IFD0:ModifyDate='\(localDateString)'",
                    "-IFD1:ModifyDate='\(localDateString)'",
                    "-MakerNotes:SonyDateTime='\(localDateString)'"]
                    + imageFilePaths)
        }

        // Some dates in Canon videos aren't updatable via exiftool (due to Canon silliness). Bummer
        // http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=6563.0
        if videoFilePaths.count > 0 {
            dateFormatter.timeZone = NSTimeZone(name: "UTC") as TimeZone?
            let utcDateString = dateFormatter.string(from: newDate as Date)

            let _ = try runExifTool(
                ["-overwrite_original",
                    "-AllDates='\(utcDateString)'",
                    "-quicktime:TrackCreateDate='\(utcDateString)'",
                    "-quicktime:TrackModifyDate='\(utcDateString)'",
                    "-quicktime:MediaCreateDate='\(utcDateString)'",
                    "-quicktime:MediaModifyDate='\(utcDateString)'",
                    "-quicktime:ContentCreateDate='\(utcDateString)'",
                    "-ExifIFD:CreateDate='\(localDateString)'",
                    "-ExifIFD:DateTimeOriginal='\(localDateString)'",
                    "-IFD0:ModifyDate='\(localDateString)'",
                    "-IFD1:ModifyDate='\(localDateString)"]
                    + videoFilePaths)
        }
    }

    static public func adjustMetadataDates(_ imageFilePaths: [String], videoFilePaths: [String], hours: Int, minutes: Int, seconds: Int) throws {
        var adjustment = "+=\(hours):\(minutes):\(seconds)"
        if (hours < 0 || minutes < 0 || seconds < 0) {
            adjustment = "-=\(abs(hours)):\(abs(minutes)):\(abs(seconds))"
        }

        if imageFilePaths.count > 0 {
            let _ = try runExifTool(
                ["-overwrite_original",
                    "-AllDates\(adjustment)",
                    "-IPTC:TimeCreated\(adjustment)",
                    "-IFD0:ModifyDate\(adjustment)",
                    "-IFD1:ModifyDate\(adjustment)",
                    "-MakerNotes:SonyDateTime\(adjustment)"]
                    + imageFilePaths)
        }

        // Some dates in Canon videos aren't updatable via exiftool (due to Canon silliness). Bummer
        // http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=6563.0
        if videoFilePaths.count > 0 {
            let _ = try runExifTool(
                ["-overwrite_original",
                    "-AllDates\(adjustment)",
                    "-quicktime:TrackCreateDate\(adjustment)",
                    "-quicktime:TrackModifyDate\(adjustment)",
                    "-quicktime:MediaCreateDate\(adjustment)",
                    "-quicktime:MediaModifyDate\(adjustment)",
                    "-quicktime:ContentCreateDate\(adjustment)",
                    "-ExifIFD:CreateDate\(adjustment)",
                    "-ExifIFD:DateTimeOriginal\(adjustment)",
                    "-IFD0:ModifyDate\(adjustment)",
                    "-IFD1:ModifyDate\(adjustment)"]
                    + videoFilePaths)
        }
    }

    static public var exifToolPath: String { return "/usr/local/bin/exiftool" }

    static fileprivate func checkFiles(_ filePaths: [String]) throws {
        for file in filePaths {
            if !FileManager.default.fileExists(atPath: file) {
                throw ExifToolError.notAFile(path: file)
            }
        }
    }

    static fileprivate func runExifTool(_ arguments: [String]) throws -> String {
        let process = ProcessInvoker.run(exifToolPath, arguments: arguments)
        if process.exitCode == 0 {
            return process.output
        }

        throw ExifToolError.updateFailed(error: "exiftool failed: \(process.exitCode); error: '\(process.error)'")
    }
}
