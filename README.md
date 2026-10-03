# Tanto

A lightweight macOS menu bar app that runs JavaScript-powered text commands anywhere you type.

Tanto lets you define small JavaScript functions and execute them directly from text fields in any application.

Type a trigger such as `@time`, and Tanto immediately replaces it with the result of the corresponding JavaScript function.

## Example

```javascript
rule("@hello", function() {
  return "Hello from Tanto!";
});

rule("@time", function() {
  return new Date().toLocaleString();
});
```

Type:

```text
@hello
```

Tanto replaces it with:

```text
Hello from Tanto!
```

## Features

- Native macOS menu bar app
- Works across applications
- JavaScript-based rules
- Immediate trigger execution
- No Node.js required
- User-editable `rules.js`
- Lightweight native implementation using Swift, AppKit, CGEventTap, and JavaScriptCore

## Rules

Your rules are stored at:

```text
~/Library/Application Support/Tanto/rules.js
```

Tanto creates a default `rules.js` automatically on first launch.

After editing the file, choose **Reload rules.js** from the Tanto menu.

## Default Rules

```javascript
rule("@hello", function() {
  return "Hello from Tanto!";
});

rule("@time", function() {
  return new Date().toLocaleString();
});
```

## Accessibility Permission

Tanto uses macOS Accessibility permission to monitor typed characters and replace matched triggers.

If Accessibility permission is disabled, Tanto indicates that it is unavailable from the menu bar.

The **Reset Accessibility…** command can be used to reset Tanto's Accessibility permission and reopen the relevant macOS System Settings page.

## Requirements

- macOS
- Accessibility permission

## Version

Current version: **0.3.0**

## License

MIT License

## Website

https://tulipsoft.com/

---

© 2026 Tulipsoft

