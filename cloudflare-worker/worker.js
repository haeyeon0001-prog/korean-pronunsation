// Korean pronunciation app — Whisper proxy Worker
//
// Receives multipart audio from the PWA, forwards to OpenAI Whisper
// with the teacher's key (stored as a Worker secret, never exposed to clients).
//
// Environment:
//   OPENAI_API_KEY   — secret (wrangler secret put OPENAI_API_KEY)
//   ALLOWED_ORIGIN   — optional, e.g. "https://haeyeon0001-prog.github.io"
//                       set to "*" or omit for dev.

const UPSTREAM = "https://api.openai.com/v1/audio/transcriptions";
const MAX_BODY_BYTES = 2 * 1024 * 1024; // 2MB — plenty for a short utterance

export default {
    async fetch(request, env) {
        const origin = env.ALLOWED_ORIGIN || "*";
        const cors = {
            "Access-Control-Allow-Origin": origin,
            "Access-Control-Allow-Methods": "POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "86400",
        };

        if (request.method === "OPTIONS") {
            return new Response(null, { headers: cors });
        }
        if (request.method !== "POST") {
            return json({ error: "POST only" }, 405, cors);
        }

        const contentType = request.headers.get("content-type") || "";
        if (!contentType.startsWith("multipart/form-data")) {
            return json({ error: "multipart/form-data required" }, 400, cors);
        }

        const contentLength = parseInt(request.headers.get("content-length") || "0", 10);
        if (contentLength && contentLength > MAX_BODY_BYTES) {
            return json({ error: "audio too large" }, 413, cors);
        }

        if (!env.OPENAI_API_KEY) {
            return json({ error: "OPENAI_API_KEY secret not configured" }, 500, cors);
        }

        let upstream;
        try {
            upstream = await fetch(UPSTREAM, {
                method: "POST",
                headers: {
                    Authorization: `Bearer ${env.OPENAI_API_KEY}`,
                    "Content-Type": contentType,
                },
                body: request.body,
            });
        } catch (err) {
            return json({ error: "upstream fetch failed: " + err.message }, 502, cors);
        }

        const body = await upstream.text();
        return new Response(body, {
            status: upstream.status,
            headers: {
                ...cors,
                "Content-Type": upstream.headers.get("content-type") || "application/json",
            },
        });
    },
};

function json(obj, status, cors) {
    return new Response(JSON.stringify(obj), {
        status,
        headers: { ...cors, "Content-Type": "application/json" },
    });
}
