# Domestic GPT Probe

This is an experimental feature for the Android build of this fork. It is intended to test proxy nodes from the phone's actual network, not from GitHub Actions or a remote VPS.

## Current implementation boundary

The first implementation must reuse Hiddify's own `ProxyRepository` and core service. It must not start a second VPN service or ask a companion app to control Hiddify.

The probe is deliberately serial: only one outbound is selected and tested at a time. This is suitable for low-memory Android devices and avoids competing tunnel switches.

## First-pass workflow

1. Require an active Hiddify connection and an available proxy group.
2. Read the outbound list from `ProxyRepository.watchProxies()`.
3. Skip group selectors and non-selectable entries; retain the original group and outbound tags only in memory.
4. Select one outbound with `selectProxy(groupTag, outboundTag)`.
5. Wait for the active outbound stream to report that outbound as selected. Do not start the request merely because the select call returned.
6. Probe `https://chatgpt.com/` with a short timeout. A request is a candidate pass only if it is confirmed to traverse the active Hiddify tunnel and receives an expected ChatGPT response. A generic 200, redirect to an unrelated host, login interstitial, proxy error, or direct-network fallback is not a pass.
7. Measure download throughput separately. Initial threshold: 500 KiB/s. Record the measured value and threshold independently from GPT reachability.
8. Retry one transient failure once, then continue to the next outbound.
9. Show a local report. Do not silently upload proxy information.

## Important fail-closed networking rule

Hiddify's existing `DioHttpClient.get(..., proxyOnly: true)` selects its direct client when the local proxy port is closed. In VPN mode that may still be captured by Android's VPN routing, but the method alone does not prove which outbound carried the request.

A new `DioHttpClient.getViaLocalProxy(...)` method has been added for strict probe traffic. It checks that Hiddify's local mixed proxy port is open and always uses the proxy-only Dio client; if the port is closed it throws instead of falling back to DIRECT. On Android VPN mode, the user must enable Hiddify's **Keep open in VPN mode** option so the local proxy port is available. If it is unavailable, the GPT check must be `inconclusive`, not a pass.

The probe must also wait for the active outbound stream to confirm the selected outbound before sending the request. If the active outbound has not updated, the tunnel is not running, or the strict local proxy route cannot be verified, classify the result as `inconclusive` or `failed`, never `passed`.

Do not log or upload raw subscription URLs, server addresses, ports, UUIDs, passwords, keys, or full outbound JSON.

## Result fields

- Opaque stable node identifier (derived locally; must not expose secrets)
- Protocol family, if safely available
- GPT reachability: passed / failed / inconclusive
- HTTP status and final host category, not full URL query strings
- Latency in milliseconds
- Download speed in KiB/s
- Failure category and retry count
- Probe timestamp and app version

## AutoSubHub handoff

The first version exports a user-reviewed JSON report. The user explicitly chooses whether to submit it to AutoSubHub. Automated GitHub upload is a later task and must use a narrowly scoped token stored with Android Keystore-backed encryption. Never embed a personal access token in source code or an APK.

## Acceptance criteria

- Android only for the first release.
- Serial execution; no parallel node switching.
- No false pass from direct-network fallback.
- GPT reachability and speed threshold are separate result fields.
- 500 KiB/s is the initial speed threshold and can be adjusted later.
- Existing subscription import, normal connection, and normal Hiddify speed test remain unchanged.
- Build and device testing are required before calling the feature complete.

## Upstream license and release requirements

This repository's `LICENSE.md` states additional conditions beyond GPL-3.0, including keeping the work as a GitHub fork, publishing source, using GitHub Actions for releases, attribution and change notices, non-commercial use without written consent, and restrictions on publishing an app-store build under a name or interface resembling Hiddify. Review those conditions before distributing any APK. This experimental fork must not be represented as an official Hiddify release.


## Reference study: svip-s/cloudflare_ip

The project at https://github.com/svip-s/cloudflare_ip is useful as a reference for the **measurement pipeline and Android operational lessons**, but it solves a different problem: it discovers and ranks Cloudflare edge IP:port candidates, whereas this fork must validate imported proxy outbounds through Hiddify.

Reusable ideas:
- Separate a cheap reachability/latency pre-filter from the more expensive download test.
- Bound every network operation with connect and total timeouts; isolate failures so one bad candidate does not abort the run.
- Keep candidate, fast-result, and full-result outputs distinct; report totals and pass rates.
- Make local-only measurement independent from optional upload/notification steps. A measurement failure must stop publication rather than publish stale or partial results.
- Provide clear run status and logs, and account for Android background execution, battery restrictions, and wake locks.
- Keep upload credentials out of source code and make remote publication a separate, explicit stage.

What must **not** be copied directly:
- Its TCP connect test checks a raw IP:port and its speed test uses curl `--resolve` against Cloudflare's speed endpoint. That is appropriate for Cloudflare edge-IP selection, not for testing SS/VLESS/Trojan/Hysteria2/etc. proxy nodes.
- Its parallel TCP and download workers (hundreds / dozens) should not be used for the Xiaomi 6 Hiddify probe. Switching the selected outbound is stateful; the first mobile implementation remains serial.
- Its instruction to exclude Termux from the VPN is specific to measuring the phone's direct route to Cloudflare. Our GPT check must intentionally traverse the selected Hiddify outbound, so it must use the strict local-proxy method and fail closed.

Adapted pipeline for this fork:
1. Enumerate eligible Hiddify outbounds and preserve group/outbound tags in memory.
2. Switch one outbound and wait for Hiddify to confirm it is active.
3. Verify the strict local proxy endpoint is available; no DIRECT fallback.
4. Run the GPT reachability check with a bounded timeout.
5. Run the download test separately, then apply the 500 KiB/s threshold.
6. Retry a transient failure once, record a structured per-node result, and continue serially.
7. Show a local summary first. Export/upload only after user confirmation.

This borrows the reference project's staged filtering, timeout discipline, reporting, and safe publication boundary without confusing Cloudflare IP speed with proxy-node usability.
