package com.example.orbithabit

import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.orbithabit/media_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "OrbitHabit_Poster.png"

                    if (bytes == null) {
                        result.error("INVALID_ARGUMENT", "Bytes cannot be null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val path = saveImageToMediaStore(this, bytes, fileName)
                        result.success(path)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.localizedMessage ?: e.message, null)
                    }
                }
                "shareImage" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val fileName = call.argument<String>("fileName") ?: "OrbitHabit_Poster.png"

                    if (bytes == null) {
                        result.error("INVALID_ARGUMENT", "Bytes cannot be null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        shareImageFile(this, bytes, fileName)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SHARE_FAILED", e.localizedMessage ?: e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveImageToMediaStore(context: Context, bytes: ByteArray, fileName: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/OrbitHabit")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val resolver = context.contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
                ?: throw Exception("No se pudo crear la imagen en MediaStore")

            resolver.openOutputStream(uri)?.use { outputStream ->
                outputStream.write(bytes)
                outputStream.flush()
            }

            contentValues.clear()
            contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, contentValues, null, null)

            return "Galería > Álbum OrbitHabit > $fileName"
        } else {
            @Suppress("DEPRECATION")
            val imagesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val appDir = File(imagesDir, "OrbitHabit")
            if (!appDir.exists()) {
                appDir.mkdirs()
            }
            val imageFile = File(appDir, fileName)
            FileOutputStream(imageFile).use { fos ->
                fos.write(bytes)
                fos.flush()
            }

            @Suppress("DEPRECATION")
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DATA, imageFile.absolutePath)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            }
            context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)

            return "Galería > OrbitHabit > $fileName"
        }
    }

    private fun shareImageFile(context: Context, bytes: ByteArray, fileName: String) {
        val cachePath = File(context.cacheDir, "shared_images")
        if (!cachePath.exists()) {
            cachePath.mkdirs()
        }
        val file = File(cachePath, fileName)
        FileOutputStream(file).use { fos ->
            fos.write(bytes)
            fos.flush()
        }

        val contentUri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, contentUri)
            putExtra(Intent.EXTRA_SUBJECT, "Cuadrante Mensual OrbitHabit")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(shareIntent, "Compartir Cuadrante Mensual")
        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(chooser)
    }
}
