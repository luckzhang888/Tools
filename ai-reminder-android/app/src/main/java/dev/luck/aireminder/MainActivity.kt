package dev.luck.aireminder

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme {
                ReminderApp(this)
            }
        }
    }
}

@Composable
private fun ReminderApp(activity: MainActivity) {
    var tab by remember { mutableIntStateOf(0) }
    var revision by remember { mutableIntStateOf(0) }
    var info by remember { mutableStateOf("") }
    val refresh: () -> Unit = { revision += 1 }

    val locationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        if (permissions[Manifest.permission.ACCESS_FINE_LOCATION] == true ||
            permissions[Manifest.permission.ACCESS_COARSE_LOCATION] == true) {
            activity.startForegroundService(Intent(activity, LocationMonitorService::class.java))
            info = "定位监测已启动。可锁屏测试提醒。"
        } else {
            info = "需要定位权限才能进行地点提醒。"
        }
        refresh()
    }

    val notificationLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        info = if (granted) "消息通知已开启" else "未授予消息通知权限，提醒可能无法弹出"
        refresh()
    }

    val startMonitoring = {
        val fine = activity.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = activity.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        if (fine || coarse) {
            activity.startForegroundService(Intent(activity, LocationMonitorService::class.java))
            info = "定位监测已启动"
            refresh()
        } else {
            locationLauncher.launch(arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION
            ))
        }
    }

    Scaffold(
        bottomBar = {
            NavigationBar {
                listOf("首页", "地点", "快递", "提醒").forEachIndexed { index, label ->
                    NavigationBarItem(
                        selected = tab == index,
                        onClick = { tab = index; info = ""; refresh() },
                        icon = { Text(listOf("⌂", "◎", "▣", "♧")[index]) },
                        label = { Text(label) }
                    )
                }
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp, vertical = 12.dp)) {
            Text("AI 生活提醒", style = MaterialTheme.typography.headlineSmall)
            Text("本机定位 · 打卡 · 快递 · 消息", color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            if (info.isNotEmpty()) {
                Text(info, color = MaterialTheme.colorScheme.primary)
                Spacer(Modifier.height(8.dp))
            }
            when (tab) {
                0 -> HomePage(
                    activity, revision, startMonitoring,
                    stop = {
                        activity.startService(Intent(activity, LocationMonitorService::class.java)
                            .setAction(LocationMonitorService.ACTION_STOP))
                        info = "已请求停止定位监测"
                        refresh()
                    },
                    enableNotifications = {
                        if (Build.VERSION.SDK_INT >= 33) {
                            notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        } else {
                            info = "当前系统无需单独申请通知权限"
                        }
                    },
                    refresh = refresh
                )
                1 -> PlacesPage(activity, revision, refresh, onMessage = { info = it })
                2 -> ParcelsPage(activity, revision, refresh)
                else -> EventsPage(activity, revision, refresh)
            }
        }
    }
}

