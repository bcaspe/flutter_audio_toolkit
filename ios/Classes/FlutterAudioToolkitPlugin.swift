import CoreMedia
import Flutter
import UIKit
import AVFoundation
import AudioToolbox
import Accelerate

public class FlutterAudioToolkitPlugin: NSObject, FlutterPlugin {
    private var progressEventSink: FlutterEventSink?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_audio_toolkit", binaryMessenger: registrar.messenger())
        let instance = FlutterAudioToolkitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let progressChannel = FlutterEventChannel(name: "flutter_audio_toolkit/progress", binaryMessenger: registrar.messenger())
        progressChannel.setStreamHandler(instance)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "convertAudio":
            handleConvertAudio(call: call, result: result)
        case "extractWaveform":
            handleExtractWaveform(call: call, result: result)
        case "isFormatSupported":
            handleIsFormatSupported(call: call, result: result)
        case "getAudioInfo":
            handleGetAudioInfo(call: call, result: result)
        case "trimAudio":
            handleTrimAudio(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleConvertAudio(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String,
              let format = args["format"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        let bitRateKbps = args["bitRate"] as? Int ?? 128 // Received in kbps from Dart
        let bitRate = bitRateKbps * 1000 // Convert to bps for iOS audio processing
        let sampleRate = args["sampleRate"] as? Int ?? 44100
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let conversionResult = try self.convertAudioFile(
                    inputPath: inputPath,
                    outputPath: outputPath,
                    format: format,
                    bitRate: bitRate,
                    sampleRate: sampleRate
                )
                DispatchQueue.main.async {
                    result(conversionResult)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "CONVERSION_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleExtractWaveform(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing inputPath", details: nil))
            return
        }
        
        let samplesPerSecond = args["samplesPerSecond"] as? Int ?? 100
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let waveformData = try self.extractWaveformData(inputPath: inputPath, samplesPerSecond: samplesPerSecond)
                DispatchQueue.main.async {
                    result(waveformData)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "WAVEFORM_ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func handleIsFormatSupported(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing inputPath", details: nil))
            return
        }
        
        let isSupported = isAudioFormatSupported(inputPath: inputPath)
        result(isSupported)
    }
    
    private func handleGetAudioInfo(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing inputPath", details: nil))
            return
        }
        
        do {
            let audioInfo = try getAudioFileInfo(inputPath: inputPath)
            result(audioInfo)
        } catch {
            result(FlutterError(code: "INFO_ERROR", message: error.localizedDescription, details: nil))
        }
    }
    
    private func handleTrimAudio(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let inputPath = args["inputPath"] as? String,
              let outputPath = args["outputPath"] as? String,
              let startTimeMs = args["startTimeMs"] as? Int,
              let endTimeMs = args["endTimeMs"] as? Int,
              let format = args["format"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing required arguments", details: nil))
            return
        }
        
        guard startTimeMs >= 0 && endTimeMs > startTimeMs else {
            result(FlutterError(code: "INVALID_RANGE", message: "Invalid time range: start=\(startTimeMs), end=\(endTimeMs)", details: nil))
            return
        }
        
        let bitRateKbps = args["bitRate"] as? Int ?? 128 // Received in kbps from Dart
        let bitRate = bitRateKbps * 1000 // Convert to bps for iOS audio processing
        let sampleRate = args["sampleRate"] as? Int ?? 44100
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let trimResult = try self.trimAudioFile(
                    inputPath: inputPath,
                    outputPath: outputPath,
                    startTimeMs: startTimeMs,
                    endTimeMs: endTimeMs,
                    format: format,
                    bitRate: bitRate,
                    sampleRate: sampleRate
                )
                
                DispatchQueue.main.async {
                    result(trimResult)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "TRIM_ERROR", message: "Failed to trim audio: \(error.localizedDescription)", details: nil))
                }
            }
        }
    }
    
    /// Configure audio session for optimal audio processing
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
    }
    
   
    /// Chooses the best export preset based on bitrate and sample rate
    func chooseExportPreset(bitRate: Int, sampleRate: Int) -> String {
        // Choose preset based on desired quality
        switch bitRate {
        case 0..<64:
            return AVAssetExportPresetLowQuality
        case 64..<128:
            return AVAssetExportPresetMediumQuality
        case 128..<256:
            return AVAssetExportPresetAppleM4A
        default:
            return AVAssetExportPresetHighestQuality
        }
    }
    
    /// Creates metadata for output file to ensure proper playback
    func createMetadata(for inputURL: URL) -> [AVMetadataItem] {
        let asset = AVAsset(url: inputURL)
        var metadata = asset.metadata
        
        // Add additional metadata if missing
        let requiredMetadata = [
            AVMetadataIdentifier.quickTimeMetadataLocationISO6709: "Generated by Flutter Audio Toolkit",
            AVMetadataIdentifier.commonIdentifierSoftware: "Flutter Audio Toolkit iOS",
            AVMetadataIdentifier.iTunesMetadataEncodingTool: "AVAssetExportSession"
        ]
        
        for (identifier, value) in requiredMetadata {
            let existingItem = metadata.first { $0.identifier == identifier }
            if existingItem == nil {
                let metadataItem = AVMutableMetadataItem()
                metadataItem.identifier = identifier
                metadataItem.value = value as NSString
                metadata.append(metadataItem)
            }
        }
        
        return metadata
    }
    
    /// Validates that the output file was created properly and can be read
    func validateOutputFile(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(domain: "AudioConverter", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "Output file was not created: \(url.path)"
            ])
        }
        
        // Check file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        guard fileSize > 0 else {
            throw NSError(domain: "AudioConverter", code: 7, userInfo: [
                NSLocalizedDescriptionKey: "Output file is empty: \(url.path)"
            ])
        }
        
        // Try to create an asset to validate the file format
        let asset = AVAsset(url: url)
        let tracks = asset.tracks(withMediaType: .audio)
        
        guard !tracks.isEmpty else {
            throw NSError(domain: "AudioConverter", code: 8, userInfo: [
                NSLocalizedDescriptionKey: "Output file contains no audio tracks: \(url.path)"
            ])
        }
    }
    
    private func convertAudioFile(inputPath: String, outputPath: String, format: String, bitRate: Int, sampleRate: Int) throws -> [String: Any] {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Ensure output directory exists
        try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        let asset = AVAsset(url: inputURL)
        
        // Get audio track
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        // Configure audio session
        try configureAudioSession()
        
        // Choose appropriate preset based on desired quality
        let presetName = chooseExportPreset(bitRate: bitRate, sampleRate: sampleRate)
        
        // Setup export session with retry logic for different presets
        var exportSession: AVAssetExportSession?
        let presetOptions = [presetName, AVAssetExportPresetAppleM4A, AVAssetExportPresetMediumQuality, AVAssetExportPresetLowQuality]
        
        for preset in presetOptions {
            if AVAssetExportSession.allExportPresets().contains(preset) {
                exportSession = AVAssetExportSession(asset: asset, presetName: preset)
                if exportSession != nil { break }
            }
        }
        
        guard let finalExportSession = exportSession else {
            throw NSError(domain: "AudioConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session with any preset"])
        }
        
        finalExportSession.outputURL = outputURL
        
        // Configure output file type safely
        try configureOutputFileType(for: finalExportSession, format: format, outputURL: outputURL)
        
        // Add metadata to ensure proper playback
        finalExportSession.metadata = createMetadata(for: inputURL)
        
        // Optimize for network use to ensure proper container format
        finalExportSession.shouldOptimizeForNetworkUse = true
        
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        var totalDuration: CMTime = CMTime.zero
        
        // Start progress monitoring
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let progress = Double(finalExportSession.progress)
            DispatchQueue.main.async {
                self?.progressEventSink?(["operation": "convert", "progress": progress])
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        
        finalExportSession.exportAsynchronously {
            timer.invalidate()
            if finalExportSession.status == .failed {
                exportError = finalExportSession.error
            }
            totalDuration = asset.duration
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = exportError {
            throw error
        }
        
        guard finalExportSession.status == .completed else {
            throw NSError(domain: "AudioConverter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Export failed with status: \(finalExportSession.status.rawValue)",
                NSLocalizedFailureReasonErrorKey: finalExportSession.error?.localizedDescription ?? "Unknown error"
            ])
        }
        
        let durationMs = Int(CMTimeGetSeconds(totalDuration) * 1000)
        
        // Verify the output file was created and has valid content
        try validateOutputFile(at: outputURL)
        
        return [
            "outputPath": outputPath,
            "durationMs": durationMs,
            "bitRate": bitRate / 1000, // Convert back to kbps for Dart consistency
            "sampleRate": sampleRate
        ]
    }
    
    private func trimAudioFile(inputPath: String, outputPath: String, startTimeMs: Int, endTimeMs: Int, format: String, bitRate: Int, sampleRate: Int) throws -> [String: Any] {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)
        
        // Use lossless copy if format is "copy"
        if format.lowercased() == "copy" {
            return try trimAudioLossless(inputURL: inputURL, outputURL: outputURL, startTimeMs: startTimeMs, endTimeMs: endTimeMs)
        }
        
        let asset = AVAsset(url: inputURL)
        
        // Get the audio track
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        // Configure audio session
        try configureAudioSession()
        
        // Validate time range
        let assetDuration = CMTimeGetSeconds(asset.duration)
        let startSeconds = Double(startTimeMs) / 1000.0
        let endSeconds = Double(endTimeMs) / 1000.0
        
        guard startSeconds >= 0 && endSeconds <= assetDuration && startSeconds < endSeconds else {
            throw NSError(domain: "AudioConverter", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Invalid time range: start=\(startSeconds)s, end=\(endSeconds)s, duration=\(assetDuration)s"
            ])
        }
        
        // Create composition for trimming
        let composition = AVMutableComposition()
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID())
        
        // Use higher timescale for more precise trimming
        let timescale: CMTimeScale = 44100
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: timescale)
        let endTime = CMTime(seconds: endSeconds, preferredTimescale: timescale)
        let duration = CMTimeSubtract(endTime, startTime)
        let timeRange = CMTimeRangeMake(start: startTime, duration: duration)
        
        do {
            try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        } catch {
            throw NSError(domain: "AudioConverter", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Failed to insert time range: \(error.localizedDescription)"
            ])
        }
        
        // Choose appropriate preset based on desired quality
        let presetName = chooseExportPreset(bitRate: bitRate, sampleRate: sampleRate)
        
        // Set up export session with retry logic
        var exportSession: AVAssetExportSession?
        let presetOptions = [presetName, AVAssetExportPresetAppleM4A, AVAssetExportPresetMediumQuality, AVAssetExportPresetLowQuality]
        
        for preset in presetOptions {
            if AVAssetExportSession.allExportPresets().contains(preset) {
                exportSession = AVAssetExportSession(asset: composition, presetName: preset)
                if exportSession != nil { break }
            }
        }
        
        guard let finalExportSession = exportSession else {
            throw NSError(domain: "AudioConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session with any preset"])
        }
        
        finalExportSession.outputURL = outputURL
        
        // Configure output file type safely
        try configureOutputFileType(for: finalExportSession, format: "m4a", outputURL: outputURL)
        
        // Add metadata to ensure proper playback
        finalExportSession.metadata = createMetadata(for: inputURL)
        
        // Optimize for network use to ensure proper container format
        finalExportSession.shouldOptimizeForNetworkUse = true
        
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        var totalDuration = CMTime.zero
        
        // Monitor progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let progress = Double(finalExportSession.progress)
            DispatchQueue.main.async {
                self?.progressEventSink?(["operation": "trim", "progress": progress])
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        
        finalExportSession.exportAsynchronously {
            timer.invalidate()
            if finalExportSession.status == .failed {
                exportError = finalExportSession.error
            }
            totalDuration = composition.duration
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = exportError {
            throw error
        }
        
        guard finalExportSession.status == .completed else {
            throw NSError(domain: "AudioConverter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Export failed with status: \(finalExportSession.status.rawValue)",
                NSLocalizedFailureReasonErrorKey: finalExportSession.error?.localizedDescription ?? "Unknown error"
            ])
        }
        
        let durationMs = Int(CMTimeGetSeconds(totalDuration) * 1000)
        
        // Verify the output file was created and has valid content
        try validateOutputFile(at: outputURL)
        
        return [
            "outputPath": outputPath,
            "durationMs": durationMs,
            "bitRate": bitRate / 1000, // Convert back to kbps for Dart consistency
            "sampleRate": sampleRate
        ]
    }
    
    private func trimAudioLossless(inputURL: URL, outputURL: URL, startTimeMs: Int, endTimeMs: Int) throws -> [String: Any] {
        let asset = AVAsset(url: inputURL)
        
        // Get the audio track
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        // Configure audio session
        try configureAudioSession()
        
        // Validate time range
        let assetDuration = CMTimeGetSeconds(asset.duration)
        let startSeconds = Double(startTimeMs) / 1000.0
        let endSeconds = Double(endTimeMs) / 1000.0
        
        guard startSeconds >= 0 && endSeconds <= assetDuration && startSeconds < endSeconds else {
            throw NSError(domain: "AudioConverter", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Invalid time range for lossless trim: start=\(startSeconds)s, end=\(endSeconds)s, duration=\(assetDuration)s"
            ])
        }
        
        // Create composition for trimming
        let composition = AVMutableComposition()
        let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: CMPersistentTrackID())
        
        // Use higher timescale for more precise trimming
        let timescale: CMTimeScale = 44100
        let startTime = CMTime(seconds: startSeconds, preferredTimescale: timescale)
        let endTime = CMTime(seconds: endSeconds, preferredTimescale: timescale)
        let duration = CMTimeSubtract(endTime, startTime)
        let timeRange = CMTimeRangeMake(start: startTime, duration: duration)
        
        do {
            try compositionAudioTrack?.insertTimeRange(timeRange, of: audioTrack, at: .zero)
        } catch {
            throw NSError(domain: "AudioConverter", code: 5, userInfo: [
                NSLocalizedDescriptionKey: "Failed to insert time range for lossless trim: \(error.localizedDescription)"
            ])
        }
        
        // Get original format information
        let formatDescriptions = audioTrack.formatDescriptions
        guard let formatDescription = formatDescriptions.first,
              CMFormatDescriptionGetMediaType(formatDescription as! CMFormatDescription) == kCMMediaType_Audio else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get audio format description"])
        }
        let audioFormatDescription = formatDescription as! CMAudioFormatDescription
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
        let originalSampleRate = Int(audioStreamBasicDescription?.pointee.mSampleRate ?? 44100)
        let originalChannels = Int(audioStreamBasicDescription?.pointee.mChannelsPerFrame ?? 2)
        let formatID = audioStreamBasicDescription?.pointee.mFormatID ?? kAudioFormatMPEG4AAC
        
        // Set up export session with appropriate preset to maintain quality
        let presetName: String
        switch formatID {
        case kAudioFormatMPEGLayer3:
            presetName = AVAssetExportPresetAppleM4A // Convert MP3 to M4A since iOS doesn't support MP3 export
        case kAudioFormatMPEG4AAC:
            presetName = AVAssetExportPresetHighestQuality // Use highest quality for existing M4A/AAC
        default:
            presetName = AVAssetExportPresetAppleM4A
        }
        
        // Set up export session with retry logic
        var exportSession: AVAssetExportSession?
        let presetOptions = [presetName, AVAssetExportPresetHighestQuality, AVAssetExportPresetAppleM4A]
        
        for preset in presetOptions {
            if AVAssetExportSession.allExportPresets().contains(preset) {
                exportSession = AVAssetExportSession(asset: composition, presetName: preset)
                if exportSession != nil { break }
            }
        }
        
        guard let finalExportSession = exportSession else {
            throw NSError(domain: "AudioConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create export session for lossless copy"])
        }
        
        finalExportSession.outputURL = outputURL
        
        // Configure output file type safely
        try configureOutputFileType(for: finalExportSession, format: "copy", outputURL: outputURL)
        
        // Add metadata to ensure proper playback
        finalExportSession.metadata = createMetadata(for: inputURL)
        
        // Optimize for network use to ensure proper container format
        finalExportSession.shouldOptimizeForNetworkUse = true
        
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: Error?
        var totalDuration = CMTime.zero
        
        // Monitor progress
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            let progress = Double(finalExportSession.progress)
            DispatchQueue.main.async {
                self?.progressEventSink?(["operation": "trim_lossless", "progress": progress])
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        
        finalExportSession.exportAsynchronously {
            timer.invalidate()
            if finalExportSession.status == .failed {
                exportError = finalExportSession.error
            }
            totalDuration = composition.duration
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = exportError {
            throw error
        }
        
        guard finalExportSession.status == .completed else {
            throw NSError(domain: "AudioConverter", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Lossless export failed with status: \(finalExportSession.status.rawValue)",
                NSLocalizedFailureReasonErrorKey: finalExportSession.error?.localizedDescription ?? "Unknown error"
            ])
        }
        
        let durationMs = Int(CMTimeGetSeconds(totalDuration) * 1000)
        
        // Verify the output file was created and has valid content
        try validateOutputFile(at: outputURL)
        
        // Estimate original bitrate
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: inputURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let originalDuration = CMTimeGetSeconds(asset.duration)
        let estimatedBitRate = originalDuration > 0 ? Int((Double(fileSize) * 8) / originalDuration) : 320000
        
        return [
            "outputPath": outputURL.path,
            "durationMs": durationMs,
            "bitRate": estimatedBitRate / 1000, // Convert to kbps for Dart consistency
            "sampleRate": originalSampleRate
        ]
    }
}

