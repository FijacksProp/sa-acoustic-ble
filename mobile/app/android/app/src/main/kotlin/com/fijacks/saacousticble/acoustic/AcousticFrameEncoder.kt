package com.fijacks.saacousticble.acoustic

import kotlin.math.PI
import kotlin.math.sin

object AcousticFrameEncoder {
    private const val sampleRate = 44100
    private const val bit0Frequency = 19000.0
    private const val bit1Frequency = 19500.0
    private const val startGuardFrequency = 18500.0
    private const val stopGuardFrequency = 19800.0
    private const val amplitude = 0.28
    private const val guardDurationMs = 120
    private const val repeatCount = 3
    private const val interFrameGapMs = 24

    fun encodeFrame(payload: String, bitDurationMs: Int = 12): ShortArray {
        val bytes = payload.toByteArray(Charsets.UTF_8)
        val capped = bytes.take(255)
        val checksum = capped.fold(0) { acc, value -> acc xor (value.toInt() and 0xFF) }
        val frame = mutableListOf<Int>()

        // Guard + preamble for coarse sync before bit decoding on receiver side.
        frame += listOf(1, 0, 1, 0, 1, 0, 1, 0)
        frame += toBits(capped.size)
        capped.forEach { frame += toBits(it.toInt() and 0xFF) }
        frame += toBits(checksum)

        val startGuard = tone(startGuardFrequency, guardDurationMs)
        val data = frame.flatMap { bit ->
            val freq = if (bit == 0) bit0Frequency else bit1Frequency
            tone(freq, bitDurationMs).asList()
        }.toShortArray()
        val stopGuard = tone(stopGuardFrequency, guardDurationMs)
        val singleFrame = ShortArray(startGuard.size + data.size + stopGuard.size)
        System.arraycopy(startGuard, 0, singleFrame, 0, startGuard.size)
        System.arraycopy(data, 0, singleFrame, startGuard.size, data.size)
        System.arraycopy(stopGuard, 0, singleFrame, startGuard.size + data.size, stopGuard.size)

        val gap = silence(interFrameGapMs)
        val totalSize = (singleFrame.size * repeatCount) + (gap.size * (repeatCount - 1))
        val burst = ShortArray(totalSize)
        var writeIndex = 0
        repeat(repeatCount) { index ->
            System.arraycopy(singleFrame, 0, burst, writeIndex, singleFrame.size)
            writeIndex += singleFrame.size
            if (index < repeatCount - 1) {
                System.arraycopy(gap, 0, burst, writeIndex, gap.size)
                writeIndex += gap.size
            }
        }
        return burst
    }

    private fun toBits(value: Int): List<Int> {
        val bits = ArrayList<Int>(8)
        for (i in 7 downTo 0) {
            bits.add((value shr i) and 1)
        }
        return bits
    }

    private fun tone(frequency: Double, durationMs: Int): ShortArray {
        val samples = (sampleRate * durationMs) / 1000
        val output = ShortArray(samples)
        val rampSamples = (sampleRate * 4) / 1000
        for (i in 0 until samples) {
            val angle = 2.0 * PI * i * frequency / sampleRate
            val ramp = when {
                i < rampSamples -> i.toDouble() / rampSamples
                i > samples - rampSamples -> (samples - i).toDouble() / rampSamples
                else -> 1.0
            }.coerceIn(0.0, 1.0)
            output[i] = (sin(angle) * Short.MAX_VALUE * amplitude * ramp).toInt().toShort()
        }
        return output
    }

    private fun silence(durationMs: Int): ShortArray {
        val samples = (sampleRate * durationMs) / 1000
        return ShortArray(samples)
    }
}
