export const CREAM_SERVER = "http://127.0.0.1:2414";

function createProxyNode(path) {
    const callable = (...args) => {
        let callPath = path;
        if (args && args.length > 0) {
            for (const a of args) {
                callPath += "|" + String(a);
            }
        }
        if (typeof __funkin__ !== "undefined" && __funkin__.call) {
            __funkin__.call(callPath);
        }
        if (typeof fetch !== "undefined") {
            send("/api/v1/call", {
                path: path,
                args: args
            }).catch(() => {});
        }
    };

    return new Proxy(callable, {
        get(_target, prop) {
            if (prop === "then" || prop === "__objectId") return undefined;
            if (prop === "toString") return () => `[Proxy ${path}]`;
            if (prop === "valueOf") return () => path;
            return createProxyNode(path + "/" + String(prop));
        }
    });
}

export function createClassProxy(module, className) {
    return createProxyNode(module);
}

async function send(endpoint, body) {
    if (typeof fetch === "undefined") return;
    const response = await fetch(`${CREAM_SERVER}${endpoint}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body)
    });
    if (!response.ok) throw new Error(`CreamServer HTTP ${response.status}`);
    const packet = await response.json();
    if (!packet.ok) throw new Error(packet.error ?? "CreamServer request failed");
    return packet.result;
}

export function get(path) {
    if (typeof fetch === "undefined") return Promise.resolve(null);
    return fetch(`${CREAM_SERVER}/api/v1/get?path=${encodeURIComponent(path)}`)
        .then(async response => {
            if (!response.ok) throw new Error(`CreamServer HTTP ${response.status}`);
            const packet = await response.json();
            if (!packet.ok) throw new Error(packet.error ?? "CreamServer request failed");
            return packet.result;
        });
}
