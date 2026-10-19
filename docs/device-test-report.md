# Android emulator verification

Verified on 19 October 2026 using the configured Pixel_8 AVD, Android 16 / API 36 (`emulator-5554`, Android x64, 1080 × 2400 display).

The on-device scenario passed using Flutter's SDK integration-test runner and real DummyJSON product/category/detail responses. All seven checkpoints completed without Flutter framework exceptions:

| Check | Result |
| --- | --- |
| Initial product/category failure and Retry | Passed; retries retrieved live API data |
| Server pagination and later-page failure | Passed; offset 20 requested and retried, existing catalogue retained |
| Combined discovery and tab preservation | Passed; global search, two categories, price band and sort; one complete-dataset download |
| Product details | Passed; real detail endpoint, multi-image swipe, position indicator, shipping/returns expansion, repeated additions and quantity badge |
| Cart editing | Passed; one merged row, pending native-keyboard quantity edit, plus, invalid zero rejection and cancelled removal |
| Demo checkout | Passed; pending edit included, total matched integer-cent rules, cart cleared, disclaimer shown, Continue Shopping restored Shop |
| Android back | Passed; details returned to the existing catalogue context |

The run recorded 12 HTTP attempts, including controlled failures. Failure conditions were injected at the HTTP transport boundary; emulator Wi-Fi was not disabled. Successful recovery and other product requests used the real API. No payment or order endpoint was called.

```powershell
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/cartly_test.dart -d emulator-5554
```

Screenshots were captured by the integration runner and visually inspected: [Shop](screenshots/shop.png), [details](screenshots/product-details.png), [cart](screenshots/cart.png), [success](screenshots/demo-success.png), [API error](screenshots/api-error.png). The generated machine-readable report is `build/integration_response_data.json` (ignored by Git).

After adding the device suite, `flutter test` still passed all 71 unit/widget tests and `flutter analyze` reported no issues. Formatting and Git whitespace checks passed. No application code needed further changes during this device pass.

The Windows computer-use helper was unavailable, so interactions used Flutter's on-device test APIs rather than desktop mouse automation. TalkBack, physical phones, other operating systems, and actual radio/network transitions remain outside this verification. The reproducible integration scenario is separate from the network-free unit/widget suite.