extension FlutterAudioToolkitPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        progressEventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        progressEventSink = nil
        return nil
    }
}

// MARK: - Private Helper Methods

private extension FlutterAudioToolkitPlugin {
    
    /// Extracts waveform data from an audio file
    func extractWaveformData(inputPath: String, samplesPerSecond: Int) throws -> [String: Any] {
        let inputURL = URL(fileURLWithPath: inputPath)
        let asset = AVAsset(url: inputURL)
        
        guard let audioTrack = asset.tracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        // Configure audio session
        try configureAudioSession()
        
        let reader = try AVAssetReader(asset: asset)
        
        // Audio output settings for PCM data
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        let readerOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        
        guard reader.startReading() else {
            throw NSError(domain: "AudioConverter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to start reading audio data"])
        }
        
        var amplitudes: [Double] = []
        let duration = CMTimeGetSeconds(asset.duration)
        let durationMs = Int(duration * 1000)
        
        // Get audio format description
        guard let formatDescription = audioTrack.formatDescriptions.first,
              CMFormatDescriptionGetMediaType(formatDescription as! CMFormatDescription) == kCMMediaType_Audio else {
            throw NSError(domain: "AudioConverter", code: 3, userInfo: [NSLocalizedDescriptionKey: "Cannot get audio format description"])
        }
        let audioFormatDescription = formatDescription as! CMAudioFormatDescription
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
        let sampleRate = Int(audioStreamBasicDescription?.pointee.mSampleRate ?? 44100)
        let channels = Int(audioStreamBasicDescription?.pointee.mChannelsPerFrame ?? 2)
        
