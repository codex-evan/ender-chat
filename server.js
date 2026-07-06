const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const PORT = Number(process.env.PORT) || 4173;
const HOST = process.env.HOST || "127.0.0.1";
const root = __dirname;
const clients = new Map();
const archivedMessages = [];
const ARCHIVE_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

const files = {
  "/": ["index.html", "text/html; charset=utf-8"],
  "/index.html": ["index.html", "text/html; charset=utf-8"],
  "/styles.css": ["styles.css", "text/css; charset=utf-8"],
  "/app.js": ["app.js", "text/javascript; charset=utf-8"],
};

function validRoomCode(code) {
  return typeof code === "string" && /^\d{4}$/.test(code);
}

function safeId(value, max) {
  max = max || 96;
  return typeof value === "string" && /^[a-zA-Z0-9_-]+$/.test(value) && value.length <= max;
}

function roomClients(room) {
  if (!clients.has(room)) clients.set(room, new Map());
  return clients.get(room);
}

function sendSse(res, event, data) {
  if (res.writableEnded) return;
  res.write("event: " + event + "\ndata: " + JSON.stringify(data) + "\n\n");
}

function broadcast(room, exceptPeer, event, data) {
  for (const [peer, res] of roomClients(room)) {
    if (peer !== exceptPeer) sendSse(res, event, data);
  }
}

function json(res, status, body) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
    "X-Frame-Options": "DENY",
  });
  res.end(JSON.stringify(body));
}

function archiveEncryptedMessage(room, peerId, encryptedData, msgType) {
  archivedMessages.push({
    id: crypto.randomUUID ? crypto.randomUUID() : peerId + "_" + Date.now(),
    room: room,
    peerId: peerId,
    encryptedData: encryptedData,
    type: msgType || "message",
    timestamp: Date.now(),
    expiresAt: Date.now() + ARCHIVE_RETENTION_MS,
  });
  while (archivedMessages.length > 0 && archivedMessages[0].expiresAt < Date.now()) {
    archivedMessages.shift();
  }
}

setInterval(function() {
  const now = Date.now();
  let cleaned = 0;
  while (archivedMessages.length > 0 && archivedMessages[0].expiresAt < now) {
    archivedMessages.shift();
    cleaned++;
  }
  if (cleaned > 0) console.log("Cleaned " + cleaned + " expired archives");
}, 3600000);

const server = http.createServer(function(req, res) {
  const url = new URL(req.url, "http://" + (req.headers.host || "localhost"));

  if (req.method === "GET" && files[url.pathname]) {
    const [file, type] = files[url.pathname];
    fs.readFile(path.join(root, file), function(error, data) {
      if (error) return json(res, 500, { error: "Unable to read file." });
      res.writeHead(200, {
        "Content-Type": type,
        "Cache-Control": file === "index.html" ? "no-store" : "public, max-age=300",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
        "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
        "X-Frame-Options": "DENY",
      });
      res.end(data);
    });
    return;
  }

  if (req.method === "GET" && url.pathname === "/events") {
    const room = url.searchParams.get("room");
    const peer = url.searchParams.get("peer");
    if (!validRoomCode(room) || !safeId(peer)) return json(res, 400, { error: "Invalid room or peer." });
    const members = roomClients(room);
    if (!members.has(peer) && members.size >= 2) {
      res.writeHead(200, { "Content-Type": "text/event-stream; charset=utf-8", "Cache-Control": "no-cache, no-transform", Connection: "keep-alive" });
      sendSse(res, "room-full", { message: "Room is full." });
      const ft = setTimeout(function() { res.end(); }, 5000);
      ft.unref();
      res.on("close", function() { clearTimeout(ft); });
      return;
    }
    res.writeHead(200, {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      Connection: "keep-alive",
      "X-Accel-Buffering": "no",
    });
    res.write(": connected\n\n");
    const previous = members.get(peer);
    if (previous && previous !== res) previous.end();
    const peers = [...members.keys()].filter(function(id) { return id !== peer; });
    members.set(peer, res);
    sendSse(res, "ready", { peers: peers });
    broadcast(room, peer, "peer-joined", { peer: peer });
    const ka = setInterval(function() { res.write(": keepalive\n\n"); }, 20000);
    res.on("close", function() {
      clearInterval(ka);
      if (members.get(peer) === res) {
        members.delete(peer);
        broadcast(room, peer, "peer-left", { peer: peer });
      }
      if (members.size === 0) clients.delete(room);
    });
    return;
  }

  if (req.method === "GET" && url.pathname === "/room-status") {
    const room = url.searchParams.get("room");
    if (!validRoomCode(room)) return json(res, 400, { error: "Invalid room." });
    const occ = clients.get(room) ? clients.get(room).size : 0;
    return json(res, 200, { full: occ >= 2, occupancy: occ });
  }

  if (req.method === "POST" && url.pathname === "/signal") {
    let raw = "";
    req.on("data", function(chunk) { raw += chunk; if (raw.length > 256000) req.destroy(); });
    req.on("end", function() {
      try {
        const msg = JSON.parse(raw);
        if (!validRoomCode(msg.room) || !safeId(msg.from) || !safeId(msg.to) || !msg.data) return json(res, 400, { error: "Invalid signal." });
        const target = roomClients(msg.room).get(msg.to);
        if (target) sendSse(target, "signal", { from: msg.from, data: msg.data });
        json(res, 200, { delivered: !!target });
      } catch (e) { json(res, 400, { error: "Malformed JSON." }); }
    });
    return;
  }

  if (req.method === "POST" && url.pathname === "/archive") {
    let raw = "";
    req.on("data", function(chunk) { raw += chunk; if (raw.length > 65536) req.destroy(); });
    req.on("end", function() {
      try {
        const msg = JSON.parse(raw);
        if (!validRoomCode(msg.room) || !safeId(msg.peerId) || !msg.encrypted) return json(res, 400, { error: "Invalid archive data." });
        archiveEncryptedMessage(msg.room, msg.peerId, msg.encrypted, msg.type || "message");
        return json(res, 200, { archived: true });
      } catch (e) { return json(res, 400, { error: "Malformed JSON." }); }
    });
    return;
  }

  if (req.method === "GET" && url.pathname === "/archive") {
    const room = url.searchParams.get("room");
    if (!validRoomCode(room)) return json(res, 400, { error: "Invalid room." });
    const msgs = archivedMessages.filter(function(m) { return m.room === room && m.expiresAt > Date.now(); });
    return json(res, 200, { messages: msgs, count: msgs.length });
  }

  if (req.method === "GET" && url.pathname === "/health") return json(res, 200, { ok: true });
  json(res, 404, { error: "Not found." });
});

server.listen(PORT, HOST, function() {
  console.log("Murmur ready at http://" + HOST + ":" + PORT);
});
process.on("SIGINT", function() { server.close(function() { process.exit(0); }); });
