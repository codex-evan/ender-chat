(() => {
  "use strict";

  const $ = (selector) => document.querySelector(selector);
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  const baseUrl = new URL(".", location.href);
  const endpoint = (name) => new URL(name, baseUrl).toString();
  const roomFromHash = new URLSearchParams(location.hash.slice(1)).get("room");
  const roomId = validId(roomFromHash) ? roomFromHash : randomId(18);
  const peerId = randomId(12);
  if (!roomFromHash) history.replaceState(null, "", `#room=${roomId}`);

  const state = {
    peerConnection: null,
    channel: null,
    remotePeer: null,
    keyPair: null,
    aesKey: null,
    fingerprint: null,
    connected: false,
    typingTimer: null,
    reconnectTimer: null,
    eventSource: null,
  };

  const els = {
    messages: $("#messages"), input: $("#messageInput"), form: $("#messageForm"), send: $("#sendBtn"),
    status: $("#statusText"), statusButton: $("#statusButton"), presence: $("#presenceDot"), banner: $("#connectionBanner"),
    waiting: $("#waitingPill"), inviteModal: $("#inviteModal"), detailsModal: $("#detailsModal"),
    inviteLink: $("#inviteLink"), toast: $("#toast"), typing: $("#typingIndicator"),
    safety: $("#safetyNumber"), detailConnection: $("#detailConnection"),
    preview: $("#sidebarPreview"), previewTime: $("#sidebarTime"), peerName: $("#peerName"), peerAvatar: $("#peerAvatar"),
  };

  function randomId(bytes) {
    return Array.from(crypto.getRandomValues(new Uint8Array(bytes)), (b) => b.toString(36).padStart(2, "0")).join("").slice(0, bytes * 2);
  }

  function validId(value) { return typeof value === "string" && /^[a-zA-Z0-9_-]{8,96}$/.test(value); }
  function b64(bytes) { return btoa(String.fromCharCode(...new Uint8Array(bytes))); }
  function unb64(value) { return Uint8Array.from(atob(value), (char) => char.charCodeAt(0)); }
  function nowTime(date = new Date()) { return date.toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false }); }

  async function makeKeyPair() {
    state.keyPair = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveKey", "deriveBits"]);
  }

  async function exportPublicKey() {
    return b64(await crypto.subtle.exportKey("raw", state.keyPair.publicKey));
  }

  async function acceptRemoteKey(rawPublicKey) {
    const remotePublic = await crypto.subtle.importKey("raw", unb64(rawPublicKey), { name: "ECDH", namedCurve: "P-256" }, false, []);
    state.aesKey = await crypto.subtle.deriveKey(
      { name: "ECDH", public: remotePublic }, state.keyPair.privateKey,
      { name: "AES-GCM", length: 256 }, false, ["encrypt", "decrypt"]
    );
    const localRaw = new Uint8Array(await crypto.subtle.exportKey("raw", state.keyPair.publicKey));
    const remoteRaw = unb64(rawPublicKey);
    const ordered = [localRaw, remoteRaw].sort(compareBytes);
    const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", concat(ordered[0], ordered[1])));
    state.fingerprint = [...digest.slice(0, 6)].map((n) => String(n).padStart(3, "0")).join(" ");
    els.safety.textContent = state.fingerprint;
    setSecure(true);
  }

  function concat(a, b) {
    const output = new Uint8Array(a.length + b.length);
    output.set(a); output.set(b, a.length);
    return output;
  }

  function compareBytes(a, b) {
    for (let index = 0; index < Math.min(a.length, b.length); index += 1) {
      if (a[index] !== b[index]) return a[index] - b[index];
    }
    return a.length - b.length;
  }

  async function encrypt(payload) {
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const cipher = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, state.aesKey, enc.encode(JSON.stringify(payload)));
    return JSON.stringify({ t: "cipher", iv: b64(iv), data: b64(cipher) });
  }

  async function decrypt(packet) {
    const plain = await crypto.subtle.decrypt({ name: "AES-GCM", iv: unb64(packet.iv) }, state.aesKey, unb64(packet.data));
    return JSON.parse(dec.decode(plain));
  }

  async function connectEvents() {
    const roomStatus = await fetch(`${endpoint("room-status")}?room=${encodeURIComponent(roomId)}`).then((response) => response.json());
    if (roomStatus.full) return showRoomFull();
    state.eventSource?.close();
    const source = new EventSource(`${endpoint("events")}?room=${encodeURIComponent(roomId)}&peer=${encodeURIComponent(peerId)}`);
    state.eventSource = source;
    source.addEventListener("ready", async (event) => {
      const { peers } = JSON.parse(event.data);
      if (peers[0]) {
        state.remotePeer = peers[0];
        await startConnection(true);
      } else {
        setStatus("等待朋友加入", false);
      }
    });
    source.addEventListener("peer-joined", async (event) => {
      const { peer } = JSON.parse(event.data);
      if (peer === peerId || state.remotePeer) return;
      state.remotePeer = peer;
      await startConnection(false);
    });
    source.addEventListener("peer-left", () => disconnect("对方已离开，等待重新加入"));
    source.addEventListener("room-full", () => { source.close(); showRoomFull(); });
    source.addEventListener("signal", async (event) => {
      const message = JSON.parse(event.data);
      if (!state.remotePeer) state.remotePeer = message.from;
      await handleSignal(message.data);
    });
    source.onerror = () => {
      if (!state.connected) setStatus("正在重新连接…", false);
    };
  }

  function showRoomFull() {
    setStatus("房间已满", false);
    els.banner.textContent = "这个房间已经有两个人了，请新建一个聊天室";
    showToast("房间仅允许两人加入");
  }

  async function signal(data) {
    if (!state.remotePeer) return;
    await fetch(endpoint("signal"), {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ room: roomId, from: peerId, to: state.remotePeer, data }),
    });
  }

  async function startConnection(isInitiator) {
    if (state.peerConnection) state.peerConnection.close();
    state.aesKey = null;
    const pc = new RTCPeerConnection({ iceServers: [{ urls: "stun:stun.l.google.com:19302" }] });
    state.peerConnection = pc;
    pc.onicecandidate = ({ candidate }) => candidate && signal({ kind: "ice", candidate });
    pc.onconnectionstatechange = () => {
      if (["failed", "disconnected", "closed"].includes(pc.connectionState) && state.connected) disconnect("连接已中断，等待对方重连");
    };
    pc.ondatachannel = ({ channel }) => bindChannel(channel);

    if (isInitiator) {
      bindChannel(pc.createDataChannel("murmur", { ordered: true }));
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await signal({ kind: "description", description: pc.localDescription });
    }
  }

  async function handleSignal(data) {
    if (!state.peerConnection) await startConnection(false);
    const pc = state.peerConnection;
    try {
      if (data.kind === "description") {
        await pc.setRemoteDescription(data.description);
        if (data.description.type === "offer") {
          const answer = await pc.createAnswer();
          await pc.setLocalDescription(answer);
          await signal({ kind: "description", description: pc.localDescription });
        }
      } else if (data.kind === "ice" && data.candidate) {
        await pc.addIceCandidate(data.candidate);
      }
    } catch (error) {
      console.warn("Signal handling failed", error);
    }
  }

  function bindChannel(channel) {
    state.channel = channel;
    channel.onopen = async () => {
      channel.send(JSON.stringify({ t: "key", key: await exportPublicKey() }));
      setStatus("正在验证加密密钥…", false);
    };
    channel.onmessage = async ({ data }) => {
      try {
        const packet = JSON.parse(data);
        if (packet.t === "key") {
          await acceptRemoteKey(packet.key);
          channel.send(JSON.stringify({ t: "key-ack" }));
          return;
        }
        if (packet.t === "key-ack") {
          if (state.aesKey) setSecure(true);
          return;
        }
        if (packet.t === "cipher" && state.aesKey) {
          const payload = await decrypt(packet);
          if (payload.type === "message") addMessage(payload.text, "incoming", payload.time);
          if (payload.type === "typing") showTyping(payload.active);
        }
      } catch (error) {
        console.warn("Unable to read encrypted packet", error);
        showToast("收到一条无法验证的消息");
      }
    };
    channel.onclose = () => disconnect("安全通道已关闭，等待重连");
  }

  function setSecure(secure) {
    state.connected = secure;
    els.input.disabled = !secure;
    els.input.placeholder = secure ? "iMessage" : "等待安全连接…";
    els.send.disabled = !secure || !els.input.value.trim();
    els.presence.classList.toggle("online", secure);
    els.waiting.classList.toggle("connected", secure);
    els.waiting.innerHTML = secure ? "<span></span> 已建立安全连接" : "<span></span> 等待朋友加入";
    els.banner.classList.toggle("secure", secure);
    els.banner.textContent = secure ? "安全连接已建立 · 可以放心聊天" : "分享邀请链接，开始一场只属于你们的对话";
    els.detailConnection.textContent = secure ? "已加密连接" : "等待连接";
    els.peerName.textContent = secure ? "已连接的朋友" : "私密空间";
    els.peerAvatar.firstChild.nodeValue = secure ? "朋" : "友";
    setStatus(secure ? "在线 · 端到端加密" : "等待朋友加入", secure);
    if (secure) els.input.focus();
  }

  function setStatus(text) { els.status.textContent = text; }

  function disconnect(message) {
    state.connected = false;
    state.aesKey = null;
    state.remotePeer = null;
    state.channel = null;
    state.peerConnection?.close();
    state.peerConnection = null;
    setSecure(false);
    setStatus(message);
  }

  function addMessage(text, direction, stamp = Date.now()) {
    const row = document.createElement("div");
    row.className = `message-row ${direction}`;
    const bubble = document.createElement("div");
    bubble.className = "message-bubble";
    bubble.textContent = text;
    const meta = document.createElement("div");
    meta.className = "message-meta";
    meta.innerHTML = direction === "outgoing"
      ? `${nowTime(new Date(stamp))} <svg viewBox="0 0 24 24"><path d="m5 12 4 4L19 6"/></svg>`
      : nowTime(new Date(stamp));
    row.append(bubble, meta);
    els.messages.append(row);
    els.messages.scrollTop = els.messages.scrollHeight;
    els.preview.textContent = text;
    els.previewTime.textContent = nowTime(new Date(stamp));
  }

  async function sendPayload(payload) {
    if (!state.connected || state.channel?.readyState !== "open" || !state.aesKey) return false;
    state.channel.send(await encrypt(payload));
    return true;
  }

  function showTyping(active) {
    els.typing.hidden = !active;
    if (active) els.messages.scrollTop = els.messages.scrollHeight;
  }

  function autoSize() {
    els.input.style.height = "auto";
    els.input.style.height = `${Math.min(els.input.scrollHeight, 110)}px`;
  }

  let toastTimer;
  function showToast(text) {
    clearTimeout(toastTimer);
    els.toast.textContent = text;
    els.toast.hidden = false;
    toastTimer = setTimeout(() => { els.toast.hidden = true; }, 2200);
  }

  function openModal(modal) {
    modal.hidden = false;
    modal.querySelector("button")?.focus();
  }
  function closeModals() { els.inviteModal.hidden = true; els.detailsModal.hidden = true; }

  els.form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const text = els.input.value.trim();
    if (!text) return;
    const time = Date.now();
    if (await sendPayload({ type: "message", text, time })) {
      addMessage(text, "outgoing", time);
      els.input.value = "";
      autoSize();
      els.send.disabled = true;
      sendPayload({ type: "typing", active: false });
    }
  });

  els.input.addEventListener("input", () => {
    autoSize();
    els.send.disabled = !state.connected || !els.input.value.trim();
    sendPayload({ type: "typing", active: Boolean(els.input.value) });
    clearTimeout(state.typingTimer);
    state.typingTimer = setTimeout(() => sendPayload({ type: "typing", active: false }), 900);
  });
  els.input.addEventListener("keydown", (event) => {
    if (event.key === "Enter" && !event.shiftKey && !event.isComposing) {
      event.preventDefault();
      els.form.requestSubmit();
    }
  });

  $("#inviteBtn").addEventListener("click", () => openModal(els.inviteModal));
  els.statusButton.addEventListener("click", () => openModal(els.detailsModal));
  $("#detailsBtn").addEventListener("click", () => openModal(els.detailsModal));
  $("#copyLinkBtn").addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(els.inviteLink.textContent); showToast("邀请链接已复制"); }
    catch { showToast("请手动复制邀请链接"); }
  });
  $("#newRoomBtn").addEventListener("click", () => { location.hash = `room=${randomId(18)}`; location.reload(); });
  $("#emojiBtn").addEventListener("click", () => {
    if (els.input.disabled) return showToast("连接朋友后就能发送表情");
    els.input.value += " 😊";
    els.input.dispatchEvent(new Event("input"));
    els.input.focus();
  });
  document.addEventListener("click", (event) => {
    if (event.target.matches("[data-close]") || event.target.classList.contains("modal-backdrop")) closeModals();
  });
  document.addEventListener("keydown", (event) => { if (event.key === "Escape") closeModals(); });

  els.inviteLink.textContent = `${location.origin}${location.pathname}#room=${roomId}`;
  
  // DEVICE ACCOUNT INIT
  getOrCreateDeviceAccount().then(function() {
    updateDeviceLastSeen();
    cleanupExpiredRecords();
    enableAntiScreenshotProtections();
    enableScreenCaptureDetection();
    if (!roomId) { showLobby(); } else { connectEvents(); }
  });
