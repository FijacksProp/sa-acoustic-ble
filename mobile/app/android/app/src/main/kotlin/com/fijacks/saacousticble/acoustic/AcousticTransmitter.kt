package com.fijacks.saacousticble.acoustic

import android.media.AudioFormat
import android.media.AudioAttributes
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
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(maxOf(minSize, frame.size * 2))
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        val written = track.write(frame, 0, frame.size)
        if (written != frame.size) {
            track.release()
            throw IllegalStateException("Could not load the complete acoustic frame.")
        }
        audioTrack = track.apply {
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
        latestPayload = null
    }

    fun getLatestPayload(): String? = latestPayload

    companion object {
        private const val SAMPLE_RATE = 44100
    }
}