        // Calculate sampling parameters
        let totalSamples = (durationMs * samplesPerSecond) / 1000
        let samplesPerBatch = max(1, sampleRate / samplesPerSecond)
        var sampleCount = 0
        var currentBatchSamples = 0
        var batchMaxAmplitude: Double = 0.0
        
        while reader.status == .reading {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
            
            guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                // ARC will handle sampleBuffer cleanup automatically
                continue
            }
            
            let length = CMBlockBufferGetDataLength(dataBuffer)
            var data = Data(count: length)
            
            let status = data.withUnsafeMutableBytes { bytes in
                CMBlockBufferCopyDataBytes(
                    dataBuffer, 
                    atOffset: 0, 
                    dataLength: length, 
                    destination: bytes.bindMemory(to: UInt8.self).baseAddress!
                )
            }
            
            guard status == kCMBlockBufferNoErr else { continue }
            
            // Process 16-bit PCM samples
            let sampleData = data.withUnsafeBytes { $0.bindMemory(to: Int16.self) }
            
            for sample in sampleData {
                let amplitude = abs(Double(sample)) / 32768.0 // Normalize to 0.0-1.0
                
                if currentBatchSamples == 0 {
                    batchMaxAmplitude = amplitude
                } else {
                    batchMaxAmplitude = max(batchMaxAmplitude, amplitude)
                }
                
                currentBatchSamples += 1
                
                if currentBatchSamples >= samplesPerBatch {
                    amplitudes.append(min(batchMaxAmplitude, 1.0))
                    sampleCount += 1
                    currentBatchSamples = 0
                    batchMaxAmplitude = 0.0
                    
                    // Update progress
                    let progress = min(Double(sampleCount) / Double(totalSamples), 1.0)
                    DispatchQueue.main.async { [weak self] in
                        self?.progressEventSink?(["operation": "waveform", "progress": progress])
                    }
                    
                    if sampleCount >= totalSamples { break }
                }
            }
            
