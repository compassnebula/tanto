import AppKit
import JavaScriptCore

final class ScriptEngine {
    private var context: JSContext?
    private let fm = FileManager.default

    private var configDirectory: URL {
        fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tanto", isDirectory: true)
    }
    private var rulesURL: URL { configDirectory.appendingPathComponent("rules.js") }

    func prepareDefaultRulesIfNeeded() {
        try? fm.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: rulesURL.path) {
            try? Self.defaultRules.write(to: rulesURL, atomically: true, encoding: .utf8)
            return
        }

    }

    func reload() {
        NSLog("Tanto: loading rules.js from %@", rulesURL.path)
        let ctx = JSContext()!
        ctx.exceptionHandler = { _, exception in
            if let exception { NSLog("Tanto JS ERROR: %@", exception.toString() ?? "unknown error") }
        }
        ctx.setObject({ () -> Double in Date().timeIntervalSince1970 * 1000 } as @convention(block) () -> Double,
                      forKeyedSubscript: "__tantoNow" as NSString)

        guard let source = try? String(contentsOf: rulesURL, encoding: .utf8) else {
            NSLog("Tanto: ERROR — could not read rules.js")
            context = ctx
            return
        }

        ctx.evaluateScript(Self.bootstrap)
        if let exception = ctx.exception {
            NSLog("Tanto: bootstrap failed: %@", exception.toString() ?? "unknown")
            ctx.exception = nil
        }

        ctx.evaluateScript(source)
        if let exception = ctx.exception {
            NSLog("Tanto: rules.js failed: %@", exception.toString() ?? "unknown")
            ctx.exception = nil
        }

        context = ctx
        let triggers = ctx.objectForKeyedSubscript("__tantoTriggers")?.call(withArguments: [])?.toArray() as? [String] ?? []
        NSLog("Tanto: rules.js loaded; triggers = %@", triggers.joined(separator: ", "))
    }

    func evaluate(_ expression: String) -> String? {
        guard let context else {
            NSLog("Tanto: JS context missing")
            return nil
        }
        guard let run = context.objectForKeyedSubscript("__tantoRun"), !run.isUndefined else {
            NSLog("Tanto: ERROR — __tantoRun missing")
            return nil
        }

        let value = run.call(withArguments: [expression])
        if let exception = context.exception {
            NSLog("Tanto JS ERROR while evaluating %@: %@", expression, exception.toString() ?? "unknown")
            context.exception = nil
            return nil
        }
        guard let value, !value.isUndefined, !value.isNull else { return nil }
        let result = value.toString()
        NSLog("Tanto: JS matched %@", expression)
        return result
    }

    func openRules() { NSWorkspace.shared.open(rulesURL) }

    private static let bootstrap = #"""
    var __tantoRules = Object.create(null);
    function rule(trigger, fn) {
      __tantoRules[String(trigger)] = fn;
    }
    function __tantoRun(trigger) {
      var fn = __tantoRules[String(trigger)];
      if (typeof fn !== 'function') return undefined;
      return String(fn());
    }
    function __tantoTriggers() {
      return Object.keys(__tantoRules);
    }
    function now() { return new Date(__tantoNow()); }
    function pad2(n) { return String(n).padStart(2, '0'); }
    function tokyoParts() {
      var parts = new Intl.DateTimeFormat('en-US', {
        timeZone: 'Asia/Tokyo', year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', hourCycle: 'h23', weekday: 'short'
      }).formatToParts(now());
      var result = {};
      parts.forEach(function(p) { result[p.type] = p.value; });
      return result;
    }
    """#

    private static let defaultRules = #"""
// Tanto rules.js
// Edit this file, then choose “Reload rules.js” from the menu bar.

rule("@hello", function() {
  return "Hello from Tanto!";
});

rule("@time", function() {
  return new Date().toLocaleString();
});
"""#
}
