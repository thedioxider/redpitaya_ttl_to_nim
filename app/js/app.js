// JS requirement: Chrome 84, Firefox 72, Safari 13.1 (ES modules, ??, all: revert)

import { formatTime, maxSteps, scaleLabel } from "./format.js";

const APP_ID = "ttl2nim";
const STATUS_URL = `/${APP_ID}/status`;
const START_URL = `/bazaar?start=${APP_ID}`;
const SOCKET_URL = `ws://${location.host}/wss`;
// Our controller answers send_all_params with TICK_PS; anything else isn't ours.
const CONTROLLER_TIMEOUT_MS = 1500;
const STATUS_POLL_MS = 2000;
const SEND_INTERVAL_MS = 100;
// Gives up waiting for the controller to confirm a sent value, e.g. one it already had.
const CONFIRM_TIMEOUT_MS = 1000;

const statusEl = document.getElementById("status");
const sliders = {
  COARSE: { title: "Coarse", bitsParam: "COARSE_BITS" },
  FINE: { title: "Fine", bitsParam: "FINE_BITS" },
};

const params = {};
let socket = null;
let connected = false;
let attaching = false;
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
  return new Promise((resolve) => {
    const ws = new WebSocket(SOCKET_URL);
    ws.binaryType = "arraybuffer";
    const settle = (ok) => {
      clearTimeout(timer);
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
    running === null || attaching
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
    slider.time.textContent = formatTime(params[name] * step);
    slider.steps.textContent = `${params[name]}/${maxSteps(bits)}`;
    slider.input.max = maxSteps(bits);
    // Keep the thumb where the user left it until the controller confirms that value:
    // confirmations of values sent mid-drag can arrive after release.
    if (params[name] === slider.sent) slider.sent = null;
    const confirming =
      slider.sent !== null && Date.now() - slider.sentAt < CONFIRM_TIMEOUT_MS;
    if (!slider.dragging && !confirming) slider.input.value = params[name];
    showFill(slider.input);
  }
}

// WebKit has no filled-part pseudo-element; the track's gradient stops at --fill instead.
function showFill(input) {
  const fill = (input.value - input.min) / (input.max - input.min || 1);
  input.style.setProperty("--fill", `${fill * 100}%`);
}

function bindSlider(name, slider) {
  const id = name.toLowerCase();
  slider.input = document.getElementById(id);
  slider.scale = document.getElementById(`${id}-scale`);
  slider.time = document.querySelector(`#${id}-value .time`);
  slider.steps = document.querySelector(`#${id}-value .steps`);
  slider.dragging = false;
  slider.sent = null;
  slider.sentAt = 0;

  let timer = null;
  const flush = () => {
    clearTimeout(timer);
    timer = null;
    slider.sent = Number(slider.input.value);
    slider.sentAt = Date.now();
    send(name, slider.sent);
    // Catches up if the confirmation never comes; the margin covers timer rounding.
    setTimeout(render, CONFIRM_TIMEOUT_MS + 50);
  };
  slider.input.addEventListener("input", () => {
    slider.dragging = true;
    showFill(slider.input);
    const wait = slider.sentAt + SEND_INTERVAL_MS - Date.now();
    if (wait <= 0) flush();
    else if (!timer) timer = setTimeout(flush, wait);
  });
  slider.input.addEventListener("change", () => {
    slider.dragging = false;
    flush();
  });
}

// Connects to our controller, (re)starting the app if it's gone.
async function attach() {
  attaching = true;
  render();
  if (!(running && (await connect()))) {
    await startApp();
    running = await fetchRunning();
    if (running) await connect();
  }
  attaching = false;
  render();
}

async function poll() {
  running = await fetchRunning();
  // Our bitstream with no controller: a page disconnected, and Red Pitaya's WebSocket server
  // exits the controller on any disconnect. Another bitstream means another app was opened.
  if (running && !connected && !attaching) await attach();
  render();
  setTimeout(poll, STATUS_POLL_MS);
}

// Older browsers ignore writing-mode on sliders and keep drawing them horizontally.
function supportsVerticalSliders() {
  const probe = document.createElement("input");
  probe.type = "range";
  // Native look and size, free of the page's slider styling.
  probe.style.cssText =
    "all: revert; position: absolute; visibility: hidden; writing-mode: vertical-lr";
  document.body.append(probe);
  const vertical = probe.offsetHeight > probe.offsetWidth;
  probe.remove();
  return vertical;
}

async function main() {
  if (!supportsVerticalSliders())
    document.documentElement.classList.add("no-vertical-sliders");
  for (const [name, slider] of Object.entries(sliders))
    bindSlider(name, slider);
  // Browsers may reset form fields when bringing a page back (Firefox on Android does).
  addEventListener("pageshow", render);
  document.addEventListener("visibilitychange", render);
  render();

  running = await fetchRunning();
  await attach();
  setTimeout(poll, STATUS_POLL_MS);
}

main();