            // ARC will handle sampleBuffer cleanup automatically
        }
        
        // Add any remaining batch
        if currentBatchSamples > 0 && sampleCount < totalSamples {
            amplitudes.append(min(batchMaxAmplitude, 1.0))
        }
        
        reader.cancelReading()
        
        // Final progress update
        DispatchQueue.main.async { [weak self] in
            self?.progressEventSink?(["operation": "waveform", "progress": 1.0])
        }
        
        return [
            "amplitudes": amplitudes,
            "sampleRate": sampleRate,
            "durationMs": durationMs,
            "channels": channels
        ]
    }
    
    /// Checks if an audio format is supported for processing
    func isAudioFormatSupported(inputPath: String) -> Bool {
        let url = URL(fileURLWithPath: inputPath)
        let asset = AVAsset(url: url)
        
        // Check if asset has audio tracks
        guard !asset.tracks(withMediaType: .audio).isEmpty else {
            return false
        }
        
        // Check file extension
        let pathExtension = url.pathExtension.lowercased()
        let supportedExtensions = ["mp3", "m4a", "aac", "wav", "ogg", "mp4"]
        
        return supportedExtensions.contains(pathExtension)
    }
    
    /// Gets comprehensive audio file information
    func getAudioFileInfo(inputPath: String) throws -> [String: Any] {
        let inputURL = URL(fileURLWithPath: inputPath)
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: inputPath) else {
            return [
                "isValid": false,
                "error": "File does not exist",
                "details": "The selected file could not be found at the specified path."
            ]
        }
        
        let asset = AVAsset(url: inputURL)
        let audioTracks = asset.tracks(withMediaType: .audio)
        
        guard let audioTrack = audioTracks.first else {
            return [
                "isValid": false,
                "error": "No audio track found",
                "details": "The file contains no audio tracks. Supported formats: mp3, m4a, aac, wav, ogg."
            ]
        }
        
        // Get file attributes
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: inputPath)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        
        // Get audio properties
        let duration = CMTimeGetSeconds(asset.duration)
        let durationMs = Int(duration * 1000)
        
        // Get format description
        guard let formatDescription = audioTrack.formatDescriptions.first,
              CMFormatDescriptionGetMediaType(formatDescription as! CMFormatDescription) == kCMMediaType_Audio else {
            throw NSError(domain: "AudioConverter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot get audio format description"])
        }
        let audioFormatDescription = formatDescription as! CMAudioFormatDescription
        
        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDescription)
        let sampleRate = Int(audioStreamBasicDescription?.pointee.mSampleRate ?? 44100)
        let channels = Int(audioStreamBasicDescription?.pointee.mChannelsPerFrame ?? 2)
        let formatID = audioStreamBasicDescription?.pointee.mFormatID ?? kAudioFormatMPEG4AAC
        
        // Estimate bitrate
        let bitRate = duration > 0 ? Int((Double(fileSize) * 8) / duration) : 320000
        
        // Determine MIME type from format ID
        let mime: String
        let formatDiagnostics: String
        let supportedForLosslessTrimming: Bool
        
        switch formatID {
        case kAudioFormatMPEGLayer3:
            mime = "audio/mpeg"
            formatDiagnostics = "MP3 format detected - Requires conversion for trimming"
            supportedForLosslessTrimming = false
        case kAudioFormatMPEG4AAC:
            mime = "audio/mp4a-latm"
            formatDiagnostics = "AAC/M4A format detected - Supports lossless trimming"
            supportedForLosslessTrimming = true
        case kAudioFormatLinearPCM:
            mime = "audio/wav"
            formatDiagnostics = "WAV format detected - Requires conversion for trimming"
            supportedForLosslessTrimming = false
        case kAudioFormatAppleLossless:
            mime = "audio/mp4"
            formatDiagnostics = "Apple Lossless format detected - Supports lossless trimming"
            supportedForLosslessTrimming = true
        default:
            mime = "audio/unknown"
            formatDiagnostics = "Unknown format - May require conversion"
            supportedForLosslessTrimming = false
        }
        
        let supportedForTrimming = true // iOS can handle most formats through conversion
        
        // Track information
        let foundTracks = audioTracks.enumerated().map { index, track in
            let trackFormatDescriptions = track.formatDescriptions
            if let trackFormatDescription = trackFormatDescriptions.first,
               CMFormatDescriptionGetMediaType(trackFormatDescription as! CMFormatDescription) == kCMMediaType_Audio {
                let audioFormatDesc = trackFormatDescription as! CMAudioFormatDescription
                let trackBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioFormatDesc)
                let trackFormatID = trackBasicDescription?.pointee.mFormatID ?? 0
                return "Track \(index): \(fourCharCodeToString(trackFormatID))"
            }
            return "Track \(index): Unknown format"
        }
        
        return [
            "isValid": true,
            "durationMs": durationMs,
            "sampleRate": sampleRate,
            "channels": channels,
            "bitRate": bitRate,
            "mime": mime,
            "trackIndex": 0,
            "fileSize": Int(fileSize),
            "supportedForTrimming": supportedForTrimming,
            "supportedForConversion": supportedForTrimming,
            "supportedForWaveform": supportedForTrimming,
            "supportedForLosslessTrimming": supportedForLosslessTrimming,
            "formatDiagnostics": formatDiagnostics,
            "foundTracks": foundTracks
        ]
    }
    
    /// Helper function to convert FourCharCode to String
    func fourCharCodeToString(_ code: FourCharCode) -> String {
        let bytes = withUnsafeBytes(of: code.bigEndian) { Data($0) }
        if let string = String(data: bytes, encoding: .ascii), !string.isEmpty {
            return string.trimmingCharacters(in: .controlCharacters)
        }
        return String(format: "0x%08X", code)
    }
    
    /// Helper function to safely configure output file type for AVAssetExportSession
    private func configureOutputFileType(for exportSession: AVAssetExportSession, format: String, outputURL: URL) throws {
        // Determine the appropriate output file type based on format and file extension
        let outputFileExtension = outputURL.pathExtension.lowercased()
        let requestedFormat = format.lowercased()
        
        var preferredFileType: AVFileType
        
        // Determine preferred file type based on format request and file extension
        if requestedFormat == "copy" {
            // For copy operations, try to maintain original format where possible
            switch outputFileExtension {
            case "m4a", "aac":
                preferredFileType = AVFileType.m4a
            case "mp4":
                preferredFileType = AVFileType.mp4
            case "caf":
                preferredFileType = AVFileType.caf
            case "wav", "wave":
                preferredFileType = AVFileType.wav
            case "aiff", "aif":
                preferredFileType = AVFileType.aiff
            default:
                preferredFileType = AVFileType.m4a // Default to M4A for audio
            }
        } else {
            // For format conversions, choose based on requested format
            switch requestedFormat {
            case "m4a", "aac":
                preferredFileType = AVFileType.m4a
            case "mp4":
                preferredFileType = AVFileType.mp4
            case "wav":
                preferredFileType = AVFileType.wav
            case "caf":
                preferredFileType = AVFileType.caf
            case "aiff":
                preferredFileType = AVFileType.aiff
            default:
                preferredFileType = AVFileType.m4a // Default to M4A for audio
            }
        }
        
        // Check if the preferred file type is supported by the export session
        if exportSession.supportedFileTypes.contains(preferredFileType) {
            exportSession.outputFileType = preferredFileType
            return
        }
        
        // Fallback logic if preferred type is not supported
        let fallbackTypes: [AVFileType] = [
            AVFileType.m4a,
            AVFileType.mp4,
            AVFileType.caf,
            AVFileType.wav,
            AVFileType.aiff
        ]
        
        for fallbackType in fallbackTypes {
            if exportSession.supportedFileTypes.contains(fallbackType) {
                exportSession.outputFileType = fallbackType
                print("Warning: Preferred file type \(preferredFileType) not supported, using \(fallbackType)")
                return
            }
        }
        
        // Last resort: use the first supported type
        if let firstSupported = exportSession.supportedFileTypes.first {
            exportSession.outputFileType = firstSupported
            print("Warning: Using first available file type: \(firstSupported)")
        } else {
            throw NSError(domain: "AudioConverter", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "No supported output file types available for export session"
            ])
        }
    }
}
