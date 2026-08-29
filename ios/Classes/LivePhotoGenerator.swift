import Foundation
import Photos
import AVFoundation
import MobileCoreServices
import ImageIO

class LivePhotoGenerator {
    
    static func generate(imagePath: String, videoPath: String, completion: @escaping (Bool, Error?) -> Void) {
        let assetIdentifier = UUID().uuidString
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        let newImageURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("jpg")
        let newVideoURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
        
        // 1. Process Image
        guard let imageSource = CGImageSourceCreateWithURL(URL(fileURLWithPath: imagePath) as CFURL, nil),
              let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            completion(false, NSError(domain: "LivePhotoGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to read image source"]))
            return
        }
        
        guard let imageDestination = CGImageDestinationCreateWithURL(newImageURL as CFURL, kUTTypeJPEG, 1, nil) else {
            completion(false, NSError(domain: "LivePhotoGenerator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"]))
            return
        }
        
        var newImageProperties = imageProperties
        let makerAppleDict: [String: Any] = ["17": assetIdentifier]
        newImageProperties[kCGImagePropertyMakerAppleDictionary as String] = makerAppleDict
        
        CGImageDestinationAddImageFromSource(imageDestination, imageSource, 0, newImageProperties as CFDictionary)
        if !CGImageDestinationFinalize(imageDestination) {
            completion(false, NSError(domain: "LivePhotoGenerator", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize image destination"]))
            return
        }
        
        // 2. Process Video
        let videoAsset = AVAsset(url: URL(fileURLWithPath: videoPath))
        
        writeVideoWithMetadata(asset: videoAsset, outputURL: newVideoURL, assetIdentifier: assetIdentifier) { success, error in
            if !success {
                completion(false, error ?? NSError(domain: "LivePhotoGenerator", code: 4, userInfo: [NSLocalizedDescriptionKey: "Failed to process video"]))
                return
            }
            
            // 3. Save to Photo Library
            PHPhotoLibrary.shared().performChanges({
                let creationRequest = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                
                creationRequest.addResource(with: .photo, fileURL: newImageURL, options: options)
                creationRequest.addResource(with: .pairedVideo, fileURL: newVideoURL, options: options)
                
            }) { success, error in
                // Cleanup temp files
                try? fileManager.removeItem(at: newImageURL)
                try? fileManager.removeItem(at: newVideoURL)
                
                completion(success, error)
            }
        }
    }
    
    private static func writeVideoWithMetadata(asset: AVAsset, outputURL: URL, assetIdentifier: String, completion: @escaping (Bool, Error?) -> Void) {
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            completion(false, NSError(domain: "LivePhotoGenerator", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
            return
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        
        // Setup Metadata
        let itemIdentifier = AVMutableMetadataItem()
        itemIdentifier.key = "com.apple.quicktime.content.identifier" as (NSCopying & NSObjectProtocol)
        itemIdentifier.keySpace = .quickTimeMetadata
        itemIdentifier.value = assetIdentifier as (NSCopying & NSObjectProtocol)
        itemIdentifier.dataType = kCMMetadataBaseDataType_UTF8 as String
        
        // Still Image Time (Optional but recommended, set to 0 or start)
        // Note: AVAssetExportSession might not support writing all custom metadata easily with presets.
        // If Passthrough doesn't allow metadata modification in the way we want, we might need AVAssetWriter.
        // However, ExportSession usually supports adding metadata.
        
        exportSession.metadata = [itemIdentifier]
        
        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true, nil)
            case .failed:
                completion(false, exportSession.error)
            case .cancelled:
                completion(false, NSError(domain: "LivePhotoGenerator", code: 6, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
            default:
                completion(false, NSError(domain: "LivePhotoGenerator", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unknown export error"]))
            }
        }
    }
}
