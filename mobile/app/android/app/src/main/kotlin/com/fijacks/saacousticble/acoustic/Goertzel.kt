package com.fijacks.saacousticble.acoustic

import kotlin.math.PI
import kotlin.math.cos

object Goertzel {
    fun power(samples: ShortArray, targetFrequency: Double, sampleRate: Int): Double {
        if (samples.isEmpty()) {
            return 0.0
        }
        val k = (0.5 + (samples.size * targetFrequency / sampleRate)).toInt()
        val omega = 2.0 * PI * k / samples.size
        val coeff = 2.0 * cos(omega)
        var q0 = 0.0
        var q1 = 0.0
        var q2: Double

        for (sample in samples) {
            q2 = q1
            q1 = q0
            q0 = coeff * q1 - q2 + sample.toDouble()
        }

        return q1 * q1 + q0 * q0 - coeff * q0 * q1
    }
}
