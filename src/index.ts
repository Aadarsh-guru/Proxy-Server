import "dotenv/config";
import Redis from "ioredis";
import { Socket } from "net";
import httpProxy from "http-proxy";
import { parseHost } from "./utils";
import http, { IncomingMessage, ServerResponse } from "http";

const port = Number(process.env.PORT) || 8000;

const redis = new Redis(process.env.REDIS_URL!);
const proxy = httpProxy.createProxyServer({ ws: true, changeOrigin: true });

// Prevent proxy from crashing the server
proxy.on("error", (err: Error, _req: IncomingMessage, res: ServerResponse | Socket) => {
    console.error("Proxy error:", err.message);
    // Only write to res if it's an HTTP response, not a raw socket
    if ("writeHead" in res) {
        if (!res.headersSent) {
            res.writeHead(502, { "Content-Type": "text/plain" });
        }
        res.end("Bad Gateway: Could not reach target service");
    } else {
        // It's a raw TCP socket (likely from a WS upgrade)
        res.end();
    }
});


// HTTP handler
const server = http.createServer(async (req: IncomingMessage, res: ServerResponse) => {
    try {
        const parsed = parseHost(req.headers.host || "");
        if (!parsed) {
            res.writeHead(400);
            return res.end("Invalid hostname format");
        }
        const { port, id } = parsed;
        const privateIP = await redis.get(`instance:${id}`);
        if (!privateIP) {
            res.writeHead(404);
            return res.end(`Service private IP address not found`);
        }
        const target = `http://${privateIP}:${port}`;
        console.log(`Proxying to: ${target}`);
        proxy.web(req, res, { target });
    } catch (err: any) {
        res.writeHead(500);
        res.end("Proxy error: " + err.message);
    }
});

// WebSocket upgrade handler
server.on("upgrade", async (req: IncomingMessage, socket: Socket, head: Buffer) => {
    try {
        const host = req.headers.host;
        if (!host) return socket.destroy();
        const [port, idPart] = host.split(".")[0].split("-");
        const privateIP = await redis.get(`instance:${idPart}`);
        if (!privateIP) return socket.destroy();
        const target = `http://${privateIP}:${port}`;
        console.log(`WS Proxying to: ${target}`);
        proxy.ws(req, socket, head, { target });
    } catch (err: any) {
        console.error("WS error:", err.message);
        socket.destroy();
    }
});

// Client error handler
server.on("clientError", (err: Error, socket: Socket) => {
    console.error("Client error:", err.message);
    socket.end("HTTP/1.1 400 Bad Request\r\n\r\n");
});

// Start server
server.listen(port, () => {
    console.log(`🚀 Proxy running on http://localhost:${port} (HTTP + WS)`);
});
