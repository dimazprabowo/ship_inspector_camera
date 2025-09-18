package com.example.ship_inspector

import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "flutter.native/helper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFileManager" -> {
                    val path = call.argument<String>("path")
                    if (path != null) {
                        try {
                            openFileManager(path)
                            result.success("File manager opened")
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to open file manager: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openFileManager(folderPath: String) {
        try {
            val folder = File(folderPath)
            
            // Create folder if it doesn't exist
            if (!folder.exists()) {
                folder.mkdirs()
            }
            
            // Try different approaches to open folder
            var success = false
            
            // Method 1: Try to open with DocumentsUI (Android's built-in file manager)
            try {
                val intent = Intent(Intent.ACTION_VIEW)
                intent.setDataAndType(Uri.fromFile(folder), "resource/folder")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    success = true
                }
            } catch (e: Exception) {
                // Continue to next method
            }
            
            // Method 2: Try with ACTION_GET_CONTENT
            if (!success) {
                try {
                    val intent = Intent(Intent.ACTION_GET_CONTENT)
                    intent.setDataAndType(Uri.fromFile(folder), "*/*")
                    intent.addCategory(Intent.CATEGORY_OPENABLE)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                        success = true
                    }
                } catch (e: Exception) {
                    // Continue to next method
                }
            }
            
            // Method 3: Try with specific file manager apps
            if (!success) {
                try {
                    // Try to open with common file managers
                    val fileManagerPackages = listOf(
                        "com.android.documentsui", // Android Documents
                        "com.google.android.documentsui", // Google Files
                        "com.mi.android.globalFileexplorer", // Mi File Manager
                        "com.android.fileexplorer", // Generic File Explorer
                        "com.estrongs.android.pop" // ES File Explorer
                    )
                    
                    for (packageName in fileManagerPackages) {
                        try {
                            val intent = packageManager.getLaunchIntentForPackage(packageName)
                            if (intent != null) {
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                                success = true
                                break
                            }
                        } catch (e: Exception) {
                            continue
                        }
                    }
                } catch (e: Exception) {
                    // Continue to fallback
                }
            }
            
            // Method 4: Fallback - Open Downloads folder or any file manager
            if (!success) {
                try {
                    val intent = Intent(Intent.ACTION_VIEW)
                    intent.type = "resource/folder"
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    
                    if (intent.resolveActivity(packageManager) != null) {
                        startActivity(intent)
                    } else {
                        // Last resort: Open any available file manager
                        val fallbackIntent = Intent(Intent.ACTION_MAIN)
                        fallbackIntent.addCategory(Intent.CATEGORY_LAUNCHER)
                        fallbackIntent.type = "*/*"
                        fallbackIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(Intent.createChooser(fallbackIntent, "Pilih File Manager"))
                    }
                } catch (e: Exception) {
                    throw Exception("Tidak dapat membuka file manager")
                }
            }
            
        } catch (e: Exception) {
            throw Exception("Gagal membuka folder: ${e.message}")
        }
    }
}
