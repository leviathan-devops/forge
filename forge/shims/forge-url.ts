/**
 * forge-url.ts — URL polyfill for FORGE/iOS.
 * Uses browser's native URL/URLSearchParams. Provides fileURLToPath/pathToFileURL.
 */

const NativeURL = globalThis.URL;
const NativeURLSearchParams = globalThis.URLSearchParams;

export { NativeURL as URL, NativeURLSearchParams as URLSearchParams };

export function fileURLToPath(url: string | URL): string {
  let urlStr: string = typeof url === 'string' ? url : url.href;
  if (urlStr.startsWith('file://')) {
    let path = urlStr.slice(7);
    if (path.startsWith('//localhost/')) path = path.slice('//localhost'.length);
    else if (path.startsWith('///')) path = path.slice(2);
    else if (path.startsWith('//')) path = path.slice(1);
    try { path = decodeURIComponent(path); } catch (decodeErr) { /* use as-is */ }
    return path;
  }
  throw new TypeError('[FORGE] fileURLToPath: URL must be a file:// URL, got: ' + urlStr);
}

export function pathToFileURL(path: string): URL {
  if (typeof path !== 'string') throw new TypeError('[FORGE] pathToFileURL: path must be a string');
  if (!path.startsWith('/')) throw new TypeError('[FORGE] pathToFileURL: path must be absolute, got: ' + path);
  const encoded = path.replace(/%/g, '%25').replace(/\\/g, '%5C').replace(/\?/g, '%3F')
    .replace(/#/g, '%23').replace(/\n/g, '%0A').replace(/\r/g, '%0D').replace(/\t/g, '%09');
  return new NativeURL('file://' + encoded);
}

export function format(urlObject: Record<string, string | number | boolean | undefined>): string {
  const url = new NativeURL(
    (urlObject.protocol ?? 'http:') + '//' + (urlObject.host ?? urlObject.hostname ?? 'localhost') +
    (urlObject.pathname ?? '/') + (urlObject.search ?? '') + (urlObject.hash ?? '')
  );
  return url.href;
}

export function resolve(from: string, to: string): string {
  return new NativeURL(to, from).href;
}

export function resolveObject(from: string, to: string): Record<string, any> {
  const resolved = new NativeURL(to, from);
  return {
    protocol: resolved.protocol, hostname: resolved.hostname, host: resolved.host,
    port: resolved.port, pathname: resolved.pathname, search: resolved.search,
    hash: resolved.hash, href: resolved.href,
  };
}

export function parse(urlStr: string): Record<string, any> {
  const url = new NativeURL(urlStr);
  return {
    protocol: url.protocol, slashes: true,
    auth: url.username ? url.username + ':' + url.password : null,
    host: url.host, port: url.port || null, hostname: url.hostname,
    hash: url.hash || null, search: url.search || null,
    query: url.searchParams.toString() || null, pathname: url.pathname || null,
    path: url.pathname + url.search, href: url.href,
  };
}

export function domainToASCII(domain: string): string {
  try { return new NativeURL('http://' + domain).hostname; } catch (err) { return domain; }
}

export function domainToUnicode(domain: string): string {
  try { return new NativeURL('http://' + domain).hostname; } catch (err) { return domain; }
}

export const Url = {
  URL: NativeURL, URLSearchParams: NativeURLSearchParams,
  fileURLToPath, pathToFileURL, format, resolve, resolveObject, parse, domainToASCII, domainToUnicode,
};

export default Url;
