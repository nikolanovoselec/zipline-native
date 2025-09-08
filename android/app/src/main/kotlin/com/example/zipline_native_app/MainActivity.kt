package com.example.zipline_native_app

import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.zipline_native_app/intent"
    private val TAG = "ZiplineNative"
    
    private var pendingSharedFiles: List<String>? = null
    private var pendingSharedText: String? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFiles" -> {
                    result.success(pendingSharedFiles)
                    pendingSharedFiles = null // Clear after retrieval
                }
                "getSharedText" -> {
                    result.success(pendingSharedText)
                    pendingSharedText = null // Clear after retrieval
                }
                "copyContentUriFile" -> {
                    val contentUri = call.argument<String>("contentUri")
                    val targetPath = call.argument<String>("targetPath")
                    if (contentUri != null && targetPath != null) {
                        val success = copyContentUriFile(contentUri, targetPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing contentUri or targetPath", null)
                    }
                }
                "getContentUriFileName" -> {
                    val contentUri = call.argument<String>("contentUri")
                    if (contentUri != null) {
                        val fileName = getContentUriFileName(contentUri)
                        result.success(fileName)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing contentUri", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Process intent if app was launched with sharing data
        handleIntent(intent)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        
        Log.d(TAG, "Handling intent: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type?.startsWith("text/") == true) {
                    // Handle shared text/URL
                    pendingSharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    Log.d(TAG, "Received shared text: $pendingSharedText")
                } else {
                    // Handle single file
                    val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    if (uri != null) {
                        pendingSharedFiles = listOf(uri.toString())
                        Log.d(TAG, "Received shared file: $uri")
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                // Handle multiple files
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                if (uris != null) {
                    pendingSharedFiles = uris.map { it.toString() }
                    Log.d(TAG, "Received ${uris.size} shared files")
                }
            }
        }
    }
    
    private fun getContentUriFileName(contentUriString: String): String? {
        return try {
            val contentUri = Uri.parse(contentUriString)
            var fileName: String? = null
            
            // Query the content resolver for the display name
            contentResolver.query(contentUri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val displayNameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (displayNameIndex != -1) {
                        fileName = cursor.getString(displayNameIndex)
                    }
                }
            }
            
            Log.d(TAG, "Extracted filename from URI: $fileName")
            fileName
        } catch (e: Exception) {
            Log.e(TAG, "Error getting filename from URI: ${e.message}")
            null
        }
    }
    
    private fun copyContentUriFile(contentUriString: String, targetPath: String): Boolean {
        return try {
            val contentUri = Uri.parse(contentUriString)
            val inputStream: InputStream? = contentResolver.openInputStream(contentUri)
            
            if (inputStream != null) {
                val targetFile = File(targetPath)
                targetFile.parentFile?.mkdirs()
                
                val outputStream = FileOutputStream(targetFile)
                inputStream.copyTo(outputStream)
                
                inputStream.close()
                outputStream.close()
                
                Log.d(TAG, "Successfully copied file to: $targetPath")
                true
            } else {
                Log.e(TAG, "Could not open input stream for: $contentUriString")
                false
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error copying file: ${e.message}")
            false
        }
    }
}
