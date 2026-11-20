package dev.luck.aireminder

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

data class Place(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val kind: String,
    val lat: Double,
    val lon: Double,
    val radius: Float = 150f
)

data class Parcel(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val collected: Boolean = false
)

data class ReminderEvent(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val detail: String,
    val timestamp: Long = System.currentTimeMillis(),
    val completed: Boolean = false
)

object DataStore {
    private fun prefs(ctx: Context) = ctx.getSharedPreferences("ai_reminder", Context.MODE_PRIVATE)

    fun places(ctx: Context): List<Place> {
        val arr = JSONArray(prefs(ctx).getString("places", "[]"))
        return (0 until arr.length()).map { i ->
            val j = arr.getJSONObject(i)
            Place(
                id = j.getString("id"), name = j.getString("name"),
                kind = j.getString("kind"), lat = j.getDouble("lat"),
                lon = j.getDouble("lon"), radius = j.getDouble("radius").toFloat()
            )
        }
    }

    @Synchronized
    fun savePlaces(ctx: Context, items: List<Place>) {
        val arr = JSONArray()
        items.forEach { p ->
            arr.put(JSONObject().put("id", p.id).put("name", p.name)
                .put("kind", p.kind).put("lat", p.lat).put("lon", p.lon)
                .put("radius", p.radius.toDouble()))
        }
        prefs(ctx).edit().putString("places", arr.toString()).apply()
    }

    fun parcels(ctx: Context): List<Parcel> {
        val arr = JSONArray(prefs(ctx).getString("parcels", "[]"))
        return (0 until arr.length()).map { i ->
            val j = arr.getJSONObject(i)
            Parcel(j.getString("id"), j.getString("name"), j.optBoolean("collected", false))
        }
    }

    @Synchronized
    fun saveParcels(ctx: Context, items: List<Parcel>) {
        val arr = JSONArray()
        items.forEach { p ->
            arr.put(JSONObject().put("id", p.id).put("name", p.name)
                .put("collected", p.collected))
        }
        prefs(ctx).edit().putString("parcels", arr.toString()).apply()
    }

    fun reminders(ctx: Context): List<ReminderEvent> {
        val arr = JSONArray(prefs(ctx).getString("reminders", "[]"))
        return (0 until arr.length()).map { i ->
            val j = arr.getJSONObject(i)
            ReminderEvent(j.getString("id"), j.getString("title"), j.getString("detail"),
                j.getLong("timestamp"), j.optBoolean("completed", false))
        }
    }

    @Synchronized
    fun addReminder(ctx: Context, event: ReminderEvent) {
        saveReminders(ctx, (listOf(event) + reminders(ctx)).take(100))
    }

    @Synchronized
    fun markCompleted(ctx: Context, id: String) {
        saveReminders(ctx, reminders(ctx).map { if (it.id == id) it.copy(completed = true) else it })
    }

    private fun saveReminders(ctx: Context, items: List<ReminderEvent>) {
        val arr = JSONArray()
        items.forEach { e ->
            arr.put(JSONObject().put("id", e.id).put("title", e.title)
                .put("detail", e.detail).put("timestamp", e.timestamp)
                .put("completed", e.completed))
        }
        prefs(ctx).edit().putString("reminders", arr.toString()).apply()
    }

    fun saveLocation(ctx: Context, lat: Double, lon: Double) {
        prefs(ctx).edit().putString("lat", lat.toString()).putString("lon", lon.toString()).apply()
    }

    fun lastLocation(ctx: Context): Pair<Double, Double>? {
        val p = prefs(ctx)
        val lat = p.getString("lat", null)?.toDoubleOrNull() ?: return null
        val lon = p.getString("lon", null)?.toDoubleOrNull() ?: return null
        return lat to lon
    }

    fun isMonitoring(ctx: Context) = prefs(ctx).getBoolean("monitoring", false)

    fun setMonitoring(ctx: Context, monitoring: Boolean) {
        prefs(ctx).edit().putBoolean("monitoring", monitoring).apply()
    }

    // null: state unchanged; true: entered; false: exited.
    @Synchronized
    fun checkTransition(ctx: Context, place: Place, distanceMeters: Float): Boolean? {
        val p = prefs(ctx)
        val key = "inside_" + place.id
        val previous = if (p.contains(key)) p.getBoolean(key, false) else null
        val inside = distanceMeters <= place.radius
        if (previous == null) {
            p.edit().putBoolean(key, inside).apply()
            return if (inside) true else null
        }
        if (!previous && inside) {
            p.edit().putBoolean(key, true).apply()
            return true
        }
        if (previous && distanceMeters >= place.radius + 60f) {
            p.edit().putBoolean(key, false).apply()
            return false
        }
        return null
    }
}
