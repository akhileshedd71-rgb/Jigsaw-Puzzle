#!/usr/bin/env python3
"""Exercise the exported game in Chromium, using an isolated browser save.

Requires Playwright (`python3 -m pip install playwright`) and Chromium.
Start tools/serve_web.py first. Screenshots go to ignored builds/screenshots.
"""

from argparse import ArgumentParser
from pathlib import Path
import shutil

from playwright.sync_api import sync_playwright


SAVE_JS = """async () => {
    const databases = await indexedDB.databases();
    const saved = [];
    for (const item of databases) {
        const db = await new Promise((resolve, reject) => {
            const request = indexedDB.open(item.name);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
        for (const name of db.objectStoreNames) {
            const keys = await new Promise((resolve, reject) => {
                const request = db.transaction(name, 'readonly').objectStore(name).getAllKeys();
                request.onsuccess = () => resolve(request.result);
                request.onerror = () => reject(request.error);
            });
            for (const key of keys) if (String(key).endsWith('piecepop_save.json')) {
                const value = await new Promise((resolve, reject) => {
                    const request = db.transaction(name, 'readonly').objectStore(name).get(key);
                    request.onsuccess = () => resolve(request.result);
                    request.onerror = () => reject(request.error);
                });
                saved.push(JSON.parse(new TextDecoder().decode(value.contents)));
            }
        }
        db.close();
    }
    return saved;
}"""


