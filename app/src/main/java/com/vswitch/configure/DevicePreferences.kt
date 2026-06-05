package com.vswitch.configure

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.deviceDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "device_preferences"
)

class DevicePreferences(private val context: Context) {

    private val serialNumberKey = stringPreferencesKey("serial_number")

    val serialNumber: Flow<String?> = context.deviceDataStore.data.map { prefs ->
        prefs[serialNumberKey]?.takeIf { it.isNotBlank() }
    }

    suspend fun saveSerialNumber(serialNumber: String) {
        context.deviceDataStore.edit { prefs ->
            prefs[serialNumberKey] = serialNumber
        }
    }
}
