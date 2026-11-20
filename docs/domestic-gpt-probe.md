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
