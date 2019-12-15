//

import RangicCore

// Use the HandBrake command line - it uses ffmpeg and  is both easier to install and has a more stable CLI than ffmpeg
open class HandBrakeRunner {
    static public func getRotationOption(_ rotation: Int?) -> String {
        if let rot = rotation {
            switch rot {
            case 90:
                return "--rotate=4"
            case 180:
                return "--rotate=3"
            case 270:
                return "--rotate=7"
            case 0:
                return ""
            default:
                Logger.warn("Unhandled rotation \(rot)")
                return ""
            }
        }
        return ""
    }

    static public func convertVideo(_ sourceName: String, _ destinationName: String, _ rotationOption: String,
                                    _ logger: LogResults) {
        let handbrakePath = "/Applications/Extras/HandBrakeCLI"
        let handbrakeResult = ProcessInvoker.run(handbrakePath,
            arguments: [ "-e", "x264", "-q", "20.0", "-a", "1", "-E", "faac", "-B", "160", "-6", "dpl2", "-R", "Auto", "-D",
                "0.0", "--audio-copy-mask", "aac,ac3,dtshd,dts,mp3", "--audio-fallback", "ffac3", "-f", "mp4",
                "--loose-anamorphic", "--modulus", "2", "-m", "--x264-preset", "veryfast", "--h264-profile",
                "auto", "--h264-level", "auto", "-O",
                rotationOption,
                "-i", sourceName,
                "-o", destinationName])
        
        logHumanReadableProcessResult(logger, "HandBrake", handbrakeResult)
        if handbrakeResult.exitCode != 0 {
            return
        }

        // Copy the original video metadata to the new video
        do {
            let exifToolResult = try ExifToolRunner.copyMetadata(sourceName, destinationName)
            logger.log("ExifTool \(exifToolResult)\n")
        } catch let error {
            logger.log("ExifTool invocation failed: \(error)\n")
        }

        // Update the file timestamp on the new video to match the metadata timestamp
        let mediaData = FileMediaData.create(NSURL(fileURLWithPath: destinationName) as URL, mediaType: .video)
        let _ = mediaData.setFileDateToExifDate()
    }

    static public func logHumanReadableProcessResult(_ logger: LogResults, _ step: String, _ invoker: ProcessInvoker) {
        if invoker.exitCode == 0 {
            logger.log("\(step) completed\n")
        } else {
            logger.log("\(step) failed: \(invoker.exitCode)\n")
            logger.log("\toutput:\(invoker.output)\n")
            logger.log("\terror:\(invoker.error)\n")
        }
    }
}
