"""MyNews API adapter. Python 3.11+, standard library only.
Run behind a TLS reverse proxy; default bind is loopback for development.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlencode, urlsplit, urlunsplit, parse_qsl
from urllib.request import Request, urlopen

CATEGORIES = {
    "breaking": ("top", None), "sports": ("sports", None),
    "technology": ("technology", None), "science": ("science", None),
    "economy": ("business", "economy OR economía OR economia"),
    "business": ("business", None), "entertainment": ("entertainment", None),
    "health": ("health", None), "politics": ("politics", None),
    "world": ("world", None),
    "culture": ("entertainment", "art OR arte OR cultura OR culture"),
    "gaming": ("technology", "videogame OR videojuegos OR gaming"),
}


def load_local_environment(path=None):
    """Read optional local configuration; hosting environment variables take priority."""
    path = Path(path) if path is not None else Path(__file__).with_name('.env')
    if not path.is_file():
        return
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        name, separator, value = line.partition('=')
        name = name.strip()
        if separator and name in {'NEWSDATA_API_KEY', 'BIND_HOST', 'PORT'}:
            os.environ.setdefault(name, value.strip())


class APIError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message
        super().__init__(message)


def safe_url(value):
    if not isinstance(value, str):
        return None
    try:
        parts = urlsplit(value)
        return value if parts.scheme in ("https", "http") and parts.hostname and not parts.username else None
    except ValueError:
        return None


def canonical_url(value):
    parts = urlsplit(value)
    query = sorted((k, v) for k, v in parse_qsl(parts.query)
                   if not k.lower().startswith("utm_") and k.lower() not in ("fbclid", "gclid"))
    return urlunsplit((parts.scheme, parts.netloc.lower(), parts.path, urlencode(query), ""))


def normalize(raw, requested_category=None, country=None):
    """Return only title/summary/link metadata; never copy the provider's content field."""
    if not isinstance(raw, dict):
        return None
    link = safe_url(raw.get("link"))
    title = raw.get("title")
    if not link or not isinstance(title, str) or not title.strip():
        return None
    try:
        date = datetime.fromisoformat(str(raw.get("pubDate", "")).replace("Z", "+00:00"))
        if date.tzinfo is None:
            date = date.replace(tzinfo=timezone.utc)  # NewsData pubDate is UTC.
        date = date.astimezone(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    except ValueError:
        return None
    provider_categories = raw.get("category") or []
    if not isinstance(provider_categories, list):
        provider_categories = []
    category = requested_category or next((c for c in provider_categories if c in CATEGORIES), "world")
    description = raw.get("description")
    return {
        "id": hashlib.sha256(canonical_url(link).encode()).hexdigest(),
        "title": title.strip(),
        "description": description if isinstance(description, str) else "La fuente no proporcionó un resumen.",
        "imageURL": safe_url(raw.get("image_url")), "articleURL": link,
        "source": raw.get("source_name") or raw.get("source_id") or "Fuente original",
        "publishedAt": date, "category": category, "country": country,
        # 'top' is not a verified urgency signal. Real push requires editorial classification.
        "isBreakingNews": False,
    }


def deduplicate(articles):
    seen, result = set(), []
    for article in sorted(articles, key=lambda a: a["publishedAt"], reverse=True):
        if article["id"] not in seen:
            seen.add(article["id"])
            result.append(article)
    return result[:100]


class NewsDataProvider:
    def __init__(self, api_key, opener=urlopen):
        self.api_key, self.opener = api_key, opener

    def _request(self, params):
        request = Request("https://newsdata.io/api/1/latest?" + urlencode(params),
                          headers={"Accept": "application/json", "User-Agent": "MyNews/1.0"})
        try:
            with self.opener(request, timeout=15) as response:
                data = response.read(4_000_001)
                if len(data) > 4_000_000:
                    raise APIError(502, "Respuesta del proveedor demasiado grande.")
                payload = json.loads(data)
        except HTTPError as error:
            # Never echo the upstream URL: it contains a private API key.
            status = error.code if error.code in (401, 403, 429) else 502
            error.close()
            raise APIError(status, "El proveedor rechazó la solicitud.") from None
        except (URLError, TimeoutError, OSError, ValueError):
            raise APIError(502, "No se pudo consultar el proveedor de noticias.") from None
        if not isinstance(payload, dict) or payload.get("status") != "success" or not isinstance(payload.get("results"), list):
            raise APIError(502, "Respuesta inválida del proveedor.")
        return payload["results"]

    def fetch(self, country=None, category=None, query=None):
        if not self.api_key:
            raise APIError(503, "Falta configurar NEWSDATA_API_KEY en el servidor.")
        params = {"apikey": self.api_key}
        if country:
            params["country"] = country.lower()
        keywords = None
        if category:
            provider_category, keywords = CATEGORIES[category]
            params["category"] = provider_category
            if keywords:
                params["q"] = keywords
        if query:
            params["q"] = query
        results = self._request(params)
        # The category+keyword combo can be too narrow for the provider's current
        # coverage; fall back to the plain category so the feed isn't empty.
        if not results and keywords and not query:
            del params["q"]
            results = self._request(params)
        articles = [normalize(raw, category, country) for raw in results]
        return [article for article in articles if article]


class NewsAPI:
    def __init__(self, provider):
        self.provider = provider
        self.cache = {}
        self.lock = threading.Lock()
        self.upstream_slots = threading.BoundedSemaphore(3)

    def cached_fetch(self, **kwargs):
        key = tuple(sorted(kwargs.items()))
        with self.lock:
            cached = self.cache.get(key)
            if cached and time.monotonic() - cached[0] < 600:
                return cached[1]
        with self.upstream_slots:
            articles = self.provider.fetch(**kwargs)
        with self.lock:
            if len(self.cache) >= 300:
                del self.cache[min(self.cache, key=lambda k: self.cache[k][0])]
            self.cache[key] = (time.monotonic(), articles)
        return articles

    def dispatch(self, path, params):
        if path == "/health":
            return {"status": "ok"}
        if path == "/v1/headlines":
            country = params.get("country", [""])[0].upper()
            categories = list(dict.fromkeys(params.get("categories", [""])[0].split(",")))
            if not re.fullmatch(r"[A-Z]{2}", country) or not categories or any(c not in CATEGORIES for c in categories):
                raise APIError(400, "País o categorías inválidos.")
            with ThreadPoolExecutor(max_workers=3) as pool:
                results = list(pool.map(lambda c: self.cached_fetch(country=country, category=c), categories))
            return {"articles": deduplicate([a for group in results for a in group])}
        if path == "/v1/search":
            query = params.get("q", [""])[0].strip()
            if not 1 <= len(query) <= 200:
                raise APIError(400, "La búsqueda debe contener entre 1 y 200 caracteres.")
            return {"articles": deduplicate(self.cached_fetch(query=query))}
        raise APIError(404, "Ruta no encontrada.")


def handler_for(api):
    class Handler(BaseHTTPRequestHandler):
        # The HTTPS gateway must enforce authentication/attestation and per-client quotas.
        def do_GET(self):
            if len(self.path) > 2048:
                self.respond(414, {"error": "Solicitud demasiado larga."})
                return
            parsed = urlsplit(self.path)
            try:
                result = api.dispatch(parsed.path, parse_qs(parsed.query))
                self.respond(200, result)
            except APIError as error:
                self.respond(error.status, {"error": error.message})
            except Exception:
                self.respond(500, {"error": "Error interno del servidor."})

        def respond(self, status, payload):
            body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, format, *args):
            pass  # Do not retain user search terms or URLs in access logs.
    return Handler


if __name__ == "__main__":
    load_local_environment()
    provider = NewsDataProvider(os.environ.get("NEWSDATA_API_KEY", ""))
    server = ThreadingHTTPServer((os.environ.get("BIND_HOST", "127.0.0.1"), int(os.environ.get("PORT", "8080"))), handler_for(NewsAPI(provider)))
    print("MyNews backend listening on port", server.server_port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
