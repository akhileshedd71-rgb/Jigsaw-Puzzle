#!/usr/bin/env python3
"""Serve a local Godot Web export with the headers used by modern browsers."""

from argparse import ArgumentParser
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class GodotRequestHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--directory", type=Path, default=Path(__file__).resolve().parents[1] / "builds" / "web")
    parser.add_argument("--bind", default="127.0.0.1", help="Listening address (default: localhost only)")
    parser.add_argument("--port", type=int, default=8060)
    args = parser.parse_args()
    directory = args.directory.resolve()
    if not (directory / "index.html").is_file():
        parser.error(f"No index.html in {directory}. Export the Web preset first.")
    server = ThreadingHTTPServer((args.bind, args.port), partial(GodotRequestHandler, directory=str(directory)))
    print(f"Piecepop preview: http://{args.bind}:{args.port}/", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
