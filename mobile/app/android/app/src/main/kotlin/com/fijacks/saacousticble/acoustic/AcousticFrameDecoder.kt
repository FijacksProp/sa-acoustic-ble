package com.fijacks.saacousticble.acoustic

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import androidx.core.content.ContextCompat

class AcousticFrameDecoder(private val context: Context) {
    fun decodeFromMic(scanDurationMs: Int = 2800): String? {
        if (!hasRecordPermission()) {
            return null
        }
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) {
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
            return null
        }

        return try {
            record.startRecording()
            readFrame(record, scanDurationMs)
        } catch (_: Exception) {
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

        while (System.currentTimeMillis() - start < scanDurationMs) {
            val read = record.read(scratch, 0, scratch.size)
            if (read <= WINDOW_SAMPLES / 2) {
                continue
            }
            val window = if (read == WINDOW_SAMPLES) {
                scratch
            } else {
                scratch.copyOf(read)
            }

            val pStart = Goertzel.power(window, START_GUARD_FREQUENCY, SAMPLE_RATE)
            val pStop = Goertzel.power(window, STOP_GUARD_FREQUENCY, SAMPLE_RATE)
            val p0 = Goertzel.power(window, BIT0_FREQUENCY, SAMPLE_RATE)
            val p1 = Goertzel.power(window, BIT1_FREQUENCY, SAMPLE_RATE)
            val strongest = maxOf(pStart, pStop, p0, p1)
            if (strongest <= 0.0) {
                continue
            }

            if (!frameStarted) {
                // Start of frame gate around 18.5 kHz.
                if (pStart > p0 * START_RATIO && pStart > p1 * START_RATIO && pStart > pStop * START_RATIO) {
                    frameStarted = true
                    bits.clear()
                }
                continue
            }

            // Stop-of-frame gate around 19.8 kHz.
            if (pStop > p0 * STOP_RATIO && pStop > p1 * STOP_RATIO) {
                val decoded = decodeBits(bits)
                if (decoded != null) {
                    return decoded
                }
                frameStarted = false
                bits.clear()
                continue
            }

            bits += if (p1 > p0) 1 else 0
            if (bits.size > MAX_BITS) {
                frameStarted = false
                bits.clear()
            }
        }
        return decodeBits(bits)
    }

    private fun decodeBits(bits: List<Int>): String? {
        if (bits.size < 24) {
            return null
        }
        var idx = 0
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
        val neededBits = 8 + 8 + (length * 8) + 8
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
    }
}