@Composable
private fun HomePage(
    activity: MainActivity,
    revision: Int,
    start: () -> Unit,
    stop: () -> Unit,
    enableNotifications: () -> Unit,
    refresh: () -> Unit
) {
    val running = DataStore.isMonitoring(activity)
    val places = DataStore.places(activity)
    val parcels = DataStore.parcels(activity).count { !it.collected }
    val events = DataStore.reminders(activity).count { !it.completed }
    val location = DataStore.lastLocation(activity)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(12.dp))
        ElevatedCard(Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp)) {
                Text(if (running) "● 位置监测：运行中" else "○ 位置监测：未开启",
                    style = MaterialTheme.typography.titleMedium)
                Spacer(Modifier.height(8.dp))
                Text("已设置地点：" + places.size + "    待取快递：" + parcels)
                Text("未完成提醒：" + events)
                if (location != null) {
                    Spacer(Modifier.height(6.dp))
                    Text("最近定位：%.5f, %.5f".format(Locale.US, location.first, location.second))
                }
                Spacer(Modifier.height(12.dp))
                Button(onClick = if (running) stop else start) {
                    Text(if (running) "停止定位监测" else "启动定位监测")
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        Button(onClick = enableNotifications) { Text("允许锁屏消息通知") }
        TextButton(onClick = refresh) { Text("刷新状态") }
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))
        Text("使用步骤", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        Text("1. 开启通知及定位权限，启动定位监测。")
        Text("2. 进入“地点”，利用最近 GPS 坐标添加公司、快递站。")
        Text("3. 进入“快递”，录入尚未取走的包裹。")
        Text("4. 进入或离开设定区域，系统保存提醒并发送本地通知。")
        Spacer(Modifier.height(12.dp))
        Text(
            "注意：定位监测需要持续显示前台服务通知，并会增加耗电。" +
            "强制停止应用、部分省电策略或设备重启后可能需要重新开启。所有地点和快递仅保存在手机本地。",
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun PlacesPage(
    activity: MainActivity, revision: Int, refresh: () -> Unit, onMessage: (String) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var kind by remember { mutableStateOf("office") }
    var radius by remember { mutableStateOf("150") }
    val places = DataStore.places(activity)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(8.dp))
        Text("新增监测地点", style = MaterialTheme.typography.titleMedium)
        OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("地点名称，如：公司、菜鸟驿站") },
            modifier = Modifier.fillMaxWidth(), singleLine = true)
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("office" to "公司", "pickup" to "快递", "other" to "其它").forEach { (value, label) ->
                FilterChip(selected = kind == value, onClick = { kind = value }, label = { Text(label) })
            }
        }
        OutlinedTextField(value = radius, onValueChange = { radius = it },
            label = { Text("触发半径（米，建议100~200）") }, modifier = Modifier.fillMaxWidth(),
            singleLine = true)
        Spacer(Modifier.height(8.dp))
        Button(onClick = {
            val point = DataStore.lastLocation(activity)
            val meters = radius.toFloatOrNull()
            when {
                name.isBlank() -> onMessage("请输入地点名称")
                point == null -> onMessage("暂无 GPS 坐标，请先开启定位监测并等待定位")
                meters == null || meters !in 80f..2000f -> onMessage("半径请输入 80 到 2000 米")
                else -> {
                    DataStore.savePlaces(activity, places + Place(
                        name = name.trim(), kind = kind, lat = point.first,
                        lon = point.second, radius = meters
                    ))
                    name = ""
                    onMessage("地点已保存，位置为最近一次 GPS 定位")
                    refresh()
                }
            }
        }) { Text("使用手机当前位置添加") }
        Spacer(Modifier.height(12.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))
        if (places.isEmpty()) Text("尚未设置地点")
        places.forEach { p ->
            ElevatedCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp)) {
                    Text(p.name, style = MaterialTheme.typography.titleMedium)
                    Text((when(p.kind) { "office" -> "公司"; "pickup" -> "快递站"; else -> "普通地点" }) +
                        " · 半径 " + p.radius.toInt() + " 米")
                    Text("%.5f, %.5f".format(Locale.US, p.lat, p.lon),
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    TextButton(onClick = {
                        DataStore.savePlaces(activity, places.filterNot { it.id == p.id })
                        refresh()
                    }) { Text("删除地点") }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun ParcelsPage(activity: MainActivity, revision: Int, refresh: () -> Unit) {
    var label by remember { mutableStateOf("") }
    val parcels = DataStore.parcels(activity)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(8.dp))
        Text("快递待办", style = MaterialTheme.typography.titleMedium)
        Text("仅在靠近“快递”类地点且有未领取包裹时提醒。")
        OutlinedTextField(
            value = label, onValueChange = { label = it }, label = { Text("快递备注或取件码") },
            modifier = Modifier.fillMaxWidth(), singleLine = true
        )
        Spacer(Modifier.height(8.dp))
        Button(onClick = {
            if (label.isNotBlank()) {
                DataStore.saveParcels(activity, parcels + Parcel(name = label.trim()))
                label = ""
                refresh()
            }
        }) { Text("添加待取快递") }
        Spacer(Modifier.height(12.dp))
        HorizontalDivider()
        Spacer(Modifier.height(12.dp))
        if (parcels.isEmpty()) Text("暂无快递记录")
        parcels.forEach { parcel ->
            ElevatedCard(Modifier.fillMaxWidth()) {
                Row(Modifier.fillMaxWidth().padding(8.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                    Row(Modifier.weight(1f)) {
                        Checkbox(checked = parcel.collected, onCheckedChange = { checked ->
                            DataStore.saveParcels(activity, parcels.map {
                                if (it.id == parcel.id) it.copy(collected = checked) else it
                            })
                            refresh()
                        })
                        Column {
                            Text(parcel.name)
                            Text(if (parcel.collected) "已领取" else "待领取",
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    TextButton(onClick = {
                        DataStore.saveParcels(activity, parcels.filterNot { it.id == parcel.id })
                        refresh()
                    }) { Text("删除") }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun EventsPage(activity: MainActivity, revision: Int, refresh: () -> Unit) {
    val events = DataStore.reminders(activity)
    val dateFormat = remember { SimpleDateFormat("MM-dd HH:mm", Locale.getDefault()) }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(8.dp))
        Text("提醒记录", style = MaterialTheme.typography.titleMedium)
        Text("通知只做提醒，不会替你自动完成公司的实际打卡。")
        Spacer(Modifier.height(12.dp))
        if (events.isEmpty()) Text("暂无提醒记录，启动定位后到指定地点测试")
        events.forEach { e ->
            ElevatedCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp)) {
                    Text(e.title, style = MaterialTheme.typography.titleMedium)
                    Text(e.detail)
                    Text(dateFormat.format(Date(e.timestamp)) +
                        (if (e.completed) " · 已确认" else " · 待确认"),
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (!e.completed) {
                        TextButton(onClick = {
                            DataStore.markCompleted(activity, e.id)
                            refresh()
                        }) { Text("标记已完成") }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}
