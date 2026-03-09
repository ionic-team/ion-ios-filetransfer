## [1.0.2](https://github.com/ionic-team/ion-ios-filetransfer/compare/1.0.1...1.0.2) (2026-02-03)


### Bug Fixes

* correct semantic-release plugin execution order to prevent GitHub release timing issue ([#17](https://github.com/ionic-team/ion-ios-filetransfer/issues/17)) ([2cc0dbc](https://github.com/ionic-team/ion-ios-filetransfer/commit/2cc0dbcb05b06595e9e86b322569891cd2ecdc00))
* Return response body in HTTP Error ([#13](https://github.com/ionic-team/ion-ios-filetransfer/issues/13)) ([0302920](https://github.com/ionic-team/ion-ios-filetransfer/commit/0302920c122b98af348e4fa8cdf62342d5ceac50))
* use absolute paths for debug symbols in XCFramework creation ([#15](https://github.com/ionic-team/ion-ios-filetransfer/issues/15)) ([1f69029](https://github.com/ionic-team/ion-ios-filetransfer/commit/1f69029fa6546ded361566de6b7c5170f9b2664c))

## 1.0.1

### 2025-08-01

- Fix progress notification for `uploadFile`.
- Fix error (only visible in logs) related to `chunkedMode` and `httpBodyStream`.

## 1.0.0

### 2025-04-14

- Implement native library with methods `downloadFile` and `uploadFile`.