def read_save(page):
    saves = page.evaluate(SAVE_JS)
    assert len(saves) == 1, "Expected one local game save in IndexedDB"
    return saves[0]


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("--url", default="http://127.0.0.1:8060/")
    parser.add_argument("--chromium", default=shutil.which("chromium") or shutil.which("google-chrome"))
    parser.add_argument("--screenshots", type=Path, default=Path(__file__).resolve().parents[1] / "builds" / "screenshots")
    parser.add_argument("--device-scale-factor", type=float, default=1, help="Use 2.25 for 1080 × 2025 store screenshots captured directly from the app")
    args = parser.parse_args()
    args.screenshots.mkdir(parents=True, exist_ok=True)
    errors = []

    def monitor(page):
        page.on("pageerror", lambda error: errors.append(str(error)))
        page.on("console", lambda message: errors.append(message.text) if message.type == "error" else None)

    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(
            executable_path=args.chromium,
            headless=True,
            args=["--no-sandbox", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"],
        )
        # A new context keeps this test's progress separate from real players.
        context = browser.new_context(viewport={"width": 480, "height": 900}, device_scale_factor=args.device_scale_factor)
        page = context.new_page()
        monitor(page)

        def capture(name):
            page.screenshot(path=str(args.screenshots / f"{name}.png"))

        response = page.goto(args.url, wait_until="networkidle")
        assert response.status == 200
        page.wait_for_timeout(1600)
        assert page.locator("canvas").bounding_box()["width"] == 480
        capture("gallery")

        # Input coordinates intentionally exercise the designed 480 × 900 UI.
        page.mouse.click(240, 850)
        page.wait_for_timeout(400)
        capture("daily")
        page.mouse.click(78, 850)
        page.wait_for_timeout(400)
        page.mouse.click(410, 412)
        page.wait_for_timeout(400)
        capture("selection")
        page.mouse.click(238, 800)
        page.wait_for_timeout(3600)
        # Wait for the first rendered board before dragging, including at high DPI.
        capture("gameplay-start")

        # The seeded first Alpine piece is #19; drag it via the real input path.
        page.mouse.move(78, 719)
        page.mouse.down()
        page.mouse.move(78, 685, steps=3)
        page.mouse.move(129, 427, steps=12)
        page.mouse.up()
        page.wait_for_timeout(400)
        page.mouse.click(53, 842)
        page.wait_for_timeout(1800)
        save = read_save(page)
        session = save["sessions"]["alpine_escape:6:classic"]
        assert len(session["state"]["placed"]) == 2, "Drag and hint must each place one piece"

        for _ in range(2):
            page.mouse.click(53, 842)
            page.wait_for_timeout(120)
        page.mouse.click(145, 842)
        page.wait_for_timeout(3800)
        capture("gameplay")
        page.mouse.click(40, 45)
        page.wait_for_timeout(300)
        page.mouse.click(398, 850)
        page.wait_for_timeout(500)
        capture("saved")

        # Reload the WASM game, then resume through the player's saved library.
        page.reload(wait_until="networkidle")
        page.wait_for_timeout(1400)
        page.mouse.click(398, 850)
        page.wait_for_timeout(500)
        page.mouse.click(423, 244)
        page.wait_for_timeout(1600)
        capture("resumed")
        save = read_save(page)
        assert len(save["sessions"]["alpine_escape:6:classic"]["state"]["placed"]) == 4

        # Repeated hints previously exposed freed toast callbacks. This is also
        # the end-to-end completion/economy regression, including real storage.
        for _ in range(32):
            page.mouse.click(53, 842)
            page.wait_for_timeout(100)
        page.wait_for_timeout(4000)
        capture("completed")
        save = read_save(page)
        session = save["sessions"]["alpine_escape:6:classic"]
        assert session["completed"] and session["awarded"], "Completion must persist"
        assert save["coins"] == 125, "One easy puzzle must award 25 coins"

        # Keep the expansion independent from the original save/reward flow.
        # Release the completed game's WebGL context before loading another copy.
        context.close()

        # Selecting New must surface Macaron Morning, which is playable for free.
        expansion = browser.new_context(viewport={"width": 480, "height": 900}, device_scale_factor=args.device_scale_factor)
        expansion_page = expansion.new_page()
        monitor(expansion_page)
        expansion_page.goto(args.url, wait_until="networkidle")
        expansion_page.wait_for_timeout(1600)
        expansion_page.mouse.click(159, 499)
        expansion_page.wait_for_timeout(500)
        expansion_page.screenshot(path=str(args.screenshots / "new-puzzles.png"))
        expansion_page.mouse.click(128, 680)
        expansion_page.wait_for_timeout(400)
        expansion_page.mouse.click(416, 650)
        expansion_page.wait_for_timeout(300)
        expansion_page.screenshot(path=str(args.screenshots / "macaron-selection-400.png"))
        expansion_page.mouse.click(238, 800)
        expansion_page.wait_for_timeout(3600)
        expansion_page.screenshot(path=str(args.screenshots / "macaron-gameplay-start.png"))
        expansion_page.mouse.click(53, 842)
        expansion_page.mouse.click(145, 842)
        expansion_page.mouse.move(240, 350)
        expansion_page.mouse.wheel(0, -200)
        expansion_page.wait_for_timeout(3800)
        expansion_save = read_save(expansion_page)
        assert "macaron_morning:20:classic" in expansion_save["sessions"], "New must open the new free Macaron puzzle at 400 pieces"
        expansion_session = expansion_save["sessions"]["macaron_morning:20:classic"]
        assert expansion_session["grid"] == 20 and expansion_session["state"]["grid"] == 20
        assert len(expansion_session["state"]["placed"]) == 1, "A hint must work on the new 400-piece board"
        assert expansion_session["state"]["zoom"] > 1, "The new 400-piece board must support zoom"
        assert expansion_save["coins"] == 100, "Starting free expansion content must not spend coins"
        expansion_page.screenshot(path=str(args.screenshots / "macaron-gameplay-400.png"))
        expansion.close()

        for width, height, name in [(390, 844, "gallery-phone"), (320, 568, "gallery-small-phone")]:
            phone = browser.new_context(viewport={"width": width, "height": height}, device_scale_factor=1, is_mobile=True, has_touch=True)
            phone_page = phone.new_page()
            monitor(phone_page)
            phone_page.goto(args.url, wait_until="networkidle")
            phone_page.wait_for_timeout(1400)
            phone_page.screenshot(path=str(args.screenshots / f"{name}.png"))
            phone.close()
        browser.close()
    assert not errors, "Browser/Godot errors: " + repr(list(dict.fromkeys(errors)))
    print("PASS: drag, hints, IndexedDB autosave, reload/resume, completion, +25 coins, new Macaron 400-piece puzzle/zoom, narrow phone layouts, and no browser/Godot errors.")
    print(f"Screenshots: {args.screenshots}")


if __name__ == "__main__":
    main()
