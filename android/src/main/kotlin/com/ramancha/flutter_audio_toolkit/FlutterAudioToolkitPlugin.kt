package com.ramancha.flutter_audio_toolkit

import android.content.Context
import android.media.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*
import java.io.File
import java.io.IOException
import java.nio.ByteBuffer
import kotlin.math.*

/** FlutterAudioToolkitPlugin */
class FlutterAudioToolkitPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var progressChannel: EventChannel
    private lateinit var context: Context
    private var progressSink: EventChannel.EventSink? = null

    companion object {
        private const val TAG = "FlutterAudioToolkit"
        private const val TIMEOUT_US = 10000L
        private const val SAMPLE_RATE = 44100
        private const val BIT_RATE = 128000
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_toolkit")
        channel.setMethodCallHandler(this)
        
        progressChannel = EventChannel(flutterPluginBinding.binaryMessenger, "flutter_audio_toolkit/progress")
        progressChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                progressSink = events
            }
            override fun onCancel(arguments: Any?) {
                progressSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        progressSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "convertAudio" -> {
                handleConvertAudio(call, result)
            }
            "extractWaveform" -> {
                handleExtractWaveform(call, result)
            }
            "isFormatSupported" -> {
                handleIsFormatSupported(call, result)
            }
            "getAudioInfo" -> {
                handleGetAudioInfo(call, result)
            }
            "trimAudio" -> {
                handleTrimAudio(call, result)
            }
            "spliceAudio" -> {
                handleSpliceAudio(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun processRemainingEncoderOutput(
    encoder: MediaCodec,
    muxer: MediaMuxer,
    audioTrackIndex: Int
) {
    val encoderBufferInfo = MediaCodec.BufferInfo()
    
    while (true) {
        val encoderOutputIndex = encoder.dequeueOutputBuffer(encoderBufferInfo, 1000L)
        when (encoderOutputIndex) {
            MediaCodec.INFO_TRY_AGAIN_LATER -> {
                break
            }
            else -> {
                if (encoderOutputIndex >= 0) {
                    val encodedData = encoder.getOutputBuffer(encoderOutputIndex)
                    
                    if (encoderBufferInfo.size > 0 && encodedData != null) {
                        muxer.writeSampleData(audioTrackIndex, encodedData, encoderBufferInfo)
                    }
                    
                    encoder.releaseOutputBuffer(encoderOutputIndex, false)
                    
                    if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        break
                    }
                }
            }
        }
    }
}

    private fun spliceAudioDataFromFile(
    extractor: MediaExtractor,
    decoder: MediaCodec,
    encoder: MediaCodec,
    muxer: MediaMuxer,
    inputFormat: MediaFormat,
    timeOffsetUs: Long,
    shouldStartMuxer: Boolean
): Long {
    val decoderBufferInfo = MediaCodec.BufferInfo()
    val encoderBufferInfo = MediaCodec.BufferInfo()
    
    var decoderDone = false
    var encoderDone = false
    var encoderEOSSignaled = false
    var muxerStarted = !shouldStartMuxer
    var audioTrackIndex = -1
    
    var fileDurationUs = 0L
    
    while (!decoderDone) {
        // Feed input to decoder
        if (!decoderDone) {
            val inputBufferIndex = decoder.dequeueInputBuffer(1000L)
            if (inputBufferIndex >= 0) {
                val inputBuffer = decoder.getInputBuffer(inputBufferIndex)
                if (inputBuffer != null) {
                    inputBuffer.clear()
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)
                    
                    if (sampleSize < 0) {
                        decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        decoderDone = true
                    } else {
                        val presentationTimeUs = extractor.sampleTime
                        decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, presentationTimeUs, 0)
                        extractor.advance()
                        
                        if (presentationTimeUs > fileDurationUs) {
                            fileDurationUs = presentationTimeUs
                        }
                    }
                }
            }
        }
        
        // Get output from decoder and feed to encoder
        val decoderOutputIndex = decoder.dequeueOutputBuffer(decoderBufferInfo, 1000L)
        if (decoderOutputIndex >= 0) {
            val decoderOutputBuffer = decoder.getOutputBuffer(decoderOutputIndex)
            
            if (decoderBufferInfo.size > 0 && decoderOutputBuffer != null) {
                val encoderInputIndex = encoder.dequeueInputBuffer(5000L)
                if (encoderInputIndex >= 0) {
                    val encoderInputBuffer = encoder.getInputBuffer(encoderInputIndex)
                    if (encoderInputBuffer != null) {
                        encoderInputBuffer.clear()
                        
                        val dataSize = minOf(decoderBufferInfo.size, encoderInputBuffer.remaining())
                        if (dataSize > 0) {
                            decoderOutputBuffer.position(decoderBufferInfo.offset)
                            decoderOutputBuffer.limit(decoderBufferInfo.offset + dataSize)
                            encoderInputBuffer.put(decoderOutputBuffer)
                        }
                        
                        // Adjust timestamp with offset
                        val adjustedTimeUs = decoderBufferInfo.presentationTimeUs + timeOffsetUs
                        
                        encoder.queueInputBuffer(
                            encoderInputIndex,
                            0,
                            dataSize,
                            adjustedTimeUs,
                            decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv()
                        )
                    }
                }
            }
            
            decoder.releaseOutputBuffer(decoderOutputIndex, false)
            
            if (decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                decoderDone = true
            }
        }
        
        // Get output from encoder
        val encoderOutputIndex = encoder.dequeueOutputBuffer(encoderBufferInfo, 1000L)
        when (encoderOutputIndex) {
            MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                if (!muxerStarted) {
                    val outputFormat = encoder.outputFormat
                    audioTrackIndex = muxer.addTrack(outputFormat)
                    muxer.start()
                    muxerStarted = true
                }
            }
            else -> {
                if (encoderOutputIndex >= 0) {
                    val encodedData = encoder.getOutputBuffer(encoderOutputIndex)
                    
                    if (encoderBufferInfo.size > 0 && muxerStarted && encodedData != null) {
                        muxer.writeSampleData(audioTrackIndex, encodedData, encoderBufferInfo)
                    }
                    
                    encoder.releaseOutputBuffer(encoderOutputIndex, false)
                    
                    if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        encoderDone = true
                    }
                }
            }
        }
    }
    
    return fileDurationUs
}

