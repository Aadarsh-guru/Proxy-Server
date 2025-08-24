
export function parseHost(host?: string): { port: number; id: string } | null {
    if (!host) return null;
    const subdomain = host.split(".")[0];
    if (!subdomain) return null;
    // Check for <port>-<id>
    if (subdomain.includes("-")) {
        const [portStr, id] = subdomain.split("-");
        const port = parseInt(portStr, 10);
        if (!port || !id) return null;
        return { port, id };
    };
    // Fallback: <id> only, default port 80
    return { port: 80, id: subdomain };
}
