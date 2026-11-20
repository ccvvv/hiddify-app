# Domestic Android Probe

This is an experimental feature for the Android build of this fork. It tests proxy nodes from the phone's actual domestic network, not from GitHub Actions or a remote VPS.

## Primary success rule

**A node is usable when the phone successfully downloads non-empty data through that selected proxy.** GPT/ChatGPT access is not required and must never be used as the default pass condition.

- Download completed and measured speed is greater than 0: **usable**.
- Download speed is at least 500 KiB/s: additionally mark **speed-passed** for ranking.
- Download completed below 500 KiB/s: still usable; classify as slower, do not discard it.
- Download failed: not usable.
- The route or active outbound cannot be verified: inconclusive, not a pass.

The 500 KiB/s threshold is a performance label, not a minimum requirement for basic usability. GPT reachability may remain an optional diagnostic field.

## Current implementation boundary

The first implementation reuses Hiddify's own `ProxyRepository` and core service. The Proxies page now has a dedicated **Domestic download probe** action. It clears previous speed results, then invokes the core's download-only speed test for the proxy group. Hiddify's core documents that a group test measures each proxy in the group and reports the per-proxy `download_speed`. This avoids a second VPN service or a companion app.

The probe is deliberately serial: only one outbound is selected and tested at a time. This is suitable for low-memory Android devices and avoids competing tunnel switches.

## First-pass workflow

1. Require an active Hiddify connection and an available proxy group.
2. Read eligible outbounds from `ProxyRepository.watchProxies()`.
3. Skip group selectors and non-selectable entries; retain original group/outbound tags only in memory.
4. Select one outbound with `selectProxy(groupTag, outboundTag)`.
5. Wait for the active outbound stream to report that outbound as selected. Do not start the request merely because the select call returned.
6. Use the strict local-proxy route to download a bounded amount of data from a stable HTTPS test endpoint. A successful non-empty download is the primary pass signal.
7. Record measured throughput. Apply 500 KiB/s only as a speed-ranking threshold, not as a usability gate.
8. Retry one transient failure once, then continue to the next outbound.
9. Show a local report. Do not silently upload proxy information.

## Important fail-closed networking rule

Hiddify's existing `DioHttpClient.get(..., proxyOnly: true)` may select its direct client when the local proxy port is closed. That method alone does not prove which outbound carried the request.

A new `DioHttpClient.getViaLocalProxy(...)` method has been added for strict probe traffic. It checks that Hiddify's local mixed proxy port is open and always uses the proxy-only Dio client; if the port is closed it throws instead of falling back to DIRECT. On Android VPN mode, the user must enable Hiddify's **Keep open in VPN mode** option so the local proxy port is available.

The probe must also wait for the active outbound stream to confirm the selected outbound before sending the request. If the active outbound has not updated, the tunnel is not running, or the strict local proxy route cannot be verified, classify the result as `inconclusive`, never `passed`.

Do not log or upload raw subscription URLs, server addresses, ports, UUIDs, passwords, keys, or full outbound JSON.

## Result fields

- Opaque stable node identifier (derived locally; must not expose secrets)
- Protocol family, if safely available
- Download status: passed / failed / inconclusive
- Optional GPT reachability: passed / failed / inconclusive; informational only
- HTTP status, not full URL query strings or response bodies
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
- A fresh, positive per-proxy download speed from the Hiddify core group test defines basic usability.
- 500 KiB/s is a speed-ranking threshold only; slower successful nodes remain usable.
- GPT access is optional and does not affect the default pass/fail result.
- Existing subscription import, normal connection, and normal Hiddify speed test remain unchanged.
- Build and device testing are required before calling the feature complete.

## Reference study: svip-s/cloudflare_ip

The project at https://github.com/svip-s/cloudflare_ip is useful as a reference for the measurement pipeline and Android operational lessons, but it solves a different problem: it discovers and ranks Cloudflare edge IP:port candidates, whereas this fork validates imported proxy outbounds through Hiddify.

Reusable ideas:
- Separate cheap reachability/latency filtering from the more expensive download test.
- Bound every network operation with connect and total timeouts; isolate failures so one bad candidate does not abort the run.
- Keep candidate, fast-result, and full-result outputs distinct; report totals and pass rates.
- Make local-only measurement independent from optional upload/notification steps.
- Provide clear run status and logs, and account for Android background execution, battery restrictions, and wake locks.
- Keep upload credentials out of source code and make remote publication a separate, explicit stage.

What must not be copied directly:
- Its TCP connect test checks a raw IP:port and its speed test uses curl `--resolve` against Cloudflare's speed endpoint. That is appropriate for Cloudflare edge-IP selection, not for testing SS/VLESS/Trojan/Hysteria2/etc. proxy nodes.
- Its high-parallelism workers should not be used for the low-memory Android probe. Switching the selected outbound is stateful; the first mobile implementation remains serial.
- Its Termux direct-route strategy is not appropriate here. Probe downloads must intentionally traverse the selected Hiddify outbound, using the strict local-proxy method and failing closed.

Adapted pipeline:
1. Enumerate eligible Hiddify outbounds and preserve group/outbound tags in memory.
2. Switch one outbound and wait for Hiddify to confirm it is active.
3. Verify the strict local proxy endpoint is available; no DIRECT fallback.
4. Download test data through that selected outbound.
5. Record actual download speed; mark >=500 KiB/s as speed-passed while retaining slower successful nodes as usable.
6. Retry a transient failure once, record a structured per-node result, and continue serially.
7. Show a local summary first. Export/upload only after user confirmation.

## Optional ChatGPT response validation

The response validator lives in `lib/features/domestic_probe/network/chatgpt_probe_response.dart`. It validates a ChatGPT web response, but it is optional diagnostic functionality only. A node that cannot reach ChatGPT can still be fully usable for ordinary internet access and download traffic.

This validator does not prove that a user account can authenticate, that a session is valid, or that a prompt can be submitted. Do not describe a passing result as a successful account login or a successful ChatGPT conversation.
