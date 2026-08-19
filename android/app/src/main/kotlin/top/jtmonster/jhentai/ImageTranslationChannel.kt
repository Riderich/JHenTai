package top.jtmonster.jhentai

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Rect
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import kotlin.math.max
import kotlin.math.min

class ImageTranslationChannel(flutterEngine: FlutterEngine) {
    private val recognizer = TextRecognition.getClient(
        JapaneseTextRecognizerOptions.Builder().build()
    )
    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "top.jtmonster.jhentai.image_translation"
    )

    init {
        channel.setMethodCallHandler(::handleCall)
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "recognizeJapanese" -> recognize(call, result)
            "renderTranslations" -> render(call, result)
            else -> result.notImplemented()
        }
    }

    private fun recognize(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("image")
        val bitmap = bytes?.let { BitmapFactory.decodeByteArray(it, 0, it.size) }
        if (bitmap == null) {
            result.error("INVALID_IMAGE", "Unable to decode the manga page", null)
            return
        }
        recognizer.process(InputImage.fromBitmap(bitmap, 0))
            .addOnSuccessListener { text ->
                val regions = text.textBlocks.flatMap { block -> block.lines }.mapNotNull { line ->
                    val box = line.boundingBox ?: return@mapNotNull null
                    mapOf(
                        "text" to line.text,
                        "x" to box.left,
                        "y" to box.top,
                        "width" to box.width(),
                        "height" to box.height()
                    )
                }
                bitmap.recycle()
                result.success(regions)
            }
            .addOnFailureListener { error ->
                bitmap.recycle()
                result.error("OCR_FAILED", error.message, null)
            }
    }

    private fun render(call: MethodCall, result: MethodChannel.Result) {
        try {
            val bytes = call.argument<ByteArray>("image")
                ?: throw IllegalArgumentException("Missing image")
            val source = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                ?: throw IllegalArgumentException("Unable to decode image")
            val bitmap = source.copy(Bitmap.Config.ARGB_8888, true)
            if (bitmap !== source) source.recycle()
            val canvas = Canvas(bitmap)
            val regions = call.argument<List<Map<String, Any?>>>("regions").orEmpty()
            regions.forEach { drawRegion(canvas, bitmap, it) }
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, output)
            bitmap.recycle()
            result.success(output.toByteArray())
        } catch (error: Throwable) {
            result.error("RENDER_FAILED", error.message, null)
        }
    }

    private fun drawRegion(canvas: Canvas, bitmap: Bitmap, region: Map<String, Any?>) {
        fun number(name: String): Int = (region[name] as? Number)?.toInt() ?: 0
        val padding = max(4, min(bitmap.width, bitmap.height) / 500)
        val left = max(0, number("x") - padding)
        val top = max(0, number("y") - padding)
        val right = min(bitmap.width, number("x") + number("width") + padding)
        val bottom = min(bitmap.height, number("y") + number("height") + padding)
        if (right <= left || bottom <= top) return
        val rect = Rect(left, top, right, bottom)
        val translation = region["translation"]?.toString()?.trim().orEmpty()
        if (translation.isEmpty()) return

        val background = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.WHITE }
        canvas.drawRect(rect, background)

        val textPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.BLACK
            textAlign = Paint.Align.CENTER
            typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL)
        }
        val lines = fitLines(translation, rect, textPaint)
        val metrics = textPaint.fontMetrics
        val lineHeight = (metrics.descent - metrics.ascent) * 1.08f
        var baseline = rect.centerY() - lineHeight * (lines.size - 1) / 2f - (metrics.ascent + metrics.descent) / 2f
        lines.forEach { line ->
            canvas.drawText(line, rect.exactCenterX(), baseline, textPaint)
            baseline += lineHeight
        }
    }

    private fun fitLines(text: String, rect: Rect, paint: Paint): List<String> {
        val maxSize = max(12f, min(rect.width(), rect.height()).toFloat())
        var size = maxSize
        while (size >= 10f) {
            paint.textSize = size
            val lines = wrap(text, rect.width().toFloat(), paint)
            val height = (paint.fontMetrics.descent - paint.fontMetrics.ascent) * 1.08f * lines.size
            if (height <= rect.height()) return lines
            size -= 2f
        }
        paint.textSize = 10f
        return wrap(text, rect.width().toFloat(), paint)
    }

    private fun wrap(text: String, width: Float, paint: Paint): List<String> {
        val lines = mutableListOf<String>()
        var current = ""
        text.forEach { character ->
            val candidate = current + character
            if (current.isNotEmpty() && paint.measureText(candidate) > width) {
                lines += current
                current = character.toString()
            } else {
                current = candidate
            }
        }
        if (current.isNotEmpty()) lines += current
        return lines.ifEmpty { listOf(text) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        recognizer.close()
    }
}
