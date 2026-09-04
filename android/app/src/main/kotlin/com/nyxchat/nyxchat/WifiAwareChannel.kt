package com.nyxchat.nyxchat

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.aware.AttachCallback
import android.net.wifi.aware.DiscoverySession
import android.net.wifi.aware.DiscoverySessionCallback
import android.net.wifi.aware.PeerHandle
import android.net.wifi.aware.PublishConfig
import android.net.wifi.aware.PublishDiscoverySession
import android.net.wifi.aware.SubscribeConfig
import android.net.wifi.aware.SubscribeDiscoverySession
import android.net.wifi.aware.WifiAwareManager
import android.net.wifi.aware.WifiAwareNetworkInfo
import android.net.wifi.aware.WifiAwareNetworkSpecifier
import android.net.wifi.aware.WifiAwareSession
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.net.Inet6Address
import java.net.NetworkInterface
import java.security.SecureRandom

/**
 * Wi-Fi Aware (NAN) discovery and data paths for the NyxChat mesh.
 *
 * Publishes the service "nyxchat" with the current discovery beacon as its
 * service-specific info and subscribes for the same service. Every peer,
 * whether found by our subscriber or asking our publisher for a link, is
 * reported to Dart together with its beacon bytes. Dart decides whether the
 * beacon belongs to a contact (or a public handle) before any data path is
 * built, so a stranger gets nothing but the same rotating beacon it can
 * already see over BLE.
 *
 * Data path. The subscriber sends a REQ message (protocol version, its TCP
 * listening port, a random passphrase, its own beacon). If Dart accepts, the
 * publisher requests the responder network (passphrase, and its port on
 * API 29+) and answers ACK with its port; the subscriber then requests the
 * initiator network with the same passphrase. Once the link is up each side
 * learns the peer's link-local IPv6 address (WifiAwareNetworkInfo on API 29+,
 * an ADDR message carrying our own address on every level) and emits a
 * `path` event {address, port, iface, ifaceIndex}. Dart dials the regular
 * authenticated NyxChat handshake over that address.
 *
 * Everything is a no-op with an "unsupported" result on devices without the
 * android.hardware.wifi.aware feature or below API 26.
 *
 * Dart side: lib/core/network/wifi_aware_manager.dart
 */
