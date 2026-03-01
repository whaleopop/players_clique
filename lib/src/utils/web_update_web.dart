import 'dart:js_interop';

@JS('eval')
external void _eval(String code);

void reloadAndUpdate() {
  _eval("""
    (async () => {
      if (navigator.serviceWorker) {
        const regs = await navigator.serviceWorker.getRegistrations();
        await Promise.all(regs.map(r => r.unregister()));
      }
      window.location.reload();
    })();
  """);
}