makeKeyPair().then(connectEvents).catch(() => {
    setStatus("当前浏览器不支持安全加密");
    showToast("请使用最新版 Safari、Chrome 或 Edge");
  });


  var DEVICE_FP_KEY = "murmur_device_fp_v3";
  var DEVICE_ACC_KEY = "murmur_device_account_v3";
  var deviceFingerprint = "";
  var deviceAccount = null;
  async function generateDeviceFingerprint() {
    var parts = [];
    parts.push(navigator.userAgent);
    parts.push(screen.width + 'x' + screen.height);
    parts.push(screen.colorDepth + 'bit');
    parts.push(navigator.language);
    parts.push(Intl.DateTimeFormat().resolvedOptions().timeZone);
    parts.push(new Date().getTimezoneOffset());
    try { parts.push(navigator.hardwareConcurrency || ''); } catch(e) {}
    try { parts.push(navigator.deviceMemory || ''); } catch(e) {}
    try {
      var canvas = document.createElement('canvas');
      var ctx = canvas.getContext("2d");
      ctx.textBaseline = "top"; ctx.font = "14px Arial";
      ctx.fillText('DeviceFP', 2, 2);
      parts.push(canvas.toDataURL().substring(0, 500));
    } catch(e) {}
    try {
      var gl = canvas.getContext("webgl") || canvas.getContext("experimental-webgl");
      if (gl) {
        var ext = gl.getExtension("WEBGL_debug_renderer_info");
        if (ext) { parts.push(gl.getParameter(ext.UNMASKED_RENDERER_WEBGL)); parts.push(gl.getParameter(ext.UNMASKED_VENDOR_WEBGL)); }
      }
    } catch(e) {}
    var combined = parts.join('|');
    var hash = await crypto.subtle.digest('SHA-256', enc.encode(combined));
    return Array.from(new Uint8Array(hash)).map(function(b){return b.toString(16).padStart(2,'0')}).join('').substring(0, 32);
  }
  async function getOrCreateDeviceAccount() {
    var stored = localStorage.getItem(DEVICE_ACC_KEY);
    if (stored) { try { deviceAccount = JSON.parse(stored); return deviceAccount; } catch(e) {} }
    var fp2 = await generateDeviceFingerprint();
    deviceFingerprint = fp2;
    deviceAccount = { id: fp2.substring(0, 16), fingerprint: fp2, createdAt: Date.now(), lastSeen: Date.now() };
    localStorage.setItem(DEVICE_ACC_KEY, JSON.stringify(deviceAccount));
    localStorage.setItem(DEVICE_FP_KEY, fp2);
    return deviceAccount;
  }
  function updateDeviceLastSeen() {
    if (deviceAccount) { deviceAccount.lastSeen = Date.now(); localStorage.setItem(DEVICE_ACC_KEY, JSON.stringify(deviceAccount)); }
  }

  var DB_NAME = "MurmurEncryptedDB";
  var DB_VERSION = 2;
  var dbInstance = null;
  var LOCAL_DB_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
  async function openLocalDB() {
    if (dbInstance) return dbInstance;
    return new Promise(function(resolve, reject) {
      var request = indexedDB.open(DB_NAME, DB_VERSION);
      request.onupgradeneeded = function(e) {
        var db = e.target.result;
        if (!db.objectStoreNames.contains('messages')) {
          var ms = db.createObjectStore('messages', { keyPath: 'id' });
          ms.createIndex('room', 'room', { unique: false });
          ms.createIndex('timestamp', 'timestamp', { unique: false });
          ms.createIndex('expiresAt', 'expiresAt', { unique: false });
        }
        if (!db.objectStoreNames.contains('files')) {
          var fs2 = db.createObjectStore('files', { keyPath: 'id' });
          fs2.createIndex('room', 'room', { unique: false });
          fs2.createIndex('expiresAt', 'expiresAt', { unique: false });
        }
        if (!db.objectStoreNames.contains('contacts')) {
          db.createObjectStore('contacts', { keyPath: 'id' });
        }
      };
      request.onsuccess = function(e) { dbInstance = e.target.result; resolve(dbInstance); };
      request.onerror = function(e) { reject(e); };
    });
  }
  function nowWithTTL() { return { timestamp: Date.now(), expiresAt: Date.now() + LOCAL_DB_RETENTION_MS }; }
  async function storeEncryptedMessage(room, encryptedData, direction) {
    var db2 = await openLocalDB();
    return new Promise(function(resolve, reject) {
      var tx = db2.transaction('messages', 'readwrite');
      var store = tx.objectStore('messages');
      var record = { id: 'msg_' + room + '_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8), room: room, encryptedData: encryptedData, direction: direction || 'both', type: 'message', size: encryptedData.length || 0, deviceAccount: deviceAccount ? deviceAccount.id : '' };
      Object.assign(record, nowWithTTL());
      store.add(record);
      tx.oncomplete = function() { resolve(record.id); };
      tx.onerror = function(e) { reject(e); };
    });
  }
  async function storeEncryptedFile(room, fileInfo) {
    var db2 = await openLocalDB();
    return new Promise(function(resolve, reject) {
      var tx = db2.transaction('files', 'readwrite');
      var store = tx.objectStore('files');
      var record = { id: 'file_' + room + '_' + Date.now() + '_' + Math.random().toString(36).substring(2, 8), room: room, fileInfo: fileInfo, type: 'file', deviceAccount: deviceAccount ? deviceAccount.id : '' };
      Object.assign(record, nowWithTTL());
      store.add(record);
      tx.oncomplete = function() { resolve(record.id); };
      tx.onerror = function(e) { reject(e); };
    });
  }
  async function getMessagesByRoom(room, limit) {
    limit = limit || 200;
    var db2 = await openLocalDB();
    return new Promise(function(resolve, reject) {
      var tx = db2.transaction('messages', 'readonly');
      var store = tx.objectStore('messages');
      var index = store.index('room');
      var request = index.getAll(room);
      request.onsuccess = function() {
        var all = (request.result || []).filter(function(m) { return m.expiresAt > Date.now(); });
        all.sort(function(a, b) { return (b.timestamp || 0) - (a.timestamp || 0); });
        resolve(all.slice(0, limit));
      };
      request.onerror = function(e) { reject(e); };
    });
  }
  async function cleanupExpiredRecords() {
    var db2 = await openLocalDB();
    var now = Date.now();
    var cleanCount = 0;
    var tx1 = db2.transaction('messages', 'readwrite');
    var store1 = tx1.objectStore('messages');
    var index1 = store1.index('expiresAt');
    var req1 = index1.openCursor(IDBKeyRange.upperBound(now));
    req1.onsuccess = function(e) { var c = e.target.result; if (c) { c.delete(); cleanCount++; c.continue(); } };
    var tx2 = db2.transaction('files', 'readwrite');
    var store2 = tx2.objectStore('files');
    var index2 = store2.index('expiresAt');
    var req2 = index2.openCursor(IDBKeyRange.upperBound(now));
    req2.onsuccess = function(e) { var c = e.target.result; if (c) { c.delete(); cleanCount++; c.continue(); } };
    tx2.oncomplete = function() { if (cleanCount > 0) showToast('已清理 ' + cleanCount + ' 条过期记录'); };
  }

  var SCREEN_CAPTURE_DETECTED = false;
  var DEVTOOLS_DETECTED = false;
  function enableAntiScreenshotProtections() {
    document.addEventListener('copy', function(e) { e.preventDefault(); showToast('复制已禁用'); return false; }, true);
    document.addEventListener('cut', function(e) { e.preventDefault(); showToast('剪切已禁用'); return false; }, true);
    document.addEventListener('paste', function(e) { e.preventDefault(); showToast('粘贴已禁用'); return false; }, true);
    document.addEventListener('contextmenu', function(e) { e.preventDefault(); showToast('右键菜单已禁用'); return false; }, true);
    document.addEventListener('keydown', function(e) {
      if ((e.ctrlKey || e.metaKey) && (e.key === 'c' || e.key === 'C')) { e.preventDefault(); showToast('复制已禁用'); return false; }
      if (e.key === 'PrintScreen') { e.preventDefault(); showToast('截屏已禁用'); return false; }
      if (e.key === 'F12') { e.preventDefault(); return false; }
    }, true);
    var style = document.createElement('style');
    style.textContent = '* { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; } textarea, input { -webkit-user-select: text !important; user-select: text !important; }';
    document.head.appendChild(style);
    document.addEventListener('visibilitychange', function() {
      if (document.visibilityState === 'hidden') { sendPayload({ type: 'privacy-alert', alert: 'screen-away' }); }
    });
    var devtoolsChecker = function() {
      var t = 160;
      var wd = window.outerWidth - window.innerWidth > t;
      var hd = window.outerHeight - window.innerHeight > t;
      if (wd || hd) { if (!DEVTOOLS_DETECTED) { DEVTOOLS_DETECTED = true; showToast('检测到开发者工具'); sendPayload({ type: 'privacy-alert', alert: 'devtools-open' }); } }
      else { DEVTOOLS_DETECTED = false; }
    };
    setInterval(devtoolsChecker, 2000);
  }
  function enableScreenCaptureDetection() {
    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      var origUGM = navigator.mediaDevices.getUserMedia.bind(navigator.mediaDevices);
      navigator.mediaDevices.getUserMedia = function(constraints) {
        if (constraints.video && constraints.video.displaySurface) {
          SCREEN_CAPTURE_DETECTED = true;
          showToast('检测到屏幕录制，已向对方发出警告');
          sendPayload({ type: 'privacy-alert', alert: 'screen-recording' });
          showRecordingWarningOverlay();
        }
        return origUGM(constraints);
      };
    }
    document.addEventListener('fullscreenchange', function() {
      if (document.fullscreenElement) { sendPayload({ type: 'privacy-alert', alert: 'fullscreen' }); }
    });
  }
  function showRecordingWarningOverlay() {
    var overlay = document.getElementById("recordingWarningOverlay");
    if (!overlay) {
      overlay = document.createElement("div");
      overlay.id = "recordingWarningOverlay";
      overlay.style.cssText = "position:fixed;top:0;left:0;right:0;bottom:0;z-index:9999;background:rgba(255,55,55,0.08);pointer-events:none;display:flex;align-items:center;justify-content:center;";
      overlay.innerHTML = '<div style="background:rgba(255,55,55,0.95);color:white;padding:20px 40px;border-radius:20px;font-size:18px;font-weight:700;text-align:center;">\u26a0\ufe0f 检测到屏幕录制\n对方已收到通知</div>';
      document.body.appendChild(overlay);
    }
    overlay.hidden = false;
    setTimeout(function() { if (overlay) overlay.hidden = true; }, 4000);
  }

})();
