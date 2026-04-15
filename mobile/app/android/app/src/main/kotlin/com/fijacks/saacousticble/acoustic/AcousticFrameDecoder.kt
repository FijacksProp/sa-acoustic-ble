package com.fijacks.saacousticble.acoustic

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

class AcousticFrameDecoder(private val context: Context) {
    var lastDiagnostics: String = "idle"
        private set

    fun decodeFromMic(scanDurationMs: Int = 2800): String? {
        if (!hasRecordPermission()) {
            lastDiagnostics = "record_audio_permission_missing"
            return null
        }
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
            lastDiagnostics = "audio_record_min_buffer_invalid"
            return null
        }
        val record = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minBuffer, WINDOW_SAMPLES * 4)
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            lastDiagnostics = "audio_record_not_initialized"
            return null
        }

        return try {
            record.startRecording()
            readFrame(record, scanDurationMs)
        } catch (error: Exception) {
            lastDiagnostics = "decode_exception:${error.javaClass.simpleName}"
            null
        } finally {
            try {
                record.stop()
            } catch (_: Exception) {
            }
            record.release()
        }
    }

    private fun readFrame(record: AudioRecord, scanDurationMs: Int): String? {
        val start = System.currentTimeMillis()
        val scratch = ShortArray(WINDOW_SAMPLES)
        val bits = ArrayList<Int>(2048)
        var frameStarted = false
        var startGuardHits = 0
        var stopGuardHits = 0
        var maxBitsResets = 0
        var lowEnergyWindows = 0
        var processedWindows = 0
        var ambiguousBitWindows = 0
        var bestStartRatio = 0.0
        var averageRms = 0.0
        var averageBitDominance = 0.0
        var lastDecodeFailure = "no_frame_end_detected"

        while (System.currentTimeMillis() - start < scanDurationMs) {
            val read = record.read(scratch, 0, scratch.size)
            if (read <= WINDOW_SAMPLES / 2) {
                lastDecodeFailure = "short_audio_read"
                continue
            }
            val window = if (read == WINDOW_SAMPLES) {
                scratch
            } else {
                scratch.copyOf(read)
            }
            val filteredWindow = conditionWindow(window)
            val rms = calculateRms(filteredWindow)
            processedWindows += 1
            averageRms += (rms - averageRms) / processedWindows
            if (rms < MIN_FILTERED_RMS) {
                lowEnergyWindows += 1
                lastDecodeFailure = "low_ultrasonic_energy"
                continue
            }

            val pStart = Goertzel.power(filteredWindow, START_GUARD_FREQUENCY, SAMPLE_RATE)
            val pStop = Goertzel.power(filteredWindow, STOP_GUARD_FREQUENCY, SAMPLE_RATE)
            val p0 = Goertzel.power(filteredWindow, BIT0_FREQUENCY, SAMPLE_RATE)
            val p1 = Goertzel.power(filteredWindow, BIT1_FREQUENCY, SAMPLE_RATE)
            val startRatio = pStart / maxOf(1.0, maxOf(p0, p1, pStop))
            if (startRatio > bestStartRatio) {
                bestStartRatio = startRatio
            }
            val strongest = maxOf(pStart, pStop, p0, p1)
            if (strongest <= 0.0) {
                continue
            }

            if (!frameStarted) {
                // Start of frame gate around 18.5 kHz.
                if (pStart > p0 * START_RATIO && pStart > p1 * START_RATIO && pStart > pStop * START_RATIO) {
                    frameStarted = true
                    startGuardHits += 1
                    bits.clear()
                }
                continue
            }

            // Stop-of-frame gate around 19.8 kHz.
            if (pStop > p0 * STOP_RATIO && pStop > p1 * STOP_RATIO) {
                stopGuardHits += 1
                val decoded = decodeBits(bits)
                if (decoded != null) {
                    lastDiagnostics =
                        "decoded_frame startGuards=$startGuardHits stopGuards=$stopGuardHits bits=${bits.size} lowEnergy=$lowEnergyWindows ambiguousBits=$ambiguousBitWindows avgRms=${averageRms.toInt()} avgBitDominance=${"%.2f".format(averageBitDominance)}"
                    return decoded
                }
                lastDecodeFailure = "stop_guard_hit_decode_failed"
                frameStarted = false
                bits.clear()
                continue
            }

            val bitDominance = maxOf(p1, p0) / maxOf(1.0, minOf(p1, p0))
            if (bitDominance < MIN_BIT_DOMINANCE_RATIO) {
                ambiguousBitWindows += 1
            }
            val bitSamples = bits.size + 1
            averageBitDominance += (bitDominance - averageBitDominance) / bitSamples
            bits += if (p1 > p0) 1 else 0
            if (bits.size > MAX_BITS) {
                maxBitsResets += 1
                lastDecodeFailure = "max_bits_exceeded"
                frameStarted = false
                bits.clear()
            }
        }
        val trailing = decodeBits(bits)
        if (trailing != null) {
            lastDiagnostics =
                "decoded_trailing_bits startGuards=$startGuardHits stopGuards=$stopGuardHits bits=${bits.size} avgRms=${averageRms.toInt()} avgBitDominance=${"%.2f".format(averageBitDominance)}"
            return trailing
        }
        lastDiagnostics =
            "decode_failed reason=$lastDecodeFailure startGuards=$startGuardHits stopGuards=$stopGuardHits maxBitResets=$maxBitsResets lowEnergy=$lowEnergyWindows ambiguousBits=$ambiguousBitWindows bestStartRatio=${"%.2f".format(bestStartRatio)} avgRms=${averageRms.toInt()} avgBitDominance=${"%.2f".format(averageBitDominance)} residualBits=${bits.size}"
        return null
    }

    private fun decodeBits(bits: List<Int>): String? {
        if (bits.size < MIN_FRAME_BITS) {
            return null
        }
        for (offset in 0..minOf(MAX_PREAMBLE_SEARCH_BITS, bits.size - MIN_FRAME_BITS)) {
            val decoded = decodeBitsAtOffset(bits, offset)
            if (decoded != null) {
                return decoded
            }
        }
        return null
    }

    private fun decodeBitsAtOffset(bits: List<Int>, offset: Int): String? {
        var idx = offset
        val preamble = readByte(bits, idx) ?: return null
        idx += 8
        if (preamble != PREAMBLE) {
            return null
        }
        val length = readByte(bits, idx) ?: return null
        idx += 8
        if (length <= 0 || length > 255) {
            return null
        }
        val neededBits = offset + 8 + 8 + (length * 8) + 8
        if (bits.size < neededBits) {
            return null
        }

        val payload = ByteArray(length)
        var checksum = 0
        for (i in 0 until length) {
            val value = readByte(bits, idx) ?: return null
            idx += 8
            payload[i] = value.toByte()
            checksum = checksum xor value
        }
        val expected = readByte(bits, idx) ?: return null
        if ((checksum and 0xFF) != expected) {
            return null
        }
        return payload.toString(Charsets.UTF_8)
    }

    private fun readByte(bits: List<Int>, start: Int): Int? {
        if (start + 8 > bits.size) {
            return null
        }
        var value = 0
        for (i in 0 until 8) {
            val bit = bits[start + i]
            if (bit != 0 && bit != 1) {
                return null
            }
            value = (value shl 1) or bit
        }
        return value
    }

    private fun hasRecordPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED
    }

    // Keep only the ultrasonic corridor where the transmitter operates.
    private fun conditionWindow(samples: ShortArray): ShortArray {
        val highPassed = HighPassFilter.process(samples)
        val bandPassed = LowPassFilter.process(highPassed)
        return applyHannWindow(bandPassed)
    }

    private fun applyHannWindow(samples: ShortArray): ShortArray {
        if (samples.isEmpty()) {
            return samples
        }
        val output = ShortArray(samples.size)
        val denominator = maxOf(1, samples.size - 1)
        for (i in samples.indices) {
            val weight = 0.5 - (0.5 * cos(2.0 * PI * i / denominator))
            output[i] = (samples[i] * weight)
                .coerceIn(Short.MIN_VALUE.toDouble(), Short.MAX_VALUE.toDouble())
                .toInt()
                .toShort()
        }
        return output
    }

    private fun calculateRms(samples: ShortArray): Double {
        if (samples.isEmpty()) {
            return 0.0
        }
        var sumSquares = 0.0
        for (sample in samples) {
            val value = sample.toDouble()
            sumSquares += value * value
        }
        return kotlin.math.sqrt(sumSquares / samples.size)
    }

    companion object {
        private const val SAMPLE_RATE = 44100
        private const val BIT_DURATION_MS = 35
        private val WINDOW_SAMPLES = SAMPLE_RATE * BIT_DURATION_MS / 1000
        private const val BIT0_FREQUENCY = 19000.0
        private const val BIT1_FREQUENCY = 19500.0
        private const val START_GUARD_FREQUENCY = 18500.0
        private const val STOP_GUARD_FREQUENCY = 19800.0
        private const val START_RATIO = 1.35
        private const val STOP_RATIO = 1.35
        private const val PREAMBLE = 0b10101010
        private const val MAX_BITS = 2200
        private const val MIN_FRAME_BITS = 24
        private const val MAX_PREAMBLE_SEARCH_BITS = 64
        private const val MIN_FILTERED_RMS = 120.0
        private const val MIN_BIT_DOMINANCE_RATIO = 1.08
        private val HighPassFilter = BiquadFilter.highPass(
            sampleRate = SAMPLE_RATE.toDouble(),
            cutoffFrequency = 18_000.0,
            q = 0.707
        )
        private val LowPassFilter = BiquadFilter.lowPass(
            sampleRate = SAMPLE_RATE.toDouble(),
            cutoffFrequency = 20_000.0,
            q = 0.707
        )
    }
}

