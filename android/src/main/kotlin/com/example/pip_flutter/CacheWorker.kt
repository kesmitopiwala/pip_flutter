package com.example.pip_flutter

import android.content.Context
import android.net.Uri
import android.util.Log
import com.example.pip_flutter.DataSourceUtils.isHTTP
import com.example.pip_flutter.DataSourceUtils.getUserAgent
import com.example.pip_flutter.DataSourceUtils.getDataSourceFactory
import androidx.work.WorkerParameters
import com.google.android.exoplayer2.upstream.cache.CacheWriter
import androidx.work.Worker
import com.google.android.exoplayer2.upstream.DataSpec
import com.google.android.exoplayer2.upstream.HttpDataSource.HttpDataSourceException
import java.lang.Exception
import java.util.*

/**
 * Cache worker which download part of video and save in cache for future usage. The cache job
 * will be executed in work manager.
 */
class CacheWorker(
    private val mContext: Context,
    params: WorkerParameters
) : Worker(mContext, params) {
    private var mCacheWriter: CacheWriter? = null
    private var mLastCacheReportIndex = 0
    override fun doWork(): Result {
        try {
            val data = inputData
            val url = data.getString(PipFlutterPlugin.URL_PARAMETER)
            val cacheKey = data.getString(PipFlutterPlugin.CACHE_KEY_PARAMETER)
            val preCacheSize = data.getLong(PipFlutterPlugin.PRE_CACHE_SIZE_PARAMETER, 0)
            val maxCacheSize = data.getLong(PipFlutterPlugin.MAX_CACHE_SIZE_PARAMETER, 0)
            val maxCacheFileSize = data.getLong(PipFlutterPlugin.MAX_CACHE_FILE_SIZE_PARAMETER, 0)
            val headers: MutableMap<String, String> = HashMap()
            for (key in data.keyValueMap.keys) {
                if (key.contains(PipFlutterPlugin.HEADER_PARAMETER)) {
                    val keySplit =
                        key.split(PipFlutterPlugin.HEADER_PARAMETER.toRegex()).toTypedArray()[0]
                    headers[keySplit] = Objects.requireNonNull(data.keyValueMap[key]) as String
                }
            }
            val uri = Uri.parse(url)
            if (isHTTP(uri)) {
                val userAgent = getUserAgent(headers)
                val dataSourceFactory = getDataSourceFactory(userAgent, headers)
                var dataSpec = DataSpec(uri, 0, preCacheSize)
                if (cacheKey != null && cacheKey.isNotEmpty()) {
                    dataSpec = dataSpec.buildUpon().setKey(cacheKey).build()
                }
                val cacheDataSourceFactory = CacheDataSourceFactory(
                    mContext,
                    maxCacheSize,
                    maxCacheFileSize,
                    dataSourceFactory
                )
                mCacheWriter = CacheWriter(
                    cacheDataSourceFactory.createDataSource(),
                    dataSpec,
                    null
                ) { _: Long, bytesCached: Long, _: Long ->
                    val completedData = (bytesCached * 100f / preCacheSize).toDouble()
                    if (completedData >= mLastCacheReportIndex * 10) {
                        mLastCacheReportIndex += 1
                        Log.d(
                            TAG,
                            "Completed pre cache of " + url + ": " + completedData.toInt() + "%"
                        )
                    }
                }
                mCacheWriter!!.cache()
            } else {
                Log.e(TAG, "Preloading only possible for remote data sources")
                return Result.failure()
            }
        } catch (exception: Exception) {
            Log.e(TAG, exception.toString())
            return if (exception is HttpDataSourceException) {
                Result.success()
            } else {
                Result.failure()
            }
        }
        return Result.success()
    }

    override fun onStopped() {
        try {
            mCacheWriter!!.cancel()
            super.onStopped()
        } catch (exception: Exception) {
            Log.e(TAG, exception.toString())
        }
    }

    companion object {
        private const val TAG = "CacheWorker"
    }
}