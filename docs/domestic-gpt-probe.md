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

The dedicated button delegates per-outbound measurements to Hiddify's core. The Dart UI makes one group-level download-test call; it does not manually switch the active proxy for each node. The core's RPC contract says a group test measures each proxy in that group and reports the speeds with the proxy entries. Do not claim a particular concurrency level until the core implementation is inspected.

## First-pass workflow

1. Require an active Hiddify connection and an available proxy group.
2. Count selectable outbound entries for the confirmation dialog.
3. Clear previous speed-test results. If clearing fails, abort rather than risk showing stale positive speeds.
4. Call `ProxyRepository.downloadTest(groupTag, bytes)` only. This deliberately ignores the general speed-test direction setting, so upload-only or both-direction preferences cannot change this probe into an upload test.
5. Hiddify's core tests the group's proxies and reports each proxy's `download_speed`.
6. A fresh speed greater than 0 means usable. A speed of at least 500 KiB/s is additionally speed-passed; lower positive speeds remain usable.
7. Show the measured speeds in Hiddify's existing proxy list. Do not silently upload proxy information.

The app currently uses Hiddify's existing per-proxy speed fields for display. The standalone `DomesticProbeResult` model is not yet wired into a separate export/report screen.


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
- Uses Hiddify core's group-level download-test RPC; the app does not manually switch the active outbound.
- Uses the core's native per-proxy speed-test path rather than a direct-network HTTP fallback.
- A fresh, positive per-proxy download speed from the Hiddify core group test defines basic usability.
- 500 KiB/s is a speed-ranking threshold only; slower successful nodes remain usable.
- GPT access is optional and does not affect the default pass/fail result.
- Existing subscription import, normal connection, and normal Hiddify speed test remain unchanged.
- Build and device testing are required before calling the feature complete.

## Generic GitHub destination configuration

The result-upload feature must be repository-agnostic. Do not hard-code the original author's AutoSubHub repository, owner, branch, workflow name, or credentials into the app.

### User setup

Add a separate **Result upload** settings screen with these fields:

- GitHub repository: required `owner/repository` (accept a repository URL as a convenience, then normalize and validate it).
- Target branch: optional; default to the repository's default branch.
- Dispatch event type: configurable, default `domestic-probe-results`.
- Credential: supplied and authorized by the user for that repository.

Provide **Test connection** before saving. It should validate the repository, credential access, and that the destination has a compatible `repository_dispatch` receiver workflow. Do not claim that a dispatch was processed merely because GitHub accepted the event: GitHub's dispatch API returns no workflow-run identifier. The UI should say "GitHub accepted the event" unless it separately verifies a matching Actions run.

### Credential and privacy requirements

- Never ship a developer's personal access token, repository secret, or default upload destination in the APK.
- Prefer a narrowly scoped fine-grained token restricted to the selected repository with the minimum permission required by the dispatch endpoint (currently repository Contents: write). Explain the scope and expiry to the user.
- Store the credential only using Android Keystore-backed encrypted storage; never log it, include it in crash reports, export it, or sync it in plaintext.
- Provide disconnect/revoke guidance and a **Delete saved credential** action.
- Upload only the sanitized, user-reviewed report. Exclude server address, port, UUID, password, private key, subscription URL, and full outbound configuration.
- Require an explicit confirmation for every upload. No automatic upload in the first release.
- If the selected repository has no compatible receiver workflow, show setup instructions and a sample workflow file the user can add to their own repository. Do not silently send data to another repository.

### Portable payload contract

Keep the event payload versioned and repository-neutral, for example:

- `schema_version`
- `generated_at`
- `app_version`
- `summary` (counts only)
- `results[]` containing opaque node ID, safe protocol family, download status, positive measured speed when available, latency, attempt count, and check timestamp.

Document the payload schema independently of AutoSubHub. AutoSubHub may remain one example receiver, not a required destination. The receiver workflow is responsible for validating the payload and deciding how to store it.

### Upload UX

1. Show the completed local report and exact destination repository.
2. Let the user review the fields and counts.
3. Require a separate **Confirm upload** action.
4. Show distinct states: not configured, ready, uploading, accepted by GitHub, receiver workflow verified, and failed.
5. Preserve the local report after failure so the user can retry without repeating the speed test.

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
