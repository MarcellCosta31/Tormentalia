import { createSocket } from '@isvend/expo-udp';

const DISCOVERY_PORT = 4445;
const DISCOVERY_MESSAGE = 'OCARO_ROOM';
const BROADCAST_INTERVAL = 2000;
const ROOM_TIMEOUT = 6000;

let broadcastSocket = null;
let listenSocket = null;
let broadcastTimer = null;
let onRoomsFound = null;
const discoveredRooms = new Map();

export async function startBroadcast(hostName, ip, playerCount = 1) {
  stopBroadcast();

  broadcastSocket = await createSocket({ type: 'udp4', reuseAddress: true, broadcast: true });
  await broadcastSocket.bind({ port: 0, address: '0.0.0.0' });

  const message = JSON.stringify({
    type: DISCOVERY_MESSAGE,
    hostName,
    ip,
    playerCount,
    maxPlayers: 2,
    timestamp: Date.now(),
  });

  broadcastTimer = setInterval(() => {
    if (broadcastSocket) {
      broadcastSocket.send(message, { host: '255.255.255.255', port: DISCOVERY_PORT });
    }
  }, BROADCAST_INTERVAL);

  broadcastSocket.send(message, { host: '255.255.255.255', port: DISCOVERY_PORT });
}

export function stopBroadcast() {
  if (broadcastTimer) {
    clearInterval(broadcastTimer);
    broadcastTimer = null;
  }
  if (broadcastSocket) {
    broadcastSocket.close();
    broadcastSocket = null;
  }
}

export async function startListening(callback) {
  stopListening();

  onRoomsFound = callback;
  listenSocket = await createSocket({ type: 'udp4', reuseAddress: true });
  await listenSocket.bind({ port: DISCOVERY_PORT, address: '0.0.0.0' });

  listenSocket.addListener('message', (event) => {
    try {
      const bytes = event.data instanceof Uint8Array ? event.data : new Uint8Array(event.data);
      const text = new TextDecoder().decode(bytes);
      const data = JSON.parse(text);
      if (data.type === DISCOVERY_MESSAGE) {
        const roomKey = `${data.ip}:${DISCOVERY_PORT}`;
        discoveredRooms.set(roomKey, {
          hostName: data.hostName,
          ip: data.ip,
          playerCount: data.playerCount,
          maxPlayers: data.maxPlayers,
          lastSeen: Date.now(),
        });
        if (onRoomsFound) {
          onRoomsFound(getRooms());
        }
      }
    } catch (e) {
      console.warn('[Discovery] Mensagem invalida ignorada:', e.message);
    }
  });
}

export function stopListening() {
  if (listenSocket) {
    listenSocket.close();
    listenSocket = null;
  }
  onRoomsFound = null;
  discoveredRooms.clear();
}

export function getRooms() {
  const now = Date.now();
  for (const [key, room] of discoveredRooms.entries()) {
    if (now - room.lastSeen > ROOM_TIMEOUT) {
      discoveredRooms.delete(key);
    }
  }
  return Array.from(discoveredRooms.values());
}

export function cleanExpiredRooms() {
  const now = Date.now();
  let changed = false;
  for (const [key, room] of discoveredRooms.entries()) {
    if (now - room.lastSeen > ROOM_TIMEOUT) {
      discoveredRooms.delete(key);
      changed = true;
    }
  }
  if (changed && onRoomsFound) {
    onRoomsFound(getRooms());
  }
}
