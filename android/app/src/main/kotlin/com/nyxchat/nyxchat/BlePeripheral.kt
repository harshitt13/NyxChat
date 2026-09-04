package com.nyxchat.nyxchat

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * BLE peripheral role for the NyxChat mesh.
 *
 * Advertises the NyxChat service UUID (+ the NyxChat id in the scan
 * response manufacturer data) and hosts a GATT server with:
 *  - TX characteristic: centrals WRITE chunks to us
 *  - RX characteristic: we NOTIFY chunks to subscribed centrals
 *
 * Dart side: lib/core/network/ble_peripheral.dart
 */
class BlePeripheral(private val context: Context) : MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL = "nyxchat/ble_peripheral"
        const val EVENT_CHANNEL = "nyxchat/ble_peripheral/events"
        val SERVICE_UUID: UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef0123456789")
        val TX_UUID: UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef01234567aa")
        val RX_UUID: UUID = UUID.fromString("a1b2c3d4-e5f6-7890-abcd-ef01234567bb")
        val CCCD_UUID: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
        const val MANUFACTURER_ID = 0x4E58
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var events: EventChannel.EventSink? = null
    private var gattServer: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null
    private var rxCharacteristic: BluetoothGattCharacteristic? = null
    private val subscribed = HashSet<String>()
    private val devices = HashMap<String, BluetoothDevice>()
    private var advertising = false

    private val manager: BluetoothManager?
        get() = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter?
        get() = manager?.adapter

    override fun onMethodCall(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "start" -> {
                    val nyxId = call.argument<String>("nyxId") ?: ""
                    result.success(start(nyxId))
                }
                "stop" -> { stop(); result.success(true) }
                "notify" -> {
                    val address = call.argument<String>("address") ?: ""
                    val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                    result.success(notifyCentral(address, data))
                }
                "isAdvertising" -> result.success(advertising)
                "subscribers" -> result.success(subscribed.toList())
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("permission", e.message, null)
        } catch (e: Exception) {
            result.error("ble", e.message, null)
        }
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) { events = sink }
    override fun onCancel(arguments: Any?) { events = null }

    private fun emit(type: String, address: String, data: ByteArray? = null) {
        mainHandler.post {
            val map = HashMap<String, Any?>()
            map["type"] = type
            map["address"] = address
            if (data != null) map["data"] = data
            events?.success(map)
        }
    }

    private fun isSupported(): Boolean {
        val a = adapter ?: return false
        return a.isEnabled && a.isMultipleAdvertisementSupported && a.bluetoothLeAdvertiser != null
    }

    @Suppress("MissingPermission")
    private fun start(nyxId: String): Boolean {
        if (advertising) return true
        val a = adapter ?: return false
        if (!a.isEnabled) return false
        val server = manager?.openGattServer(context, serverCallback) ?: return false
        gattServer = server

        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val tx = BluetoothGattCharacteristic(
            TX_UUID,
            BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE,
            BluetoothGattCharacteristic.PERMISSION_WRITE
        )
        val rx = BluetoothGattCharacteristic(
            RX_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_READ
        )
        rx.addDescriptor(
            BluetoothGattDescriptor(
                CCCD_UUID,
                BluetoothGattDescriptor.PERMISSION_READ or BluetoothGattDescriptor.PERMISSION_WRITE
            )
        )
        service.addCharacteristic(tx)
        service.addCharacteristic(rx)
        rxCharacteristic = rx
        server.addService(service)

        val adv = a.bluetoothLeAdvertiser ?: return false
        advertiser = adv
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .setTimeout(0)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()
        // The NyxChat id (<= 24 bytes) rides in the scan response so the
        // 31-byte primary advertisement keeps room for the 128-bit UUID.
        val idBytes = nyxId.toByteArray(Charsets.UTF_8).take(24).toByteArray()
        val scanResponse = AdvertiseData.Builder()
            .addManufacturerData(MANUFACTURER_ID, idBytes)
            .build()
        adv.startAdvertising(settings, data, scanResponse, advertiseCallback)
        advertising = true
        return true
    }

    @Suppress("MissingPermission")
    private fun stop() {
        try { advertiser?.stopAdvertising(advertiseCallback) } catch (_: Exception) {}
        try { gattServer?.close() } catch (_: Exception) {}
        gattServer = null
        advertiser = null
        rxCharacteristic = null
        subscribed.clear()
        devices.clear()
        advertising = false
    }

    @Suppress("MissingPermission")
    private fun notifyCentral(address: String, data: ByteArray): Boolean {
        val server = gattServer ?: return false
        val rx = rxCharacteristic ?: return false
        val device = devices[address] ?: return false
        if (!subscribed.contains(address)) return false
        rx.value = data
        return server.notifyCharacteristicChanged(device, rx, false)
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            emit("advertising", "", null)
        }
        override fun onStartFailure(errorCode: Int) {
            advertising = false
            emit("advertiseFailed", errorCode.toString(), null)
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        @Suppress("MissingPermission")
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            val address = device.address
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                devices[address] = device
                emit("connected", address)
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                devices.remove(address)
                subscribed.remove(address)
                emit("disconnected", address)
            }
        }

        @Suppress("MissingPermission")
        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice, requestId: Int, characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray?
        ) {
            if (characteristic.uuid == TX_UUID && value != null) {
                devices[device.address] = device
                emit("write", device.address, value)
            }
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
        }

        @Suppress("MissingPermission")
        override fun onDescriptorWriteRequest(
            device: BluetoothDevice, requestId: Int, descriptor: BluetoothGattDescriptor,
            preparedWrite: Boolean, responseNeeded: Boolean, offset: Int, value: ByteArray?
        ) {
            if (descriptor.uuid == CCCD_UUID) {
                val enable = value != null && value.isNotEmpty() && (value[0].toInt() and 0x01) != 0
                if (enable) {
                    devices[device.address] = device
                    subscribed.add(device.address)
                    emit("subscribed", device.address)
                } else {
                    subscribed.remove(device.address)
                    emit("unsubscribed", device.address)
                }
            }
            if (responseNeeded) {
                gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
            }
        }

        @Suppress("MissingPermission")
        override fun onDescriptorReadRequest(
            device: BluetoothDevice, requestId: Int, offset: Int, descriptor: BluetoothGattDescriptor
        ) {
            val value = if (subscribed.contains(device.address))
                BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            else BluetoothGattDescriptor.DISABLE_NOTIFICATION_VALUE
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, value)
        }

        @Suppress("MissingPermission")
        override fun onCharacteristicReadRequest(
            device: BluetoothDevice, requestId: Int, offset: Int, characteristic: BluetoothGattCharacteristic
        ) {
            gattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, ByteArray(0))
        }

        @Suppress("MissingPermission")
        override fun onMtuChanged(device: BluetoothDevice, mtu: Int) {
            emit("mtu", device.address, byteArrayOf((mtu shr 8).toByte(), (mtu and 0xff).toByte()))
        }
    }
}