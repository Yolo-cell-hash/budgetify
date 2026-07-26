package com.jayrk.budget_tracker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import java.io.File
import java.nio.ByteBuffer

/**
 * Encodes a list of PNG frames into a looping H.264/MP4 with MediaCodec.
 *
 * Why video at all: the Wrapped "animated share" used to be a GIF, and a GIF
 * is a dead end on both targets. Instagram never animates a shared GIF — it
 * flattens it to a still — and a GIF's 256-colour palette cannot hold the
 * card's midnight-to-gold gradients, so WhatsApp re-encoded an already
 * dithered, low-resolution source and the result looked blurry. H.264 is what
 * both platforms actually animate, in full colour, at full resolution.
 *
 * MediaCodec/MediaMuxer are platform APIs — no new dependency, nothing added
 * to the APK, and no network, so the app's offline guarantee is untouched.
 */
object WrappedVideoEncoder {

    private const val MIME = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val TIMEOUT_US = 10_000L

    /** Whether this device has an H.264 encoder we can drive. */
    fun isSupported(): Boolean = try {
        val codec = MediaCodec.createEncoderByType(MIME)
        codec.release()
        true
    } catch (e: Exception) {
        false
    }

    /**
     * Encode [framePaths] (PNG files, all [width]×[height]) to [outPath].
     *
     * The frame list spans exactly one period of the card's motion, so it is
     * fed [loops] times back to back and the result plays as a seamless cycle.
     * Blocking and CPU-heavy — call it off the main thread.
     */
    fun encode(
        framePaths: List<String>,
        outPath: String,
        width: Int,
        height: Int,
        fps: Int,
        loops: Int,
        bitRate: Int,
    ) {
        require(framePaths.isNotEmpty()) { "no frames to encode" }
        // H.264 needs even dimensions; the caller sizes for this, but a stray
        // odd pixel would otherwise fail deep inside the codec.
        require(width % 2 == 0 && height % 2 == 0) { "dimensions must be even" }

        val codec = MediaCodec.createEncoderByType(MIME)

        var muxer: MediaMuxer? = null
        var trackIndex = -1
        var muxing = false
        val bufferInfo = MediaCodec.BufferInfo()
        val pixels = IntArray(width * height)

        try {
            configure(codec, width, height, fps, bitRate)
            codec.start()
            muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

            val totalFrames = framePaths.size * loops
            var frameIndex = 0

            while (frameIndex < totalFrames) {
                val inputIndex = codec.dequeueInputBuffer(TIMEOUT_US)
                if (inputIndex >= 0) {
                    // Re-decoded per loop rather than cached: one 1080×1920
                    // frame is ~8 MB of ARGB, so holding the whole sequence in
                    // memory to save a decode would risk an OOM on low-RAM
                    // phones for a few hundred milliseconds of CPU.
                    val path = framePaths[frameIndex % framePaths.size]
                    val bitmap = BitmapFactory.decodeFile(path)
                        ?: throw IllegalStateException("could not decode frame $path")
                    try {
                        if (bitmap.width != width || bitmap.height != height) {
                            throw IllegalStateException(
                                "frame ${bitmap.width}x${bitmap.height} != ${width}x$height"
                            )
                        }
                        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
                    } finally {
                        bitmap.recycle()
                    }

                    val size = writeFrame(codec, inputIndex, pixels, width, height)
                    val ptsUs = frameIndex * 1_000_000L / fps
                    codec.queueInputBuffer(inputIndex, 0, size, ptsUs, 0)
                    frameIndex++
                }

                val drained = drain(codec, muxer, bufferInfo, trackIndex, muxing)
                trackIndex = drained.first
                muxing = drained.second
            }

            // Flush the encoder: signal end of stream, then drain until it says
            // it is done, or the tail of the clip is silently truncated.
            val inputIndex = codec.dequeueInputBuffer(-1L)
            codec.queueInputBuffer(
                inputIndex, 0, 0, totalFrames * 1_000_000L / fps,
                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
            )
            while (true) {
                val drained = drain(codec, muxer, bufferInfo, trackIndex, muxing)
                trackIndex = drained.first
                muxing = drained.second
                if (drained.third) break
            }
        } finally {
            try {
                codec.stop()
            } catch (e: Exception) {
                // Already stopped or never started — nothing to salvage.
            }
            codec.release()
            if (muxer != null) {
                try {
                    if (muxing) muxer.stop()
                } catch (e: Exception) {
                    // Leave the partial file for the caller to discard.
                }
                muxer.release()
            }
        }

        val out = File(outPath)
        if (!out.exists() || out.length() == 0L) {
            throw IllegalStateException("encoder produced no data")
        }
    }