private class BiquadFilter private constructor(
    private val b0: Double,
    private val b1: Double,
    private val b2: Double,
    private val a1: Double,
    private val a2: Double,
) {
    fun process(input: ShortArray): ShortArray {
        var x1 = 0.0
        var x2 = 0.0
        var y1 = 0.0
        var y2 = 0.0
        val output = ShortArray(input.size)

        for (i in input.indices) {
            val x0 = input[i].toDouble()
            val y0 = (b0 * x0) + (b1 * x1) + (b2 * x2) - (a1 * y1) - (a2 * y2)
            output[i] = y0.coerceIn(Short.MIN_VALUE.toDouble(), Short.MAX_VALUE.toDouble()).toInt().toShort()
            x2 = x1
            x1 = x0
            y2 = y1
            y1 = y0
        }

        return output
    }

    companion object {
        fun lowPass(sampleRate: Double, cutoffFrequency: Double, q: Double): BiquadFilter {
            val omega = 2.0 * PI * cutoffFrequency / sampleRate
            val alpha = sin(omega) / (2.0 * q)
            val cosOmega = cos(omega)
            val a0 = 1.0 + alpha
            val b0 = (1.0 - cosOmega) / 2.0 / a0
            val b1 = (1.0 - cosOmega) / a0
            val b2 = (1.0 - cosOmega) / 2.0 / a0
            val a1 = (-2.0 * cosOmega) / a0
            val a2 = (1.0 - alpha) / a0
            return BiquadFilter(b0, b1, b2, a1, a2)
        }

        fun highPass(sampleRate: Double, cutoffFrequency: Double, q: Double): BiquadFilter {
            val omega = 2.0 * PI * cutoffFrequency / sampleRate
            val alpha = sin(omega) / (2.0 * q)
            val cosOmega = cos(omega)
            val a0 = 1.0 + alpha
            val b0 = (1.0 + cosOmega) / 2.0 / a0
            val b1 = (-(1.0 + cosOmega)) / a0
            val b2 = (1.0 + cosOmega) / 2.0 / a0
            val a1 = (-2.0 * cosOmega) / a0
            val a2 = (1.0 - alpha) / a0
            return BiquadFilter(b0, b1, b2, a1, a2)
        }
    }
}
