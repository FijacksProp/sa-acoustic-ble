package com.fijacks.saacousticble.acoustic

import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack

class AcousticTransmitter {
    private var audioTrack: AudioTrack? = null
    private var latestPayload: String? = null

    fun start(payload: String) {
        stop()
        latestPayload = payload
        val frame = AcousticFrameEncoder.encodeFrame(payload)
        val minSize = AudioTrack.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        audioTrack = AudioTrack(
            AudioManager.STREAM_MUSIC,
            SAMPLE_RATE,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            maxOf(minSize, frame.size * 2),
            AudioTrack.MODE_STATIC
        ).apply {
            write(frame, 0, frame.size)
            setLoopPoints(0, frame.size, -1)
            play()
        }
    }

    fun stop() {
        audioTrack?.apply {
            try {
                stop()
            } catch (_: Exception) {
            }
            release()
        }
        audioTrack = null
    }

    fun getLatestPayload(): String? = latestPayload

    companion object {
        private const val SAMPLE_RATE = 44100
    }
}