class WifiAwareChannel(private val context: Context) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "nyxchat/wifi_aware"
        const val EVENT_CHANNEL = "nyxchat/wifi_aware/events"
        const val SERVICE_NAME = "nyxchat"
        private const val MSG_REQ: Byte = 1
        private const val MSG_ACK: Byte = 2
        private const val MSG_ADDR: Byte = 3
        private const val MSG_NACK: Byte = 4
        private const val MSG_VERSION: Byte = 1
        private const val MAX_BEACON = 64
        private const val PASSPHRASE_LENGTH = 16
        private const val PASSPHRASE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789"
        private const val PATH_TIMEOUT_MS = 30_000
        private const val REQUEST_TIMEOUT_MS = 20_000L
        private const val RETRY_DELAY_MS = 3_000L
    }

    /** One remote peer handle, valid only in the session it was seen on. */
    private class PeerEntry(val id: Int, val handle: PeerHandle, val fromPublish: Boolean) {
        var beacon: ByteArray = ByteArray(0)
        var passphrase: String? = null
        var peerPort = 0
        var peerAddress: String? = null
        var iface: String? = null
        var ifaceIndex = 0
        var network: Network? = null
        var callback: ConnectivityManager.NetworkCallback? = null
        var accepted = false
        var addrSent = false
        var pathEmitted = false
        var timeout: Runnable? = null
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val random = SecureRandom()
    private var events: EventChannel.EventSink? = null
    private var session: WifiAwareSession? = null
    private var publish: PublishDiscoverySession? = null
    private var subscribe: SubscribeDiscoverySession? = null
    private var receiver: BroadcastReceiver? = null
    private var retry: Runnable? = null
    private var beacon: ByteArray = ByteArray(0)
    private var listeningPort = 0
    private var running = false
    private var attaching = false
    private var nextPeerId = 1
    private val peers = HashMap<Int, PeerEntry>()

    private val manager: WifiAwareManager?
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            context.getSystemService(Context.WIFI_AWARE_SERVICE) as? WifiAwareManager
        else null
    private val connectivity: ConnectivityManager?
        get() = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

    // MethodChannel / EventChannel

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "status" -> result.success(status())
                "start" -> {
                    if (!isSupported()) {
                        result.error("unsupported", "Wi-Fi Aware is not available on this device", null)
                        return
                    }
                    if (!hasDiscoveryPermission()) {
                        result.error("permission", "nearby devices / location permission not granted", null)
                        return
                    }
                    beacon = (call.argument<ByteArray>("beacon") ?: ByteArray(0)).take(MAX_BEACON).toByteArray()
                    listeningPort = call.argument<Int>("port") ?: 0
                    result.success(start())
                }
                "updateBeacon" -> {
                    beacon = (call.argument<ByteArray>("beacon") ?: ByteArray(0)).take(MAX_BEACON).toByteArray()
                    result.success(updateBeacon())
                }
                "openPath" -> result.success(openPath(call.argument<Int>("peer") ?: -1))
                "closePath" -> {
                    closePath(call.argument<Int>("peer") ?: -1)
                    result.success(true)
                }
                "stop" -> {
                    stop()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
        } catch (e: Exception) {
            result.error("aware", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { events = sink }
    override fun onCancel(arguments: Any?) { events = null }

    /** Called from the activity when it is destroyed. */
    fun release() { stop() }

    private fun emit(map: Map<String, Any?>) {
        mainHandler.post { events?.success(map) }
    }

    private fun emitState() {
        emit(mapOf(
            "type" to "state",
            "supported" to isSupported(),
            "available" to (manager?.isAvailable ?: false),
            "attached" to (session != null),
            "publishing" to (publish != null),
            "subscribing" to (subscribe != null),
            "paths" to peers.values.count { it.network != null },
        ))
    }

    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_WIFI_AWARE) &&
            manager != null

    /** Publish/subscribe need NEARBY_WIFI_DEVICES on 13+, fine location before. */
    private fun hasDiscoveryPermission(): Boolean {
        val permission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            Manifest.permission.NEARBY_WIFI_DEVICES else Manifest.permission.ACCESS_FINE_LOCATION
        return ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED
    }

    private fun status(): Map<String, Any?> = mapOf(
        "supported" to isSupported(),
        "available" to (manager?.isAvailable ?: false),
        "attached" to (session != null),
        "running" to running,
        "paths" to peers.values.count { it.network != null },
    )
    // Lifecycle

    private fun start(): Boolean {
        val m = manager ?: return false
        if (running) return true
        running = true
        registerReceiver()
        if (m.isAvailable) attach() else emitState() // attaches when Wi-Fi comes up
        return true
    }

    private fun stop() {
        running = false
        cancelRetry()
        dropSessions()
        receiver?.let {
            try { context.unregisterReceiver(it) } catch (_: Exception) {}
        }
        receiver = null
        emitState()
    }

    private fun attach() {
        val m = manager ?: return
        if (session != null || attaching || !running) return
        attaching = true
        m.attach(object : AttachCallback() {
            override fun onAttached(s: WifiAwareSession) {
                attaching = false
                if (!running) {
                    s.close()
                    return
                }
                session = s
                startPublish()
                startSubscribe()
                emitState()
            }

            override fun onAttachFailed() {
                attaching = false
                emitState()
                scheduleRetry()
            }

            // Aware went away underneath us (Wi-Fi off, airplane mode, resource
            // contention): everything built on the session is gone.
            override fun onAwareSessionTerminated() {
                attaching = false
                dropSessions()
                emitState()
                scheduleRetry()
            }
        }, mainHandler)
    }

    private fun scheduleRetry() {
        cancelRetry()
        val r = Runnable {
            retry = null
            if (!running || session == null) {
                if (running && manager?.isAvailable == true) attach()
            } else {
                if (publish == null) startPublish()
                if (subscribe == null) startSubscribe()
            }
        }
        retry = r
        mainHandler.postDelayed(r, RETRY_DELAY_MS)
    }

    private fun cancelRetry() {
        retry?.let { mainHandler.removeCallbacks(it) }
        retry = null
    }

    private fun registerReceiver() {
        if (receiver != null) return
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, intent: Intent?) {
                val m = manager ?: return
                if (m.isAvailable) {
                    if (running && session == null) attach()
                } else {
                    dropSessions()
                }
                emitState()
            }
        }
        receiver = r
        val filter = IntentFilter(WifiAwareManager.ACTION_WIFI_AWARE_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            context.registerReceiver(r, filter)
        }
    }

    private fun publishConfig(): PublishConfig = PublishConfig.Builder()
        .setServiceName(SERVICE_NAME)
        .setServiceSpecificInfo(beacon)
        .setPublishType(PublishConfig.PUBLISH_TYPE_UNSOLICITED)
        .setTerminateNotificationEnabled(true)
        .build()

    private fun startPublish() {
        val s = session ?: return
        try {
            s.publish(publishConfig(), publishCallback, mainHandler)
        } catch (e: Exception) {
            emitError("publish: ${e.message}")
        }
    }

    private fun startSubscribe() {
        val s = session ?: return
        val config = SubscribeConfig.Builder()
            .setServiceName(SERVICE_NAME)
            .setSubscribeType(SubscribeConfig.SUBSCRIBE_TYPE_PASSIVE)
            .setTerminateNotificationEnabled(true)
            .build()
        try {
            s.subscribe(config, subscribeCallback, mainHandler)
        } catch (e: Exception) {
            emitError("subscribe: ${e.message}")
        }
    }

    /**
     * Re-publish with the rotated beacon. A passive subscriber is not
     * guaranteed to hear again about a publisher whose info changed, so while
     * no path is in use the subscription is renewed as well; entries that
     * belonged to the old subscribe session are reported lost.
     */
    private fun updateBeacon(): Boolean {
        val p = publish ?: return false
        p.updatePublish(publishConfig())
        if (peers.values.none { it.network != null || it.accepted }) {
            val stale = peers.values.filter { !it.fromPublish }
            for (e in stale) dropPeer(e, notify = true)
            subscribe?.close()
            subscribe = null
            startSubscribe()
        }
        return true
    }

    private val publishCallback = object : DiscoverySessionCallback() {
        override fun onPublishStarted(s: PublishDiscoverySession) {
            publish = s
            emitState()
        }

        override fun onSessionConfigFailed() { emitError("publish config refused") }

        override fun onSessionTerminated() {
            publish = null
            for (e in peers.values.filter { it.fromPublish }) dropPeer(e, notify = true)
            emitState()
            if (running && session != null) scheduleRetry()
        }

        override fun onMessageReceived(peerHandle: PeerHandle, message: ByteArray?) {
            onMessage(peerHandle, message ?: return, fromPublish = true)
        }

        override fun onMessageSendFailed(messageId: Int) { onSendFailed(messageId) }
    }

    private val subscribeCallback = object : DiscoverySessionCallback() {
        override fun onSubscribeStarted(s: SubscribeDiscoverySession) {
            subscribe = s
            emitState()
        }

        override fun onSessionConfigFailed() { emitError("subscribe config refused") }

        override fun onSessionTerminated() {
            subscribe = null
            for (e in peers.values.filter { !it.fromPublish }) dropPeer(e, notify = true)
            emitState()
            if (running && session != null) scheduleRetry()
        }

        override fun onServiceDiscovered(
            peerHandle: PeerHandle, serviceSpecificInfo: ByteArray?, matchFilter: MutableList<ByteArray>?
        ) {
            val entry = findEntry(peerHandle, fromPublish = false) ?: newEntry(peerHandle, fromPublish = false)
            entry.beacon = serviceSpecificInfo ?: ByteArray(0)
            emit(mapOf("type" to "discovered", "peer" to entry.id, "beacon" to entry.beacon, "role" to "subscriber"))
        }

        override fun onServiceLost(peerHandle: PeerHandle, reason: Int) {
            val e = findEntry(peerHandle, fromPublish = false) ?: return
            if (e.network == null) dropPeer(e, notify = true)
        }

        override fun onMessageReceived(peerHandle: PeerHandle, message: ByteArray?) {
            onMessage(peerHandle, message ?: return, fromPublish = false)
        }

        override fun onMessageSendFailed(messageId: Int) { onSendFailed(messageId) }
    }

    private fun onSendFailed(messageId: Int) {
        val e = peers[messageId] ?: return
        if (e.network == null) dropPeer(e, notify = true)
    }

    private fun dropSessions() {
        for (e in peers.values.toList()) dropPeer(e, notify = true)
        try { publish?.close() } catch (_: Exception) {}
        try { subscribe?.close() } catch (_: Exception) {}
        publish = null
        subscribe = null
        try { session?.close() } catch (_: Exception) {}
        session = null
        attaching = false
    }
    // NAN messages
    //
    //   REQ  [1, version, port(2), passLen, passphrase, beacon]  subscriber -> publisher
    //   ACK  [2, port(2)]                                        publisher -> subscriber
    //   ADDR [3, ipv6(16), port(2)]                              own link-local address, both ways
    //   NACK [4]                                                 publisher refuses

    private fun onMessage(handle: PeerHandle, msg: ByteArray, fromPublish: Boolean) {
        if (msg.isEmpty()) return
        when (msg[0]) {
            MSG_REQ -> if (fromPublish) onLinkRequest(handle, msg)
            MSG_ACK -> if (!fromPublish) onAck(handle, msg)
            MSG_ADDR -> onAddr(handle, msg, fromPublish)
            MSG_NACK -> findEntry(handle, fromPublish)?.let { dropPeer(it, notify = true) }
        }
    }

    private fun onLinkRequest(handle: PeerHandle, msg: ByteArray) {
        if (msg.size < 5 || msg[1] != MSG_VERSION) return
        val port = readPort(msg, 2)
        val passLen = msg[4].toInt() and 0xff
        if (passLen < 8 || passLen > 63 || msg.size < 5 + passLen) return
        val existing = findEntry(handle, fromPublish = true)
        val entry = if (existing != null && existing.network == null && !existing.accepted) existing
        else {
            existing?.let { dropPeer(it, notify = true) }
            newEntry(handle, fromPublish = true)
        }
        entry.passphrase = String(msg, 5, passLen, Charsets.US_ASCII)
        entry.peerPort = port
        entry.beacon = msg.copyOfRange(5 + passLen, msg.size)
        // Dart resolves the beacon and answers with openPath or closePath.
        armTimeout(entry)
        emit(mapOf("type" to "discovered", "peer" to entry.id, "beacon" to entry.beacon, "role" to "publisher"))
    }

    private fun onAck(handle: PeerHandle, msg: ByteArray) {
        val entry = findEntry(handle, fromPublish = false) ?: return
        val pass = entry.passphrase ?: return
        val s = subscribe ?: return
        if (msg.size >= 3) entry.peerPort = readPort(msg, 1)
        entry.accepted = true
        requestNetwork(entry, s, pass, responder = false)
    }

    private fun onAddr(handle: PeerHandle, msg: ByteArray, fromPublish: Boolean) {
        if (msg.size < 19) return
        val entry = findEntry(handle, fromPublish) ?: return
        val addr = try {
            Inet6Address.getByAddress(null, msg.copyOfRange(1, 17)) as? Inet6Address
        } catch (_: Exception) { null } ?: return
        entry.peerAddress = plainAddress(addr)
        val port = readPort(msg, 17)
        if (port > 0) entry.peerPort = port
        maybeEmitPath(entry)
    }

    /** Dart accepted this peer: ask for a link (subscriber) or answer one (publisher). */
    private fun openPath(id: Int): Boolean {
        val entry = peers[id] ?: return false
        if (entry.callback != null) return true
        return if (entry.fromPublish) acceptRequest(entry) else sendRequest(entry)
    }

    /** Dart declined (or is done with) this peer. */
    private fun closePath(id: Int) {
        val entry = peers[id] ?: return
        if (entry.fromPublish && !entry.accepted) {
            try { publish?.sendMessage(entry.handle, entry.id, byteArrayOf(MSG_NACK)) } catch (_: Exception) {}
        }
        dropPeer(entry, notify = false)
    }

    private fun sendRequest(entry: PeerEntry): Boolean {
        val s = subscribe ?: return false
        val pass = randomPassphrase()
        entry.passphrase = pass
        val passBytes = pass.toByteArray(Charsets.US_ASCII)
        val msg = ByteArray(5 + passBytes.size + beacon.size)
        msg[0] = MSG_REQ
        msg[1] = MSG_VERSION
        writePort(msg, 2, listeningPort)
        msg[4] = passBytes.size.toByte()
        System.arraycopy(passBytes, 0, msg, 5, passBytes.size)
        System.arraycopy(beacon, 0, msg, 5 + passBytes.size, beacon.size)
        s.sendMessage(entry.handle, entry.id, msg)
        armTimeout(entry)
        return true
    }

    private fun acceptRequest(entry: PeerEntry): Boolean {
        val p = publish ?: return false
        val pass = entry.passphrase ?: return false
        entry.accepted = true
        // Responder first, so the initiator's request finds it waiting.
        if (!requestNetwork(entry, p, pass, responder = true)) return false
        val ack = ByteArray(3)
        ack[0] = MSG_ACK
        writePort(ack, 1, listeningPort)
        p.sendMessage(entry.handle, entry.id, ack)
        armTimeout(entry)
        return true
    }

    // Data path

    @Suppress("DEPRECATION")
    private fun requestNetwork(entry: PeerEntry, session: DiscoverySession, pass: String, responder: Boolean): Boolean {
        val cm = connectivity ?: return false
        val specifier = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val b = WifiAwareNetworkSpecifier.Builder(session, entry.handle).setPskPassphrase(pass)
            if (responder && listeningPort in 1..65535) b.setPort(listeningPort)
            b.build()
        } else {
            // Below 29 there is no port in the specifier; it travels in ACK/ADDR.
            session.createNetworkSpecifierPassphrase(entry.handle, pass)
        }
        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI_AWARE)
            .setNetworkSpecifier(specifier)
            .build()
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                entry.network = network
                emitState()
            }

            override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                entry.network = network
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val info = caps.transportInfo as? WifiAwareNetworkInfo
                    info?.peerIpv6Addr?.let { entry.peerAddress = plainAddress(it) }
                    if (info != null && info.port > 0) entry.peerPort = info.port
                }
                maybeEmitPath(entry)
            }

            override fun onLinkPropertiesChanged(network: Network, lp: LinkProperties) {
                entry.network = network
                entry.iface = lp.interfaceName
                entry.ifaceIndex = try {
                    lp.interfaceName?.let { NetworkInterface.getByName(it)?.index } ?: 0
                } catch (_: Exception) { 0 }
                sendAddress(entry, lp)
                maybeEmitPath(entry)
            }

            override fun onLost(network: Network) { dropPeer(entry, notify = true) }
            override fun onUnavailable() { dropPeer(entry, notify = true) }
        }
        entry.callback = callback
        return try {
            cm.requestNetwork(request, callback, mainHandler, PATH_TIMEOUT_MS)
            true
        } catch (e: Exception) {
            entry.callback = null
            emitError("requestNetwork: ${e.message}")
            false
        }
    }

    /** Tell the peer our link-local address on the Aware interface (needed below API 29). */
    private fun sendAddress(entry: PeerEntry, lp: LinkProperties) {
        if (entry.addrSent) return
        val own = lp.linkAddresses.map { it.address }.filterIsInstance<Inet6Address>()
            .firstOrNull { it.isLinkLocalAddress } ?: return
        val s: DiscoverySession = (if (entry.fromPublish) publish else subscribe) ?: return
        val msg = ByteArray(19)
        msg[0] = MSG_ADDR
        System.arraycopy(own.address, 0, msg, 1, 16)
        writePort(msg, 17, listeningPort)
        try {
            s.sendMessage(entry.handle, entry.id, msg)
            entry.addrSent = true
        } catch (_: Exception) {}
    }

    private fun maybeEmitPath(entry: PeerEntry) {
        if (entry.pathEmitted || entry.network == null) return
        val addr = entry.peerAddress ?: return
        val iface = entry.iface ?: return
        if (entry.peerPort <= 0) return
        entry.pathEmitted = true
        clearTimeout(entry)
        emit(mapOf(
            "type" to "path", "peer" to entry.id, "address" to addr, "port" to entry.peerPort,
            "iface" to iface, "ifaceIndex" to entry.ifaceIndex,
        ))
        emitState()
    }

    private fun dropPeer(entry: PeerEntry, notify: Boolean) {
        clearTimeout(entry)
        entry.callback?.let {
            try { connectivity?.unregisterNetworkCallback(it) } catch (_: Exception) {}
        }
        entry.callback = null
        entry.network = null
        if (peers.remove(entry.id) != null && notify) emit(mapOf("type" to "lost", "peer" to entry.id))
        emitState()
    }

    // Helpers

    private fun findEntry(handle: PeerHandle, fromPublish: Boolean): PeerEntry? =
        peers.values.firstOrNull { it.fromPublish == fromPublish && it.handle == handle }

    private fun newEntry(handle: PeerHandle, fromPublish: Boolean): PeerEntry {
        val e = PeerEntry(nextPeerId++, handle, fromPublish)
        peers[e.id] = e
        return e
    }

    private fun armTimeout(entry: PeerEntry) {
        clearTimeout(entry)
        val r = Runnable {
            entry.timeout = null
            if (!entry.pathEmitted) dropPeer(entry, notify = true)
        }
        entry.timeout = r
        mainHandler.postDelayed(r, REQUEST_TIMEOUT_MS)
    }

    private fun clearTimeout(entry: PeerEntry) {
        entry.timeout?.let { mainHandler.removeCallbacks(it) }
        entry.timeout = null
    }

    private fun emitError(message: String) = emit(mapOf("type" to "error", "message" to message))

    private fun randomPassphrase(): String {
        val sb = StringBuilder(PASSPHRASE_LENGTH)
        repeat(PASSPHRASE_LENGTH) { sb.append(PASSPHRASE_CHARS[random.nextInt(PASSPHRASE_CHARS.length)]) }
        return sb.toString()
    }

    private fun plainAddress(addr: Inet6Address): String = (addr.hostAddress ?: "").substringBefore('%')

    private fun readPort(b: ByteArray, at: Int): Int = ((b[at].toInt() and 0xff) shl 8) or (b[at + 1].toInt() and 0xff)

    private fun writePort(b: ByteArray, at: Int, port: Int) {
        b[at] = (port shr 8).toByte()
        b[at + 1] = port.toByte()
    }
}