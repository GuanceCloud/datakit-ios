import assert from 'node:assert/strict'
import test from 'node:test'
import { verifyObjectiveCCategories } from './verify-runtime.mjs'

const appKitCategories = `
0000000000184e80 (__DATA,__objc_const) non-external __OBJC_$_CATEGORY_NSApplication_$_FTAutotrack
0000000000185518 (__DATA,__objc_const) non-external __OBJC_$_CATEGORY_NSWindow_$_FTAutoTrack
`
const standaloneWebView = '00000000001824c0 (__DATA,__objc_const) non-external __OBJC_$_CATEGORY_WKWebView_$_FTAutoTrack'
// Captured from the release addon after Visitor ID introduced a second WKWebView category.
const mergedWebView = `
00000000001824c0 (__DATA,__objc_const) non-external __OBJC_$_CATEGORY_WKWebView_$_FTVisitorIDBridge
00000000001065f0 (__TEXT,__objc_methlist) non-external __OBJC_$_INSTANCE_METHODS_WKWebView(FTVisitorIDBridge|FTAutoTrack)
`

test('accepts standalone Objective-C categories', () => {
  assert.doesNotThrow(() => verifyObjectiveCCategories(appKitCategories + standaloneWebView))
})

test('accepts the linked WKWebView method list after category merging', () => {
  assert.doesNotThrow(() => verifyObjectiveCCategories(appKitCategories + mergedWebView))
})

test('rejects a missing category even when its method implementation remains', () => {
  const implementation = '0000000000089f8c (__TEXT,__text) non-external -[WKWebView(FTAutoTrack) ft_loadRequest:]'
  assert.throws(() => verifyObjectiveCCategories(appKitCategories + implementation), /CATEGORY_WKWebView_\$_FTAutoTrack/u)
})

test('a merged method list must have a surviving category record', () => {
  const methodListOnly = mergedWebView.replace(/^.*CATEGORY_WKWebView.*$/mu, '')
  assert.throws(() => verifyObjectiveCCategories(appKitCategories + methodListOnly), /CATEGORY_WKWebView_\$_FTAutoTrack/u)
})

test('merged category names must match both the class and the complete category name', () => {
  for (const symbol of [
    '__OBJC_$_INSTANCE_METHODS_OtherWebView(FTVisitorIDBridge|FTAutoTrack)',
    '__OBJC_$_INSTANCE_METHODS_WKWebView(FTVisitorIDBridge|FTAutoTrackExtra)',
    '__OBJC_$_CATEGORY_WKWebView_$_FTAutoTrackExtra',
  ]) {
    assert.throws(() => verifyObjectiveCCategories(appKitCategories + symbol), /CATEGORY_WKWebView_\$_FTAutoTrack/u)
  }
})

test('each architecture must retain all required categories', () => {
  assert.doesNotThrow(() => verifyObjectiveCCategories(appKitCategories + mergedWebView))
  assert.throws(() => verifyObjectiveCCategories(mergedWebView), /CATEGORY_NSApplication_\$_FTAutotrack/u)
  assert.throws(() => verifyObjectiveCCategories(appKitCategories.replace(/^.*CATEGORY_NSWindow.*$/mu, '') + mergedWebView), /CATEGORY_NSWindow_\$_FTAutoTrack/u)
})
