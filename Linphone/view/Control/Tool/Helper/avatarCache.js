// =============================================================================
// Gastecom fix (2026-09-30): cache corta (TTL) para las 4 llamadas de UtilsCpp
// que Avatar.qml/ChatListView.qml hacian sin cache por cada avatar pintado o
// reciclado. Cada llamada crea un VariantObject (2 QObject, viaje asincrono al
// hilo Linphone) - en scroll por listas de cientos de contactos LDAP eran
// cientos de objetos/colas de eventos por segundo solo para pintar avatares.
// Ver RENDIMIENTO.md.
//
// Los VariantObject que devuelve UtilsCpp son de un solo uso (requestValue()
// se llama una vez, en el constructor; no hay push de cambios en caliente si
// el contacto se edita despues), asi que reusar el MISMO objeto para la MISMA
// direccion durante un rato corto no cambia el dato que se ve, solo evita
// repetir la peticion mientras ese avatar sigue visible/reciclandose en la
// misma sesion de scroll. TTL corto (4s) en vez de cache indefinida: si el
// contacto se edita, el proximo scroll ya trae el valor fresco sin esperar a
// un reinicio de la app.
//
// Propiedad del objeto devuelto: VariantObject se crea con `new VariantObject(...)`
// sin padre (ver model/object/VariantObject.cpp) y sin setObjectOwnership propio,
// asi que QML le da JavaScriptOwnership - el motor JS lo recolecta cuando no
// queda ninguna referencia JS viva. Guardarlo aqui, en un modulo .pragma library
// (que vive en el mismo motor JS que las bindings de QML), es seguro: mientras
// esta en el mapa de cache sigue habiendo una referencia JS y no se libera.
// =============================================================================

.pragma library

.import UtilsCpp 1.0 as UtilsCppModule

// 2026-10-14: en un .import de JS el calificador es el MODULO, no el singleton
// (registrado en App.cpp como qmlRegisterSingletonType("UtilsCpp", 1, 0,
// "UtilsCpp")). Con `UtilsCpp.getDisplayName(...)` daba "is not a function" y
// los contactos salian sin nombre ni avatar.
var UtilsCpp = UtilsCppModule.UtilsCpp

var _cache = {}
var _ttlMs = 4000

function _get(kind, address, compute) {
	if (!address) return compute()
	var key = kind + "|" + address
	var entry = _cache[key]
	var now = Date.now()
	if (entry && (now - entry.time) < _ttlMs) {
		return entry.value
	}
	var value = compute()
	_cache[key] = { value: value, time: now }
	_prune(now)
	return value
}

// 2026-10-14: sin esto la cache solo crecia (una entrada por direccion distinta
// vista en toda la sesion). Barrido de caducadas como mucho cada _ttlMs.
var _lastPrune = 0
function _prune(now) {
	if (now - _lastPrune < _ttlMs) return
	_lastPrune = now
	for (var k in _cache) {
		if (now - _cache[k].time >= _ttlMs) delete _cache[k]
	}
}

function getDisplayName(address) {
	return _get("displayName", address, function () { return UtilsCpp.getDisplayName(address) })
}

function findAvatarByAddress(address) {
	return _get("avatar", address, function () { return UtilsCpp.findAvatarByAddress(address) })
}

function getFriendSecurityLevel(address) {
	return _get("friendSecurityLevel", address, function () { return UtilsCpp.getFriendSecurityLevel(address) })
}

function getFriendAddressSecurityLevel(address) {
	return _get("addressSecurityLevel", address, function () { return UtilsCpp.getFriendAddressSecurityLevel(address) })
}

function findFriendByAddress(address) {
	return _get("friend", address, function () { return UtilsCpp.findFriendByAddress(address) })
}