    /**
     * Configure the encoder, declaring the colour space we convert into so
     * players don't guess and shift the card's gold.
     *
     * The colour keys exist from API 24 (our floor) but are advisory, and a
     * strict vendor codec can reject a format carrying them. Rather than lose
     * video entirely on such a device — the caller would silently drop to the
     * GIF — retry once with the plain format.
     */
    private fun configure(
        codec: MediaCodec,
        width: Int,
        height: Int,
        fps: Int,
        bitRate: Int,
    ) {
        fun format(withColorSpace: Boolean) =
            MediaFormat.createVideoFormat(MIME, width, height).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
                )
                setInteger(MediaFormat.KEY_BIT_RATE, bitRate)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                // Every frame a keyframe would bloat the file; one per second
                // keeps seeking snappy for platforms that scrub the clip.
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                if (withColorSpace && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    setInteger(MediaFormat.KEY_COLOR_STANDARD,
                        MediaFormat.COLOR_STANDARD_BT709)
                    setInteger(MediaFormat.KEY_COLOR_RANGE,
                        MediaFormat.COLOR_RANGE_LIMITED)
                    setInteger(MediaFormat.KEY_COLOR_TRANSFER,
                        MediaFormat.COLOR_TRANSFER_SDR_VIDEO)
                }
            }

        try {
            codec.configure(
                format(true), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        } catch (e: Exception) {
            codec.reset()
            codec.configure(
                format(false), null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
        }
    }

    /**
     * Pull whatever the encoder has ready into the muxer. Returns the (possibly
     * newly created) track index, whether the muxer has been started, and
     * whether end-of-stream was seen.
     */
    private fun drain(
        codec: MediaCodec,
        muxer: MediaMuxer,
        info: MediaCodec.BufferInfo,
        trackIndexIn: Int,
        muxingIn: Boolean,
    ): Triple<Int, Boolean, Boolean> {
        var trackIndex = trackIndexIn
        var muxing = muxingIn
        while (true) {
            val outputIndex = codec.dequeueOutputBuffer(info, TIMEOUT_US)
            when {
                outputIndex == MediaCodec.INFO_TRY_AGAIN_LATER ->
                    return Triple(trackIndex, muxing, false)

                outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    // The real format (with SPS/PPS) only exists now; this is
                    // the only valid moment to add the track.
                    trackIndex = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                    muxing = true
                }

                outputIndex >= 0 -> {
                    val buffer = codec.getOutputBuffer(outputIndex)
                    // Codec config bytes ride in the track format, not the
                    // stream; writing them as a sample corrupts the file.
                    val isConfig =
                        info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                    if (buffer != null && !isConfig && info.size > 0 && muxing) {
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        muxer.writeSampleData(trackIndex, buffer, info)
                    }
                    codec.releaseOutputBuffer(outputIndex, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                        return Triple(trackIndex, muxing, true)
                    }
                }
            }
        }
    }

    /**
     * Convert one ARGB frame into the codec's input buffer as 4:2:0 YUV, and
     * return how many bytes to queue.
     *
     * Prefers [MediaCodec.getInputImage], which exposes per-plane row and pixel
     * strides — the only way to be correct on every device, since vendors
     * differ on both plane order (I420 vs NV12) and row padding. The size is
     * taken from the very planes we wrote, so it can't drift from the layout.
     */
    private fun writeFrame(
        codec: MediaCodec,
        index: Int,
        argb: IntArray,
        width: Int,
        height: Int,
    ): Int {
        val image = codec.getInputImage(index)
        if (image != null) {
            val yPlane = image.planes[0]
            val uPlane = image.planes[1]
            val vPlane = image.planes[2]
            writeYuv(
                argb, width, height,
                yPlane.buffer, yPlane.rowStride, yPlane.pixelStride,
                uPlane.buffer, uPlane.rowStride, uPlane.pixelStride,
                vPlane.buffer, vPlane.rowStride, vPlane.pixelStride,
            )
            // Semi-planar layouts share one chroma buffer between the U and V
            // planes, so summing all three would double-count it.
            val chroma = if (uPlane.buffer === vPlane.buffer) {
                uPlane.buffer.capacity()
            } else {
                uPlane.buffer.capacity() + vPlane.buffer.capacity()
            }
            return yPlane.buffer.capacity() + chroma
        }
        // Fallback for a codec that won't hand back an Image: assume NV12
        // (semi-planar, U before V), the most common raw layout.
        val buffer = codec.getInputBuffer(index)
            ?: throw IllegalStateException("no input buffer $index")
        buffer.clear()
        val ySize = width * height
        val y = buffer.duplicate().apply { position(0); limit(ySize) }.slice()
        val uv = buffer.duplicate().apply { position(ySize) }.slice()
        writeYuv(
            argb, width, height,
            y, width, 1,
            uv, width, 2,
            uv.duplicate().apply { position(1) }.slice(), width, 2,
        )
        return ySize * 3 / 2
    }

    /**
     * BT.709 limited-range ARGB → YUV 4:2:0, honouring each plane's strides.
     * Chroma is averaged over each 2×2 block rather than point-sampled, which
     * matters on the card's fine gold hairlines and spark dots.
     *
     * Integer coefficients are the BT.709 matrix scaled by 1024.
     */
    private fun writeYuv(
        argb: IntArray,
        width: Int,
        height: Int,
        yBuf: ByteBuffer, yRowStride: Int, yPixelStride: Int,
        uBuf: ByteBuffer, uRowStride: Int, uPixelStride: Int,
        vBuf: ByteBuffer, vRowStride: Int, vPixelStride: Int,
    ) {
        for (row in 0 until height) {
            for (col in 0 until width) {
                val c = argb[row * width + col]
                val r = (c shr 16) and 0xFF
                val g = (c shr 8) and 0xFF
                val b = c and 0xFF
                // Y' = 16 + 219 * (0.2126R + 0.7152G + 0.0722B) / 255
                val y = (16 * 1024 + 187 * r + 629 * g + 63 * b) shr 10
                yBuf.put(row * yRowStride + col * yPixelStride, y.coerceIn(0, 255).toByte())
            }
        }
        var uvRow = 0
        while (uvRow < height / 2) {
            var uvCol = 0
            while (uvCol < width / 2) {
                var rs = 0
                var gs = 0
                var bs = 0
                for (dy in 0..1) {
                    for (dx in 0..1) {
                        val c = argb[(uvRow * 2 + dy) * width + (uvCol * 2 + dx)]
                        rs += (c shr 16) and 0xFF
                        gs += (c shr 8) and 0xFF
                        bs += c and 0xFF
                    }
                }
                val r = rs / 4
                val g = gs / 4
                val b = bs / 4
                // Cb = 128 + 112 * (B - Y709) / (1 - 0.0722) / 255
                val u = (128 * 1024 - 103 * r - 347 * g + 450 * b) shr 10
                // Cr = 128 + 112 * (R - Y709) / (1 - 0.2126) / 255
                val v = (128 * 1024 + 450 * r - 409 * g - 41 * b) shr 10
                uBuf.put(uvRow * uRowStride + uvCol * uPixelStride,
                    u.coerceIn(0, 255).toByte())
                vBuf.put(uvRow * vRowStride + uvCol * vPixelStride,
                    v.coerceIn(0, 255).toByte())
                uvCol++
            }
            uvRow++
        }
    }
}
