package com.dejavu.player.dejavu_music_player

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Bundle
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioService
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.dejavu.player/audio_utils"
    private val SYNC_CHANNEL = "com.dejavu.player/sync_service"
    private val executor = Executors.newFixedThreadPool(2)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startService(Intent(this, CloseAppOnTaskRemovedService::class.java))
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        if (isFinishing) {
            try {
                stopService(Intent(this, AudioService::class.java))
            } catch (_: Exception) {}
            try {
                stopService(Intent(this, DejaVuSyncService::class.java))
            } catch (_: Exception) {}
        }
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "stripVideoFromMp4" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    val startOffsetMs = (call.argument<Number>("startOffsetMs"))?.toLong() ?: 0L
                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val success = extractAudioTrack(inputPath, outputPath, startOffsetMs)
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("EXTRACTION_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "cropThumbnailSquare" -> {
                    val inputPath = call.argument<String>("inputPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "inputPath and outputPath are required", null)
                        return@setMethodCallHandler
                    }
                    executor.execute {
                        try {
                            val success = cropImageSquare(inputPath, outputPath)
                            runOnUiThread {
                                result.success(success)
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("CROP_ERROR", e.message, null)
                            }
                        }
                    }
                }
                "scanFile" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        // MediaScannerConnection only works on shared/external storage (e.g. /storage/emulated/0).
                        // Private internal app directories (/data/user/0/... or filesDir) cannot be scanned by
                        // the system MediaScanner service and will throw java.nio.file.NoSuchFileException.
                        val isInternal = path.startsWith("/data/") ||
                                path.startsWith(filesDir.path) ||
                                path.startsWith(cacheDir.path)
                        if (!isInternal) {
                            MediaScannerConnection.scanFile(this, arrayOf(path), null, null)
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startSyncService" -> {
                    val title = call.argument<String>("title") ?: "DejaVu Sync"
                    val message = call.argument<String>("message") ?: "Synchronizing playlist..."
                    val progress = call.argument<Int>("progress") ?: 0
                    val total = call.argument<Int>("total") ?: 0
                    val indeterminate = call.argument<Boolean>("indeterminate") ?: (total <= 0)

                    val intent = Intent(this, DejaVuSyncService::class.java).apply {
                        action = DejaVuSyncService.ACTION_START
                        putExtra(DejaVuSyncService.EXTRA_TITLE, title)
                        putExtra(DejaVuSyncService.EXTRA_MESSAGE, message)
                        putExtra(DejaVuSyncService.EXTRA_PROGRESS, progress)
                        putExtra(DejaVuSyncService.EXTRA_TOTAL, total)
                        putExtra(DejaVuSyncService.EXTRA_INDETERMINATE, indeterminate)
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "updateSyncProgress" -> {
                    val title = call.argument<String>("title") ?: "DejaVu Sync"
                    val message = call.argument<String>("message") ?: "Synchronizing playlist..."
                    val progress = call.argument<Int>("progress") ?: 0
                    val total = call.argument<Int>("total") ?: 0
                    val indeterminate = call.argument<Boolean>("indeterminate") ?: (total <= 0)

                    val intent = Intent(this, DejaVuSyncService::class.java).apply {
                        action = DejaVuSyncService.ACTION_UPDATE
                        putExtra(DejaVuSyncService.EXTRA_TITLE, title)
                        putExtra(DejaVuSyncService.EXTRA_MESSAGE, message)
                        putExtra(DejaVuSyncService.EXTRA_PROGRESS, progress)
                        putExtra(DejaVuSyncService.EXTRA_TOTAL, total)
                        putExtra(DejaVuSyncService.EXTRA_INDETERMINATE, indeterminate)
                    }
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                    } catch (_: Exception) {}
                    result.success(true)
                }
                "stopSyncService" -> {
                    try {
                        val intent = Intent(this, DejaVuSyncService::class.java).apply {
                            action = DejaVuSyncService.ACTION_STOP
                        }
                        startService(intent)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun cropImageSquare(inputPath: String, outputPath: String): Boolean {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) return false

        val bitmap = BitmapFactory.decodeFile(inputPath) ?: return false
        val size = minOf(bitmap.width, bitmap.height)
        val x = (bitmap.width - size) / 2
        val y = (bitmap.height - size) / 2

        val cropped = Bitmap.createBitmap(bitmap, x, y, size, size)
        val outFile = File(outputPath)
        FileOutputStream(outFile).use { out ->
            cropped.compress(Bitmap.CompressFormat.JPEG, 90, out)
        }

        if (cropped != bitmap) {
            cropped.recycle()
        }
        bitmap.recycle()
        return true
    }

    private fun extractAudioTrack(inputPath: String, outputPath: String, startOffsetMs: Long = 0L): Boolean {
        val inputFile = File(inputPath)
        if (!inputFile.exists()) return false

        val tempOut = File("$outputPath.tmp")
        if (tempOut.exists()) tempOut.delete()

        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(inputPath)
            var audioTrackIndex = -1
            var audioFormat: MediaFormat? = null

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("audio/")) {
                    audioTrackIndex = i
                    audioFormat = format
                    break
                }
            }

            if (audioTrackIndex == -1 || audioFormat == null) {
                return false
            }

            var hasVideo = false
            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
                if (mime.startsWith("video/")) {
                    hasVideo = true
                    break
                }
            }

            val audioMime = audioFormat.getString(MediaFormat.KEY_MIME) ?: ""
            val isAac = audioMime.contains("mp4a", ignoreCase = true) || audioMime.contains("aac", ignoreCase = true)

            val startUs = startOffsetMs * 1000L
            if (!hasVideo && startUs <= 0) {
                // Already pure audio and no intro to strip
                return true
            }

            // MediaMuxer MPEG_4 requires AAC audio; for Opus/WebM skip muxing to preserve original file
            if (!isAac && !hasVideo) {
                return true
            }

            muxer = MediaMuxer(tempOut.absolutePath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val muxerAudioTrack = muxer.addTrack(audioFormat)
            muxer.start()

            extractor.selectTrack(audioTrackIndex)
            if (startUs > 0) {
                extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)
            }

            val bufferSize = 256 * 1024
            val buffer = ByteBuffer.allocateDirect(bufferSize)
            val bufferInfo = MediaCodec.BufferInfo()
            var baseTimeUs: Long = -1L

            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(buffer, 0)
                if (bufferInfo.size < 0) {
                    break
                }
                val sampleTime = extractor.sampleTime
                if (baseTimeUs == -1L) {
                    baseTimeUs = sampleTime
                }
                bufferInfo.presentationTimeUs = Math.max(0L, sampleTime - baseTimeUs)
                bufferInfo.flags = extractor.sampleFlags
                muxer.writeSampleData(muxerAudioTrack, buffer, bufferInfo)
                extractor.advance()
            }

            muxer.stop()
            muxer.release()
            muxer = null

            extractor.release()

            val finalTarget = File(outputPath)
            if (finalTarget.exists()) finalTarget.delete()
            return tempOut.renameTo(finalTarget)
        } catch (e: Exception) {
            tempOut.delete()
            return false
        } finally {
            try { muxer?.release() } catch (_: Exception) {}
            try { extractor.release() } catch (_: Exception) {}
        }
    }
}
