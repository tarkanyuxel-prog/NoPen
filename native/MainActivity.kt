package com.nopen.app

import android.content.Intent
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val methodName = "nopen/speech"
    private val eventName = "nopen/speech_events"
    private var recognizer: SpeechRecognizer? = null
    private var sink: EventChannel.EventSink? = null
    private var locale = "tr-TR"
    private var shouldListen = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventName).setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
            override fun onCancel(arguments: Any?) { sink = null }
        })
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodName).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(SpeechRecognizer.isOnDeviceRecognitionAvailable(this))
                "start" -> {
                    locale = call.argument<String>("locale") ?: "tr-TR"
                    if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
                        result.error("UNAVAILABLE", "On-device speech recognition is not available.", null)
                    } else {
                        startRecognizer()
                        result.success(true)
                    }
                }
                "stop" -> { shouldListen = false; recognizer?.stopListening(); result.success(true) }
                else -> result.notImplemented()
            }
        }
    }

    private fun startRecognizer() {
        shouldListen = true
        if (recognizer == null) {
            recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            recognizer?.setRecognitionListener(object: RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) {
                    if (shouldListen) window.decorView.postDelayed({ listenOnce() }, 350)
                }
                override fun onResults(results: Bundle?) {
                    emit(results, true)
                    if (shouldListen) window.decorView.postDelayed({ listenOnce() }, 250)
                }
                override fun onPartialResults(partialResults: Bundle?) { emit(partialResults, false) }
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
        }
        listenOnce()
    }

    private fun emit(bundle: Bundle?, finalResult: Boolean) {
        val list = bundle?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val text = list?.firstOrNull() ?: return
        sink?.success(mapOf("text" to text, "final" to finalResult))
    }

    private fun listenOnce() {
        if (!shouldListen) return
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        recognizer?.startListening(intent)
    }

    override fun onDestroy() {
        shouldListen = false
        recognizer?.destroy()
        recognizer = null
        super.onDestroy()
    }
}
