const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');
const source = fs.readFileSync(path.join(__dirname, '../ingress-websocket.js'), 'utf8');

function setup(href) {
  class Socket {
    static OPEN = 1;
    constructor(...args) { this.args = args; }
    send(data) { this.sent = data; }
  }
  const window = { location: new URL(href), WebSocket: Socket };
  vm.runInNewContext(source, { window, URL });
  return { window, Socket };
}

test('HTTPS sidebar keeps ingress prefix and notify protocol', () => {
  const { window, Socket } = setup('https://ha.example/api/hassio_ingress/test-session/#/player');
  const ws = new window.WebSocket('wss://ha.example:3688', 'notify');
  assert.deepEqual(ws.args, ['wss://ha.example/api/hassio_ingress/test-session/ws', 'notify']);
  assert.ok(ws instanceof Socket);
  assert.equal(window.WebSocket.OPEN, 1);
  ws.send('subscription');
  assert.equal(ws.sent, 'subscription');
});

test('HTTP sidebar preserves custom HA port and protocol arrays', () => {
  const { window } = setup('http://ha.local:8123/api/hassio_ingress/another-session/');
  const protocols = ['notify'];
  const ws = new window.WebSocket('ws://ha.local:3688', protocols);
  assert.deepEqual(ws.args, ['ws://ha.local:8123/api/hassio_ingress/another-session/ws', protocols]);
});

test('unrelated sockets are unchanged, including missing protocol argument', () => {
  const { window } = setup('https://ha.example/api/hassio_ingress/test-session/');
  assert.deepEqual(new window.WebSocket('wss://elsewhere/socket').args, ['wss://elsewhere/socket']);
  assert.deepEqual(new window.WebSocket('wss://elsewhere/socket', 'other').args,
    ['wss://elsewhere/socket', 'other']);
});

test('direct LAN access does not replace the native constructor', () => {
  const { window, Socket } = setup('http://owntone.local:3689/#/player');
  assert.equal(window.WebSocket, Socket);
});
