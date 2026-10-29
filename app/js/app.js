// JS requirement: Chrome 80, Firefox 72, Safari 13.1 (ES modules, ??)

import { maxSteps, scaleLabel, stepLabel } from "./format.js";

const APP_ID = "ttl2nim";
const STATUS_URL = `/${APP_ID}/status`;
const START_URL = `/bazaar?start=${APP_ID}`;
const SOCKET_URL = `ws://${location.host}/wss`;
// Our controller answers send_all_params with TICK_PS; anything else isn't ours.
const CONTROLLER_TIMEOUT_MS = 1500;
const STATUS_POLL_MS = 2000;
const SEND_INTERVAL_MS = 100;

const statusEl = document.getElementById("status");
const sliders = {
  COARSE: { title: "Coarse", bitsParam: "COARSE_BITS" },
  FINE: { title: "Fine", bitsParam: "FINE_BITS" },
};

const params = {};
let socket = null;
let connected = false;
let connecting = false;
let running = null;

async function fetchRunning() {
  try {
    const response = await fetch(STATUS_URL, { cache: "no-store" });
    return (await response.json()).running === true;
  } catch {
    return false;
  }
}

async function startApp() {
  try {
    await fetch(START_URL, { cache: "no-store" });
  } catch {
    // The status poll shows the outcome.
  }
}

function perStepPs(name) {
  const tickPs = params.TICK_PS;
  return name === "COARSE" ? tickPs : tickPs / 2 ** params.FINE_BITS;
}

function send(name, value) {
  if (connected)
    socket.send(JSON.stringify({ parameters: { [name]: { value } } }));
}

// Resolves true once the controller has sent TICK_PS, false if the socket fails or times out.
function connect() {
  connecting = true;
  return new Promise((resolve) => {
    const ws = new WebSocket(SOCKET_URL);
    ws.binaryType = "arraybuffer";
    const settle = (ok) => {
      clearTimeout(timer);
      connecting = false;
      if (!ok) ws.close();
      resolve(ok);
    };
    const timer = setTimeout(() => settle(false), CONTROLLER_TIMEOUT_MS);

    ws.onopen = () => {
      ws.send(
        JSON.stringify({
          parameters: { in_command: { value: "send_all_params" } },
        }),
      );
    };
    ws.onmessage = (event) => {
      const text = new TextDecoder().decode(
        pako.inflate(new Uint8Array(event.data)),
      );
      const parameters = JSON.parse(text).parameters ?? {};
      for (const [name, param] of Object.entries(parameters))
        params[name] = param.value;
      if (!connected && "TICK_PS" in params) {
        socket = ws;
        connected = true;
        settle(true);
      }
      render();
    };
    ws.onclose = () => {
      if (socket === ws) {
        socket = null;
        connected = false;
        render();
      }
      settle(false);
    };
  });
}

function render() {
  const ready = running === true && connected;
  const state =
    running === null || connecting
      ? "connecting"
      : ready
        ? "running"
        : "stopped";
  statusEl.dataset.state = state;
  statusEl.textContent = {
    connecting: "Connecting…",
    running: "Running",
    stopped: "Not running",
  }[state];

  for (const [name, slider] of Object.entries(sliders)) {
    slider.input.disabled = !ready;
    if (!("TICK_PS" in params)) continue;
    const bits = params[slider.bitsParam];
    const step = perStepPs(name);
    slider.scale.textContent = scaleLabel(slider.title, step);
    slider.value.textContent = stepLabel(params[name], bits, step);
    slider.input.max = maxSteps(bits);
    if (!slider.dragging) slider.input.value = params[name];
  }
}

function bindSlider(name, slider) {
  const id = name.toLowerCase();
  slider.input = document.getElementById(id);
  slider.scale = document.getElementById(`${id}-scale`);
  slider.value = document.getElementById(`${id}-value`);
  slider.dragging = false;

  let lastSent = 0;
  let timer = null;
  const flush = () => {
    clearTimeout(timer);
    timer = null;
    lastSent = Date.now();
    send(name, Number(slider.input.value));
  };
  slider.input.addEventListener("input", () => {
    slider.dragging = true;
    const wait = lastSent + SEND_INTERVAL_MS - Date.now();
    if (wait <= 0) flush();
    else if (!timer) timer = setTimeout(flush, wait);
  });
  slider.input.addEventListener("change", () => {
    slider.dragging = false;
    flush();
  });
}

async function poll() {
  running = await fetchRunning();
  if (running && !connected && !connecting) await connect();
  render();
  setTimeout(poll, STATUS_POLL_MS);
}

async function main() {
  for (const [name, slider] of Object.entries(sliders))
    bindSlider(name, slider);
  render();

  running = await fetchRunning();
  // Reattach to a running controller; otherwise (re)start the app, which reloads the FPGA.
  if (!(running && (await connect()))) {
    await startApp();
    running = await fetchRunning();
    if (running) await connect();
  }
  render();
  setTimeout(poll, STATUS_POLL_MS);
}

main();
