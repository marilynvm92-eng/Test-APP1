import io
import json
import os
import tempfile
from pathlib import Path
from unittest.mock import patch
import threading
import unittest
from http.server import ThreadingHTTPServer
from urllib.error import HTTPError
from urllib.request import urlopen
from server import APIError, NewsAPI, NewsDataProvider, canonical_url, deduplicate, handler_for, normalize, load_local_environment

RAW = {"title": "Una noticia", "link": "https://example.com/a?utm_source=feed", "pubDate": "2026-09-15 10:00:00",
       "source_name": "Fuente", "description": "Resumen", "category": ["technology"], "content": "NO COPIAR"}


class FakeProvider:
    def __init__(self):
        self.calls = 0
    def fetch(self, country=None, category=None, query=None):
        self.calls += 1
        return [normalize(RAW, category, country)]


class BackendTests(unittest.TestCase):
    def test_local_configuration_and_hosting_priority(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / '.env'
            path.write_text('# local\nNEWSDATA_API_KEY=fixture-key\nPORT=8080\nUNRELATED=ignored\n', encoding='utf-8')
            with patch.dict(os.environ, {}, clear=True):
                load_local_environment(path)
                self.assertEqual(os.environ['NEWSDATA_API_KEY'], 'fixture-key')
                self.assertNotIn('UNRELATED', os.environ)
            with patch.dict(os.environ, {'NEWSDATA_API_KEY': 'hosting-key'}, clear=True):
                load_local_environment(path)
                self.assertEqual(os.environ['NEWSDATA_API_KEY'], 'hosting-key')

    def test_mapping_and_no_full_content(self):
        article = normalize(RAW, "technology", "CR")
        self.assertEqual(article["country"], "CR")
        self.assertEqual(article["publishedAt"], "2026-09-15T10:00:00Z")
        self.assertNotIn("content", article)
        self.assertNotIn("NO COPIAR", json.dumps(article))
        self.assertFalse(article["isBreakingNews"])

    def test_unsafe_or_broken_articles_are_discarded(self):
        for change in ({"link": "javascript:alert(1)"}, {"pubDate": "bad"}, {"title": None}, {"link": "https://user:pass@example.com"}):
            self.assertIsNone(normalize(RAW | change))
        self.assertIsNone(normalize(None))

    def test_tracking_url_duplicates_share_id(self):
        a = normalize(RAW)
        b = normalize(RAW | {"link": "https://example.com/a?fbclid=abc#section"})
        self.assertEqual(a["id"], b["id"])
        self.assertEqual(len(deduplicate([a, b])), 1)

    def test_cache_separates_country_and_category(self):
        provider = FakeProvider()
        api = NewsAPI(provider)
        for country in ("CR", "CR", "MX"):
            api.dispatch("/v1/headlines", {"country": [country], "categories": ["technology"]})
        self.assertEqual(provider.calls, 2)

    def test_invalid_parameters(self):
        api = NewsAPI(FakeProvider())
        for path, params in (("/v1/headlines", {"country": ["CR"], "categories": ["invalid"]}),
                             ("/v1/search", {"q": [" "]}), ("/v1/search", {"q": ["x" * 201]})):
            with self.assertRaises(APIError) as context:
                api.dispatch(path, params)
            self.assertEqual(context.exception.status, 400)

    def test_upstream_status_and_secret_redaction(self):
        for status in (401, 403, 429, 500):
            def fail(request, timeout):
                raise HTTPError(request.full_url, status, "secret", {}, None)
            with self.assertRaises(APIError) as context:
                NewsDataProvider("PRIVATE_KEY", opener=fail).fetch(country="CR")
            self.assertNotIn("PRIVATE_KEY", str(context.exception))
            self.assertEqual(context.exception.status, status if status != 500 else 502)

    def test_upstream_fixture(self):
        def opener(request, timeout):
            return io.BytesIO(json.dumps({"status": "success", "results": [RAW]}).encode())
        self.assertEqual(len(NewsDataProvider("test", opener=opener).fetch(country="CR")), 1)

    def test_missing_key_is_explicit(self):
        with self.assertRaises(APIError) as context:
            NewsDataProvider("").fetch()
        self.assertEqual(context.exception.status, 503)

    def test_http_contract(self):
        server = ThreadingHTTPServer(("127.0.0.1", 0), handler_for(NewsAPI(FakeProvider())))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            with urlopen(f"http://127.0.0.1:{server.server_port}/v1/headlines?country=CR&categories=technology") as response:
                self.assertEqual(response.status, 200)
                article = json.load(response)["articles"][0]
                self.assertEqual(set(article), {"id", "title", "description", "imageURL", "articleURL", "source", "publishedAt", "category", "country", "isBreakingNews"})
            with self.assertRaises(HTTPError) as context:
                urlopen(f"http://127.0.0.1:{server.server_port}/v1/search?q=")
            self.assertEqual(context.exception.code, 400)
            context.exception.close()
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


if __name__ == "__main__":
    unittest.main()