private fun handleSpliceAudio(call: MethodCall, result: Result) {
    val inputPaths = call.argument<List<String>>("inputPaths")
    val outputPath = call.argument<String>("outputPath")
    val format = call.argument<String>("format") ?: "m4a"
    val bitRateKbps = call.argument<Int>("bitRate") ?: 128
    val sampleRate = call.argument<Int>("sampleRate") ?: SAMPLE_RATE

    if (inputPaths == null || outputPath == null || inputPaths.isEmpty()) {
        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
        return
    }

    GlobalScope.launch(Dispatchers.IO) {
        try {
            Log.d(TAG, "Starting audio splicing: ${inputPaths.size} files -> $outputPath")
            val splicedData = spliceAudioFiles(inputPaths, outputPath, format, bitRateKbps * 1000, sampleRate)
            Handler(Looper.getMainLooper()).post {
                result.success(splicedData)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Audio splicing failed", e)
            Handler(Looper.getMainLooper()).post {
                result.error("SPLICE_ERROR", "Audio splicing failed: ${e.javaClass.simpleName} - ${e.message}", null)
            }
        }
    }
}

    private suspend fun spliceAudioFiles(
    inputPaths: List<String>,
    outputPath: String,
    format: String,
    bitRate: Int,
    sampleRate: Int
): Map<String, Any?> = withContext(Dispatchers.IO) {
    
    Log.d(TAG, "Splicing ${inputPaths.size} audio files into: $outputPath")
    
    val extractor = MediaExtractor()
    var decoder: MediaCodec? = null
    var encoder: MediaCodec? = null
    var muxer: MediaMuxer? = null
    
    try {
        // Ensure output directory exists
        File(outputPath).parentFile?.mkdirs()
        
        // Setup muxer
        muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        
        var audioTrackIndex = -1
        var muxerStarted = false
        var totalDurationUs = 0L
        var currentTimeOffsetUs = 0L
        
        // Process each input file
        for ((fileIndex, inputPath) in inputPaths.withIndex()) {
            Log.d(TAG, "Processing file $fileIndex: $inputPath")
            
            // Setup extractor for current file
            extractor.setDataSource(inputPath)
            
            // Find audio track
            var currentAudioTrackIndex = -1
            var inputFormat: MediaFormat? = null
            
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    currentAudioTrackIndex = i
                    inputFormat = format
                    break
                }
            }
            
            if (currentAudioTrackIndex == -1 || inputFormat == null) {
                Log.w(TAG, "No audio track found in file: $inputPath")
                continue
            }
            
            extractor.selectTrack(currentAudioTrackIndex)
            
            // Setup decoder for first file or if format changed
            if (decoder == null) {
                val inputMime = inputFormat.getString(MediaFormat.KEY_MIME)!!
                decoder = MediaCodec.createDecoderByType(inputMime)
                decoder.configure(inputFormat, null, null, 0)
                decoder.start()
                
                // Setup encoder
                val outputMime = "audio/mp4a-latm"
                encoder = MediaCodec.createEncoderByType(outputMime)
                
                val inputChannels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                val inputSampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                    inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                } else {
                    sampleRate
                }
                
                val outputChannels = if (inputChannels in 1..2) inputChannels else 2
                val outputSampleRate = if (inputSampleRate in 8000..48000) inputSampleRate else sampleRate
                
                val encoderFormat = MediaFormat.createAudioFormat(outputMime, outputSampleRate, outputChannels).apply {
                    setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                    setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                    setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 65536)
                    setInteger(MediaFormat.KEY_CHANNEL_MASK, 
                        if (outputChannels == 1) AudioFormat.CHANNEL_OUT_MONO 
                        else AudioFormat.CHANNEL_OUT_STEREO)
                }
                
                encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
                encoder.start()
            }
            
            // Process audio data from current file
            val fileDurationUs = spliceAudioDataFromFile(
                extractor, decoder, encoder, muxer, 
                inputFormat, currentTimeOffsetUs, !muxerStarted
            )
            
            totalDurationUs += fileDurationUs
            currentTimeOffsetUs = totalDurationUs
            
            // Reset extractor for next file
            extractor.release()
            extractor = MediaExtractor()
            
            // Report progress
            val progress = (fileIndex + 1).toDouble() / inputPaths.size.toDouble()
            Handler(Looper.getMainLooper()).post {
                progressSink?.success(mapOf("operation" to "splice", "progress" to progress))
            }
        }
        
        // Signal EOS to encoder
        if (encoder != null) {
            val encoderInputIndex = encoder.dequeueInputBuffer(5000L)
            if (encoderInputIndex >= 0) {
                encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
            }
        }
        
        // Process remaining encoder output
        if (encoder != null && muxer != null) {
            processRemainingEncoderOutput(encoder, muxer, audioTrackIndex)
        }
        
        Log.d(TAG, "Audio splicing completed successfully")
        
        mapOf(
            "outputPath" to outputPath,
            "durationMs" to (totalDurationUs / 1000).toInt(),
            "bitRate" to (bitRate / 1000),
            "sampleRate" to sampleRate,
            "filesProcessed" to inputPaths.size
        )
        
    } finally {
        // Cleanup resources
        decoder?.let {
            try {
                it.stop()
                it.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing decoder", e)
            }
        }
        
        encoder?.let {
            try {
                it.stop()
                it.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing encoder", e)
            }
        }
        
        muxer?.let {
            try {
                it.stop()
                it.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing muxer", e)
            }
        }
        
        try {
            extractor.release()
        } catch (e: Exception) {
            Log.w(TAG, "Error releasing extractor", e)
        }
    }
}

    private fun handleConvertAudio(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")
        val format = call.argument<String>("format")
        val bitRateKbps = call.argument<Int>("bitRate") ?: 128 // Received in kbps from Dart
        val sampleRate = call.argument<Int>("sampleRate") ?: SAMPLE_RATE

        // Convert bitRate from kbps to bps for MediaCodec
        val bitRate = bitRateKbps * 1000

        if (inputPath == null || outputPath == null || format == null) {
            result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
            return
        }

        GlobalScope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "Starting audio conversion: $inputPath -> $outputPath (format: $format, bitRate: ${bitRateKbps}kbps)")
                val convertedData = convertAudio(inputPath, outputPath, format, bitRate, sampleRate)
                Handler(Looper.getMainLooper()).post {
                    result.success(convertedData)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Audio conversion failed", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("CONVERSION_ERROR", "Audio conversion failed: ${e.javaClass.simpleName} - ${e.message}", null)
                }
            }
        }
    }

    private suspend fun convertAudio(
        inputPath: String,
        outputPath: String,
        format: String,
        bitRate: Int,
        sampleRate: Int
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        
        Log.d(TAG, "Converting audio file: $inputPath -> $outputPath, format: $format")
        
        // Handle copy format with lossless copying
        if (format.lowercase() == "copy") {
            return@withContext convertAudioLossless(inputPath, outputPath)
        }
        
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null  
        var muxer: MediaMuxer? = null

        try {
            // Setup extractor
            extractor.setDataSource(inputPath)
            Log.d(TAG, "Setting data source: $inputPath")

            // Find audio track
            var audioTrackIndex = -1
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                Log.d(TAG, "Track $i: MIME = $mime")
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    Log.d(TAG, "Found audio track at index $i")
                    break
                }
            }

            if (audioTrackIndex == -1) {
                throw IOException("No audio track found in input file")
            }

            val inputFormat = extractor.getTrackFormat(audioTrackIndex)
            extractor.selectTrack(audioTrackIndex)

            // Create decoder
            val inputMime = inputFormat.getString(MediaFormat.KEY_MIME) ?: ""
            Log.d(TAG, "Creating decoder for MIME type: $inputMime")
            decoder = MediaCodec.createDecoderByType(inputMime)
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()

            // Create encoder with proper AAC configuration
            val outputMime = "audio/mp4a-latm" // Always use AAC for M4A format
            
            Log.d(TAG, "Creating AAC encoder for MIME type: $outputMime")
            encoder = MediaCodec.createEncoderByType(outputMime)
            
            // Get input format details for proper encoding setup
            val inputChannels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val inputSampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                sampleRate
            }
            
            Log.d(TAG, "Input format - Channels: $inputChannels, Sample Rate: $inputSampleRate")
            
            // Use input format characteristics or defaults
            val outputChannels = if (inputChannels in 1..2) inputChannels else 2
            val outputSampleRate = if (inputSampleRate in 8000..48000) inputSampleRate else sampleRate
            
            val outputFormat = MediaFormat.createAudioFormat(outputMime, outputSampleRate, outputChannels).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                
                // CRITICAL: Increase buffer sizes to prevent data loss
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 65536) // Increased from 16384
                
                // Essential for proper AAC encoding
                setInteger(MediaFormat.KEY_CHANNEL_MASK, 
                    if (outputChannels == 1) AudioFormat.CHANNEL_OUT_MONO 
                    else AudioFormat.CHANNEL_OUT_STEREO)
                
                // Optional quality improvements for AAC
                // Higher quality settings that may help
                try {
                    // These may not be supported on all devices, so wrap in try-catch
                    setInteger("aac-target-ref-bitrate", bitRate)
                    setInteger("aac-encoded-target-level", 1) // Enable high quality
                } catch (e: Exception) {
                    Log.d(TAG, "Optional AAC quality settings not supported: ${e.message}")
                }
            }
            
            Log.d(TAG, "*** AUDIO QUALITY DEBUG ***")
            Log.d(TAG, "Encoder config - Channels: $outputChannels, Sample Rate: $outputSampleRate, Bit Rate: $bitRate bps (${bitRate/1000} kbps)")
            Log.d(TAG, "*** END AUDIO QUALITY DEBUG ***")
            
            encoder.configure(outputFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            
            // Create muxer
            // Ensure output directory exists
            File(outputPath).parentFile?.mkdirs()
            
            Log.d(TAG, "Creating muxer for output: $outputPath")
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val audioData = processAudioData(extractor, decoder, encoder, muxer, inputFormat, outputPath, bitRate, sampleRate)
            
            Log.d(TAG, "Audio conversion completed successfully")
            audioData
            
        } finally {
            Log.d(TAG, "Cleaning up conversion resources")
            
            decoder?.let {
                try {
                    // Try to stop, but it might already be stopped/released
                    try {
                        it.stop()
                        Log.d(TAG, "Conversion decoder stopped")
                    } catch (e: IllegalStateException) {
                        Log.d(TAG, "Decoder already stopped - this is expected")
                    }
                    
                    it.release()
                    Log.d(TAG, "Conversion decoder released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing conversion decoder", e)
                }
            }
            
            encoder?.let {
                try {
                    // Try to stop, but it might already be stopped/released
                    try {
                        it.stop()
                        Log.d(TAG, "Conversion encoder stopped")
                    } catch (e: IllegalStateException) {
                        Log.d(TAG, "Encoder already stopped - this is expected")
                    }
                    
                    it.release()
                    Log.d(TAG, "Conversion encoder released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing conversion encoder", e)
                }
            }
            
            muxer?.let {
                try {
                    // Try to stop, but it might already be stopped
                    try {
                        it.stop()
                        Log.d(TAG, "Conversion muxer stopped in finally block")
                    } catch (e: IllegalStateException) {
                        Log.d(TAG, "Muxer already stopped - this is expected")
                    }
                    
                    it.release()
                    Log.d(TAG, "Conversion muxer released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing conversion muxer", e)
                }
            }
            
            try {
                extractor.release()
                Log.d(TAG, "Conversion extractor released")
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing conversion extractor", e)
            }
            
            // Verify file was created and is valid
            val outputFile = File(outputPath)
            if (outputFile.exists()) {
                val fileSize = outputFile.length()
                Log.d(TAG, "Converted file created successfully: $outputPath (size: $fileSize bytes)")
                
                // Basic validation - M4A files should have minimum size and start with proper headers
                if (fileSize < 100) {
                    Log.w(TAG, "WARNING: Output file is very small ($fileSize bytes) - may be invalid")
                } else {
                    Log.d(TAG, "File size looks reasonable for M4A format")
                }
            } else {
                Log.e(TAG, "ERROR: Converted file was not created: $outputPath")
                throw IOException("Conversion output file was not created: $outputPath")
            }
        }
    }

    private suspend fun processAudioData(
        extractor: MediaExtractor,
        decoder: MediaCodec,
        encoder: MediaCodec,
        muxer: MediaMuxer,
        inputFormat: MediaFormat,
        outputPath: String,
        bitRate: Int,
        sampleRate: Int
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        val decoderBufferInfo = MediaCodec.BufferInfo()
        val encoderBufferInfo = MediaCodec.BufferInfo()

        var decoderDone = false
        var encoderDone = false
        var encoderEOSSignaled = false
        var muxerStarted = false
        var audioTrackIndex = -1

        val inputDurationUs = inputFormat.getLong(MediaFormat.KEY_DURATION)
        var processedDurationUs = 0L
        
        // Timeout mechanism
        val startTime = System.currentTimeMillis()
        val maxProcessingTimeMs = 120000 // 2 minutes maximum
        var loopCounter = 0
        var lastProgressTime = System.currentTimeMillis()
        var noOutputCounter = 0

        Log.d(TAG, "Starting audio processing loop with input duration: ${inputDurationUs / 1000}ms")

        while (!encoderDone) {
            loopCounter++
            val currentTime = System.currentTimeMillis()
            
            // Check for timeout
            if (currentTime - startTime > maxProcessingTimeMs) {
                Log.w(TAG, "Processing timeout reached after ${(currentTime - startTime) / 1000}s - forcing completion")
                break
            }
            
            // Log progress periodically
            if (currentTime - lastProgressTime > 3000) {
                Log.d(TAG, "Loop $loopCounter: decoder done: $decoderDone, encoder done: $encoderDone, EOS signaled: $encoderEOSSignaled")
                lastProgressTime = currentTime
            }

            var hasActivity = false

            // 1. Feed input to decoder (only if not done)
            if (!decoderDone) {
                val inputBufferIndex = decoder.dequeueInputBuffer(1000L) // 1ms timeout
                if (inputBufferIndex >= 0) {
                    hasActivity = true
                    val inputBuffer = decoder.getInputBuffer(inputBufferIndex)
                    if (inputBuffer != null) {
                        inputBuffer.clear()
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        
                        if (sampleSize < 0) {
                            Log.d(TAG, "End of input reached - signaling decoder EOS")
                            decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            decoderDone = true
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                            
                            // Update progress
                            processedDurationUs = presentationTimeUs
                            val progress = if (inputDurationUs > 0) {
                                (processedDurationUs.toDouble() / inputDurationUs.toDouble()).coerceIn(0.0, 0.95)
                            } else 0.0
                            
                            Handler(Looper.getMainLooper()).post {
                                progressSink?.success(mapOf("operation" to "convert", "progress" to progress))
                            }
                        }
                    }
                }
            }

            // 2. Get output from decoder and feed to encoder
            val decoderOutputIndex = decoder.dequeueOutputBuffer(decoderBufferInfo, 1000L)
            when (decoderOutputIndex) {
                MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    hasActivity = true
                    val newFormat = decoder.outputFormat
                    Log.d(TAG, "Decoder output format changed: $newFormat")
                    // Note: We continue using our pre-configured encoder format
                }
                MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    // No output available yet
                }
                else -> {
                    if (decoderOutputIndex >= 0) {
                        hasActivity = true
                        val decoderOutputBuffer = decoder.getOutputBuffer(decoderOutputIndex)
                        
                        if (decoderBufferInfo.size > 0 && decoderOutputBuffer != null) {
                            // CRITICAL FIX: Retry encoder input buffer with longer timeout and blocking wait
                            var encoderInputIndex = -1
                            var retryCount = 0
                            val maxRetries = 10
                            
                            // Keep trying to get encoder input buffer - don't lose audio data!
                            while (encoderInputIndex < 0 && retryCount < maxRetries) {
                                encoderInputIndex = encoder.dequeueInputBuffer(5000L) // 5 second timeout
                                if (encoderInputIndex < 0) {
                                    retryCount++
                                    Log.w(TAG, "Encoder input buffer unavailable, retry $retryCount/$maxRetries")
                                    // Flush encoder output buffers to make space
                                    val tempOutputIndex = encoder.dequeueOutputBuffer(encoderBufferInfo, 0)
                                    if (tempOutputIndex >= 0) {
                                        encoder.releaseOutputBuffer(tempOutputIndex, false)
                                        Log.d(TAG, "Released encoder output buffer to make space")
                                    }
                                    Thread.sleep(10) // Brief pause before retry
                                }
                            }
                            
                            if (encoderInputIndex >= 0) {
                                val encoderInputBuffer = encoder.getInputBuffer(encoderInputIndex)
                                if (encoderInputBuffer != null) {
                                    encoderInputBuffer.clear()
                                    
                                    // Copy PCM data safely from decoder to encoder
                                    val dataSize = minOf(decoderBufferInfo.size, encoderInputBuffer.remaining())
                                    if (dataSize > 0) {
                                        decoderOutputBuffer.position(decoderBufferInfo.offset)
                                        decoderOutputBuffer.limit(decoderBufferInfo.offset + dataSize)
                                        encoderInputBuffer.put(decoderOutputBuffer)
                                    }
                                    
                                    encoder.queueInputBuffer(
                                        encoderInputIndex,
                                        0,
                                        dataSize,
                                        decoderBufferInfo.presentationTimeUs,
                                        decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv()
                                    )
                                    
                                    Log.v(TAG, "Successfully queued ${dataSize} bytes to encoder")
                                }
                            } else {
                                Log.e(TAG, "CRITICAL: Failed to get encoder input buffer after $maxRetries retries - AUDIO DATA LOST!")
                                // This should not happen with the retry logic, but if it does, we have a serious problem
                            }
                        }
                        
                        decoder.releaseOutputBuffer(decoderOutputIndex, false)
                        
                        // Check if decoder reached EOS
                        if (decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            Log.d(TAG, "Decoder EOS flag detected")
                            if (!encoderEOSSignaled) {
                                // Signal EOS to encoder
                                val encoderInputIndex = encoder.dequeueInputBuffer(5000L) // Wait up to 5s
                                if (encoderInputIndex >= 0) {
                                    encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    encoderEOSSignaled = true
                                    Log.d(TAG, "EOS signal sent to encoder")
                                } else {
                                    Log.w(TAG, "Could not signal EOS to encoder - will retry")
                                }
                            }
                        }
                    }
                }
            }

            // 3. If decoder is done but we haven't signaled EOS to encoder yet, try again
            if (decoderDone && !encoderEOSSignaled) {
                val encoderInputIndex = encoder.dequeueInputBuffer(1000L)
                if (encoderInputIndex >= 0) {
                    encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                    encoderEOSSignaled = true
                    hasActivity = true
                    Log.d(TAG, "Late EOS signal sent to encoder")
                }
            }

            // 4. Get output from encoder - CRITICAL: Process ALL available output buffers
            var processedEncoderOutput = false
            do {
                val encoderOutputIndex = encoder.dequeueOutputBuffer(encoderBufferInfo, 1000L)
                processedEncoderOutput = false
                
                when (encoderOutputIndex) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        hasActivity = true
                        processedEncoderOutput = true
                        if (!muxerStarted) {
                            val outputFormat = encoder.outputFormat
                            Log.d(TAG, "Encoder output format changed - starting muxer")
                            Log.d(TAG, "Encoder output format: $outputFormat")
                            
                            // Validate the output format before adding to muxer
                            if (!outputFormat.containsKey(MediaFormat.KEY_MIME)) {
                                Log.e(TAG, "ERROR: Encoder output format missing MIME type")
                                throw IOException("Invalid encoder output format - missing MIME type")
                            }
                            
                            val outputMime = outputFormat.getString(MediaFormat.KEY_MIME)
                            Log.d(TAG, "Adding track to muxer with MIME: $outputMime")
                            
                            audioTrackIndex = muxer.addTrack(outputFormat)
                            muxer.start()
                            muxerStarted = true
                            Log.d(TAG, "Muxer started successfully with track index: $audioTrackIndex")
                        }
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        // No output available - this is normal
                    }
                    else -> {
                        if (encoderOutputIndex >= 0) {
                            hasActivity = true
                            processedEncoderOutput = true
                            val encodedData = encoder.getOutputBuffer(encoderOutputIndex)
                            
                            if (encoderBufferInfo.size > 0 && muxerStarted && encodedData != null) {
                                muxer.writeSampleData(audioTrackIndex, encodedData, encoderBufferInfo)
                                Log.v(TAG, "Wrote ${encoderBufferInfo.size} bytes of encoded audio to muxer")
                            }
                            
                            encoder.releaseOutputBuffer(encoderOutputIndex, false)
                            
                            if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                Log.d(TAG, "Encoder EOS received - processing complete!")
                                encoderDone = true
                            }
                        }
                    }
                }
            } while (processedEncoderOutput && !encoderDone) // Keep processing all available output buffers

            // 5. Detect stuck situations
            if (!hasActivity) {
                noOutputCounter++
                if (noOutputCounter > 1000) { // No activity for 1000 iterations
                    if (encoderEOSSignaled) {
                        Log.w(TAG, "No activity for too long after EOS signaled - forcing completion")
                        break
                    } else if (decoderDone) {
                        Log.w(TAG, "No activity and decoder done but no EOS signaled - forcing EOS")
                        try {
                            val encoderInputIndex = encoder.dequeueInputBuffer(0L)
                            if (encoderInputIndex >= 0) {
                                encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                encoderEOSSignaled = true
                                Log.d(TAG, "Force-signaled EOS to encoder")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to force-signal EOS", e)
                            break
                        }
                    }
                    noOutputCounter = 0
                }
            } else {
                noOutputCounter = 0
            }

            // 6. Emergency brake for excessive iterations
            if (loopCounter > 50000) {
                Log.w(TAG, "Emergency brake: too many iterations ($loopCounter)")
                break
            }
        }

        Log.d(TAG, "Audio processing loop completed after $loopCounter iterations")

        // Stop muxer if it was started (but don't release - handled in finally block)
        try {
            if (muxerStarted) {
                muxer.stop()
                Log.d(TAG, "Muxer stopped successfully")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping muxer", e)
        }

        // Note: Codec cleanup (stop/release) is handled in the main convertAudio finally block
        // to avoid double-release issues
        
        val durationMs = (inputDurationUs / 1000).toInt()
        
        // Verify file was created and send final progress
        val outputFile = File(outputPath)
        if (outputFile.exists()) {
            val fileSize = outputFile.length()
            Log.d(TAG, "*** FILE SIZE DEBUG ***")
            Log.d(TAG, "Conversion completed successfully: $outputPath (size: $fileSize bytes = ${fileSize / 1024}KB = ${fileSize / (1024 * 1024)}MB)")
            Log.d(TAG, "Expected size for ${(inputDurationUs / 1000)}ms at ${bitRate/1000}kbps should be approximately ${(inputDurationUs / 1000) * (bitRate/1000) / 8}KB")
            Log.d(TAG, "*** END FILE SIZE DEBUG ***")
            
            // Send final 100% progress
            Handler(Looper.getMainLooper()).post {
                progressSink?.success(mapOf("operation" to "convert", "progress" to 1.0))
            }
        } else {
            Log.e(TAG, "ERROR: Converted file was not created: $outputPath")
            throw IOException("Output file was not created: $outputPath")
        }

        mapOf(
            "outputPath" to outputPath,
            "durationMs" to durationMs,
            "bitRate" to (bitRate / 1000), // Convert back to kbps for Dart consistency
            "sampleRate" to sampleRate
        )
    }
    
    // Waveform extraction implementation
    private fun handleExtractWaveform(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        val samplesPerSecond = call.argument<Int>("samplesPerSecond") ?: 100

        if (inputPath == null) {
            result.error("INVALID_ARGUMENTS", "Missing inputPath", null)
            return
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            result.error("FILE_NOT_FOUND", "Input file does not exist: $inputPath", null)
            return
        }

        CoroutineScope(Dispatchers.IO).launch {
            try {
                val waveformData = extractWaveformData(inputPath, samplesPerSecond)
                
                Handler(Looper.getMainLooper()).post {
                    result.success(waveformData)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error extracting waveform", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("EXTRACTION_FAILED", "Failed to extract waveform: ${e.message}", null)
                }
            }
        }
    }

    private fun handleIsFormatSupported(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        if (inputPath == null) {
            result.error("INVALID_ARGUMENTS", "Missing inputPath", null)
            return
        }
        
        // Basic format check - can be enhanced later
        val isSupported = inputPath.lowercase().let {
            it.endsWith(".mp3") || it.endsWith(".wav") || it.endsWith(".m4a") || it.endsWith(".aac")
        }
        result.success(isSupported)
    }    private fun handleGetAudioInfo(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        if (inputPath == null) {
            result.error("INVALID_ARGUMENTS", "Missing inputPath", null)
            return
        }

        GlobalScope.launch(Dispatchers.IO) {
            try {
                val audioInfo = getAudioFileInfo(inputPath)
                Handler(Looper.getMainLooper()).post {
                    result.success(audioInfo)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to get audio info", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("AUDIO_INFO_ERROR", "Failed to get audio info: ${e.message}", null)
                }
            }
        }
    }    private fun getAudioFileInfo(inputPath: String): Map<String, Any?> {
        val extractor = MediaExtractor()
        val file = File(inputPath)
        
        Log.d(TAG, "Getting audio info for: $inputPath")
        
        // First check if file exists and is readable
        if (!file.exists()) {
            Log.e(TAG, "File does not exist: $inputPath")
            return mapOf(
                "isValid" to false,
                "error" to "File does not exist",
                "details" to "The selected file could not be found at the specified path."
            )
        }
        
        if (!file.canRead()) {
            Log.e(TAG, "File is not readable: $inputPath")
            return mapOf(
                "isValid" to false,
                "error" to "File is not readable",
                "details" to "Permission denied or file is corrupted."
            )
        }
        
        val fileSize = file.length()
        if (fileSize == 0L) {
            Log.e(TAG, "File is empty: $inputPath")
            return mapOf(
                "isValid" to false,
                "error" to "File is empty",
                "details" to "The selected file has no content."
            )
        }
        
        Log.d(TAG, "File exists and readable, size: $fileSize bytes")
        
        try {
            extractor.setDataSource(inputPath)
            Log.d(TAG, "MediaExtractor setDataSource successful")
            
            val trackCount = extractor.trackCount
            Log.d(TAG, "Total tracks in file: $trackCount")
            
            if (trackCount == 0) {
                return mapOf(
                    "isValid" to false,
                    "error" to "No tracks found",
                    "details" to "The file contains no audio or video tracks. It may be corrupted or in an unsupported format."
                )
            }
            
            // Find audio track and log all tracks for debugging
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null
            val trackInfo = mutableListOf<String>()
            
            for (i in 0 until trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: "unknown"
                trackInfo.add("Track $i: $mime")
                Log.d(TAG, "Track $i: MIME = $mime")
                
                if (mime.startsWith("audio/") && audioTrackIndex == -1) {
                    audioTrackIndex = i
                    audioFormat = format
                    Log.d(TAG, "Found first audio track at index $i")
                }
            }
            
            if (audioTrackIndex == -1 || audioFormat == null) {
                val supportedFormats = "mp3, m4a, aac, wav, ogg"
                return mapOf(
                    "isValid" to false,
                    "error" to "No audio track found",
                    "details" to "The file contains no audio tracks. Supported formats: $supportedFormats. Found tracks: ${trackInfo.joinToString(", ")}",
                    "foundTracks" to trackInfo
                )
            }
            
            // Extract audio information
            val mime = audioFormat.getString(MediaFormat.KEY_MIME) ?: "unknown"
            Log.d(TAG, "Audio format MIME: $mime")            // Check if format is supported for trimming
            val supportedForTrimming = when {
                mime.equals("audio/mpeg", ignoreCase = true) -> true  // MP3
                mime.equals("audio/mp3", ignoreCase = true) -> true   // Alternative MP3 MIME
                mime.contains("mp3") -> true                          // Fallback for mp3
                mime.equals("audio/aac", ignoreCase = true) -> true   // AAC
                mime.equals("audio/mp4", ignoreCase = true) -> true   // M4A/MP4
                mime.equals("audio/mp4a-latm", ignoreCase = true) -> true // M4A variant
                mime.contains("aac") -> true                          // AAC fallback
                mime.contains("mp4") -> true                          // MP4 fallback
                mime.contains("m4a") -> true                          // M4A fallback
                mime.equals("audio/wav", ignoreCase = true) -> true   // WAV
                mime.equals("audio/wave", ignoreCase = true) -> true  // WAV variant
                mime.equals("audio/x-wav", ignoreCase = true) -> true // WAV variant
                mime.contains("wav") -> true                          // WAV fallback
                mime.equals("audio/ogg", ignoreCase = true) -> true   // OGG
                mime.equals("audio/vorbis", ignoreCase = true) -> true // OGG Vorbis
                mime.contains("ogg") -> true                          // OGG fallback
                else -> false
            }
            
            // Check if format supports lossless trimming (direct stream copy)
            val supportedForLosslessTrimming = when {
                mime.equals("audio/mp4", ignoreCase = true) -> true   // M4A/MP4
                mime.equals("audio/mp4a-latm", ignoreCase = true) -> true // M4A variant
                mime.equals("audio/aac", ignoreCase = true) -> true   // AAC in container
                mime.contains("mp4") -> true                          // MP4 fallback
                mime.contains("m4a") -> true                          // M4A fallback
                else -> false  // MP3, WAV, OGG require conversion for trimming
            }
            
            val durationUs = audioFormat.getLong(MediaFormat.KEY_DURATION)
            val durationMs = durationUs / 1000
            val sampleRate = audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channelCount = audioFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val bitRate = if (audioFormat.containsKey(MediaFormat.KEY_BIT_RATE)) {
                audioFormat.getInteger(MediaFormat.KEY_BIT_RATE)
            } else {
                // Estimate bit rate from file size and duration
                val durationSeconds = durationUs / 1_000_000.0
                if (durationSeconds > 0) {
                    ((fileSize * 8) / durationSeconds).toInt()
                } else {
                    0
                }
            }
              Log.d(TAG, "Audio info extracted - Duration: ${durationMs}ms, SampleRate: $sampleRate, Channels: $channelCount, BitRate: $bitRate")
            Log.d(TAG, "MIME type: $mime, Supported for trimming: $supportedForTrimming")
              // Add diagnostic information about format support
            val formatDiagnostics = when {
                mime.equals("audio/mpeg", ignoreCase = true) -> "MP3 format detected (audio/mpeg) - Requires conversion for trimming"
                mime.equals("audio/mp3", ignoreCase = true) -> "MP3 format detected (audio/mp3) - Requires conversion for trimming"
                mime.equals("audio/aac", ignoreCase = true) -> "AAC format detected - Supports lossless trimming"
                mime.equals("audio/mp4", ignoreCase = true) -> "M4A/MP4 format detected - Supports lossless trimming"
                mime.equals("audio/mp4a-latm", ignoreCase = true) -> "M4A format detected - Supports lossless trimming"
                mime.equals("audio/wav", ignoreCase = true) -> "WAV format detected - Requires conversion for trimming"
                mime.equals("audio/wave", ignoreCase = true) -> "WAV format detected - Requires conversion for trimming"
                mime.equals("audio/x-wav", ignoreCase = true) -> "WAV format detected - Requires conversion for trimming"
                mime.equals("audio/ogg", ignoreCase = true) -> "OGG format detected - Requires conversion for trimming"
                mime.equals("audio/vorbis", ignoreCase = true) -> "OGG Vorbis format detected - Requires conversion for trimming"
                else -> "Unknown/unsupported format: $mime - May require conversion"
            }

            return mapOf(
                "isValid" to true,
                "durationMs" to durationMs.toInt(),
                "sampleRate" to sampleRate,
                "channels" to channelCount,
                "bitRate" to bitRate,
                "mime" to mime,  // Changed from mimeType to mime to match UI
                "trackIndex" to audioTrackIndex,
                "fileSize" to fileSize,
                "supportedForTrimming" to supportedForTrimming,
                "supportedForConversion" to supportedForTrimming,
                "supportedForWaveform" to supportedForTrimming,
                "supportedForLosslessTrimming" to supportedForLosslessTrimming,
                "formatDiagnostics" to formatDiagnostics,
                "foundTracks" to trackInfo
            )
            
        } catch (e: IOException) {
            Log.e(TAG, "IOException while reading file", e)
            return mapOf(
                "isValid" to false,
                "error" to "Cannot read audio file",
                "details" to "The file may be corrupted, encrypted, or in an unsupported format. Error: ${e.message}"
            )
        } catch (e: IllegalArgumentException) {
            Log.e(TAG, "IllegalArgumentException while reading file", e)
            return mapOf(
                "isValid" to false,
                "error" to "Invalid audio format",
                "details" to "The file format is not supported by Android MediaExtractor. Error: ${e.message}"
            )
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected error while reading file", e)
            return mapOf(
                "isValid" to false,
                "error" to "Unexpected error",
                "details" to "An unexpected error occurred while analyzing the file: ${e.javaClass.simpleName} - ${e.message}"
            )
        } finally {
            try {
                extractor.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing MediaExtractor", e)
            }
        }
    }    private fun handleTrimAudio(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath") 
        val startTimeMs = call.argument<Int>("startTimeMs")
        val endTimeMs = call.argument<Int>("endTimeMs")
        val format = call.argument<String>("format")
        val bitRateKbps = call.argument<Int>("bitRate") ?: 128 // Received in kbps from Dart
        val sampleRate = call.argument<Int>("sampleRate") ?: SAMPLE_RATE

        // Convert bitRate from kbps to bps for MediaCodec
        val bitRate = bitRateKbps * 1000

        if (inputPath == null || outputPath == null || startTimeMs == null || endTimeMs == null || format == null) {
            result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
            return
        }

        if (startTimeMs >= endTimeMs) {
            result.error("INVALID_RANGE", "Start time must be less than end time", null)
            return
        }

        GlobalScope.launch(Dispatchers.IO) {
            try {
                Log.d(TAG, "Starting audio trimming: $inputPath -> $outputPath (${startTimeMs}ms to ${endTimeMs}ms, bitRate: ${bitRateKbps}kbps)")
                val trimmedData = trimAudio(inputPath, outputPath, startTimeMs, endTimeMs, format, bitRate, sampleRate)
                Handler(Looper.getMainLooper()).post {
                    result.success(trimmedData)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Audio trimming failed", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("TRIM_ERROR", "Audio trimming failed: ${e.javaClass.simpleName} - ${e.message}", null)
                }
            }
        }
    }    private suspend fun trimAudio(
        inputPath: String,
        outputPath: String,
        startTimeMs: Int,
        endTimeMs: Int,
        format: String,
        bitRate: Int,
        sampleRate: Int
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        
        Log.d(TAG, "Trimming audio file: $inputPath -> $outputPath (${startTimeMs}ms to ${endTimeMs}ms)")
        Log.d(TAG, "Format: $format, Bit rate: $bitRate kbps, Sample rate: $sampleRate Hz")
        
        // Use lossless copy if format is "copy"
        if (format.lowercase() == "copy") {
            return@withContext trimAudioLossless(inputPath, outputPath, startTimeMs, endTimeMs)
        }
        
        val startTimeUs = startTimeMs * 1000L
        val endTimeUs = endTimeMs * 1000L
        val durationUs = endTimeUs - startTimeUs
        
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        var encoder: MediaCodec? = null
        var muxer: MediaMuxer? = null

        try {
            // Setup extractor
            extractor.setDataSource(inputPath)
            
            // Find audio track
            var audioTrackIndex = -1
            var inputFormat: MediaFormat? = null
            
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    inputFormat = format
                    break
                }
            }
            
            if (audioTrackIndex == -1 || inputFormat == null) {
                throw IllegalArgumentException("No audio track found in input file")
            }
            
            extractor.selectTrack(audioTrackIndex)
            extractor.seekTo(startTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            
            // Setup decoder
            val inputMime = inputFormat.getString(MediaFormat.KEY_MIME)!!
            decoder = MediaCodec.createDecoderByType(inputMime)
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()
            
            // Setup encoder with proper AAC configuration
            val outputMime = "audio/mp4a-latm" // AAC for M4A format
            
            Log.d(TAG, "Creating AAC encoder for trim operation")
            encoder = MediaCodec.createEncoderByType(outputMime)
            
            // Get input format details for proper encoding setup
            val inputChannels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            val inputSampleRate = if (inputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                sampleRate
            }
            
            Log.d(TAG, "Trim - Input format - Channels: $inputChannels, Sample Rate: $inputSampleRate")
            
            // Use input format characteristics or defaults
            val outputChannels = if (inputChannels in 1..2) inputChannels else 2
            val outputSampleRate = if (inputSampleRate in 8000..48000) inputSampleRate else sampleRate
            
            // Calculate actual bitrate in bits per second (bps)
            val actualBitRate = bitRate * 1000
            
            Log.d(TAG, "Configuring encoder with bitRate: $actualBitRate bps ($bitRate kbps)")
            
            val encoderFormat = MediaFormat.createAudioFormat(outputMime, outputSampleRate, outputChannels).apply {
                setInteger(MediaFormat.KEY_BIT_RATE, actualBitRate)
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
                
                // Essential for proper AAC encoding
                setInteger(MediaFormat.KEY_CHANNEL_MASK, 
                    if (outputChannels == 1) AudioFormat.CHANNEL_OUT_MONO 
                    else AudioFormat.CHANNEL_OUT_STEREO)
            }
            
            Log.d(TAG, "Trim encoder config - Channels: $outputChannels, Sample Rate: $outputSampleRate, Bit Rate: $actualBitRate bps")
            
            encoder = MediaCodec.createEncoderByType(outputMime)
            encoder.configure(encoderFormat, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            encoder.start()
            
            // Setup muxer
            File(outputPath).parentFile?.mkdirs()
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            
            // Process audio data with time range
            processAudioDataWithTimeRange(extractor, decoder, encoder, muxer, inputFormat, outputPath, startTimeUs, endTimeUs)
            
            Log.d(TAG, "Audio trimming processing completed")
            
            mapOf(
                "outputPath" to outputPath,
                "durationMs" to (durationUs / 1000).toInt(),
                "bitRate" to bitRate, // Return the actual kbps value
                "sampleRate" to outputSampleRate
            )
            
        } finally {
            Log.d(TAG, "Cleaning up trim resources")
            
            decoder?.let { 
                try {
                    // Try to stop, but it might already be stopped/released
                    try {
                        it.stop()
                        Log.d(TAG, "Trim decoder stopped")
                    } catch (e: IllegalStateException) {
                        Log.d(TAG, "Trim decoder already stopped - this is expected")
                    }
                    
                    it.release()
                    Log.d(TAG, "Trim decoder released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing trim decoder", e)
                }
            }
            
            encoder?.let {
                try {
                    // Try to stop, but it might already be stopped/released
                    try {
                        it.stop()
                        Log.d(TAG, "Trim encoder stopped")
                    } catch (e: IllegalStateException) {
                        Log.d(TAG, "Trim encoder already stopped - this is expected")
                    }
                    
                    it.release()
                    Log.d(TAG, "Trim encoder released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing trim encoder", e)
                }
            }
            
            muxer?.let {
                try {
                    // Try to stop, but it might already be stopped
                    try {
                        it.stop()
                        Log.d(TAG, "Trim muxer stopped")
                    } catch (e: IllegalStateException) {
                        Log.d(TAG, "Trim muxer already stopped - this is expected")
                    }
                    
                    it.release()
                    Log.d(TAG, "Trim muxer released")
                } catch (e: Exception) {
                    Log.e(TAG, "Error releasing trim muxer", e)
                }
            }
            
            try {
                extractor.release()
                Log.d(TAG, "Trim extractor released")
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing trim MediaExtractor", e)
            }
            
            // Verify file was created
            val outputFile = File(outputPath)
            if (outputFile.exists()) {
                val fileSize = outputFile.length()
                Log.d(TAG, "Trimmed file created successfully: $outputPath (size: $fileSize bytes)")
            } else {
                Log.e(TAG, "ERROR: Trimmed file was not created: $outputPath")
                throw IOException("Trim output file was not created: $outputPath")
            }
        }
    }

    private fun processAudioDataWithTimeRange(
        extractor: MediaExtractor,
        decoder: MediaCodec,
        encoder: MediaCodec,
        muxer: MediaMuxer,
        inputFormat: MediaFormat,
        outputPath: String,
        startTimeUs: Long,
        endTimeUs: Long
    ) {
        val decoderBufferInfo = MediaCodec.BufferInfo()
        val encoderBufferInfo = MediaCodec.BufferInfo()
        
        var decoderDone = false
        var encoderDone = false
        var encoderEOSSignaled = false
        var muxerStarted = false
        var audioTrackIndex = -1
        
        val processingDurationUs = endTimeUs - startTimeUs
        var processedDurationUs = 0L
        
        // Timeout mechanism
        val startTime = System.currentTimeMillis()
        val maxProcessingTimeMs = 120000 // 2 minutes maximum
        var loopCounter = 0
        var lastProgressTime = System.currentTimeMillis()
        var noOutputCounter = 0
        
        Log.d(TAG, "Starting trim processing loop for range ${startTimeUs/1000}ms to ${endTimeUs/1000}ms")
        
        try {
            while (!encoderDone) {
                loopCounter++
                val currentTime = System.currentTimeMillis()
                
                // Check for timeout
                if (currentTime - startTime > maxProcessingTimeMs) {
                    Log.w(TAG, "Trim processing timeout - forcing completion")
                    break
                }
                
                // Log progress periodically
                if (currentTime - lastProgressTime > 3000) {
                    Log.d(TAG, "Trim loop $loopCounter: decoder done: $decoderDone, encoder done: $encoderDone")
                    lastProgressTime = currentTime
                }

                var hasActivity = false

                // 1. Feed input to decoder
                if (!decoderDone) {
                    val inputBufferIndex = decoder.dequeueInputBuffer(1000L)
                    if (inputBufferIndex >= 0) {
                        hasActivity = true
                        val inputBuffer = decoder.getInputBuffer(inputBufferIndex)
                        if (inputBuffer != null) {
                            inputBuffer.clear()
                            val sampleSize = extractor.readSampleData(inputBuffer, 0)
                            val presentationTimeUs = extractor.sampleTime
                            
                            if (sampleSize < 0 || presentationTimeUs >= endTimeUs) {
                                decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                decoderDone = true
                                Log.d(TAG, "Trim: End of range reached - signaling decoder EOS")
                            } else if (presentationTimeUs >= startTimeUs) {
                                // Adjust timestamp to start from 0
                                val adjustedTimeUs = presentationTimeUs - startTimeUs
                                decoder.queueInputBuffer(inputBufferIndex, 0, sampleSize, adjustedTimeUs, 0)
                                extractor.advance()
                                
                                // Update progress
                                processedDurationUs = adjustedTimeUs
                                val progress = if (processingDurationUs > 0) {
                                    (processedDurationUs.toDouble() / processingDurationUs.toDouble()).coerceIn(0.0, 0.95)
                                } else 0.0
                                
                                Handler(Looper.getMainLooper()).post {
                                    progressSink?.success(mapOf("operation" to "trim", "progress" to progress))
                                }
                            } else {
                                // Skip samples before start time
                                decoder.queueInputBuffer(inputBufferIndex, 0, 0, 0, 0)
                                extractor.advance()
                            }
                        }
                    }
                }

                // 2. Get output from decoder and feed to encoder
                val decoderOutputIndex = decoder.dequeueOutputBuffer(decoderBufferInfo, 1000L)
                if (decoderOutputIndex >= 0) {
                    hasActivity = true
                    val decoderOutputBuffer = decoder.getOutputBuffer(decoderOutputIndex)
                    
                    if (decoderBufferInfo.size > 0 && decoderOutputBuffer != null) {
                        // Try to feed to encoder
                        val encoderInputIndex = encoder.dequeueInputBuffer(1000L)
                        if (encoderInputIndex >= 0) {
                            val encoderInputBuffer = encoder.getInputBuffer(encoderInputIndex)
                            if (encoderInputBuffer != null) {
                                encoderInputBuffer.clear()
                                
                                // Copy data safely
                                val dataSize = minOf(decoderBufferInfo.size, encoderInputBuffer.remaining())
                                if (dataSize > 0) {
                                    decoderOutputBuffer.position(decoderBufferInfo.offset)
                                    decoderOutputBuffer.limit(decoderBufferInfo.offset + dataSize)
                                    encoderInputBuffer.put(decoderOutputBuffer)
                                }
                                
                                encoder.queueInputBuffer(
                                    encoderInputIndex,
                                    0,
                                    dataSize,
                                    decoderBufferInfo.presentationTimeUs,
                                    decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv()
                                )
                            }
                        }
                    }
                    
                    decoder.releaseOutputBuffer(decoderOutputIndex, false)
                    
                    // Check if decoder reached EOS
                    if (decoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        Log.d(TAG, "Trim: Decoder EOS flag detected")
                        if (!encoderEOSSignaled) {
                            val encoderInputIndex = encoder.dequeueInputBuffer(5000L)
                            if (encoderInputIndex >= 0) {
                                encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                encoderEOSSignaled = true
                                Log.d(TAG, "Trim: EOS signal sent to encoder")
                            }
                        }
                    }
                }

                // 3. If decoder is done but no EOS signaled yet
                if (decoderDone && !encoderEOSSignaled) {
                    val encoderInputIndex = encoder.dequeueInputBuffer(1000L)
                    if (encoderInputIndex >= 0) {
                        encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        encoderEOSSignaled = true
                        hasActivity = true
                        Log.d(TAG, "Trim: Late EOS signal sent to encoder")
                    }
                }

                // 4. Get output from encoder
                val encoderOutputIndex = encoder.dequeueOutputBuffer(encoderBufferInfo, 1000L)
                when (encoderOutputIndex) {
                    MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        hasActivity = true
                        if (!muxerStarted) {
                            Log.d(TAG, "Trim: Encoder output format changed - starting muxer")
                            audioTrackIndex = muxer.addTrack(encoder.outputFormat)
                            muxer.start()
                            muxerStarted = true
                        }
                    }
                    MediaCodec.INFO_TRY_AGAIN_LATER -> {
                        // No output available
                    }
                    else -> {
                        if (encoderOutputIndex >= 0) {
                            hasActivity = true
                            val encodedData = encoder.getOutputBuffer(encoderOutputIndex)
                            
                            if (encoderBufferInfo.size > 0 && muxerStarted && encodedData != null) {
                                muxer.writeSampleData(audioTrackIndex, encodedData, encoderBufferInfo)
                            }
                            
                            encoder.releaseOutputBuffer(encoderOutputIndex, false)
                            
                            if (encoderBufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                                Log.d(TAG, "Trim: Encoder EOS received - processing complete!")
                                encoderDone = true
                            }
                        }
                    }
                }

                // 5. Detect stuck situations
                if (!hasActivity) {
                    noOutputCounter++
                    if (noOutputCounter > 1000) {
                        if (encoderEOSSignaled) {
                            Log.w(TAG, "Trim: No activity after EOS - forcing completion")
                            break
                        } else if (decoderDone) {
                            Log.w(TAG, "Trim: No activity and decoder done - forcing EOS")
                            try {
                                val encoderInputIndex = encoder.dequeueInputBuffer(0L)
                                if (encoderInputIndex >= 0) {
                                    encoder.queueInputBuffer(encoderInputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                    encoderEOSSignaled = true
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to force EOS in trim", e)
                                break
                            }
                        }
                        noOutputCounter = 0
                    }
                } else {
                    noOutputCounter = 0
                }

                // 6. Emergency brake
                if (loopCounter > 30000) {
                    Log.w(TAG, "Trim: Emergency brake after $loopCounter iterations")
                    break
                }
            }
            
        } finally {
            // Cleanup is handled by caller
            Log.d(TAG, "Trim processing completed after $loopCounter iterations")
            
            // Send final progress
            Handler(Looper.getMainLooper()).post {
                progressSink?.success(mapOf("operation" to "trim", "progress" to 1.0))
            }
        }
    }

    /**
     * Lossless audio trimming that preserves the original format
     * Uses MediaExtractor and MediaMuxer to copy the stream directly without decode/encode
     */
    private suspend fun trimAudioLossless(
        inputPath: String,
        outputPath: String,
        startTimeMs: Int,
        endTimeMs: Int
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        
        Log.d(TAG, "Starting lossless audio trimming: $inputPath -> $outputPath (${startTimeMs}ms to ${endTimeMs}ms)")
        
        val startTimeUs = startTimeMs * 1000L
        val endTimeUs = endTimeMs * 1000L
        val durationUs = endTimeUs - startTimeUs
        
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var audioTrackIndex = -1
        var outputTrackIndex = -1
        var totalBytesProcessed = 0L
        
        try {
            // Setup extractor
            extractor.setDataSource(inputPath)
            Log.d(TAG, "Lossless trim: Input file has ${extractor.trackCount} tracks")
            
            // Find audio track and get its format
            var audioFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                Log.d(TAG, "Track $i: MIME = $mime")
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    audioFormat = format
                    Log.d(TAG, "Found audio track at index $i with format: $mime")
                    break
                }
            }
            
            if (audioTrackIndex == -1 || audioFormat == null) {
                throw IllegalArgumentException("No audio track found in input file")
            }
            
            // Get original file extension for output
            val inputFile = File(inputPath)
            val originalExtension = inputFile.extension.lowercase()
            
            // Determine output format based on original file
            val outputFormat = when (originalExtension) {
                "mp3" -> {
                    // MP3 files cannot be directly muxed - they need conversion
                    Log.w(TAG, "MP3 lossless trimming not directly supported by MediaMuxer. Using M4A container instead.")
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                }
                "m4a", "aac", "mp4" -> MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                "wav" -> {
                    Log.w(TAG, "WAV lossless trimming may not preserve original format. Using M4A container instead.")
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4 
                }
                "ogg" -> {
                    Log.w(TAG, "OGG lossless trimming may not preserve original format. Using M4A container instead.")
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                }
                else -> {
                    Log.w(TAG, "Unknown format $originalExtension, using M4A container")
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                }
            }
            
            // Setup muxer
            // Ensure output directory exists
            File(outputPath).parentFile?.mkdirs()
            
            muxer = MediaMuxer(outputPath, outputFormat)
            outputTrackIndex = muxer.addTrack(audioFormat)
            
            // Select the audio track and seek to start time
            extractor.selectTrack(audioTrackIndex)
            extractor.seekTo(startTimeUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            
            // Get the actual seek position (may be different from requested due to sync frames)
            val actualStartTimeUs = extractor.sampleTime
            Log.d(TAG, "Requested start: ${startTimeUs}μs, Actual start: ${actualStartTimeUs}μs")
            
            // Start muxer
            muxer.start()
            
            // Copy samples within the time range
            val bufferInfo = MediaCodec.BufferInfo()
            val buffer = ByteBuffer.allocate(1024 * 1024) // 1MB buffer
            var samplesProcessed = 0
            
            while (true) {
                val sampleTime = extractor.sampleTime
                
                // Check if we've reached the end time
                if (sampleTime < 0 || sampleTime >= endTimeUs) {
                    Log.d(TAG, "Reached end time or end of stream at ${sampleTime}μs")
                    break
                }
                
                // Read sample data
                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                
                if (sampleSize < 0) {
                    Log.d(TAG, "No more samples available")
                    break
                }
                
                // Only copy samples within our target range
                if (sampleTime >= startTimeUs) {
                    // Adjust timestamp to start from 0
                    val adjustedTimeUs = sampleTime - actualStartTimeUs
                    
                    bufferInfo.presentationTimeUs = adjustedTimeUs
                    bufferInfo.size = sampleSize
                    bufferInfo.offset = 0
                    bufferInfo.flags = extractor.sampleFlags
                    
                    // Write sample to output
                    buffer.rewind()
                    muxer.writeSampleData(outputTrackIndex, buffer, bufferInfo)
                    totalBytesProcessed += sampleSize
                    samplesProcessed++
                    
                    // Update progress
                    val progress = ((sampleTime - startTimeUs).toDouble() / durationUs.toDouble()).coerceIn(0.0, 1.0)
                    Handler(Looper.getMainLooper()).post {
                        progressSink?.success(mapOf("operation" to "trim", "progress" to progress))
                    }
                }
                
                // Advance to next sample
                if (!extractor.advance()) {
                    Log.d(TAG, "No more samples to advance")
                    break
                }
            }
            
            Log.d(TAG, "Lossless trim completed: $samplesProcessed samples, $totalBytesProcessed bytes")
            
            // Verify output file was created
            val outputFile = File(outputPath)
            if (!outputFile.exists()) {
                Log.e(TAG, "Lossless trimmed file was not created: $outputPath")
            } else {
                Log.d(TAG, "Lossless trimmed file created successfully: $outputPath (${outputFile.length()} bytes)")
            }
            
            // Get audio properties from original format
            val originalSampleRate = audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val originalBitRate = if (audioFormat.containsKey(MediaFormat.KEY_BIT_RATE)) {
                audioFormat.getInteger(MediaFormat.KEY_BIT_RATE)
            } else {
                // Estimate bitrate based on file size and duration
                val fileSizeBytes = File(inputPath).length()
                val durationSeconds = (extractor.getTrackFormat(audioTrackIndex).getLong(MediaFormat.KEY_DURATION) / 1_000_000.0)
                ((fileSizeBytes * 8) / durationSeconds).toInt()
            }
            
            mapOf(
                "outputPath" to outputPath,
                "durationMs" to (durationUs / 1000).toInt(),
                "bitRate" to originalBitRate,
                "sampleRate" to originalSampleRate
            )
            
        } finally {
            try {
                muxer?.stop()
                muxer?.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing MediaMuxer", e)
            }
            
            try {
                extractor.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing MediaExtractor", e)
            }
        }
    }

    private fun extractWaveformData(inputPath: String, samplesPerSecond: Int): Map<String, Any> {
        val extractor = MediaExtractor()
        var decoder: MediaCodec? = null
        val amplitudes = mutableListOf<Double>()
        
        try {
            extractor.setDataSource(inputPath)
            
            // Find audio track
            var audioTrackIndex = -1
            var inputFormat: MediaFormat? = null
            
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    inputFormat = format
                    break
                }
            }
            
            if (audioTrackIndex == -1 || inputFormat == null) {
                throw IllegalArgumentException("No audio track found in input file")
            }
            
            // Extract audio information
            val durationUs = inputFormat.getLong(MediaFormat.KEY_DURATION)
            val durationMs = (durationUs / 1000).toInt()
            val sampleRate = inputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            val channels = inputFormat.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            
            // Select and configure decoder
            extractor.selectTrack(audioTrackIndex)
            val mime = inputFormat.getString(MediaFormat.KEY_MIME)!!
            decoder = MediaCodec.createDecoderByType(mime)
            
            // Configure output format for raw PCM
            val outputFormat = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_RAW, sampleRate, channels)
            outputFormat.setInteger(MediaFormat.KEY_PCM_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
            
            decoder.configure(inputFormat, null, null, 0)
            decoder.start()
            
            val bufferInfo = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            
            // Calculate sample interval
            val totalSamples = (durationMs * samplesPerSecond) / 1000
            val samplesPerBatch = max(1, sampleRate / samplesPerSecond)
            var sampleCount = 0
            var currentBatchSamples = 0
            var batchMaxAmplitude = 0.0
            
            while (!outputDone) {
                // Feed input to decoder
                if (!inputDone) {
                    val inputIndex = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (inputIndex >= 0) {
                        val inputBuffer = decoder.getInputBuffer(inputIndex)!!
                        val sampleSize = extractor.readSampleData(inputBuffer, 0)
                        
                        if (sampleSize < 0) {
                            decoder.queueInputBuffer(inputIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            val presentationTimeUs = extractor.sampleTime
                            decoder.queueInputBuffer(inputIndex, 0, sampleSize, presentationTimeUs, 0)
                            extractor.advance()
                              // Report progress
                            val progress = (presentationTimeUs.toDouble() / durationUs).coerceIn(0.0, 1.0)
                            Handler(Looper.getMainLooper()).post {
                                progressSink?.success(mapOf("operation" to "extract", "progress" to progress))
                            }
                        }
                    }
                }
                
                // Get output from decoder
                val outputIndex = decoder.dequeueOutputBuffer(bufferInfo, TIMEOUT_US)
                when {
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        // Output format changed
                    }
                    outputIndex >= 0 -> {
                        val outputBuffer = decoder.getOutputBuffer(outputIndex)!!
                        
                        if (bufferInfo.size > 0) {
                            // Process PCM data to extract amplitudes
                            val pcmData = ByteArray(bufferInfo.size)
                            outputBuffer.get(pcmData)
                            
                            // Convert bytes to 16-bit samples and calculate amplitude
                            for (i in 0 until pcmData.size step 2) {
                                if (i + 1 < pcmData.size) {
                                    val sample = ((pcmData[i + 1].toInt() shl 8) or (pcmData[i].toInt() and 0xFF)).toShort()
                                    val amplitude = abs(sample.toDouble()) / 32768.0 // Normalize to 0.0-1.0
                                    
                                    batchMaxAmplitude = max(batchMaxAmplitude, amplitude)
                                    currentBatchSamples++
                                    
                                    if (currentBatchSamples >= samplesPerBatch) {
                                        amplitudes.add(batchMaxAmplitude)
                                        batchMaxAmplitude = 0.0
                                        currentBatchSamples = 0
                                        sampleCount++
                                    }
                                }
                            }
                        }
                        
                        decoder.releaseOutputBuffer(outputIndex, false)
                        
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true
                        }
                    }
                }
            }
            
            // Add final batch if needed
            if (currentBatchSamples > 0) {
                amplitudes.add(batchMaxAmplitude)
            }
            
            return mapOf(
                "amplitudes" to amplitudes,
                "sampleRate" to sampleRate,
                "durationMs" to durationMs,
                "channels" to channels
            )
            
        } finally {
            try {
                decoder?.stop()
                decoder?.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing decoder", e)
            }
            
            try {
                extractor.release()
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing extractor", e)
            }
        }
    }

    /**
     * Lossless audio conversion that preserves the original format
     * Uses MediaExtractor and MediaMuxer to copy the stream directly without decode/encode
     */
    private suspend fun convertAudioLossless(
        inputPath: String,
        outputPath: String
    ): Map<String, Any?> = withContext(Dispatchers.IO) {
        
        Log.d(TAG, "Starting lossless audio conversion: $inputPath -> $outputPath")
        
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        var audioTrackIndex = -1
        var outputTrackIndex = -1
        var totalBytesProcessed = 0L
        
        try {
            // Setup extractor
            extractor.setDataSource(inputPath)
            Log.d(TAG, "Lossless: Input file has ${extractor.trackCount} tracks")
            
            // Find audio track and get its format
            var audioFormat: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                Log.d(TAG, "Track $i: MIME = $mime")
                if (mime?.startsWith("audio/") == true) {
                    audioTrackIndex = i
                    audioFormat = format
                    Log.d(TAG, "Found audio track at index $i with format: $mime")
                    break
                }
            }
            
            if (audioTrackIndex == -1 || audioFormat == null) {
                throw IllegalArgumentException("No audio track found in input file")
            }
            
            // Setup muxer with M4A format (most compatible)
            File(outputPath).parentFile?.mkdirs()
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            outputTrackIndex = muxer.addTrack(audioFormat)
            
            // Select the audio track
            extractor.selectTrack(audioTrackIndex)
            muxer.start()
            
            Log.d(TAG, "Starting lossless copy operation")
            
            // Copy data
            val buffer = ByteBuffer.allocate(1024 * 1024) // 1MB buffer
            val bufferInfo = MediaCodec.BufferInfo()
            
            var sampleCount = 0
            while (true) {
                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                
                if (sampleSize < 0) {
                    Log.d(TAG, "Lossless copy completed. Processed $sampleCount samples, $totalBytesProcessed bytes")
                    break
                }
                
                bufferInfo.presentationTimeUs = extractor.sampleTime
                bufferInfo.size = sampleSize
                bufferInfo.offset = 0
                bufferInfo.flags = extractor.sampleFlags
                
                muxer.writeSampleData(outputTrackIndex, buffer, bufferInfo)
                totalBytesProcessed += sampleSize
                sampleCount++
                
                // Progress reporting
                if (sampleCount % 1000 == 0) {
                    Log.d(TAG, "Lossless copy progress: $sampleCount samples, $totalBytesProcessed bytes")
                }
                
                extractor.advance()
            }
            
            // Get duration from input format
            val durationUs = if (audioFormat.containsKey(MediaFormat.KEY_DURATION)) {
                audioFormat.getLong(MediaFormat.KEY_DURATION)
            } else {
                0L
            }
            
            val durationMs = (durationUs / 1000).toInt()
            
            // Get bitrate (estimated if not available)
            val bitRate = if (audioFormat.containsKey(MediaFormat.KEY_BIT_RATE)) {
                audioFormat.getInteger(MediaFormat.KEY_BIT_RATE) / 1000 // Convert to kbps
            } else {
                128 // Default estimate
            }
            
            // Get sample rate
            val sampleRate = if (audioFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                audioFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                44100 // Default
            }
            
            mapOf(
                "outputPath" to outputPath,
                "durationMs" to durationMs,
                "bitRate" to bitRate,
                "sampleRate" to sampleRate
            )
            
        } finally {
            try {
                muxer?.stop()
                muxer?.release()
                Log.d(TAG, "Lossless muxer released")
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing lossless muxer", e)
            }
            
            try {
                extractor.release()
                Log.d(TAG, "Lossless extractor released")
            } catch (e: Exception) {
                Log.w(TAG, "Error releasing lossless extractor", e)
            }
            
            // Verify file was created
            val outputFile = File(outputPath)
            if (outputFile.exists()) {
                val fileSize = outputFile.length()
                Log.d(TAG, "Lossless converted file created: $outputPath (size: $fileSize bytes)")
            } else {
                Log.e(TAG, "ERROR: Lossless converted file was not created: $outputPath")
                throw IOException("Lossless conversion output file was not created")
            }
        }
    }
}
