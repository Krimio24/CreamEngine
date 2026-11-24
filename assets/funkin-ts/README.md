# funkin-ts 0.2.0

Generated module bindings for CreamEngine and HaxeFlixel.

## Coverage

- CreamEngine `Source/funkin`: 25 Haxe modules discovered from the repository's `main` branch.
- HaxeFlixel: 258 modules from tag `6.2.0`.
- Imports preserve Haxe module paths, using slash-separated TypeScript specifiers.

## Example

```ts
import { TitleState } from "funkin/ui/title/TitleState";
import { FlxG } from "flixel/FlxG";
import { FlxSprite } from "flixel/FlxSprite";

TitleState.moveToAttract();

FlxG.sound.play("confirmMenu");

const sprite = new FlxSprite(100, 120);
sprite.loadGraphic("images/my-sprite.png");
```

A short alias is also provided:

```ts
import { TitleState } from "funkin/ui/TitleState";
```

## Important runtime contract

These modules are generated dynamic proxies, not a full static translation of Haxe source into TypeScript. They provide import coverage and route method/property access to CreamServer at `http://127.0.0.1:2414`.

The server must implement:

- `POST /api/v1/create` — construct an instance and associate an `objectId`.
- `POST /api/v1/call` — call a static or instance method.
- `GET /api/v1/get?path=...` — read a property/path.

Expected response:

```json
{ "ok": true, "result": null }
```

For errors:

```json
{ "ok": false, "error": "Unknown method" }
```

## Async behavior

Network-backed calls return Promises. Use `await` when ordering matters:

```ts
await sprite.__ready;
await sprite.loadGraphic("images/my-sprite.png");
await sprite.setPosition(200, 150);
```

The Haxe object must remain owned by CreamEngine. The server must validate every module, class, member, object ID and argument; do not expose unrestricted reflection.

## Build

```bash
npm install
npm run build
```

## Version note

The CreamEngine module list was read from the repository's `main` tree. HaxeFlixel modules are based on the `6.2.0` tag. This package does not include OpenFL, Lime, Flixel Addons or FlxAnimate bindings yet, even though CreamEngine declares those dependencies in `project.xml`.
