package com.example.pip_flutter

import android.content.Context
import android.util.Log
import com.google.android.exoplayer2.upstream.cache.SimpleCache
import com.google.android.exoplayer2.upstream.cache.LeastRecentlyUsedCacheEvictor
import com.google.android.exoplayer2.database.ExoDatabaseProvider
import java.io.File
import java.lang.Exception

object PipFlutterPlayerCache {
    @Volatile
    private var instance: SimpleCache? = null
    fun createCache(context: Context, cacheFileSize: Long): SimpleCache? {
        if (instance == null) {
            synchronized(PipFlutterPlayerCache::class.java) {
                if (instance == null) {
                    instance = SimpleCache(
                        File(context.cacheDir, "pipFlutterPlayerCache"),
                        LeastRecentlyUsedCacheEvictor(cacheFileSize),
                        ExoDatabaseProvider(context)
                    )
                }
            }
        }
        return instance
    }

    @JvmStatic
    fun releaseCache() {
        try {
            if (instance != null) {
                instance!!.release()
                instance = null
            }
        } catch (exception: Exception) {
            Log.e("PipFlutterPlayerCache", exception.toString())
        }
    }
}