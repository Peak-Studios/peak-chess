type NuiPayload = Record<string, unknown>;

declare global {
  interface Window {
    GetParentResourceName?: () => string;
    peakChessDebug?: {
      send: (action: string, data?: NuiPayload) => void;
    };
  }
}

export function getResourceName() {
  return window.GetParentResourceName?.() ?? "peak-chess";
}

export function isFiveM() {
  return typeof window.GetParentResourceName === "function";
}

export async function postNui(action: string, data: NuiPayload = {}) {
  if (!isFiveM()) {
    console.info(`[peak-chess:nui] ${action}`, data);
    return {};
  }

  const response = await fetch(`https://${getResourceName()}/${action}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  });

  try {
    return await response.json();
  } catch {
    return {};
  }
}

export function onNuiMessage(callback: (action: string, data: NuiPayload) => void) {
  const listener = (event: MessageEvent) => {
    const payload = event.data;
    if (!payload || typeof payload !== "object" || typeof payload.action !== "string") {
      return;
    }

    callback(payload.action, (payload.data ?? {}) as NuiPayload);
  };

  window.addEventListener("message", listener);
  return () => window.removeEventListener("message", listener);
}
