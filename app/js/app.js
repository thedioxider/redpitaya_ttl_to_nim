// JS requirement: Chrome 84, Firefox 72, Safari 13.1 (ES modules, ??, all: revert)

import {
  formatCoarse,
  formatFine,
  maxSteps,
  parseAmount,
  scaleLabel,
  splitTotal,
} from "./format.js";

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
// [us, ns]
const totalFields = document.querySelectorAll("#total input");

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

  for (const field of totalFields) field.disabled = !ready;
  for (const [name, slider] of Object.entries(sliders)) {
    slider.input.disabled = !ready;
    for (const button of slider.buttons) button.disabled = !ready;
    if (!("TICK_PS" in params)) continue;
    const bits = params[slider.bitsParam];
    const step = perStepPs(name);
    slider.scale.textContent = scaleLabel(slider.title, step);
    slider.input.max = maxSteps(bits);
    // Keep the thumb where the user left it until the controller confirms that value:
    // confirmations of values sent mid-drag can arrive after release.
    if (params[name] === slider.sent) slider.sent = null;
    const confirming =
      slider.sent !== null && Date.now() - slider.sentAt < CONFIRM_TIMEOUT_MS;
    if (!slider.dragging && !confirming) slider.input.value = params[name];
    slider.shown = confirming ? slider.sent : params[name];
    const format = name === "COARSE" ? formatCoarse : formatFine;
    slider.time.textContent = format(slider.shown * step);
    slider.steps.textContent = `${slider.shown}/${maxSteps(bits)} steps`;
    showFill(slider.input);
  }
  if ("TICK_PS" in params) showTotal();
}

function totalPs() {
  return Object.entries(sliders).reduce(
    (sum, [name, slider]) => sum + slider.shown * perStepPs(name),
    0,
  );
}

function showTotal() {
  splitTotal(totalPs()).forEach((value, i) => {
    const field = totalFields[i];
    // Leaves what's being typed alone.
    if (field === document.activeElement) return;
    field.value = value;
    fitWidth(field);
  });
}

// Rounds to the nearest fine step; fine steps add up to one coarse step.
function setTotal(ps) {
  const perCoarse = 2 ** params.FINE_BITS;
  const fineSteps = Math.round(ps / perStepPs("FINE"));
  let coarse = Math.floor(fineSteps / perCoarse);
  let fine = fineSteps % perCoarse;
  const maxCoarse = maxSteps(params.COARSE_BITS);
  if (coarse > maxCoarse) [coarse, fine] = [maxCoarse, perCoarse - 1];
  sliders.COARSE.setSteps(coarse);
  sliders.FINE.setSteps(fine);
}

// Each field applies when it loses focus; unparsable text reverts. us with a decimal point
// replaces the ns (1.5 us reads 1 us 500 ns, 15.0 us zeroes them), ns over 999 carry into us.
function bindTotal() {
  const [usField, nsField] = totalFields;
  let reverting = false;
  for (const field of totalFields) {
    field.addEventListener("focus", () => field.select());
    field.addEventListener("input", () => fitWidth(field));
    field.addEventListener("keydown", (event) => {
      if (event.key === "Enter" && field === usField) nsField.focus();
      else if (event.key === "Enter") field.blur();
      else if (event.key === "Escape") {
        reverting = true;
        field.blur();
      }
    });
    field.addEventListener("blur", () => {
      const us = parseAmount(usField.value);
      let ns = parseAmount(nsField.value);
      if (field === usField && /[.,]/.test(usField.value)) ns = 0;
      if (!reverting && us !== null && ns !== null)
        setTotal(us * 1e6 + ns * 1e3);
      reverting = false;
      render();
    });
  }
}

// Digits are tabular, so a ch per character fits them.
function fitWidth(field) {
  field.style.width = `calc(${Math.max(field.value.length, 1)}ch + 2px)`;
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
  slider.steps = document.querySelector(`#${id}-scale + .steps`);
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

  const setSteps = (target) => {
    const value = Math.min(
      Math.max(target, Number(slider.input.min)),
      Number(slider.input.max),
    );
    if (value === Number(slider.input.value)) return;
    slider.input.value = value;
    showFill(slider.input);
    flush();
  };
  slider.setSteps = setSteps;

  slider.buttons = slider.input.parentElement.querySelectorAll(".step");
  for (const button of slider.buttons) {
    button.addEventListener("click", () => {
      setSteps(
        "value" in button.dataset
          ? Number(button.dataset.value)
          : Number(slider.input.value) + Number(button.dataset.step),
      );
    });
  }
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
  bindTotal();
  // Browsers may reset form fields when bringing a page back (Firefox on Android does).
  addEventListener("pageshow", render);
  document.addEventListener("visibilitychange", render);
  render();

  running = await fetchRunning();
  await attach();
  setTimeout(poll, STATUS_POLL_MS);
}

main();
